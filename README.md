# Party Games

41 party games for 2–6 friends: on one phone, in online rooms, or solo.
Flutter app (`mobile/`) + Node/Socket.IO server (`server/`).

## Develop
    cd server && npm install && npm test && npm start     # guest logins, port 3000
    cd mobile && flutter pub get && flutter test && flutter run   # emulator reaches the PC at 10.0.2.2:3000

## Deploy the server (play online from anywhere)
The server is a small Docker app. On **Render** (free plan available):
1. render.com > sign in with GitHub > **New > Blueprint** > pick this repo (and branch). `render.yaml` sets everything up.
2. When it's live, open `https://<name>.onrender.com/health` → `{"ok":true}`.
3. Check online play end to end: `cd server && npm install && npm run smoke -- https://<name>.onrender.com`

Free plan: the server sleeps after 15 min idle and takes about a minute to wake; the app keeps retrying
and connects by itself. The Starter plan (~$7/month) never sleeps.
Logins are guest names (`ALLOW_DEV_AUTH=true`): fine for friends, not real accounts.

## Build the app for players
    cd mobile
    flutter build apk --release --dart-define=SERVER_URL=https://<name>.onrender.com          # Party Games
    flutter build apk --release --dart-define=SERVER_URL=https://<name>.onrender.com --dart-define=APP_STYLE=flat   # Party Games Flat
    flutter build appbundle --release --dart-define=SERVER_URL=https://<name>.onrender.com    # .aab for the Play Store

App ID: `com.shubhamgupta.partygames` (flat: `com.shubhamgupta.partygames.flat`).
Release builds are signed with `mobile/android/upload-keystore.jks` + `key.properties` (not in git).
**Back both files up**: without them you cannot publish updates. Without them builds fall back to the debug key.
Players can still point the app at another server under Home > **Server**.

## Playing nearby (same Wi-Fi or a phone hotspot)
- **Hotspot phone has mobile data:** everyone just uses the online server. Nothing to set up.
- **No internet at all:** one laptop joins the Wi-Fi/hotspot and runs `cd server && npm start`.
  It prints its address; every phone enters it under Home > **Server** (e.g. `192.168.43.20:3000`).
  Windows may ask to allow Node.js through the firewall: allow it on private networks.
  Some campus/office Wi-Fi blocks phone-to-phone traffic: use a hotspot instead.
- One-device games and solo games need no server at all.

## Without a computer
GitHub > Actions > **Build Android APK** > Run workflow > enter your server URL, then download the
`party-games-apk` artifact and install it (this build uses the debug key).
