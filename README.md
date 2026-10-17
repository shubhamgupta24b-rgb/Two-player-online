# RivalRooms

Two-player and party games on one phone, in an online room, or solo. The Flutter app is `mobile/`. The Node and Socket.IO server is `server/`. The Android application id is `com.shubhamgupta.partygames` (flat builds use `com.shubhamgupta.partygames.flat`).

The home screen lists every game in `listedGames()` (`mobile/lib/features/local_games/local_games_hub_screen.dart`). Online rooms use `gameCatalog` in `mobile/lib/games/game_catalog.dart`. Guess the Person and Raja Mantri have their own screens. Ludo 2 vs 2 is the team variant of Ludo.

## Develop

```
cd server && npm install && npm test && npm start
cd mobile && flutter pub get && flutter test && flutter run
```

The server listens on port 3000. An Android emulator reaches the computer at `10.0.2.2:3000`, which is the default `SERVER_URL` in `mobile/lib/config.dart`. Guest logins are on when `ALLOW_DEV_AUTH=true`.

## Home screen

The lamp at the top of the home screen switches the dark and light palettes from the home preview. Dark is the default. The choice is saved on the phone as `set_home_light` and is also in Settings as Light theme. Trending, All Games, the profile menu, Settings, Profile, the leaderboard page chrome, and the Online / Wi-Fi sheets follow that choice. Reduced motion skips the lamp swing. Game paintings are unchanged.

The headings “PICK YOUR NEXT MATCH” and “Quick to pick up. Hard to put down.” are not on the home screen.

Trending shows the game cards, then Online / Wi-Fi and Offline, then the top-3 leaderboard. All Games shows the search field, the category and player filters, and the full hub list. The mode buttons and the leaderboard are not on All Games.

From 340dp wide, both grids are 3 columns, so each full pair of rows is six cards. Below 340dp the grid drops to 2 columns. At 900dp and wider the games hub uses 6 columns. The last row can be short.

Tapping a card opens that game on this phone. The header search icon switches to All Games and focuses the search field.

The profile avatar opens Profile, Settings, and Privacy Policy. The dot is green when the socket is connected, amber while a connect attempt from this screen is in progress, and grey when it is not connected. It is not an account-presence light.

Online / Wi-Fi opens two real paths. Same host is the existing hotspot flow: host on this phone, or join a friend on the same Wi-Fi. Online is the existing internet flow: Create room, Join room, and Quick play. Offline lists the games in `listedGames()`, which all open on this phone. It does not list online catalog ids that have no local screen.

Profile edits the name and colour already stored on the phone, and opens My records. Settings keeps music, sound effects, vibration, and reduce motion, and shows the app version from `mobile/pubspec.yaml` (`0.1.0+1`). There is no notification setting. Privacy Policy opens the existing privacy screen.

Trending uses the server `online_counts` list, highest live player count first, and only games that exist in the app. If nobody is in a room, it shows Memory, Smash Karts, Ludo, and Air Hockey, with no made-up counts.

The leaderboard on Trending is the same data as the full leaderboard: server wins when the server has any, otherwise wins saved on the phone. It does not show sample players.

## Game previews

Each game id has a flat painted preview in `mobile/lib/features/home/game_preview.dart`. `gamePreviewManifest` maps the id to a one-line description of the scene. Cards, the games hub, and room tiles use that painting. There is no remote image request. An unknown id draws an empty frame instead of a broken image.

## Multiplayer

Rooms are 6-letter codes over Socket.IO. The host's phone runs relay games. Memory card counts 8, 12, 16, 20, 24, 28, and 32 are chosen when the room is created and checked on the server (`server/src/rooms/RoomManager.js`). Online Memory rooms stay capped at 4 players.

`cd server && npm test` covers the server. `cd mobile && flutter test` covers the app. `mobile/test/home_redesign_test.dart` checks the six-card column rule and that every listed game has a preview.

## Deploy the server

The server is a small Docker app. On Render:

1. render.com, sign in with GitHub, New, Blueprint, pick this repo and branch. `render.yaml` sets the service up.
2. Open `https://<name>.onrender.com/health` and expect `{"ok":true}`.
3. `cd server && npm install && npm run smoke -- https://<name>.onrender.com`

On the free plan the server sleeps after 15 minutes idle and can take about a minute to wake. The app keeps retrying. Guest names are not real accounts.

## Build the app

```
cd mobile
flutter build apk --release --dart-define=SERVER_URL=https://<name>.onrender.com
flutter build apk --release --dart-define=SERVER_URL=https://<name>.onrender.com --dart-define=APP_STYLE=flat
flutter build appbundle --release --dart-define=SERVER_URL=https://<name>.onrender.com
```

Release builds sign with `mobile/android/upload-keystore.jks` and `key.properties`. Those files are not in git. Without them the build falls back to the debug key, and you cannot publish an update over a store build that used the upload key. Keep both files backed up.

On 2026-10-17, `flutter build apk --release` from `mobile/` with no `SERVER_URL` override produced `mobile/build/app/outputs/flutter-apk/app-release.apk` (59.2 MB). That binary keeps the default address `http://10.0.2.2:3000`. The upload keystore was present for that build. The APK is not committed.

Nearby play with no internet: one phone taps Online / Wi-Fi, then Same host, and turns on a hotspot. Friends join that hotspot, tap Online / Wi-Fi, then Same host, and join. A laptop on the same network can run `cd server && npm start` instead. The join sheet accepts a typed host address such as `192.168.43.20:3000`.

GitHub Actions, Build Android APK, runs a debug-key APK when you pass a server URL.

## Limits

Classic Snake, Penalty Shootout, Fruit Duel, Snake Duel, and Crush It still have source in the repo. They are not in the hub list or the online catalog. Their previews exist so a leftover id does not show a blank card.

The home screen does not have a separate Server page. The internet address is the `SERVER_URL` used at build time. Same-network addresses are typed in the Same host sheet.

Battleship still sends both fleets in the shared relay state. On 2026-10-17, `flutter test` in `mobile/` reported 863 passed and 5 failed. Those five failures were already present on commit `c6a55b8` before the home redesign. See `UI_REDESIGN_PROGRESS.md`.
