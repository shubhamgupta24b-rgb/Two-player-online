# JindoBlu APK Inventory → Two-player-online Mapping

**Status:** static metadata inventory + repository source-tree mapping. This is not method-level reverse engineering. Exact scoring, timings, physics constants, levels and end conditions remain unverified until native IL2CPP methods are analysed or controlled gameplay is observed.

## Evidence boundary

The supplied `base.apk` and `split_config.arm64_v8a.apk` are two splits of one Unity IL2CPP Android app (`com.JindoBlu.FourPlayers`). The base contains `assets/bin/Data/Managed/Metadata/global-metadata.dat` (~12.1 MB); the ARM64 split contains `lib/arm64-v8a/libil2cpp.so` (~68.3 MB). Type names and strings are useful leads, not proof of complete gameplay rules. REA/JADX could not be installed in the sandbox because direct GitHub and npm registry DNS requests failed. Do not label any candidate as fully reverse engineered.

## UnityFS asset-file cross-check (new evidence)

The compressed UnityFS index was decoded successfully: 2,053 blocks expand to a 268,960,812-byte virtual stream, and the bundle contains 12 indexed virtual files. Matching identifiers occur in both `globalgamemanagers` and asset files such as `sharedassets1.assets` / `resources.assets`. The repeated title-like identifiers include:

- `3_POOL`, `16_MINIGOLF`, `21_WHACKAMOLE`, `25_PITTURA`, `26_FISHING`, `32_FIREWORKS`, `33_ARCHERY`
- `46_HUNGRYHIPPOS`, `49_MEMORY`, `50_KNIFEHIT`, `54_HOTPOTATO`, `57_DOTSBOXES`, `72_FLAPPYDUNK`, `82_SOCCERSTARS`
- `112_ARCHERY2`, `120_SLOTCARS`, `127_SHOOTINGGALLERY`, `130_SNAKESLADDERS`, `133_BASKETBALLHOOPS`, `144_FIND`, `145_GUESS_THE_PERSON`, `146_IMPOSTOR`

This cross-file repetition is stronger evidence than raw bundle strings alone, but it still does not prove all candidates are selectable in this build. Some entries have explicit tutorial/settings variants. Serialized-object tables and scene references remain to be decoded, and the supplied APK has not yet been run for controlled gameplay observation.

## Candidate inventory and existing-app mapping

| APK candidate | Evidence seen in metadata | Existing app mapping | Recommendation |
|---|---|---|---|
| Archery | `ControllerArchery`, `FrecciaArchery`, `BersaglioArchery` | `archery` local game + catalogue | Audit existing implementation against reference before adding anything. |
| Astronavi (spacecraft) | `Astronave`, `ControllerAstronavi` | `space_shooter` solo game is adjacent, not proven equivalent | Treat as a separate candidate until gameplay confirms overlap. |
| Dots & Boxes | `BoardBox`, `BoardLine`, `DotsBoxesAutoplay` | `dots_boxes` local game, 2–4 players | Reuse; validate rules/board sizing against reference. |
| Duell (fruit-cutting duel) | `DuellController`, `FruitController`, `ICuttableItem` | `fruit_duel` local/online game | Strong likely overlap; compare interaction/scoring before merging. |
| Fireworks | `ControllerFireworks`, `Razzo`, `TargetFireworks` | `slingshot` / `shooting_gallery` are adjacent only | New game likely needed; inspect launch/target mechanics first. |
| Fishing | `ControllerFishing`, `CannaDaPesca`, `Pesce` | No direct mapping found | New game candidate. |
| FlappyDunk | `ControllerFlappyDunk`, `BallController`, hoop/score types | `basketball_hoops` exists but is not proven equivalent | Compare mechanics; do not silently replace basketball. |
| HammerHit | `ControllerHammerHit` | `bottle_smash` is only an adjacent reaction/action game | New candidate pending scene/behavior evidence. |
| HappyBirds | `HappyBirdsController`, `Bird`, `SpikeController` | `flappy_jump` solo is adjacent | Determine whether distinct game loop and scoring are used. |
| HotPotato | `HotPotatoController`, `Ball`, `Character` | No direct mapping found | New multiplayer candidate; define pass/hazard/timer rules from evidence. |
| HungryHippos | `ControllerHungryHippos`, `HippoHead` | No direct mapping found | New candidate. |
| KingYard | `ControllerKingYard`, `PersonaggioCPU`, `PowerUpYard` | `smash_karts` is not equivalent based on available evidence | New candidate; exact objective remains unknown. |
| KnifeHit | `KnifeHitController`, `Knife`, `Rotator` | No direct mapping found | New candidate; measure timing, collision and progression. |
| Macchinina | `CheckpointMacchinina` | No direct mapping confirmed | Keep unresolved; one class name is insufficient to infer the full game. |
| MathMagic | `MathMagicController`, `MathHandler`, `PlayerAnswerHandler` | `math_duel` exists | Likely related; compare question generation, response timing and scoring. |
| Memory | `MemoryController`, `MemoryCard`, `MemoryBot` | `memory` local/online game | Reuse; verify pair count, turn retention and end scoring. |
| Minigolf | `ControllerMinigolf`, `PistaMinigolf`, `PlayerMinigolf` | `mini_golf` local game | Reuse; compare aim/power/physics and hole rules. |
| Pinguini | `ControllerPinguini`, `Pinguino`, fish/effect types | No direct mapping found | New candidate. |
| Pittura (painting/territory) | `ControllerPittura`, `PitturaPlayersHandler`, `RulloPittura` | `paint_fight` local/online game | Strong likely overlap; compare territory ownership and movement. |
| Pool | `ControllerPool`, `Billiard`, `BilliardPocket`, `PallaOtto` | No direct mapping found | New game candidate; requires measured ball physics and foul/scoring rules. |
| PullTheRope | `ControllerPullTheRope` | No direct mapping found | New candidate; inspect input cadence, team/player count and finish condition. |
| Racing | `RacingController`, `Car`, `Track`, `Checkpoint` | `smash_karts` is not confirmed equivalent | New candidate unless play evidence shows same loop. |
| Rane (frogs) | `ControllerRane`, `Rana` | No direct mapping found | New candidate; mechanics unclear. |
| Rubasoldi | `ControllerRubasoldi`, `Cassaforte`, `RampinoRubasoldi` | No direct mapping found | New candidate; infer no rules until scene/behavior evidence. |
| Sliding Puzzle | `SlidingPuzzleGameController`, shuffle/layout types | `sliding_puzzle` solo game | Reuse for local solo; assess whether multiplayer/relay mode is meaningful. |
| Snake | `ControllerSnake`, `SnakeHead`, `SnakeBody` | `classic_snake` solo and `snake_duel` competitive games | Reuse only if rule/arena differences are resolved. |
| SoccerStars | `SoccerController`, `SoccerBall`, `SoccerGoal`, player/bot types | No direct mapping found | New candidate; likely physics/sports. |
| Solitaire | `SolitaireController`, `Card`, `GamePile` | No direct mapping found | New solo candidate; not an online-room priority. |
| Sottacqua (underwater) | `ControllerSottacqua`, `PesceSottacqua` | No direct mapping found | New candidate; mechanics unclear. |
| Topolini (mice) | `ControllerTopolini`, `Topolino`, cheese/cat types | No direct mapping found | New candidate. |
| Traffico (traffic) | `ControllerTraffico`, `MacchininaTraffico`, `OstacoloTraffico` | No direct mapping found | New candidate. |
| Whack-a-Mole | `ControllerWhackAMole`, `MolePit` | `whack_mole` solo game | Reuse for solo; confirm target count/timer/scoring. |

