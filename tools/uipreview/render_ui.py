#!/usr/bin/env python3
"""
Render the game's real UI to PNG without Roblox.

The client UI is built in code (src/client/UI, src/client/Controllers/UIController). This tool
runs that code in the Luau CLI on a mock Roblox API (tools/mapgen/mock_roblox.luau +
tools/uipreview/mock_gui.luau + stubs.luau), serialises PlayerGui to JSON and lays it out and
draws it here: UDim2 sizes/positions, anchor points, UIListLayout / UIGridLayout / UIPadding /
UIScale, UICorner, UIStroke (borders and text outlines), UIGradient, TextScaled text with
UITextSizeConstraint, emoji, ScrollingFrames, studded ViewportFrame backgrounds and simple 3D
thumbnails of pet/item models.

It is an approximation of the Roblox renderer, good enough to judge layout, sizes, colours and
style. Usage:

    python3 tools/uipreview/render_ui.py                 # every scene -> docs/ui/*.png
    python3 tools/uipreview/render_ui.py hud shop        # just these scenes
    LUAU=/path/to/luau UIPREVIEW_FONTS=/dir python3 tools/uipreview/render_ui.py

Fonts: Montserrat (Roblox's Gotham* fonts), Luckiest Guy and Fredoka One TTFs are read from
tools/uipreview/fonts (or $UIPREVIEW_FONTS); Noto Color Emoji from the system.
"""

import json
import math
import os
import subprocess
import sys
import tempfile
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "docs", "ui")
FONT_DIR = os.environ.get("UIPREVIEW_FONTS", os.path.join(HERE, "fonts"))
EMOJI_FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
FALLBACK_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

W, H = 1920, 1080
SS = 2  # supersampling
GUI_INSET = 58  # Roblox top bar (ScreenGuis without IgnoreGuiInset start below it)

FONT_FILES = {
    "LuckiestGuy": "LuckiestGuy.ttf",
    "FredokaOne": "FredokaOne.ttf",
    "GothamBlack": "Montserrat-Black.ttf",
    "GothamBold": "Montserrat-ExtraBold.ttf",
    "GothamMedium": "Montserrat-Bold.ttf",
    "Gotham": "Montserrat-Bold.ttf",
    "Montserrat": "Montserrat-Bold.ttf",
}

# --------------------------------------------------------------------------------------------
# Running the Luau side
# --------------------------------------------------------------------------------------------

SHARED = "src/shared"
CLIENT = "src/client"


def module_paths():
    out = []
    for base, mount in ((SHARED, "ReplicatedStorage/Shared"), (CLIENT, "StarterPlayer/StarterPlayerScripts/Client")):
        for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
            for name in sorted(files):
                if not name.endswith(".luau") or name.endswith(".client.luau") or name.endswith(".server.luau"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, name), os.path.join(ROOT, base))
                out.append((mount + "/" + rel[: -len(".luau")].replace(os.sep, "/"), os.path.join(dirpath, name)))
    return out


def bundle(scene_code: str) -> str:
    def read(path):
        with open(path, encoding="utf-8") as f:
            return f.read()

    stubs = read(os.path.join(HERE, "stubs.luau"))
    parts = [
        read(os.path.join(ROOT, "tools", "mapgen", "mock_roblox.luau")),
        "local function warn(...) end",
        read(os.path.join(HERE, "mock_gui.luau")),
        stubs,
    ]
    for path, source in module_paths():
        if f'STUB_MODULES["{path}"]' in stubs:
            body = f'return STUB_MODULES["{path}"]()'
        else:
            body = read(source).replace("export type ", "type ")
        parts.append(f'defineModule("{path}", function(script)\n{body}\nend)')
    parts.append(
        """
local function guiTree()
	local out = {}
	for _, child in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
		table.insert(out, serialize(child))
	end
	return "[" .. table.concat(out, ",") .. "]"
end
"""
    )
    parts.append(scene_code)
    parts.append('print("@@GUI@@" .. guiTree())')
    return "\n".join(parts)


def run_scene(scene_code: str):
    luau = os.environ.get("LUAU", "luau")
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "uipreview.luau")
        with open(path, "w", encoding="utf-8") as f:
            f.write(bundle(scene_code))
        result = subprocess.run([luau, path], cwd=tmp, capture_output=True, text=True)
    if result.returncode != 0 or "@@GUI@@" not in result.stdout:
        sys.stderr.write(result.stdout[-3000:] + "\n" + result.stderr[-3000:] + "\n")
        raise SystemExit("Luau scene failed")
    line = next(l for l in result.stdout.splitlines() if l.startswith("@@GUI@@"))
    return json.loads(line[len("@@GUI@@"):])


# --------------------------------------------------------------------------------------------
# Values
# --------------------------------------------------------------------------------------------


def val(node, key, default=None):
    v = node["Properties"].get(key)
    if v is None:
        return default
    if isinstance(v, dict) and "$t" in v:
        t, x = v["$t"], v["v"]
        if t == "Enum":
            return x
        return x
    return v


def color(node, key, default):
    c = val(node, key)
    if c is None:
        return default
    return tuple(max(0, min(255, round(ch * 255))) for ch in c)


def udim2(node, key, default):
    v = val(node, key)
    return v if v is not None else default


def udim(node, key, default=(0, 0)):
    v = val(node, key)
    return tuple(v) if v is not None else default


def kids(node, cls=None):
    return [c for c in node["Children"] if cls is None or c["ClassName"] == cls]


def first(node, cls):
    for c in node["Children"]:
        if c["ClassName"] == cls:
            return c
    return None


GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ScrollingFrame", "ViewportFrame", "CanvasGroup"}
TEXT_CLASSES = {"TextLabel", "TextButton", "TextBox"}


def default_size(cls):
    if cls in TEXT_CLASSES:
        return [0, 200, 0, 50]
    return [0, 100, 0, 100]


# --------------------------------------------------------------------------------------------
# Fonts and text
# --------------------------------------------------------------------------------------------


@lru_cache(maxsize=None)
def font_path(name):
    file = FONT_FILES.get(name)
    if file and os.path.exists(os.path.join(FONT_DIR, file)):
        return os.path.join(FONT_DIR, file)
    return FALLBACK_FONT


