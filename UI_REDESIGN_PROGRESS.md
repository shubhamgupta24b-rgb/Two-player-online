# UI redesign progress

Last updated: 2026-10-17
Branch: `feature/memory-game`
Baseline commit before this work: `c6a55b8aec9807f48a0d93d7ce03a9b493ec9f84`
Latest commit: `23cf61b` added `DONE.md` on this branch. The lavender home changes are in the working tree and are not committed yet.
Completed phases: 18 of 18 for the first redesign, plus the lavender navigation pass below
Games audited: 67 games on the home and hub list (`listedGames()`), plus online-only ids and retired source ids covered by the preview manifest
Unique previews: 74, one scene per id in `gamePreviewManifest`. The lavender pass did not redraw them.
Six-card layout: verified. At 390dp and 411dp, All Games is 3 columns. At 320dp it is 2 columns. `mobile/test/home_redesign_test.dart` expects a batch of 6 at 390dp. The home widget test passed again at 320, 411, and 800 after the lavender pass.
Gameplay and multiplayer regression: the full `flutter test` on 2026-10-17, before this lavender pass, finished 863 passed, 5 failed. Those 5 failures were already present on `c6a55b8`. This pass re-ran `home_redesign_test.dart` (4 passed) and the home layout test at three sizes (3 passed). The full suite and a new APK were not re-run.
Current blockers: none in the home navigation.
Next steps: none for the lamp pass. The full suite was not re-run for this branch.

## Lamp theme pass

Branch: `feature/ui-polish-theme-profile-apk`, created from `feature/memory-game`.

The home uses the dark and light palettes in the lamp preview. A hanging lamp and the Settings switch write `set_home_light`. Dark is the default. The promotional lines “PICK YOUR NEXT MATCH” and “Quick to pick up. Hard to put down.” are not in the app. Game preview painters were not edited.

Trending still has cards, Online / Wi-Fi, Offline, and the leaderboard. All Games still hides those controls. Profile, Settings, and Privacy Policy still open from the avatar. Same host and Online are unchanged.

The full leaderboard page background and title follow the lamp. Rank cards keep their gold, silver, and bronze fills. Privacy stays on the existing policy screen. There is no separate presence service: the avatar dot is the socket connection.

Tests on 2026-10-17: `home_redesign_test.dart` 5 passed, `leaderboard_test.dart` 5 passed, the home layout test passed at 320, 411, and 800, and the lamp widget test passed. The full `flutter test` suite was not re-run. The APK is recorded after the build.

## Lavender home pass

Reference: `two_player_game_home_preview_lavender_final.html`. Solid `#F2EEFF` background, white cards, purple `#8655F6` for the active tab and the Online / Wi-Fi button. Game preview painters were not edited.

1. Audit. Status: COMPLETED. Flutter app on `feature/memory-game`. Home is `home_screen.dart`. Games come from `listedGames()`. Rooms, sockets, and the privacy screen were already present.
2. Preview. Status: COMPLETED. Header, tabs, 3-column cards, mode buttons, and a leaderboard card. Sample names in the HTML are not app data.
3. Existing features. Status: COMPLETED. Socket `connected` is the status dot. Settings already persist music, vibration, and reduce motion. Privacy is `PrivacyScreen`. Same-network play is `LanHost` and `LanDiscovery`. There is no notification setting.
4. Main and All Games. Status: COMPLETED. Trending keeps cards, Online / Wi-Fi, Offline, and the leaderboard. All Games keeps search and filters and hides those controls.
5. Profile status and menu. Status: COMPLETED. Green when the socket is connected, amber while this screen is connecting, grey otherwise. The avatar opens Profile, Settings, and Privacy Policy.
6. Settings and privacy. Status: COMPLETED. `SettingsScreen` uses the existing switches and shows version `0.1.0+1`. Privacy opens the existing screen.
7. Online / Wi-Fi. Status: COMPLETED. Same host uses the existing hotspot sheet. Online uses Create room, Join room, and Quick play.
8. Offline and leaderboard. Status: COMPLETED. Offline lists `listedGames()` only. The leaderboard stays on Trending and still uses server or on-phone wins.
9. Tests. Status: COMPLETED for the home tests named above. Full suite not re-run.
10. Docs. Status: COMPLETED. `README.md` and this file match the new home flow.

