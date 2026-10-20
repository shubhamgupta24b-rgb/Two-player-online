# UI Implementation Plan (feature/clay-games-ui-uno)

## Baseline inspection summary

- Flutter app located at `/home/runner/work/Two-player-online/Two-player-online/mobile`.
- Entry/startup flow:
  - `lib/main.dart` initializes config/audio/settings/LAN host and launches `SplashScreen`.
  - `lib/features/splash/splash_screen.dart` restores auth and transitions to mode/home flow.
- Existing design system already contains reusable tokens/components:
  - `lib/core/ui/tokens.dart`
  - `lib/core/ui/app_theme_ext.dart`
  - `lib/core/ui/components.dart`
  - `lib/core/ui/game_kit.dart`
  - `lib/core/ui/app_flavor.dart`
- Game catalogue and shell:
  - `lib/games/game_catalog.dart`
  - `lib/features/local_games/local_games_hub_screen.dart`
  - `lib/features/local_games/shell/local_game_shell.dart`
- Multiplayer/local-online infrastructure present and must be preserved:
  - `lib/core/network/socket_manager.dart`
  - `lib/core/room/room_manager.dart`
  - `lib/core/session/game_session_manager.dart`
  - `lib/core/lan/*`
  - Screens: create/join/quick/lobby/game-host
- UNO already has real local logic and UI (`lib/features/local_games/uno/uno_board.dart`) and will be visually polished while preserving mechanics.

## Baseline tooling attempt

- Attempted:
  - `flutter pub get`
- Result:
  - Failed in this environment because `flutter` is not installed (`/bin/bash: flutter: command not found`).
- Impact:
  - Baseline automated test/analyze/build execution is currently blocked by missing Flutter/Dart toolchain in the runner environment.

## Implementation phases

1. **Reusable clay system alignment**
   - Add lightweight reusable clay theme/widget layer (`lib/theme/*`, `lib/widgets/*`) mapped to existing token system for pastel colors, spacing, typography, rounded cards/buttons/chips/nav surfaces.
2. **Welcome screen**
   - Update splash welcome visuals to reference style (pastel floating shapes, title/subtitle copy) while keeping real initialization logic and automatic navigation.
3. **Home and navigation**
   - Redesign `HomeScreen` into responsive clay hub with:
     - top profile/title/rewards/settings row
     - search
     - horizontal All/Board/Card/Arcade/Sports filters
     - responsive game grid
     - favorites support
     - bottom navigation (Home/Favorites/Settings)
4. **Game details**
   - Add dedicated game details screen:
     - back/favorite
     - large illustration
     - real metadata chips from catalog/local game data
     - description
     - rules dialog (actual rules text)
     - Play action
5. **Mode selection with real flows**
   - Add mode selection screen per game with Local/Online options.
   - Preserve online/same-host functionality and room creation/join/quick flows.
   - Pass selected game context to room creation/quick-play where applicable.
6. **UNO visual polish**
   - Update UNO board layout to reference composition:
     - opponent area + face-down cards/count
     - centered draw/discard piles
     - active color + status
     - current hand and action controls
   - Keep current rules/mechanics intact.
7. **Tests**
   - Add/update widget tests for:
     - home navigation
     - search/filtering
     - favorites
     - game details/rules
     - mode selection
     - basic responsive behavior
8. **Validation + report**
   - Run formatting/tests/analyze/release build if Flutter toolchain is available.
   - Record results (or toolchain blockers), APK path if generated, changed files, and remaining gaps in final report.
