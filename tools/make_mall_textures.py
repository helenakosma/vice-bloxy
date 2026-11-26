"""Generates the Eaton Centre interior textures into assets/textures/mall/.

Run:  python tools/make_mall_textures.py
Then import the PNGs in Roblox Studio (Asset Manager -> Bulk Import) and paste
each image ID into src/shared/Assets.lua (the mall_* entries). Until then the
game uses plain Roblox materials for those surfaces.

Most are near-white / grey so the game can tint them per store (Texture.Color3):
one wood, one marble, one fabric etc. serve every brand's colour.
Everything is procedural (numpy + Pillow); the posters' brands are made up.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "mall")
os.makedirs(OUT, exist_ok=True)
random.seed(2026)
FONTS = "C:/Windows/Fonts/"


def font(name, size):
    try:
        return ImageFont.truetype(FONTS + name, size)
    except OSError:
        return ImageFont.load_default()


def noise(w, h, scale, octaves=4, seed=0):
    """Tileable value noise in [0, 1]."""
    r = np.random.default_rng(seed)
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        cells = max(2, int(scale * 2 ** o))
        grid = r.random((cells, cells))
        grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (w + w // cells, h + h // cells), Image.BICUBIC)
        total += np.asarray(img, dtype=float)[:h, :w] / 255 * amp
        norm += amp
        amp *= 0.5
    return total / norm


def save(arr_or_img, name):
    img = arr_or_img if isinstance(arr_or_img, Image.Image) else Image.fromarray(np.clip(arr_or_img, 0, 255).astype(np.uint8))
    img.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def grey(arr):
    return np.stack([arr] * 3, axis=-1)


# --------------------------------------------------------------- floors
def floor_tile(name="mall_floor_tile", tiles=2, seed=1):
    """Large porcelain tiles with thin grout (one texture = tiles x tiles)."""
    W = 512
    n = noise(W, W, 6, 4, seed)
    base = 236 + (n - 0.5) * 14
    step = W // tiles
    for t in range(tiles):
        for s in range(tiles):
            base[t * step:(t + 1) * step, s * step:(s + 1) * step] += random.uniform(-5, 5)
    arr = grey(base)
    for k in range(tiles + 1):
        g = min(W - 1, k * step)
        arr[max(0, g - 2):g + 2, :, :] = 168
        arr[:, max(0, g - 2):g + 2, :] = 168
    save(arr, name)


def wood_floor(name="mall_wood", seed=2):
    W = 512
    rows = 8
    arr = np.zeros((W, W, 3))
    h = W // rows
    r = np.random.default_rng(seed)
    for i in range(rows):
        grain = noise(W, h, 3, 3, seed + i)
        streak = np.sin(np.linspace(0, r.uniform(20, 40), W))[None, :] * 0.5 + 0.5
        tone = 205 + r.uniform(-14, 14)
        band = tone + (grain - 0.5) * 30 + (streak - 0.5) * 10
        arr[i * h:(i + 1) * h] = grey(band)
        arr[i * h:i * h + 2] *= 0.72  # plank seam
        cut = int(r.uniform(0.2, 0.8) * W)
        arr[i * h:(i + 1) * h, cut:cut + 2] *= 0.75  # butt joint
    save(arr, name)


def marble(name="mall_marble", seed=3):
    W = 512
    n = noise(W, W, 3, 5, seed)
    x = np.linspace(0, 6 * math.pi, W)
    veins = np.abs(np.sin(x[None, :] + n * 9 + x[:, None] * 0.4))
    v = np.clip(1 - veins * 6, 0, 1) ** 2
    base = 240 - v * 70 - (n - 0.5) * 12
    save(grey(base), name)


def terrazzo(name="mall_terrazzo", seed=4):
    W = 512
    img = Image.new("RGB", (W, W), (226, 214, 204))
    d = ImageDraw.Draw(img)
    r = random.Random(seed)
    chips = [(150, 70, 56), (90, 60, 52), (246, 240, 232), (196, 120, 96), (120, 120, 116), (230, 190, 160)]
    for _ in range(1400):
        x, y = r.randrange(W), r.randrange(W)
        s = r.choice([2, 3, 4, 6, 9])
        pts = [(x + r.randint(-s, s), y + r.randint(-s, s)) for _ in range(5)]
        for dx in (-W, 0, W):
            for dy in (-W, 0, W):
                d.polygon([(p[0] + dx, p[1] + dy) for p in pts], fill=r.choice(chips))
    save(img, name)


def concrete_polished(name="mall_concrete", seed=5):
    W = 512
    n = noise(W, W, 4, 5, seed)
    fine = noise(W, W, 40, 2, seed + 1)
    base = 200 + (n - 0.5) * 40 + (fine - 0.5) * 12
    save(grey(base), name)


def carpet(name="mall_carpet", seed=6):
    W = 256
    fine = np.random.default_rng(seed).random((W, W))
    n = noise(W, W, 8, 3, seed)
    base = 200 + (fine - 0.5) * 40 + (n - 0.5) * 20
    save(Image.fromarray(np.clip(grey(base), 0, 255).astype(np.uint8)).filter(ImageFilter.SMOOTH), name)


# --------------------------------------------------------------- walls
def subway_tile(name="mall_subway_tile"):
    W = 512
    rows, cols = 8, 4
    arr = np.full((W, W, 3), 244.0)
    th, tw = W // rows, W // cols
    for i in range(rows):
        off = (tw // 2) if i % 2 else 0
        arr[i * th:i * th + 3] = 190
        for j in range(cols + 1):
            x = (j * tw + off) % W
            arr[i * th:(i + 1) * th, max(0, x - 1):x + 2] = 190
        # a soft glaze highlight near each tile's top
        arr[i * th + 4:i * th + 10] += 6
    save(arr, name)


def slatwall(name="mall_slatwall"):
    W = 256
    arr = np.full((W, W, 3), 236.0)
    for k in range(0, W, 32):
        arr[k:k + 5] = 150  # the groove
        arr[k + 5:k + 7] = 214
    save(arr, name)


def brushed_metal(name="mall_brushed_metal", seed=7):
    W = 256
    r = np.random.default_rng(seed)
    streaks = r.random((W, 1)) * np.ones((1, W))
    streaks = np.asarray(Image.fromarray((streaks * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), dtype=float) / 255
    base = 200 + (streaks - 0.5) * 40
    save(grey(base), name)


def fabric(name="mall_fabric", seed=8):
    W = 256
    x = np.arange(W)
    weave = (np.sin(x[None, :] * math.pi / 2) * np.sin(x[:, None] * math.pi / 2))
    fine = np.random.default_rng(seed).random((W, W))
    base = 214 + weave * 18 + (fine - 0.5) * 16
    save(grey(base), name)


def ceiling_tile(name="mall_ceiling_tile", seed=9):
    W = 256
    fine = np.random.default_rng(seed).random((W, W))
    pits = (fine > 0.985) * -40
    base = 236 + (fine - 0.5) * 8 + pits
    arr = grey(base)
    arr[0:3] = 180
    arr[:, 0:3] = 180
    save(arr, name)


def wood_slats(name="mall_wood_slats", seed=10):
    W = 256
    arr = np.zeros((W, W, 3))
    grain = noise(W, W, 4, 3, seed)
    lines = np.sin(np.linspace(0, 60, W))[None, :] * 0.5 + 0.5
    base = 200 + (grain - 0.5) * 40 + (lines - 0.5) * 14
    save(grey(base), name)


# --------------------------------------------------------------- posters
def poster(name, title, sub, bg, fg, figure):
    """A campaign poster: a colour field with a soft light, a slim fashion
    figure in a long coat mid-stride, the headline and a line under it."""
    W, H = 512, 768
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    for y in range(H):
        f = y / H
        c = tuple(int(bg[i] * (1.08 - 0.3 * f)) for i in range(3))
        d.line([(0, y), (W, y)], fill=tuple(min(255, v) for v in c))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.15, H * 0.2, W * 0.85, H * 0.8], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img = Image.composite(Image.new("RGB", (W, H), tuple(min(255, v + 40) for v in bg)), img, glow)
    d = ImageDraw.Draw(img)
    cx = W // 2 + (70 if figure == "right" else -70 if figure == "left" else 0)
    dark = tuple(int(v * 0.2) for v in fg) if sum(fg) < 300 else (34, 30, 30)
    coat = fg
    # shadow on the floor
    d.ellipse([cx - 90, 700, cx + 90, 724], fill=tuple(int(v * 0.75) for v in bg))
    # legs mid-stride (trousers dark), shoes
    d.polygon([(cx - 34, 470), (cx - 6, 470), (cx - 30, 700), (cx - 52, 700)], fill=dark)
    d.polygon([(cx + 6, 470), (cx + 34, 470), (cx + 56, 696), (cx + 34, 700)], fill=dark)
    d.ellipse([cx - 64, 690, cx - 26, 708], fill=dark)
    d.ellipse([cx + 30, 688, cx + 68, 706], fill=dark)
    # long coat with lapels and a belt, arms
    d.polygon([(cx - 62, 236), (cx + 62, 236), (cx + 86, 560), (cx - 86, 560)], fill=coat)
    d.polygon([(cx - 62, 236), (cx - 92, 250), (cx - 104, 430), (cx - 80, 432), (cx - 66, 300)], fill=coat)
    d.polygon([(cx + 62, 236), (cx + 92, 250), (cx + 100, 430), (cx + 76, 432), (cx + 66, 300)], fill=coat)
    shadow = tuple(int(v * 0.82) for v in coat)
    d.polygon([(cx - 4, 236), (cx - 30, 236), (cx - 4, 330)], fill=shadow)
    d.polygon([(cx + 4, 236), (cx + 30, 236), (cx + 4, 330)], fill=shadow)
    d.line([(cx, 330), (cx, 560)], fill=shadow, width=3)
    d.rectangle([cx - 74, 380, cx + 74, 392], fill=shadow)
    # neck, head, hair
    d.rectangle([cx - 9, 200, cx + 9, 240], fill=tuple(min(255, int(v * 0.95)) for v in (232, 200, 176)))
    d.ellipse([cx - 26, 140, cx + 26, 206], fill=(232, 200, 176))
    d.pieslice([cx - 30, 132, cx + 30, 196], 180, 360, fill=dark)
    # headline and line
    size = 64 if len(title) <= 11 else 48
    d.text((36, 34), title, font=font("arialbd.ttf", size), fill=fg)
    d.text((38, 34 + size + 8), sub, font=font("arial.ttf", 24), fill=fg)
    d.line([(38, 34 + size + 44), (180, 34 + size + 44)], fill=fg, width=3)
    save(img, name)


if __name__ == "__main__":
    floor_tile()
    wood_floor()
    marble()
    terrazzo()
    concrete_polished()
    carpet()
    subway_tile()
    slatwall()
    brushed_metal()
    fabric()
    ceiling_tile()
    wood_slats()
    poster("mall_poster_autumn", "AUTUMN EDIT", "new knitwear in store", (196, 120, 84), (250, 240, 228), "left")
    poster("mall_poster_denim", "THE DENIM SHOP", "every fit, every wash", (52, 76, 120), (236, 240, 248), "right")
    poster("mall_poster_sport", "MOVE MORE", "new season training gear", (30, 30, 34), (250, 250, 250), "centre")
    poster("mall_poster_sale", "UP TO 50% OFF", "selected styles", (200, 30, 40), (255, 255, 255), "left")
