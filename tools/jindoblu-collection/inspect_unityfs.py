#!/usr/bin/env python3
"""Inspect the UnityFS header and printable game identifiers in an APK.

Uses only Python's standard library. It does not decompress UnityFS blocks,
parse serialized Unity objects, or execute APK content.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path

DEFAULT_MEMBER = "assets/bin/Data/data.unity3d"


def cstring(data: bytes, offset: int) -> tuple[str, int]:
    end = data.find(b"\0", offset)
    if end < 0:
        raise ValueError("Unexpected end of UnityFS header while reading string")
    return data[offset:end].decode("utf-8", errors="replace"), end + 1


def inspect(apk: Path, member: str) -> dict:
    with zipfile.ZipFile(apk) as zf:
        info = zf.getinfo(member)
        bundle = zf.read(member)
    digest = hashlib.sha256(bundle).hexdigest()
    if not bundle.startswith(b"UnityFS\0"):
        raise ValueError(f"{member} does not begin with a UnityFS signature")
    offset = 8
    format_version = struct.unpack_from(">I", bundle, offset)[0]
    offset += 4
    player_version, offset = cstring(bundle, offset)
    engine_version, offset = cstring(bundle, offset)
    if offset + 20 > len(bundle):
        raise ValueError("UnityFS header is truncated")
    declared_size, compressed_info_size, uncompressed_info_size, flags = struct.unpack_from(">QIII", bundle, offset)
    offset += 20

    # Names are leads only. UnityFS can contain metadata for inactive or legacy content.
    ascii_strings = re.findall(rb"[A-Za-z][A-Za-z0-9 _./-]{3,90}", bundle)
    candidates = set()
    pattern = re.compile(
        r"(?i)(archery|minigolf|memory|knife.?hit|hot.?potato|soccer|basketball|"
        r"guess.?the.?person|whack.?a.?mole|pittura|fishing|fireworks|hungry.?hippos|"
        r"flappy.?dunk|pool|dots.?boxes|math.?magic|king.?yard|pull.?the.?rope)"
    )
    for raw in ascii_strings:
        value = raw.decode("ascii", errors="ignore").strip()
        if pattern.search(value) and len(value) <= 90:
            candidates.add(value)
    return {
        "apk": str(apk),
        "member": member,
        "zip_member_size": info.file_size,
        "zip_compression": info.compress_type,
        "sha256": digest,
        "unityfs_signature": "UnityFS",
        "unityfs_format_version": format_version,
        "unity_player_version": player_version,
        "unity_engine_version": engine_version,
        "declared_bundle_size": declared_size,
        "actual_bundle_size": len(bundle),
        "bundle_size_matches_header": declared_size == len(bundle),
        "compressed_blocks_info_size": compressed_info_size,
        "uncompressed_blocks_info_size": uncompressed_info_size,
        "flags_hex": hex(flags),
        "header_bytes": offset,
        "candidate_strings": sorted(candidates)[:250],
        "limitations": [
            "Printable strings are leads, not proof that a title is an active playable scene.",
            "This script does not decompress UnityFS blocks or parse serialized Unity objects.",
            "No APK code is executed and no Unity assets are copied into the game project."
        ]
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path, help="Path to the supplied base APK")
    parser.add_argument("--member", default=DEFAULT_MEMBER, help="UnityFS member path inside APK")
    parser.add_argument("--output", type=Path, help="Optional JSON output file")
    args = parser.parse_args()
    report = inspect(args.apk, args.member)
    rendered = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if report["bundle_size_matches_header"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
