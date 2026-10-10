#!/usr/bin/env python3
"""
Render quick isometric previews of the baked map (src/workspace/Map/*.model.json) so you
can eyeball the layout without opening Studio. Writes docs/map/Hub.png, Lane.png and Training.png.

    python3 tools/mapgen/render_preview.py      (needs Pillow + numpy)

This is a flat-shaded block renderer (no textures, text or particles) — Studio is the real view.
"""

import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAP_DIR = os.path.join(ROOT, "src", "workspace", "Map")

# name -> (min x, max x, min z, max z) region to show
VIEWS = {
    "Hub": (-360, 270, -190, 130),
    "Lane": (-150, 150, 40, 1000),
    "Training": (-312, -66, -44, 60),
}
OUT_DIR = os.path.join(ROOT, "docs", "map")

WIDTH, HEIGHT = 1600, 1000
YAW = math.radians(-28)  # camera swings left of the entrance
PITCH = math.radians(38)
LIGHT = np.array([0.45, 0.8, -0.4])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
SKY_TOP, SKY_BOTTOM = (120, 180, 255), (200, 230, 255)

# Camera basis (looking toward +Z from the front-left, tilted down).
forward = np.array([math.sin(YAW) * math.cos(PITCH), -math.sin(PITCH), math.cos(YAW) * math.cos(PITCH)])
right = np.cross([0, 1, 0], forward)
right /= np.linalg.norm(right)
up = np.cross(forward, right)
TO_CAMERA = -forward


def cframe(props):
    cf = props.get("CFrame", {}).get("CFrame")
    if not cf:
        return np.zeros(3), np.eye(3)
    return np.array(cf["position"], dtype=float), np.array(cf["orientation"], dtype=float)


def box_faces(size):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    corners = np.array([[sx * hx, sy * hy, sz * hz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)])
    quads = [
        ([4, 5, 7, 6], [1, 0, 0]),
        ([0, 2, 3, 1], [-1, 0, 0]),
        ([2, 6, 7, 3], [0, 1, 0]),
        ([0, 1, 5, 4], [0, -1, 0]),
        ([1, 3, 7, 5], [0, 0, 1]),
        ([0, 4, 6, 2], [0, 0, -1]),
    ]
    return [(corners[idx], np.array(n, dtype=float)) for idx, n in quads]


MAX_TILE = 6  # studs; big faces are split so painter's-algorithm depth sorting stays correct


def subdivide(quad):
    a, b, c, d = quad
    nu = max(1, math.ceil(np.linalg.norm(b - a) / MAX_TILE))
    nv = max(1, math.ceil(np.linalg.norm(d - a) / MAX_TILE))
    if nu == 1 and nv == 1:
        return [quad]

    def lerp(u, v):
        return a + (b - a) * u + (d - a) * v

    tiles = []
    for i in range(nu):
        for j in range(nv):
            u0, u1, v0, v1 = i / nu, (i + 1) / nu, j / nv, (j + 1) / nv
            tiles.append(np.array([lerp(u0, v0), lerp(u1, v0), lerp(u1, v1), lerp(u0, v1)]))
    return tiles


def cylinder_faces(size, sides=12):
    # Roblox cylinders run along local X.
    h, r = size[0] / 2, min(size[1], size[2]) / 2
    ring = [(r * math.cos(2 * math.pi * i / sides), r * math.sin(2 * math.pi * i / sides)) for i in range(sides)]
    faces = []
    for i in range(sides):
        (y0, z0), (y1, z1) = ring[i], ring[(i + 1) % sides]
        quad = np.array([[-h, y0, z0], [h, y0, z0], [h, y1, z1], [-h, y1, z1]])
        mid = math.pi * 2 * (i + 0.5) / sides
        faces.append((quad, np.array([0, math.cos(mid), math.sin(mid)])))
    faces.append((np.array([[h, y, z] for y, z in ring]), np.array([1.0, 0, 0])))
    faces.append((np.array([[-h, y, z] for y, z in reversed(ring)]), np.array([-1.0, 0, 0])))
    return faces


def collect(node, out):
    props = node.get("Properties", {})
    if node["ClassName"] in ("Part", "SpawnLocation") and props.get("Transparency", 0) < 0.95:
        out.append({**props, "Name": node.get("Name")})
    for child in node.get("Children", []):
        collect(child, out)
    return out


def project(points):
    return np.stack([points @ right, -(points @ up), points @ forward], axis=1)


def floor_info(parts):
    """(top y, centre, half extents) of the dojo floor; framing ignores far-away decor."""
    for props in parts:
        if props.get("Name") == "Floor":
            pos, _ = cframe(props)
            return pos[1] + props["Size"][1] / 2, pos, np.array(props["Size"]) / 2
    return 0.0, np.zeros(3), np.array([1e9, 1e9, 1e9])


