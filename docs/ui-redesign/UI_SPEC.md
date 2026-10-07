# Party Games — UI/UX Redesign Spec

This spec covers the Flutter app in `mobile/` on the `feature/memory-game` branch: all 62 games and every app screen. It is written for Claude Code to implement, step by step, using `PROMPTS.md`.

Mockups live in `docs/ui-redesign/mockups/`. Each `*.dc.html` file is the source of one 390×844 phone screen: plain HTML + inline SVG with the exact colours, sizes, radii, fonts and drawings. They are reference files, not runnable pages — read the markup and SVG paths and port them to Flutter widgets and `CustomPainter`s. PNG pictures of the same screens can be exported from the design canvases and dropped next to them.
- `app/` — `Main.dc.html` (Home), `Hub.dc.html` (Games hub), `Intro.dc.html` (game intro), `Lobby.dc.html` (room lobby), `Pause.dc.html` (pause sheet)
- `archery/`, `smash_karts/`, `memory/` — `Before.dc.html` (current UI, for comparison) and the after screens

The mockups set the look. Where a mockup and this text disagree, the mockup wins on looks and this text wins on behaviour. Names, scores and players in mockups are sample data.

---

## 0. Ground rules (apply to every change)

1. **UI layer only.** Do not change game rules, scoring, timing, `LocalGameLogic` subclasses, bots (`shell/bots.dart`, every `bot:`), `TurnsSpec.simulate`, `RelaySpec` `create/save/load/apply/hostAuto` or their JSON keys, `core/lan/*`, `core/network/*`, `core/room`, `core/session`, `core/records`, socket event names, or the server. If a UI change truly needs one of these, stop and list it.
2. **Keep every `LocalGameInfo` id, title and field.** The hub, create-room grid, online rooms and records depend on them.
3. **Keep both flavors working:** default (night) and `--dart-define=APP_STYLE=flat`. Keep `isFlatGame()` behaviour. Section 7 covers the flat flavor.
4. **No new runtime packages.** Draw with `CustomPainter`, `Canvas`, `Path`. Fonts are bundled assets. Don't touch Gradle/AGP/Kotlin/SDK versions.
5. **No emoji in the game UI or HUD.** Replace them with drawn icons from the icon set (2.13). Emoji can stay in data the user never sees as an icon (for example `MemoryLogic.symbols` stays as the internal pair key, but cards draw fruit illustrations).
6. **Player identity = colour + shape**, always both (2.2).
7. After every batch: `cd mobile && flutter analyze && flutter test`. Report what passed, what failed and what could not be run.

---

## 1. Visual direction: "Party Night"

A dark, warm night backdrop (from the logo) with tactile, real-feeling game surfaces on top: felt card tables, wooden boards, paper cards, grass, asphalt, sky. Chunky friendly headings, clean body text, soft depth, satisfying feedback.

### 1.1 Colour tokens — `lib/core/ui/tokens.dart`

| Token | Night | Flat | Use |
|---|---|---|---|
| `bgTop` / `bgMid` / `bgBottom` | `#151A4A` / `#0B0E2E` / `#060820` | `#6BB8E0` / `#4FA3D1` / `#3E8FBF` | screen gradient |
| `surface` | `rgba(255,255,255,0.06)` | `#FFFFFF` | cards, panels |
| `surfaceStrong` | `rgba(255,255,255,0.10)` | `#F2F5F9` | buttons, chips |
| `stroke` | `rgba(255,255,255,0.10)` | `#D9DEE6` | 1–2 px borders |
| `overlay` | `rgba(10,14,40,0.66)` | `rgba(34,33,43,0.72)` | chips over a scene |
| `text` | `#FFFFFF` | `#22212B` | primary text |
| `textMuted` | `#C3C9EE` | `#4A5568` | secondary text (≥4.5:1) |
| `label` | `#AAB2E8` | `#5A6478` | small caps labels |
| `gold` | `#FFC93C` | same | primary action, highlights, "+points" |
| `goldDeep` | `#A87A12` | same | button bottom edge |
| `onGold` | `#1A1440` | same | text on gold |
| `success` | `#2ECC71` | same | health, correct |
| `danger` | `#FF5E5B` | same | miss, wrong, low time |
| `info` | `#2E8BFF` | same | links, neutral highlight |

Keep `AppColors` and `FlatColors` as thin aliases of these tokens so old code compiles while migrating. Expose them through a `ThemeExtension<GameTokens>` and read them with `context.tokens`.

### 1.2 Player colours and shapes

Replace `gpPlayerColors` (`guess_person/models/gp_player.dart`) with this order. Every player marker draws the shape filled with the colour and a 1.5 px white outline.

| Seat | Colour | Shape | Light text tint (on dark) |
|---|---|---|---|
| 1 | `#2E8BFF` blue | circle | `#9CC9FF` |
| 2 | `#FF8A1F` orange | diamond | `#FFD2A8` |
| 3 | `#2ECC71` green | triangle | `#B5F0CD` |
| 4 | `#B07CFF` purple | rounded square | `#DDC9FF` |
| 5 | `#FF5C8A` pink | star | `#FFC2D4` |
| 6 | `#E0A800` yellow | hexagon | `#FFE7A0` |

The text tint is for names drawn on dark overlays.

Add `PlayerShape` (enum) and `playerShapeFor(index)`. Guess the Person uses the same list, so check its screens after the change.

### 1.3 Typography

