# Party Games design system

How the app's screens are built, for anyone adding or changing a screen. Everything here
lives in `mobile/lib/core/ui/` (tokens and components) and
`mobile/lib/features/local_games/shell/` (the game shell).

## 1. Tokens

`core/ui/tokens.dart` holds the raw scales. `core/ui/app_theme_ext.dart` holds the
flavour-aware set, `GameTokens`, a `ThemeExtension`. Read it with **`context.tk`**.

| Scale | Values | Use |
|---|---|---|
| `Space` | xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 | All padding and gaps |
| `Radii` | sm 8 · md 12 · lg 16 · xl 24 (+ `rSm…rXl` BorderRadius) | Corners |
| `Motion` | fast 120ms · normal 220ms · slow 360ms; `standard`, `emphasized` curves | Animations; always wrap durations in `Motion.of(context, d)` |
| `kTouchTarget` | 48 | Minimum tap size |
| `Brand` | navy, night, deep, blue #2E8BFF, red #FF3B5C, gold #FFC93C, purple, green, ink | The logo palette |
| `StatusColors` | success, warn, danger, info | States |
| `PlayerPalette` | 6 colours + 6 shapes (● ▲ ■ ◆ ★ ⬢) | Player identity |

### Two flavours, one API

- `GameTokens.neon` is the default night look. `GameTokens.flatSet` is the flat app's
  sky-blue board-game look.
- App screens get `appTokens`, which is flat in the flat build. Inside a game, the shell
  wraps flat games (`isFlatGame`) in `TokenScope(flat: true)`.
- Widgets never check `flatStyle` themselves; they read `context.tk`.

### Text pairs and contrast

All pairs pass WCAG 4.5:1, checked by `test/design_tokens_test.dart`.

| Where the text sits | Use |
|---|---|
| Directly on the background or on `glass` | `onBg` / `onBgMuted` (or `t.styles.*`) |
| On `card` / `cardRaised` surfaces | `text` / `textMuted` (or `t.cardStyles.*`) |
| On any coloured fill | `onColor(fill)` for white vs ink; `fillFor(color)` to darken a colour until white text passes |

### Type scale

`t.styles` gives `display` 34, `headline` 26, `title` 18, `body` 15, `bodyStrong`, `label`
12.5 caps, `caption`, `button`, `score` 20 and `scoreLarge` 64. Score styles use **tabular
figures** so numbers don't jump as they change.

### Players are never told apart by colour alone

Every player seat has a shape. `PlayerAvatar`, `PlayerChip`, `TurnBanner`, the score badges
and the board pieces draw it with `PlayerShapePainter`. Seats come from
`PlayerPalette.indexOf(color)` for the default colours.

## 2. Components (`core/ui/components.dart`)

| Component | What it is |
|---|---|
| `AppButton` | Primary / secondary / ghost / danger. 54dp (48 compact). Sinks when pressed, haptic + click. Picks a readable text colour |
| `AppIconButton` | Round, 48dp target, tooltip and semantics label |
| `AppChip` | Selectable choice, 48dp (`round:` for single digits) |
| `AppCard` | Rounded surface: `glass`, `card` or `raised`, optional tint |
| `SectionLabel` | Small caps heading |
| `showAppDialog`, `confirmAction` | Dialogs. Use `confirmAction` for anything destructive |
| `showAppSheet` | Bottom sheet |
| `showToast` | Non-blocking message with a tone (info / success / warn / danger) |
| `AppBanner` | Strip for ongoing states (reconnecting, offline) |
| `EmptyState`, `EmptyState.error` | Friendly empty and error screens. Never show raw errors; run server text through `friendlyError` |
| `Skeleton` | Pulsing placeholder (static with reduce motion) |
| `PlayerAvatar`, `PlayerChip` | Player identity: colour, shape, initial / name, score |
| `TimerRing` | Time-left ring |
| `TurnBanner` | "PLAYER 1'S TURN" pill with the player's shape |
| `RoomCodeDisplay` | Big spaced room code with a copy button |
| `SettingSwitch`, `SettingsPanel`, `showSettingsSheet` | Sound, vibration, reduce motion, player name and colour |
| `haptic(HapticWeight)` | Vibration that respects the setting |
| `Shake` | Wobble for an invalid move (bump `trigger`) |

