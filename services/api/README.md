# PulangAman API

Phase 0 Node.js + Express foundation.

## Setup

```bash
cp .env.example .env
# Start Postgres + Redis (from repo root)
docker compose up -d
npm install
npm run migrate
npm run dev
```

Health: `GET /health`  
WebSocket: `ws://localhost:3000/ws?token=<firebase-or-dev-token>`

Local auth stub (no Firebase): use `Authorization: Bearer dev:<firebaseUid>`.
