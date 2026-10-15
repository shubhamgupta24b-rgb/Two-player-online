# RivalRooms Development Tracker

Last updated: 2026-10-15
Repository requested: https://github.com/shubhamgupta24b-rgb/RivalRooms
Repository access: Not available to the connected GitHub account (GitHub returned 404). The existing accessible repository is https://github.com/shubhamgupta24b-rgb/Two-player-online; do not modify it as a substitute unless confirmed.

## Product requirements
- Home screen: one page only, with clear entry choices: Online, Single Player, Multiplayer, Offline/Local.
- No unnecessary marketing/description text on the home screen.
- Privacy Policy must live in Settings only, not on the home screen.
- Visual reference: Basketball Hoops and Fruit Cut main gameplay UI that the user liked. Natural game-specific palette and artwork, simple readable controls, minimal overlays; avoid generic neon blue/purple AI-looking layouts.
- Start by improving two games: Basketball Hoops and Fruit Cut, then add 8 distinct games per planned development batch/session, selected from the existing repo games.
- Support modes according to each game capability: solo/practice, same-device local, online room/match, offline local. The interface must not imply a mode when the game doesn't support it.
- Maintain gameplay rules, scoring, timers, navigation, and synchronized server-authoritative online match state.
- Keep this file updated whenever a feature is changed: design/implementation status, files changed, test/build result, deployment status, and known issues.
- Backend intended for Render. APK requested for user testing and in-sandbox testing where possible; also prepare AAB for Play Console later.
- Do not claim deployment, APK generation, sandbox testing, or Play Console upload unless actually completed.

## Plan
1. Obtain access to the requested RivalRooms repository, or get explicit confirmation to use Two-player-online instead.
2. Inspect project structure, branches, current home screen, game implementations, server protocol, tests, and Android build/signing setup.
3. Create this tracker (or merge it into the repo’s existing tracker if one exists) and define a one-page home:
   - Play Online
   - Single Player
   - Multiplayer (room / invite)
   - Offline / Local
   - Settings entry; Privacy Policy only inside Settings.
4. Review Basketball Hoops and Fruit Cut implementations and existing UI. Preserve game logic. Refine one game at a time; implement mode availability truthfully.
5. Add/update tests for navigation, solo/local modes, multiplayer state handling, score/timer behavior, and responsive layouts.
6. Build and test Android debug/release APK locally or via GitHub Actions; verify actual artifact before sharing.
7. Deploy the server to Render, configure production auth and environment variables, verify /health and end-to-end multiplayer.
8. Continue through the next 8 distinct games per batch, recording progress here.
9. Once stable, generate a signed AAB, check privacy/data-safety and store assets, then prepare for Play Console release.

## Screen/mode behavior
- Single player: no server requirement; practice/AI implementation only where actually supported.
- Multiplayer online: join/create room; server-authoritative room membership, turns/actions, scores, timers and results.
- Local/offline: shared device or local network only where implemented; clearly label local requirements.
- Settings: sound, haptics, display/accessibility options where supported, server configuration if already available, and Privacy Policy link.
- Home: compact game entry and mode actions, no long paragraphs or privacy text.

## Progress
| Item | Status | Notes |
|---|---|---|
| Plan | Drafted | Based on user requirements |
| Confirm target repo | Blocked | RivalRooms returns 404 via connected GitHub integration |
| Inspect accessible existing repo | Partial | Two-player-online has mobile Flutter app, server Node/Socket.IO and render.yaml |
| One-page home redesign | Not started | Await target repo access/confirmation |
| Basketball Hoops | Not started | First game after repository access |
| Fruit Cut | Not started | Second game after repository access |
| Render deployment | Not started | Existing Render blueprint exists in accessible repo, not yet verified live |
| APK artifact | Not started | Need build environment / CI artifact |
| APK testing | Not started | Must build and verify before claiming tests |
| Play Console AAB | Not started | After gameplay and release checks |

## Batches
### Batch 1 — first two games
1. Basketball Hoops — pending code inspection and implementation.
2. Fruit Cut — pending code inspection and implementation.

### Batch 2 — next 8 distinct games
Select only after inventorying current game list; avoid duplicate or removed games. Track each game's solo/local/online support and tests here.

## Log
- 2026-10-15: Initial plan/tracker drafted. GitHub connector could access Two-player-online but returned 404 for RivalRooms. No code changes made.
