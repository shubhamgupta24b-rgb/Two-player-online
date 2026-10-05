# UI redesign — audit (Prompt 0)

Branch `feature/ui-redesign`, made from `feature/ui-overhaul` at `8085312`. The overhaul branch
(itself from `feature/memory-game`) already added a token system (`core/ui/tokens.dart`,
`app_theme_ext.dart`), shared components (`core/ui/components.dart`), a settings store,
a real pause, results with a podium, `GameHud` / `GameStatus`, and hold-to-reveal secrets.
This redesign upgrades those in place to `UI_SPEC.md`.

The spec and mockups were delivered in `ui-redesign/` at the repo root. They were moved to
`docs/ui-redesign/`, where the spec expects them.

## Baseline (before any redesign code)

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **816 passed**, 0 failed (30 test files) |

## 1. The 62 games

60 in `localGames` + Guess the Person + Raja Mantri = 62. Ludo 2 vs 2 is Ludo's
`teamVariant`.

**Layout:** Split = players at opposite ends · Whole = one shared view · Pass = hand the
phone around · Turns = has a take-turns mode · Online = has `RelaySpec`.

**Shell widgets used now:** **TP** TickingPlay · **Hud** GameHud · **St** GameStatus ·
**PZ** PlayerZones · **SMB/DMB** Score/Duel middle bar · **PF** PartyFrame/GameTopBar ·
**P&R** PassAndReveal · **PC** PassCover · **PrC** PromptCard · **PP** PlayerPicker ·
**SF** SoloFrame · **Own** own header/HUD.

**Emoji in UI** lists the emoji literals in the game's file (strings shown to the player).
Every game also shows its `LocalGameInfo.emoji` as an icon in the hub and intro.

