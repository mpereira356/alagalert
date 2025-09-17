import json
from pathlib import Path
from typing import Optional

DATA_DIR = Path(__file__).resolve().parents[2] / "data" / "ibge"

def _read_json(path: Path):
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))

def load_regions_geojson(level: str, uf: Optional[str] = None):
    """
    level=state  -> lê uf.json (FeatureCollection de UFs)
    level=city   -> lê municipios.geojson (FeatureCollection) e filtra por UF (se fornecido)
    """
    if level == "state":
        return _read_json(DATA_DIR / "uf.json")

    if level == "city":
        gj = _read_json(DATA_DIR / "municipios.geojson")
        if gj is None:
            return None
        if uf:
            feats = []
            for f in gj.get("features", []):
                props = f.get("properties") or {}
                # tenta várias chaves comuns de UF em bases do IBGE
                sigla = (props.get("UF") or props.get("uf") or props.get("SIGLA") or props.get("sigla") or "").upper()
                if sigla == uf.upper():
                    feats.append(f)
            return {"type": "FeatureCollection", "features": feats}
        return gj

    return None
