# Deploy gratis: Render + Neon + Upstash

Panduan hosting PulangAman API tanpa biaya untuk tahap pra-user. Arsitektur
tetap utuh (Express + WebSocket + timer panic + PostGIS + Redis presence).

| Komponen | Layanan gratis | Peran |
|----------|----------------|-------|
| API Express | Render (Free web service) | Proses long-lived, WS, timer panic |
| Postgres + PostGIS | Neon (Free) | Data utama + geofence |
| Redis | Upstash (Free) | Presence / last location (TTL) |
| Auth + Push | Firebase (Spark/Free) | OTP + FCM (opsional dulu) |

> Catatan free tier: Render Free tidur setelah ~15 menit idle dan bangun
> ~30-50 detik saat request pertama. Cukup untuk demo/uji, bukan SLA produksi.

## 1. Postgres + PostGIS (Neon)

1. Buat project di [neon.tech](https://neon.tech).
2. Buka SQL editor, aktifkan PostGIS:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```
3. Ambil connection string, pastikan diakhiri `?sslmode=require`, contoh:
   ```
   postgres://USER:PASSWORD@ep-xxx.aws.neon.tech/pulangaman?sslmode=require
   ```
   Ini menjadi `DATABASE_URL`.

## 2. Redis (Upstash)

1. Buat database Redis di [upstash.com](https://upstash.com).
2. Salin URL yang berformat TLS (`rediss://...`). ioredis mengaktifkan TLS
   otomatis dari skema `rediss://`.
   Ini menjadi `REDIS_URL`.

## 3. API (Render)

### Opsi A - Blueprint (disarankan)
1. Push repo ini ke GitHub (sudah).
2. Di Render: New > Blueprint, pilih repo. Render membaca `render.yaml`.
3. Isi env var yang `sync: false`: `DATABASE_URL`, `REDIS_URL`,
   `FIREBASE_PROJECT_ID` (boleh kosong dulu), `GOOGLE_MAPS_API_KEY` (opsional).
4. Deploy. Migrasi berjalan otomatis via `startCommand`
   (`npm run migrate && node dist/index.js`).

### Opsi B - Manual
- New > Web Service, pilih repo.
- Root Directory: `services/api`
- Build: `npm ci && npm run build`
- Start: `npm run migrate && node dist/index.js`
- Health Check Path: `/health`
- Tambahkan env var yang sama seperti di `render.yaml`.

## 4. Verifikasi

```bash
curl https://<nama-service>.onrender.com/health
```
Harapkan `"ok": true`, `"database": true`, `"redis": true`.

## 5. Hubungkan mobile app

Jalankan Flutter dengan base URL produksi (bukan `10.0.2.2`):
```bash
flutter run \
  --dart-define=API_BASE_URL=https://<nama-service>.onrender.com \
  --dart-define=WS_BASE_URL=wss://<nama-service>.onrender.com \
  --dart-define=USE_DEV_AUTH=true
```
Catatan: gunakan `wss://` (bukan `ws://`) karena Render menyajikan HTTPS.

## Catatan biaya & batasan

- Semua langkah di atas Rp 0 untuk volume kecil / demo.
- Render Free sleep saat idle; kalau butuh selalu-on gratis, alternatif Koyeb.
- Firebase belum wajib: tanpa `FIREBASE_PROJECT_ID`, auth memakai stub dev
  (`Authorization: Bearer dev:<uid>`). Untuk publik, konfigurasikan Firebase.
- Vercel tidak dipakai untuk API ini: serverless memutus WebSocket dan timer
  panic in-memory. Vercel hanya cocok bila nanti ada web admin (Next.js) terpisah.
