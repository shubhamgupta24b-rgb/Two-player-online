#!/usr/bin/env python3
"""Parse a UnityFS bundle's block index and optionally extract its virtual files.

Requires Python 3 and the 'lz4' package for UnityFS LZ4/LZ4HC blocks:
    python -m pip install lz4
This reads a UnityFS bundle from an APK ZIP member; it never executes APK code.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path, PurePosixPath

DEFAULT_MEMBER = "assets/bin/Data/data.unity3d"


def cstring(data: bytes, offset: int) -> tuple[str, int]:
    end = data.find(b"\0", offset)
    if end < 0:
        raise ValueError("Truncated null-terminated UnityFS header string")
    return data[offset:end].decode("utf-8", errors="replace"), end + 1


def parse_bundle(bundle: bytes) -> tuple[dict, list[dict], int, int, list[dict]]:
    if not bundle.startswith(b"UnityFS\0"):
        raise ValueError("Bundle does not start with UnityFS signature")
    offset = 8
    version = struct.unpack_from(">I", bundle, offset)[0]
    offset += 4
    player_version, offset = cstring(bundle, offset)
    engine_version, offset = cstring(bundle, offset)
    declared_size, compressed_info_size, uncompressed_info_size, flags = struct.unpack_from(">QIII", bundle, offset)
    offset += 20

    # 0x200 means the block-info region is aligned to a 16-byte boundary.
    info_offset = (offset + 15) & ~15 if flags & 0x200 else offset
    if flags & 0x80:
        info_offset = len(bundle) - compressed_info_size
    info_compressed = bundle[info_offset:info_offset + compressed_info_size]
    compression = flags & 0x3F
    if compression == 0:
        info = info_compressed
    elif compression in (2, 3):
        try:
            import lz4.block
        except ImportError as exc:
            raise RuntimeError("Install lz4 to parse UnityFS index: python -m pip install lz4") from exc
        info = lz4.block.decompress(info_compressed, uncompressed_size=uncompressed_info_size)
    else:
        raise RuntimeError(f"Unsupported UnityFS block-info compression type: {compression}")
    if len(info) != uncompressed_info_size:
        raise ValueError(f"Block-info length mismatch: expected {uncompressed_info_size}, got {len(info)}")

    # UnityFS block-info starts with a 16-byte content hash, then block count.
    cursor = 16
    block_count = struct.unpack_from(">I", info, cursor)[0]
    cursor += 4
    blocks = []
    for index in range(block_count):
        uncompressed, compressed, block_flags = struct.unpack_from(">IIH", info, cursor)
        cursor += 10
        blocks.append({"index": index, "uncompressed_size": uncompressed,
                       "compressed_size": compressed, "flags": block_flags})

    node_count = struct.unpack_from(">I", info, cursor)[0]
    cursor += 4
    nodes = []
    for index in range(node_count):
        file_offset, file_size, node_flags = struct.unpack_from(">QQI", info, cursor)
        cursor += 20
        name, cursor = cstring(info, cursor)
        nodes.append({"index": index, "offset": file_offset, "size": file_size,
                      "flags": node_flags, "name": name})
    if cursor != len(info):
        raise ValueError(f"Unexpected {len(info) - cursor} trailing bytes in block-info")
    data_offset = info_offset + compressed_info_size
    # Some UnityFS variants align the first data block to 16 bytes (flag 0x40).
    if flags & 0x40 and not flags & 0x80:
        data_offset = (data_offset + 15) & ~15
    if flags & 0x80:
        # With info at end, data starts at the aligned end of the header.
        data_offset = (offset + 15) & ~15
    summary = {
        "format_version": version,
        "player_version": player_version,
        "engine_version": engine_version,
        "declared_bundle_size": declared_size,
        "actual_bundle_size": len(bundle),
        "bundle_size_matches_header": declared_size == len(bundle),
        "compressed_info_size": compressed_info_size,
        "uncompressed_info_size": uncompressed_info_size,
        "flags_hex": hex(flags),
        "block_count": block_count,
        "node_count": node_count,
        "uncompressed_data_size": sum(x["uncompressed_size"] for x in blocks),
        "compressed_data_size": sum(x["compressed_size"] for x in blocks),
        "sha256": hashlib.sha256(bundle).hexdigest(),
    }
    return summary, nodes, data_offset, compression, blocks


def safe_name(name: str) -> str:
    # Flatten virtual paths to avoid writing outside the extraction directory.
    return "__".join(PurePosixPath(name).parts).replace(":", "_") or "unnamed"


def printable_candidates(data: bytes) -> list[str]:
    pattern = re.compile(
        r"(?i)(archery|minigolf|memory|knife.?hit|hot.?potato|soccer|basketball|"
        r"guess.?the.?person|whack.?a.?mole|pittura|fishing|fireworks|hungry.?hippos|"
        r"flappy.?dunk|pool|dots.?boxes|math.?magic|king.?yard|pull.?the.?rope)"
    )
    found = set()
    for raw in re.findall(rb"[A-Za-z][A-Za-z0-9 _./-]{3,90}", data):
        value = raw.decode("ascii", errors="ignore").strip()
        if pattern.search(value) and len(value) <= 90:
            found.add(value)
    return sorted(found)


def inspect(apk: Path, member: str, extract_dir: Path | None) -> dict:
    with zipfile.ZipFile(apk) as archive:
        bundle = archive.read(member)
    summary, nodes, data_offset, compression, blocks = parse_bundle(bundle)
    report = {"apk": str(apk), "member": member, **summary, "files": []}

    if extract_dir is not None:
        try:
            import lz4.block
        except ImportError as exc:
            raise RuntimeError("Install lz4 to extract UnityFS files: python -m pip install lz4") from exc
        virtual = bytearray(summary["uncompressed_data_size"])
        src = data_offset
        dst = 0
        for block in blocks:
            chunk = bundle[src:src + block["compressed_size"]]
            src += block["compressed_size"]
            if block["flags"] & 0x3F == 0:
                decoded = chunk
            elif block["flags"] & 0x3F in (2, 3):
                decoded = lz4.block.decompress(chunk, uncompressed_size=block["uncompressed_size"])
            else:
                raise RuntimeError(f"Unsupported block compression flags: {block['flags']}")
            if len(decoded) != block["uncompressed_size"]:
                raise ValueError(f"Block {block['index']} length mismatch")
            virtual[dst:dst + len(decoded)] = decoded
            dst += len(decoded)

        extract_dir.mkdir(parents=True, exist_ok=True)
        for node in nodes:
            start, end = node["offset"], node["offset"] + node["size"]
            if end > len(virtual):
                raise ValueError(f"Node exceeds virtual data: {node['name']}")
            payload = bytes(virtual[start:end])
            output = extract_dir / safe_name(node["name"])
            output.write_bytes(payload)
            report["files"].append({
                **node,
                "extracted_file": output.name,
                "sha256": hashlib.sha256(payload).hexdigest(),
                "candidate_strings": printable_candidates(payload)[:100],
            })
    else:
        report["files"] = nodes
    report["limitations"] = [
        "The UnityFS file index is parsed; extracted files are not fully decoded Unity serialized objects.",
        "Candidate strings and file names do not prove that a game is active or reveal its complete rules.",
        "The script does not execute APK code or copy reference assets into the Flutter app.",
    ]
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path, help="Path to supplied base APK")
    parser.add_argument("--member", default=DEFAULT_MEMBER, help="UnityFS ZIP member")
    parser.add_argument("--extract-dir", type=Path, help="Optional directory for extracted virtual files")
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    args = parser.parse_args()
    report = inspect(args.apk, args.member, args.extract_dir)
    rendered = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if report["bundle_size_matches_header"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
