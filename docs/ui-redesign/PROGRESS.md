# UI redesign — progress log

## Prompt 0 — Audit (2026-10-05)

- **What:** wrote `AUDIT.md`:
  - the 62-game table (layout, shell widgets, emoji per game);
  - own bars / results / dialogs;
  - spec-vs-code conflicts and the plan for each.
- **Setup:**
  - moved the delivered `ui-redesign/` folder to `docs/ui-redesign/`;
  - branch `feature/ui-redesign` from `feature/ui-overhaul`.
- **Baseline:** `flutter analyze` no issues; `flutter test` 816 passed, 0 failed.
- **Not tested:** nothing to run on a device in this phase.

## Prompt 1 — Tokens, fonts, theme (2026-10-06)

- **Fonts:** bundled Lilita One (from google/fonts) and Nunito 600/700/800/900 static (Fontsource's
  build of the Google Fonts family, Latin subset) in `mobile/assets/fonts/`, with both OFL licences,
  declared in `pubspec.yaml`. Nunito is the app's default font.
- **Tokens:** `tokens.dart` and `app_theme_ext.dart` now hold the spec 1.1 values for night and flat.
  - Night: bgTop/Mid/Bottom, surface 6%, surfaceStrong 10%, stroke, overlay, textMuted #C3C9EE,
    label #AAB2E8, gold/goldDeep/onGold.
  - Flat: the spec's sky, white surfaces, ink text.
  - Plus the type scale 1.3 (display 48, h1 38, h2 26, h3 20, score 28 tabular, body 15/800,
    bodySmall 13/700, label 11/800, micro 10/900), radii 6/10/14/18/24, shadows and motion.
  - `context.tokens` added; `context.tk` kept as an alias. `AppColors` / `FlatColors` / `GpColors`
    remain aliases.
- **Player identity:** the spec 1.2 palette (blue, orange, green, purple, pink, yellow) with circle,
  diamond, triangle, rounded square, star, hexagon. Added text tints, `playerShapeFor(index)` and
  `PlayerBadge` (shape + 1.5 px white outline + optional initial).
- **Settings store:** sound, vibration and reduce motion already existed (`core/settings/app_settings.dart`,
  `GameAudio`).
- **Deviation:** flat `bgBottom` is `#4494C4` instead of `#3E8FBF`. With the spec value, ink text
  measured 4.46:1, just under the spec's own 4.5:1 rule.
- **Results:**
  - `flutter analyze`: no issues.
  - `flutter test`: 816 passed, 0 failed (baseline 816).
  - `flutter build apk --debug`: built.
  - `flutter build apk --debug --dart-define=APP_STYLE=flat`: built.
- **Not tested on the emulator in this phase:** the PC was low on memory, and the last emulator
  start never finished booting. Tokens only change looks, which later phases screenshot.

## App logo (between prompts 1 and 2, 2026-10-06)

- **What:** the logo pack from `app-logo.zip` is in `docs/app-logo/`.
  - Android launcher icons and adaptive foreground (all densities), background `#241A7A`.
  - `PartyLogoPainter` redrawn from `render_logo.py` (same 1024 grid); its API is unchanged.
  - `logo.png` is the new master.
