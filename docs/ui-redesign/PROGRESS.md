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

## Prompt 4 — app pages (done)

**Changed (spec 4.1–4.11)**
- **Splash:** logo with glow, "Party Games" in Lilita, tagline. It fades in over 360 ms, and a spinner shows only after 1 s.
- **Login:** "Who's playing?" with a live badge preview, a name field (gold focus ring), a row of 6 colour+shape choices (saved to the existing player-colour setting), the gold "Play as guest" button, and the Google note as plain muted text.
- **Home (Main mockup):**
  - greeting with the player badge and a connection pill (Online / Hosting / Wi-Fi host / Offline, tap to retry);
  - indigo hero with drawn dice and cards, and "Play on one phone";
  - 3 mode tiles: Play online opens a sheet with Create / Join / Quick play; Same Wi-Fi runs the existing host/join flow and then the same sheet; My records;
  - "Continue: play X again" (from recent games), the Featured games row and a Privacy link;
  - the Wi-Fi sheet is restyled.
- **Games hub (Hub mockup):**
  - header "62 games", search, category chips (All / Party / Board / Cards / Action / Solo / Favourites) and a players filter (Any / 2 / 3 / 4 / 5–6);
  - recently played row; drawn `GameTile`s with a star button (long-press still works);
  - empty state with a Clear button.
