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
