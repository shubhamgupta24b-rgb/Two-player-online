# Claude Code prompts — UI redesign

Run these one at a time, in order, from the repo root in Claude Code. Wait for each to finish, check the report and the app on your emulator, then paste the next one. Every prompt is self-contained.

## Setup (you do this once, in Git Bash)

```bash
cd /path/to/Two-player-online
git fetch origin
git checkout feature/memory-game
git checkout -b feature/ui-redesign
mkdir -p docs/ui-redesign
# copy the downloaded ui-redesign folder contents here:
#   docs/ui-redesign/UI_SPEC.md
#   docs/ui-redesign/PROMPTS.md
#   docs/ui-redesign/mockups/...
git add docs/ui-redesign
git commit -m "Add UI redesign spec and mockups"
claude
```

---

## Prompt 0 — Audit (no code changes)

```text
Read docs/ui-redesign/UI_SPEC.md fully, then look at every file in docs/ui-redesign/mockups/ (they are HTML + SVG reference sources for phone screens, not runnable pages).

Do NOT change any code yet. Audit the Flutter app in mobile/:
1. Confirm the 62 games: 60 in `localGames` (mobile/lib/features/local_games/local_games_hub_screen.dart) plus Guess the Person and Raja Mantri. Make a table: spec number (section 5), id, file, layout (split/whole/pass/turns), which shell widgets it uses now, emoji used in its UI.
2. List every place that builds its own top bar, score display, result screen or pause dialog instead of the shell's.
3. List anything in the spec that conflicts with the current code (a widget name that doesn't exist, a feature the logic doesn't support).
4. Run: cd mobile && flutter analyze && flutter test — record the baseline (pass/fail counts) so later batches can be compared.
Write the audit to docs/ui-redesign/AUDIT.md and summarise it to me.
```

## Prompt 1 — Design system: tokens, fonts, theme

```text
Follow docs/ui-redesign/UI_SPEC.md sections 0, 1 and 2.1–2.2. Rules in section 0 are strict: UI only, no logic/bot/network/relay changes, keep all LocalGameInfo ids, keep both flavors (default and --dart-define=APP_STYLE=flat).

Do:
1. Fonts: download Lilita One and Nunito from Google Fonts (fonts.google.com, "Download family"). Put Lilita One Regular and the static Nunito SemiBold/Bold/ExtraBold/Black TTFs from the zip's static/ folder in mobile/assets/fonts/, with both OFL.txt license files. Declare them in pubspec.yaml (Nunito weights 600/700/800/900).
2. Create mobile/lib/core/ui/tokens.dart with every token in section 1.1 (night + flat), spacing, radii, shadows, motion (1.4, 1.5) and the typography scale (1.3).
3. Create a ThemeExtension<GameTokens> with night and flat instances, wire it into buildAppTheme() in core/ui/app_ui.dart, add a `context.tokens` extension.
4. Turn AppColors and FlatColors into aliases of the tokens so existing code still compiles.
5. Player colours and shapes (1.2): update gpPlayerColors order/values, add PlayerShape enum, playerShapeFor(index), and the PlayerBadge widget (2.2) drawn with CustomPainter.
6. Add a Settings store (shared_preferences, already a dependency) for sound, vibration, reduce motion.
Then run: cd mobile && flutter analyze && flutter test, and flutter build apk --debug and flutter build apk --debug --dart-define=APP_STYLE=flat. Report exact results, compare with the baseline in AUDIT.md, commit with a clear message.
```

## Prompt 2 — Materials and icon set

```text
Follow docs/ui-redesign/UI_SPEC.md sections 1.6 and 2.13. Same rules as section 0.

Create mobile/lib/core/ui/materials/ with FeltPainter, WoodPainter, PaperCard, CardBack, SkyPainter (day/sunset/night with sun, clouds, tree line, hills helpers), GrassPainter, AsphaltPainter, WaterPainter, CourtPainter. Match colours and shapes in the mockups (mockups/memory/Main.dc.html for felt, card back and paper cards; mockups/archery/Main.dc.html for day sky and grass; mockups/smash_karts/Main.dc.html for sunset sky and asphalt).

Create mobile/lib/core/ui/icons/game_icons.dart: a GameIcon widget + painters for every icon listed in 2.13, plus the fruit illustrations. Port the fruit SVG paths from mockups/memory/Main.dc.html (the <g id="f-..."> groups) to Flutter Path code so they look the same. Add the missing fruits (orange, pear, melon) in the same style.

Add a debug-only gallery screen (only reachable in debug builds) that shows every material and icon so I can check them on the emulator. Run analyze + tests, report, commit.
```

## Prompt 3 — Shared game components (shell)

```text
Follow docs/ui-redesign/UI_SPEC.md sections 2.3–2.16 and 3. Same rules as section 0. Upgrade existing widgets in place and keep their public names (PauseButton, SplitScreen, PlayerZones, ScoreMiddleBar, DuelMiddleBar, TurnsPlay, TurnBar, PartyFrame, GameTopBar, PassAndReveal, PromptCard, PlayerPicker, TimeChip, WaitingNote, GameTheme, GameBackground, GlassIconButton, ScorePill).

Build: PlayerScoreCard, TurnBanner, GameTopBar (upgrade), SceneFrame, OverlayChip, PauseSheet (match mockups/app/Pause.dc.html), CountdownOverlay, ResultScreen (replaces _Result, _ResultCard, _SoloResult in shell/local_game_shell.dart; match the Results mockups in mockups/archery, mockups/smash_karts, mockups/memory), HowToPlay, split-screen kit (ControlStrip, rotated far side, side timer), pass-the-phone + press-and-hold reveal, ConnectionBanner (read-only use of existing socket/room/LAN state), FeedbackLayer (score pops, shake, confetti) that respects the Reduce motion and Vibration settings.

Restyle the shell intro (_Intro) to match mockups/app/Intro.dc.html (spec 4.5).

Every game must still start, play and finish after this change even though the games themselves are not restyled yet. Run analyze + tests + both debug builds, then run the app and open 3 games (one split-screen, one turn-based, one solo) to check the intro, countdown, pause sheet and result screen. Take screenshots with `adb exec-out screencap -p > shot.png` and compare with the mockups. Report, commit.
```

