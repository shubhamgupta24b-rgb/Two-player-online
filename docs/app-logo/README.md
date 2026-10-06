# Party Games — app logo

A split game controller: the blue half and the orange half are the two players (player 1 and 2 colours from `docs/ui-redesign/UI_SPEC.md`), the gold lightning bolt is the duel, and the buttons are the player shapes (circle, diamond, triangle, square). Deep indigo tile with confetti.

## Brand colours (same as the UI spec)

| Name | Hex |
|---|---|
| Indigo (tile, top-left → bottom-right) | `#4A35C2` → `#241A7A` → `#0B0E2E` |
| Player blue | `#2E8BFF` (light `#6CB4FF`, dark `#1659C9`) |
| Player orange | `#FF8A1F` (light `#FFB866`, dark `#D9600A`) |
| Gold | `#FFC93C` (light `#FFE58A`, dark `#F0A500`) |
| Ink outline | `#120C3A` |

## Files

- `android/res/mipmap-*/ic_launcher.png` — launcher icon, all densities (48–192 px)
- `android/res/mipmap-*/ic_launcher_foreground.png` — Android adaptive icon foreground (108–432 px)
- `android/res/values/ic_launcher_background.xml` — adaptive icon background colour `#241A7A`
- `store/icon_1024.png` — master icon (rounded tile)
- `store/playstore_512.png` — Play Store icon (square, Google rounds it)
- `store/adaptive_foreground_1024.png` — master adaptive foreground
- `render_logo.py` — the script that drew it (Python + Pillow + numpy), all shapes in a 1024 × 1024 grid

## Claude Code prompt

Copy this folder to `docs/app-logo/` in the repo, then paste:

```text
Update the app logo using docs/app-logo/ (read README.md there first). UI and assets only.

1. Copy docs/app-logo/android/res/mipmap-*/ic_launcher.png and ic_launcher_foreground.png over the files with the same names in mobile/android/app/src/main/res/mipmap-*/. Copy docs/app-logo/android/res/values/ic_launcher_background.xml over mobile/android/app/src/main/res/values/ic_launcher_background.xml. Keep mipmap-anydpi-v26/ic_launcher.xml as it is.
2. The in-app logo is drawn in code by PartyLogoPainter in mobile/lib/core/ui/party_logo.dart (used by PartyLogoIcon / AppLogo on splash and home). Redraw PartyLogoPainter to match docs/app-logo/store/icon_1024.png, porting the shapes from docs/app-logo/render_logo.py (same 1024 grid: background gradient + glows + sunburst, confetti, controller body with ink outline and blue/orange halves, white d-pad, four white player-shape buttons, gold bolt with ink outline, sparkles). Keep the constructor (rounded, artScale) and the PartyLogoIcon / PartyLogoFull API the same.
3. Copy docs/app-logo/store/icon_1024.png over logo.png in the repo root (used in README.md).
4. Run: cd mobile && flutter analyze && flutter test, then flutter run on the emulator, check the launcher icon on the home screen and the logo on the splash screen. Report what you saw and commit.
```

If the UI redesign is still running in Claude Code, send this after the current phase finishes (or tell it: "after this phase, do the logo task in docs/app-logo/README.md").
