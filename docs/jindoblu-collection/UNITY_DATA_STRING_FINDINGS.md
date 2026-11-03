# Unity Data Asset String Findings

**Source:** `assets/bin/Data/data.unity3d` from the supplied `base.apk`. The file is a Unity serialized data container; the findings below come from printable-string extraction, not a complete Unity asset-bundle parser.

## What was directly observed

- Parsed the UnityFS header from the supplied APK: format version `8`, player version field `5.x.x`, engine version `2022.3.62f3`; the declared bundle size exactly matches the extracted member size (33,457,502 bytes). The bundle SHA-256 is `5cbb070566ad1bbcdf216604903777184361ce35f1cb0b5104c70152456e7e7e`.
- The original `inspect_unityfs.py` performed header/string checks. I then used the installed Python `lz4` package to decompress the block index and all 2,053 UnityFS data blocks locally. The virtual data stream is 268,960,812 bytes and all compressed bytes were consumed exactly; the 12 indexed virtual files were identified. This successful test informed the new `parse_unityfs_index.py` tool.
- The UnityFS block index contains these virtual files: `globalgamemanagers`, `Resources/unity_builtin_extra`, `globalgamemanagers.assets`, `sharedassets0.assets`, `globalgamemanagers.assets.resS`, `sharedassets0.assets.resS`, `level0`, `sharedassets1.assets`, `sharedassets1.assets.resS`, `level1`, `resources.assets`, and `resources.assets.resS`. File sizes and hashes were checked during the local extraction.
- The parser does **not** yet decode Unity serialized-object tables or render scenes. It extracts the UnityFS virtual-file index and can optionally extract those files and scan their printable strings.

- `data.unity3d` is present at approximately 33.46 MB.
- `ScriptingAssemblies.json` lists `Assembly-CSharp.dll` and Unity packages including TextMeshPro, URP, Unity Services, and several third-party SDKs.
- Printable strings include `assets/Scenes/Loader.u`, menu/list labels such as `ALLGAMES`, `GAME INFO`, and `Game Title`, and many game/scene-like identifiers.
- The decompressed `globalgamemanagers` virtual file contains a stronger set of title-like identifiers, including `3_POOL`, `16_MINIGOLF`, `21_WHACKAMOLE`, `25_PITTURA`, `26_FISHING`, `32_FIREWORKS`, `33_ARCHERY`, `46_HUNGRYHIPPOS`, `49_MEMORY`, `50_KNIFEHIT`, `54_HOTPOTATO`, `57_DOTSBOXES`, `72_FLAPPYDUNK`, `82_SOCCERSTARS`, `112_ARCHERY2`, `120_SLOTCARS`, `127_SHOOTINGGALLERY`, `130_SNAKESLADDERS`, `133_BASKETBALLHOOPS`, `144_FIND`, `145_GUESS_THE_PERSON`, and `146_IMPOSTOR`, plus tutorial/settings variants for several titles.
- `sharedassets1.assets` and `resources.assets` also contain matching banner names and tutorial/title strings for many of those candidates. This cross-file agreement is stronger than a lone printable string, but still does not establish exact rules or guarantee that each entry is selectable in the supplied build.
- Additional identifiers suggest the package includes other game families, for example `05_DARTS`, `2_DUELL`, `11_MACCHININE`, `19_ASTRONAVI`, `28_TRAFFICO`, `30_SNAKESLADDERS`, `120_SLOTCARS`, `127_SHOOTINGGALLERY`, `138_CUPPONG`, `144_FIND`, `146_IMPOSTOR`, and `149_OOPS`.

## Important interpretation limits

1. The virtual-file index and matching identifiers were recovered from the compressed bundle, but the Unity serialized-object tables have not yet been fully parsed. Matching identifiers are not proof that every item is a shipped selectable game; some may be tutorials, old content, UI labels, or variants.
2. Numeric prefixes should not be treated as stable game IDs in our Flutter app. Preserve the existing app's catalogue IDs.
3. The presence of a name such as `Pool`, `Memory`, or `SoccerStars` does not reveal exact rules, scoring, physics constants, or network behavior.
4. No Unity scenes were fully parsed or rendered in this step. The string `Scenes/Loader.u` is only a partial path fragment.
5. The APK's proprietary Unity assets are not copied into the Flutter app. Use the evidence to design original replacements and validate gameplay behaviour.

## Recommended next analysis

- Parse the serialized Unity files (for example with a compatible Unity asset parser) to recover object types, object names, and scene references.
- Inspect the title/banner text records and link them to serialized objects or scene names; identify active menu entries separately from tutorial and legacy variants.
- Match each confirmed title to a controller/type in `IL2CPP_METHOD_INVENTORY.md`.
- Use controlled gameplay captures to confirm which candidate titles are active and to record setup, input, scoring, end-state, and restart behavior.
- Update `REFERENCE_INVENTORY.md` only when the evidence can distinguish an active title from an unused or legacy asset.

## Current status

This is a meaningful step beyond raw string scanning: the UnityFS block index was parsed and all blocks were decompressed successfully. However, Unity serialized-object parsing, scene rendering, and gameplay reverse engineering are still incomplete.
