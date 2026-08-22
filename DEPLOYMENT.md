# Yobalema — mise en service

## 1. Démo locale

Depuis `backend/yobalema_backend` :

```bash
cp .env.example .env
docker compose up --build
```

API : http://localhost:4000/health
Admin : http://localhost:4000/admin/

Comptes seed :
- Chauffeur : +221770000001 / Yobalema123!
- Passager : +221770000002 / Yobalema123!
- Admin : +221770000003 / YobalemaAdmin123!

## 2. Paiement électronique

Le serveur ne marque jamais un paiement Wave/Orange Money comme payé sans confirmation.
Le fournisseur doit appeler :

`POST /api/payments/webhook/WAVE` ou `POST /api/payments/webhook/ORANGE_MONEY`

avec le corps JSON `{ rideId, providerRef, status }` et l'en-tête `X-Yobalema-Signature`, calculé en HMAC-SHA256 avec `PAYMENT_WEBHOOK_SECRET`.

## 3. OTP

En développement, `OTP_DEV=true` renvoie `devOtp` dans la réponse pour tester sans SMS. En production, remplacer cette partie par le fournisseur SMS choisi et mettre `OTP_DEV=false`.

## 4. Production

- PostgreSQL managé + sauvegardes
- HTTPS / reverse proxy
- JWT_SECRET et PAYMENT_WEBHOOK_SECRET aléatoires
- CORS limité au domaine réel
- SMS OTP réel
- credentials et webhooks officiels Wave/Orange Money
- FCM/APNs pour les push
- monitoring et logs
- conformité juridique et protection des données
