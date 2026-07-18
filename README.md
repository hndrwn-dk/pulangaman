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
flutter run
```

API health: `http://localhost:3000/health`  
Local auth stub (no Firebase): `Authorization: Bearer dev:<firebaseUid>`

## Phase status

- **Phase 0 (this branch):** foundation scaffold — API routes, schema migrations, Flutter shell
- **Phase 1:** parent–child tracking, geofences, normal panic + SMS
