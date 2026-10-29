# Nitro Knockout — deployment & environment guide

Nitro Knockout is the original React/Three.js/**Rapier (WebAssembly)** 3D kart-combat game
replacing Smash Karts in this app. It runs in a WebView on every phone; the room host's
WebView is the authoritative simulation and the game server relays and validates all traffic.

## What runs where

| Piece | Where | Notes |
|---|---|---|
| WASM game build (`index.html` + one JS bundle + CSS) | `mobile/assets/nitro/` | Rapier's WASM ships **base64-inlined** in the JS bundle, so nothing is fetched at runtime. Loaded with `loadFlutterAsset('assets/nitro/index.html')` → served from `https://appassets.androidplatform.net/assets/...`, which keeps module scripts and WebGL working offline. |
| Flutter WebView host | `mobile/lib/features/local_games/nitro_knockout/` | `nitro_game_view.dart` (bridge), `nitro_knockout_game.dart` (offline catalog entry), `nitro_online_screen.dart` (online host/guest screen). |
| Game server module | `server/src/games/nitro_knockout.js` | Registered in `server/src/games/registry.js`. Validates every snapshot/input/score. |
| Rooms (codes, lobby, ready, rematch, reconnect) | `server/src/rooms/RoomManager.js` | Room sizes now 2–10 (`maxPlayers`). |

## Offline mode (no network, no account)

From **Local games → Nitro Knockout**: the WebView boots with `mode: 'offline'` and the
engine spawns **8 karts — you plus the 7 built-in AI drivers (NOVA, BOLT, ROOK, JINX, MISO,
APEX, ECHO)** who drive, navigate, fight, grab weapons and score. Nothing else is required.

## Online mode (2–10 human players)

1. Deploy the game server (below) and point the app at it (Home → Server, or the
   `SERVER_URL` dart-define the APK workflow injects).
2. Create a room, pick any size 2–10, choose **Nitro Knockout**, share the room code.
3. Everyone readies up; the host taps PLAY in the game to start all seats at once.
4. The host publishes ~12 snapshots/s (`nitro:state`); guests stream inputs (`nitro:input`)
   and render the host's frames with interpolation. The server validates host-only
   publishing, snapshot structure/bounds, input ranges and final scores.
5. Results, rematch (`PLAY AGAIN`), leaving, and reconnects (60 s grace) all run through
   the existing room lifecycle. If the host drops mid-match, the server migrates the host
   and the new host's phone re-boots its WebView as the simulation owner.

## Deploying the game server

```bash
cd server
npm ci
npm test                       # 96 tests, including the nitro suite
node src/index.js              # listens on :3000 (see src/config.js)
```

The repo also ships `render.yaml` — the same Render deploy used for the other games hosts
Nitro Knockout automatically (the module registers itself through `games/registry.js`).
Set the usual environment (Firebase admin credentials for auth, Mongo URI for records);
none of the nitro code needs extra keys — nothing was added to the client bundle.

Environment variables are documented in `server/src/config.js`; secrets stay server-side.

## Rebuilding the WASM bundle

Only needed if the game source changes (`app/` in the source ZIP):

```bash
cd app && npm ci && npm run build     # dist/ → copy to mobile/assets/nitro/
cd app && npm run verify              # Playwright self-check: render/enter/direction/pause
```

Then copy `dist/*` into `mobile/assets/nitro/` (keep the `assets/` subfolder layout) and
rebuild the app. No other Flutter changes are needed.

**Bridge fix that must also be in the source.** The shipped bundle is patched by hand in
the boot function (`MK` in the minified file; the boot-options parser in `net.ts`). The
channel is now created for every mode, offline included, and it calls `postMessage`:

```js
// before: offline had no channel (its `result` never reached Flutter), and
// webview_flutter channels only have postMessage, so `.post` dropped every message
channel: mode === 'offline' ? undefined : { post: m => window.NitroBridge?.post(m) }
// after
channel: { post: m => window.NitroBridge?.postMessage(m) }
```

Make the same change in the game source before rebuilding, or online play and offline
results break again. Snapshots stay host-only and inputs guest-only (the engine checks
`net`), so offline only ever posts `result`.

## Building the APK

```bash
cd mobile
flutter pub get
flutter analyze                 # clean
flutter test                    # unit + widget tests
flutter build apk --release --dart-define=SERVER_URL=https://<your-server>
```

Or run the repo's **Build Android APK** workflow (Actions → Build Android APK → set the
server URL); it pins the latest stable Flutter, generates the Android project, injects the
INTERNET permission and uploads `app-release.apk`.
