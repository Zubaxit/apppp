#!/usr/bin/env python3
"""Derive every Android launcher asset from the master Amar News icon.

The master artwork lives at `assets/brand/icon_master.png` (1024x1024, generated
once and reviewed by hand). Everything the launcher, the splash and the in-app
brand mark use is produced from that single file by this script, so the app can
never drift away from its icon:

    mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png     legacy icon
    mipmap-*/ic_launcher_foreground.png                         adaptive foreground
    drawable-nodpi/launch_mark.png                              splash mark
    assets/icons/icon-512.png                                   store / README
    assets/icons/ic_launcher_{mdpi..xxxhdpi}.png                docs
    assets/brand/amar_news_mark.png                             in-app mark

Adaptive-icon geometry follows the Android spec: the foreground canvas is 108 dp
and only the central 66 dp is guaranteed visible, so the artwork is scaled into
that safe zone rather than being cropped by whichever mask the launcher uses.

    python3 -m venv .venv && .venv/bin/pip install pillow
    .venv/bin/python scripts/build_launcher_icons.py

Pillow is a build-time tool only; the app itself ships the emitted PNGs.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "brand" / "icon_master.png"

# density bucket -> legacy icon px
LEGACY = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
# adaptive-icon foreground is 108 dp; the visible safe circle is 66 dp
FOREGROUND = {bucket: round(108 * px / 48) for bucket, px in LEGACY.items()}
SAFE_FRACTION = 66 / 108


def rounded(image: Image.Image, radius_fraction: float) -> Image.Image:
    """Clip to a rounded square with a hard alpha edge (no resampling fringe)."""
    size = image.size[0]
    mask = Image.new("L", (size * 4, size * 4), 0)
    from PIL import ImageDraw

    radius = int(size * 4 * radius_fraction)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1), radius=radius, fill=255
    )
    mask = mask.resize((size, size), Image.LANCZOS)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def square_master() -> Image.Image:
    image = Image.open(MASTER).convert("RGB")
    if image.size[0] != image.size[1]:
        side = min(image.size)
        left = (image.size[0] - side) // 2
        top = (image.size[1] - side) // 2
        image = image.crop((left, top, left + side, top + side))
    return image


def write(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)}  {path.stat().st_size} B")


def main() -> int:
    if not MASTER.exists():
        raise SystemExit(f"master artwork missing: {MASTER.relative_to(ROOT)}")
    master = square_master()
    res = ROOT / "android" / "app" / "src" / "main" / "res"

    print("legacy launcher icons")
    for bucket, px in LEGACY.items():
        icon = master.resize((px, px), Image.LANCZOS)
        write(res / f"mipmap-{bucket}" / "ic_launcher.png", icon)

    print("adaptive foregrounds (artwork inside the 66 dp safe zone)")
    for bucket, px in FOREGROUND.items():
        art_size = max(1, round(px * SAFE_FRACTION))
        art = master.resize((art_size, art_size), Image.LANCZOS).convert("RGBA")
        canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        offset = (px - art_size) // 2
        canvas.alpha_composite(art, (offset, offset))
        write(res / f"mipmap-{bucket}" / "ic_launcher_foreground.png", canvas)

    print("splash mark (a single bitmap, so the splash shows the real icon)")
    write(res / "drawable-nodpi" / "launch_mark.png", rounded(master.resize((256, 256), Image.LANCZOS), 0.22))

    print("store + documentation copies")
    write(ROOT / "assets" / "icons" / "icon-512.png", master.resize((512, 512), Image.LANCZOS))
    for bucket, px in LEGACY.items():
        write(
            ROOT / "assets" / "icons" / f"ic_launcher_{bucket}.png",
            master.resize((px, px), Image.LANCZOS),
        )

    print("in-app mark (the same artwork, pre-rounded for light and dark chrome)")
    write(
        ROOT / "assets" / "brand" / "amar_news_mark.png",
        rounded(master.resize((320, 320), Image.LANCZOS), 0.22),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
