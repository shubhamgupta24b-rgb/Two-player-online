# JindoBlu 1–4 Player Games Collection — Implementation Plan

## Goal
Port the mini-game collection represented by the user-supplied Android APKs into the existing **Two-player-online** Flutter app. The uploaded `base.apk` and `split_config.arm64_v8a.apk` are parts of one Android application and must be analysed together.

The goal is to reproduce gameplay behaviour and feel (including physics where applicable) from the authorised reference, while using the reference as a source of behavioural evidence and designing a coherent, original presentation that fits this app. Do not transplant Unity binaries or copy assets unless their reuse rights are explicitly confirmed.

## Repository / safety constraints
- Repository: `shubhamgupta24b-rgb/Two-player-online`
- Working branch: `feature/jindoblu-collection` (branched from `main`)
- Do not commit implementation work directly to `main`.
- Preserve the existing Flutter app, Node.js/Socket.IO server, LAN play, room/session flow, records, theme variants, and all existing game IDs.
- Existing catalogue and relay infrastructure are already shared by online rooms and local play; additions must use the current contracts instead of creating a parallel app.
- Never mark a game playable until its implementation, routing, and tests are present.
- Do not ship extracted proprietary assets unless the user's permission covers those specific assets; prefer original vector/custom-painted assets and sounds.

## Phase 0 — APK and reference inventory
1. Inspect both APKs together and confirm package/application metadata, Unity version clues, IL2CPP metadata, scenes, asset bundles, and resource names.
2. Establish a screen inventory from actual gameplay/reference captures: title/setup, active gameplay, pause, round-end, result, and settings where applicable.
3. Create a per-game inventory containing: reference title, mechanics, player count, input method, timing/scoring rules, physics parameters to measure, state transitions, and whether online multiplayer is meaningful.
4. Separate measured facts from hypotheses. Do not invent game names or physics values from incomplete metadata.
5. Record which visuals are original replacements versus references; preserve a clear provenance note for any reused asset with explicit permission.

## Phase 1 — Shared foundations
- Add a small collection module/metadata manifest that maps each confirmed reference game to its app game ID, category, player limits, input type, and implementation status.
- Use the existing `gameCatalog`, local-game shell, `LocalGameInfo`, relay/server registry, and game session flow.
- Keep one-device play and online room play clearly distinguished. For competitive games, define authoritative state ownership and deterministic scoring before UI work.
- Add reusable primitives only where multiple games need them: countdown/start gate, score strip, round result, haptics/audio hooks, input normalization, and pause/restart handling.
- Physics-sensitive games must have fixed-step/update rules, bounded values, reproducible test cases, and documented tuning constants.

## Implementation batches
The APK inventory determines the exact titles and batch membership. Do not guess the collection's full game list before the inventory is complete.

### Batch A — Small, deterministic games
- Start with confirmed games whose mechanics are discrete and easy to test (tap/reflex, simple board, or turn-based games).
- Implement state transitions and rules first, then screen design and animations.
- Add logic/unit tests, Flutter widget tests, and online state/relay tests where online play is supported.

### Batch B — Physics and motion games
- Implement movement, velocity, gravity, acceleration, drag/friction, collision boundaries, bounce/jump, and reset conditions only for games where those mechanics are observed.
- Measure reference behaviour through repeatable trials; expose tunable constants and compare outcomes instead of relying on visual guesswork.
- Ensure the game loop remains smooth on mobile and does not let network jitter control local rendering.
- For online competitive play, send input/state at an appropriate rate and define reconciliation/authority; do not stream every rendered frame blindly.

### Batch C — Sports and aim/timing games
- Recreate aiming, launch/swipe gestures, target collision, scoring zones, turn/round flow, and tie-breakers as applicable.
- Validate touch targets, portrait/landscape behaviour, low-end device performance, and multiplayer fairness.

### Batch D — Fast arcade and survival games
- Implement timers, spawn patterns, hazards, power-ups, lives, score progression, and end conditions from the verified reference.
- Use original visual assets and distinct animations while matching gameplay response and difficulty curves.

### Batch E — Collection integration and polish
- Finish remaining verified games in the inventory.
- Add each game to home/category grids, setup/help, local play, online room selection, records/results, and LAN filtering as appropriate.
- Ensure incomplete or internet-only games are accurately labelled and cannot enter unsupported modes.
- Check both existing visual flavours: default and `--dart-define=APP_STYLE=flat`.

## Required acceptance criteria per game
- [ ] Behaviour documented from the reference, with unknowns explicitly listed.
- [ ] Rules, scoring, timing, restart, pause, and win/loss states implemented.
- [ ] Original, polished UI consistent with the app's existing design system; no generic neon/AI-looking treatment.
- [ ] Touch input and screen scaling work on common Android aspect ratios.
- [ ] Correct catalogue ID/title/player limits/category; no duplicate IDs.
- [ ] Local play tested; online/LAN play enabled only when the game's networking contract is implemented.
- [ ] Unit/widget/server tests added and passing.
- [ ] Existing games and both theme flavours remain unaffected.
- [ ] APK build succeeds and is smoke-tested before calling the batch complete.

