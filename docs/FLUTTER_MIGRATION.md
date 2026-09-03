# Hubsom Flutter migration

The production client for Android, iOS, and Web lives in [`hubsom_app/`](../hubsom_app/).

## Goals

- **One codebase** for Android, iOS, and Web (no separate Kotlin / Swift / web SPA clients to maintain).
- **Preserve** every Hubsom feature, workflow, business rule, and screen from the existing product.
- **Reuse** the existing Firebase + Hubsom Next.js API / Cloud Functions / Admin Portal — do not recreate Firestore or break admin APIs.

## Architecture

| Layer | Location |
|-------|----------|
| Presentation | `hubsom_app/lib/features/**` |
| State | Riverpod (`core/providers`) |
| Repositories | `core/repositories` |
| Services | Dio API, Agora, maps, payments, Hive, notifications |
| Models | Ported from `src/types` |

Maps use **flutter_map + OpenStreetMap** with OpenRouteService / OSRM / GraphHopper (not Google Maps). Live uses **Agora** (same as web).

## Running alongside Next.js

1. Start Hubsom API: `npm run dev` (port 3000).
2. Run Flutter:  
   `cd hubsom_app && flutter run -d chrome --dart-define=HUBSOM_API_BASE_URL=http://localhost:3000`

See [`hubsom_app/README.md`](../hubsom_app/README.md) for dart-defines and build targets.
