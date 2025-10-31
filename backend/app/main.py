import os
from typing import Optional
from pathlib import Path

from fastapi import FastAPI, Request, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

import httpx

# serviços locais
from .services.regions import load_regions_geojson
from .services.geocode import (
    nominatim_lookup,
    nominatim_lookup_states,
)
from .services.weather_client import fetch_hourly_forecast
from .utils.risk_engine import compute_risk

# ---------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
RATE_LIMIT = os.getenv("RATE_LIMIT", "60/minute")

limiter = Limiter(key_func=get_remote_address, default_limits=[])

app = FastAPI(title="AlagAlert API", version="0.7.0")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------
class RiskBody(BaseModel):
    lat: float
    lon: float

# ---------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------
@app.get("/health")
@limiter.limit(RATE_LIMIT)
def health(request: Request):
    return JSONResponse({"ok": True})

# ---------------------------------------------------------------------
# Geocode (cidades)
# ---------------------------------------------------------------------
@app.get("/geocode")
async def geocode(
    request: Request,
    q: str = Query(..., min_length=1),
    country: str = Query("br"),
    limit: int = Query(8, ge=1, le=50),  # <-- aumentado para aceitar até 50
    cities_only: bool = Query(True),
    uf: Optional[str] = Query(
        None, min_length=2, max_length=2, description="Filtro opcional de UF (ex: SP, RJ)"
    ),
):
    """Busca cidades via Nominatim com filtro opcional por UF."""
    try:
        from .services.geocode import nominatim_lookup, nominatim_lookup_structured_city_uf

        results = await nominatim_lookup(
            query=q,
            country=country,
            limit=limit,
            cities_only=cities_only,
            prefer_uf=(uf or "").upper() or None,
        )

        if (not results) and uf:
            results = await nominatim_lookup_structured_city_uf(
                city=q, uf=uf.upper(), limit=limit
            )

        return results or []
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erro ao consultar Nominatim: {e}")

# ---------------------------------------------------------------------
# Geocode (estados)
# ---------------------------------------------------------------------
@app.get("/geocode-states")
@limiter.limit(RATE_LIMIT)
async def geocode_states(
    request: Request,
    q: str = Query(..., min_length=1, description="Nome ou sigla do estado (ex.: 'sp', 'sao paulo')"),
    country: Optional[str] = Query("br", min_length=0, max_length=2),
    limit: int = Query(27, ge=1, le=27),
):
    results = await nominatim_lookup_states(query=q, country=country or None, limit=limit)
    if not results:
        raise HTTPException(404, detail="Nenhum estado encontrado")
    return JSONResponse(results)

# ---------------------------------------------------------------------
# IBGE – estados e cidades
# ---------------------------------------------------------------------
@app.get("/states")
@limiter.limit(RATE_LIMIT)
async def list_states(request: Request):
    url = "https://servicodados.ibge.gov.br/api/v1/localidades/estados"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url)
            r.raise_for_status()
            data = r.json()
            data = sorted(data, key=lambda x: x.get("nome", ""))
            return [{"sigla": uf["sigla"], "nome": uf["nome"]} for uf in data]
    except httpx.HTTPError as e:
        raise HTTPException(502, detail=f"Falha IBGE estados: {e}")

@app.get("/cities")
@limiter.limit(RATE_LIMIT)
async def list_cities_by_state(
    request: Request,
    uf: str = Query(..., min_length=2, max_length=2),
):
    uf = uf.upper()
    url = f"https://servicodados.ibge.gov.br/api/v1/localidades/estados/{uf}/municipios"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url)
            r.raise_for_status()
            data = r.json()
            data = sorted(data, key=lambda x: x.get("nome", ""))
            return [{"nome": m["nome"]} for m in data]
    except httpx.HTTPError as e:
        raise HTTPException(502, detail=f"Falha IBGE municípios: {e}")

