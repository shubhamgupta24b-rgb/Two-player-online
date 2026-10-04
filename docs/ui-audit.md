# UI audit (Phase 0)

Snapshot of branch `feature/memory-game` at `a040aed`, taken before the UI overhaul.
Screens were rendered with `flutter test tool/screens_test.dart` (411×914) and reviewed as
contact sheets. Counts come from a source scan (`Color(0x…)`, `Colors.*`, `fontSize:` per file).

## Game list check

`localGames` holds 60 shell games. `_entries()` adds Guess the Person and Raja Mantri,
for **62**: 11 board/cards, 13 party/word, 17 action, 21 solo. That matches the brief's list.
Ludo 2 vs 2 (`ludo_teams`) is a `teamVariant` of Ludo, not a separate game. **No mismatches.**

## The 62 games

Shell pieces: **TP** TickingPlay · **PZ** PlayerZones (split screen, 2–6 zones) ·
**SMB/DMB** Score/Duel middle bar · **ZCC** ZoneCenterChip · **PF** PartyFrame/GameTopBar ·
**P&R** PassAndReveal · **PC** PromptCard · **PP** PlayerPicker · **SF** SoloFrame ·
**own bar** = the game builds its own `Row(PauseButton, …)` header and score pills.
Flags: **on** online relay · **bot** computer players · **turns** take-turns mode · **teams** 2 vs 2 · **split** split screen.

