# Lancement rapide

## Backend
```bash
cd backend/yobalema_backend
docker compose up -d
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run seed
npm run dev
```

## Flutter
```bash
cd flutter/Yobalema_Kaolack_Updated_White
flutter pub get
flutter run --dart-define=YobalemaApiUrl=http://10.0.2.2:4000
```

Sur un téléphone réel, remplace `10.0.2.2` par l'IP locale de la machine qui exécute le backend.
