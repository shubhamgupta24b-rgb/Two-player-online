# Done on feature/memory-game

Branch tip `c6a55b8`, pushed to `origin/feature/memory-game`. These commits are not on `origin/main` (`3cb7016`).

## Done

- App name is RivalRooms. Flat builds use RivalRooms Flat.
- Home is the room screen: Ready to play?, Create room, Join room, Quick play. Commit `8b8f791`. The air-hockey tabletop start menu is not used. The start images are still listed in `pubspec.yaml`.
- Online leaderboard ranks by wins, then games played, then name. Commit `2a59cd5`. The server counts finished online games only. If that board is empty, the phone shows wins saved on the device and says so. "Playing now" does not change the order.
- Memory card counts 8, 12, 16, 20, 24, 28, and 32 go from room creation through the server. Online Memory rooms are capped at 4 players.
- UI redesign of existing game screens, through the emoji-removal pass `b0a9b41`, is on this branch relative to `origin/main`.

Catalog, counted in source:

- Hub list: 65 games, 24 of them solo. Hub total is 67 with Guess the Person and Raja Mantri. Online catalog: 44.
- Classic Snake, Penalty Shootout, Fruit Duel, Snake Duel, and Crush It are not in the hub or the online catalog.
- Their client source remains. Crush It and Fruit Duel still have dedicated server modules and online screens. Penalty and Snake Duel stay on the relay list. Classic Snake has no server module.

Added in `c6a55b8`, with the bugfixes in that commit:

- Fruit Cut, Chicken Jump, Knife Hit, Sweet Swap (original match-3; title is Sweet Swap), Bike Racing, Hungry Hippos, Tug of War, Carrom, Eight Ball, Minesweeper Race.
- Ball Sort: 50 puzzles each for Easy, Medium, and Hard, dealt by legal pours from a solved board.
- Minesweeper: 3 local tiers. A dug board does not change tier, and locked level buttons stay disabled.
- Hangman has one hint (category, length, first letter).
- Block Drop's play screen has no bottom buttons. Control is swipe and tap.
- Level unlocks use SharedPreferences key `lvl_<id>`.
- Chicken Jump and Knife Hit keep notifying and repainting while they run.
- Hungry Hippos names the unique leader when time runs out. A tie finishes with no named winner.
- Carrom and Eight Ball ignore an illegal or second shot, and moving pieces settle.
- Minesweeper Race does not put the mine seed in the relay state. A guest load clears mines and cannot apply a win.

Server relay list on this branch includes `bike_race`, `hungry_hippos`, `tug_of_war`, `carrom`, `eight_ball`, `minesweeper_race`. Those ids are not in `origin/main`'s relay list. Live Render serves them only after this branch is deployed.

Release APK: `C:\Users\sg857\Desktop\Two Player\PartyGames.apk`, 61,807,817 bytes, 14 Oct 2026 23:02. Same SHA-256 as the release APK in this checkout. The binary contains `https://two-player-online-m9jy.onrender.com`. Checkout is `c6a55b8`.

Checks in the tree for that landing (not re-run for this note): `expansion_test`, relay round-trip and 320×568 layout, catalog counts above, `server/tests/relay.test.js`, and flutter analyze on the edited libraries.

## Not done

- Connect Four, Battleship, Paint Fight, 2048, and Color Switch were not changed by the expansion commit.
- Battleship `save()` still sends both fleets in the one shared relay blob. The board draws an unsunk enemy ship only for your own fleet, at the end, or once it is sunk.
- Colour Clash still allows 2 to 6 players. Raja Mantri is still exactly 4.
- Knife Hit, Hungry Hippos, and Tug of War are implementations in this repo. They do not reference RivalRoom-Clay.
- No `CODEOWNERS` file. The proposed split into smaller pull requests was not opened. One pull request is already open for the whole branch: [#7](https://github.com/shubhamgupta24b-rgb/Two-player-online/pull/7), head `c6a55b8`, not merged.
