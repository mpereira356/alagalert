import os
from typing import Optional

from fastapi import FastAPI, Request, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from .services.geocode import local_lookup, nominatim_lookup, find_centroid_by_city
from .services.weather_client import fetch_hourly_forecast
from .services.regions import load_regions_geojson
from .utils.risk_engine import compute_risk

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
RATE_LIMIT = os.getenv("RATE_LIMIT", "60/minute")

limiter = Limiter(key_func=get_remote_address, default_limits=[])
app = FastAPI(title="AlagAlert API", version="0.2.0")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",  # Flutter Web em qualquer porta
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class RiskBody(BaseModel):
    lat: float
    lon: float

@app.get("/health")
@limiter.limit(RATE_LIMIT)
def health(request: Request):
    return JSONResponse({"ok": True})

@app.get("/geocode")
@limiter.limit(RATE_LIMIT)
def geocode(request: Request, q: str = Query(..., min_length=1)):
    # 1ª tentativa: lookup local por IBGE (rápido e offline)
    locs = local_lookup(q)
    if locs:
        return JSONResponse(locs)
    # 2ª tentativa: Nominatim (se desejar, chamar aqui de forma assíncrona)
    return JSONResponse([])

@app.get("/regions")
@limiter.limit(RATE_LIMIT)
def regions(
    request: Request,
    level: str = Query(..., pattern="^(state|city)$"),
    uf: Optional[str] = Query(None, min_length=2, max_length=2),
):
    gj = load_regions_geojson(level=level, uf=(uf.upper() if uf else None))
    if gj is None:
        raise HTTPException(404, detail="GeoJSON não disponível")
    return JSONResponse(gj)

@app.get("/risk/by-city")
@limiter.limit(RATE_LIMIT)
async def risk_by_city(
    request: Request,
    uf: str = Query(..., min_length=2, max_length=2),
    city: str = Query(..., min_length=1),
):
    uf = uf.upper()
    # 1) tenta pegar lat/lon do IBGE leve
    centroid = find_centroid_by_city(uf, city)
    if centroid is None:
        # fallback rápido: Nominatim
        nomi = await nominatim_lookup(f"{city} {uf}, Brasil")
        if not nomi:
            raise HTTPException(404, detail="Cidade não encontrada")
        centroid = {"lat": nomi[0]["lat"], "lon": nomi[0]["lon"]}

    lat, lon = centroid["lat"], centroid["lon"]

    # 2) consulta Open-Meteo (24h) e extrai janela de 6h
    hourly = await fetch_hourly_forecast(lat=lat, lon=lon)

    # 3) calcula risco
    result = compute_risk(hourly)
    result["location"] = {"uf": uf, "city": city, "lat": lat, "lon": lon}
    return JSONResponse(result)

@app.post("/risk")
@limiter.limit(RATE_LIMIT)
async def risk_by_coords(request: Request, body: RiskBody):
    hourly = await fetch_hourly_forecast(lat=body.lat, lon=body.lon)
    result = compute_risk(hourly)
    result["location"] = {"lat": body.lat, "lon": body.lon}
    return JSONResponse(result)