| # | id | batch | file | shell pieces | input | players | flags | main visual problems |
|---|---|---|---|---|---|---|---|---|
| 1 | ludo | B1 | ludo/ludo_game.dart | TP, own bar | tap | 2–4 | on, bot, teams | Flat board, no depth; status line small at the bottom; pills duplicate shared scores |
| 2 | snakes_ladders | B1 | snakes_ladders/… | TP, own bar | tap | 2–6 | on, bot | Pastel board is busy; tokens hard to spot; tiny status text |
| 3 | checkers | B1 | checkers/… | TP, own bar | tap | 2 | on, bot, turns | Good board; upside-down status text reads oddly; no last-move mark |
| 4 | connect_four | B1 | connect_four/… | TP, own bar | tap | 2 | on, bot | Large empty space above the board; flat grid; colour-only legend |
| 5 | tic_tac_toe | B1 | tic_tac_toe/… | TP, own bar | tap | 2 | on, bot | Grey glass cells look disabled; lots of empty space |
| 6 | dots_boxes | B1 | dots_boxes/… | TP, own bar | tap | 2–4 | on, bot | Plain dot grid, small hit areas, no paper/board feel |
| 7 | battleship | B2 | battleship/… | TP, own bar, own pass screen | tap | 2 | on, bot | Own pass-the-phone panel (duplicate of P&R) |
| 8 | bingo | B2 | bingo/… | TP, own bar, own pass screen | tap | 2–6 | on, bot | Own pass panel; card hidden behind a dim overlay |
| 9 | memory | B2 | memory/… | TP, own score cards | tap | 2–6 | bot | Decent; own score tiles; no matched-pair flourish |
| 10 | colour_clash | B2 | colour_clash/… | TP, own pills, own pass sheet | tap | 2–6 | on, bot, turns | Most `Colors.*` (26) and font sizes (12) in the board games |
| 11 | raja_mantri | B2 | features/raja_mantri/ | own screens | tap | 4 | — (own online flow) | Separate screens, own theme colours, own result |
| 12 | guess_person | B3 | features/guess_person/ | own theme (gp_theme), own header/result | tap | 2–6 | own online flow | Separate theme system (GpColors/GpCoral) |
| 13 | find_spy | B3 | find_spy/… | PF, P&R, PC, PP | tap | 3–6 | on | Big empty area around the pass card |
| 14 | undercover | B3 | undercover/… | PF, P&R, PC, PP | tap | 3–6 | on | Same as Find the Spy |
| 15 | mafia | B3 | mafia/… | PF, P&R, PC, PP | tap | 4–6 | on | Same; 5 hard-coded colours |
| 16 | charades | B3 | charades/ (+party/word_turns) | PF, PC | tap | 2–6 | on | Prompt card floats mid-screen; buttons far below |
| 17 | heads_up | B3 | heads_up/ (+word_turns) | PF, PC | tap | 2–6 | on | Same as Charades |
| 18 | draw_guess | B4 | draw_guess/… | PF, PC | drag, tap, text | 2–6 | on | 15 `Colors.*`; canvas lacks a paper look |
| 19 | quiz_battle | B4 | quiz_battle/… | PZ, SMB | tap | 2–4 | on, bot, split | Question text cut with "…" on small phones |
| 20 | most_likely | B4 | most_likely/ (+prompt_vote) | PF, P&R, PP | tap | 3–6 | on | Pass card, empty space |
| 21 | would_rather | B4 | would_rather/ (+prompt_vote) | PF, P&R, PP | tap | 2–6 | on | Same |
| 22 | truth_dare | B4 | truth_dare/… | TP, own bar | tap | 2–6 | on | Own header; 13 hard-coded colours |
| 23 | hand_cricket | B4 | hand_cricket/… | SMB | tap | 2 | on, bot, split | Number buttons fine; halves look empty |
| 24 | rock_paper_scissors | B4 | rps/… | PZ, SMB, ZCC | tap | 2–6 | on, bot, split | Small hands; weak "picked" state |
| 25 | crush_it | B5 | crush_it/… | PZ, DMB, ZCC | tap | 2–6 | bot, split | Fine; score numbers colour-only |
| 26 | basketball_hoops | B5 | basketball/… | PZ, DMB, ZCC, own pills | drag | 2–4 | on, bot, turns, split | 25 hard-coded colours |
| 27 | fruit_duel | B5 | fruit_duel/… | PZ, DMB, ZCC | drag | 2–4 | bot, turns, split | Lanes look empty/plain |
| 28 | paint_fight | B5 | paint_fight/… | DMB | drag | 2 | bot, turns, split | Beige grid looks unfinished |
| 29 | air_hockey | B5 | air_hockey/… | DMB | drag | 2 | on, bot, turns, split | Table flat, no rink markings depth |
| 30 | ping_pong | B5 | ping_pong/… | SMB | drag | 2 | on, bot, turns, split | Plain table |
| 31 | snake_duel | B5 | snake_duel/… | SMB | tap | 2 | on, bot, turns, split | Arrow buttons huge, arena plain |
| 32 | reaction_tap | B5 | reaction_tap/… | PZ, SMB, ZCC | tap | 2–6 | on, bot, split | OK |
| 33 | penalty | B5 | penalty/… | SMB | tap | 2 | on, bot, split | 17 `Colors.*` |
| 34 | math_duel | B6 | math_duel/… | PZ, SMB, ZCC | tap | 2–4 | on, bot, split | Score chips float apart from the bar |
| 35 | smash_karts | B6 | smash_karts/… | own HUD | drag, tap | 2–4 | on, bot, turns, split | 48 colours / 49 `Colors.*` (most in the app) |
| 36 | mini_golf | B6 | mini_golf/… | TP, own bar | drag | 1–4 | on, bot | Status text tiny at the bottom; own pills |
| 37 | slingshot | B6 | slingshot/… | TP, own bar | drag | 1–4 | on, bot | Same; scene small on tall phones |
| 38 | archery | B6 | archery/… | TP, own bar | drag | 1–4 | on, bot | Same |
| 39 | shooting_gallery | B6 | shooting_gallery/… | TP, own bar | tap | 1–4 | on, bot | Own START overlay with a stock FilledButton |
| 40 | bottle_smash | B6 | bottle_smash/… | TP, own bar | drag | 1–4 | on, bot | Same as the other batch-3 games |
| 41 | fruit_merge_battle | B6 | fruit_merge/… | PZ, SMB, ZCC, SF | drag, tap | 2–4 | on, bot, turns, split | Jar fine; HUD differs from solo version |
| 42 | fruit_merge | B7 | fruit_merge/… | SF | drag, tap | 1 | — | Good |
| 43 | game_2048 | B7 | solo/game_2048.dart | SF | drag | 1 | — | Muddy brown board |
| 44 | classic_snake | B7 | solo/classic_snake.dart | SF | drag, tap | 1 | — | OK; arrow pad small |
| 45 | flappy_jump | B7 | solo/flappy_jump.dart | SF | tap | 1 | — | OK |
| 46 | minesweeper | B7 | solo/minesweeper.dart | SF | tap, hold | 1 | — | Cells < 48dp on 360dp phones |
| 47 | brick_breaker | B7 | solo/brick_breaker.dart | SF | drag | 1 | — | OK |
| 48 | whack_mole | B7 | solo/whack_mole.dart | SF | tap | 1 | — | Flat holes |
| 49 | piano_tiles | B7 | solo/piano_tiles.dart | SF | tap | 1 | — | OK |
| 50 | word_scramble | B7 | solo/word_scramble.dart | SF | tap | 1 | — | Empty space above letters |
| 51 | stack_tower | B7 | solo/stack_tower.dart | SF | tap | 1 | — | OK |
| 52 | simon_says | B8 | solo/simon_says.dart | SF | tap | 1 | — | Pads flat, no lit state depth |
| 53 | ball_sort | B8 | solo/ball_sort.dart | SF | tap | 1 | — | Good |
| 54 | sliding_puzzle | B8 | solo/sliding_puzzle.dart | SF | tap | 1 | — | Good |
| 55 | sudoku | B8 | solo/sudoku.dart | SF | tap | 1 | — | Number pad keys < 48dp |
| 56 | hangman | B8 | solo/hangman.dart | SF | tap | 1 | — | Keys < 48dp on 360dp phones |
| 57 | dino_run | B8 | solo/dino_run.dart | SF | tap | 1 | — | OK |
| 58 | block_drop | B8 | solo/block_drop.dart | SF | drag, tap | 1 | — | OK |
| 59 | bubble_shooter | B8 | solo/bubble_shooter.dart | SF | drag | 1 | — | Good |
| 60 | sky_jumper | B8 | solo/sky_jumper.dart | SF | drag | 1 | — | OK |
| 61 | space_shooter | B8 | solo/space_shooter.dart | SF | drag | 1 | — | OK |
| 62 | color_switch | B8 | solo/color_switch.dart | SF | tap | 1 | — | OK |