@lru_cache(maxsize=None)
def get_font(name, px):
    return ImageFont.truetype(font_path(name), max(1, int(round(px))))


@lru_cache(maxsize=None)
def emoji_font():
    return ImageFont.truetype(EMOJI_FONT, 109)


def is_emoji(ch):
    o = ord(ch)
    return (
        0x1F000 <= o <= 0x1FAFF
        or 0x2600 <= o <= 0x27BF
        or 0x2B00 <= o <= 0x2BFF
        or 0x2190 <= o <= 0x21FF
        or 0x2300 <= o <= 0x23FF
        or o in (0x00A9, 0x00AE, 0x203C, 0x2049, 0x2122, 0x2139, 0x3030, 0x303D)
    )


@lru_cache(maxsize=4096)
def emoji_image(seq):
    f = emoji_font()
    img = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    try:
        d.text((10, 10), seq, font=f, embedded_color=True)
    except Exception:
        return None
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else None


def runs(text):
    """Split text into (is_emoji, string) runs; variation selectors / ZWJ stick to emoji."""
    out = []
    i = 0
    while i < len(text):
        ch = text[i]
        if is_emoji(ch):
            seq = ch
            i += 1
            while i < len(text) and (ord(text[i]) in (0xFE0F, 0x200D) or (seq.endswith("‍") and is_emoji(text[i]))):
                seq += text[i]
                i += 1
            out.append((True, seq))
        else:
            if ord(ch) in (0xFE0F, 0x200D):
                i += 1
                continue
            if out and not out[-1][0]:
                out[-1] = (False, out[-1][1] + ch)
            else:
                out.append((False, ch))
            i += 1
    return out


def parse_rich(text, default):
    """Minimal RichText: <font color="#rrggbb"> plus stripping of other tags.
    Returns (plain text, per-character colours)."""
    import re

    plain, colours, stack = [], [], [default]
    pos = 0
    for m in re.finditer(r"<(/?)(\w+)([^>]*)>", text):
        chunk = text[pos : m.start()]
        plain.append(chunk)
        colours.extend([stack[-1]] * len(chunk))
        closing, tag, attrs = m.group(1), m.group(2).lower(), m.group(3)
        if tag == "font":
            if closing:
                if len(stack) > 1:
                    stack.pop()
            else:
                cm = re.search(r'color\s*=\s*"#?([0-9a-fA-F]{6})"', attrs)
                stack.append(tuple(int(cm.group(1)[i : i + 2], 16) for i in (0, 2, 4)) if cm else stack[-1])
        elif tag == "br":
            plain.append("\n")
            colours.append(stack[-1])
        pos = m.end()
    chunk = text[pos:]
    plain.append(chunk)
    colours.extend([stack[-1]] * len(chunk))
    out = "".join(plain).replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
    return out, colours[: len(out)]


def text_width(text, font_name, px):
    f = get_font(font_name, px)
    w = 0.0
    for emo, s in runs(text):
        if emo:
            w += px * 1.12
        else:
            w += f.getlength(s)
    return w


def wrap(text, font_name, px, max_w, wrap_words):
    lines = []
    for para in text.split("\n"):
        if not wrap_words:
            lines.append(para)
            continue
        words = para.split(" ")
        current = ""
        for word in words:
            trial = word if not current else current + " " + word
            if current and text_width(trial, font_name, px) > max_w + 0.5:
                lines.append(current)
                current = word
            else:
                current = trial
        lines.append(current)
    return lines


def fit_text(text, font_name, box_w, box_h, scaled, size, wrapped, max_size, min_size):
    if not scaled:
        return size, wrap(text, font_name, size, box_w, wrapped)
    hi = int(min(100, max_size if max_size else 100))
    for px in range(hi, 0, -1):
        if px < (min_size or 1):
            break
        lines = wrap(text, font_name, px, box_w, True)
        if len(lines) * px <= box_h + 0.01 and all(text_width(l, font_name, px) <= box_w + 0.5 for l in lines):
            return px, lines
    px = max(1, int(min_size or 1))
    return px, wrap(text, font_name, px, box_w, True)


# --------------------------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------------------------


class Box:
    __slots__ = ("node", "x", "y", "w", "h", "k", "ox", "oy", "children", "clip", "z", "content_h", "canvas")

    def screen(self):
        return (self.ox + self.k * self.x, self.oy + self.k * self.y, self.k * self.w, self.k * self.h)


def resolve(ud, pw, ph):
    return ud[0] * pw + ud[1], ud[2] * ph + ud[3]


def visible_gui(node):
    return node["ClassName"] in GUI_CLASSES and val(node, "Visible", True)


def apply_constraints(node, w, h):
    ar = first(node, "UIAspectRatioConstraint")
    if ar:
        ratio = val(ar, "AspectRatio", 1)
        dom = val(ar, "DominantAxis", "Width")
        if dom == "Width":
            h = w / ratio
        else:
            w = h * ratio
    sc = first(node, "UISizeConstraint")
    if sc:
        mn = val(sc, "MinSize", [0, 0])
        mx = val(sc, "MaxSize", [1e9, 1e9])
        w = max(mn[0], min(mx[0], w))
        h = max(mn[1], min(mx[1], h))
    return w, h


def layout_node(node, px, py, pw, ph, k, ox, oy, placed=None):
    """Lay out `node` inside parent rect (px,py,pw,ph) of transform (k, ox, oy)."""
    b = Box()
    b.node = node
    size = udim2(node, "Size", default_size(node["ClassName"]))
    w, h = resolve(size, pw, ph)
    w, h = apply_constraints(node, w, h)
    if placed is not None:
        x, y = placed
    else:
        pos = udim2(node, "Position", [0, 0, 0, 0])
        anchor = val(node, "AnchorPoint", [0, 0])
        x = px + pos[0] * pw + pos[1] - anchor[0] * w
        y = py + pos[2] * ph + pos[3] - anchor[1] * h
    b.x, b.y, b.w, b.h = x, y, w, h

    # UIScale scales this object (and its subtree) around its anchor point.
    scale = first(node, "UIScale")
    s = val(scale, "Scale", 1) if scale else 1
    if s != 1:
        anchor = val(node, "AnchorPoint", [0, 0])
        ax, ay = x + anchor[0] * w, y + anchor[1] * h
        ox, oy = ox + k * ax * (1 - s), oy + k * ay * (1 - s)
        k = k * s
    b.k, b.ox, b.oy = k, ox, oy
    b.canvas = None
    layout_children(b)

    auto = val(node, "AutomaticSize", "None")
    if auto in ("Y", "XY") and b.children:
        bottom = max(c.y + c.h for c in b.children) - b.y
        pad = first(node, "UIPadding")
        if pad:
            bottom += udim(pad, "PaddingBottom")[1]
        if bottom > b.h:
            b.h = bottom
            layout_children(b)
    return b


