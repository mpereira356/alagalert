# app/services/geocode.py
from typing import Optional, List, Dict
import httpx
import unicodedata

NOMINATIM_BASE = "https://nominatim.openstreetmap.org/search"
HEADERS = {"User-Agent": "AlagAlert/1.0 (contact: suporte@alagalert.local)"}

# Mapa UF -> nome do estado (para busca estruturada)
UF_TO_STATE = {
    "AC": "Acre","AL":"Alagoas","AP":"Amapá","AM":"Amazonas","BA":"Bahia","CE":"Ceará",
    "DF":"Distrito Federal","ES":"Espírito Santo","GO":"Goiás","MA":"Maranhão",
    "MT":"Mato Grosso","MS":"Mato Grosso do Sul","MG":"Minas Gerais","PA":"Pará",
    "PB":"Paraíba","PR":"Paraná","PE":"Pernambuco","PI":"Piauí","RJ":"Rio de Janeiro",
    "RN":"Rio Grande do Norte","RS":"Rio Grande do Sul","RO":"Rondônia","RR":"Roraima",
    "SC":"Santa Catarina","SP":"São Paulo","SE":"Sergipe","TO":"Tocantins"
}

def _normalize(s: str) -> str:
    if not s:
        return ""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    return s.lower().strip()

def _row_to_item(d: Dict) -> Dict:
    addr = d.get("address", {})
    raw_code = (
        addr.get("state_code")
        or addr.get("ISO3166-2-lvl4")
        or addr.get("ISO3166-2-lvl6")
        or ""
    )
    uf_norm = raw_code.split("-")[-1].upper() if raw_code else ""
    city_name = (
        addr.get("city")
        or addr.get("town")
        or addr.get("village")
        or d.get("display_name", "")
    )
    return {
        "lat": d["lat"],
        "lon": d["lon"],
        "city": city_name,
        "uf": uf_norm,
        "display_name": d.get("display_name"),
        "address": addr,
        "class": d.get("class"),
        "type": d.get("type"),
        "importance": d.get("importance", 0),
    }

async def _nominatim_get(params: Dict) -> List[Dict]:
    async with httpx.AsyncClient(headers=HEADERS, timeout=15) as client:
        r = await client.get(NOMINATIM_BASE, params=params)
        r.raise_for_status()
        return r.json()

async def nominatim_lookup(
    query: str,
    country: str = "br",
    limit: int = 8,
    cities_only: bool = True,
    prefer_uf: Optional[str] = None,
):
    """Busca livre no Nominatim, com priorização por UF."""
    params = {
        "q": query,
        "countrycodes": country,
        "format": "json",
        "addressdetails": 1,
        "limit": limit,
    }
    data = await _nominatim_get(params)
    items = [_row_to_item(d) for d in data]

    if cities_only:
        items = [it for it in items if any(k in it["address"] for k in ["city", "town", "village"])]

    if not items:
        # fallback: mesma query sem filtro “cities_only” (filtra manual depois)
        data2 = await _nominatim_get(params)
        items = [_row_to_item(d) for d in data2]
        items = [it for it in items if any(k in it["address"] for k in ["city", "town", "village"])]

    if prefer_uf:
        pref = prefer_uf.upper()
        prio = [it for it in items if it["uf"] == pref]
        if prio:
            items = prio + [it for it in items if it["uf"] != pref]

    items.sort(key=lambda it: it.get("importance", 0), reverse=True)

    return [
        {"lat": it["lat"], "lon": it["lon"], "city": it["city"], "uf": it["uf"], "display_name": it["display_name"]}
        for it in items
    ]

async def nominatim_lookup_structured_city_uf(
    city: str,
    uf: str,
    limit: int = 5,
) -> List[Dict]:
    """
    Fallback estruturado: city + state + country = Brazil.
    Usa o nome completo do estado para aumentar precisão.
    """
    uf = uf.upper().strip()
    state_name = UF_TO_STATE.get(uf, uf)  # aceita “SP” ou o nome já completo
    params = {
        "city": city,
        "state": state_name,
        "country": "Brazil",
        "format": "json",
        "addressdetails": 1,
        "limit": limit,
    }
    data = await _nominatim_get(params)
    items = [_row_to_item(d) for d in data]
    # ainda reforça a UF quando vier com "BR-SP"
    items = [it for it in items if it["uf"] in (uf, "")]
    items.sort(key=lambda it: it.get("importance", 0), reverse=True)
    return [
        {"lat": it["lat"], "lon": it["lon"], "city": it["city"], "uf": it["uf"], "display_name": it["display_name"]}
        for it in items
    ]

async def nominatim_lookup_states(query: str, country: Optional[str] = None, limit: int = 10):
    params = {
        "q": query,
        "format": "json",
        "addressdetails": 1,
        "limit": limit,
        "countrycodes": country or "br",
        "featuretype": "state",
    }
    data = await _nominatim_get(params)
    results = []
    for d in data:
        address = d.get("address", {})
        state = address.get("state") or d.get("display_name", "")
        uf = (
            address.get("state_code")
            or address.get("ISO3166-2-lvl4")
            or ""
        )
        if not uf and state:
            last = state.split()[-1]
            uf = last.upper() if len(last) == 2 else ""
        results.append({
            "lat": d.get("lat"),
            "lon": d.get("lon"),
            "state": state,
            "uf": uf,
            "display_name": d.get("display_name"),
        })
    return results
