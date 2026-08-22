# Yobalema — édition finale V4

Yobalema est une plateforme de mobilité pensée pour la région de Kaolack : passager, chauffeur, matching GPS, course en temps réel, paiement, notation, support et supervision administrateur.

## Contenu
- `backend/yobalema_backend` : Node.js + TypeScript + Express + Prisma + PostgreSQL + Socket.IO
- `flutter/Yobalema_Kaolack_Updated_White` : application Flutter reliée à l'API

## V4 — ce qui est finalisé
- Authentification JWT + OTP
- Limitation des requêtes d'authentification
- Chauffeurs vérifiés + véhicule obligatoire avant passage en ligne
- Matching du chauffeur le plus proche
- Devis serveur et plafond 5 000 FCFA
- Course : demande → acceptation → arrivée → OTP de prise en charge → trajet → terminée/annulée
- GPS temps réel via Socket.IO avec authentification JWT du socket
- Historique des courses
- Paiement espèces / adaptateurs Wave et Orange Money
- Portefeuille chauffeur et écritures de gains
- Notifications persistées
- Tickets support passager/chauffeur + traitement admin
- Notes 1–5 étoiles
- Dashboard administrateur : statistiques, chauffeurs, support
- Docker pour PostgreSQL

## Démarrage backend
1. Installer Node.js 20+ et Docker.
2. Copier `.env.example` vers `.env` et modifier `JWT_SECRET`.
3. `docker compose up -d`
4. `npm install`
5. `npx prisma generate`
6. `npx prisma migrate dev --name init`
7. `npm run seed`
8. `npm run dev`

API : `http://localhost:4000`  
Admin : `http://localhost:4000/admin/`  
Health : `http://localhost:4000/health`

## Flutter
Depuis le dossier Flutter :
`flutter pub get`

Émulateur Android :
`flutter run --dart-define=YobalemaApiUrl=http://10.0.2.2:4000`

Téléphone physique : remplacer l'URL par l'adresse IP locale du PC.

## Compte démo
Le seed crée un chauffeur de démonstration. Les identifiants exacts sont indiqués dans `backend/yobalema_backend/prisma/seed.ts`.

## Passage en production
Les points qui doivent être branchés avec les fournisseurs réels avant exploitation commerciale sont :
- fournisseur SMS pour l'OTP ;
- API officielle Wave ;
- API officielle Orange Money ;
- notifications push FCM/APNs ;
- secrets JWT et CORS stricts ;
- HTTPS ;
- sauvegardes PostgreSQL et supervision ;
- vérification juridique/commerciale des tarifs et documents chauffeurs.

Aucune transaction Wave/Orange Money n'est simulée comme payée : les adaptateurs V4 retournent explicitement `integrationRequired=true` tant que les credentials et webhooks officiels ne sont pas configurés.

## Déploiement rapide
Voir `DEPLOYMENT.md`. Le backend peut être lancé avec Docker Compose.
