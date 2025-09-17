# AlagAlert – Backend (FastAPI)

API intermediária do sistema **AlagAlert**, responsável por consumir serviços externos
(meteorologia, geocodificação) e calcular o risco de alagamento.

##  Requisitos
- Python 3.7+
- Virtualenv

## ▶ Como rodar
```bash
cd backend
python -m venv .venv
source .venv/bin/activate    # Linux/Mac
.venv\Scripts\activate.ps1   # Windows
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