def render(name, parts):
    polygons = []
    ground, floor_centre, floor_half = floor_info(parts)
    frame_points = [
        project((floor_centre + floor_half * np.array([sx, sy, sz]))[None, :])[0][:2]
        for sx in (-1, 1)
        for sy in (-1, 1)
        for sz in (-1, 1)
    ] if floor_half[0] < 1e8 else []
    for props in parts:
        pos, rot = cframe(props)
        size = props.get("Size", [4, 1, 2])
        if props.get("Transparency", 0) >= 0.95:
            continue
        color = np.array(props.get("Color", [0.64, 0.64, 0.64])) * 255
        shape = props.get("Shape", "Block")
        neon = props.get("Material") == "Neon"
        if shape == "Ball":
            center = project(pos[None, :])[0]
            polygons.append(("ball", center, size[0] / 2, color, neon))  # (layer slot = radius)
            continue
        offset_from_floor = np.abs(pos - floor_centre)
        if offset_from_floor[0] <= floor_half[0] + 5 and offset_from_floor[2] <= floor_half[2] + 5:
            frame_points.append(project(pos[None, :])[0][:2])
        faces = cylinder_faces(size) if shape == "Cylinder" else box_faces(size)
        for local, normal in faces:
            world_normal = rot @ normal
            if world_normal @ TO_CAMERA <= 0:
                continue
            world = local @ rot.T + pos
            shade = 1.0 if neon else 0.55 + 0.45 * max(0.0, world_normal @ LIGHT)
            fill = np.clip(color * shade, 0, 255)
            tiles = subdivide(world) if len(world) == 4 else [world]
            # Flat tops lying on the floor (floor, mats, pads) are drawn first, lowest first.
            on_ground = world_normal[1] > 0.99 and world[:, 1].max() <= ground + 1.6
            layer = world[:, 1].mean() if on_ground else None
            for tile in tiles:
                polygons.append(("poly", project(tile), layer, fill, neon))

    # Fit everything on screen.
    points = np.array(frame_points)
    lo, hi = points.min(axis=0), points.max(axis=0)
    scale = min((WIDTH - 120) / (hi[0] - lo[0]), (HEIGHT - 160) / (hi[1] - lo[1]))
    offset = np.array([WIDTH / 2, HEIGHT / 2 + 30]) - (lo + hi) / 2 * scale

    image = Image.new("RGB", (WIDTH, HEIGHT))
    sky = ImageDraw.Draw(image)
    for y in range(HEIGHT):
        t = y / HEIGHT
        sky.line([(0, y), (WIDTH, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM)))
    draw = ImageDraw.Draw(image)

    def order(p):
        if p[0] == "poly" and p[2] is not None:
            return (0, p[2], -p[1][:, 2].mean())
        depth = p[1][:, 2].mean() if p[0] == "poly" else p[1][2]
        return (1, 0, -depth)

    for kind, pts, radius, color, _ in sorted(polygons, key=order):
        fill = tuple(int(c) for c in color)
        if kind == "ball":
            cx, cy = pts[:2] * scale + offset
            r = radius * scale
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=(30, 25, 30))
        else:
            xy = [tuple(p) for p in (pts[:, :2] * scale + offset)]
            draw.polygon(xy, fill=fill, outline=fill)

    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 44)
    except OSError:
        font = ImageFont.load_default()
    draw.text((40, 30), f"{name} — map preview", fill=(255, 255, 255), font=font, stroke_width=4, stroke_fill=(30, 20, 30))
    return image


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    parts = []
    for filename in sorted(os.listdir(MAP_DIR)):
        if filename.endswith(".model.json"):
            with open(os.path.join(MAP_DIR, filename), encoding="utf-8") as f:
                collect(json.load(f), parts)
    for name, (min_x, max_x, min_z, max_z) in VIEWS.items():
        inside = []
        for props in parts:
            pos, _ = cframe(props)
            if min_x - 40 <= pos[0] <= max_x + 40 and min_z - 40 <= pos[2] <= max_z + 40:
                inside.append(props)
        floor = {"Name": "Floor", "Size": [max_x - min_x, 0.01, max_z - min_z], "Transparency": 1,
                 "CFrame": {"CFrame": {"position": [(min_x + max_x) / 2, -0.01, (min_z + max_z) / 2],
                                       "orientation": [[1, 0, 0], [0, 1, 0], [0, 0, 1]]}}}
        target = os.path.join(OUT_DIR, f"{name}.png")
        render(name, [floor] + inside).save(target)
        print(f"  {name}: {len(inside)} parts -> {os.path.relpath(target, ROOT)}")


if __name__ == "__main__":
    main()
