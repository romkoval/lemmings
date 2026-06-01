#!/usr/bin/env python3
"""Generates simple PNG placeholders for tilesets using only stdlib."""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TILESETS = ROOT / "assets" / "tilesets"
TILESETS.mkdir(parents=True, exist_ok=True)


def make_png(path: Path, width: int, height: int, color_at) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type none
        for x in range(width):
            r, g, b, a = color_at(x, y)
            raw.extend([r, g, b, a])
    compressor = zlib.compressobj(9)
    compressed = compressor.compress(bytes(raw)) + compressor.flush()

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    out = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    path.write_bytes(out)


def main() -> None:
    # Atlas: 32x16, two tiles (terrain at 0,0 - brown; steel at 16,0 - gray)
    def atlas(x, y):
        if x < 16:
            return (139, 90, 43, 255)  # terrain brown
        return (120, 120, 130, 255)  # steel gray

    make_png(TILESETS / "main_atlas.png", 32, 16, atlas)
    print("wrote", TILESETS / "main_atlas.png")


if __name__ == "__main__":
    main()
