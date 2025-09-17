# backend/tools/add_cities.py
import csv, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IBGE_DIR = ROOT / "data" / "ibge"
MUN_JSON = IBGE_DIR / "municipios.json"
MUN_GEOJSON = IBGE_DIR / "municipios.geojson"

def load_json(path: Path):
    if not path.exists():
        return None
    # aceita arquivos salvos com BOM
    return json.loads(path.read_text(encoding="utf-8-sig"))

def ensure_files():
    IBGE_DIR.mkdir(parents=True, exist_ok=True)
    if not MUN_JSON.exists():
        MUN_JSON.write_text("[]", encoding="utf-8")
    if not MUN_GEOJSON.exists():
        MUN_GEOJSON.write_text(json.dumps({"type":"FeatureCollection","features":[]}, ensure_ascii=False, indent=2), encoding="utf-8")

def add_city(uf: str, nome: str, lat: float, lon: float, box: float = 0.15):
    # atualiza municipios.json
    mun = load_json(MUN_JSON) or []
    if not any(m.get("uf")==uf and str(m.get("nome","")).lower()==nome.lower() for m in mun):
        mun.append({"uf": uf, "nome": nome, "centroid": {"lat": lat, "lon": lon}})
        MUN_JSON.write_text(json.dumps(mun, ensure_ascii=False, indent=2), encoding="utf-8")

    # adiciona polígono retangular em municipios.geojson
    gj = load_json(MUN_GEOJSON) or {"type":"FeatureCollection","features":[]}
    coords = [
        [lon - box, lat + box],
        [lon - box, lat - box],
        [lon + box, lat - box],
        [lon + box, lat + box],
        [lon - box, lat + box],
    ]
    gj["features"].append({
        "type": "Feature",
        "properties": {"nome": nome, "UF": uf},
        "geometry": {"type": "Polygon", "coordinates": [coords]},
    })
    MUN_GEOJSON.write_text(json.dumps(gj, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"OK: {nome}/{uf} adicionado.")

def main():
    if len(sys.argv) < 2:
        print("Uso: python tools/add_cities.py tools/cities.csv")
        print("CSV esperado: uf,nome,lat,lon")
        sys.exit(1)
    ensure_files()
    # lê CSV aceitando BOM
    with open(sys.argv[1], newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            uf = row["uf"].strip()
            nome = row["nome"].strip()
            lat = float(row["lat"])
            lon = float(row["lon"])
            add_city(uf, nome, lat, lon)

if __name__ == "__main__":
    main()
