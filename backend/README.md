# Yobalema V3 — backend production-ready starter

Cette V3 ajoute les briques nécessaires avant une mise en production : OTP téléphone, vérification des chauffeurs, OTP de prise en charge, paiements Wave/Orange Money en mode **adaptateur** (la confirmation est simulée tant que les clés opérateur ne sont pas configurées), notation 1–5, statistiques et Socket.IO authentifié.

## Démarrage
1. Copier `.env.example` vers `.env`.
2. `docker compose up -d`
3. `npm install`
4. `npx prisma generate`
5. `npx prisma migrate dev --name v3`
6. `npm run seed`
7. `npm run dev`

## Paiements
Les endpoints `POST /api/rides/:id/payment/confirm` attendent un `providerRef`. Ils constituent le point d'intégration avec l'API officielle Wave ou Orange Money. Aucun faux paiement n'est présenté comme réel.

## OTP
Pour le développement, les endpoints retournent `devOtp`. En production, supprimer ce champ et brancher un fournisseur SMS.

## Sécurité
Le Socket.IO exige `handshake.auth.userId`; pour une production stricte, remplacer ce mécanisme par un JWT Socket.IO vérifié côté serveur.
