import json
from pathlib import Path
from typing import List, Dict, Optional
import httpx

DATA_DIR = Path(__file__).resolve().parents[2] / "data" / "ibge"

def _read_json(path: Path):
    if not path.exists():
        return None
    # tolera BOM no Windows
    return json.loads(path.read_text(encoding="utf-8-sig"))

UF_JSON = _read_json(DATA_DIR / "uf.json")  # FeatureCollection
MUN_LIST = _read_json(DATA_DIR / "municipios.json") or []  # lista leve [{"uf","nome","centroid":{lat,lon}}]

def local_lookup(query: str) -> List[Dict]:
    """Busca simples na tabela leve de municípios IBGE."""
    q = query.lower().strip()
    results = []
    for m in MUN_LIST:
        name = m.get("nome", "")
        uf = (m.get("uf") or "").upper()
        comp = f"{name} {uf}".lower()
        if q in name.lower() or q in comp:
            c = m.get("centroid") or {}
            if "lat" in c and "lon" in c:
                results.append({
                    "name": f"{name} - {uf}",
                    "uf": uf,
                    "city": name,
                    "lat": c["lat"],
                    "lon": c["lon"],
                    "source": "IBGE"
                })
    return results

def find_centroid_by_city(uf: str, city: str) -> Optional[Dict]:
    uf = uf.upper()
    for m in MUN_LIST:
        if (m.get("uf") or "").upper() == uf and (m.get("nome") or "").lower() == city.lower():
            c = m.get("centroid") or {}
            if "lat" in c and "lon" in c:
                return {"lat": float(c["lat"]), "lon": float(c["lon"])}
    return None

async def nominatim_lookup(query: str, url: str = "https://nominatim.openstreetmap.org/search") -> List[Dict]:
    """Fallback para geocodificação via OSM/Nominatim."""
    headers = {"User-Agent": "alagalert/1.0 (educational)"}
    params = {"q": query, "format": "json", "limit": 5, "addressdetails": 1}
    async with httpx.AsyncClient(timeout=10, headers=headers) as client:
        r = await client.get(url, params=params)
        r.raise_for_status()
        data = r.json()
        out = []
        for item in data:
            addr = item.get("address", {})
            out.append({
                "name": item.get("display_name"),
                "uf": addr.get("state"),
                "city": addr.get("city") or addr.get("town") or addr.get("village"),
                "lat": float(item["lat"]),
                "lon": float(item["lon"]),
                "source": "Nominatim",
            })
        return out
