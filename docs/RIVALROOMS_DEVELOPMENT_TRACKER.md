# RivalRooms / Party Games — Development Tracker

Last updated: 2026-10-15

> **Repository access note:** The user requested https://github.com/shubhamgupta24b-rgb/RivalRooms, but the connected GitHub account returns 404 for that repository. Work below is tracked in the accessible repository https://github.com/shubhamgupta24b-rgb/Two-player-online only because it is the available candidate; no game code is being changed until the target is confirmed or RivalRooms access is granted.

## Decisions / requirements
- Home is **one page**, concise, with clear entry choices: **Online**, **Single Player**, **Multiplayer**, and **Offline/Local**.
- Remove unnecessary explanatory paragraphs, featured-game clutter, and marketing copy from Home.
- Privacy Policy is accessible from **Settings only**, never Home.
- Reference visual style: the user likes the **main gameplay UI** designs for Basketball Hoops and Fruit Cut. Use natural, game-specific artwork/colors and clear gameplay area. Avoid generic AI-looking blue/purple gradients and excess decorative copy.
- Start by improving **Basketball Hoops** and **Fruit Cut**, one by one. Then select 8 distinct games from the existing catalogue per next batch.
- Keep mode options truthful to each game: solo/practice, same-device local, online rooms and offline/LAN only where supported.
- Preserve actual game mechanics, score calculations, timers, navigation, and server-authoritative online synchronization. Do not replace working logic with mock data.
- Maintain this tracker as the single source of progress: status, files touched, test/build output, deployment status, known issues.
- Deployment target is Render. Provide APK for user testing and sandbox testing where build/test tools permit. Prepare signed AAB and Play Console checks later.
- Never claim tests, live deployment, APK creation, sandbox tests, or store upload unless actually completed.

## Agreed implementation plan
1. Confirm target repository access; inspect current branches and project before code edits.
2. Inspect Home, Settings/privacy navigation, game catalogue, Basketball Hoops, Fruit Cut, server event protocol, tests, and Android build/signing.
3. Simplify Home to one page with four mode choices, no filler copy; move Privacy into Settings.
4. Improve Basketball Hoops main gameplay UI without changing timing/scoring/state events.
5. Improve Fruit Cut main gameplay UI without changing slicing/scoring/state events.
6. Add/adjust tests; run Flutter analyzer/tests and server tests as available.
7. Build a verified APK (debug for testing, release if signing config is available). Share only an actual artifact. Test local/sandbox execution if an emulator/runtime is available.
8. Deploy/verify Render server using its health endpoint and end-to-end online smoke tests; ensure public auth and privacy config are production-ready before release.
9. Work through next batches of 8 distinct existing games, updating this tracker after each batch.
10. Before Play Console: verify signed AAB, package ID, upload key backup, privacy policy, Data safety form, content rating, screenshots, and online match testing.

## Current repository investigation (accessible candidate only)
- Candidate repository: https://github.com/shubhamgupta24b-rgb/Two-player-online (public; default branch `main`; connector reports push permission).
- Flutter app under `mobile/`, server under `server/` using Node/Socket.IO; `render.yaml` exists.
- README states the app has 41 party games and documents Flutter tests/builds and Render hosting. The free Render plan sleeps after idle, so it is not guaranteed always-online; Starter avoids sleeping.
- Current Home implementation path: `mobile/lib/features/home/home_screen.dart`. It currently shows welcome header, hero panel, mode tiles for Play online/Same Wi-Fi/My records, recent/featured games, and a Privacy button at the bottom. Privacy should be moved into Settings and removed from Home.
- Basketball implementation: `mobile/lib/games/basketball_hoops/basketball_hoops_screen.dart`. Existing gameplay uses `GameSessionManager`, server-provided phase/endsAt/target/score/shots/nextShotAt and action `basketball:shoot`; use those values and preserve action payload.
- Fruit implementation: `mobile/lib/games/fruit_duel/fruit_duel_screen.dart`. Existing gameplay uses server-provided phase/endsAt/fruitLane/fruitId/players and action `fruit_duel:slash`; preserve its payload and lane/fruit ID behavior.
- Game catalogue path: `mobile/lib/games/game_catalog.dart`; includes many local games and online-capable entries.
- Render config: `render.yaml` deploys a Docker web service from `server/`, with `/health` and a privacy contact environment variable. README warns guest/development auth is not suitable for store release.
- Flutter package uses Provider, Socket.IO client and SharedPreferences.

## Progress status
| Item | Status | Notes |
|---|---|---|
| Requested RivalRooms repository | **Blocked** | Connector returns 404; repo may be private or not installed for connector |
| Accessible candidate repo inspection | Partial | Existing Party Games repo inspected as fallback candidate |
| Tracker file | Complete (initial) | Committed to accessible candidate at `docs/RIVALROOMS_DEVELOPMENT_TRACKER.md`; no application code changed |
| One-page Home redesign | Not started | Need confirm target repository |
| Privacy only in Settings | Not started | Current candidate Home has a Privacy button that needs relocation |
| Basketball Hoops redesign | Not started | Existing screen and server action inspected |
| Fruit Cut/Fruit Duel redesign | Not started | Existing screen and server action inspected |
| Flutter tests/analyzer | Not run | No local repository checkout/runtime setup performed |
| Render deployment | Not verified | Blueprint exists; live URL not provided/verified |
| APK build | Not built | Must build from real checkout and verify artifact |
| APK/sandbox testing | Not done | Requires generated APK and available Android runtime |
| Play Store AAB | Not built | After QA and release signing/privacy checks |

## Next 8-game batch
Do not select until confirming target repo and inspecting full catalogue. Choose eight distinct games; track each separately:
1. Pending
2. Pending
3. Pending
4. Pending
5. Pending
6. Pending
7. Pending
8. Pending

## Work log
- 2026-10-15: Plan and first tracker committed to accessible candidate repo. Inspected Home, game catalogue, Basketball Hoops, Fruit Duel, README, and Render config. No production/game code changed because the exact requested RivalRooms repository was not accessible.
