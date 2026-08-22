# Yobalema Flutter

Application Flutter reliée au backend Yobalema V4.

## Lancement

```bash
flutter pub get
flutter run --dart-define=YobalemaApiUrl=http://10.0.2.2:4000
```

Sur téléphone réel, utiliser `http://IP_DU_PC:4000`.

La création de course accepte `CASH`, `WAVE` ou `ORANGE_MONEY` via `YobalemaApi.createRide`.