## Prompt 4 — App pages

```text
Follow docs/ui-redesign/UI_SPEC.md section 4 (4.1–4.11). Same rules as section 0 — screens only; do not change navigation targets, room/socket/LAN calls, records or auth logic.

Restyle, in this order: splash, login, home (match mockups/app/Main.dc.html), games hub (match mockups/app/Hub.dc.html; add category tabs, player-count filter, recently played, favourites, drawn game tiles — add a small art painter per game id, simple but distinct, using the materials and icons), quick play, create room + game grid, join room (6 letter boxes), room lobby (match mockups/app/Lobby.dc.html), records, privacy, and the restyled Wi-Fi sheet on home.

Check both flavors. Run analyze + tests + both debug builds, then screenshot home, hub, lobby on the emulator and compare with the mockups; fix differences (up to 3 rounds). Report, commit.
```

## Prompts 5–12 — Games, in batches

Use this template for each batch, replacing the batch line. Spec numbers are from section 5.

```text
Follow docs/ui-redesign/UI_SPEC.md section 0 (strict), the shared components already built, and section 5 for each game below. Where a game has mockups (archery, smash_karts, memory in docs/ui-redesign/mockups/), match them closely and port their SVG drawings to CustomPainter.

BATCH: <paste one batch line from below>

For each game:
- Restyle its view/painter to the section 5 description using tokens, materials and icons. No emoji left in its UI.
- Use GameTopBar / PlayerScoreCard / split-screen kit / PassAndReveal / ResultScreen as fits its layout.
- Add the key-moment feedback (announcement + sound via GameAudio + haptic) listed for it.
- Do not change its LocalGameLogic, bot, RelaySpec or rules text meaning.
- Check every mode it supports: local, vs computer (bot), take turns (turns), teams (teamVariant), online view (RelaySpec.view).

After the batch: cd mobile && flutter analyze && flutter test, then run each game on the emulator, screenshot it mid-game, compare with its spec (and mockup if any), fix differences. Report per game: done / issues / what you could not test. Commit the batch.
```

Batch lines:

- **B1 — Board 1:** 1 Ludo (+ Ludo 2 vs 2), 2 Snakes & Ladders, 3 Checkers, 4 Connect Four, 5 Tic-Tac-Toe, 6 Dots & Boxes
- **B2 — Board 2 & cards:** 7 Battleship, 8 Bingo, 9 Memory (mockups/memory), 10 Colour Clash, 11 Raja Mantri Chor Sipahi (spec 4.13)
- **B3 — Party 1:** 12 Guess the Person (spec 4.12), 13 Find the Spy, 14 Undercover, 15 Mafia, 16 Dumb Charades, 17 Heads Up
- **B4 — Party 2:** 18 Draw & Guess, 19 Quiz Battle, 20 Most Likely To, 21 Would You Rather, 22 Truth or Dare, 23 Hand Cricket, 24 Rock Paper Scissors
- **B5 — Action 1:** 25 Crush It, 26 Basketball Hoops, 27 Fruit Duel, 28 Paint Fight, 29 Air Hockey, 30 Ping Pong, 31 Snake Duel, 32 Reaction Tap, 33 Penalty Shootout
- **B6 — Action 2:** 34 Math Duel, 35 Smash Karts (mockups/smash_karts), 36 Mini Golf, 37 Slingshot, 38 Archery (mockups/archery), 39 Shooting Gallery, 40 Bottle Smash, 41 Fruit Merge Battle
- **B7 — Solo 1:** 42 Fruit Merge, 43 2048, 44 Classic Snake, 45 Flappy Jump, 46 Minesweeper, 47 Brick Breaker, 48 Whack-a-Mole, 49 Piano Tiles, 50 Word Scramble, 51 Stack Tower
- **B8 — Solo 2:** 52 Simon Says, 53 Ball Sort, 54 Sliding Puzzle, 55 Sudoku, 56 Hangman, 57 Dino Run, 58 Block Drop, 59 Bubble Shooter, 60 Sky Jumper, 61 Space Shooter, 62 Color Switch

If a batch is too big for one session, split it: run the template with the first half of the line, then the second half.

## Prompt 13 — Final pass

```text
Final check of the UI redesign against docs/ui-redesign/UI_SPEC.md:
1. Search mobile/lib for leftover emoji used as icons in game UI, hard-coded Color(0x…)/Colors.* outside tokens and named scene palettes, and hard-coded fontSize outside the type scale. List and fix them.
2. Go through section 8 (accessibility and quality bar) and section 9 (done checklist) for all 62 games; produce docs/ui-redesign/CHECKLIST.md with one row per game: done / issues.
3. Run cd mobile && flutter analyze && flutter test, flutter build apk --debug, flutter build apk --debug --dart-define=APP_STYLE=flat. Compare with the AUDIT.md baseline.
4. List anything you could not test (online play, LAN/hotspot on real devices, tablets).
Report and commit.
```

## You test by hand at the end

- Two real phones: online room, and Same Wi-Fi (one phone hosts).
- Each split-screen game with two people on one phone.
- Flat flavor build.
- Sound, vibration and reduce-motion toggles.
