# PulangAman

Community safety network for parents and children (Indonesia).

## Docs

- [Product & architecture plan](docs/planpulangaman.md)

## Monorepo layout

| Path | Purpose |
|------|---------|
| `apps/mobile` | Flutter app (Android & iOS) |
| `services/api` | Node.js 20 + Express API |
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
Local auth stub (no Firebase): `Authorization: Bearer dev:<firebaseUid>`

## Phase status

- **Phase 0:** foundation scaffold — schema, Docker, Flutter shell
- **Phase 1 (implemented):** parent–child session, live location + WS, geofence enter/exit with debounce, panic cascade (FCM stub + SMS console/http), offline queue, 7-day location purge, stale-location warning
- **Phase 2 (implemented):** pre-approved guardian invite/accept/revoke, distance-ranked guardian notify on panic escalate, guardian ack / share location / need backup, kill switches

## Safety notes

- Guardians are invite-only for a specific child — no public stranger dispatch
- SMS/FCM use console stubs until Firebase Messaging + Indonesian SMS provider credentials are configured
- Set `KILL_SWITCH_GUARDIAN_NOTIFY=true` or `KILL_SWITCH_LOCATION_SHARE=true` to disable those paths regionally