## Existing implementation to preserve

The current app already has local-game modules and a shared shell. Examples confirmed in the branch source tree include:

- `mobile/lib/games/game_catalog.dart` — online catalogue and player caps.
- `mobile/lib/features/local_games/shell/local_game_shell.dart` and `local_game_info.dart` — shared local-game presentation/contract.
- `mobile/lib/features/local_games/dots_boxes/dots_boxes_game.dart` — existing turn-based Dots & Boxes implementation.
- `mobile/lib/features/local_games/archery/archery_game.dart`, `mini_golf/mini_golf_game.dart`, `solo/sliding_puzzle.dart`, `solo/classic_snake.dart`, `solo/whack_mole.dart` — existing adjacent/direct modules.
- `server/src/games/registry.js`, `server/src/games/relay/index.js`, `server/src/rooms/RoomManager.js` — existing server-side game registry/room lifecycle.
- `mobile/lib/core/lan/` and `mobile/lib/core/network/socket_manager.dart` — existing LAN/network infrastructure.

Do not add duplicate game IDs or bypass these contracts. Catalogue availability alone does not prove that a game has authoritative online rules implemented.

## Recommended implementation order

### Step 1 — Validate existing matches first
1. Dots & Boxes
2. Memory
3. Archery
4. Minigolf
5. Sliding Puzzle (solo)
6. Snake / Snake Duel
7. Whack-a-Mole (solo)
8. Fruit Duel, Math Duel, Paint Fight, Basketball Hoops: verify which are truly equivalent to the APK variants.

For each, record measured reference behavior, identify gaps, then update the existing game rather than adding a duplicate.

### Step 2 — Add small deterministic games
Prioritize SoccerStars only after its ball/player turn and score model are observed; implement Solitaire as solo if desired. Add unit tests before screens or network integration.

### Step 3 — Physics and fast arcade games
Pool, FlappyDunk, KnifeHit, Racing, HotPotato, Fishing and Fireworks require repeatable measurements of movement, collision, timing, scoring and reset behavior. Keep simulation independent of render frame rate; define network authority before enabling online play.

### Step 4 — Remaining candidates
Implement the remaining confirmed games one at a time. Use neutral/original art and sound; do not bundle extracted proprietary assets without rights.

## Required evidence per game

- Reference screens: setup, active round, pause/restart, results.
- Player count and local/online interaction model.
- Input rules, timing, scoring, turn ownership and finish/tie conditions.
- Physics values measured from repeatable trials where relevant.
- Known differences between reference and port.
- Logic tests, Flutter widget tests and server tests where applicable.
- Build and smoke test on Android before marking complete.

## Current blockers and truthfulness

- Direct sandbox requests to GitHub and npm registry failed DNS resolution, so the pinned JADX engine JAR and REA package are not available locally.
- Host Java is OpenJDK 21, but Node is v22.16.0; current REA docs require Node 22.19+ for the 22.x line.
- Flutter SDK is not present on PATH in this sandbox; an Android APK cannot currently be built locally from this environment.
- No methods have been decompiled and no reference gameplay has been run. Exact physics, scoring, timers and levels are still unknown.

Next external prerequisite: restore package download access (or provide a trusted local copy of the REA package and SHA-256-pinned JADX JAR). Then run the official APK analysis, and only afterward implement the first verified gap. The source APK is a reference only; do not copy its Unity binaries or assets into the app.
