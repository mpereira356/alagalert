# AlagAlert – Mobile (Flutter)

Aplicativo em Flutter que consome a API do **AlagAlert** e apresenta ao usuário
o risco de alagamentos em cidades brasileiras.

#  Requisitos
- Flutter SDK (stable)
- Android Studio / Emulador / Chrome

# Como rodar (dev)
```bash
cd mobile
flutter clean
flutter pub get

# Web
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000

# Android 
flutter run --dart-define=API_URL=http://10.0.2.2:8000