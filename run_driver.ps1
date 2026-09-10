Write-Host "🚀 Lancement de Yobalema Chauffeur sur Chrome..." -ForegroundColor Green
Start-Process "http://localhost:3001"
flutter run -d web-server -t lib/main_driver.dart --no-pub --web-port=3001 --web-hostname=127.0.0.1