Files: `home_chrome.dart`, `home_screen.dart`, `game_card.dart`, `settings_screen.dart`, `components.dart` (`SettingsPanel.showPreferences`), `start_pages_test.dart`, `README.md`, this file.

## Design notes

The current home uses the lavender preview, described in the pass above. The notes below are the earlier night-theme pass and are kept as history.

`home-final.html` was the first phone reference: safe header, Trending and All Games, image cards, Online and Offline, then a top-3 leaderboard. Sample names in that file were not copied into the app.

`RivalRooms Game Previews.html` draws a small scene per game. The app keeps one painted scene per game id. The lavender pass did not change those paintings.

Tokens live in `mobile/lib/features/home/home_chrome.dart`. The home now uses `#F2EEFF`, white cards, and `#8655F6`. Cards use one shadow, `0 3px 12px` at about 8% of `#433078`. Pressed cards fade to 0.82 opacity. Motion follows the app reduce-motion setting.

## Phase 1. Repository audit and baseline

Status: COMPLETED

The branch was `feature/memory-game` at `c6a55b8`. Flutter app in `mobile/`, Node server in `server/`. Home was `mobile/lib/features/home/home_screen.dart` (room buttons, a hero, a horizontal featured row). The game list is `listedGames()` in the hub. Online games are `gameCatalog`. Previews were `GameBadgePainter` in `game_art.dart`, one glossy gradient with a shared icon, plus a few board sketches.

Untracked files left untouched: `DONE.md`, `mobile/devtools_options.yaml`. `mobile/tool/layout_preview_test.dart` was untracked and was extended for screenshots.

Baseline, 2026-10-17, `flutter test` in `mobile/`: 859 passed, 5 failed.

Pre-existing failures:

- `batch3_games_test.dart` expects `penalty` in the live game set. Penalty is not in the hub list.
- `local_games_widget_test.dart` hub scroll throws `Bad state: No element`.
- `local_games_widget_test.dart` Ball Sort overflows on a small phone.
- `online_game_screens_test.dart` Memory screen does not find "Your turn" or "Opponent's turn".

No server `node_modules` was present, so `npm test` was not part of the baseline.

Files expected to change: home screen, game art, hub grid, tests, README, this file.

## Phase 2. Design reference analysis

Status: COMPLETED

See Design notes. No sample users were copied into the app.

## Phase 3. Design system

Status: COMPLETED

`home_chrome.dart` and `home_layout.dart`. Column rule: under 340dp use 2, from 340dp use 3, from 900dp use 6.

## Phase 4. Home header

Status: COMPLETED

Avatar with a connection dot, "Welcome", the saved name or "Player", and Settings. SafeArea supplies the status inset. The old hero is gone.

## Phase 5. Trending and All Games

Status: COMPLETED

Trending reads `online_counts`. All Games is `listedGames()` with search, categories, favourites, and player filters. The selected tab uses a gold underline. Card taps still open the existing game route.

## Phase 6. Six-card All Games layout

Status: COMPLETED

`GridView.count` with `allGamesColumns`. `mobile/test/home_redesign_test.dart` expects batch size 6 at 390dp. The home widget test checks 2 columns at 320 and 3 columns at 411 and 800 (the home column is capped at 640, so 800 still lays out as 3).

## Phase 7. Reusable game cards

Status: COMPLETED

`HomeGameCard` in `game_card.dart`. `GameTile` uses the same preview, a flat border, and a small shadow. The 3px press sink is gone.

## Phase 8. Game and artwork audit

Status: COMPLETED

Each manifest entry names the scene from the game that is actually in the repo: pairs for Memory, discs for Connect Four, a sea grid for Battleship, a Ludo board, sliced fruit, a pool table, and so on. Retired ids are included so they do not fall through to a shared icon.

## Phase 9. Unique previews

Status: COMPLETED

Painted in `game_preview.dart`. Flat shapes, no gloss, no extruded text. The test paints every scene and one missing id.

## Phase 10. Artwork integration

Status: COMPLETED

`GameBadgePainter` draws `GamePreviewPainter` when the id is in the manifest. Otherwise it draws the existing icon on a flat fill. No network images.

## Phase 11. Upper game-selection area

Status: COMPLETED

Header, tabs, then the grid. Trending stays a short 2-column set (4 columns from 700dp). Titles stay on the card. No per-card descriptions.