- **Game art:** `shell/game_art.dart` gives each of the 62 games a small art painter: the surface it's played on (felt, wood, paper card, day / sunset / night sky, grass, court, ice, water, track) plus a glow in the game colour and its drawn icon. It is shared by the hub, home, create room, quick play, the lobby, records and the intro header.
- **Create room:** room-size stepper with badge preview, a "N games fit P players" line, the hub-style grid (games that don't fit are dimmed but can still be picked, as before), a bottom sheet, and a gold Create button.
- **Join room:** 6 Lilita letter boxes (paste and auto-advance as before). Errors now show inline under the boxes with a shake, not as a toast.
- **Quick play:** gold "Any game" card, "Or pick a game" grid, and a "Finding a room" dots animation while it searches.
- **Lobby (Lobby mockup):**
  - Leave (danger) · GAME ROOM · settings;
  - indigo code card with letter boxes, Copy and Share;
  - player rows with badge, YOU · HOST tag, crown and READY / NOT READY / OFFLINE pills; dashed empty seats;
  - next-game card with Change; a "Waiting for … to tap Ready" line;
  - gold Start (host) or Ready / "Ready, tap to undo" (guests); Party mode as an outline button;
  - an "Open to everyone" pill for Quick play rooms; `ConnectionBanner` for reconnecting / player left / host left.
- **Records:** totals (games, wins, different), rows with game art, best score in Lilita and "played N · wins M", sorted last-played first; trophy empty state.
- **Privacy:** drawn icons, 15 px body text, the danger-outline delete button, and a Delete / Keep confirm.
- **Kit additions:** `PageHeader`, `SectionHeader`, `KitChip`, `KitField`, `AppPage`, `shareText`. Kit buttons and chips now follow the flat tokens: white tiles with ink text on sky.
- **Share:** the lobby Share button uses a new `share` method on the existing `party/device` channel in `MainActivity` (Android `ACTION_SEND` chooser, no new package). If that fails it copies the code instead.
- **Background:** the night `AppBackground` now uses the spec gradient (#151A4A → #0B0E2E → #060820) with very faint glows.

**Not changed**
- Navigation targets, room / socket / LAN calls, auth and records logic.
- Guess the Person and Raja Mantri screens (spec 4.12–4.13); they are done with the game batches.

**Decision**
- Quick play has no Cancel button while it searches. Cancelling would need a leave-room call after a match lands, which counts as room logic.

**Tests**
- `flutter analyze` is clean and `flutter test` passes 830 tests. The hub, home, create room, lobby, quick play, records, raja hub-entry and login tests were updated to the new labels.
- Debug APKs build for both flavors.

**Could not test**
- The emulator still can't boot (not enough free RAM). Instead, `tool/pages_render_test.dart` rendered all nine pages in both flavors and I compared them with the Main / Hub / Lobby mockups.
- On a real phone: the share sheet, online rooms and Wi-Fi hosting are all untested.

## B1 — Board 1 (done)

**Shared pieces added**
- `ScoreHud`: game top bar + `PlayerScoreRow`.
- `MomentWatcher` and `keyMoment()`: announcement + sound + haptic from a state change.
- `possessive()` ("Your roll" / "Aarav's roll").
- `DiceTray` restyled: player badge, turn line in the player colour, the last event.
- 3D dice: rounded cube with a shaded edge and sunken pips.
- `BoardFrame` is now the shared wood material.
- `widgets/pawn.dart`: glossy dome token with the seat shape on top.

**Per game**
- **Ludo / Ludo 2 vs 2:**
  - wood table with cream inlaid track, seat-coloured bases and paths, drawn star safe squares, a drawn trophy at the centre;
  - dome tokens with shape marks and a gold ring when movable;
  - score cards show tokens home (count + 4 pips), with ROLL / MOVE tags or TEAM A / TEAM B;
  - moments: CAPTURED! (shake), HOME! (confetti), ALL HOME!, TURN LOST, ROLL AGAIN pop;
  - results show tokens-home pips per row.
- **Snakes & Ladders:**
  - paper board with cream and pastel squares and Nunito 900 numbers, a flag on 100;
  - wooden ladders with shadows; tapering patterned snakes with eyes and a tongue;
  - dome tokens; LADDER! and SNAKE! moments, ROLL AGAIN pop.
- **Checkers:**
  - maple and walnut squares with grain inside the wood frame;
  - stacked grooved discs with the seat shape, a crown for kings;
  - picked piece lifts with a gold ring; movable pieces get a white ring, gold when a capture is compulsory; soft gold target dots;
  - score cards at both ends (the far one rotated for the far player) with pieces left, YOUR TURN / MUST CAPTURE tags and a captured-pieces stack;
  - moments: CAPTURE! pop, DOUBLE / MULTI JUMP! (shake), KING! (confetti).
- **Connect Four:** score-card HUD, a gold line drawn through the winning four, FOUR IN A ROW! / DRAW! moments.
- **Tic-Tac-Toe:** chalkboard kept; score cards show each player's X or O; THREE IN A ROW! / DRAW! moments.
- **Dots & Boxes:** notebook kept; claimed boxes at 25 % with the owner's shape (no letter); score cards with box counts; BOX! Go again moment.

**Kept the same:** all `LocalGameLogic`, bots, `RelaySpec` save/load/apply and rules. Only emoji were removed from the Checkers rule text.

**Tests**
- `flutter analyze` is clean and `flutter test` passes 830 tests. `ludo_teams_test` (TEAM A / TEAM B tags) and `bots_test` ("Your roll") were updated.
- Debug builds pass for both flavors.
- Each game was rendered mid-game with `tool/screens_test.dart` (now taps Start and a few spots).

**Could not test**
- Emulator (not enough RAM).
- Online view of these games and two people on one real phone.

## B2 — part 1: Memory, Battleship (done; Bingo, Colour Clash, Raja Mantri still to do)

**Memory** (mockups memory/*)
- Felt card table, `CardBack` backs, paper faces with drawn fruit (the logic keeps its emoji keys; the view maps each to a fruit icon).
- Matched cards are tinted with the owner's colour and badge. The pair just matched glows gold; a wrong pair gets a red outline and a tilt.
- The banner shows "MATCH! +1 pair · X goes again" or "No match" with a draining bar for the reveal time.
- Score cards show the collected fruit, with GO AGAIN / MISSED / NEXT tags.
- Results: "Board clear" label, "N of 12 pairs · P players", a fan of 3 cards as the hero, and a fruit row per player.
- The flat app keeps its cartoon faces.

**Battleship**
- Seas use `WaterPainter`; grey top-down ships with deck and turrets (sunk ones dark).
- Hits are flames with smoke, misses white splash rings, and the last shot is ringed in gold.
- Score cards show ships left (pips), and the turn banner shows Hit / Miss / Sunk.
- Moments: HIT! and SUNK! with shake, MISS pop.

**Also:** compact `TurnBanner` sub-lines are now one line.

**Tests:** analyze clean, 830 tests pass.

## B2 — part 2: Bingo, Colour Clash, Raja Mantri (B2 done)

**Bingo**
- Paper 5×5 card with Lilita numbers.
- Called numbers are stamped with an ink-dauber blot in the caller's colour. The caller is worked out from the call order, since turns go round one by one.
- Completed lines are struck through with a marker stroke.
- B-I-N-G-O letters are 5 big tiles that light up gold.
- Called-number history strip in caller colours; score cards show each player's letters.
- Moments: LINE! and BINGO! (confetti).

**Colour Clash**
- Cards are paper with a colour field and a tilted oval (four colours on wilds).
- Lilita numbers; Skip, Reverse and the wild star are drawn; +2 / +4 in Lilita.
- Drawn suit marks per colour (heart, star, triangle, diamond) replace the ♥★♣♦ text.
- Felt table: a two-card draw pile, and a ring in the current colour with direction arrows around the discard.
- The hand is fanned with playable cards lifted, and the ONE! button pulses gold.
- New colour picker and a pass-the-phone sheet.
- Moments: +2!, +4! (shake), SKIP!, REVERSE!, ONE CARD!
- No emoji left in its UI.

**Raja Mantri Chor Sipahi (spec 4.13)**
- Cards use the shared `CardBack` and paper faces with drawn emblems: crown (Raja), scroll (Mantri), shield (Sipahi), mask (Chor).
- Seats sit on the felt table, with badge + name, a gold points line and a `+N` edge tag after the reveal.
- The headline panel uses drawn icons, the Mantri countdown ring uses Lilita, and the result banner is a success / miss `TurnBanner`.
- Moments: RAJA!, CAUGHT!, ESCAPED! (shake).
- The menu is styled like the game intro: role cards, rule steps, badge + name fields, round chips, gold "Deal the cards".
- Final results use the shared `ResultScreen` (all four role cards as the hero).
- The online Raja Mantri screen (`games/raja_mantri`) shares these widgets. Its headline texts still contain emoji; that's left for the online-variants sweep in the final pass.

**Tests**
- analyze clean, 830 tests pass; `raja_mantri_test` was updated for the new labels.
- Debug builds pass for both flavors.
- Renders: `tool/screens_test.dart` (bingo, colour_clash) and the new `tool/rmcs_render_test.dart`.

## B3 — Party 1 (done)

**Dumb Charades / Heads Up** (`party/word_turns.dart`)
- Ready screen with the player's big badge and "Name's turn".
- Charades: the movie is on a clapperboard card that the actor holds to read.
- Heads Up: the word is huge on a paper card, with full-height Skip (left) and Got it (right) side zones.
- Everyone else sees a big ring timer with the count.
- Got it flashes green with a +1 pop; Skip flashes orange.
- Turn summary uses player score cards.

**Find the Spy**
- Each of the 30 locations has a drawn icon (the logic keeps its emoji keys).
- The location is a paper card; the spy gets a dark "You are the SPY" card with a magnifier.
- Possible locations show as paper chips; the spy's guess is a grid of location cards.
- Result banner; moments: SPY CAUGHT!, SPY WINS!, TOWN WINS! (confetti).

**Undercover**
- Clue rounds show each player in speaking order with a speech-bubble tag.
- The voted-out card flips to show their word.
- The final reveal shows both words side by side.
- Moments: VOTED OUT, CAUGHT! (confetti), UNDERCOVER WINS!

**Mafia**
- Role cards use drawn emblems: mafia mask, doctor cross, detective magnifier, villager house. The mafia card is dark.
- Night happens under a starry sky with a moon; morning under a day sky, cross-fading between them.
- The detective's check is a success / miss banner.
- The final reveal lists every role.
- Moments: NIGHT N, MORNING, MAFIA WINS!, TOWN WINS!

**Guess the Person (spec 4.12)**
- `gp_theme.dart` now uses the tokens:
  - night background (sky with "?" marks in the flat app);
  - felt board under the grid; cream paper person cards (portraits kept);
  - round close button, sheet-coloured panels, badge + name chips.
- `GpButton` is now a chunky Lilita button with a sinking edge. It is shared by the not-yet-redesigned games too, which therefore already get the new button look.
- Hand-off screen with badge and name; how-to-play with drawn step icons.
- Game over uses the shared `ResultScreen`; the final guess is a gold `TurnBanner`.
- Emoji removed from its texts.

**Also:** `PromptCard` gained `icon:` and `dark:`.

**Tests**
- analyze clean, 830 tests pass; the GP widget test was updated (two labels lost their emoji).
- Debug builds pass for both flavors.
- New render tools: `tool/gp_render_test.dart`; word games rendered with `tool/screens_test.dart`.

## B4 — Party 2 (done)

**Most Likely To / Would You Rather** (`party/prompt_vote.dart`)
- The question is a paper card with a drawn icon.
- Would You Rather: two big A (blue) / B (red) choice cards. The reveal is a split bar with the counts, each side's voters as badges, and the majority side glowing gold.
- Most Likely To: the reveal is player rows with the voters' badges stacking in, and a crown for the winners.
- Moments: winner name + confetti, or "A perfect split!".

**Truth or Dare**
- Round table: wood rim around felt.
- A see-through glass bottle with highlights, a paper label and a cork.
- Seat chips with badge + name; the picked player is ringed gold.
- Big TRUTH (blue) / DARE (orange) cards; the prompt is a paper card.
- Skip / "Did it +1" (gold), with a +1 pop.

**Rock Paper Scissors**
- Drawn rock, paper and scissors hands on round buttons in the player's colour, with zone tints.
- The reveal shows a big hand, gold when it wins, plus the other players' hands with their badges.
- SHOOT! moment.

**Hand Cricket**
- Stadium scoreboard with LED-style digits (both scores, innings / target, ball) and pause.
- The number pad is drawn hands showing 1–5 fingers, with a thumbs-up for 6.
- The reveal shows both hands, and an OUT! red stamp.
- Moments: OUT!, SIX!, FOUR!, INNINGS 2.
- Halves scale down on short screens.

**Quiz Battle**
- Category chips: each emoji key is shown as a drawn icon + word (Bollywood, Cricket, India, …).
- Question in Lilita; player-colour answer buttons; a lock over a player's buttons after a wrong answer; first-to-N pips.
- A correct answer flashes green with a "+1 Name" pop.
- Small sideways zones lay out at 270 px tall and scale down.

**Draw & Guess**
- Hold the eye button to peek at the word; a round clear button; a paper sheet with a soft shadow.
- Guesser chips with badges; a typed-guess field for online.
- End banner "The word was…"; moments GOT IT! (confetti) or NOBODY GOT IT.
- Not done: brush colours / sizes / eraser. They would need colour in the stroke data, which changes the logic and the relay JSON, so the pencil stays one colour.

**Tests:** analyze clean, 830 tests pass; debug builds pass for both flavors.

## B5 — Action 1 (Crush It, Basketball Hoops, Fruit Duel, Paint Fight, Air Hockey, Ping Pong, Snake Duel, Reaction Tap, Penalty Shootout)

Checked with render PNGs (`tool/screens_test.dart`); the emulator can't run on this machine. **All B5 games:** zone tints via `PlayerZones(colors:)`, badge headers, Lilita text, no emoji in the UI, gp_theme removed.

**Crush It**
- A squash pad with a hammer icon that springs back on every tap.
- Burst rays and a floating +1 on each tap; the leader's pad glows gold.
- The result subtitle shows the winning tap count.

**Fruit Duel**
- Wooden lanes; drawn fruit replaces the emoji (the logic keeps its emoji keys and maps them to icons).
- A slice shows a blade arc and a juice splash, and the fruit splits into two falling halves.
- "+N" / "MISS" in Lilita.

**Basketball Hoops**
- The existing drawn court is kept. Name badge; Lilita for the clock, SWISH / MISS text and the "Swipe up to shoot" hint.
- The online top bar uses EdgeTags.

**Paint Fight**
- Badge HUD with a big percentage, plus a coverage split bar.
- Painted cells are drawn as overlapping blobs with drops; the empty paper has dot texture.

**Air Hockey**
- The table now leaves room for its rail, so it no longer pokes past the screen edge.
- "GOAL!" in Lilita, in the scorer's colour.

**Ping Pong**
- Lilita point text.

**Snake Duel**
- Chunky player-colour buttons with drawn left/right arrows (they replace ◀ ▶) and semantic labels.
- The arena gets the board radius and a shadow.
- The rule text no longer uses arrow glyphs.

**Reaction Tap**
- A signal lamp with an icon for each state: red with a lock, green with a bolt, gold with a star for the winner.
- Name and score badge; sentence-case calls.

**Penalty Shootout**
- Football, glove, target and check icons replace the emoji.
- KICKER / KEEPER chip with an icon; Lilita titles (GOAL! / GREAT SAVE! in gold); zone semantics.

**Tests:** analyze clean, 830 tests pass (two tests now expect the "Swipe up to shoot" copy); debug builds pass for both flavors.

## B6 — Action 2 (Math Duel, Smash Karts, Mini Golf, Slingshot, Archery, Shooting Gallery, Bottle Smash, Fruit Merge Battle)

Checked with render PNGs; the emulator can't run on this machine.

**Math Duel**
- A chalkboard card shows the sum; each zone has chunky answer buttons with an edge.
- A wrong answer puts a lock over that zone; first-to-7 pips.
- A correct answer flashes green with a "+1 Name" pop.
- Zone tints; small zones scale down from a 250 px design height.

**Smash Karts**
- Every emoji is now a drawn icon: weapons (rocket, triple rocket, mine, gun, bolt, shield) on the karts, in the kill feed, on the FIRE button and on the controls strip; hearts and the mystery box are icons too.
- Rank medals (1/2/3 circles) with player badges.
- Lilita clock and announcements; kit overlay chips.
- Not done: redrawing the park itself (sunset palette, rear-view karts). The existing drawn arena is kept.

**Archery**
- Golden-hour sky and warm hills; mowed-grass stripes.
- A striped windsock that stretches with the wind, and a "WIND n" chip with a drawn arrow.
- A straw target boss; a drawn archer in the shooter's colour (replaces 🧍).
- The range sits in a SceneFrame; the HUD shows "n left" (replaces the bow emoji).

**Shooting Gallery**
- Striped awning with a scalloped edge and chasing bulbs.
- Tin-plate targets with drawn duck / rabbit / star / bomb (replace the emoji); Lilita +/- points.
- Start overlay with badge, "Name's turn" and a gold Start button.
- SceneFrame.

**Bottle Smash**
- Shaded glass bottles with an outline, cork, paper label and highlights.
- SceneFrame; the turn text shows "n balls left" (replaces the emoji).

**Slingshot**
- Birds in the shooter's colour; SceneFrame; "n birds left / n pigs left" text.

**Mini Golf**
- The flag is in the current player's colour; walls get a bevel highlight; SceneFrame.

**Fruit Merge (solo + battle)**
- Drawn fruit icons for the whole chain, cherry to watermelon (the logic keeps its emoji list).
- Glass-jar reflections; badge header; "Box full!" in Lilita.
- Timer label without the emoji.

**Note:** messages that live in logic state and are relayed online (mini golf / slingshot / bottle smash `message`) are unchanged; `GameStatus` strips emoji when it displays them.

**Tests:** analyze clean, 830 tests pass; debug builds pass for both flavors.

## B7 + B8 — Solo games (all 20 in `solo/`, plus Fruit Merge solo from B6)

Checked with render PNGs (a contact sheet of every solo game); the emulator can't run on this machine.

**Shared (`SoloFrame`)**
- An optional `lives` row of drawn hearts (used by Brick Breaker, Hangman, Space Shooter and Sudoku's mistakes).
- The NEW BEST chip has a drawn trophy and uses Lilita.
- All solo titles and subtitles are sentence case with no emoji (timer / flag / heart emoji were replaced with words or icons).

**Drawn art instead of emoji**
- **Dino Run:** a drawn dinosaur with a run cycle and a hurt tint, cactus and bird icons with a wing bob, and a cartoon burst on a crash. Dusk desert sky, mesas and sand; SceneFrame.
- **Space Shooter:**
  - a drawn ship (hull, cockpit, fins) with a two-tone engine flame;
  - alien icons (purple-tinted shooters), UFO tanks with 3 health pips, and a glowing bolt power-up;
  - a ringed planet; SceneFrame.
- **Sky Jumper:** a drawn green hopper with big eyes.
- **Classic Snake:** a checkered lawn, a blue snake and a drawn apple.
- **Color Switch:** a drawn star.
- **Whack-a-Mole:** mole, golden mole (glowing) and bomb icons.
- **Minesweeper:** drawn bomb and flag in the cells, Lilita numbers, and a Dig / Flag pill toggle with icons.
- **Sudoku:** pencil icon on the Notes key.

**Restyled**
- **2048:** wooden tray; tiles ramp from cream through orange to gold; Lilita numbers.
- **Sliding Puzzle:** dark wooden frame; light wooden blocks with a bevel; tiles in their home spot get a green edge.
- **Word Scramble:** wooden letter tiles; underlined answer slots that fill with tiles.
- **Simon Says:** a round console with blue / orange / green / purple pads, rounded outer corners, and a centre hub showing the step count.
- **Hangman:** a chalkboard in a wooden frame with a chalk gallows and figure, a category chip, and chalk keys (wrong ones greyed out with a red cross).
- **Ball Sort and Word Scramble buttons:** now KitButton / GoldButton with drawn icons (undo, restart, flag, skip).
- **gp_theme:** no longer used by any solo game.

**Left as is** (they already matched the spec): Block Drop, Brick Breaker, Bubble Shooter, Flappy Jump, Piano Tiles, Stack Tower.

**Note:** Hangman's category keys still contain emoji because they are game data; they are stripped when displayed.

**Tests:** analyze clean, 830 tests pass.