- Display: **Lilita One** (OFL). Headings, scores, timers, big announcements.
- Body: **Nunito** 600/700/800/900 (OFL). Everything else.
- Bundle both as assets under `mobile/assets/fonts/` with their OFL license files, declare them in `pubspec.yaml`. No runtime font downloading.
- Scale: `display 48/1.0`, `h1 38/1.05`, `h2 26`, `h3 20`, `score 28 tabular`, `body 15/800`, `bodySmall 13/700`, `label 11/800 letter-spacing 0.16em uppercase`, `micro 9–10/900 uppercase` for tags.
- Numbers that change (scores, timers) use `FontFeature.tabularFigures()`.

### 1.4 Spacing, radius, depth

- Spacing scale 4 / 8 / 12 / 16 / 24 / 32. Screen padding 16 horizontal, 14 top, 22 bottom (plus SafeArea).
- Radius 6 (tiles), 10 (cards), 14 (chips, banners), 18 (player cards, buttons), 24 (boards, scene frames), full (round buttons).
- Shadows: small `0 4 10 rgba(0,0,0,0.35)`, large `0 14 34 rgba(0,0,0,0.5)`. Pressable things have a 4–6 px darker "bottom edge" that sinks when pressed (keep the existing `PressableCard` feel).

### 1.5 Motion

- Durations: fast 120 ms, normal 220 ms, slow 360 ms. Curves: `easeOutCubic` standard, `easeOutBack` for pops, `elasticOut` only for the fire button / power-up.
- Announcements ("+1 SMASH!", "BULLSEYE!", "MATCH!") scale 1.6 → 1.0 in 300 ms, hold, fade.
- Respect a new **Reduce motion** setting: replace scale/slide with fades, no confetti, no screen shake.
- Haptics through `HapticFeedback`: `selectionClick` on picks, `lightImpact` on throws/shots, `mediumImpact` on scores/hits, `heavyImpact` on wins. Respect a **Haptics** setting.

### 1.6 Materials library — `lib/core/ui/materials/`

Reusable painters so games share the same realistic surfaces:
- `FeltPainter` — radial green felt (`#136457 → #08332D`), optional wood rim (`#6B4423`, 3 px) and thin gold inner line (`rgba(233,196,106,0.35)`). Card games and board games.
- `WoodPainter` — warm board with subtle grain lines. Ludo, Checkers, Snakes & Ladders, Tic-Tac-Toe, Connect Four frame.
- `PaperCard` — cream `#FFFDF6 → #F5E9D2` face, inner hairline `#E2D3B5`, drop shadow. Any face-up card.
- `CardBack` — indigo `#3B2D9A → #1F1666`, gold lattice at 28 % opacity, gold inner border, centre emblem. Every face-down card in every game.
- `SkyPainter` — day (`#21458A → #5B94D4 → #BFD7EC → #F2D49B`), sunset (`#1D1646 → #5E2C6E → #E0556A → #FFB45E`), night (`#0B0E2E → #151A4A` with stars). Sun, clouds, tree line, far hills helpers.
- `GrassPainter` — gradient `#7FBD50 → #4A8A30` with soft horizontal mowing stripes.
- `AsphaltPainter` — `#565A66 → #30333B`, skid marks, kerbs (red `#E5383B` / white).
- `WaterPainter` — sea `#1B6CA8 → #0E3F6B` with light wave lines (Battleship).
- `CourtPainter` — wood court/table surfaces (Basketball, Ping Pong, Air Hockey).

---

## 2. Shared components — `lib/core/ui/` and `lib/features/local_games/shell/`

Upgrade existing widgets in place where they exist (keep public names); add new ones next to them.

### 2.1 `GameTokens` theme extension
All colours/sizes above. Two instances: night, flat.

### 2.2 `PlayerBadge(index, size)`
Colour + shape marker from 1.2. Optional initial inside (Lilita One, dark ink on light colours).

### 2.3 `PlayerScoreCard`
Used by every turn-based or score game. Rounded 18, `surface` fill, 2 px border.
- Row: `PlayerBadge` 28–30 px, name (Nunito 900 15), score (Lilita 28 tabular) right-aligned.
- Optional second row: progress pips (arrows left, lives, shots), collected items, or per-round boxes.
- States: **active** (border = player colour, 4 px glow ring at 16 %, tinted fill 16 %), **tag** (small pill on the top edge: `AIMING`, `YOUR TURN`, `GO AGAIN`, `UP NEXT`, `MISSED`, `NEXT`, `+10` in gold), **idle**, **out/wrecked** (desaturated, 55 % opacity).
- Layouts: 2 players = 2 columns; 3–4 = one compact row (name 12 px, score 22 px, 58 px tall); 5–6 = 3×2 grid compact.

### 2.4 `TurnBanner`
40–60 px rounded 14–18 panel under the HUD or the scene. Big Lilita line + small Nunito line + optional player badge or gesture icon. Variants: turn (player colour), success (gold), miss (danger with a draining timer bar for the reveal time), info (neutral).

### 2.5 `GameTopBar`
Pause (44 px round glass) · centre label (game name in small caps + state line in Lilita 20, e.g. "Arrow 3 of 5", "6 pairs left", "Round 2 / 3") · help (44 px round, opens How to play). Replace the scattered `PauseButton` rows.

### 2.6 `SceneFrame`
Rounded 24 container with large shadow and 1 px light stroke for any `CustomPaint` scene that does not fill the screen (Archery range, Bottle Smash stall, Mini Golf course…). Overlay chips go inside its corners.

### 2.7 `OverlayChip`
`overlay` fill, 14 radius, 1 px stroke: small caps label (9 px) above a Lilita value, optional icon. For wind, power, angle, ammo, timers on top of scenes.

