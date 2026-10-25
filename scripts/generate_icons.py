#!/usr/bin/env python3
"""Generate the Amar News launcher icons without any image library.

The mark is drawn procedurally and encoded as PNG with zlib: a graphite tile
carrying a white front page whose masthead rule is the app's printed red, with
three text lines below. It is grayscale plus one red — the same identity the
interface uses — and reads at 48 px.

    python3 scripts/generate_icons.py
"""
from __future__ import annotations

import math
import os
import struct
import zlib

SS = 4  # supersampling factor

GRAPHITE_TOP = (32, 32, 35)
GRAPHITE_BOTTOM = (15, 15, 17)
WHITE = (247, 246, 244)
INK = (60, 60, 64)
RED = (175, 31, 43)


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
        bg = tuple(int(round(a + (b - a) * t)) for a, b in zip(GRAPHITE_TOP, GRAPHITE_BOTTOM))
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

    # Front page.
    fill_rect(0.26, 0.25, 0.74, 0.75, WHITE, radius=0.055)
    # Folded corner: the page is being turned, which is what the app is for.
    # The corner is cut out of the sheet and replaced with a red dog-ear.
    fold = 0.17
    for y in range(int(0.25 * h), int(0.75 * h)):
        fy = (y / h - 0.25) / fold
        if fy > 1.0:
            break
        x_end = 0.74 - fold * (1.0 - fy)
        t = y / (h - 1)
        cut = tuple(int(round(a + (b - a) * t)) for a, b in zip(GRAPHITE_TOP, GRAPHITE_BOTTOM))
        for x in range(int(x_end * w), int(0.74 * w)):
            px[y][x] = cut
    for y in range(int(0.25 * h), int((0.25 + fold) * h)):
        fy = (y / h - 0.25) / fold
        x_start = 0.74 - fold * (1.0 - fy)
        for x in range(int(x_start * w), int((x_start + 0.011) * w)):
            if 0 <= x < w:
                px[y][x] = RED
    # Printed-red masthead rule across the top of the page.
    fill_rect(0.32, 0.30, 0.60, 0.345, RED, radius=0.010)
    # Text lines, the last one short: a front page, not a paragraph.
    fill_rect(0.32, 0.41, 0.68, 0.442, INK, radius=0.008)
    fill_rect(0.32, 0.475, 0.68, 0.507, INK, radius=0.008)
    fill_rect(0.32, 0.54, 0.55, 0.572, INK, radius=0.008)
    # A thin rule under the column, echoing the app's hairline separators.
    fill_rect(0.32, 0.635, 0.68, 0.648, RED, radius=0.004)

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
