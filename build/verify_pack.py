#!/usr/bin/env python3
"""build/verify_pack.py — JIOH-60: checks an exported .pck before it ships.

    python3 build/verify_pack.py <game.pck> [project root]

Fails (exit 1) if the pack holds anything from tools/, build/, tests/ or the
debug scenes, or if any .ogv under resources/fmv/ is missing or differs by a
single byte from the source. Reads the Godot 4 pack directory directly
(format 2 and 3), so it needs nothing but Python.
"""
import hashlib
import pathlib
import struct
import sys

FORBIDDEN = ("tools/", "build/", "tests/", "scenes/debug/", "scripts/debug/")
FLAG_REL_FILEBASE = 1 << 1


def read_directory(data: bytes) -> dict:
    if data[:4] != b"GDPC":
        raise ValueError("not a Godot pack (no GDPC magic); is the pck embedded?")
    fmt, _major, _minor, _patch, flags = struct.unpack_from("<5I", data, 4)
    base, at = struct.unpack_from("<Q", data, 24)[0], 32
    if fmt >= 3:
        at = struct.unpack_from("<Q", data, 32)[0]
    else:
        at = 32 + 16 * 4
    if flags & 1:
        raise ValueError("the pack directory is encrypted")
    count = struct.unpack_from("<I", data, at)[0]
    at += 4
    files = {}
    for _ in range(count):
        n = struct.unpack_from("<I", data, at)[0]
        at += 4
        path = data[at:at + n].rstrip(b"\0").decode("utf-8")
        at += n
        offset, size = struct.unpack_from("<QQ", data, at)
        at += 16 + 16 + 4  # md5, file flags
        if flags & FLAG_REL_FILEBASE:
            offset += base
        files[path.removeprefix("res://")] = (offset, size)
    return files


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    pck = pathlib.Path(sys.argv[1])
    root = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else ".")
    data = pck.read_bytes()
    files = read_directory(data)
    problems = []
    for path in sorted(files):
        if path.startswith(FORBIDDEN) or "/debug/" in path:
            problems.append(f"excluded path shipped: {path}")
    fmv = sorted((root / "resources/fmv").glob("**/*.ogv")) if (root / "resources/fmv").exists() else []
    for src in fmv:
        rel = src.relative_to(root).as_posix()
        if rel not in files:
            problems.append(f"FMV missing from the pack: {rel}")
            continue
        offset, size = files[rel]
        packed = data[offset:offset + size]
        if hashlib.sha256(packed).digest() != hashlib.sha256(src.read_bytes()).digest():
            problems.append(f"FMV differs from source: {rel}")
    for p in problems:
        print("VERIFY FAIL:", p)
    if problems:
        return 1
    print(f"VERIFY OK: {pck.name}: {len(files)} files, {len(fmv)} FMV byte-identical, nothing excluded shipped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