## Phase 12. Online, offline, and social features

Status: COMPLETED

Online calls the existing internet connection and opens Create room, Join room, and Quick play. Offline opens the existing Same Wi-Fi sheet. The leaderboard uses `rowsFromLeaderboardJson` and phone records, with loading, empty, offline, and error text. Settings, My records, and Privacy remain.

## Phase 13. Remove unnecessary 3D effects

Status: COMPLETED

Removed from the home and from game badges: gloss ovals, gradient icon fills, the hero gradient card, and the badge blur. Card flip in Memory, the Smash Karts board tilt, and Raja Mantri role flips stay. Those are gameplay.

## Phase 14. Responsive design and accessibility

Status: COMPLETED

Home widget test at 320x568, 411x914, and 800x1280. Tabs and mode buttons are at least 48dp. Titles use two lines and ellipsis. Pressed and selected states are on the card and the tabs. `Motion.of` honors reduce motion.

## Phase 15. Gameplay and multiplayer

Status: COMPLETED

`flutter test` in `mobile/` on 2026-10-17: 863 passed, 5 failed. Baseline before the redesign was 859 passed, 5 failed. The four new tests are in `home_redesign_test.dart`. The five failures are unchanged:

- music test expects `penalty`, which is not in the hub list
- hub scroll test throws `Bad state: No element`
- Ball Sort overflows on a small phone
- online Memory screen tests do not find "Your turn" or "Opponent's turn"

Memory counts 8, 12, 16, 20, 24, 28, and 32 are still the create-room chips and the server check. This redesign did not change Memory rules, scoring, or the relay. Screenshot: `docs/ui-redesign/screenshots/preview_memory_setup.png`.

Not done: a live two-phone match.

## Phase 16. Tests and visual verification

Status: COMPLETED

- `flutter test test/home_redesign_test.dart` passed (columns, trending parser, preview coverage, paint)
- `flutter test test/games_hub_test.dart` passed
- `flutter test test/leaderboard_test.dart` passed
- `flutter test test/start_pages_test.dart --name "home lays out"` passed at 320, 411, and 800
- `flutter test` full suite: 863 passed, 5 failed, as in phase 15
- `flutter test tool/layout_preview_test.dart` passed

Screenshots, also copied to `docs/ui-redesign/screenshots/`:

- `preview_home.png` Trending
- `preview_all_games.png` six-card rows
- `preview_all_games_later.png` a later batch
- `preview_all_games_narrow.png` 320dp, two columns
- `preview_home_narrow.png`
- `preview_memory_setup.png`
- `preview_games.png` the games hub

Originals from the test run are under `mobile/build/screens/`.

## Phase 17. Performance and release preparation

Status: COMPLETED

Previews are drawn in the app. No new dependency was added. Unused glossy board painting in `game_art.dart` was removed after the preview painter replaced it.

`flutter build apk --release` from `mobile/` finished on 2026-10-17. Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`, 62,086,365 bytes (Flutter reported 59.2 MB). No `SERVER_URL` dart-define was passed, so this APK uses the default `http://10.0.2.2:3000`. `mobile/android/key.properties` and `upload-keystore.jks` were present on this machine and are not in git. The APK itself is a build output and is not committed. Gradle printed upcoming-support warnings for Gradle 8.14.3, Android Gradle Plugin 8.11.1, and Kotlin 2.2.20. The task still succeeded.

## Phase 18. Final verification

Status: COMPLETED

Home follows the `home-final.html` hierarchy. All Games is three columns from 340dp, so a full pair of rows is six cards, and every listed game stays in the grid. 67 hub games were audited. 74 preview scenes are mapped. Glossy shared badges are gone from the home cards and hub tiles. Gameplay transforms were left in place.

`flutter test` in `mobile/`: 863 passed, 5 failed. Those five failed on `c6a55b8` before this work. A live two-phone match was not run. `npm test` in `server/` was not run because `server/node_modules` was not installed. The release APK path is in phase 17. Nothing was pushed.

## Results log

Home layout test, 2026-10-17: passed on 320, 411, and 800.

Full `flutter test`, 2026-10-17: 863 passed, 5 failed. Same five failures as the baseline. Four new tests passed.

Screenshot test passed. Files listed in phase 16.

Release APK, 2026-10-17: `flutter build apk --release` succeeded. See phase 17.

