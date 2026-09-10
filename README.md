# Yobalema Flutter

Application Flutter reliée au backend Yobalema V4.

## Entrées officielles
Le projet contient deux applications Flutter distinctes :

- Passager : `lib/main_passenger.dart`
- Chauffeur : `lib/main_driver.dart`

`lib/main.dart` n'existe plus : aucune entrée legacy ne doit être utilisée.

## Lancement local
```bash
flutter pub get
flutter run -t lib/main_passenger.dart --dart-define=YobalemaApiUrl=http://localhost:4000
```

Pour lancer l'application Chauffeur :

```bash
flutter run -t lib/main_driver.dart --dart-define=YobalemaApiUrl=http://localhost:4000
```

Sur téléphone réel, remplacer `localhost` par l'adresse IP du PC, par exemple
`http://192.168.1.20:4000`.

## Builds
```bash
flutter build apk -t lib/main_passenger.dart
flutter build apk -t lib/main_driver.dart
flutter build web -t lib/main_passenger.dart
flutter build web -t lib/main_driver.dart
```

La création de course accepte `CASH`, `WAVE` ou `ORANGE_MONEY` via `YobalemaApi.createRide`.
