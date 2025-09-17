from typing import Dict, List
import os
import httpx

OPEN_METEO_URL = os.getenv("OPEN_METEO_URL", "https://api.open-meteo.com/v1/forecast")

async def fetch_hourly_forecast(lat: float, lon: float) -> List[Dict]:
    """
    Retorna lista de pontos horários:
      [{"timestamp", "temperature", "precipitation", "wind_speed"}, ...]
    """
    params = {
        "latitude": lat,
        "longitude": lon,
        "hourly": "temperature_2m,precipitation,wind_speed_10m",
        "forecast_days": 1,
        "timezone": "auto",
    }
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(OPEN_METEO_URL, params=params)
        r.raise_for_status()
        j = r.json()
        h = j.get("hourly", {})
        times = h.get("time", []) or []
        temps = h.get("temperature_2m", []) or []
        precs = h.get("precipitation", []) or []
        winds = h.get("wind_speed_10m", []) or []
        out = []
        for i in range(min(len(times), len(temps), len(precs), len(winds))):
            out.append({
                "timestamp": times[i],
                "temperature": float(temps[i]) if temps[i] is not None else None,
                "precipitation": float(precs[i]) if precs[i] is not None else None,
                "wind_speed": float(winds[i]) if winds[i] is not None else None,
            })
        return out
