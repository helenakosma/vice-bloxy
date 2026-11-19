"""Generates the Vice Bloxy texture set into assets/textures/.

Run:  python tools/make_textures.py
Then import the PNGs in Roblox Studio (Asset Manager -> Bulk Import) and put the
resulting image IDs into src/shared/Assets.lua.

Everything is procedural (numpy + Pillow); fonts come from the local Windows fonts.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1986)
random.seed(1986)
FONTS = "C:/Windows/Fonts/"


def font(name, size):
    try:
        return ImageFont.truetype(FONTS + name, size)
    except OSError:
        return ImageFont.load_default()


def noise(w, h, scale, octaves=4, seed=0, tile=True):
    """Tileable value noise in [0, 1]."""
    r = np.random.default_rng(seed)
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        cells = max(2, int(scale * 2 ** o))
        grid = r.random((cells, cells))
        if tile:
            grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (w + w // cells, h + h // cells), Image.BICUBIC)
        arr = np.asarray(img, dtype=float)[:h, :w] / 255
        total += arr * amp
        norm += amp
        amp *= 0.5
    return total / norm


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def shade(rgb, f):
    return tuple(int(max(0, min(255, c * f))) for c in rgb)


# ---------------------------------------------------------------- walls
def brick(name, base, mortar=(150, 144, 136), seed=1):
    W = H = 512
    rows, cols = 24, 8
    bh, bw = H / rows, W / cols
    img = Image.new("RGB", (W, H), mortar)
    d = ImageDraw.Draw(img)
    r = random.Random(seed)
    for row in range(rows):
        off = (bw / 2) if row % 2 else 0
        for c in range(-1, cols + 1):
            x0 = c * bw + off + 2
            y0 = row * bh + 2
            f = r.uniform(0.78, 1.15)
            if r.random() < 0.08:
                f *= 0.7
            col = shade(base, f)
            col = (col[0] + r.randint(-8, 8), col[1] + r.randint(-6, 6), col[2] + r.randint(-6, 6))
            for dx in (0, -W, W):
                d.rectangle([x0 + dx, y0, x0 + dx + bw - 4, y0 + bh - 4], fill=col)
    arr = np.asarray(img, dtype=float)
    n = noise(W, H, 16, 4, seed)[..., None]
    fine = noise(W, H, 64, 2, seed + 7)[..., None]
    arr = arr * (0.82 + 0.3 * n) * (0.92 + 0.16 * fine)
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), name)


def blocks(name, base, rows, cols, joint=(120, 116, 110), seed=2, var=0.08):
    W = H = 512
    img = Image.new("RGB", (W, H), joint)
    d = ImageDraw.Draw(img)
    r = random.Random(seed)
    bh, bw = H / rows, W / cols
    for row in range(rows):
        off = (bw / 2) if row % 2 else 0
        for c in range(-1, cols + 1):
            f = r.uniform(1 - var, 1 + var)
            x0 = c * bw + off + 1.5
            for dx in (0, -W, W):
                d.rectangle([x0 + dx, row * bh + 1.5, x0 + dx + bw - 3, row * bh + bh - 3], fill=shade(base, f))
    arr = np.asarray(img, dtype=float)
    n = noise(W, H, 8, 5, seed)[..., None]
    arr = arr * (0.85 + 0.25 * n)
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), name)


def concrete(name, base=(150, 148, 142), seed=3):
    W = H = 512
    n = noise(W, H, 6, 6, seed)
    streak = noise(W, 8, 24, 3, seed + 1)
    streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), dtype=float)[..., None] / 255
    arr = np.ones((H, W, 3)) * np.array(base)
    arr = arr * (0.82 + 0.28 * n[..., None]) * (0.9 + 0.12 * streak)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # Formwork panel joints and tie holes.
    for x in (0, 256):
        d.line([x, 0, x, H], fill=shade(base, 0.7), width=2)
    d.line([0, 256, W, 256], fill=shade(base, 0.7), width=2)
    for x in range(64, W, 128):
        for y in range(64, H, 128):
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=shade(base, 0.55))
    save(img, name)


def sidewalk(name, seed=4):
    W = H = 512
    base = np.array((168, 164, 156))
    n = noise(W, H, 10, 5, seed)
    speck = (np.random.default_rng(seed).random((H, W)) < 0.02) * -40
    arr = base * (0.86 + 0.2 * n[..., None]) + speck[..., None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for x in (0, 256):
        d.line([x, 0, x, H], fill=(112, 108, 102), width=3)
    for y in (0, 256):
        d.line([0, y, W, y], fill=(112, 108, 102), width=3)
    r = random.Random(seed)
    for _ in range(5):  # gum spots and stains
        x, y = r.randint(10, 500), r.randint(10, 500)
        s = r.randint(3, 9)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(132, 128, 122))
    for _ in range(3):  # hairline cracks
        x, y = r.randint(0, 512), r.randint(0, 512)
        pts = [(x, y)]
        for _ in range(6):
            x += r.randint(-18, 18)
            y += r.randint(-18, 18)
            pts.append((x, y))
        d.line(pts, fill=(118, 114, 108), width=1)
    save(img.filter(ImageFilter.SMOOTH), name)


def grime(name, seed=5):
    W, H = 512, 1024
    r = np.random.default_rng(seed)
    alpha = np.zeros((H, W))
    # Streaks running down from the top and from ledges.
    for _ in range(70):
        x = r.integers(0, W)
        width = r.integers(3, 18)
        start = r.choice([0, r.integers(0, H)])
        length = r.integers(60, 500)
        strength = r.uniform(0.15, 0.45)
        ys = np.arange(start, min(H, start + length))
        fade = np.linspace(1, 0, len(ys)) ** 1.5 * strength
        xs = slice(max(0, x - width // 2), min(W, x + width // 2))
        alpha[ys, xs] = np.maximum(alpha[ys, xs], fade[:, None])
    # Dirt near the ground and a soft top band.
    yy = np.linspace(0, 1, H)[:, None]
    alpha = np.maximum(alpha, np.clip((yy - 0.85) / 0.15, 0, 1) * 0.45)
    alpha = np.maximum(alpha, np.clip((0.06 - yy) / 0.06, 0, 1) * 0.35)
    alpha *= 0.7 + 0.6 * noise(W, H, 8, 4, seed)
    a = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))
    img = Image.new("RGBA", (W, H), (34, 30, 26, 0))
    img.putalpha(a)
    save(img, name)


# ---------------------------------------------------------------- windows
def window_base(W=256, H=384):
    return Image.new("RGB", (W, H)), W, H


def reflection(img, strength=0.35, seed=0):
    W, H = img.size
    over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    r = random.Random(seed)
    x = r.randint(-W, 0)
    d.polygon([(x, H), (x + W * 0.5, H), (x + W * 1.4, 0), (x + W * 0.9, 0)], fill=(220, 230, 240, int(255 * strength * 0.5)))
    d.polygon([(x + W * 0.6, H), (x + W * 0.7, H), (x + W * 1.6, 0), (x + W * 1.5, 0)], fill=(230, 236, 245, int(255 * strength * 0.35)))
    over = over.filter(ImageFilter.GaussianBlur(6))
    base = img.convert("RGBA")
    base.alpha_composite(over)
    return base.convert("RGB")


def sash(img):
    d = ImageDraw.Draw(img)
    W, H = img.size
    d.rectangle([0, H * 0.48, W, H * 0.52], fill=(236, 232, 224))
    d.rectangle([0, 0, W, 6], fill=(236, 232, 224))
    d.rectangle([0, H - 6, W, H], fill=(236, 232, 224))
    d.rectangle([0, 0, 6, H], fill=(236, 232, 224))
    d.rectangle([W - 6, 0, W, H], fill=(236, 232, 224))
    return img


def window_curtains():
    img, W, H = window_base()
    arr = np.zeros((H, W, 3))
    yy = np.linspace(0, 1, H)[:, None]
    warm = np.array((236, 200, 150)) * (1 - 0.35 * yy) + np.array((60, 40, 20)) * 0.2
    arr[:] = warm[:, None, :] if warm.ndim == 2 else warm
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    d.ellipse([W * 0.35, H * 0.08, W * 0.65, H * 0.18], fill=(255, 240, 200))  # ceiling light
    col = random.choice([(150, 40, 50), (60, 80, 140), (200, 180, 140), (70, 110, 80)])
    for side in (0, 1):
        x0 = 0 if side == 0 else W * 0.68
        for k in range(8):
            f = 0.75 + 0.35 * math.sin(k * 1.3)
            d.rectangle([x0 + k * W * 0.04, 0, x0 + (k + 1) * W * 0.04, H], fill=shade(col, f))
    return sash(reflection(img, 0.25, 1))


def window_blinds():
    img, W, H = window_base()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, H], fill=(70, 66, 60))
    drop = int(H * 0.7)
    for y in range(0, drop, 9):
        d.rectangle([0, y, W, y + 6], fill=(214, 208, 196))
        d.line([0, y + 6, W, y + 6], fill=(150, 144, 134))
    d.rectangle([0, drop, W, H], fill=(48, 44, 40))
    return sash(reflection(img, 0.3, 2))


def window_dark():
    img, W, H = window_base()
    arr = np.zeros((H, W, 3))
    yy = np.linspace(0, 1, H)[:, None]
    sky = np.array((150, 175, 200)) * (1 - yy) + np.array((40, 48, 58)) * yy
    arr[:] = sky[:, None, :]
    img = Image.fromarray(arr.astype(np.uint8))
    d = ImageDraw.Draw(img)
    for i in range(4):  # reflected buildings
        x = random.randint(0, W)
        d.rectangle([x, H * random.uniform(0.25, 0.5), x + random.randint(30, 80), H], fill=(58, 64, 72))
    return sash(reflection(img, 0.45, 3))


def window_room():
    img, W, H = window_base()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, H], fill=(196, 170, 130))
    d.rectangle([0, H * 0.75, W, H], fill=(120, 86, 60))  # furniture/floor
    d.rectangle([W * 0.55, H * 0.25, W * 0.85, H * 0.45], fill=(80, 60, 50))  # picture frame
    d.rectangle([W * 0.58, H * 0.28, W * 0.82, H * 0.42], fill=(90, 130, 150))
    d.ellipse([W * 0.12, H * 0.45, W * 0.32, H * 0.62], fill=(255, 230, 170))  # lamp
    d.rectangle([W * 0.2, H * 0.6, W * 0.24, H * 0.8], fill=(60, 50, 40))
    img = img.filter(ImageFilter.GaussianBlur(1.5))
    return sash(reflection(img, 0.3, 4))


# ---------------------------------------------------------------- shops
PRODUCT_COLORS = [(200, 40, 40), (240, 190, 40), (40, 110, 190), (60, 160, 70), (240, 240, 230), (230, 120, 40), (130, 60, 160), (30, 30, 30)]


def shop_shelves():
    W = H = 512
    img = Image.new("RGB", (W, H), (60, 60, 64))
    d = ImageDraw.Draw(img)
    levels = 5
    lh = H / levels
    r = random.Random(7)
    for lv in range(levels):
        y1 = (lv + 1) * lh
        d.rectangle([0, y1 - 10, W, y1], fill=(220, 220, 216))  # shelf lip
        d.rectangle([0, y1 - 10, W, y1 - 4], fill=(250, 250, 248))
        x = 0
        while x < W:
            pw = r.randint(18, 40)
            ph = r.randint(int(lh * 0.45), int(lh * 0.85))
            col = r.choice(PRODUCT_COLORS)
            d.rectangle([x + 1, y1 - 10 - ph, x + pw - 1, y1 - 10], fill=col)
            d.rectangle([x + 4, y1 - 10 - ph * 0.7, x + pw - 4, y1 - 10 - ph * 0.45], fill=shade(col, 1.5))
            d.rectangle([x + 1, y1 - 10 - ph, x + 4, y1 - 10], fill=shade(col, 0.7))
            x += pw
        for px in range(10, W, 64):  # price tags
            d.rectangle([px, y1 - 8, px + 16, y1 - 3], fill=(255, 230, 60))
    save(img, "shop_shelves")


def shop_fridge():
    W, H = 256, 512
    img = Image.new("RGB", (W, H), (220, 236, 245))
    d = ImageDraw.Draw(img)
    r = random.Random(8)
    for lv in range(5):
        y1 = 40 + (lv + 1) * 88
        d.rectangle([10, y1 - 4, W - 10, y1], fill=(200, 210, 215))
        x = 14
        col = r.choice(PRODUCT_COLORS)
        while x < W - 30:
            bw = r.randint(16, 22)
            bh = r.randint(55, 75)
            if r.random() < 0.3:
                col = r.choice(PRODUCT_COLORS)
            d.rounded_rectangle([x, y1 - 4 - bh, x + bw, y1 - 4], radius=6, fill=col)
            d.rectangle([x + 3, y1 - 4 - bh * 0.6, x + bw - 3, y1 - 4 - bh * 0.35], fill=(245, 245, 240))
            d.rectangle([x + bw * 0.35, y1 - 8 - bh, x + bw * 0.65, y1 - bh], fill=shade(col, 0.6))
            x += bw + 3
    d.rectangle([0, 0, W, 34], fill=(30, 30, 34))
    d.text((20, 6), "COLD DRINKS", fill=(120, 220, 255), font=font("arialbd.ttf", 20))
    d.rectangle([0, 0, 8, H], fill=(180, 184, 188))
    d.rectangle([W - 8, 0, W, H], fill=(180, 184, 188))
    d.rectangle([W - 28, 200, W - 18, 320], fill=(150, 154, 158))
    save(reflection(img, 0.3, 9), "shop_fridge")


def storefront(name, kind):
    W, H = 512, 256
    img = Image.new("RGB", (W, H), (230, 214, 180))
    d = ImageDraw.Draw(img)
    r = random.Random(10 if kind == "deli" else 11)
    d.rectangle([0, H * 0.8, W, H], fill=(150, 140, 126))  # floor
    for x in range(0, W, 100):
        d.ellipse([x + 30, 6, x + 70, 18], fill=(255, 250, 230))  # lights
    if kind == "deli":
        for lv in range(4):
            y = 40 + lv * 36
            x = 0
            while x < W:
                pw = r.randint(10, 22)
                d.rectangle([x, y, x + pw - 2, y + 28], fill=r.choice(PRODUCT_COLORS))
                x += pw
            d.rectangle([0, y + 28, W, y + 32], fill=(220, 220, 220))
        d.rectangle([W * 0.55, H * 0.55, W * 0.95, H * 0.85], fill=(120, 80, 50))  # counter
        d.rectangle([W * 0.6, H * 0.5, W * 0.68, H * 0.56], fill=(40, 40, 40))
    else:
        for i in range(5):
            x = 40 + i * 95
            d.line([x, 60, x + 70, 60], fill=(160, 160, 160), width=3)
            for k in range(6):
                col = r.choice([(30, 30, 30), (220, 220, 210), (150, 40, 50), (60, 80, 130), (190, 150, 110)])
                d.rectangle([x + k * 11, 62, x + k * 11 + 9, 150], fill=col)
        for mx in (120, 360):  # mannequins
            d.ellipse([mx - 10, 90, mx + 10, 112], fill=(230, 225, 215))
            d.rectangle([mx - 16, 112, mx + 16, 180], fill=r.choice([(40, 40, 40), (180, 60, 70)]))
    img = img.filter(ImageFilter.GaussianBlur(2))
    save(reflection(img, 0.35, 12), name)


def menu_board():
    W, H = 512, 256
    img = Image.new("RGB", (W, H), (28, 30, 30))
    d = ImageDraw.Draw(img)
    big, small = font("bahnschrift.ttf", 30), font("bahnschrift.ttf", 20)
    d.text((24, 14), "BEAN STREET  ·  MENU", fill=(240, 220, 170), font=big)
    items = [("ESPRESSO", "3.00"), ("CAPPUCCINO", "4.25"), ("LATTE", "4.50"), ("COLD BREW", "4.75"),
             ("CROISSANT", "3.50"), ("BAGEL & SCHMEAR", "4.00"), ("MUFFIN", "3.25"), ("AVOCADO TOAST", "9.00")]
    for i, (name, price) in enumerate(items):
        x = 24 if i < 4 else 272
        y = 70 + (i % 4) * 42
        d.text((x, y), name, fill=(235, 235, 230), font=small)
        d.text((x + 190, y), price, fill=(240, 200, 120), font=small)
    save(img, "menu_board")


def poster(name, title, sub, bg, fg, accent):
    W, H = 256, 384
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    d.ellipse([-60, 120, W + 60, H + 200], fill=accent)
    d.text((18, 20), title, fill=fg, font=font("impact.ttf", 46))
    d.text((18, 80), sub, fill=fg, font=font("arialbd.ttf", 18))
    d.rounded_rectangle([90, 170, 166, 330], radius=18, fill=shade(fg, 0.9))
    d.rectangle([100, 220, 156, 270], fill=bg)
    save(img, name)


# ---------------------------------------------------------------- road decals
def rgba(W, H):
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def manhole():
    img = rgba(256, 256)
    d = ImageDraw.Draw(img)
    d.ellipse([8, 8, 248, 248], fill=(72, 70, 66, 255))
    d.ellipse([20, 20, 236, 236], fill=(92, 88, 82, 255))
    for k in range(-5, 6):
        d.line([128 + k * 18, 30, 128 + k * 18, 226], fill=(70, 68, 64, 255), width=5)
        d.line([30, 128 + k * 18, 226, 128 + k * 18], fill=(70, 68, 64, 255), width=5)
    d.ellipse([20, 20, 236, 236], outline=(60, 58, 54, 255), width=6)
    d.text((86, 112), "SEWER", fill=(64, 62, 58, 255), font=font("arialbd.ttf", 22))
    save(img, "manhole")


def drain_grate():
    img = rgba(256, 128)
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 252, 124], fill=(70, 68, 64, 255))
    for x in range(16, 244, 16):
        d.rectangle([x, 14, x + 8, 114], fill=(18, 18, 18, 255))
    save(img, "drain_grate")


def arrow(name, kind):
    W, H = 256, 512
    img = rgba(W, H)
    d = ImageDraw.Draw(img)
    white = (235, 235, 230, 235)
    if kind == "straight":
        d.rectangle([108, 160, 148, 500], fill=white)
        d.polygon([(48, 180), (128, 20), (208, 180)], fill=white)
    else:
        sign = -1 if kind == "left" else 1
        d.rectangle([108, 260, 148, 500], fill=white)
        cx = 128
        d.rectangle([min(cx, cx + sign * 70), 220, max(cx + 20, cx + sign * 70 + 20), 260], fill=white)
        tip_x = cx + sign * 120
        base_x = cx + sign * 50
        d.polygon([(base_x, 150), (tip_x, 240), (base_x, 330)], fill=white)
        d.rectangle([min(cx - 20, base_x), 220, max(cx + 20, base_x), 260], fill=white)
    save(img, name)


def stop_sign():
    img = rgba(256, 256)
    d = ImageDraw.Draw(img)
    pts = [(128 + 120 * math.cos(math.pi / 8 + k * math.pi / 4), 128 + 120 * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
    d.polygon(pts, fill=(245, 245, 245, 255))
    pts2 = [(128 + 108 * math.cos(math.pi / 8 + k * math.pi / 4), 128 + 108 * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
    d.polygon(pts2, fill=(196, 24, 30, 255))
    f = font("arialbd.ttf", 66)
    tw = d.textlength("STOP", font=f)
    d.text((128 - tw / 2, 92), "STOP", fill=(250, 250, 250, 255), font=f)
    save(img, "stop_sign")


# ---------------------------------------------------------------- billboards
def billboard(name, title, sub, bg1, bg2, fg, size=150):
    W, H = 1024, 512
    arr = np.zeros((H, W, 3))
    xx = np.linspace(0, 1, W)[None, :, None]
    arr[:] = np.array(bg1) * (1 - xx) + np.array(bg2) * xx
    img = Image.fromarray(arr.astype(np.uint8))
    d = ImageDraw.Draw(img)
    d.ellipse([560, -120, 1160, 480], fill=shade(bg2, 1.25))
    d.text((60, 90), title, fill=fg, font=font("impact.ttf", size))
    d.text((66, 280), sub, fill=fg, font=font("arialbd.ttf", 44))
    d.rounded_rectangle([760, 120, 900, 440], radius=40, fill=(250, 250, 250))
    d.rectangle([780, 220, 880, 330], fill=bg1)
    save(img, name)


def night_windows():
    """Overlay for lit floor bands at night: a row of windows (some lit, some dark)
    separated by mullions. Transparent where a window is lit so the glow shows."""
    W, H = 512, 256
    img = rgba(W, H)
    d = ImageDraw.Draw(img)
    frame = (26, 26, 30, 255)
    cells = 8
    cw = W / cells
    r = random.Random(42)
    d.rectangle([0, 0, W, H * 0.16], fill=frame)
    d.rectangle([0, H * 0.84, W, H], fill=frame)
    for c in range(cells):
        x0 = c * cw
        d.rectangle([x0, 0, x0 + cw * 0.12, H], fill=frame)
        roll = r.random()
        if roll < 0.35:  # dark window
            d.rectangle([x0 + cw * 0.12, H * 0.16, x0 + cw, H * 0.84], fill=(18, 20, 26, 240))
        elif roll < 0.55:  # blinds half down
            for y in range(int(H * 0.16), int(H * 0.5), 10):
                d.rectangle([x0 + cw * 0.12, y, x0 + cw, y + 6], fill=(60, 50, 40, 200))
        elif roll < 0.65:  # curtain on one side
            d.rectangle([x0 + cw * 0.12, H * 0.16, x0 + cw * 0.4, H * 0.84], fill=(90, 40, 40, 170))
    save(img, "night_windows")


if __name__ == "__main__":
    night_windows()
    brick("brick_red", (150, 72, 52), seed=1)
    brick("brick_brown", (120, 84, 64), mortar=(140, 132, 120), seed=2)
    blocks("limestone", (206, 196, 176), rows=6, cols=3, seed=3)
    concrete("concrete_stained")
    sidewalk("sidewalk_slabs")
    grime("grime_streaks")
    save(window_curtains(), "window_curtains")
    save(window_blinds(), "window_blinds")
    save(window_dark(), "window_dark")
    save(window_room(), "window_room")
    shop_shelves()
    shop_fridge()
    storefront("storefront_deli", "deli")
    storefront("storefront_boutique", "boutique")
    menu_board()
    poster("poster_cola", "FIZZ", "COLA · TASTE THE CITY", (200, 30, 40), (250, 250, 245), (150, 20, 30))
    poster("poster_radio", "VICE FM", "98.4 · ALL NIGHT HITS", (30, 20, 60), (255, 120, 200), (80, 40, 140))
    manhole()
    drain_grate()
    arrow("arrow_straight", "straight")
    arrow("arrow_left", "left")
    arrow("arrow_right", "right")
    stop_sign()
    billboard("billboard_phone", "NOVA X", "THE PHONE THAT GETS YOU", (20, 30, 60), (60, 120, 200), (255, 255, 255))
    billboard("billboard_burger", "MEGA BURGER", "NOW OPEN 24 HOURS", (230, 150, 20), (200, 40, 30), (255, 250, 235), size=104)
