# Unity Data Asset String Findings

**Source:** `assets/bin/Data/data.unity3d` from the supplied `base.apk`. The file is a Unity serialized data container; the findings below come from printable-string extraction, not a complete Unity asset-bundle parser.

## What was directly observed

- Parsed the UnityFS header from the supplied APK: format version `8`, player version field `5.x.x`, engine version `2022.3.62f3`; the declared bundle size exactly matches the extracted member size (33,457,502 bytes). The bundle SHA-256 is `5cbb070566ad1bbcdf216604903777184361ce35f1cb0b5104c70152456e7e7e`.
- Added and locally executed `tools/jindoblu-collection/inspect_unityfs.py` using only Python's standard library. It verified the size/header consistency and emitted a JSON report of candidate printable strings. This is header/string inspection only; UnityFS block decompression and serialized-object parsing remain undone.

- `data.unity3d` is present at approximately 33.46 MB.
- `ScriptingAssemblies.json` lists `Assembly-CSharp.dll` and Unity packages including TextMeshPro, URP, Unity Services, and several third-party SDKs.
- Printable strings include `assets/Scenes/Loader.u`, menu/list labels such as `ALLGAMES`, `GAME INFO`, and `Game Title`, and many game/scene-like identifiers.
- Example identifiers include `12_ARCHERY2`, `16_MINIGOLF`, `49_MEMORY`, `50_KNIFEHIT`, `54_HOTPOTATO`, `82_SOCCERSTARS`, `133_BASKETBALLHOOPS`, `145_GUESS_THE_PERSON`, `21_WHACKAMOLE`, `25_PITTURA`, `26_FISHING`, `32_FIREWORKS`, `46_HUNGRYHIPPOS`, and `2_FLAPPYDUNK`.
- Additional identifiers suggest the package includes other game families, for example `05_DARTS`, `2_DUELL`, `11_MACCHININE`, `19_ASTRONAVI`, `28_TRAFFICO`, `30_SNAKESLADDERS`, `120_SLOTCARS`, `127_SHOOTINGGALLERY`, `138_CUPPONG`, `144_FIND`, `146_IMPOSTOR`, and `149_OOPS`.

## Important interpretation limits

1. These are strings and identifiers found in a serialized Unity data file. They are not, by themselves, proof that every item is a shipped playable game; some may be tutorials, old content, UI labels, bundles, unused assets, or variants.
2. Numeric prefixes should not be treated as stable game IDs in our Flutter app. Preserve the existing app's catalogue IDs.
3. The presence of a name such as `Pool`, `Memory`, or `SoccerStars` does not reveal exact rules, scoring, physics constants, or network behavior.
4. No Unity scenes were fully parsed or rendered in this step. The string `Scenes/Loader.u` is only a partial path fragment.
5. The APK's proprietary Unity assets are not copied into the Flutter app. Use the evidence to design original replacements and validate gameplay behaviour.

## Recommended next analysis

- Use a Unity asset parser compatible with the APK's Unity version to inspect serialized files and asset-bundle indexes.
- Extract scene names, text assets, sprites/audio references, and scriptable-object records where technically supported.
- Match each confirmed title to a controller/type in `IL2CPP_METHOD_INVENTORY.md`.
- Use controlled gameplay captures to confirm which candidate titles are active and to record setup, input, scoring, end-state, and restart behavior.
- Update `REFERENCE_INVENTORY.md` only when the evidence can distinguish an active title from an unused or legacy asset.

## Current status

This is a new static-evidence layer beyond the metadata method-name inventory, but it is **not** a scene extraction, full asset inventory, or gameplay reverse engineering result.
