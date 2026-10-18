#!/usr/bin/env python3
"""Offline inventory of Unity/IL2CPP APK splits. Uses Python standard library only.

This does not execute the APK or decompile native IL2CPP method bodies.
"""
from __future__ import annotations
import argparse, hashlib, re, zipfile
from pathlib import Path

KEYWORDS = re.compile(
    r"(Controller|GameController|GameManager|Score|Turn|Player|Collision|"
    r"FixedUpdate|Update|Shoot|Throw|Hit|Spawn|Winner|EndGame|GameFinished|"
    r"Configure|Billiard|Soccer|Pool|Memory|DotsBoxes|Archery|Minigolf|"
    r"KnifeHit|HotPotato|HungryHippos|FlappyDunk|MathMagic|WhackAMole)",
    re.IGNORECASE,
)

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def printable_strings(data: bytes, min_len: int = 4) -> list[str]:
    pattern = rb"[\x20-\x7e]{%d,}" % min_len
    return [x.decode("ascii", "replace") for x in re.findall(pattern, data)]

def inspect_apk(path: Path, output: Path) -> tuple[dict, list[str]]:
    raw_hash = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            raw_hash.update(chunk)
    details = {"path": str(path.resolve()), "size_bytes": path.stat().st_size,
               "sha256": raw_hash.hexdigest(), "entries": [], "key_files": []}
    candidate_strings: set[str] = set()
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        details["entry_count"] = len(names)
        details["entries"] = names
        for name in names:
            low = name.lower()
            if (name.endswith("global-metadata.dat") or low.endswith("libil2cpp.so")
                    or name.endswith("AndroidManifest.xml") or "sharedassets" in low
                    or "level" in low and low.endswith(".assets")):
                info = z.getinfo(name)
                details["key_files"].append({
                    "name": name, "size_bytes": info.file_size,
                    "compressed_bytes": info.compress_size,
                })
            if name.endswith("global-metadata.dat"):
                data = z.read(name)
                details["metadata"] = {"name": name, "size_bytes": len(data),
                                       "sha256": sha256(data)}
                for s in printable_strings(data):
                    if KEYWORDS.search(s):
                        candidate_strings.add(s)
    report = [
        f"# APK Inventory: {path.name}", "",
        f"- File: `{path.resolve()}`",
        f"- Size: {details['size_bytes']:,} bytes",
        f"- APK SHA-256: `{details['sha256']}`",
        f"- ZIP entry count: {details['entry_count']:,}", "",
        "## Relevant files", "",
        "| Entry | Uncompressed bytes | Compressed bytes |",
        "|---|---:|---:|",
    ]
    for x in details["key_files"]:
        report.append(f"| `{x['name']}` | {x['size_bytes']:,} | {x['compressed_bytes']:,} |")
    if "metadata" in details:
        m = details["metadata"]
        report += ["", "## IL2CPP metadata", "",
                   f"- Entry: `{m['name']}`",
                   f"- Size: {m['size_bytes']:,} bytes",
                   f"- SHA-256: `{m['sha256']}`", "",
                   "## Candidate class/method strings", "",
                   "These are printable strings from the metadata, not proof that each method is reachable or that its body was recovered.", ""]
        report.extend(f"- `{s}`" for s in sorted(candidate_strings, key=str.casefold))
    else:
        report += ["", "## IL2CPP metadata", "", "No `global-metadata.dat` entry was found in this APK split."]
    output.write_text("\n".join(report) + "\n", encoding="utf-8")
    return details, sorted(candidate_strings, key=str.casefold)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", required=True, type=Path, help="Path to base.apk")
    p.add_argument("--split", required=True, type=Path, help="Path to ABI split APK")
    p.add_argument("--out", default=Path("jindoblu-analysis"), type=Path)
    args = p.parse_args()
    for file in (args.base, args.split):
        if not file.is_file():
            p.error(f"APK not found: {file}")
    args.out.mkdir(parents=True, exist_ok=True)
    summary = ["# Combined APK Split Inventory", "",
               "Both files should be treated as splits of one installable app, not separate games.", ""]
    for path in (args.base, args.split):
        details, _ = inspect_apk(path, args.out / f"{path.stem}-inventory.md")
        summary += [f"## {path.name}", "",
                    f"- SHA-256: `{details['sha256']}`",
                    f"- ZIP entries: {details['entry_count']:,}",
                    f"- Size: {details['size_bytes']:,} bytes"]
        if "metadata" in details:
            summary.append(f"- IL2CPP metadata: `{details['metadata']['name']}` ({details['metadata']['size_bytes']:,} bytes)")
        summary.append("")
    summary += [
        "## Important limits", "",
        "- This is offline static inventory only; the APK is not executed.",
        "- Printable metadata strings do not recover IL2CPP method bodies.",
        "- REA's JADX Android provider primarily handles the Android/DEX layer. Unity IL2CPP gameplay logic is native ARM64 code and needs native disassembly/decompilation (e.g. Ghidra) plus metadata-to-native mapping.",
        "- Do not copy extracted proprietary assets into another app unless you have rights to reuse them.",
    ]
    (args.out / "COMBINED_INVENTORY.md").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(f"Inventory written to: {(args.out / 'COMBINED_INVENTORY.md').resolve()}")
    print(f"Per-split reports written to: {args.out.resolve()}")

if __name__ == "__main__":
    main()
