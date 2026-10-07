# Handoff: finish the Party Games UI redesign

You are continuing a UI redesign of the Flutter app in `mobile/` (repo `Two-player-online`, branch `feature/ui-redesign`). About half the work is left: 51 of 62 games still need their own redesign (B3-B8), plus the final pass. Everything listed under "Already done" is committed and pushed. Work only on this branch and push after every batch.

## Read first
1. `docs/ui-redesign/UI_SPEC.md`: the spec. Section 0 is strict, section 5 describes every game, and sections 8 and 9 are the quality bar and the done checklist.
2. `docs/ui-redesign/PROMPTS.md`: the batch template (Prompts 5–12) and the final pass (Prompt 13).
3. `docs/ui-redesign/PROGRESS.md`: what each finished phase changed and decided.
4. `docs/ui-redesign/mockups/`: HTML + inline SVG references. Archery and Smash Karts have full mockups that are not built yet; port their SVG drawings into CustomPainters.

## Strict rules (UI_SPEC section 0)
- UI only. Do not change game logic, scoring, timing, bots, `RelaySpec` save/load/apply or JSON keys, `core/lan`, `core/network`, `core/room`, `core/session`, `core/records`, socket events or the server.
- Keep every `LocalGameInfo` id and title. Rule texts keep their meaning; you may remove emoji from them.
- Keep both flavors working: the default build and `--dart-define=APP_STYLE=flat`.
- No new runtime packages. Don't upgrade Gradle, AGP, Kotlin or SDK versions.
- No emoji in game UI: use the drawn icons. Player identity is colour + shape (`PlayerBadge`), never colour alone.
- If a change would need logic or network changes, stop and ask.

## Remaining work, in order
- **B3 — Party 1:** Guess the Person (`features/guess_person/*`, spec 4.12: keep `person_portrait.dart`, merge `gp_theme.dart` colours into tokens), Find the Spy, Undercover, Mafia, Dumb Charades, Heads Up.
- **B4 — Party 2:** Draw & Guess, Quiz Battle, Most Likely To, Would You Rather, Truth or Dare, Hand Cricket, Rock Paper Scissors.
- **B5 — Action 1:** Crush It, Basketball Hoops, Fruit Duel, Paint Fight, Air Hockey, Ping Pong, Snake Duel, Reaction Tap, Penalty Shootout.
- **B6 — Action 2:** Math Duel, Smash Karts (mockups/smash_karts), Mini Golf, Slingshot, Archery (mockups/archery), Shooting Gallery, Bottle Smash, Fruit Merge Battle.
- **B7 — Solo 1:** Fruit Merge, 2048, Classic Snake, Flappy Jump, Minesweeper, Brick Breaker, Whack-a-Mole, Piano Tiles, Word Scramble, Stack Tower.
- **B8 — Solo 2:** Simon Says, Ball Sort, Sliding Puzzle, Sudoku, Hangman, Dino Run, Block Drop, Bubble Shooter, Sky Jumper, Space Shooter, Color Switch.
- **Prompt 13 — final pass:**
  - search for leftover emoji, hard-coded colours and font sizes;
  - write `docs/ui-redesign/CHECKLIST.md` with one row per game;
  - run analyze, the tests and both debug builds;
  - list what could not be tested.

For each game:
- Restyle its view and painter to its UI_SPEC section 5 entry.
- Use the shared kit: header, score cards or split-screen kit, banners, overlay chips, scene frame.
- Add the key-moment feedback listed for it: announcement + sound + haptic.
- Fill the result extras (score line, hero, row detail) where it tracks real stats.
- Check every mode it supports: local, vs computer (`bot`), take turns (`turns`), teams (`teamVariant`), and the online view (`RelaySpec.view`).

## Already done (reuse these, don't rebuild them)
- **Tokens / theme:**
  - `lib/core/ui/tokens.dart` and `app_theme_ext.dart`; read them with `context.tk`.
  - Fonts: `Fonts.display` (Lilita One), `Fonts.body` (Nunito).
  - Palettes: `PlayerPalette`, `NeonPalette`, `FlatPalette`, `Brand`, `StatusColors`; spacing and shape constants `Radii`, `Space`, `Shadows`, `Motion`.
- **Icons:**
  - `lib/core/ui/icons/game_icons.dart`: `GameIcon(GameIcons.x)` and `paintIcon(canvas, icon, rect)`.
  - About 100 icons plus 15 fruit.
- **Materials:** `lib/core/ui/materials/materials.dart`
  - `FeltPainter`, `WoodPainter`, `PaperCard`/`PaperCardPainter`, `CardBack`;
  - `SkyPainter` (day / sunset / night, with hills and trees), `GrassPainter`, `AsphaltPainter`, `WaterPainter`, `CourtPainter`.