### 2.8 `PauseSheet` (replaces the current pause dialog)
Bottom sheet over a dimmed game: "Paused" title with the game state line, Resume (gold), Restart, How to play, toggles for Sound, Vibration (haptics) and Reduce motion, Quit game (danger outline, confirm dialog). Settings persist with `shared_preferences`. Mockup: `app/Pause.dc.html`.

### 2.9 `CountdownOverlay`
3 · 2 · 1 · GO in Lilita 120, each number scales 1.4 → 1.0 and fades, ring sweeps around it. Short tick sound per number if sound is on.

### 2.10 `ResultScreen` (replaces `_Result`, `_ResultCard`, `_SoloResult`)
- Hero: winner line "**Name** wins!" (name in their tint) or "It's a draw!", subtitle with the real score and unit ("46 – 40 · 5 arrows each").
- A game-specific hero illustration slot (podium of karts, fan of cards, trophy) — default is a drawn trophy.
- Ranked rows: rank (gold for 1st), badge, name, game-specific detail (per-round boxes, collected items, a bar), total.
- Solo: score, **NEW BEST** badge when it beats `records`, best so far.
- Buttons: **Rematch** (gold, 56 px), **Change players** (outline), **All games** (ghost).
- Only show stats the logic actually tracks.

### 2.11 `HowToPlay`
Opens from intro and pause. One screen: game art header, 3–4 rule steps each with a drawn icon, "Got it" button. Text comes from `LocalGameInfo.rules` (rewrite emoji inline in rules into drawn icon spans).

### 2.12 Split-screen kit (`shell/split_screen.dart`)
- `SplitScreen` / `PlayerZones`: far player's half rotated 180°. Zones get a 2 px top border and 10–24 % tint in the player's colour.
- `ControlStrip(player, children)`: 96–120 px strip at each edge with the player's controls; the top one is rotated 180°.
- `ScoreMiddleBar` / `DuelMiddleBar`: centred bar with both scores and the timer, never overlapping touch zones; text readable from both sides (scores drawn rotated per side).
- Timer on a shared phone runs along the side edge (rotated 90°) so nobody reads it upside down.

### 2.13 Icon set — `lib/core/ui/icons/game_icons.dart`
`CustomPainter` icons (stroke + fill, 24-unit grid) replacing every emoji in game UI:
wind, target, arrow, bow, heart, heart-empty, shield, rocket, triple-rocket, mine, bolt (boost), gun, mystery box, crown, trophy, star, coin, clock, dice faces 1–6, eye (peek), skip, check, cross, refresh, undo, flag, bomb, duck, rabbit, mole, golden mole, alien, ufo, tank, cactus, bird, apple, ladder, snake, rock, paper, scissors, bat, ball, puck, mallet, football, glove, bottle, pig, wood block, stone block, paint brush, pencil, lightbulb (hint), lock, crown-king (checkers).
Fruit illustrations (Memory, Fruit Duel, Fruit Merge): apple, banana, grapes, watermelon, strawberry, kiwi, cherry, mango, peach, pineapple, coconut, lemon, orange, pear, melon (see `memory/` mockups for style).

### 2.14 Pass-the-phone and secret reveal (`party/party_widgets.dart`)
- `PassAndReveal`: full-screen "Pass the phone to **Name**" with their badge, then **press and hold** to reveal the secret (role, word, card hand), release hides it. The previous player's info is never visible on the hand-off screen.
- `PromptCard`: paper card style, large text, category label.
- `PlayerPicker`: chips with badge + name, selected = filled colour with check.
- `WaitingNote`, `TimeChip`: use tokens.

### 2.15 Connection UX (online and LAN)
`ConnectionBanner` at the top, non-blocking: Connecting… / Reconnecting… (spinner) / A player left (Wait · Continue · End) / Host left / Lost Wi-Fi host — switched to online. Never show raw error strings. Uses existing state from `SocketManager`, `RoomManager`, `LanHost` — read only.

### 2.16 Feedback
Score pops (+N floating up in gold), hit flashes, screen shake (≤ 6 px, off with Reduce motion), confetti (≤ 40 particles, off with Reduce motion), all through one `FeedbackLayer` in the shell.

---

## 3. States every game must show

1. **Intro** (shell): game art header, tagline, rules preview, player setup, options (Teams, Take turns, minutes), Start.
2. **Countdown** (if the game is real-time).
3. **Playing**: HUD + scene + clear "whose turn / what to do" line.
4. **Key moments**: score, hit, miss, special (bullseye, swish, smash, bingo, king), each with sound + haptic + announcement.
5. **Waiting** (online): "Waiting for **Name**…" with their badge.
6. **Disconnected** (online/LAN): ConnectionBanner.
7. **Paused**: PauseSheet.
8. **Result**: ResultScreen.

---

## 4. App pages

Mockups in `mockups/app/`. All screens use `GameTopBar`-style headers (back or close 44 px, centred small-caps title), tokens, Lilita/Nunito.

### 4.1 Splash — `features/splash/splash_screen.dart`
Logo (existing `PartyLogoIcon`) centred with a soft blue/red glow, "Party Games" in Lilita 38, line "One phone or many · play anywhere". Fade in 360 ms; no spinner unless loading > 1 s.

### 4.2 Login / Welcome — `features/login/login_screen.dart`
Title "WELCOME!" → "Who's playing?". Name field (filled `surfaceStrong`, 18 radius, gold focus ring, label above), avatar colour row (6 player colours + shapes, pick one), "Play as guest" gold button. "Google sign-in coming soon" as a muted note, not a disabled button.

