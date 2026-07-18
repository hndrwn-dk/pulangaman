# PulangAman

Community safety network for parents and children (Indonesia).

## Docs

- [Product & architecture plan](docs/planpulangaman.md)
- [Premium UX + differentiators plan](docs/premium-ux-plan.md)
- [Free deploy guide (Render + Neon + Upstash)](docs/deploy-free.md)

## Monorepo layout

| Path | Purpose |
|------|---------|
| `apps/mobile` | Flutter app (Android & iOS) |
| `services/api` | Node.js 20 + Express API |
| `services/api/public/school-admin` | Phase 3 light school admin web |
| `docker-compose.yml` | Local Postgres (PostGIS) + Redis |
| `docs/` | Architecture and product docs |

## Prerequisites

- Node.js 20+
- Flutter 3.x
- Docker (for local Postgres + Redis)

## Quick start

```bash
# Infrastructure
docker compose up -d

# API
cd services/api
cp .env.example .env
npm install
npm run migrate
npm run dev

# Mobile (another terminal)
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:3000 \
  --dart-define=USE_DEV_AUTH=true
```

API health: `http://localhost:3000/health`  
School admin UI: `http://localhost:3000/school-admin/`  
Local auth stub (no Firebase): `Authorization: Bearer dev:<firebaseUid>`

## Phase status

- **Phase 0–2:** foundation, parent–child tracking/panic/geofences, pre-approved guardians
- **Phase 3:** school admin light (roster, panic contact, geofence attendance signal), community report pins (72h expiry), safe route v1 (Directions optional + report avoidance)
- **Phase 3.5 differentiators:** playful premium UI, durable school attendance ledger, rewards/streaks, Android screen-time monitoring + Accessibility soft-blocking
- **Phase 4:** explicitly deferred (BLE mesh, stealth panic, WebRTC, TFLite/ML, Mapbox, Firestore, public stranger dispatch, etc.)

## Safety notes

- Guardians are invite-only for a specific child — no public stranger dispatch
- SMS/FCM/Maps Directions use stubs or optional keys until credentials are configured
- Google Maps tiles/Directions are optional for local dev; coordinates and straight-line/detour routing still work
- Set `KILL_SWITCH_GUARDIAN_NOTIFY=true` or `KILL_SWITCH_LOCATION_SHARE=true` to disable those paths
- Screen-time blocking is Android-only; PulangAman/phone/messages remain emergency-allowlisted
- Set `KILL_SWITCH_POLICY_ENFORCE=true` to disable published policy enforcement
