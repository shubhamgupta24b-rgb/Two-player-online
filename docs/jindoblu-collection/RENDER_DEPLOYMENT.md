# Render deployment (separate backend)

This repository keeps the Flutter app and the Node.js/Socket.IO backend in one repository, but Render runs the backend as a **separate web service**. The APK is built separately by GitHub Actions.

## Deploy the backend

1. Push/merge the desired branch to GitHub. The current working branch is `feature/jindoblu-collection`.
2. Sign in to Render and choose **New → Blueprint**.
3. Select this repository and the branch to deploy. Render reads the root-level `render.yaml`.
4. Review the service named `two-player-online`. Its Docker context is `server/`, its health check is `/health`, and the initial setup asks for `PRIVACY_CONTACT`.
5. Create the service and wait for the deploy to finish.
6. Open `https://<your-service>.onrender.com/health`. A healthy response looks like `{"ok":true,"app":"party-games"}`.
7. Open `https://<your-service>.onrender.com/privacy` and check that the privacy-policy page loads.

## Initial free test deployment — important

The Blueprint sets `AUTH_MODE=dev` and `ALLOW_DEV_AUTH=true` to allow a first test with friends without Firebase credentials. **This is a temporary test configuration only.** Dev auth allows a client to claim an identity; do not use this public service for real accounts, private rooms, sensitive data, or a production Play Store release. Before public launch, configure Firebase authentication and set `AUTH_MODE=firebase`, then remove `ALLOW_DEV_AUTH` (or set it to `false`).

The server currently stores room state in memory. A restart or free-service sleep can interrupt rooms; this is acceptable for a first smoke test, not durable matchmaking. Persistent room state / scaling should be a later phase.

## Point an APK at Render

The mobile build accepts the Dart define `SERVER_URL`. For a Render build, use the exact HTTPS origin from your Render dashboard, for example:

```bash
cd mobile
flutter pub get
flutter build apk --release --dart-define=SERVER_URL=https://YOUR-SERVICE.onrender.com
```

Do not include `/health` or a trailing Socket.IO path in the base URL. The app's manual server setting can still be used for local/LAN testing. A Render URL must use HTTPS; Socket.IO negotiates the appropriate secure transport.

The GitHub Actions build currently defaults to the Android-emulator local server URL for a local/LAN smoke-test APK. Set the repository Actions variable `SERVER_URL` to the Render origin to make the workflow produce a Render-targeted APK.

## Smoke-test checklist

- [ ] `/health` returns HTTP 200 and `ok: true`.
- [ ] `/privacy` loads and contains the configured contact.
- [ ] Two separate devices install the same Render-targeted APK.
- [ ] Both devices use the same Render service URL.
- [ ] Create a room, join from the second device, start a supported game, exchange actions, and verify both clients update.
- [ ] Test disconnect/reconnect and record the expected behavior when the free service sleeps or restarts.
- [ ] Confirm local same-device and LAN play still work independently.

A successful deploy and health check do not, by themselves, prove that live two-device multiplayer works; that requires the device smoke test above.
