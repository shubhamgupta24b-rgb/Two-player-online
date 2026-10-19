# Clay Games — 22-Game Implementation Tracker

Branch: `feature/clay-games-ui-uno`

This checklist defines the requested 22-game collection and prevents placeholder entries from being counted as complete. A game is **complete** only when its rules, playable UI, scoring/turn handling, local play, and any advertised online mode work; builds and tests must pass.

## Requested collection (22)

| # | Game | Required implementation | Status at start of this pass |
|---:|---|---|---|
| 1 | Tic Tac Toe | 3×3 board, win/draw detection, rematch | Existing module; verify |
| 2 | Connect Four | 7×6 board, legal drops, win/draw detection | Existing module; verify |
| 3 | Chess | Legal moves, check/checkmate/stalemate, promotion, undo/rematch | Not verified; implement/verify |
| 4 | Carrom | Striker/coins, fouls, queen cover, scoring | Existing module; verify |
| 5 | 8 Ball Pool | Turn/foul rules, solids/stripes, 8-ball win/loss | Existing module; verify |
| 6 | Table Tennis | Paddle/ball, serve, rally and match scoring | Existing Ping Pong module; verify |
| 7 | Memory Match | Configurable pairs, matching, turn and score rules | Existing module; verify |
| 8 | Mini Golf | Aim/power, obstacle course, strokes and winner | Existing module; verify |
| 9 | Darts | Aim/throw and a defined scoring mode | Existing module; verify |
| 10 | Air Hockey | Puck/paddles, goals, score and match end | Existing module; verify |
| 11 | Racing | Track, controls, collisions and finish condition | Existing Smash Karts module; verify match to brief |
| 12 | Basketball | Shot control, timer and score | Existing module; verify |
| 13 | Fruit Cut | Swipe slicing, misses, hazards and score | Not satisfied by Fruit Duel; implement separately |
| 14 | Maths Duel | Timed questions, correct-answer score and winner | Existing module; verify |
| 15 | Guess Who / Guess the Person | Secret character, questions/elimination and win condition | Existing Guess Person flow; verify exact requested rules |
| 16 | Backgammon | Board, dice, legal moves, hits, bearing off | Not verified; implement/verify |
| 17 | Checkers | Legal diagonal moves, captures, kings and win condition | Existing module; verify |
| 18 | Battleship | Hidden ship placement, shots, hits/misses and win condition | Existing module; verify |
| 19 | Raja Mantri | Four-player role/scoring round | Existing Raja Mantri flow; verify |
| 20 | Chor Sipahi | Role assignment and scoring as part of Raja Mantri | Covered by Raja Mantri rules, not a separate game unless requested |
| 21 | UNO | Standard deck, draw/play, action cards, UNO call, round scoring | Current entry aliases Colour Clash; not yet an independent UNO implementation |
| 22 | Ludo | Dice, tokens, safe cells, home path and finish | Existing module; verify |

## Implementation and verification gates

- [ ] Clay-style collection screen and navigation verified on web and mobile layouts.
- [ ] Every game opens the intended game, not a misleading alias or placeholder.
- [ ] Rules shown before play match the implemented rules.
- [ ] Turn ownership, scores, end conditions, restart/rematch work.
- [ ] Online games synchronize state and reject out-of-turn/illegal actions.
- [ ] Two-device online smoke test and same-device/offline smoke test.
- [ ] `flutter analyze`, relevant tests, and `flutter build web --release` pass.
- [ ] Render deployment succeeds and the public URL is opened and smoke-tested.

## Important status note

Existing source files are not proof that a game is complete. Do not mark any row complete until the code and the relevant play path have been inspected and tested. The current Render deployment attempt previously failed during Flutter web compilation, so deployment must not be called live until a later deploy succeeds.
