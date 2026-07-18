# PulangAman Mobile (Phase 1–2)

Flutter app for parent, child, and pre-approved guardian flows.

## Local run (dev auth)

Dev auth uses `Authorization: Bearer dev:<uid>` against the local API (no Firebase project required).

```bash
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:3000 \
  --dart-define=USE_DEV_AUTH=true \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

On iOS simulator / desktop, prefer `http://localhost:3000` and `ws://localhost:3000`.

## Features

- Parent: add children, live map + stale warning, Home/School zones, invite/revoke guardians, panic ack/resolve
- Child: foreground location upload, 3-tap panic, offline queue + SMS compose fallback
- Guardian: accept invites, alert ack, share location, need backup (no stranger dispatch)

## Google Maps (required for live map tiles)

Without a key the parent live map shows coordinates only (beige placeholder).

1. Create a key in [Google Cloud Console](https://console.cloud.google.com/) with **Maps SDK for Android** enabled.
2. Add to `android/local.properties` (do not commit secrets):

```properties
GOOGLE_MAPS_API_KEY=your_android_maps_key
```

3. Full restart (not hot reload):

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:3000 \
  --dart-define=USE_DEV_AUTH=true \
  --dart-define=GOOGLE_MAPS_API_KEY=your_android_maps_key
```

`--dart-define` drives the in-app “key missing” banner; `local.properties` is what the Android Maps SDK actually uses.

## Notes

- Background location hardening (Android Foreground Service / iOS Significant Change) should be validated on devices before field pilots.