# ---------------------------------------------------------------------
# Risco por cidade
# ---------------------------------------------------------------------
@app.get("/risk/by-city")
@limiter.limit(RATE_LIMIT)
async def risk_by_city(
    request: Request,
    uf: str = Query(..., min_length=2, max_length=2),
    city: str = Query(..., min_length=1),
):
    uf = uf.upper()

    nomi = await nominatim_lookup(
        query=f"{city} {uf}, Brasil",
        country="br",
        limit=3,
        cities_only=True,
        prefer_uf=uf,
    )

    if not nomi:
        from .services.geocode import nominatim_lookup_structured_city_uf
        nomi = await nominatim_lookup_structured_city_uf(city=city, uf=uf, limit=5)

    if not nomi:
        raise HTTPException(404, detail="Cidade não encontrada no Nominatim")

    lat = float(nomi[0]["lat"])
    lon = float(nomi[0]["lon"])

    hourly = await fetch_hourly_forecast(lat=lat, lon=lon)
    result = compute_risk(hourly)
    result["location"] = {"uf": uf, "city": city, "lat": lat, "lon": lon}
    return JSONResponse(result)

# ---------------------------------------------------------------------
# Risco por coordenadas
# ---------------------------------------------------------------------
@app.post("/risk")
@limiter.limit(RATE_LIMIT)
async def risk_by_coords(request: Request, body: RiskBody):
    hourly = await fetch_hourly_forecast(lat=body.lat, lon=body.lon)
    result = compute_risk(hourly)
    result["location"] = {"lat": body.lat, "lon": body.lon}
    return JSONResponse(result)

# ---------------------------------------------------------------------
# Risco por UF (para mapa)
# ---------------------------------------------------------------------
@app.get("/risk/by-uf")
@limiter.limit(RATE_LIMIT)
async def risk_by_uf(
    request: Request,
    uf: str = Query(..., min_length=2, max_length=2),
):
    uf = uf.upper()
    url = f"https://servicodados.ibge.gov.br/api/v1/localidades/estados/{uf}/municipios"
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.get(url)
            r.raise_for_status()
            cities = r.json()
    except httpx.HTTPError as e:
        raise HTTPException(502, detail=f"Falha IBGE: {e}")

    out = []
    for c in cities:
        name = c.get("nome")
        if not name:
            continue
        try:
            nomi = await nominatim_lookup(
                query=f"{name}, {uf}, Brasil",
                country="br",
                limit=1,
                cities_only=True,
            )
            if not nomi:
                continue
            lat = float(nomi[0]["lat"])
            lon = float(nomi[0]["lon"])
            hourly = await fetch_hourly_forecast(lat=lat, lon=lon)
            risk = compute_risk(hourly).get("risk_level")
            out.append({"city": name, "uf": uf, "lat": lat, "lon": lon, "risk": risk})
        except Exception:
            continue

    if not out:
        raise HTTPException(404, detail=f"Nenhum município encontrado para {uf}")
    return JSONResponse(out)

# ---------------------------------------------------------------------
# Regions (GeoJSON)
# ---------------------------------------------------------------------
@app.get("/regions")
@limiter.limit(RATE_LIMIT)
async def regions(
    request: Request,
    level: str = Query(..., pattern="^(state|city)$"),
    uf: Optional[str] = Query(None, min_length=2, max_length=2),
):
    try:
        gj = load_regions_geojson(level=level, uf=(uf.upper() if uf else None))
        if gj is None:
            raise HTTPException(404, detail="GeoJSON não disponível")
        return JSONResponse(gj)
    except Exception as e:
        raise HTTPException(500, detail=f"Erro ao carregar regiões: {e}")

# ---------------------------------------------------------------------
# Servir Flutter Web na raiz
# ---------------------------------------------------------------------
WEB_DIR = os.getenv(
    "WEB_DIR",
    str(Path(__file__).resolve().parents[2] / "mobile" / "build" / "web")
)
if os.path.isdir(WEB_DIR) and os.path.exists(os.path.join(WEB_DIR, "index.html")):
    print(f"[AlagAlert] Servindo Flutter Web em: {WEB_DIR}")
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")
else:
    print(f"[AlagAlert] AVISO: Pasta WEB não encontrada ou sem index.html: {WEB_DIR}")
