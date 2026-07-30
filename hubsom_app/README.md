# Hubsom Flutter (Android · iOS · Web)

Single Flutter codebase that replaces the separate client surfaces for Hubsom while preserving the existing marketplace, live shopping, auctions, seller tools, Hubers dispatch, wallet/payments, messaging, and admin API contracts.

The Next.js app in the repo root remains the API / Auth.js backend. This Flutter client talks to those same REST routes and optionally to Firebase when enabled.

## Stack

- Flutter 3+ / Dart / Material 3
- Riverpod · GoRouter
- Dio · Hive · Cached Network Image
- Firebase Auth / Firestore / Storage / Messaging (optional via dart-define)
- Agora (same live provider as web)
- flutter_map + OpenStreetMap + OpenRouteService / OSRM / GraphHopper (**no Google Maps**)
- Payments: Stripe, Paystack, MTN MoMo, Telecel Cash, AirtelTigo Money, wallet, COD

## Project layout

```
lib/
  core/          config, theme, services, repositories, providers
  models/        shared domain models (ported from Hubsom types)
  features/      screens mirroring Next.js routes
  widgets/       shared UI
  main.dart
```

## Configure

```bash
flutter pub get

flutter run -d chrome \
  --dart-define=HUBSOM_API_BASE_URL=http://localhost:3000 \
  --dart-define=AGORA_APP_ID=your_agora_app_id \
  --dart-define=FIREBASE_ENABLED=false
```

| Define | Purpose |
|--------|---------|
| `HUBSOM_API_BASE_URL` | Hubsom Next.js origin (default `http://localhost:3000`) |
| `HUBSOM_ADMIN_API_KEY` | Admin portal key for promotions/catalog sync |
| `AGORA_APP_ID` | Live streaming |
| `STRIPE_PUBLISHABLE_KEY` / `PAYSTACK_PUBLIC_KEY` | Cards |
| `OPENROUTESERVICE_KEY` | Routing (falls back to public OSRM) |
| `FIREBASE_ENABLED` | `true` to initialize Firebase |

## Run targets

```bash
# Web (hubsom.com marketplace)
flutter run -d chrome --dart-define=HUBSOM_API_BASE_URL=https://hubsom.com

# Android
flutter run -d android

# iOS (macOS)
flutter run -d ios
```

## Feature parity (routes)

| Area | Flutter path | Backend |
|------|----------------|---------|
| Home / marketplace | `/`, `/marketplace` | `/api/products`, `/api/promotions` |
| Categories | `/categories`, `/categories/:slug` | products by category |
| Products / wishlist / reviews | `/products/:id`, `/account/saved` | save + reviews APIs |
| Live / auctions | `/live`, `/live/:id`, `/auctions` | streams, chat, reactions, bids, Agora token |
| Cart / checkout | `/cart`, `/checkout` | `/api/checkout` |
| Messaging | `/messages`, `/messages/:userId` | `/api/messages` |
| Seller hub | `/seller/*` | store, products, orders, shipments, Hubers |
| Delivery map | `/driver/track/:shipmentId` | OSM + ORS/OSRM |
| Account / wallet | `/account/*`, `/wallet` | profile, addresses, wallet |
| Auth | `/auth/sign-in`, `/auth/sign-up` | Auth.js + signup |

Admin Portal continues to use existing `/api/admin/*` endpoints; Flutter sellers/buyers consume the same public APIs.

## Backend note

Do **not** recreate Firestore collections. Keep Cloud Functions and HubsomAdmin as-is. Point Flutter at the running Hubsom API; enable Firebase only when production options are present.

## Build

```bash
flutter analyze
flutter build web --release
flutter build apk --release
flutter build ios --release   # macOS + Xcode
```