`GpButton` (Guess the Person's old button) and `GlassIconButton` still exist for their
callers, but they are `AppButton` / `AppIconButton` underneath.

## 3. Building a game screen

A one-device game is a `LocalGameInfo` with a `play:` builder that returns
`TickingPlay(create, builder, onFinished)`. The shell (`LocalGameShell`) provides
everything around it.

**What the shell gives you, for free:**
- the intro (drawn header, rules as steps, player count, modes, teams, vs-computer);
- the 3-2-1 countdown;
- the **pause menu** (resume, restart, how to play, sound, vibration, reduce motion, quit with confirm). **The game clock stops while it is open**;
- results (winner reveal, podium for 3+, score table, solo best and new record);
- rematch and change players;
- take turns (hand-off card, timer ring);
- music, records and haptics.

**What your view should use:**
- **Header:** `GameHud(players:, scores:, turn:, extra:, trailing: HudLabel(...))` for
  turn and score games. `SoloFrame(title:, score:, extra:)` for solo games, which also shows
  your best and a NEW BEST badge. Split-screen duels use `PlayerZones` / `SplitScreen` with
  `ScoreMiddleBar` or `DuelMiddleBar`.
- **Status:** `GameStatus(player:, turnText:, message:)` for "whose turn" and big result
  messages. Dice games use `DiceTray`.
- **Board:** put it in a `RepaintBoundary`, optionally inside a `BoardFrame`. Colours that
  belong to the drawn object (wood, felt, ink) go in a **named const palette at the top of the
  file**, not inline.
- **Secrets:** `PassAndReveal` (a card) or `PassCover` (a whole screen). Both use
  hold-to-reveal and a fully opaque cover.
- **Party prompts:** `PromptCard`, `PlayerPicker`, `TimeChip`, `WaitingNote`.
- **States:**
  - **valid targets:** gold dots;
  - **selected:** a gold ring;
  - **last move:** a lighter square, or a gold line;
  - **win:** a highlight, or a line drawn in;
  - **invalid move:** `Shake` plus `haptic(HapticWeight.heavy)`.
- **Sounds:** only through `GameAudio.sfx(...)`. Haptics only through `haptic(...)` in UI
  code. (Logic classes still call `HapticFeedback` directly; the vibration switch silences
  those at the Android view level.)

## 4. Do / don't

| Do | Don't |
|---|---|
| `context.tk.styles.title` | `TextStyle(color: Colors.white, fontSize: 18, …)` |
| `fillFor(player.color)` under white text | Put white text on a raw player colour (amber and green fail contrast) |
| `Motion.of(context, Motion.normal)` | Hard-code durations, or animate when reduce motion is on |
| `confirmAction(...)` before leaving or deleting | `showDialog(AlertDialog(...))` |
| `showToast(context, friendlyError(err), tone: Tone.danger)` | `SnackBar(content: Text(err))` with raw server codes |
| `AppIconButton` (48dp) | A bare `IconButton` with a 40dp box |
| Shapes and labels next to colours | Colour as the only way to tell players or options apart |
| `FittedBox(fit: BoxFit.scaleDown)` inside fixed-height keys | Fixed-height columns of text (they overflow at large text) |
| In widget tests, pump fixed durations while a game runs | `pumpAndSettle()` on a running game or a spinner (it never settles) |

## 5. Tests that guard the design

| Test | Checks |
|---|---|
| `test/design_tokens_test.dart` | Contrast for both flavours, scales, player palette, `TokenScope`, reduce motion |
| `test/local_games_widget_test.dart` | Every game played at 320×568, 411×914 and 800×1280, plus every player count; any overflow fails |
| `test/text_scale_test.dart` | Every game, the pause menu and the games list at 1.3× text on a 360dp phone |
| `tool/screens_test.dart` + `tool/contact_sheet.ps1 -Match … -Name …` | Renders screens to PNG for review |
| `tool/shell_screens_test.dart` | Renders the countdown, pause menu and results |
