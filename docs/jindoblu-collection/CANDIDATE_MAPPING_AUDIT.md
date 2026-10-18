# JindoBlu-to-Flutter Candidate Mapping Audit

**Branch:** `feature/jindoblu-collection`  
**Purpose:** Prevent duplicate work and distinguish observed asset names from confirmed gameplay.

## Evidence standard

- **Asset-name evidence:** title-like identifiers found in the decompressed UnityFS virtual files. This is not proof that a title is selectable or active.
- **Existing-app overlap:** a similarly named implementation exists in the current Flutter catalogue. It is a candidate match, not proof of identical rules.
- **Mechanics verified:** requires controlled gameplay observation or validated serialized/native evidence. No candidate below is marked mechanics-verified based on static strings alone.

## Candidate mapping

| Unity title-like identifier | Existing Flutter candidate | Current recommendation | Confidence |
|---|---|---|---|
| `3_POOL` | No obvious exact catalogue entry | Observe controls/rules; possible new game if active | Asset name only |
| `16_MINIGOLF` | `mini_golf` | Audit current implementation before considering changes | Strong name overlap |
| `21_WHACKAMOLE` | No obvious catalogue entry | Verify active menu entry and input/timing rules | Asset name only |
| `33_ARCHERY`, `112_ARCHERY2` | `archery` | Treat as one possible family with variants until proven otherwise | Strong name overlap |
| `49_MEMORY` | `memory` | Compare setup options, turn rules, scoring, and player count | Strong name overlap |
| `57_DOTSBOXES` | `dots_boxes` | Audit existing rules and board sizes first | Strong name overlap |
| `72_FLAPPYDUNK` | Possibly `basketball_hoops`, but not equivalent by name alone | Do not merge without gameplay evidence | Weak/hypothetical |
| `82_SOCCERSTARS` | No obvious exact catalogue entry | Good candidate to investigate next if selectable | Asset name only |
| `120_SLOTCARS` | No obvious exact catalogue entry | Verify active status and control scheme | Asset name only |
| `127_SHOOTINGGALLERY` | `shooting_gallery` | Audit existing implementation before changes | Strong name overlap |
| `130_SNAKESLADDERS` | `snakes_ladders` | Audit existing board/rules first | Strong name overlap |
| `133_BASKETBALLHOOPS` | `basketball_hoops` | Audit existing mechanics and multiplayer behavior | Strong name overlap |
| `145_GUESS_THE_PERSON` | `guess_who` | Compare question flow, character selection, and win conditions | Strong name overlap |
| `146_IMPOSTOR` | `find_spy` / `undercover` | Similar genre only; do not assume equivalent roles/rules | Weak/hypothetical |
| `50_KNIFEHIT`, `54_HOTPOTATO`, `46_HUNGRYHIPPOS`, `26_FISHING`, `32_FIREWORKS` | No obvious exact catalogue entry | Hold until active/selectable status and mechanics are verified | Asset name only |

## Existing app files to audit before implementing

- Catalogue: `mobile/lib/games/game_catalog.dart`
- Local game registry and metadata: `mobile/lib/features/local_games/`
- Online game registry: `server/src/games/registry.js`
- Relay implementation: `server/src/games/relay/index.js`
- Room lifecycle: `server/src/rooms/RoomManager.js`
- Shared game host/module: `mobile/lib/games/game_host_screen.dart`, `mobile/lib/games/game_module.dart`
- LAN/network integration: `mobile/lib/core/lan/`, `mobile/lib/core/network/socket_manager.dart`

## Implementation gate

Do not create a new game just because a title string exists. For each candidate, record:
1. Evidence that it appears in an active/selectable menu.
2. Setup options and supported player count.
3. Core inputs and deterministic state transitions.
4. Scoring, round end, restart, and tie behavior.
5. Whether multiplayer is turn-based, simultaneous, or real-time.
6. A test plan covering local play and the intended network mode.

Only after these are observed should a candidate be assigned an implementation task. Reuse existing game IDs where a game already exists; never import Unity binaries or proprietary art assets into the Flutter project.

## Current limitations

The UnityFS container and its 12 virtual files have been indexed and decompressed. Serialized-object tables, rendered scenes, and native IL2CPP gameplay behavior have **not** yet been decoded. Therefore the table above is a triage map, not a claim of full reverse engineering.
