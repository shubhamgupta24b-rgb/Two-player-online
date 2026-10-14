# UI redesign checklist

One row per game (62 games). "Done" means: redesigned per UI_SPEC section 5, no emoji drawn as icons in the game UI, kit components and fonts, verified by a render PNG (`tool/screens_test.dart`), analyze clean and all widget tests passing. Device-level checks (touch feel, real-phone online and Wi-Fi play, tablets) are listed at the bottom as not tested.

| # | Game | Batch | Status | Notes |
|---|---|---|---|---|
| 1 | Ludo | B1 | Done |  |
| 2 | Snakes & Ladders | B1 | Done |  |
| 3 | Checkers | B1 | Done |  |
| 4 | Connect Four | B1 | Done |  |
| 5 | Tic-Tac-Toe | B1 | Done |  |
| 6 | Dots & Boxes | B1 | Done |  |
| 7 | Memory | B2 | Done |  |
| 8 | Battleship | B2 | Done |  |
| 9 | Bingo | B2 | Done |  |
| 10 | Colour Clash | B2 | Done |  |
| 11 | Raja Mantri Chor Sipahi | B2 | Done |  |
| 12 | Heads Up | B3 | Done |  |
| 13 | Dumb Charades | B3 | Done |  |
| 14 | Find the Spy | B3 | Done |  |
| 15 | Undercover | B3 | Done |  |
| 16 | Mafia | B3 | Done |  |
| 17 | Guess the Person | B3 | Done (with note) | Attribute question chips still show emoji glyphs (no drawn icons for hair/beard etc. yet). |
| 18 | Most Likely To | B4 | Done |  |
| 19 | Would You Rather | B4 | Done |  |
| 20 | Truth or Dare | B4 | Done |  |
| 21 | Rock Paper Scissors | B4 | Done |  |
| 22 | Hand Cricket | B4 | Done |  |
| 23 | Quiz Battle | B4 | Done |  |
| 24 | Draw & Guess | B4 | Done (with note) | Brush colours / sizes / eraser not added (would change stroke data and relay JSON). |
| 25 | Crush It | B5 | Done |  |
| 26 | Fruit Duel | B5 | Done |  |
| 27 | Basketball Hoops | B5 | Done |  |
| 28 | Paint Fight | B5 | Done |  |
| 29 | Air Hockey | B5 | Done |  |
| 30 | Ping Pong | B5 | Done |  |
| 31 | Snake Duel | B5 | Done |  |
| 32 | Reaction Tap | B5 | Done |  |
| 33 | Penalty Shootout | B5 | Done |  |
| 34 | Math Duel | B6 | Done |  |
| 35 | Smash Karts | B6 | Done (with note) | Park scene not redrawn (sunset palette, rear-view karts); emoji, HUD and controls done. |
| 36 | Mini Golf | B6 | Done (with note) | Relayed status messages keep emoji in state; stripped on display. |
| 37 | Slingshot | B6 | Done (with note) | Relayed status messages keep emoji in state; stripped on display. |
| 38 | Archery | B6 | Done |  |
| 39 | Shooting Gallery | B6 | Done |  |
| 40 | Bottle Smash | B6 | Done (with note) | Relayed status messages keep emoji in state; stripped on display. |
| 41 | Fruit Merge Battle | B6 | Done |  |
| 42 | Fruit Merge | B6 | Done |  |
| 43 | 2048 | B7/B8 | Done |  |
| 44 | Classic Snake | B7/B8 | Done |  |
| 45 | Flappy Jump | B7/B8 | Done | Already matched the spec; text cleanup only. |
| 46 | Minesweeper | B7/B8 | Done |  |
| 47 | Brick Breaker | B7/B8 | Done | Already matched the spec; hearts now drawn. |
| 48 | Whack-a-Mole | B7/B8 | Done |  |
| 49 | Piano Tiles | B7/B8 | Done | Already matched the spec; text cleanup only. |
| 50 | Word Scramble | B7/B8 | Done |  |
| 51 | Stack Tower | B7/B8 | Done | Already matched the spec; text cleanup only. |
| 52 | Simon Says | B7/B8 | Done |  |
| 53 | Ball Sort | B7/B8 | Done |  |
| 54 | Sliding Puzzle | B7/B8 | Done |  |
| 55 | Sudoku | B7/B8 | Done |  |
| 56 | Hangman | B7/B8 | Done (with note) | Category keys are game data with emoji; stripped on display. |
| 57 | Dino Run | B7/B8 | Done |  |
| 58 | Block Drop | B7/B8 | Done | Already matched the spec; text cleanup only. |
| 59 | Bubble Shooter | B7/B8 | Done | Already matched the spec; text cleanup only. |
| 60 | Sky Jumper | B7/B8 | Done |  |
| 61 | Space Shooter | B7/B8 | Done |  |
| 62 | Color Switch | B7/B8 | Done |  |

## App pages

Home, hub, splash, login, create room, join room, quick play, lobby, game grid, records and privacy are redesigned (Prompt 4). Dialogs and empty states now draw icons instead of emoji (final pass).

## Final pass (Prompt 13)

- Emoji used as UI: removed from all game screens, the online Raja Mantri, Guess Who, Fruit Duel and party-results screens, the turns overlay, the settings sheet title, dialogs and empty states. What remains is data (game logic lists, relayed state, the emoji fields of LocalGameInfo used as keys) or lookup tables that turn emoji keys into drawn icons.
- Still emoji on screen: the Guess the Person attribute question chips.
- Hard-coded colours and font sizes: the redesigned screens use kit tokens, `Fonts` and named scene palettes inside painters; scene painters keep their own local palettes on purpose (spec section 4).
- Checks: `flutter analyze` clean; 830 tests pass; debug builds pass for the default and flat flavours; the release APK builds.

## Not tested

- Online play between two real phones, and Same Wi-Fi hosting on real devices.
- Touch feel, haptics and sound on a real phone; split-screen games with two people on one phone.
- Tablets and very small phones beyond the 320x568 and 411x914 test sizes.
- The emulator does not run on this machine, so every visual check used render PNGs instead of a live app.
