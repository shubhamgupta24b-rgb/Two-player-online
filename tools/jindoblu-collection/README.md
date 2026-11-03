# JindoBlu APK analysis runner

This folder contains a reproducible, offline-first inventory runner for the user-supplied APK splits.

## Requirements
- Windows PowerShell 5.1+ or PowerShell 7.
- Python 3.9+ (standard library for the initial ZIP/string inventory).
- Optional: `python -m pip install lz4` for UnityFS block-index parsing and virtual-file extraction.
- The original `base.apk` and `split_config.arm64_v8a.apk` files available on disk.

## Run the static inventory first

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\jindoblu-collection\Analyze-JindoBlu.ps1 `
  -BaseApk "C:\path\to\base.apk" `
  -Arm64SplitApk "C:\path\to\split_config.arm64_v8a.apk" `
  -OutputDirectory ".\jindoblu-analysis"
```

This initial runner reads ZIP entries and printable strings. It does not run the APK. It writes a combined report and one report per split, including SHA-256 digests and relevant Unity files.

## Optional REA Android package inspection

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\jindoblu-collection\Analyze-JindoBlu.ps1 `
  -BaseApk "C:\path\to\base.apk" `
  -Arm64SplitApk "C:\path\to\split_config.arm64_v8a.apk" `
  -OutputDirectory ".\jindoblu-analysis" `
  -RunReaAndroidInspection
```

REA currently requires Node.js 22.19+ (or 24.11+ / 26+) and npm. The optional path downloads the official `jadx-headless-mcp 0.7.1` JAR and checks its pinned SHA-256 before invoking REA. It does not silently accept an unverified JAR. If the machine has no network access, the download step will fail and the offline report remains available.

Official requirements: [REA Android analysis](https://github.com/morluto/rea/blob/main/docs/android-analysis.md), [REA README](https://github.com/morluto/rea).

## Critical limitation for Unity IL2CPP

The APK contains Unity IL2CPP metadata and native ARM64 code. REA's JADX Android workflow helps inspect the Android package/DEX layer; it does not by itself decompile Unity's native IL2CPP gameplay methods. Method-level gameplay analysis requires native analysis tooling such as Ghidra/IDA/Hopper and a metadata-to-native method mapping. No gameplay code is executed by this script. Use only APKs you own or are authorized to analyze, and do not reuse extracted proprietary assets without rights.

## UnityFS virtual-file index (deeper static pass)

Install the optional LZ4 dependency, then from the repository root run:

```powershell
python -m pip install lz4
python .\\tools\\jindoblu-collection\\parse_unityfs_index.py \\
  "C:\\path\\to\\base.apk" \\
  --output ".\\jindoblu-analysis\\unityfs-index.json"
```

To decompress all UnityFS blocks and write the 12 indexed virtual files to a separate directory, add `--extract-dir ".\\jindoblu-analysis\\unityfs-files"`. The tool reports virtual-file sizes, hashes, and candidate strings. It does not yet parse Unity serialized-object tables, render scenes, or prove that every title-like identifier is an active selectable game. Keep extracted reference assets outside the shipped app unless their reuse rights are confirmed.