| # | id | file | layout | shell widgets now | emoji in its UI |
|---|---|---|---|---|---|
| 1 | ludo (+ ludo_teams) | ludo/ludo_game.dart | Whole · Online · Teams | TP, Hud, DiceTray, BoardFrame | ★ 🅰 🅱 🎲 🏆 🏠 🤝 (+ 🏠 💥 in messages from ludo_logic) |
| 2 | snakes_ladders | snakes_ladders/snakes_ladders_game.dart | Whole · Online | TP, Hud, DiceTray, BoardFrame | 🏁 🐍 📍 🪜 |
| 3 | checkers | checkers/checkers_game.dart | Whole (ends) · Online · Turns | TP, Hud, St | ● ⚫ 🏆 👑 🤝 |
| 4 | connect_four | connect_four/connect_four_game.dart | Whole · Online | TP, Hud, St | 🏆 🔴 🤝 |
| 5 | tic_tac_toe | tic_tac_toe/tic_tac_toe_game.dart | Whole · Online | TP, Hud, St | ❌ 🏆 🤝 |
| 6 | dots_boxes | dots_boxes/dots_boxes_game.dart | Whole · Online | TP, Hud, St | 🏆 🔲 🤝 |
| 7 | battleship | battleship/battleship_game.dart | Pass · Online | TP, Hud, St, PC | 🎯 🏆 💥 💦 🔥 🙈 🚢 🛡 |
| 8 | bingo | bingo/bingo_game.dart | Pass · Online | TP, Hud, St, PC | 🎉 🔢 |
| 9 | memory | memory/memory_game.dart | Whole | TP, Hud, St | 🍇 🍉 🍋 🍌 🍍 🍎 🍑 🍒 🍓 🥝 🥥 🥭 (card faces) 🧠 🎉 |
| 10 | colour_clash | colour_clash/colour_clash_game.dart | Pass · Online · Turns | TP, Hud, own hand-off | ⇄ ★ ♣ ♥ ♦ ✓ 🂠 🃏 📱 🤖 (⇄ ★ also in logic labels) |
| 11 | raja_mantri | features/raja_mantri/ | Pass | Own screens | 🃏 🏆 👉 👑 👮 📱 🚨 🚪 🤫 🥇 🥈 🥉 🧠 ♞ 🕵️ ✓ ✗ |
| 12 | guess_person | features/guess_person/ | Pass · own online | Own screens | question icons 👓 🎩 🧔 💇 ♀️ ♂️ …, 🎲 🏆 🔒 🚪 🤝 ⏰ ❌ 🎉 ⏱ |
| 13 | find_spy | find_spy/find_spy_game.dart | Pass · Online | PF, P&R, PrC, PP | 39 location emoji (🏖️ 🏥 🚀 …), 🕵️ 😈 ✅ ❌ |
| 14 | undercover | undercover/undercover_game.dart | Pass · Online | PF, P&R, PrC, PP | ✓ ✅ 🎭 😇 😈 🤝 🤫 |
| 15 | mafia | mafia/mafia_game.dart | Pass · Online | PF, P&R, PrC, PP | ☀️ 🌙 🔪 💉 🔍 🧑 🌾 💀 😴 🎉 😈 🔴 🟢 🤝 ✓ |
| 16 | charades | charades/charades_game.dart (+ party/word_turns.dart) | Pass · Online | PF, PrC | 🎬 (+ ⏱️ ✓ 👏 🔥 🤔) |
| 17 | heads_up | heads_up/heads_up_game.dart (+ word_turns) | Pass · Online | PF, PrC | 🙆 (+ word_turns) |
| 18 | draw_guess | draw_guess/draw_guess_game.dart | Pass · Online | PF, PrC | ✏️ 🎉 🎨 👁 😅 |
| 19 | quiz_battle | quiz_battle/quiz_battle_game.dart | Split · Online | PZ, SMB | 73 uses: category icons 🏏 🎬 🌍 🧠 … and 🇮🇳 |
| 20 | most_likely | most_likely/most_likely_game.dart (+ party/prompt_vote.dart) | Pass · Online | PF, P&R, PP | 👉 👑 (+ 🙋 🤔) |
| 21 | would_rather | would_rather/would_rather_game.dart (+ prompt_vote) | Pass · Online | PF, P&R, PP | 🤔 |
| 22 | truth_dare | truth_dare/truth_dare_game.dart | Whole · Online | TP, Hud | ⭐ 🍾 |
| 23 | hand_cricket | hand_cricket/hand_cricket_game.dart | Split · Online | SMB | ☝️ ✓ 🎯 🏆 🏏 🥎 |
| 24 | rock_paper_scissors | rps/rps_game.dart | Split · Online | PZ, SMB, ZCC | ✊ ✋ ✌️ 🎉 🔒 |
| 25 | crush_it | crush_it/crush_it_game.dart | Split | PZ, DMB, ZCC | 👊 |
| 26 | basketball_hoops | basketball/basketball_game.dart | Split · Turns · Online | PZ, DMB, TurnBar, own pills | 🏀 |
| 27 | fruit_duel | fruit_duel/fruit_duel_game.dart | Split · Turns | PZ, DMB, TurnBar | 🍇 🍉 🍊 🍌 🍍 🍎 🍓 🥝 💥 🔪 ✗ |
| 28 | paint_fight | paint_fight/paint_fight_game.dart | Split · Turns | DMB | 🎨 |
| 29 | air_hockey | air_hockey/air_hockey_game.dart | Split · Turns · Online | DMB | 🏒 |
| 30 | ping_pong | ping_pong/ping_pong_game.dart | Split · Turns · Online | SMB | 🏓 |
| 31 | snake_duel | snake_duel/snake_duel_game.dart | Split · Turns · Online | SMB | ◀ ▶ 🐍 |
| 32 | reaction_tap | reaction_tap/reaction_tap_game.dart | Split · Online | PZ, SMB, ZCC | ⚡ |
| 33 | penalty | penalty/penalty_game.dart | Split · Online | SMB | ⚽ 🧤 🎯 ✓ |
| 34 | math_duel | math_duel/math_duel_game.dart | Split · Online | PZ, SMB, ZCC | 🧮 |
| 35 | smash_karts | smash_karts/smash_karts_game.dart | Split/solo · Turns · Online | Own HUD + controls | ❓ ❤️ 🖤 ⚡ 🎆 🏎️ 💣 💥 🔫 🚀 🛡️ 🥇 🥈 🥉 (weapon labels also in logic) |
| 36 | mini_golf | mini_golf/mini_golf_game.dart | Whole · Online | TP, Hud, St | ⛳ 🐦 |
| 37 | slingshot | slingshot/slingshot_game.dart | Whole · Online | TP, Hud, St | 🐦 🐷 🎉 |
| 38 | archery | archery/archery_game.dart | Whole · Online | TP, Hud, St | 🏹 🌬️ 🎯 🧍 ← → |
| 39 | shooting_gallery | shooting_gallery/shooting_gallery_game.dart | Whole · Online | TP, Hud, own start card | 🦆 🐰 ⭐ 💣 🔫 |
| 40 | bottle_smash | bottle_smash/bottle_smash_game.dart | Whole · Online | TP, Hud, St | 🍾 ⚾ 🎉 |
| 41 | fruit_merge_battle | fruit_merge/fruit_merge_game.dart | Split · Turns · Online | PZ, SMB, ZCC, SF | 11 fruit emoji (also the logic's fruit list), ⏱ → |
| 42 | fruit_merge | fruit_merge/fruit_merge_game.dart | Solo | SF | same fruit emoji |
| 43 | game_2048 | solo/game_2048.dart | Solo | SF | 🔢 |
| 44 | classic_snake | solo/classic_snake.dart | Solo | SF | 🍎 🐍 |
| 45 | flappy_jump | solo/flappy_jump.dart | Solo | SF | 🐦 |
| 46 | minesweeper | solo/minesweeper.dart | Solo | SF | 💣 🚩 💥 ⛏️ ⏱ 🎉 |
| 47 | brick_breaker | solo/brick_breaker.dart | Solo | SF | ❤️ 🧱 |
| 48 | whack_mole | solo/whack_mole.dart | Solo | SF | 🐹 🌟 💣 🔨 ⏱ |
| 49 | piano_tiles | solo/piano_tiles.dart | Solo | SF | 🎹 |
| 50 | word_scramble | solo/word_scramble.dart | Solo | SF | 🔤 ⏱ |
| 51 | stack_tower | solo/stack_tower.dart | Solo | SF | 🏗️ ✨ |
| 52 | simon_says | solo/simon_says.dart | Solo | SF | 👀 👆 🟢 ❌ |
| 53 | ball_sort | solo/ball_sort.dart | Solo | SF | 🧪 ↶ ↻ 🏁 🎉 |
| 54 | sliding_puzzle | solo/sliding_puzzle.dart | Solo | SF | 🔢 🎉 |
| 55 | sudoku | solo/sudoku.dart | Solo | SF | 📝 ✏️ ❌ ⏱ 🎉 |
| 56 | hangman | solo/hangman.dart | Solo | SF | ❤️ 🪢 💀 🎉 + category emoji 🎬 🏏 🌍 🍛 🐾 🏙️ |
| 57 | dino_run | solo/dino_run.dart | Solo | SF | 🦖 🌵 🦅 🐦 💥 |
| 58 | block_drop | solo/block_drop.dart | Solo | SF | 🧱 ◀ ▶ |
| 59 | bubble_shooter | solo/bubble_shooter.dart | Solo | SF | 🫧 |
| 60 | sky_jumper | solo/sky_jumper.dart | Solo | SF | 🐸 🟦 🟫 🟨 |
| 61 | space_shooter | solo/space_shooter.dart | Solo | SF | 🚀 👾 👽 🛸 ⚡ ❤️ |
| 62 | color_switch | solo/color_switch.dart | Solo | SF | 🎨 🔘 ⭐ |

**Totals:** 706 emoji literals in 99 files under `lib/`. That includes app screens (home 26,
games list 19, shell 24, lobby 7, privacy 7, records 5) and the legacy server-run screens in
`lib/games/` (guess_who, raja_mantri, game_host).

## 2. Own top bars, scores, results or pause dialogs (not the shell's)

- **Own header / HUD:** Smash Karts (`_Hud`, `_Controls`); Raja Mantri (own table header);
  Guess the Person (`game_header.dart`, `question_panel.dart`); Shooting Gallery (own START
  card over the stall); Colour Clash (own `_Handoff` panel).
- **Own score displays inside the play area:** Truth or Dare seats; Bingo's B-I-N-G-O tiles;
  Basketball zone pills; Quiz Battle / Math Duel per-zone score lines; Penalty kick
  tags.
- **Own result screens:**
  - Raja Mantri: `_finished()` in `rmcs_screen.dart`.
  - Guess the Person: `result_view.dart`.
  - The online game host: `games/game_host_screen.dart` (online round results, party
    standings).
- **Own pause / leave dialogs:** Raja Mantri and Guess the Person (both now use
  `confirmAction`, but not the pause sheet). Every shell game already uses the shell's pause
  sheet.

## 3. Spec vs code: conflicts and gaps

| Spec item | Current code | Plan |
|---|---|---|
| Files under `docs/ui-redesign/` | Delivered in `ui-redesign/` | Moved |
| `context.tokens` | Existing code uses `context.tk` | Add `context.tokens`; keep `tk` as an alias |
| Token values (1.1) | Different values (e.g. flat sky was deepened, `textMuted` #B9BEE8) | Switch to the spec values. Flat text on the sky becomes ink #22212B (passes 4.5:1); white on the spec's sky would not |
| Player palette (1.2): blue, orange, green, purple, pink, yellow / circle, diamond, triangle, rounded square, star, hexagon | blue, vermilion, green, amber, violet, pink / circle, triangle, square, diamond, star, hexagon | Switch to the spec order; add `playerShapeFor(index)` and `PlayerBadge` |
| Fonts Lilita One + Nunito (bundled) | None bundled (Roboto) | Download both OFL families; add as assets |
| Icon set (2.13) and fruit art | None; emoji everywhere | Build `core/ui/icons/game_icons.dart`; port the fruit SVG paths from `mockups/memory` |
| Materials (1.6) | Per-game ad-hoc painters | Build `core/ui/materials/` |
| `PlayerScoreCard`, `SceneFrame`, `OverlayChip`, `CountdownOverlay`, `ResultScreen`, `HowToPlay`, `ControlStrip`, `ConnectionBanner`, `FeedbackLayer` | Partly covered by `GameHud`, `PlayerChip`, `TimerRing`, `AppBanner`, shell `_Result` | Build them; keep the old names as thin wrappers where used |
| Lobby "Share" button | No share package; copy only | Add an Android share intent in `MainActivity` (no new package) |
| ConnectionBanner "A player left (Wait · Continue · End)", "Host left", "Lost Wi-Fi host — switched to online" | The client only knows `SocketManager.connected` and `RoomPlayer.connected`. No server events for continue / end, and no automatic switch to online | Show what the state supports ("X lost connection, waiting…", "Host offline", "Reconnecting…"). The Wait / Continue / End actions need server changes: not done, listed |
| Intro: per-player "Computer" toggle | Shell has a bot count; computers take the last seats | Rows show a Computer switch that moves the people/computer split (people first, as now) |
| Intro: editable player names | Names are generated | Editable in the intro (shell UI state only) |
| Reaction Tap reaction time in ms | Logic doesn't expose times | Show "+1" only (spec allows this) |
| Snakes & Ladders "exact-100 hint", Ludo "TURN LOST", Battleship "SUNK: Cruiser" | Need checking against each logic's messages | Show only what the logic reports |
| ResultScreen per-round detail (e.g. archery arrows) | The shell only receives final scores | Generic rows with totals in the shell. Game-specific detail only where the game's view already has it |
| Tests look for `PLAY`, `🤖 PLAY VS COMPUTER`, `PLAY AGAIN`, `ALL GAMES` | Spec renames to Start / Rematch / All games | Update the widget tests with the new labels |
| Run on the emulator after every phase | The emulator didn't finish booting last time (under 1 GB free RAM) | Try each phase with a smaller emulator. If it fails, review screens rendered by `flutter test` (`tool/screens_test.dart`) and say so |