## Validation commands
From the repository root:
```bash
cd server && npm install && npm test
cd ../mobile && flutter pub get && flutter analyze && flutter test
flutter build apk --release --dart-define=SERVER_URL=https://<deployed-server>
```
Also run two-device tests for online-enabled games: room join/leave, 2–4 player counts as configured, synchronized inputs/state, score/result agreement, disconnect/reconnect, and repeated round/restart flows.

## Delivery checkpoints
1. APK/reference inventory and exact batch list.
2. Batch implementation with a dedicated commit on `feature/jindoblu-collection`.
3. Automated test results and known gaps.
4. Release APK artifact for device testing after a successful build.
5. Continue with the next batch only after the previous batch has a testable checkpoint.

## Current status
- [x] Confirmed the repository and main branch.
- [x] Created isolated working branch `feature/jindoblu-collection`.
- [x] Created `REFERENCE_INVENTORY.md` mapping 32 metadata-supported game candidates against existing app modules to avoid duplicates.
- [x] Created `IL2CPP_METHOD_INVENTORY.md` by parsing metadata version 31 type/method records; controller method names are recovered, but native method bodies are not decompiled.
- [x] Added `IL2CPP_NATIVE_ANALYSIS.md` with a Ghidra workflow, metadata-to-native mapping cautions, candidate controller priorities, and evidence/confidence requirements.
- [x] Added `.github/workflows/jindoblu-validation.yml` to run server tests, Flutter analysis/tests, and publish a short-lived test APK artifact on branch updates; server tests passed on the first run, while the Flutter job is still running at the time of this update.
- [x] Inspected printable strings in `assets/bin/Data/data.unity3d` and recorded candidate game/scene identifiers in `UNITY_DATA_STRING_FINDINGS.md`; these strings are leads, not proof of playable scenes or exact mechanics.
- [x] Added a Python standard-library offline APK-split inventory script and Windows PowerShell runner under `tools/jindoblu-collection/`; the runner optionally downloads and verifies the official pinned JADX JAR before REA's Android package inspection.
- [ ] Run the runner on a host with working network access and Node.js 22.19+ / 24.11+ / 26+; this sandbox currently cannot resolve GitHub and has Node 22.16.0.
- [ ] Obtain native IL2CPP method analysis through Ghidra/IDA/Hopper and a metadata-to-native mapping; JADX alone does not decompile Unity IL2CPP gameplay code.
- [ ] Complete scene/assets and controlled-play inventory; confirm exact rules, scores, timings and physics.
- [ ] Implement the first verified gap after confirming its rules.
- [ ] Run tests and produce the first test APK (Flutter SDK is not present on this sandbox PATH).


## Progress update — 2026-10-18

### Completed
- Indexed and decompressed the UnityFS bundle from the supplied APK; documented the 12 virtual files and candidate title-like identifiers.
- Added the reference inventory, IL2CPP inventory, UnityFS tools, and candidate mapping audit.
- Cross-checked the candidate titles against the existing Flutter catalogue and Socket.IO relay registry to avoid duplicate game IDs/server registrations.
- Added a Render deployment runbook for the separate Node.js/Socket.IO service.
- Updated the server container image to Node 22 to match the CI runtime.
- Updated the validation workflow so `SERVER_URL` can be set as a GitHub Actions repository variable; without it, the APK targets the Android emulator's local server address.

### Validation state
- Previously observed on CI: server tests, Dart analysis, and Flutter tests passed.
- The release APK build was not confirmed on the earlier run. A newer workflow run is validating the latest deployment/CI changes; do not mark the APK as delivered until an artifact is visible and downloadable.
- Render service creation, public health check, and two-device online room test are not yet verified. The Render account connection/deploy action and actual Render service URL are still needed to finish those steps.

### Next execution order
1. Finish the current CI run and resolve any APK-build failure before distributing an APK.
2. Create the Render Blueprint from `render.yaml`, set `PRIVACY_CONTACT`, and verify `/health` and `/privacy`.
3. Set GitHub Actions repository variable `SERVER_URL` to the exact HTTPS Render service origin and build a hosted-backend APK.
4. Run a two-device smoke test: create room, join, start game, exchange actions, disconnect/reconnect.
5. Observe and document actual JindoBlu game mechanics before implementing a new game. Candidate strings alone are not sufficient evidence to claim exact rules.
6. Before public/Play Store release, replace the temporary public dev-auth configuration with Firebase auth and revisit room-state persistence and service-sleep behavior.
