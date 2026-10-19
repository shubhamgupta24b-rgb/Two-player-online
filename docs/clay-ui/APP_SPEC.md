# Two Player Games — Clay UI implementation spec

This branch turns the existing Flutter game collection into the soft-clay design shown in the supplied reference. Build the light visual variant with `--dart-define=APP_STYLE=flat` (the branch's light/clay flavor).

## Design system

- Background: warm off-white / pale lavender gradient; very subtle pastel blobs, never high-contrast neon.
- Main text: navy. Secondary text: muted slate.
- Surfaces: white, large 18–28 px corner radii, fine lavender border, soft diffuse shadow.
- Primary action: bright blue rounded pill with white bold label.
- Game tiles: colorful, distinctive illustration in the upper 70%; compact white name strip; no paragraph copy.
- Navigation: compact, familiar back/settings/favourites controls.
- Typography: existing bundled Nunito body and Lilita One display fonts.
- Motion: short, soft press-in and lift transitions; respect reduced-motion settings.

## Gameplay layout contract (all games)

1. Use SafeArea and available screen dimensions. The board/court/table is the largest element on screen.
2. The top row contains only back/pause, game title if needed, and settings/help.
3. Player names, score, timer, and turn state stay visible in a compact HUD; do not hide score in a menu.
4. Keep controls adjacent to the play area and large enough for touch. Put secondary actions in a small bottom row.
5. Avoid intro paragraphs, large banners, persistent ads/placeholders, and redundant navigation during active play.
6. Use the same layout contract for local and online modes; only the player hand/seat details change.
7. Result view shows winner, score, rematch, and leave/change-game actions.
8. Preserve each game's existing rules and synchronization. Do not silently replace real game logic with a static preview.

## Screens in the supplied reference

- App launch / logo
- Game hub with search, category chips, game grid, favourites, and settings
- Game details (art, 2-player badge, duration/difficulty, concise rules, Rules and Play actions)
- Play mode selector (Local Play / Online Play)
- UNO active table (opponent hand count at top, discard/draw piles centered, own hand and action controls at bottom)
- Compact active-play tiles/previews for:
  1. Tic Tac Toe
  2. Connect Four
  3. Chess
  4. Carrom
  5. 8 Ball Pool
  6. Table Tennis
  7. Memory Match
  8. Mini Golf
  9. Darts
  10. Air Hockey
  11. Racing
  12. Basketball
  13. Fruit Cut
  14. Maths Duel
  15. Guess Who
  16. Backgammon
  17. Checkers
  18. Battleship
  19. Raja Mantri
  20. Chor Sipahi
  21. UNO

Some labels are repeated in the supplied collage because it shows both individual previews and a gallery. Treat each title as one game, not a separate implementation.

## Existing implementations and gap policy

Prefer reusing the current implementations in `mobile/lib/features/local_games` and the existing online relay adapters. At the time this spec was added, the repository already has games including Tic Tac Toe, Connect Four, Carrom, 8 Ball Pool, Table Tennis, Memory, Mini Golf, Darts, Air Hockey, Basketball, Maths Duel, Guess Person, Checkers, Battleship, and Raja Mantri/Chor Sipahi. The branch adds an UNO catalog entry by reusing the existing Colour Clash rules engine as an initial integration; this is not yet a fully distinct official UNO implementation.

Chess and Backgammon are not identified as existing game modules in the current hub source. Racing can reuse the existing Smash Karts module only if its mechanics meet the intended racing rules. Fruit Cut must be a true slicing game, not simply relabeled Fruit Duel. These are implementation gaps and must not be represented as completed just because a tile exists.

## Acceptance checklist

- [ ] Launches with the clay theme and no dark/neon fallback surfaces.
- [ ] Search, category filters, favourites, settings, and every game tile work.
- [ ] Every shown game opens its own actual game screen.
- [ ] Active game shows score/turn/timer without obscuring the play area.
- [ ] Local play works and online play uses authoritative host/relay state.
- [ ] Rules/help are available on demand, not forced as a large banner.
- [ ] UNO: 7-card deal, legal matching, draw, Skip/Reverse two-player behavior, +2, Wild, legal +4 challenge, UNO penalty, round scoring, and rematch are tested.
- [ ] `flutter analyze`, unit tests, and Android debug build pass.
