# Unity IL2CPP Native Analysis Runbook

## Purpose

Use this runbook to continue analysis of the user-provided JindoBlu reference APK pair when a local machine with Ghidra is available. The APK contains Unity IL2CPP code: the DEX/Java layer and the native gameplay layer are different targets. JADX/REA Android inspection can describe the Android wrapper, but it cannot recover the C# gameplay method bodies compiled into `libil2cpp.so`.

This is a static-analysis workflow. Do not execute an unknown APK on a personal device or use extracted assets in the port unless their reuse rights are confirmed.

## Inputs and known evidence

- `base.apk`: APK package, Unity data, and `assets/bin/Data/Managed/Metadata/global-metadata.dat`.
- `split_config.arm64_v8a.apk`: ARM64 native libraries, including `lib/arm64-v8a/libil2cpp.so`.
- Earlier inventory found IL2CPP metadata version 31 and method-name evidence for controllers including `ControllerPool`, `SoccerController`, and `ControllerMinigolf`. These are useful search anchors, not proof that exact game rules or numeric parameters have been recovered.
- See `REFERENCE_INVENTORY.md` and `IL2CPP_METHOD_INVENTORY.md` for the existing evidence and confidence labels.

## 1. Prepare a clean analysis directory

Keep originals unchanged and record hashes before extracting:

```powershell
Get-FileHash .\base.apk -Algorithm SHA256
Get-FileHash .\split_config.arm64_v8a.apk -Algorithm SHA256
```

Extract each APK with 7-Zip or another ZIP-compatible tool into separate folders. Confirm these files exist:

- `base\assets\bin\Data\Managed\Metadata\global-metadata.dat`
- `split\lib\arm64-v8a\libil2cpp.so`

Record the SHA-256 hashes of both extracted files as well. Never rename or overwrite the original APKs.

## 2. Import the native library into Ghidra

1. Install a current Ghidra release supported by your Java runtime from the official Ghidra release page: https://github.com/NationalSecurityAgency/ghidra/releases
2. Create a new, dedicated non-shared project.
3. Import `libil2cpp.so`; accept ELF/ARM64/AArch64 detection.
4. Run auto-analysis with the default analyzers first. Save the project.
5. Check ELF headers, sections, imports/exports, and whether symbols are stripped. Expect many generated IL2CPP methods to have no friendly symbol names.
6. Search strings and cross-references for method/type names found in the metadata inventory. Native string references can help locate registration tables and nearby code, but a string match alone does not prove a gameplay call path.

## 3. Connect metadata names to native addresses

IL2CPP metadata contains type/method definitions and the binary contains native code plus registration structures. Mapping a method name to the correct native body generally requires the matching Unity/IL2CPP metadata layout and registration data; it is not a simple text search.

For each candidate method:

1. Capture the fully qualified type name, method name, parameter count/signatures, and metadata token/index from the metadata parser.
2. Determine whether the build exposes a usable method pointer for that metadata entry. Account for generic methods, shared generic implementations, abstract/extern methods, and methods with no native body.
3. Use a version-compatible IL2CPP metadata parser or Ghidra extension to parse method-pointer/code-registration structures. Verify the parser supports the metadata version and ARM64 binary in this APK before trusting its output.
4. Resolve the pointer in Ghidra and confirm it falls inside an executable mapped segment. Record the address, function boundaries, cross-references, and confidence.
5. Rename functions only after corroborating the mapping. Preserve the original address/name in the notes so the analysis is reproducible.

Do not guess structure offsets from another Unity version or assign a nearby function to a method merely because the order looks plausible.

## 4. Prioritize the first candidate controllers

Start with small, identifiable methods from the existing inventory rather than trying to reverse the entire library at once:

- Pool/billiards: `ConfigureBilliards`, `ChangeTurn`, `BilliardWhiteInPocket`, `ShootBilliardWhite`, `BilliardIncreaseScore`, `OnDrag`, `OnRelease`.
- Soccer: `HandleThrow`, `HandleGoal`, `HandleOwnGoal`.
- Minigolf: drag/release handlers, collision handling, ball-in-hole and victory methods.

For each method, document:
- resolved native address and evidence for the mapping;
- called functions and important field offsets;
- constants, comparisons, branches, and state mutations;
- any observed physics/scoring/timing values, with units and the exact code path;
- uncertainty (for example, an indirect call or unresolved field type).

A method name alone only suggests intent. It does not establish exact rules, score values, physics constants, player count, or multiplayer synchronization.

## 5. Use runtime observations to validate static hypotheses

Where permitted, capture reference gameplay on a controlled test device or emulator. For each candidate game, collect screenshots/video of setup, a normal round, edge cases, pause/restart, and result screens. Record input sequence and observable outcomes. Compare those observations with the native code hypotheses.

Do not bypass licensing, account protections, anti-cheat, or server-side access controls. If the app requires a remote service that is unavailable, mark the behaviour as unverified rather than fabricating it.

## 6. Evidence format

Append results to a separate report rather than replacing the initial inventory. Suggested table:

| Reference game | Type/method | Metadata evidence | Native address | Static finding | Runtime validation | Confidence |
|---|---|---|---|---|---|---|
| Pool | `ControllerPool.ChangeTurn` | type/method record | TBD | TBD | TBD | Candidate only |

Use these confidence labels consistently:
- **Observed** — directly seen in a captured run.
- **Static-confirmed** — supported by a resolved native body and clear control/data flow.
- **Corroborated** — static finding also matches repeatable runtime observation.
- **Candidate** — inferred from names or partial structure only.
- **Unknown** — insufficient evidence.

## 7. What this does and does not deliver

This workflow can help identify native control flow, scoring conditions, and physics constants if the method mappings can be resolved. It does not automatically recover original C# source, Unity scenes, editable project files, or asset licensing. It also does not implement the games in Flutter.

After the first controller is mapped and validated, write a small behaviour specification for one game and implement that game behind the existing app's current catalogue/session contracts. Keep all changes on `feature/jindoblu-collection`, add tests, and build an APK before marking the game complete.
