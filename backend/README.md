# AlagAlert – Backend


## ▶️ Como rodar (Windows/macOS/Linux)

# dentro de backend/
python -m venv .venv
# macOS/Linux
source .venv/bin/activate
# Windows PowerShell
# .\.venv\Scripts\Activate.ps1

pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000