### 4.3 Home — `features/home/home_screen.dart` (mockup `app/Main.dc.html`)
- Header: greeting "Hi, **Name**" + avatar badge, connection pill (Online / Hosting on this phone / Offline) on the right.
- Hero card "Ready to play?": "62 games · 2–6 players · no internet needed", primary button **Play on one phone** (gold) → Games hub.
- Mode row (3 big tiles, 2 + 1 layout or a horizontal row): **Play online** (Create room / Join room / Quick play), **Same Wi-Fi** (opens the existing `_WifiSearchSheet` restyled: host on this phone / find host / type host IP), **My records**.
- "Featured games" carousel: 5 large tiles with drawn game art (not emoji), name, player count chip.
- "Continue: Play *Archery* again" chip when the hub has a last-played game.
- Footer: Privacy link.

### 4.4 Games hub — `features/local_games/local_games_hub_screen.dart` (mockup `app/Hub.dc.html`)
- Top: title "62 games", search field, category tabs: All · Party · Board · Cards · Action · Solo · Favourites (uses `GameCategory` + solo flag + favourites).
- Player-count filter chips: Any · 2 · 3 · 4 · 5–6.
- Grid 2 columns of `GameTile`: drawn art area (game colour gradient + the game's icon painter), title, player range chip (`2–4`, `SOLO`), star toggle (long-press still works). Pressed = sink.
- "Recently played" row above the grid when not searching.
- Empty search state: "No games match '…'" with a clear button.

### 4.5 Game intro (shell `_Intro`) — `shell/local_game_shell.dart` (mockup `app/Intro.dc.html`)
- Art header 200 px: game scene thumbnail (painter at small size) with the game colour glow.
- Title Lilita 38, tagline.
- "How to play" 3 icon steps (first 3 rules) + "All rules" link → HowToPlay.
- Players: count stepper (min–max from `LocalGameInfo`), list of player rows (badge, editable name, "Computer" toggle when `bot != null`).
- Options when supported: **Teams 2 vs 2** (`teamVariant`), **Play mode** Split screen / Take turns + minutes (`turns`, `turnMinuteOptions`).
- **Start** gold button pinned at the bottom.

### 4.6 Quick play — `features/quick_play/quick_play_screen.dart`
"Quick play": big gold "Any game" card (fastest match), then "Or pick a game" grid of online-capable games (same `GameTile`). Searching state: animated dots + "Finding a room…" + Cancel.

### 4.7 Create room — `features/create_room/create_room_screen.dart` + `game_grid.dart`
"Create a room": room size stepper (2–6) with badges preview, "One room, any game" note, then the game grid filtered to games that fit ("24 games fit 4 players"). Create = gold.

### 4.8 Join room — `features/join_room/join_room_screen.dart`
"Join a room": 6 large letter boxes (Lilita 28, auto-advance, paste support), helper "Ask the host for the 6-letter code on their screen", Join gold button, error inline under the boxes.

### 4.9 Room lobby — `features/lobby/lobby_screen.dart` (mockup `app/Lobby.dc.html`)
- Room code card: letters spaced in Lilita 34, copy + share buttons, "Friends tap Join room and enter this code".
- Players list "Players · 3 / 4": rows with badge, name ("you" tag), host crown icon, READY / waiting state; empty slots dashed "Waiting for a player…".
- Next game card (host can CHANGE) with game art + name.
- Bottom: **Ready** toggle (gold when not ready, success-outlined when ready); host sees **Start** once all are ready. Leave as a ghost button in the header.
- Quick play rooms: "Open to everyone" pill.
- Reconnecting: ConnectionBanner.

### 4.10 Records — `features/records/records_screen.dart`
"My records · saved on this phone": per game rows with game icon, best score (Lilita), "played N · wins M", sorted by last played; empty state with trophy illustration. Link to Privacy.

### 4.11 Privacy — `features/privacy/privacy_screen.dart`
Plain readable page (body 15, max width), "Delete my data on this phone" danger outline button → confirm dialog (Delete in danger, Keep).

### 4.12 Guess the Person — `features/guess_person/screens/*`
Keep its portraits (`person_portrait.dart`). Restyle menu, settings, game, how-to-play with tokens: paper cards for people, felt board behind the grid, question panel as a bottom sheet, `PassAndReveal` for hand-offs, `ResultScreen`. Merge `gp_theme.dart` colours into tokens.

### 4.13 Raja Mantri Chor Sipahi — `features/raja_mantri/*`
Felt table, 4 face-down role cards in `CardBack` style that flip to paper faces with drawn crown (Raja), scroll (Mantri), shield (Sipahi), mask (Chor). Round banner "Round 2 / 5", suspects highlighted, reveal animation, standings with `PlayerScoreCard`s, `ResultScreen`.

---

## 5. Game specs (62)

Each entry: **file** · layout · what to draw · HUD · key moments · emoji to replace. "Split" = `splitScreen: true` (players at opposite ends); "Whole" = one shared view; "Pass" = hand the phone around; "Turns" = take-turns mode exists.

### 5.1 Board games (felt or wood, pieces with depth)

**1. Ludo / Ludo 2 vs 2** — `ludo/ludo_game.dart` (`_LudoPainter`) · Whole · Wood board with inlaid coloured paths and bases in seat colours, cream track squares, star safe squares as drawn stars, glossy dome tokens with shadow and a rim in seat colour plus shape mark on top. 3D dice (`widgets/dice.dart`) rolls with a tumble animation in a tray at the current player's corner. HUD: compact score row = tokens home (4 pips each). Moments: capture (token knocked back with bounce, "CAPTURED!"), token home (sparkle at centre), extra roll pill "ROLL AGAIN", three-6s "TURN LOST". Teams: partner badges linked by a thin line in the score row. Replace: ★.

**2. Snakes & Ladders** — `snakes_ladders/snakes_ladders_game.dart` (`_SnlPainter`) · Whole · Paper-textured 10×10 board, alternating cream/pastel squares, numbers in Nunito 900, drawn wooden ladders and patterned snakes with heads/eyes. Tokens = seat-colour pawns with shape tops; several on one square fan out. Dice tray with 3D dice. Moments: climb (token slides up the ladder), bite (token slides down the snake body path), roll-6 "ROLL AGAIN", exact-100 hint when close. Replace: 🪜 🐍.

**3. Checkers** — `checkers/checkers_game.dart` · Whole, players at opposite ends · Wood board, dark/light squares with grain, pieces as stacked discs with grooves in seat colour, king = crown icon embossed on top. Selected piece lifts (shadow grows), legal moves as soft gold dots, forced captures pulse. Captured pieces stack beside each player's edge. Score cards at both ends (far one rotated). Moments: capture chain, crowning ("KING!"). Replace: 👑.

**4. Connect Four** — `connect_four/connect_four_game.dart` · Whole · Blue moulded frame with round holes over the felt background, discs drop with gravity + bounce, ghost disc above the column under your finger. Winning four glow and connect with a line. Replace: none.

**5. Tic-Tac-Toe** — `tic_tac_toe/tic_tac_toe_game.dart` · Whole · Chalkboard or paper grid; X and O drawn as animated strokes in seat colours (X = player 1, O = player 2, also shapes). Win line drawn across. Match score cards on top. Replace: ❌ ⭕ if used.

**6. Dots & Boxes** — `dots_boxes/dots_boxes_game.dart` (`_DotsPainter`) · Whole · Paper notebook background (faint grid), round dots, hover segment preview, drawn lines in seat colour, claimed boxes filled 25 % with the player's shape centred. Moment: "BOX! Go again".

**7. Battleship** — `battleship/battleship_game.dart` · Pass (one phone) / online · Two 8×8 seas with `WaterPainter`, grey ships drawn top-down (hull, deck details), hits = flame + smoke, misses = white splash ring. Your fleet below small, enemy sea above large. Pass screen between turns with "Don't peek". Moments: hit (shake + "HIT! Fire again"), sunk ("SUNK: Cruiser"), miss.

**8. Bingo** — `bingo/bingo_game.dart` · Pass/online, 2–6 · Each card = paper 5×5 with numbers in Lilita, called numbers stamped with an ink dauber circle in the caller's colour, completed lines drawn as a marker stroke, B-I-N-G-O letters as 5 big tiles that light up gold. Called-number history strip. Moment: "BINGO!" with confetti.

**9. Memory** — `memory/memory_game.dart` · Whole · See mockups `memory/`. Felt table, `CardBack` backs, paper faces with fruit illustrations, matched cards keep face up tinted in owner colour with owner badge, match glow + "MATCH! Go again", mismatch red outline + tilt + draining reveal bar. Player cards show collected fruit. Replace: 🧠 and fruit emoji on cards.

**10. Colour Clash** (UNO-like) — `colour_clash/colour_clash_game.dart` (`_WildPainter`) · Pass/online · Felt table, draw pile (`CardBack`) and discard pile centre with the top card large; your hand fanned at the bottom (hidden until SHOW MY CARDS — use `PassAndReveal`). Cards: rounded paper with colour field, big number/symbol in Lilita, drawn Skip/Reverse/+2/Wild/+4 symbols. Playable cards lift slightly. Current colour ring around the discard pile, direction arrow ring. Opponents shown as seats with card counts. Moments: +2/+4 cards fly to the victim, "ONE!" button pulses gold when you have 2 cards. Replace: ⊘ ⇄.

**11. Raja Mantri Chor Sipahi** — see 4.13.

### 5.2 Party & word games (paper cards, felt, pass-the-phone)

**12. Guess the Person** — see 4.12.

**13. Find the Spy** — `find_spy/find_spy_game.dart` (`_SpyView`) · Pass · Role reveal with `PassAndReveal`: location card (drawn place illustration + name) or "YOU ARE THE SPY" card (dark, magnifier icon). Question phase: timer, player chips, "Who asks whom" arrow. Vote screen: `PlayerPicker`. Spy guess: grid of location cards. Moments: spy caught / spy wins reveal.

**14. Undercover** — `undercover/undercover_game.dart` (`_UcView`) · Pass · Word card reveal (paper card, word large), clue rounds list each player's clue as speech bubbles, vote with `PlayerPicker`, eliminated player card flips to show their word. Final reveal of the undercover word side by side.

**15. Mafia** — `mafia/mafia_game.dart` (`_MafiaView`) · Pass · Night phase: dark navy sky with moon, roles as cards (Mafia mask, Doctor cross, Detective magnifier, Villager house), private actions behind `PassAndReveal`. Day phase: warm sky, "**Name** was taken in the night" or "Nobody died", discussion timer, vote. Moments: night/day transition (sky fade), winner team reveal.

**16. Dumb Charades** — `charades/charades_game.dart` · Pass · Actor sees the movie on a clapperboard-style card (only them, hold to reveal), others see a big 60 s ring timer. GOT IT (success) / SKIP buttons large at the bottom. Turn summary card with movies acted.

**17. Heads Up** — `heads_up/heads_up_game.dart` · Pass, phone on forehead · Huge word in Lilita on a paper card filling the screen (landscape friendly), timer ring, GOT IT/SKIP as full-height side zones (left/right) plus buttons. Green flash on got it, orange on skip. Round summary list.

**18. Draw & Guess** — `draw_guess/draw_guess_game.dart` (`_DrawView`, `_InkPainter`) · Pass/online · Paper sheet canvas with soft shadow, brush colours as paint pots, size slider, eraser, clear. Peek button = eye icon, hold to show the word. Timer ring 75 s. Guessers (online) type in a chat-style bar; correct guesses pop with the guesser's badge. "Who got it?" `PlayerPicker`.

**19. Quiz Battle** — `quiz_battle/quiz_battle_game.dart` · Split 2–4 · Question in the middle (readable from both ends: duplicate rotated), category chip (Bollywood/Cricket/GK… with icons), each player's 4 answer buttons in their zone. Right = success flash + "+1", wrong = lock icon over that player's buttons. First to 7 track per player.

**20. Most Likely To** — `most_likely/most_likely_game.dart` · Pass · Question card "Who is most likely to…" large, secret vote via `PlayerPicker` behind pass screens, reveal with votes stacking as badges onto the winner's card, crown icon awarded. Replace: 👑.

**21. Would You Rather** — `would_rather/would_rather_game.dart` · Pass · Two big choice cards A / B (blue vs orange halves), secret picks, reveal as a split bar with badges on each side, majority side glows gold.

**22. Truth or Dare** — `truth_dare/truth_dare_game.dart` (`_BottlePainter`) · Whole, players around the phone · Felt or wooden floor, a realistic glass bottle (highlights, label) spins with easing and points at a player seat marker placed around the edge. Then two big cards TRUTH (blue) / DARE (orange); prompt on a paper card; Did it (+1) / Skip.

**23. Hand Cricket** — `hand_cricket/hand_cricket_game.dart` · Split 2 · Each half: number pad 1–6 as drawn hand gestures (fingers), secret pick. Middle: stadium scoreboard (runs/balls/target, LED-style digits), reveal shows both hands. OUT = red stamp "OUT!". Innings switch banner.

**24. Rock Paper Scissors** — `rps/rps_game.dart` · Split 2–6 · Each zone three big drawn hand buttons (rock, paper, scissors), "SHOOT!" countdown, reveal all hands with arrows showing who beats whom, points float. Replace: ✊ ✋ ✌️.

### 5.3 Action duels (real-time, split screen or whole scene)

**25. Crush It** — `crush_it/crush_it_game.dart` · Split 2–6 · Each zone a big tactile pad in the player colour; each tap squashes the pad, spawns a crack/burst particle and a +1. Centre: 10 s timer ring and live tap counts. Winner zone glows.

**26. Basketball Hoops** — `basketball/basketball_game.dart` (`_CourtPainter`) · Split (30 s) or Turns · Wood court floor with lines, glass backboard with a red square, orange rim + white net (net swings on score), leather ball with seams and spin, shadow on the floor. Moving hoop after 5 s shows rail. Swipe trail. Moments: "SWISH! +3" (net ripple), "+2" rim in. Score cards per zone.

**27. Fruit Duel** — `fruit_duel/fruit_duel_game.dart` · Split (20 s) or Turns · Three wooden lanes per side, fruit illustrations pop up, slicing draws a blade arc with juice splash in the fruit's colour, halves fall. "+2 FIRST!" / "+1". Speed meter.

**28. Paint Fight** — `paint_fight/paint_fight_game.dart` (`_BoardPainter`, `_PaintBoard`) · Split 2 · Board of cells as wet paint tiles with slight gloss; strokes leave a brush trail; stealing cells shows a splat. Live % bar in the middle (blue vs orange). 25 s timer.

**29. Air Hockey** — `air_hockey/air_hockey_game.dart` (`_TablePainter`) · Split 2 · White glossy table with air holes dot pattern, red centre line, blue goal creases, goals as dark slots, mallets as 3D handles in player colours, puck with motion blur and rim. Goal = light flash on the goal + "GOAL!". First to 5.

**30. Ping Pong** — `ping_pong/ping_pong_game.dart` (`_PongPainter`) · Split 2 · Blue table with white lines and net, paddles as red/black rubber paddles with wooden handles (tinted rim in player colour), white ball with shadow and trail. Speed lines as it speeds up. First to 7.

**31. Snake Duel** — `snake_duel/snake_duel_game.dart` (`_ArenaPainter`) · Split 2 · Dark neon arena grid, glowing light-trail snakes in player colours with bright heads, ◀ ▶ big turn buttons in each control strip. Crash = burst + round banner "Round to Meera". First to 3. Replace: ◀ ▶ as drawn arrows.

**32. Reaction Tap** — `reaction_tap/reaction_tap_game.dart` · Split 2–6 · Each zone a big traffic-light style pad: RED (wait, subtle pulse) → GREEN (go). Early tap = "TOO SOON −1" shake. Fastest gets "+1" and their reaction time in ms if the logic exposes it (otherwise just +1). First to 5.

**33. Penalty Shootout** — `penalty/penalty_game.dart` · Split 2 · Middle: goal with net and posts, keeper silhouette, ball on the spot, grass stripes. Each player's zone: LEFT / MIDDLE / RIGHT big buttons (kicker sees shoot arrows, keeper sees dive arrows). Reveal: ball flies, keeper dives, net bulges or "SAVED!". Kick tracker 5 dots per player + sudden death.

**34. Math Duel** — `math_duel/math_duel_game.dart` · Split 2–4 · Chalkboard middle with the sum (duplicated rotated for the far side), each zone answer tiles (paper style). Wrong = lock on that zone for this sum. First to 7.

**35. Smash Karts** — `smash_karts/smash_karts_game.dart` (`_ParkPainter`, `_Hud`, `_Controls`) · Solo chase cam / Split shared view / online · See mockups `smash_karts/`. Sunset Park, rear-view karts, crates, walls, trees, glowing boxes, boost pads, rockets, mines, explosions, leaderboard with shapes, drawn weapon icons, joystick + glowing FIRE button. Replace: 🚀 🎆 💣 🔫 ⚡ 🛡️ ❤️ ❓ 🥇🥈🥉.

**36. Mini Golf** — `mini_golf/mini_golf_game.dart` (`_CoursePainter`, `_GolfView`) · Whole, take turns · Top-down course: putting green with mowing stripes, wooden walls with bevel, sand traps with grain, water if any, hole with flag (flag in current player colour), ball with dimple highlight and shadow. Drag-back aim: dotted line + power arc. HUD: hole "3 / 6", strokes, par-like "7 − strokes". Moment: "HOLE IN ONE! +6".

**37. Slingshot** — `slingshot/slingshot_game.dart` (`_SlingPainter`, `_SlingView`) · Whole, take turns · Side view, day `SkyPainter`, hills, wooden Y-slingshot with rubber band, round birds (original design, not a copy of any known franchise) in player colour, fort of wood (grain) and stone (cracks after first hit) blocks, green round pigs (original design). Trajectory dots. Moments: block break particles, pig pop "+100", bird bonus "+50". Replace: 🐷.

**38. Archery** — `archery/archery_game.dart` (`_RangePainter`, `_ArcheryView`) · Whole, take turns · See mockups `archery/`. Golden-hour range, drawn archer in player colour, wooden stand + straw target, wind chip + windsock, power/angle chip, aim guide, face-on scoring inset, "BULLSEYE!". Replace: 🧍 🌬️ 🎯.

**39. Shooting Gallery** — `shooting_gallery/shooting_gallery_game.dart` (`_GalleryPainter`) · Whole, take turns · Fairground stall: striped awning, wooden counter, back wall with lights, rows of moving tin targets (duck 10, rabbit 20, star 50, bomb −30) drawn as flat tin cut-outs with hinges that flip down when hit. Crosshair at tap point, 6-bullet magazine display, reload bar. Replace: 🦆 🐰 ⭐ 💣.

**40. Bottle Smash** — `bottle_smash/bottle_smash_game.dart` (`_StallPainter`) · Whole, take turns · Fairground stall shelf, glass bottles (green/brown, highlights, labels) in a pyramid, ball with seams, swipe trail, glass shatter particles. Balls left as 3 icons, round "2 / 4", sliding shelf rail from round 3. Moment: "CLEAR! +3".

**41. Fruit Merge Battle** — `fruit_merge/fruit_merge_game.dart` (`_BoxPainter`) · Split or Turns · Each player's glass jar (wooden base, glass reflections), fruit illustrations scale up through the chain, red danger line that pulses when close, next fruit preview. Merge = pop + juice burst. Live scores in the middle bar.

### 5.4 Solo games (one player, best score)

Common for all solo games: top bar (pause, score in Lilita, best score small), `ResultScreen` solo variant with NEW BEST.

**42. Fruit Merge** — `fruit_merge/fruit_merge_game.dart` · Same jar as 41, full screen, next-fruit preview top right, chain legend strip at the bottom with drawn fruits. Replace fruit emoji.

**43. 2048** — `solo/game_2048.dart` · Warm wooden tray with recessed slots; tiles as chunky rounded blocks with a colour ramp from cream (2) through orange to gold (2048) and Lilita numbers; slide 120 ms, merge pop. Undo not added (logic unchanged).

**44. Classic Snake** — `solo/classic_snake.dart` (`_SnakePainter`) · Grass board with checker shading, snake with scaled body segments, eyes that look in the move direction, apple illustration. D-pad drawn arrows under the board. Replace: 🍎.

**45. Flappy Jump** — `solo/flappy_jump.dart` (`_FlappyPainter`) · Day sky parallax (clouds, city), green pipes with rims and highlights, original round bird character, ground strip scrolling. Score huge at top centre.

**46. Minesweeper** — `solo/minesweeper.dart` (`_MinesView`) · Raised grass tiles (unopened) vs dug soil (opened), numbers in classic colours with Lilita, flags as drawn red flags, mines as drawn bombs with sparkle; dig/flag mode toggle pill. Replace: 🚩 💣.

**47. Brick Breaker** — `solo/brick_breaker.dart` (`_BrickPainter`) · Night arena, glossy bricks in rows of colours with bevel, metal paddle, glowing ball with trail, lives as heart icons. Brick break particles.

**48. Whack-a-Mole** — `solo/whack_mole.dart` · Grass garden, 3×3 dirt holes with rims, original mole character pops with squash/stretch, golden mole glows, bomb with fuse. Mallet hit effect. 30 s timer bar. Replace: 🐹 🌟 💣.

**49. Piano Tiles** — `solo/piano_tiles.dart` (`_PianoPainter`) · Glossy black tiles on ivory lanes, tapped tile fades grey with a ripple, speed indicator. Miss = red flash on the wrong lane.

**50. Word Scramble** — `solo/word_scramble.dart` · Wooden letter tiles (Scrabble-like look, no letter values), tap to move into slots, slots underline, correct = tiles flip gold. Timer 60 s ring, Skip button.

**51. Stack Tower** — `solo/stack_tower.dart` (`_StackPainter`) · Isometric slabs with a gradient colour shift per level, sliced overhang falls off with rotation, "PERFECT" flash when aligned. Sky gradient changes as the tower rises.

**52. Simon Says** — `solo/simon_says.dart` · Four big glossy pads (blue, orange, green, purple) in a round console, lit pad glows and plays its tone, steps counter in the centre hub.

**53. Ball Sort** — `solo/ball_sort.dart` · Glass test tubes with reflections on a wooden rack, glossy balls, lifted ball hovers above the selected tube, pour animation arc. Undo / Restart / Done as icon buttons.

**54. Sliding Puzzle** — `solo/sliding_puzzle.dart` · Wooden frame, numbered wooden tiles with bevels, slide 120 ms. Moves counter. 3×3 then 4×4 banner.

**55. Sudoku** — `solo/sudoku.dart` · Paper grid, thick 3×3 lines, given numbers ink-dark, entered numbers blue, notes small grey, selected row/column/box tinted, mistakes red with heart icons for the 3 lives. Number pad below as paper keys, Notes toggle with pencil icon. Replace: ✏️.

**56. Hangman** — `solo/hangman.dart` (`_GallowsPainter`) · Chalkboard scene with a chalk-drawn gallows and figure (drawn stroke by stroke per wrong guess), category chip, word slots, keyboard as chalk keys (used = greyed, wrong = red cross). Lives as hearts.

**57. Dino Run** — `solo/dino_run.dart` (`_DinoPainter`) · Desert at dusk: sand, distant mesas, cacti with shading, original dino character with run cycle, birds flapping. Distance in metres top right. Replace: 🌵.

**58. Block Drop** — `solo/block_drop.dart` (`_BoardPainter`, `_NextPainter`) · Dark well with faint grid, bevelled glossy blocks per piece colour, ghost piece outline, next piece panel, line clear flash. Control buttons drawn: ◀ ▶ ⟳ ⤓.

**59. Bubble Shooter** — `solo/bubble_shooter.dart` (`_BubblePainter`) · Night sky, glossy bubbles with highlight, cannon at the bottom, dotted aim line with wall bounce, danger line, swap bubble. Pop = burst ring, falling bubbles drop with gravity.

**60. Sky Jumper** — `solo/sky_jumper.dart` (`_SkyPainter`) · Sky that darkens to space as you climb, clouds, original jumper character, platforms: normal (grass top), moving (blue metal), cracked (stone that crumbles), spring (yellow coil). Height in metres. Replace: 🟦 🟫 🟨.

**61. Space Shooter** — `solo/space_shooter.dart` (`_SpacePainter`) · Deep space parallax stars and a planet, player ship with engine flame, aliens: basic (green bug-like), shooter (purple), tank UFO (3 hits, health pips). Laser bolts, explosions, power-up bolt icon. Lives as ship icons. Replace: 👾 👽 🛸 ⚡.

**62. Color Switch** — `solo/color_switch.dart` (`_SwitchPainter`) · Dark background, spinning segmented rings in 4 bright colours (blue, orange, green, purple to match the player palette), glowing ball, colour-changer orb with 4 quadrants, stars collectible. Replace: 🔘 ⭐.

---

## 6. Online variants

Games with `online:` use the same view in `RelaySpec.view`. In online play:
- "You" tag on the local player's `PlayerScoreCard`.
- Waiting state ("Waiting for **Meera**…") replaces the turn instruction when it isn't your turn.
- ConnectionBanner for reconnects; never block the board for a short reconnect.
- Hidden information (Battleship fleet, card hands, roles) shows only for `me`.

## 7. Flat flavor (`APP_STYLE=flat`)

Same components with the flat token set: sky-blue background with faint question marks (keep `QuestionMarksPainter`), white chunky tiles (`flatTile`), dark name strips, ink text. Games in `flatGames` (memory, charades, heads_up, find_spy, undercover, mafia, most_likely, would_rather, truth_dare) use flat surfaces: white `PaperCard`s on the dark-blue board (`FlatColors.board`) instead of felt; Memory keeps its cartoon faces from `person_portrait.dart`.

## 8. Accessibility and quality bar

- Touch targets ≥ 48 dp. Text contrast ≥ 4.5:1 (3:1 for ≥ 24 px). Text scale 1.3 without overflow.
- Every interactive control has a `Semantics` label; scenes have a short `Semantics` description of the state ("Aarav's turn, wind 3.2 right").
- Player identity never by colour alone (shape badges everywhere).
- 60 fps on a mid-range Android phone: `RepaintBoundary` around scenes and boards, precise `shouldRepaint`, cache `TextPainter`s and static layers (backgrounds, boards) in `Picture`s.
- Phones 360 dp to tablets; portrait for all games; SafeArea and gesture bar respected.
- Sound/haptics/reduce-motion settings respected everywhere.

## 9. Done checklist per game

- [ ] Uses tokens; no hard-coded colours/sizes except named scene palettes at the top of the file.
- [ ] Uses `GameTopBar`/HUD components, `PlayerScoreCard` or split-screen kit, `ResultScreen`, `PauseSheet`, `HowToPlay`.
- [ ] Scene drawn per section 5; no emoji in UI.
- [ ] Key moments have announcement + sound + haptic.
- [ ] Works: local, vs computer (if `bot`), take turns (if `turns`), teams (if `teamVariant`), online (if `online`).
- [ ] `flutter analyze` clean, `flutter test` passes.
