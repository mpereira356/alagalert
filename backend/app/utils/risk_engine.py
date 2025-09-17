from typing import Dict, List
from statistics import mean

# Pesos (máximo 1.0)
W_RAIN = 0.70  # chuva total 6h
W_WIND = 0.25  # vento médio 6h
W_TEMP = 0.05  # ajuste leve por temperatura

def _normalize(val: float, min_v: float, max_v: float) -> float:
    if max_v <= min_v:
        return 0.0
    x = (val - min_v) / (max_v - min_v)
    return max(0.0, min(1.0, x))

def compute_risk(hourly: List[Dict]) -> Dict:
    """
    hourly: lista de pontos horários: {timestamp, temperature, precipitation, wind_speed}
    Janela de 6h mais recentes (ou primeiras 6h, conforme ordenação da API).
    """
    if not hourly:
        return {
            "risk_score": 0.0,
            "level": "Baixo",
            "message": "Sem dados meteorológicos.",
            "factors": {"precipitation_6h_mm": 0.0, "wind_avg_6h_kmh": 0.0, "temp_avg_6h_c": 0.0},
            "forecast_window": [],
        }

    # Open-Meteo retorna em ordem cronológica. Considera as primeiras 6 leituras (6h).
    window = hourly[:6] if len(hourly) >= 6 else hourly

    rain_6h = sum([(p.get("precipitation") or 0.0) for p in window])
    wind_avg = mean([(p.get("wind_speed") or 0.0) for p in window])
    temp_avg = mean([(p.get("temperature") or 0.0) for p in window])

    # Normalizações simples (ajuste conforme calibração real):
    # - chuva: 0..30 mm em 6h -> 0..1
    # - vento: 0..60 km/h -> 0..1
    # - temp:  10..35 °C -> 0..1 (usada só como ajuste)
    n_rain = _normalize(rain_6h, 0.0, 30.0)
    n_wind = _normalize(wind_avg, 0.0, 60.0)
    n_temp = _normalize(temp_avg, 10.0, 35.0)

    score = (n_rain * W_RAIN) + (n_wind * W_WIND) + (n_temp * W_TEMP)
    score = max(0.0, min(1.0, score))

    if score >= 0.8:
        level, msg = "Crítico", "Risco crítico de alagamento. Evite áreas de risco."
    elif score >= 0.6:
        level, msg = "Alto", "Risco alto. Fique atento a alagamentos."
    elif score >= 0.4:
        level, msg = "Moderado", "Risco moderado nas próximas horas."
    else:
        level, msg = "Baixo", "Risco baixo."

    return {
        "risk_score": round(score, 3),
        "level": level,
        "message": msg,
        "factors": {
            "precipitation_6h_mm": round(rain_6h, 2),
            "wind_avg_6h_kmh": round(wind_avg, 2),
            "temp_avg_6h_c": round(temp_avg, 2),
        },
        "forecast_window": window,
    }
