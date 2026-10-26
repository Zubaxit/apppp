#!/usr/bin/env python3
"""Bundle the publishers' own marks for the directory and the feed rows.

Each publisher's artwork is placed by hand in `scripts/publisher_logo_sources/<id>.<ext>`
— downloaded from the source recorded in `assets/publishers/SOURCES.md`, then
looked at before it is committed. This script does the mechanical part:

  * trims the transparent/white margin so the mark fills the tile;
  * keeps the original aspect ratio (contain, never stretched or cropped);
  * centres it on a transparent square canvas at a fixed size;
  * writes one PNG per publisher plus `assets/publishers/logos.json`, the map the
    app reads and the tests validate.

Run:  .venv/bin/python scripts/prepare_publisher_logos.py

Nothing is fetched here. That is deliberate: an automatic downloader would make
it easy to ship a wrong logo, and the whole point of this set is that every mark
was matched to its publisher by a human.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "scripts" / "publisher_logo_sources"
OUT = ROOT / "assets" / "publishers"
MANIFEST = OUT / "logos.json"

SIZE = 128          # 62 dp at 2x is 124 px, so 128 covers the largest tile
PADDING = 0.04      # of the canvas, keeps a wordmark off the tile edge
WHITE_THRESHOLD = 246


def flatten_alpha(image: Image.Image) -> Image.Image:
    """Compose onto white and return an RGB image."""
    if image.mode in ("RGBA", "LA", "P"):
        image = image.convert("RGBA")
        background = Image.new("RGBA", image.size, (255, 255, 255, 255))
        return Image.alpha_composite(background, image).convert("RGB")
    return image.convert("RGB")


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of everything that is not white and not transparent."""
    rgb = flatten_alpha(image)
    background = Image.new("RGB", rgb.size, (255, 255, 255))
    diff = ImageChops.difference(rgb, background).convert("L")
    mask = diff.point(lambda value: 255 if value > WHITE_THRESHOLD - 240 else 0)
    box = mask.getbbox()
    return box or (0, 0, rgb.size[0], rgb.size[1])


def normalise(path: Path) -> Image.Image:
    with Image.open(path) as opened:
        source = opened.convert("RGBA")
    box = content_box(source)
    trimmed = source.crop(box)

    canvas_size = SIZE
    inner = int(canvas_size * (1 - PADDING * 2))
    ratio = min(inner / trimmed.size[0], inner / trimmed.size[1])
    scaled = trimmed.resize(
        (max(1, round(trimmed.size[0] * ratio)), max(1, round(trimmed.size[1] * ratio))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(
        scaled, ((canvas_size - scaled.size[0]) // 2, (canvas_size - scaled.size[1]) // 2)
    )
    return canvas


def main() -> int:
    if not RAW.exists():
        raise SystemExit(
            "no source artwork: expected scripts/publisher_logo_sources/<id>.<ext>"
        )

    entries: dict[str, dict[str, str]] = {}
    for path in sorted(RAW.iterdir()):
        if path.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        publisher_id = path.stem
        logo = normalise(path)
        target = OUT / f"{publisher_id}.png"
        logo.save(target, "PNG", optimize=True)
        entries[publisher_id] = {"file": f"assets/publishers/{publisher_id}.png"}
        print(f"  {publisher_id:<18} {logo.size[0]}x{logo.size[1]}  {target.stat().st_size} B")

    MANIFEST.write_text(
        json.dumps(
            {
                "note": (
                    "Bundled publisher marks, used only to identify each publisher in this "
                    "reader. Provenance and the exact source for each file: "
                    "assets/publishers/SOURCES.md."
                ),
                "size": SIZE,
                "logos": entries,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"  manifest: {MANIFEST.relative_to(ROOT)} ({len(entries)} publishers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