- **Game kit:** `lib/core/ui/game_kit.dart`, exported from `components.dart`.
  - Buttons and controls: `GoldButton`, `KitButton`, `RoundButton`, `PillSwitch`.
  - Score cards: `PlayerScoreCard`, `PlayerScoreRow`, `RoundBoxes`, `Pips`, `EdgeTag`.
  - Scene pieces: `OverlayChip`, `MeterBar`, `SceneFrame`, `CountdownOverlay`, `ConnectionBanner`.
  - Effects: `FeedbackLayer` / `GameFeedback` (pop, announce, flash, shake, confetti), `ConfettiBurst`.
  - Page pieces: `PageHeader`, `SectionHeader`, `KitChip`, `KitField`, `AppPage`, `shareText`.
  - Text helpers: `stripEmoji`, `ruleSpan`, `nameColor`.
- **Components:**
  - `TurnBanner` (in `components.dart`) has kinds turn / success / miss (with `drain`) / info.
  - `PlayerBadge` is in `components.dart` too.
- **Shell:** `lib/features/local_games/shell/`
  - `game_intro.dart`, `pause_sheet.dart`, `how_to_play.dart`, `result_screen.dart`.
  - `ResultExtras` via `ResultScope.of(context)`: set `subtitle`, `hero`, `detail`, `label`. Wrap closures in parentheses inside a cascade.
  - `game_art.dart`: per-game icon / ground / tile art, and `gameScenes` to register a custom intro scene.
  - `local_game_shell.dart`: `PauseButton`, `HelpButton`, `LeaveGameScope`, and a `FeedbackLayer` around every game.
- **HUD helpers:** `shell/game_hud.dart`
  - `ScoreHud` (top bar + score cards), `DiceTray`, `BoardFrame` (wood).
  - `MomentWatcher<T>` + `keyMoment(fx, 'TEXT', sub:, sound:, ...)` turn a state change into an announcement, sound and buzz.
  - `possessive(name)` gives "Your" or "Name's" (the lone person is named "You").
- **Party widgets:** `party/party_widgets.dart`
  - `GameTopBar` (pause · title + state line · help), `PartyFrame`;
  - `PassAndReveal`, `PassCover`, `HoldToReveal`, `PromptCard` (paper), `PlayerPicker`, `TimeChip`, `WaitingNote`.
- **Split-screen kit:** `shell/split_screen.dart`
  - `SplitScreen` / `PlayerZones` (`colors:` adds zone tints), `ControlStrip`, `SideTimer`, `ScoreMiddleBar`, `DuelMiddleBar`.
- **Tokens and dice:** `widgets/pawn.dart` (`PawnPainter` dome token), `widgets/dice.dart` (3D die).
- **Finished games, as examples:**
  - B1: Ludo, Snakes & Ladders, Checkers, Connect Four, Tic-Tac-Toe, Dots & Boxes.
  - B2: Memory, Battleship, Bingo, Colour Clash, Raja Mantri. Copy their patterns.
  - The online Raja Mantri screen (`games/raja_mantri/raja_mantri_screen.dart`) still has emoji in its headlines; clean them up in the final pass.

## After every batch
1. `cd mobile && flutter analyze && flutter test` (830 tests at the moment). Update tests only for changed labels; never weaken what a test checks.
2. Render the games and look at the PNGs in `mobile/build/screens/`. The Android emulator cannot boot on this PC (not enough RAM), so use the render tool instead: `flutter test tool/screens_test.dart --plain-name <game_id>`.
3. Both debug builds: `flutter build apk --debug` and `flutter build apk --debug --dart-define=APP_STYLE=flat`.
4. Append an entry to `docs/ui-redesign/PROGRESS.md`. Commit with a clear message ending with the line `Co-Authored-By: <your model> <noreply@anthropic.com>`, then push.

## Gotchas on this Windows machine
- **Shells:** PowerShell 5.1 and Git Bash are both available.
  - Never edit source files with PowerShell `Get-Content` / `Set-Content`: they corrupt emoji and UTF-8. Use the editor tools, or Python with UTF-8.
  - Bash heredocs that contain both quotes and `$` sometimes fail to parse. Write scripts to a file first, then run them.
- **Line endings:** many files use CRLF, so a search/replace that expects `\n` can silently miss. Check that each replace actually happened.
- **Text in widget tests:** the test font draws every character as a wide box, so long `Row`s overflow in tests. Wrap their text in `Flexible` with ellipsis.
- **Overflow checks:** the overflow tests run at 320x568 and at 1.3x text size.
- **Banner heights:** give a compact `TurnBanner` a fixed slot of at least 54 px.
- **Android files:** `mobile/android` is gitignored; to commit a file there, use `git add -f`.

## When everything is done
- Build the release APK: `flutter build apk --release --dart-define=SERVER_URL=https://two-player-online-m9jy.onrender.com`.
- Copy it to `C:\Users\sg857\Desktop\Two Player\PartyGames.apk`.
- Never touch `PartyGamesFlat.apk`.
- Report clearly what could not be tested: online play, Wi-Fi hosting on real phones, the emulator, tablets.
