# UI overhaul report

Branch `feature/ui-overhaul`, started from `feature/memory-game` at `a040aed`.
No game logic, bots, scores, timing rules, `RelaySpec` save/load/apply, LAN, network, room,
session, records or server code was changed. The only change near game time is a UI-level
pause: `TickingPlay` stops its ticker while the pause menu is open, and game time resumes
from the same moment.

## What every game gets from the shared layer

- Tokens and themes for both flavours.
- The new intro, countdown and **real pause menu**: resume, restart, how to play, sound,
  vibration, reduce motion, and quit with confirm.
- Results with a winner reveal, a podium for 3 or more players, a score table, and best /
  new record for solo games.
- Take-turns hand-off cards and a timer ring.
- Hold-to-reveal secrets.
- Player shapes next to colours.
- Haptics that respect the vibration setting.
- Sounds through `GameAudio`.
- 48dp pause and back buttons.

## 1. Checklist (all 62)

"Shared" means the game uses the rebuilt shell and shared widgets, but its own play area
wasn't redrawn.

| # | Game | Batch | Status | Notes |
|---|---|---|---|---|
| 1 | Ludo (+ 2v2) | B1 | Done | GameHud with team letters and tokens home, DiceTray, BoardFrame |
| 2 | Snakes & Ladders | B1 | Done | GameHud, DiceTray, BoardFrame |
| 3 | Checkers | B1 | Done | Wooden frame, shapes on pieces, mirrored status; move animation kept |
| 4 | Connect Four | B1 | Done | Frame on feet, discs fall from the top, shapes on discs, shake on a full column |
| 5 | Tic-Tac-Toe | B1 | Done | Chalkboard, marks drawn in, chalk win line, shake on a taken square |
| 6 | Dots & Boxes | B1 | Done | Notebook page, marker lines, owner shapes, precise repaint |
| 7 | Battleship | B2 | Done | Sea with waves, hulls, splash misses, cell labels, PassCover |
| 8 | Bingo | B2 | Done | Paper ticket, dabber stamps, called strip; the old cover leaked the last card (fixed) |
| 9 | Memory | B2 | Done | GameHud, status, owner shape on matches |
| 10 | Colour Clash | B2 | Done | Suit symbol per colour (colour-blind safe), hold-to-reveal hand-off, 48dp buttons |
| 11 | Raja Mantri Chor Sipahi | B2 | Partial | Shared buttons, chips, confirm, settings, avatars, haptics. Keeps its own flow (not the shell's pause and results) |
| 12 | Guess the Person | B3 | Partial | Theme merged into tokens, shared confirm, sounds and haptics through settings, portraits kept. Keeps its own flow |
| 13 | Find the Spy | B3 | Done (shared) | Party widgets, tokenised chips |
| 14 | Undercover | B3 | Done (shared) | Party widgets |
| 15 | Mafia | B3 | Done (shared) | Party widgets, token prompt text; role colours are a named palette |
| 16 | Dumb Charades | B3 | Done (shared) | word_turns + PromptCard |
| 17 | Heads Up | B3 | Done (shared) | word_turns + PromptCard |
| 18 | Draw & Guess | B4 | Done | Sketchpad paper in a frame, precise ink repaint, 48dp buttons, token guess field |
| 19 | Quiz Battle | B4 | Done (shared) | Haptics and sounds on right / wrong |
| 20 | Most Likely To | B4 | Done (shared) | prompt_vote |
| 21 | Would You Rather | B4 | Done (shared) | Named A/B palette (options also lettered) |
| 22 | Truth or Dare | B4 | Done | Wooden table with felt, avatar seats, GameHud, readable SKIP |
| 23 | Hand Cricket | B4 | Done (shared) | Haptics through settings |
| 24 | Rock Paper Scissors | B4 | Done | 84dp hands; lock state that doesn't reveal the pick |
| 25 | Crush It | B5 | Done (shared) | Middle bar with shape badges |
| 26 | Basketball Hoops | B5 | Done (shared) | Take-turns bar with timer ring |
| 27 | Fruit Duel | B5 | Shared | Lanes not redrawn |
| 28 | Paint Fight | B5 | Shared | Painter already drawn with precise repaint |
| 29 | Air Hockey | B5 | Done | Rink with rail, ice and holes, markings, 3D mallets |
| 30 | Ping Pong | B5 | Done | Tournament table, net and posts, bats with handles |
| 31 | Snake Duel | B5 | Done | Checkered arena, shaded snakes with eyes |
| 32 | Reaction Tap | B5 | Shared | |
| 33 | Penalty Shootout | B5 | Done (shared) | Tag and goal buttons fit small phones and large text |
| 34 | Math Duel | B6 | Shared | Score chips still float apart from the middle bar |
| 35 | Smash Karts | B6 | Shared | Own HUD kept (most hard-coded colours in the app) |
| 36 | Mini Golf | B6 | Done | GameHud (hole), GameStatus |
| 37 | Slingshot | B6 | Done | GameHud (fort), GameStatus |
| 38 | Archery | B6 | Done | GameHud (arrows left), GameStatus |
| 39 | Shooting Gallery | B6 | Done | GameHud with timer ring, shared START, cartridge strip |
| 40 | Bottle Smash | B6 | Done | GameHud (round), GameStatus |
| 41 | Fruit Merge Battle | B6 | Shared | |
| 42–62 | 21 solo games | B7/B8 | Done (SoloFrame) | Best score and NEW BEST badge in the header for all 21 |
| | Hangman | B8 | Done | Keys 48dp or more, labels, sounds |
| | Sudoku | B8 | Done | Two-row 48dp pad, NOTES as a key, scales with large text |
| | 2048 | B7 | Done | Deeper board, raised tiles |
| | Whack-a-Mole | B7 | Done | Lawn, dirt pits |
| | Simon Says | B8 | Done | Glossy pads in a bezel, stronger lit state |
| | Minesweeper | B7 | Shared | Cells stay under 48dp on 360dp phones (9×9 board); flag mode helps |
| | Other 15 solo games | B7/B8 | Done (SoloFrame) | Play areas unchanged |

**App screens:**
- **Lobby:** big room code with copy, ready / offline states, reconnect and host-away
  banners, confirm on leave.
- **Join, Quick Play, Create Room, Login:** friendly toasts; Join's code boxes shake when a
  join fails.
- **Online play:** connection banners, settings.
- **Home:** settings sheet and toasts.
- **Games list:** settings, drawn tiles.
- **Records, Privacy:** shared buttons and confirm.

## 2. Not finished (plainly)

- **Token migration is incomplete.** Inside many game widgets, colours and font sizes are
  still literals:

  | Count | Before (audit) | Now |
  |---|---|---|
  | `Colors.*` | ~1138 | 1004 |
  | `fontSize:` | ~391 | 372 |
  | `Color(0x…)` | ~688 | 739 |

  `Color(0x…)` went **up**: many of the new ones are named palettes for drawn objects (wood,
  felt, ink), which the brief allows, but not all. Shared chrome uses tokens; the long tail of
  per-game text styles does not yet.
- **Raja Mantri and Guess the Person** keep their own game flows, so they don't use the
  shell's pause menu or results.
- **Visual polish** of the play area was not done for Fruit Duel, Reaction Tap, Math Duel,
  Smash Karts, Fruit Merge Battle, Minesweeper and 15 of the solo games. They do get all the
  shared improvements.
- **Share** for room codes: only copy. Sharing needs a share package (e.g. `share_plus`),
  which I didn't add.
- **Landscape** was not reviewed. **Tablets** are covered only by the 800×1280 playthrough
  test.

## 3. Logic and network changes recommended, not made

1. **A player leaves mid-game: wait / continue / end.** The client can only show "X lost
   connection, waiting…" from `RoomPlayer.connected`. Real choices need server events and
   actions, for example `player_left` with a vote, `continue_without`, and `end_game`.
2. **Host left.** The same: the server should hand host to another player (or end the game)
   and say so in `room_state`, so the UI can show "You are the host now".
3. **Error codes.** `errorMessage()` falls back to "Something went wrong (CODE)". The UI now
   hides the code (`friendlyError`), but the server or `core/room` should send a message for
   every code.
4. **Haptics in logic classes.** About 80 `HapticFeedback` calls live inside `LocalGameLogic`
   classes. The vibration switch silences them at the Android view level. Moving them to the
   UI (or to an injectable callback) would make the setting platform-independent.
5. **Pausing online games.** There is no pause in relay games. It would need a host-side pause
   in each `RelaySpec` (state field + action).
6. **Minesweeper / Sudoku touch size.** A 9×9 board can't reach 48dp cells on a 360dp phone.
   A zoom / pan mode, or a smaller board size option, would need logic support.
7. **`ticking_play` pause.** This was done in the shell. It changes nothing for online play,
   where the host's clock keeps running.

## 4. Commands run and results

All run from `mobile/` unless noted.

| Command | Result |
|---|---|
| `flutter analyze` (after every batch) | No issues found |
| `flutter test` (after every batch) | Passed each time: 754 tests during the batches, **817** at the end (+12 token tests, +63 large-text tests) |
| `npm test` (server/, before the overhaul) | 85/85 passed (server not changed) |
| `flutter test tool/screens_test.dart [--plain-name id]` | Renders reviewed per batch as contact sheets |
| `flutter test tool/shell_screens_test.dart` | Countdown, pause menu and results rendered and reviewed |
| `flutter build apk --debug` | Built `app-debug.apk` |
| `flutter build apk --debug --dart-define=APP_STYLE=flat` | Built `app-debug.apk` (flat) |
| `flutter build apk --release --dart-define=SERVER_URL=…` | Built `app-release.apk` (57.3 MB), copied to `Desktop\Two Player\PartyGames.apk` |

**Not run (needs a real device):**
- 60 fps on a mid-range Android phone;
- the vibration switch actually silencing haptics;
- TalkBack walk-through;
- hotspot / LAN play;
- the online reconnect and host-away banners against a real server drop.
