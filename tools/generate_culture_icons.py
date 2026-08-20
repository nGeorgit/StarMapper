#!/usr/bin/env python3
"""Generates assets/culture_icons/*.png -- one glyph per Culture-menu category tile,
drawn in the same dot-and-line style ConstellationLines.gd/StarField.gd render on the
sphere (blue lines, glowing white star points), so tiles match the app's own visual
language instead of mismatched historical illustrations. Run after editing GLYPHS below
or after re-running parse_stellarium_data.py (constellation ids/segments can shift).

    python3 tools/generate_culture_icons.py
"""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SETS_DIR = ROOT / "data" / "constellation_sets"
OUT_DIR = ROOT / "assets" / "culture_icons"

CANVAS = 512
SUPERSAMPLE = 4  # draw at 4x, downsample for antialiasing
PADDING_FRAC = 0.22  # fraction of canvas kept empty on each side around the glyph's bbox

LINE_COLOR = (102, 153, 255, 235)  # matches ConstellationLines.gd line_color (0.4, 0.6, 1.0)
LINE_WIDTH = 9  # at supersample scale
STAR_COLOR = (255, 255, 255, 255)
STAR_GLOW_COLOR = (190, 210, 255, 255)
STAR_CORE_RADIUS = 7  # at supersample scale
STAR_GLOW_RADIUS = 26

# One representative, well-connected constellation per category tile, chosen from a
# member of that category's own skyculture data (see CultureMenu.gd CATEGORY_DEFS).
GLYPHS = [
    {"out": "modern_glyph.png", "set": "modern", "cid": "Ori"},
    {"out": "chinese_glyph.png", "set": "chinese", "cid": "206"},
    {"out": "greek_glyph.png", "set": "greek_leidenAratea", "cid": "Ori"},
    {"out": "arabic_glyph.png", "set": "arabic_al-sufi", "cid": "Ori"},
    {"out": "babylonian_glyph.png", "set": "babylonian_mulapin", "cid": "037"},
]


def find_constellation(set_id: str, cid: str) -> dict:
    data = json.loads((SETS_DIR / f"{set_id}.json").read_text())
    for c in data["constellations"]:
        if c["id"] == cid:
            return c
    raise KeyError(f"{cid} not found in {set_id}.json")


def unit_vector(ra_deg: float, dec_deg: float) -> tuple:
    ra, dec = math.radians(ra_deg), math.radians(dec_deg)
    return (math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec))


def vector_to_radec(v: tuple) -> tuple:
    x, y, z = v
    n = math.sqrt(x * x + y * y + z * z)
    x, y, z = x / n, y / n, z / n
    dec = math.asin(z)
    ra = math.atan2(y, x)
    return math.degrees(ra), math.degrees(dec)


def gnomonic_project(ra_deg: float, dec_deg: float, ra0_deg: float, dec0_deg: float) -> tuple:
    """Tangent-plane projection centered on (ra0, dec0); fine for a single constellation's
    angular extent (never near the 90-degree-from-center singularity)."""
    ra, dec = math.radians(ra_deg), math.radians(dec_deg)
    ra0, dec0 = math.radians(ra0_deg), math.radians(dec0_deg)
    d_ra = ra - ra0
    cos_c = math.sin(dec0) * math.sin(dec) + math.cos(dec0) * math.cos(dec) * math.cos(d_ra)
    x = math.cos(dec) * math.sin(d_ra) / cos_c
    y = (math.cos(dec0) * math.sin(dec) - math.sin(dec0) * math.cos(dec) * math.cos(d_ra)) / cos_c
    return x, y


def render_glyph(constellation: dict, out_path: Path) -> None:
    segments = constellation["segments"]

    vertices_radec = []
    for seg in segments:
        vertices_radec.append((seg[0], seg[1]))
        vertices_radec.append((seg[2], seg[3]))

    mean = [0.0, 0.0, 0.0]
    for ra, dec in vertices_radec:
        vx, vy, vz = unit_vector(ra, dec)
        mean[0] += vx
        mean[1] += vy
        mean[2] += vz
    ra0, dec0 = vector_to_radec(tuple(mean))

    projected_segments = [
        (
            gnomonic_project(seg[0], seg[1], ra0, dec0),
            gnomonic_project(seg[2], seg[3], ra0, dec0),
        )
        for seg in segments
    ]
    all_points = [p for pair in projected_segments for p in pair]
    xs = [p[0] for p in all_points]
    ys = [p[1] for p in all_points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    span = max(max_x - min_x, max_y - min_y, 1e-6)

    canvas = CANVAS * SUPERSAMPLE
    usable = canvas * (1.0 - 2.0 * PADDING_FRAC)
    scale = usable / span
    cx, cy = (min_x + max_x) / 2.0, (min_y + max_y) / 2.0

    def to_pixels(pt):
        x, y = pt
        # flip y: dec increases upward on sky, downward in image pixel space
        return (canvas / 2.0 + (x - cx) * scale, canvas / 2.0 - (y - cy) * scale)

    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    glow_layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    glow_draw = ImageDraw.Draw(glow_layer)

    for a, b in projected_segments:
        pa, pb = to_pixels(a), to_pixels(b)
        draw.line([pa, pb], fill=LINE_COLOR, width=LINE_WIDTH)

    seen = set()
    for ra, dec in vertices_radec:
        key = (round(ra, 4), round(dec, 4))
        if key in seen:
            continue
        seen.add(key)
        px, py = to_pixels(gnomonic_project(ra, dec, ra0, dec0))
        r = STAR_GLOW_RADIUS
        glow_draw.ellipse([px - r, py - r, px + r, py + r], fill=STAR_GLOW_COLOR)

    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=STAR_GLOW_RADIUS * 0.6))
    img = Image.alpha_composite(glow_layer, img)
    draw = ImageDraw.Draw(img)
    for ra, dec in seen:
        px, py = to_pixels(gnomonic_project(ra, dec, ra0, dec0))
        r = STAR_CORE_RADIUS
        draw.ellipse([px - r, py - r, px + r, py + r], fill=STAR_COLOR)

    img = img.resize((CANVAS, CANVAS), Image.LANCZOS)
    img.save(out_path)
    print(f"wrote {out_path.relative_to(ROOT)} ({len(segments)} segments, {len(seen)} stars)")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for glyph in GLYPHS:
        constellation = find_constellation(glyph["set"], glyph["cid"])
        render_glyph(constellation, OUT_DIR / glyph["out"])


if __name__ == "__main__":
    main()