- **Check:** `tool/logo_render_test.dart` renders the in-app logo. It matches `store/icon_1024.png`.
- **Results:** analyze clean; 816 tests passed.
- **Not tested:** the launcher icon on a device or emulator (only 833 MB of RAM free; the emulator
  can't boot).

## Prompt 2 — Materials and icon set (2026-10-06)

- **`core/ui/icons/svg_path.dart`:** a small SVG path-data parser (M L H V C S Q T A Z,
  absolute and relative), so the mockups' drawings are ported as their original path strings.
- **`core/ui/icons/game_icons.dart`:** `GameIcon` widget and `paintIcon()` for painters.
  - Every icon in spec 2.13: wind, target, arrow, bow, hearts, shield, rocket, triple rocket,
    mine, bolt, gun, mystery box, crown, trophy, star, coin, clock, dice 1–6, eye, skip, check,
    cross, refresh, undo, flag, bomb, duck, rabbit, mole, golden mole, alien, ufo, tank, cactus,
    bird, apple, ladder, snake, rock / paper / scissors, bat, balls, puck, mallet, football,
    glove, bottle, wood / stone block, paint brush, pencil, lightbulb, lock, crown-king.
  - The app icons the mockups use, plus a few the game specs need: magnifier, mask, scroll,
    moon, sun, medical, clapper, speech, arrows.
  - 15 fruit: the 12 in the Memory mockup ported path for path, plus orange, pear and melon in
    the same style.
- **`core/ui/materials/materials.dart`:** `FeltPainter`, `WoodPainter`, `PaperCard` /
  `PaperCardPainter`, `CardBack` / `CardBackPainter` (ported from the mockup's card back),
  `SkyPainter` (day / sunset / night + sun, clouds, hills, tree line helpers), `GrassPainter`,
  `AsphaltPainter` (kerbs, skid marks), `WaterPainter`, `CourtPainter`.
- **`core/ui/debug_gallery.dart`:** every material, badge, icon and fruit on one page. Reachable
  from Settings in debug builds only.
- **Tooling:** render tools now load the bundled fonts. `tool/gallery_render_test.dart` renders
  the gallery; it was reviewed.
- **Results:** analyze clean; 823 tests passed (+7 in `test/game_icons_test.dart`).
- **Not tested:** the gallery on the emulator (not enough free memory); it was reviewed as a
  render instead.

## Prompt 3 — shared game components (done)

**Changed**
- New `core/ui/game_kit.dart` (exported from `components.dart`):
  - `GoldButton`, `KitButton` (outline / ghost / soft / danger), `RoundButton` (44 px, glass or dark), `PillSwitch`, `EdgeTag`;
  - `PlayerScoreCard` + `PlayerScoreRow` (2 / 3–4 compact / 5–6 grid), `RoundBoxes`, `Pips`;
  - `OverlayChip` + `MeterBar`, `SceneFrame`;
  - `CountdownOverlay` (3 · 2 · 1 · GO, ring, tick sound + haptic);
  - `ConnectionBanner` (states only, no new logic);
  - `FeedbackLayer` / `GameFeedback` (pop, announce, flash, shake ≤ 6 px, confetti ≤ 40; shake and confetti off with Reduce motion), `ConfettiBurst`;
  - emoji → drawn icon helpers (`ruleSpan`, `leadingRuleIcon`, `stripEmoji`).
- `TurnBanner` upgraded in place: panel with turn / success / miss (draining bar) / info kinds.
- Shell:
  - new `game_intro.dart`: Intro mockup, with art header, first 3 rules + All rules, players stepper, rows with editable names and per-seat Person / Computer switch (maps to the existing bot count), Teams, Play mode + minutes, Start pinned;
  - `pause_sheet.dart`: Pause mockup;
  - `how_to_play.dart`;
  - `result_screen.dart`: `ResultScreen` replaces `_Result` / `_ResultCard` / `_SoloResult`, plus `ResultExtras` / `ResultScope` so games can add a score line, hero art and per-row detail in their batches;
  - `game_art.dart`: icon per game id, plus a registry for game scene painters.
- `PauseButton` is now a 44 px round button. New `HelpButton`. `LeaveGameScope` also carries help and the state line.
- `GameTopBar` is now pause · small-caps name + Lilita state line · help.
- Party widgets restyled:
  - pass-the-phone hand-off with badge + hold button;
  - paper `PromptCard`;
  - `PlayerPicker` with check;
  - `TimeChip` with clock;
  - `WaitingNote`.
- Split-screen kit:
  - optional zone tints (`colors:`);
  - `ControlStrip`, `SideTimer`;
  - restyled middle bars and centre chip.

**Decisions**
- Hold-to-reveal kept as "hold until full, then shown until Hide & pass". Several secrets need taps (votes, choices), so "release hides" would block them.
- The confirm dialogs for Restart and Quit have no emoji.

**Tests**
- `flutter analyze` is clean, and `flutter test` passes: 830 tests (+7 new in `test/game_kit_test.dart`).
- Intro, vs-computer, teams, take-turns and text-scale tests were updated to the new labels: Start, the players stepper, Computer switches, Rematch / Play again. The new `test/shell_helpers.dart` holds the shared steps.
- Debug APKs build for both flavors (default and `APP_STYLE=flat`).

**Could not test**
- The emulator still can't boot (not enough free RAM). Instead, the screens were rendered to PNG with `tool/shell_render_test.dart` (intro, how to play, pause, 2- and 4-player results, solo result) and compared with the mockups.
- Not tested on a real phone: online play and Wi-Fi hosting.
