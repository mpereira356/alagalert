from pydantic import BaseModel, Field
from typing import List, Literal, Optional, Dict, Any

class GeoCodeResult(BaseModel):
    name: str
    uf: str
    city: str
    lat: float
    lon: float
    source: Literal["ibge", "nominatim"]

class WeatherPoint(BaseModel):
    timestamp: str
    temperature: float | None = None
    precipitation: float | None = None
    wind_speed: float | None = None

class RiskFactors(BaseModel):
    precipitation_6h_mm: float
    wind_avg_6h_kmh: float
    temp_avg_6h_c: float

class RiskResult(BaseModel):
    risk_score: float = Field(ge=0, le=1)
    level: Literal["Baixo","Moderado","Alto","Crítico"]
    message: str
    factors: RiskFactors
    forecast_window: List[WeatherPoint]
    location: Optional[Dict[str, Any]] = None  # {uf, city, lat, lon}

# Regions
class RegionsQuery(BaseModel):
    level: Literal["state","city"]
    uf: Optional[str] = None