def layout_children(b):
    node = b.node
    x, y, w, h = b.x, b.y, b.w, b.h
    if node["ClassName"] == "ScrollingFrame":
        canvas = udim2(node, "CanvasSize", [0, 0, 2, 0])
        cw, ch = resolve(canvas, w, h)
        cw = max(cw, w) if cw > 0 else w
        b.canvas = (cw, ch)
        w, h = cw, max(ch, 0)

    pad = first(node, "UIPadding")
    if pad:
        pl = udim(pad, "PaddingLeft")
        pr = udim(pad, "PaddingRight")
        pt = udim(pad, "PaddingTop")
        pb = udim(pad, "PaddingBottom")
        l, r = pl[0] * w + pl[1], pr[0] * w + pr[1]
        t, bt = pt[0] * h + pt[1], pb[0] * h + pb[1]
        cx, cy, cw_, ch_ = x + l, y + t, w - l - r, h - t - bt
    else:
        cx, cy, cw_, ch_ = x, y, w, h

    children = [c for c in node["Children"] if visible_gui(c)]
    list_layout = first(node, "UIListLayout")
    grid = first(node, "UIGridLayout")
    out = []
    if list_layout or grid:
        lay = list_layout or grid
        order = val(lay, "SortOrder", "LayoutOrder")
        indexed = list(enumerate(children))
        if order == "Name":
            indexed.sort(key=lambda t: (t[1]["Name"], t[0]))
        else:
            indexed.sort(key=lambda t: (val(t[1], "LayoutOrder", 0), t[0]))
        children = [c for _, c in indexed]
        halign = val(lay, "HorizontalAlignment", "Left")
        valign = val(lay, "VerticalAlignment", "Top")
        if grid:
            cell = udim2(grid, "CellSize", [0, 100, 0, 100])
            cpad = udim2(grid, "CellPadding", [0, 5, 0, 5])
            cwid, chei = resolve(cell, cw_, ch_)
            padx, pady = resolve(cpad, cw_, ch_)
            per_row = max(1, int((cw_ + padx + 0.001) // (cwid + padx)))
            maxc = val(grid, "FillDirectionMaxCells", 0)
            if maxc:
                per_row = min(per_row, maxc)
            n = len(children)
            rows = math.ceil(n / per_row) if n else 0
            row_w = min(n, per_row) * cwid + max(0, min(n, per_row) - 1) * padx
            total_h = rows * chei + max(0, rows - 1) * pady
            sx = cx + {"Left": 0, "Center": (cw_ - row_w) / 2, "Right": cw_ - row_w}[halign]
            sy = cy + {"Top": 0, "Center": (ch_ - total_h) / 2, "Bottom": ch_ - total_h}[valign]
            for i, c in enumerate(children):
                r, col = divmod(i, per_row)
                c = dict(c)
                c["Properties"] = dict(c["Properties"])
                c["Properties"]["Size"] = {"$t": "UDim2", "v": [0, cwid, 0, chei]}
                out.append(layout_node(c, cx, cy, cw_, ch_, b.k, b.ox, b.oy, placed=(sx + col * (cwid + padx), sy + r * (chei + pady))))
        else:
            horizontal = val(lay, "FillDirection", "Vertical") == "Horizontal"
            padding = udim(lay, "Padding")
            gap = padding[0] * (cw_ if horizontal else ch_) + padding[1]
            sizes = []
            for c in children:
                sw, sh = resolve(udim2(c, "Size", default_size(c["ClassName"])), cw_, ch_)
                sizes.append(apply_constraints(c, sw, sh))
            total = sum(s[0] if horizontal else s[1] for s in sizes) + gap * max(0, len(children) - 1)
            if horizontal:
                cur = cx + {"Left": 0, "Center": (cw_ - total) / 2, "Right": cw_ - total}[halign]
            else:
                cur = cy + {"Top": 0, "Center": (ch_ - total) / 2, "Bottom": ch_ - total}[valign]
            for c, (sw, sh) in zip(children, sizes):
                if horizontal:
                    yy = cy + {"Top": 0, "Center": (ch_ - sh) / 2, "Bottom": ch_ - sh}[valign]
                    out.append(layout_node(c, cx, cy, cw_, ch_, b.k, b.ox, b.oy, placed=(cur, yy)))
                    cur += out[-1].w + gap
                else:
                    xx = cx + {"Left": 0, "Center": (cw_ - sw) / 2, "Right": cw_ - sw}[halign]
                    out.append(layout_node(c, cx, cy, cw_, ch_, b.k, b.ox, b.oy, placed=(xx, cur)))
                    cur += out[-1].h + gap
    else:
        for c in children:
            out.append(layout_node(c, cx, cy, cw_, ch_, b.k, b.ox, b.oy))
    b.children = out

    if node["ClassName"] == "ScrollingFrame":
        auto = val(node, "AutomaticCanvasSize", "None")
        content = (max(c.y + c.h for c in out) - y) if out else 0
        if pad:
            content += udim(pad, "PaddingBottom")[1]
        cw, ch = b.canvas
        if auto in ("Y", "XY"):
            ch = max(ch, content)
        b.canvas = (cw, ch)


# --------------------------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------------------------


def corner_radius(node, w, h):
    c = first(node, "UICorner")
    if not c:
        return None
    r = udim(c, "CornerRadius", (0, 8))
    rad = r[0] * min(w, h) + r[1]
    return max(0, min(rad, min(w, h) / 2))


def rr_mask(size, rect, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = rect
    if x1 <= x0 or y1 <= y0:
        return m
    d.rounded_rectangle((x0, y0, x1 - 1, y1 - 1), radius=max(0, radius), fill=255)
    return m


def gradient_layer(grad, size, base_rgb, base_alpha):
    """Colour/alpha layer for a UIGradient over `size` (in layer pixels)."""
    gw, gh = size
    rot = math.radians(val(grad, "Rotation", 0))
    offset = val(grad, "Offset", [0, 0])
    cseq = val(grad, "Color")
    tseq = val(grad, "Transparency")
    dx, dy = math.cos(rot), math.sin(rot)
    # Parameter t along the gradient direction, 0..1 across the box (centre-based like Roblox).
    steps = 256
    lut_c, lut_a = [], []
    for i in range(steps):
        t = i / (steps - 1)
        if cseq:
            c = sample_cseq(cseq, t)
        else:
            c = (1, 1, 1)
        a = 1 - (sample_nseq(tseq, t) if tseq else 0)
        lut_c.append(tuple(int(base_rgb[j] * c[j]) for j in range(3)))
        lut_a.append(int(base_alpha * a))
    img = Image.new("RGBA", size)
    px = img.load()
    half = 0.5 * (abs(dx) * gw + abs(dy) * gh) or 1
    for yy in range(gh):
        for xx in range(gw):
            u = ((xx - gw / 2 - offset[0] * gw) * dx + (yy - gh / 2 - offset[1] * gh) * dy) / (2 * half) + 0.5
            i = min(steps - 1, max(0, int(u * (steps - 1))))
            c = lut_c[i]
            px[xx, yy] = (c[0], c[1], c[2], lut_a[i])
    return img


def sample_cseq(seq, t):
    pts = seq
    if t <= pts[0][0]:
        return pts[0][1:]
    for a, b in zip(pts, pts[1:]):
        if a[0] <= t <= b[0]:
            f = (t - a[0]) / ((b[0] - a[0]) or 1)
            return tuple(a[i] + (b[i] - a[i]) * f for i in range(1, 4))
    return pts[-1][1:]


def sample_nseq(seq, t):
    pts = seq
    if t <= pts[0][0]:
        return pts[0][1]
    for a, b in zip(pts, pts[1:]):
        if a[0] <= t <= b[0]:
            f = (t - a[0]) / ((b[0] - a[0]) or 1)
            return a[1] + (b[1] - a[1]) * f
    return pts[-1][1]


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    def paste(self, layer, x, y, clip):
        """Alpha-composite `layer` at (x, y) (supersampled px), clipped to rect `clip`."""
        x, y = int(round(x)), int(round(y))
        lw, lh = layer.size
        cx0, cy0, cx1, cy1 = clip
        x0, y0 = max(x, cx0, 0), max(y, cy0, 0)
        x1, y1 = min(x + lw, cx1, self.img.width), min(y + lh, cy1, self.img.height)
        if x1 <= x0 or y1 <= y0:
            return
        part = layer.crop((x0 - x, y0 - y, x1 - x, y1 - y))
        self.img.alpha_composite(part, (x0, y0))


def stroke_of(node, text_object):
    """(border stroke, text stroke) UIStroke children."""
    border, text = None, None
    for s in kids(node, "UIStroke"):
        if not val(s, "Enabled", True):
            continue
        mode = val(s, "ApplyStrokeMode", "Contextual")
        if text_object and mode == "Contextual":
            text = s
        else:
            border = s
    return border, text


def draw_background(cv, b, clip):
    node = b.node
    sx, sy, sw, sh = b.screen()
    cls = node["ClassName"]
    trans = val(node, "BackgroundTransparency", 0)
    bg = color(node, "BackgroundColor3", (163, 162, 165) if cls != "ViewportFrame" else (163, 162, 165))
    radius = corner_radius(node, b.w, b.h)
    border, _ = stroke_of(node, cls in TEXT_CLASSES)
    grad = first(node, "UIGradient")

    t = (border and val(border, "Thickness", 1) * b.k) or 0
    margin = int(math.ceil(t * SS)) + 2
    lw, lh = int(round(sw * SS)) + 2 * margin, int(round(sh * SS)) + 2 * margin
    if lw <= 0 or lh <= 0 or lw > 8000 or lh > 8000:
        return
    rad = (radius or 0) * b.k * SS
    inner = (margin, margin, margin + int(round(sw * SS)), margin + int(round(sh * SS)))

    if trans < 1:
        alpha = int(255 * (1 - trans))
        if grad and val(grad, "Enabled", True):
            fill = gradient_layer_cached(grad, (inner[2] - inner[0], inner[3] - inner[1]), bg, alpha)
            layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
            layer.paste(fill, (inner[0], inner[1]))
        else:
            layer = Image.new("RGBA", (lw, lh), bg + (alpha,))
        mask = rr_mask((lw, lh), inner, rad)
        layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", (lw, lh), 0), mask))
        cv.paste(layer, sx * SS - margin, sy * SS - margin, clip)
        # Legacy 1px border (only without UICorner)
        if radius is None and val(node, "BorderSizePixel", 1) > 0 and cls not in ("ViewportFrame",):
            bc = color(node, "BorderColor3", (27, 42, 53))
            edge = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
            d = ImageDraw.Draw(edge)
            bw = int(val(node, "BorderSizePixel", 1) * SS)
            d.rectangle((inner[0] - bw, inner[1] - bw, inner[2] + bw - 1, inner[3] + bw - 1), outline=bc + (alpha,), width=bw)
            cv.paste(edge, sx * SS - margin, sy * SS - margin, clip)

    if border and t > 0:
        sc = color(border, "Color", (0, 0, 0))
        st = val(border, "Transparency", 0)
        ts = t * SS
        outer = rr_mask((lw, lh), (inner[0] - ts, inner[1] - ts, inner[2] + ts, inner[3] + ts), rad + ts if rad else 0)
        hole = rr_mask((lw, lh), inner, rad)
        ring = Image.composite(Image.new("L", (lw, lh), 0), outer, hole)
        layer = Image.new("RGBA", (lw, lh), sc + (0,))
        layer.putalpha(ring.point(lambda v: int(v * (1 - st))))
        cv.paste(layer, sx * SS - margin, sy * SS - margin, clip)


_grad_cache = {}


def gradient_layer_cached(grad, size, rgb, alpha):
    key = (json.dumps(grad["Properties"], sort_keys=True), size, rgb, alpha)
    if key not in _grad_cache:
        # Render small and scale up: gradients are smooth.
        small = (max(1, size[0] // 4), max(1, size[1] // 4))
        _grad_cache[key] = gradient_layer(grad, small, rgb, alpha).resize(size, Image.BILINEAR)
    return _grad_cache[key]


def draw_text(cv, b, clip):
    node = b.node
    text = val(node, "Text", "Label" if node["ClassName"] == "TextLabel" else "Button")
    if node["ClassName"] == "TextBox" and not text:
        text = val(node, "PlaceholderText", "")
    if not text:
        return
    ttrans = val(node, "TextTransparency", 0)
    if ttrans >= 1:
        return
    font_name = val(node, "Font", "SourceSans")
    tcolor = color(node, "TextColor3", (27, 42, 53))
    char_colours = None
    if val(node, "RichText", False):
        text, char_colours = parse_rich(text, tcolor)
    scaled = val(node, "TextScaled", False)
    size = val(node, "TextSize", 14)
    wrapped = val(node, "TextWrapped", False)
    tsc = first(node, "UITextSizeConstraint")
    max_size = val(tsc, "MaxTextSize", 100) if tsc else 100
    min_size = val(tsc, "MinTextSize", 1) if tsc else 1
    xa = val(node, "TextXAlignment", "Center")
    ya = val(node, "TextYAlignment", "Center")

    pad = first(node, "UIPadding")
    bx, by, bw, bh = b.x, b.y, b.w, b.h
    if pad:
        l, r = udim(pad, "PaddingLeft")[1], udim(pad, "PaddingRight")[1]
        t_, bt = udim(pad, "PaddingTop")[1], udim(pad, "PaddingBottom")[1]
        bx, by, bw, bh = bx + l, by + t_, bw - l - r, bh - t_ - bt

    px, lines = fit_text(text, font_name, bw, bh, scaled, size, wrapped, max_size, min_size)
    _, tstroke = stroke_of(node, True)
    k = b.k
    fpx = px * k * SS
    if fpx < 1:
        return
    font = get_font(font_name, fpx)
    st_w = 0
    st_col = (0, 0, 0)
    st_alpha = 1
    if tstroke:
        st_w = val(tstroke, "Thickness", 1) * k * SS
        st_col = color(tstroke, "Color", (0, 0, 0))
        st_alpha = 1 - val(tstroke, "Transparency", 0)
    elif val(node, "TextStrokeTransparency", 1) < 1:
        st_w = 1 * k * SS
        st_col = color(node, "TextStrokeColor3", (0, 0, 0))
        st_alpha = 1 - val(node, "TextStrokeTransparency", 1)

    margin = int(st_w) + 4
    lw = int(bw * k * SS) + 2 * margin + int(fpx)
    lh = int(max(bh, len(lines) * px) * k * SS) + 2 * margin + int(fpx)
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    stroke_layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ds = ImageDraw.Draw(stroke_layer)
    ascent, descent = font.getmetrics()
    total_h = len(lines) * fpx
    box_w, box_h = bw * k * SS, bh * k * SS
    top = margin + {"Top": 0, "Center": (box_h - total_h) / 2, "Bottom": box_h - total_h}[ya]
    alpha = int(255 * (1 - ttrans))
    cursor = 0  # index into the full text, for RichText colours
    for i, line in enumerate(lines):
        lwid = text_width(line, font_name, fpx)
        left = margin + {"Left": 0, "Center": (box_w - lwid) / 2, "Right": box_w - lwid}[xa]
        base = top + i * fpx + (fpx - (ascent + descent)) / 2 + ascent
        cur = left
        line_runs = runs(line)
        if char_colours is not None:
            start = text.find(line, cursor) if line else cursor
            start = cursor if start < 0 else start
            cursor = start + len(line)
            coloured = []
            idx = start
            for emo, seg in line_runs:
                if emo:
                    coloured.append((emo, seg, tcolor))
                    idx += len(seg)
                    continue
                buf, bc = "", None
                for ch in seg:
                    c = char_colours[idx] if idx < len(char_colours) else tcolor
                    if bc is not None and c != bc:
                        coloured.append((False, buf, bc))
                        buf = ""
                    buf += ch
                    bc = c
                    idx += 1
                if buf:
                    coloured.append((False, buf, bc))
            line_runs = coloured
        else:
            line_runs = [(emo, seg, tcolor) for emo, seg in line_runs]
        for emo, s, run_colour in line_runs:
            if emo:
                im = emoji_image(s)
                if im is not None:
                    eh = int(fpx * 0.92)
                    ew = max(1, int(im.width * eh / im.height))
                    em = im.resize((ew, eh), Image.LANCZOS)
                    ey = int(base - fpx * 0.78)
                    ex = int(cur + (fpx * 1.12 - ew) / 2)
                    if st_w > 0:
                        sil = Image.new("RGBA", em.size, st_col + (255,))
                        sil.putalpha(em.getchannel("A"))
                        rad = int(max(1, st_w))
                        grown = sil.getchannel("A").filter(ImageFilter.MaxFilter(2 * (rad // 2) + 1))
                        sil2 = Image.new("RGBA", em.size, st_col + (0,))
                        sil2.putalpha(grown)
                        stroke_layer.alpha_composite(sil2, (ex, ey))
                    if alpha < 255:
                        em.putalpha(em.getchannel("A").point(lambda v: v * alpha // 255))
                    layer.alpha_composite(em, (ex, ey))
                cur += fpx * 1.12
            else:
                if st_w > 0:
                    ds.text((cur, base), s, font=font, fill=st_col + (int(255 * st_alpha),), anchor="ls",
                            stroke_width=int(round(st_w)), stroke_fill=st_col + (int(255 * st_alpha),))
                d.text((cur, base), s, font=font, fill=run_colour + (alpha,), anchor="ls")
                cur += font.getlength(s)
    grad = first(node, "UIGradient")
    if grad and val(grad, "Enabled", True):
        g = gradient_layer_cached(grad, (lw, lh), (255, 255, 255), 255)
        rgb = Image.merge("RGB", layer.split()[:3])
        from PIL import ImageChops

        rgb = ImageChops.multiply(rgb, Image.merge("RGB", g.split()[:3]))
        layer = Image.merge("RGBA", (*rgb.split(), layer.getchannel("A")))
    stroke_layer.alpha_composite(layer)
    sx, sy, _, _ = b.screen()
    ox = sx + (bx - b.x) * k
    oy = sy + (by - b.y) * k
    cv.paste(stroke_layer, ox * SS - margin, oy * SS - margin, clip)


def stud_layout(width, height, radius, pitch, stud, edge, phase):
    """Mirror of StudBackground.Layout in src/client/UI/StudBackground.luau: the L bars."""
    reach = radius + 1

    def span(u, length, across):
        d = radius - u if u < radius else (u - (length - radius) if u > length - radius else 0)
        if d <= 0:
            return 0, across
        inset = radius - math.sqrt(max(0, reach * reach - d * d))
        return inset, across - inset

    bars = []

    def vertical(x0, x1, y0, y1):
        x0, x1 = max(x0, 0), min(x1, width)
        if x1 - x0 < 1:
            return
        lo, hi = span((x0 + x1) / 2, width, height)
        y0, y1 = max(y0, lo), min(y1, hi)
        if y1 - y0 >= 1:
            bars.append((x0, y0, x1 - x0, y1 - y0))

    def horizontal(x0, x1, y0, y1):
        y0, y1 = max(y0, 0), min(y1, height)
        if y1 - y0 < 1:
            return
        lo, hi = span((y0 + y1) / 2, height, width)
        x0, x1 = max(x0, lo), min(x1, hi)
        if x1 - x0 >= 1:
            bars.append((x0, y0, x1 - x0, y1 - y0))

    cols = math.ceil((width - phase) / pitch)
    rows = math.ceil((height - phase) / pitch)
    for r in range(rows):
        for c in range(cols):
            x, y = phase + c * pitch, phase + r * pitch
            vertical(x, x + edge, y, y + stud)
            horizontal(x + edge, x + stud, y + stud - edge, y + stud)
    return bars


def draw_square_studs(cv, b, clip):
    """StudBackground holder: same bars as src/client/UI/StudBackground.luau."""
    attrs = b.node.get("Attributes", {})
    pitch = attrs["StudPitch"]
    stud = attrs.get("StudSize", 11)
    edge = attrs.get("StudEdge", 2)
    phase = attrs.get("StudPhase", -4)
    alpha = int(255 * (1 - attrs.get("StudTransparency", 0.8)))
    width, height = round(b.w), round(b.h)
    radius = min(attrs.get("StudRadiusScale", 0) * min(width, height) + attrs.get("StudRadiusOffset", 12), min(width, height) / 2)
    sx, sy, sw, sh = b.screen()
    k = b.k * SS
    w, h = int(round(sw * SS)) + 2, int(round(sh * SS)) + 2
    if w <= 2 or h <= 2:
        return
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x, y, bw, bh in stud_layout(width, height, radius, pitch, stud, edge, phase):
        x0, y0 = round(x) * k, round(y) * k  # Roblox snaps offsets to whole pixels
        d.rectangle((x0, y0, x0 + round(bw) * k - 1, y0 + round(bh) * k - 1), fill=(0, 0, 0, alpha))
    cv.paste(layer, sx * SS, sy * SS, clip)


def draw_studs(cv, b, clip, plate):
    """Top-down view of a studded plastic plate (SurfaceType.Studs), like the map."""
    sx, sy, sw, sh = b.screen()
    base = color(plate, "Color", (200, 200, 200))
    vp = b.node
    amb = color(vp, "Ambient", (125, 125, 125))
    lc = color(vp, "LightColor", (150, 150, 150))
    lit = min(1.25, (amb[0] + lc[0] * 0.92) / 255)
    top = tuple(min(255, int(c * lit)) for c in base)
    w, h = int(round(sw * SS)), int(round(sh * SS))
    if w <= 0 or h <= 0:
        return
    layer = Image.new("RGBA", (w, h), top + (255,))
    d = ImageDraw.Draw(layer)
    pitch = 18 * b.k * SS
    dia = pitch * 0.6
    hi = tuple(min(255, int(c * 1.10 + 8)) for c in top)
    sh_ = tuple(int(c * 0.72) for c in top)
    rim = tuple(int(c * 0.86) for c in top)
    ny, nx = int(h / pitch) + 2, int(w / pitch) + 2
    offx = (w - (nx - 1) * pitch) / 2 - pitch / 2
    offy = (h - (ny - 1) * pitch) / 2 - pitch / 2
    for j in range(ny):
        for i in range(nx):
            cx = offx + i * pitch + pitch / 2
            cy = offy + j * pitch + pitch / 2
            r = dia / 2
            d.ellipse((cx - r + SS, cy - r + SS * 1.5, cx + r + SS, cy + r + SS * 1.5), fill=sh_)
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rim)
            d.ellipse((cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86), fill=hi)
    radius = corner_radius(vp, b.w, b.h)
    if radius:
        layer.putalpha(rr_mask((w, h), (0, 0, w, h), radius * b.k * SS))
    cv.paste(layer, sx * SS, sy * SS, clip)


def draw_viewport_model(cv, b, clip):
    """Very small 3D renderer for pet / item / egg thumbnails."""
    vp = b.node
    cam = first(vp, "Camera")
    if not cam:
        return
    sx, sy, sw, sh = b.screen()
    w, h = int(round(sw * SS)), int(round(sh * SS))
    if w <= 2 or h <= 2:
        return
    cf = val(cam, "CFrame")
    fov = math.radians(val(cam, "FieldOfView", 70))
    if not cf:
        return
    cpos = cf[0:3]
    R = [cf[3:6], cf[6:9], cf[9:12]]
    f = (h / 2) / math.tan(fov / 2)
    amb = [c / 255 for c in color(vp, "Ambient", (200, 200, 200))]
    lcol = [c / 255 for c in color(vp, "LightColor", (140, 140, 140))]
    ld = val(vp, "LightDirection", [-1, -1, -1])
    ln = math.sqrt(sum(c * c for c in ld)) or 1
    L = [-c / ln for c in ld]

    def to_cam(p):
        d = [p[i] - cpos[i] for i in range(3)]
        # R^T * d (R columns are camera axes)
        return [sum(R[r][c] * d[r] for r in range(3)) for c in range(3)]

    def project(p):
        v = to_cam(p)
        depth = -v[2]
        if depth < 0.05:
            depth = 0.05
        return (w / 2 + v[0] / depth * f, h / 2 - v[1] / depth * f, depth)

    faces = []

    def shade(base, normal, neon=False):
        if neon:
            return tuple(min(255, int(c * 1.15)) for c in base)
        dot = max(0.0, sum(normal[i] * L[i] for i in range(3)))
        out = []
        for i in range(3):
            k = 0.45 * amb[i] + 0.75 * lcol[i] * dot + 0.12
            out.append(min(255, int(base[i] * min(1.25, k))))
        return tuple(out)

    def walk(n):
        for c in n["Children"]:
            if c["ClassName"] in ("Part", "MeshPart", "WedgePart") and val(c, "Transparency", 0) < 0.95:
                parts.append(c)
            walk(c)

    parts = []
    walk(vp)
    for p in parts:
        pcf = val(p, "CFrame", [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
        size = val(p, "Size", [4, 1, 2])
        col = color(p, "Color", (163, 162, 165))
        neon = val(p, "Material", "Plastic") == "Neon"
        alpha = int(255 * (1 - val(p, "Transparency", 0)))
        pos = pcf[0:3]
        M = [pcf[3:6], pcf[6:9], pcf[9:12]]

        def world(local):
            return [pos[i] + sum(M[i][j] * local[j] for j in range(3)) for i in range(3)]

        def wnormal(local):
            return [sum(M[i][j] * local[j] for j in range(3)) for i in range(3)]

        shape = val(p, "Shape", "Block")
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        if shape == "Ball":
            r = min(size) / 2
            cx, cy, depth = project(pos)
            pr = r / depth * f
            faces.append((depth - r, "ball", (cx, cy, pr), col, alpha))
            continue
        polys = []
        if shape == "Cylinder":
            n = 14
            ry, rz = hy, hz
            ring = [(math.cos(2 * math.pi * i / n), math.sin(2 * math.pi * i / n)) for i in range(n)]
            for i in range(n):
                a, c2 = ring[i], ring[(i + 1) % n]
                quad = [(-hx, a[0] * ry, a[1] * rz), (hx, a[0] * ry, a[1] * rz), (hx, c2[0] * ry, c2[1] * rz), (-hx, c2[0] * ry, c2[1] * rz)]
                mid = ((a[0] + c2[0]) / 2, (a[1] + c2[1]) / 2)
                polys.append((quad, (0, mid[0], mid[1])))
            polys.append(([(hx, a[0] * ry, a[1] * rz) for a in ring], (1, 0, 0)))
            polys.append(([(-hx, a[0] * ry, a[1] * rz) for a in reversed(ring)], (-1, 0, 0)))
        else:
            corners = {
                (sx_, sy_, sz_): (sx_ * hx, sy_ * hy, sz_ * hz) for sx_ in (-1, 1) for sy_ in (-1, 1) for sz_ in (-1, 1)
            }
            for axis in range(3):
                for sign in (-1, 1):
                    quad_keys = []
                    others = [a for a in range(3) if a != axis]
                    for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                        key = [0, 0, 0]
                        key[axis] = sign
                        key[others[0]] = u
                        key[others[1]] = v
                        quad_keys.append(tuple(key))
                    normal = [0, 0, 0]
                    normal[axis] = sign
                    polys.append(([corners[k_] for k_ in quad_keys], tuple(normal)))
        for quad, nloc in polys:
            wn = wnormal(nloc)
            wpts = [world(q) for q in quad]
            centre = [sum(pt[i] for pt in wpts) / len(wpts) for i in range(3)]
            to_camv = [cpos[i] - centre[i] for i in range(3)]
            if sum(wn[i] * to_camv[i] for i in range(3)) <= 0:
                continue
            proj = [project(pt) for pt in wpts]
            depth = sum(pp[2] for pp in proj) / len(proj)
            faces.append((depth, "poly", [(pp[0], pp[1]) for pp in proj], shade(col, wn, neon), alpha))

    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for depth, kind, geo, col, alpha in sorted(faces, key=lambda t: -t[0]):
        if kind == "ball":
            cx, cy, pr = geo
            base = shade(col, [L[0], L[1], L[2]])
            d.ellipse((cx - pr, cy - pr, cx + pr, cy + pr), fill=tuple(int(c * 0.82) for c in col) + (alpha,))
            d.ellipse((cx - pr * 0.9, cy - pr * 0.95, cx + pr * 0.75, cy + pr * 0.7), fill=base + (alpha,))
            d.ellipse((cx - pr * 0.55, cy - pr * 0.7, cx - pr * 0.15, cy - pr * 0.3), fill=tuple(min(255, c + 50) for c in base) + (alpha,))
        else:
            d.polygon(geo, fill=col + (alpha,))
    cv.paste(layer, sx * SS, sy * SS, clip)


def draw_box(cv, b, clip):
    node = b.node
    cls = node["ClassName"]
    if cls == "ViewportFrame":
        plate = next((c for c in node["Children"] if c["ClassName"] == "Part" and val(c, "TopSurface") == "Studs"), None)
        if val(node, "BackgroundTransparency", 0) < 1:
            draw_background(cv, b, clip)
        if plate is not None:
            draw_studs(cv, b, clip, plate)
        else:
            draw_viewport_model(cv, b, clip)
        border, _ = stroke_of(node, False)
        if border:
            # Border drawn by draw_background when the background is visible.
            pass
        return
    if cls in ("ImageLabel", "ImageButton"):
        # Images need uploaded assets; show the background only.
        draw_background(cv, b, clip)
        return
    draw_background(cv, b, clip)
    if cls == "Frame" and "StudPitch" in b.node.get("Attributes", {}):
        draw_square_studs(cv, b, clip)
    if cls in TEXT_CLASSES:
        draw_text(cv, b, clip)


class OffsetCanvas:
    """Collects one element's drawing so it can be rotated (GuiObject.Rotation) as a unit."""

    def __init__(self, x0, y0, w, h):
        self.x0, self.y0 = x0, y0
        self.img = Image.new("RGBA", (max(1, w), max(1, h)), (0, 0, 0, 0))

    def paste(self, layer, x, y, clip):
        self.img.alpha_composite(layer, (int(round(x - self.x0)), int(round(y - self.y0))))


def draw_rotated(cv, b, clip, rotation):
    sx, sy, sw, sh = b.screen()
    margin = int(max(sw, sh) * SS)  # room for strokes / overhang
    x0, y0 = int(sx * SS) - margin, int(sy * SS) - margin
    local = OffsetCanvas(x0, y0, int(sw * SS) + 2 * margin, int(sh * SS) + 2 * margin)
    full = (-10**9, -10**9, 10**9, 10**9)
    draw_box(local, b, full)
    cx, cy = (sx + sw / 2) * SS - x0, (sy + sh / 2) * SS - y0
    rotated = local.img.rotate(-rotation, resample=Image.BICUBIC, center=(cx, cy))
    cv.paste(rotated, x0, y0, clip)


def render_tree(cv, b, clip):
    rotation = val(b.node, "Rotation", 0)
    if rotation:
        draw_rotated(cv, b, clip, rotation)
    else:
        draw_box(cv, b, clip)
    node = b.node
    child_clip = clip
    sx, sy, sw, sh = b.screen()
    if node["ClassName"] == "ScrollingFrame" or val(node, "ClipsDescendants", False):
        r = (int(sx * SS), int(sy * SS), int((sx + sw) * SS), int((sy + sh) * SS))
        child_clip = (max(clip[0], r[0]), max(clip[1], r[1]), min(clip[2], r[2]), min(clip[3], r[3]))
    ordered = sorted(enumerate(b.children), key=lambda t: (val(t[1].node, "ZIndex", 1), t[0]))
    for _, c in ordered:
        render_tree(cv, c, child_clip)
    if node["ClassName"] == "ScrollingFrame" and b.canvas and b.canvas[1] > b.h + 1:
        thick = val(node, "ScrollBarThickness", 12) * b.k
        frac = b.h / b.canvas[1]
        bar = Image.new("RGBA", (max(1, int(thick * SS)), max(1, int(sh * frac * SS))), color(node, "ScrollBarImageColor3", (0, 0, 0)) + (int(255 * (1 - val(node, "ScrollBarImageTransparency", 0))),))
        cv.paste(bar, (sx + sw - thick) * SS, sy * SS, clip)


def render(guis, background, out_path, size=(W, H)):
    global W, H
    W, H = size
    cv = Canvas(W, H)
    if background is not None:
        bg = background.convert("RGBA").resize((W * SS, H * SS), Image.LANCZOS)
        cv.img.alpha_composite(bg)
    guis = sorted(guis, key=lambda g: val(g, "DisplayOrder", 0))
    for gui in guis:
        if not val(gui, "Enabled", True):
            continue
        inset = 0 if val(gui, "IgnoreGuiInset", False) else GUI_INSET
        root = Box()
        root.node = gui
        root.x, root.y, root.w, root.h = 0, inset, W, H - inset
        root.k, root.ox, root.oy = 1, 0, 0
        root.canvas = None
        layout_children(root)
        clip = (0, 0, W * SS, H * SS)
        for _, c in sorted(enumerate(root.children), key=lambda t: (val(t[1].node, "ZIndex", 1), t[0])):
            render_tree(cv, c, clip)
    img = cv.img.resize((W, H), Image.LANCZOS).convert("RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path)
    return img


# --------------------------------------------------------------------------------------------
# Scenes
# --------------------------------------------------------------------------------------------

START = """
local UIController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Controllers.UIController)
"""

PHONE = "workspace.CurrentCamera.ViewportSize = Vector2.new(844, 390)\n"

# Scenes rendered at a different screen size (default 1920x1080).
SIZES = {"hud_phone": (844, 390), "shop_phone": (844, 390)}

SCENES = {
    "hud": START + "UIController.Start()",
    "hud_phone": START + PHONE + "UIController.Start()",
    "shop_phone": START + PHONE + 'UIController.Start()\nopenWindow("ShopMenu")',
    "shop": START + 'UIController.Start()\nopenWindow("ShopMenu")',
    "pets": START + 'UIController.Start()\nopenWindow("PetsMenu")',
    "rebirth": START + 'UIController.Start()\nopenWindow("RebirthMenu")',
    "trails": START + 'UIController.Start()\nopenWindow("TrailsMenu")',
    "inventory": START + 'UIController.Start()\nopenWindow("InventoryMenu")',
    "gifts": START + 'UIController.Start()\nopenWindow("GiftsMenu")',
    "welcomeback": START + "SAMPLE_SESSION.OfflineAmount = 31638\nSAMPLE_SESSION.OfflineSeconds = 5400\nUIController.Start()",
    "toasts": START
    + """UIController.Start()
local Popups = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.Popups)
Popups.Toast("Equipped Panda!", "Success")
Popups.Toast("You need 500 more Wins.", "Error")
Popups.Banner("NEW RECORD!", "You smashed 37 walls", nil)
""",
}


def backdrop():
    """A simple stud-world backdrop so the UI is judged in context."""
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        if t < 0.42:
            c = (int(120 + 70 * t), int(180 + 50 * t), 255)
        else:
            u = (t - 0.42) / 0.58
            c = (int(92 - 20 * u), int(190 - 30 * u), int(70 - 20 * u))
        d.line([(0, y), (W, y)], fill=c)
    # checker tiles on the ground
    for j in range(12):
        y0 = int(H * 0.42 + (j ** 1.6) * 9)
        y1 = int(H * 0.42 + ((j + 1) ** 1.6) * 9)
        for i in range(-20, 40):
            if (i + j) % 2 == 0:
                x0 = W / 2 + (i - 10) * (40 + j * 18)
                x1 = x0 + (40 + j * 18)
                d.rectangle((x0, y0, x1, y1), fill=(84, 176, 64))
    return img.filter(ImageFilter.GaussianBlur(2))


def main(argv):
    names = argv or list(SCENES)
    bg = backdrop()
    for name in names:
        guis = run_scene(SCENES[name])
        out = os.path.join(OUT_DIR, f"{name}.png")
        render(guis, bg, out, SIZES.get(name, (1920, 1080)))
        print(f"  {name:<12} -> {os.path.relpath(out, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
