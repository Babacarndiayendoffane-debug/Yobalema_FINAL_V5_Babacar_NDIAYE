@echo off
echo ========================================================
echo  Lancement de Yobalema Chauffeur (Chrome Direct)
echo ========================================================
flutter run -d chrome -t lib/main_driver.dart --web-port=3001 --web-hostname=127.0.0.1
