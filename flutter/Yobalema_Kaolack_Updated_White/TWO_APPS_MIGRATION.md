# Yobalema Two-App Architecture

Yobalema is now migrating from one dual-role mobile application to two dedicated applications connected to the same backend.

## Applications

### Yobalema Passenger
- Passenger authentication
- Request a motorcycle ride
- Quote and price confirmation
- Driver tracking
- OTP pickup confirmation
- Cash, Wave and Orange Money payment flows
- Ride history and ratings

Entry point:

`flutter run -t lib/main_passenger.dart`

### Yobalema Driver
- Driver authentication and profile
- Motorcycle-only availability
- Online/offline status
- Real-time ride offers
- Navigation and trip lifecycle
- Earnings and wallet
- Ratings and history

Entry point:

`flutter run -t lib/main_driver.dart`

## Shared backend rules

Both applications use the existing Yobalema backend and must preserve these business rules:

1. Service area: Kaolack administrative region only.
2. Vehicle type: motorcycle only.
3. Platform commission: fixed at 10 percent.
4. Driver share: 90 percent.
5. Backend remains the source of truth for pricing, ride state, payment state and authorization.

## Migration plan

The new entry points are the first separation boundary. Existing passenger and driver features from `lib/main.dart` must next be moved into role-specific feature folders without duplicating API contracts.

Target structure:

```
lib/
  core/
    api/
    auth/
    config/
  passenger/
    auth/
    rides/
    tracking/
    payments/
  driver/
    auth/
    availability/
    offers/
    navigation/
    earnings/
  main_passenger.dart
  main_driver.dart
```

The legacy `main.dart` remains untouched during this first migration step to avoid breaking the currently working application while the two dedicated apps are completed.
