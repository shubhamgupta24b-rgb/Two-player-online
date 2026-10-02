# Multiplayer mini-game platform

## Server (Node.js + Socket.IO)

```bash
cd server
npm install
npm test
npm start
```

Server health check: `GET /health`  
Default local port: `3000`

## Render deployment (recommended: Native Node service from `server/`)

Create a **Web Service** with this configuration:

- **Runtime**: Node
- **Root Directory**: `server`
- **Build Command**: `npm ci`
- **Start Command**: `npm start`
- **Health Check Path**: `/health`

Required/important environment variables:

- `NODE_ENV=production`
- `AUTH_MODE=firebase` (recommended for production)
- `RECONNECT_GRACE_MS=60000` (or your preferred value)
- `FIREBASE_PROJECT_ID=<your-firebase-project-id>`
- One Firebase credential method:
  - `GOOGLE_APPLICATION_CREDENTIALS=<path inside runtime to service-account json>`, or
  - `FIREBASE_SERVICE_ACCOUNT_JSON=<single-line service-account JSON>`
- Optional:
  - `MONGO_URI=<mongodb connection string>` (leave unset to run without Mongo-backed profiles)
  - `ALLOW_DEV_AUTH=true` only for temporary production testing when `AUTH_MODE=dev`

> Safety: `AUTH_MODE=dev` is blocked in production unless `ALLOW_DEV_AUTH=true`.

## Render deployment (alternative: Docker)

If you prefer Docker on Render:

- **Environment**: Docker
- **Docker Context**: `server`
- **Dockerfile Path**: `server/Dockerfile` (or `Dockerfile` with context `server`)
- **Health Check Path**: `/health`
- Use the same environment variables listed above.

## Mobile (Flutter client)

```bash
cd mobile
flutter create --platforms=android --org com.example.partygames .
flutter pub get
flutter run
```

Set the backend URL when running/building the app:

```bash
flutter run --dart-define=SERVER_URL=https://<your-render-service>.onrender.com
```

`mobile/lib/config.dart` reads `SERVER_URL` and falls back to `http://10.0.2.2:3000` for local emulator usage.

## Playing on two phones
Online games (e.g. Guess Who) need both phones to reach the same server. In the app: Home > **Server**.
- **Same Wi-Fi:** run `cd server && npm start` on your PC, then enter `<PC-IP>:3000` (find the IP with `ipconfig`).
  Windows may ask to allow Node.js through the firewall: allow it on private networks.
- **Anywhere:** host the server on Render and enter `https://<name>.onrender.com`.

## Phone-only path (no computer)
1. Deploy `server/` to Render using the settings above.
2. Put this whole project in a GitHub repo.
3. GitHub > Actions > "Build Android APK" > Run workflow > enter your server URL.
4. Download the `party-games-apk` artifact, unzip, open the .apk on your phone and install.
