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


TILE = (24, 24, 28)  # graphite, sampled from the master's own tile


def square_master() -> Image.Image:
    image = Image.open(MASTER).convert("RGB")
    if image.size[0] != image.size[1]:
        side = min(image.size)
        left = (image.size[0] - side) // 2
        top = (image.size[1] - side) // 2
        image = image.crop((left, top, left + side, top + side))
    # The generator paints its own rounded tile over a dark field; flatten those
    # corners to the tile colour so the launcher's own mask is the only edge.
    flat = Image.new("RGB", image.size, TILE)
    flat.paste(image, (0, 0), rounded(Image.new("RGB", image.size, (255, 255, 255)), 0.235))
    return flat


def page_rgba(master: Image.Image) -> Image.Image:
    """Lift the page artwork off the generated tile.

    The master is a tile with a page on it. Android needs the pieces separately:
    the legacy icon composes them back together (so the generated tile shadow is
    replaced by the app's own), and the adaptive icon needs the page alone
    inside the safe zone. Pixels that are tile — the dark field, the soft
    shadow the generator drew — become transparent; the white sheet and the
    saturated red fold are kept with a soft edge so the cutout stays smooth.
    """
    from PIL import ImageFilter

    rgb = master.convert("RGB")
    mask = Image.new("L", rgb.size, 0)
    src = rgb.load()
    dst = mask.load()
    for y in range(rgb.size[1]):
        for x in range(rgb.size[0]):
            r, g, b = src[x, y]
            bright = (r + g + b) / 3
            redness = (r - g) * 1.4
            value = max(bright - 118, redness - 40)
            dst[x, y] = 0 if value <= 0 else (255 if value >= 55 else int(value / 55 * 255))
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))

    art = rgb.convert("RGBA")
    art.putalpha(mask)
    box = mask.getbbox()
    if box is None:
        raise SystemExit("could not locate the page artwork in the master")
    pad = round(min(box[2] - box[0], box[3] - box[1]) * 0.01)
    return art.crop((
        max(0, box[0] - pad),
        max(0, box[1] - pad),
        min(rgb.size[0], box[2] + pad),
        min(rgb.size[1], box[3] + pad),
    ))


def compose_tile(page: Image.Image, px: int, page_fraction: float,
                 radius_fraction: float = 0.235) -> Image.Image:
    """The graphite tile with the page centred on it, at `px` square."""
    tile = Image.new("RGBA", (px, px), TILE + (255,))
    tile.putalpha(rounded(Image.new("RGB", (px, px), TILE), radius_fraction).getchannel("A"))
    target = max(1, round(px * page_fraction))
    ratio = target / max(page.size)
    art = page.resize(
        (max(1, round(page.size[0] * ratio)), max(1, round(page.size[1] * ratio))),
        Image.LANCZOS,
    )
    tile.alpha_composite(art, ((px - art.size[0]) // 2, (px - art.size[1]) // 2))
    return tile


def write(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)}  {path.stat().st_size} B")


def main() -> int:
    if not MASTER.exists():
        raise SystemExit(f"master artwork missing: {MASTER.relative_to(ROOT)}")
    master = square_master()
    res = ROOT / "android" / "app" / "src" / "main" / "res"

    page = page_rgba(master)

    print("legacy launcher icons (tile + page, generated from the master)")
    for bucket, px in LEGACY.items():
        write(res / f"mipmap-{bucket}" / "ic_launcher.png", compose_tile(page, px, 0.62))

    print("adaptive foregrounds (page artwork inside the 66 dp safe zone)")
    for bucket, px in FOREGROUND.items():
        # 84 % of the safe circle: Android's own icons leave a little air.
        target = max(1, round(px * SAFE_FRACTION * 0.88))
        ratio = target / max(page.size)
        art = page.resize(
            (max(1, round(page.size[0] * ratio)),
             max(1, round(page.size[1] * ratio))),
            Image.LANCZOS,
        )
        canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        canvas.alpha_composite(
            art, ((px - art.size[0]) // 2, (px - art.size[1]) // 2)
        )
        write(res / f"mipmap-{bucket}" / "ic_launcher_foreground.png", canvas)

    print("splash mark (a single bitmap, so the splash shows the real icon)")
    write(res / "drawable-nodpi" / "launch_mark.png", compose_tile(page, 256, 0.62))

    print("store + documentation copies")
    write(ROOT / "assets" / "icons" / "icon-512.png", compose_tile(page, 512, 0.62))
    for bucket, px in LEGACY.items():
        write(
            ROOT / "assets" / "icons" / f"ic_launcher_{bucket}.png",
            compose_tile(page, px, 0.62),
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