## Duplicated widgets and one-off UI

- **Score pills.** 13 games build the same `Wrap` of coloured `Container`s with the name and score:
  ludo, snakes_ladders, checkers, bingo, colour_clash, tic_tac_toe, dots_boxes, memory, mini_golf,
  slingshot, archery, shooting_gallery, bottle_smash. There is no shared widget for it.
- **Top bars.** Three styles exist: `GameTopBar` (party games), `SoloFrame` (solo games), and a
  hand-built `Row(PauseButton, pills, …)` in 14 games. Smash Karts has its own HUD.
- **Whose-turn line.** `'${p.whose} TURN'` is written by hand in 13 files, in different places
  (top, bottom, or upside down).
- **Pass the phone.** Shared `PassAndReveal` and `TurnsPlay._Card`, plus own versions in
  battleship, bingo and colour_clash ("PASS THE PHONE" appears 10 times in 7 files).
- **Buttons.** `GpButton` (84 uses) is the main one. Also `PressableCard`, 9 `FilledButton`s,
  15 `TextButton`s and an `ElevatedButton`, each styled differently.
- **Dialogs and messages.** 8 `showDialog`s and 6 `AlertDialog`s, each styled inline.
  18 `SnackBar`s with raw text. The shell's leave dialog is only used by the shell.
- **Backgrounds.** Five: `AppBackground`, `GameBackground`, `GpBackground`, `CoralBackground`,
  `FlatBackground`.
- **Themes.** `AppColors`, `FlatColors`, `GpColors`, `GpCoral`, plus per-file literals
  (~688 `Color(0x…)`, ~1138 `Colors.*`, ~391 `fontSize:`).
- **Guess the Person** has its own header, result view, pass screen and player tag.
  **Raja Mantri** has its own screens and result.
- **Performance.** 19 painters return `shouldRepaint => true` and only one `RepaintBoundary`
  exists, so every tick repaints whole subtrees.
- **Feedback.** `HapticFeedback` is called directly in 59 files, mostly inside logic classes, with
  no on/off setting. Sounds already go through `GameAudio`, except 2 `SystemSound` clicks in
  Guess the Person.
- **Accessibility.** The split-screen middle bars show scores as coloured numbers only, and the
  Connect Four legend is colour dots only. Minesweeper, Sudoku and Hangman controls fall below
  48dp on 360dp phones.
