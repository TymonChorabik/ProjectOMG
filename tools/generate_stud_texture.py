#!/usr/bin/env python3
"""
Generate the seamless square-stud textures used by Kung Fu Chop!

Style: the modern Roblox "studded" look (Steal an Egg, Steal a Brainrot, ...) — every stud is
a raised rounded square with a dark bevel on its left and bottom edges (light from the
top-right), a faint highlight on the top/right, and a soft drop shadow.

Outputs (assets/textures/):
  stud_overlay.png      128x128 RGBA, transparent background = 1 stud. Upload this and set
                        Config.Assets.StudTexture. It only adds light/shadow, so the same asset
                        works on every panel colour (UI ImageLabel, ScaleType Tile, TileSize
                        32x32) and every part colour (3D Texture, 1 stud per tile).
  checker_overlay.png   64x64 RGBA 2x2 checker (one cell darkened). Optional second upload for
                        Config.Assets.CheckerTexture: floors get the 4x4-stud checker tiles.
  stud_tile.png         128x128 opaque grey version for Blender materials / SurfaceAppearance.
  stud_ui_preview.png   a HUD panel with the overlay tiled at 32x32.
  stud_floor_preview.png  a green floor with studs + 4x4 checker, like the reference games.

Usage: python3 tools/generate_stud_texture.py   (needs Pillow + numpy)
"""

import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")

TILE = 128
SUPERSAMPLE = 4

STUD_HALF = 0.34  # half-size of the raised square (fraction of the tile)
STUD_CORNER = 0.06  # corner radius
BEVEL = 0.07  # bevel band width inside the square
FACE_LIGHT = 0.06  # flat top face: slightly lighter than the gaps
SHADOW_STRENGTH = 0.78  # left/bottom bevel darkness
HIGHLIGHT_STRENGTH = 0.32  # top/right bevel brightness
OUTLINE_STRENGTH = 0.30
DROP_SHADOW = (-0.03, 0.03, 0.14)  # (dx, dy, strength): down-left
LIGHT = np.array([0.6, -0.8])  # from the top-right (x right, y down)


def rounded_box_sdf(px, py, half, radius):
    qx = np.abs(px) - half + radius
    qy = np.abs(py) - half + radius
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - radius


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def stud_light_map(size: int) -> np.ndarray:
    """Signed light value per pixel: >0 lighten (white), <0 darken (black)."""
    coords = (np.arange(size) + 0.5) / size
    x, y = np.meshgrid(coords, coords)
    px, py = x - 0.5, y - 0.5
    aa = 1.5 / size

    sd = rounded_box_sdf(px, py, STUD_HALF, STUD_CORNER)
    value = np.zeros_like(x)

    # Soft drop shadow (down-left) outside the stud.
    sdx, sdy, strength = DROP_SHADOW
    shadow_sd = rounded_box_sdf(px - sdx, py - sdy, STUD_HALF, STUD_CORNER)
    value -= strength * (1 - smoothstep(-0.01, 0.025, shadow_sd)) * smoothstep(-aa, aa, sd)

    # Bevel: outward normal of the square, lit from the top-right.
    gy, gx = np.gradient(sd)
    norm = np.sqrt(gx * gx + gy * gy) + 1e-9
    nx, ny = gx / norm, gy / norm
    light = LIGHT / np.linalg.norm(LIGHT)
    facing = nx * light[0] + ny * light[1]
    bevel = np.where(facing < 0, facing * SHADOW_STRENGTH, facing * HIGHLIGHT_STRENGTH)

    depth = -sd  # >0 inside
    bevel_weight = 1 - smoothstep(BEVEL * 0.55, BEVEL, depth)
    stud = FACE_LIGHT * (1 - bevel_weight) + bevel * bevel_weight
    inside = smoothstep(-aa, aa, -sd)
    value = value * (1 - inside) + stud * inside

    # Crisp dark outline around each stud.
    value -= OUTLINE_STRENGTH * (1 - smoothstep(0, 0.012, np.abs(sd)))

    return np.clip(value, -1, 1)


def to_overlay(value: np.ndarray) -> Image.Image:
    rgb = np.where(value[..., None] > 0, 255, 0).astype(np.uint8).repeat(3, axis=2)
    alpha = (np.abs(value) * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def to_opaque(value: np.ndarray, base: int = 200) -> Image.Image:
    shade = np.where(value > 0, base + (255 - base) * value, base * (1 + value))
    grey = np.clip(shade, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([grey, grey, grey]), "RGB")


def checker_overlay(size: int = 64, darkness: float = 0.13) -> Image.Image:
    image = np.zeros((size, size, 4), dtype=np.uint8)
    half = size // 2
    alpha = int(255 * darkness)
    image[:half, :half, 3] = alpha
    image[half:, half:, 3] = alpha
    return Image.fromarray(image, "RGBA")


def tile_onto(base: Image.Image, overlay: Image.Image, tile: int) -> Image.Image:
    small = overlay.resize((tile, tile), Image.LANCZOS)
    for ty in range(0, base.height, tile):
        for tx in range(0, base.width, tile):
            base.alpha_composite(small, (tx, ty))
    return base


def ui_preview(overlay: Image.Image) -> Image.Image:
    """A red HUD panel with the overlay tiled at TileSize 32x32."""
    width, height = 512, 192
    body = tile_onto(Image.new("RGBA", (width, height), (170, 30, 34, 255)), overlay, 32)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width - 1, height - 1], radius=22, fill=255)
    panel = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    panel.paste(body, (0, 0), mask)
    ImageDraw.Draw(panel).rounded_rectangle([2, 2, width - 3, height - 3], radius=22, outline=(26, 18, 28, 255), width=5)
    return panel


def floor_preview(overlay: Image.Image, checker: Image.Image) -> Image.Image:
    """Green floor, 1 stud = 24px, with the 4x4-stud checker on top."""
    stud = 24
    floor = Image.new("RGBA", (stud * 16, stud * 12), (46, 160, 86, 255))
    tile_onto(floor, checker, stud * 8)
    tile_onto(floor, overlay, stud)
    return floor


def main():
    os.makedirs(OUT, exist_ok=True)
    value = stud_light_map(TILE * SUPERSAMPLE)

    overlay = to_overlay(value).resize((TILE, TILE), Image.LANCZOS)
    overlay.save(os.path.join(OUT, "stud_overlay.png"))
    to_opaque(value).resize((TILE, TILE), Image.LANCZOS).save(os.path.join(OUT, "stud_tile.png"))

    checker = checker_overlay()
    checker.save(os.path.join(OUT, "checker_overlay.png"))

    ui_preview(overlay).save(os.path.join(OUT, "stud_ui_preview.png"))
    floor_preview(overlay, checker).save(os.path.join(OUT, "stud_floor_preview.png"))
    print("Wrote stud textures + previews to", OUT)


if __name__ == "__main__":
    main()
