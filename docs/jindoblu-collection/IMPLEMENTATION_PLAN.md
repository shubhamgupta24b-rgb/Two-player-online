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
- [ ] Obtain the pinned JADX engine JAR and compatible REA package; direct sandbox DNS access to GitHub/npm currently fails.
- [ ] Complete scene/assets and controlled-play inventory; confirm exact rules, scores, timings and physics.
- [ ] Implement the first verified gap after confirming its rules.
- [ ] Run tests and produce the first test APK (Flutter SDK is not present on this sandbox PATH).
