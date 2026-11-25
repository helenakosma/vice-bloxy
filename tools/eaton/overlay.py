"""Draw the generated Eaton Centre geometry (src/.../EatonCentre/Data/*.lua) over
the leasing-plan sheets (out/<level>.png) so the two can be compared directly.
Writes docs/eaton/overlays/<level>.png. Grey fill = our floor, red = storefront
walls, blue = plaster walls, black = exterior walls, green = entrances,
magenta = escalators, orange = balustrades round floor openings."""
import json, os, re, sys
import cv2, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "..", "src", "server", "World", "EatonCentre", "Data")
OUT = os.path.join(HERE, "out")
DEST = os.path.join(HERE, "..", "..", "docs", "eaton", "overlays")
RES = 2.0
NUM = r"-?[\d.]+"

def block(src, name):
    m = re.search(r"\b" + name + r" = \{(.*?)\n\t\},", src, re.S)
    return [list(map(float, re.findall(NUM, b)[:5])) for b in re.findall(r"\{([^{}]*)\}", m.group(1))] if m else []

shared = open(os.path.join(DATA, "Shared.lua"), encoding="utf-8").read()
escs = [tuple(map(float, x)) for x in re.findall(r"from = (\d), to = (\d), bottom = \{ (" + NUM + "), (" + NUM + r") \}, top = \{ (" + NUM + "), (" + NUM + r") \}", shared)]
IDX = {"concourse": 0, "L1": 1, "L2": 2, "L3": 3}
COL = {1: (200, 90, 40), 2: (40, 40, 220), 3: (20, 20, 20), 4: (40, 170, 40)}
for lv, idx in IDX.items():
    src = open(os.path.join(DATA, lv + ".lua"), encoding="utf-8").read()
    reg = json.load(open(os.path.join(OUT, lv + ".json")))["registration"]
    q, y = reg["queenPx"], reg["yongePx"]
    im = cv2.imread(os.path.join(OUT, lv + ".png"))
    def px(u, v):
        return int(round(q + RES * u)), int(round(y - RES * v))
    fill = im.copy()
    for s in block(src, "slabs"):
        cv2.rectangle(fill, px(s[0], s[1]), px(s[2], s[3]), (150, 150, 150), -1)
    im = cv2.addWeighted(fill, 0.35, im, 0.65, 0)
    for w in block(src, "walls"):
        if len(w) >= 5:
            cv2.line(im, px(w[0], w[1]), px(w[2], w[3]), COL.get(int(w[4]), (0, 0, 0)), 2)
    for r in block(src, "rails"):
        cv2.line(im, px(r[0], r[1]), px(r[2], r[3]), (0, 140, 255), 2)
    for e in escs:
        if idx in (int(e[0]), int(e[1])):
            cv2.arrowedLine(im, px(e[2], e[3]), px(e[4], e[5]), (200, 0, 200), 3, tipLength=0.15)
    # a 100 ft grid in plan feet
    for u in range(0, 1500, 100):
        cv2.putText(im, str(u), px(u, -20), 0, 0.8, (0, 0, 180), 2)
    scale = 1600 / im.shape[1]
    cv2.imwrite(os.path.join(DEST, lv + ".png"), cv2.resize(im, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA))
    # Close-up of the Yonge & Dundas corner.
    x0, x1 = max(0, q + int(RES * 1150)), min(im.shape[1], q + int(RES * 1440))
    y0, y1 = max(0, y - int(RES * 250)), min(im.shape[0], y + int(RES * 30))
    if x1 > x0 and y1 > y0:
        cv2.imwrite(os.path.join(DEST, lv + "_corner.png"), im[y0:y1, x0:x1])
    print(lv, "ok")

# Sheets not built yet (Level 2B, Level 4): draw what was traced from them.
for lv in ("L2B", "L4"):
    d = json.load(open(os.path.join(OUT, lv + ".json")))
    reg = d["registration"]
    q, y = reg["queenPx"], reg["yongePx"]
    im = cv2.imread(os.path.join(OUT, lv + ".png"))
    def px(p):
        return [int(round(q + RES * p[0])), int(round(y - RES * p[1]))]
    def polys(items, colour, thick, fill=None):
        global im
        for it in items:
            for poly in it.get("polys", [it]):
                pts = np.array([px(p) for p in poly["outer"]], np.int32)
                if fill is not None:
                    layer = im.copy()
                    cv2.fillPoly(layer, [pts], fill)
                    im = cv2.addWeighted(layer, 0.35, im, 0.65, 0)
                cv2.polylines(im, [pts], True, colour, thick)
    polys(d["common"], (150, 150, 150), 1, (150, 150, 150))
    polys(d["voids"], (0, 140, 255), 2)
    polys([s for s in d["specials"] if s.get("kind") == "void"], (0, 140, 255), 3)
    polys(d["units"], (40, 40, 220), 3)
    polys(d["footprint"], (20, 20, 20), 2)
    for u in range(0, 1500, 100):
        cv2.putText(im, str(u), tuple(px((u, -20))), 0, 0.8, (0, 0, 180), 2)
    scale = 1600 / im.shape[1]
    cv2.imwrite(os.path.join(DEST, lv + ".png"), cv2.resize(im, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA))
    print(lv, "ok")
