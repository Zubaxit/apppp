#!/usr/bin/env python3
"""Generate the app's launcher icons without any image library.

The icon is drawn procedurally (Bangladesh-green tile with a white newspaper
glyph and a red accent bar) and encoded as PNG with zlib. Run from the
repository root:

    python3 scripts/generate_icons.py
"""
from __future__ import annotations

import math
import os
import struct
import zlib

SS = 4  # supersampling factor

GREEN_TOP = (18, 118, 92)
GREEN_BOTTOM = (11, 90, 70)
WHITE = (255, 255, 255)
RED = (244, 42, 65)


def rounded_rect_sdf(x, y, cx, cy, hw, hh, r):
    qx = abs(x - cx) - (hw - r)
    qy = abs(y - cy) - (hh - r)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - r


def blend(dst, src, alpha):
    return tuple(int(round(d + (s - d) * alpha)) for d, s in zip(dst, src))


def draw(size):
    """Return raw RGB rows for a `size`x`size` icon."""
    w = h = size * SS
    px = [[(0, 0, 0) for _ in range(w)] for _ in range(h)]

    for y in range(h):
        t = y / (h - 1)
        bg = tuple(int(round(a + (b - a) * t)) for a, b in zip(GREEN_TOP, GREEN_BOTTOM))
        for x in range(w):
            px[y][x] = bg

    # Tile mask (rounded square, slight inset so the icon breathes).
    tile_r = w * 0.22
    for y in range(h):
        for x in range(w):
            d = rounded_rect_sdf(x + 0.5, y + 0.5, w / 2, h / 2, w / 2 - 1, h / 2 - 1, tile_r)
            if d > 0:
                px[y][x] = (0, 0, 0)

    def fill_rect(x0, y0, x1, y1, color, radius=0.0):
        for y in range(int(y0 * w), int(y1 * w)):
            for x in range(int(x0 * w), int(x1 * w)):
                if 0 <= x < w and 0 <= y < h:
                    if radius > 0:
                        d = rounded_rect_sdf(
                            x + 0.5, y + 0.5,
                            (x0 + x1) * w / 2, (y0 + y1) * h / 2,
                            (x1 - x0) * w / 2, (y1 - y0) * h / 2, radius * w,
                        )
                        if d > 0:
                            continue
                    px[y][x] = color

    # Newspaper page.
    fill_rect(0.24, 0.28, 0.76, 0.72, WHITE, radius=0.045)
    # Headline block with a red accent strip, matching the flag colours.
    fill_rect(0.30, 0.34, 0.50, 0.46, RED, radius=0.012)
    fill_rect(0.30, 0.34, 0.50, 0.377, WHITE, radius=0.0)
    # Body lines.
    for row in range(3):
        y0 = 0.35 + row * 0.042
        fill_rect(0.53, y0, 0.70, y0 + 0.022, GREEN_BOTTOM, radius=0.006)
    for row in range(4):
        y0 = 0.50 + row * 0.048
        width = 0.44 if row < 3 else 0.28
        fill_rect(0.30, y0, 0.30 + width, y0 + 0.022, GREEN_BOTTOM, radius=0.006)

    # Box filter down to the requested size.
    out = []
    for y in range(size):
        row = []
        for x in range(size):
            r = g = b = 0
            for dy in range(SS):
                for dx in range(SS):
                    pr, pg, pb = px[y * SS + dy][x * SS + dx]
                    r += pr
                    g += pg
                    b += pb
            n = SS * SS
            row.append((r // n, g // n, b // n))
        out.append(row)
    return out


def write_png(path, rows):
    height = len(rows)
    width = len(rows[0])
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for r, g, b in row:
            raw.extend((r, g, b))
    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(png)


DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for density, size in DENSITIES.items():
        rows = draw(size)
        targets = [
            os.path.join(root, "android", "app", "src", "main", "res",
                         f"mipmap-{density}", "ic_launcher.png"),
            os.path.join(root, "assets", "icons", f"ic_launcher_{density}.png"),
        ]
        for target in targets:
            write_png(target, rows)
        print(f"wrote {density} ({size}px)")
    store = draw(512)
    write_png(os.path.join(root, "assets", "icons", "icon-512.png"), store)
    print("wrote assets/icons/icon-512.png")


if __name__ == "__main__":
    main()
