# Yobalema V5 — Masterclass Moto

Yobalema est une plateforme de mobilité **100 % MOTO**, conçue d'abord pour toute la région administrative de Kaolack.

## Principes non négociables
- Une seule catégorie de véhicule : `MOTO`.
- Périmètre : toute la région de Kaolack, pas seulement la ville de Kaolack.
- Route et distance : priorité au routage réel OSRM, jamais à la distance à vol d'oiseau pour facturer une course.
- Prix : simples, raisonnables et affichés avant validation.
- Commission : **10 % Yobalema / 90 % chauffeur**, fixe.
- Sécurité : chauffeur vérifié, PIN de prise en charge, suivi temps réel et contrôles backend.
- Paiements : CASH disponible ; Wave et Orange Money restent des intégrations officielles à brancher, sans faux statut payé.

## Architecture
- `backend/yobalema_backend` : Node.js + TypeScript + Express + Prisma + PostgreSQL + Socket.IO.
- `flutter/Yobalema_Kaolack_Updated_White` : client Flutter Passenger/Driver.
- `src/geo.ts` : validation géographique Kaolack par frontière polygonale.
- `src/routing.ts` : service de routage routier OSRM avec timeout et fallback.
- `src/pricing.ts` : tarification locale et partage 10/90.
- `src/prisma.ts` : garde-fous de persistance pour empêcher une catégorie automobile ou un partage de commission incohérent.

## Niveau produit visé
Yobalema doit atteindre les standards de fiabilité d'une plateforme mondiale :

**Passenger** : départ/destination précis, ETA, itinéraire réel, prix upfront, recherche chauffeur, suivi en direct, PIN, sécurité, paiement, historique, notation.

**Driver** : onboarding et vérification, ONLINE/OFFLINE, demandes en temps réel, navigation, revenus, portefeuille, historique, notifications et outils de performance.

**Operations** : support, supervision, statistiques, contrôle des chauffeurs et traçabilité des paiements.

## Tests backend
```bash
npm run build
npm test
```

Les smoke tests couvrent notamment les tarifs locaux, le partage 10/90 et des points intérieurs/extérieurs à Kaolack.

## Production
Avant exploitation commerciale : HTTPS, secrets dédiés, CORS strict, SMS OTP réel, API officielles Wave/Orange Money, push FCM/APNs, PostgreSQL managé + sauvegardes, monitoring, conformité juridique et vérification des documents chauffeurs.
