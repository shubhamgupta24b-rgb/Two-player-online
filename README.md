# Multiplayer mini-game platform

## Server (Phase 1 + Guess the Person done, 9 tests)
    cd server && npm install && npm test && npm start     # dev auth mode, port 3000

## Mobile (Phase 1 client, needs first build on your machine)
    cd mobile
    flutter create --platforms=android --org com.example.partygames .   # generates android/ (keeps lib/ and pubspec.yaml)
    flutter pub get
    # emulator:
    flutter run
    # physical devices (same Wi-Fi as your PC, server running):
    flutter run --dart-define=SERVER_URL=http://<PC-LAN-IP>:3000

The Android debug manifest already allows INTERNET and cleartext HTTP is fine for debug builds.
For release builds you must add `<uses-permission android:name="android.permission.INTERNET"/>` and use HTTPS/WSS.

## Playing on two phones
Online games (e.g. Guess Who) need both phones to reach the same server. In the app: Home > **Server**.
- **Same Wi-Fi:** run `cd server && npm start` on your PC, then enter `<PC-IP>:3000` (find the IP with `ipconfig`).
  Windows may ask to allow Node.js through the firewall: allow it on private networks.
- **Anywhere:** host the server (see `render.yaml`: Render > New > Blueprint > this repo) and enter `https://<name>.onrender.com`.

## Phone-only path (no computer)
1. Deploy `server/` (Dockerfile) to a host such as Render as a Web Service. Set env: `AUTH_MODE=dev`, `ALLOW_DEV_AUTH=true` (temporary test only).
2. Put this whole project in a GitHub repo.
3. GitHub > Actions > "Build Android APK" > Run workflow > enter your server URL.
4. Download the `party-games-apk` artifact, unzip, open the .apk on your phone and install.
