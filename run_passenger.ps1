Write-Host "🚀 Lancement de Yobalema Passager sur Chrome..." -ForegroundColor Green
Start-Process "http://localhost:3000"
flutter run -d web-server -t lib/main_passenger.dart --no-pub --web-port=3000 --web-hostname=127.0.0.1

