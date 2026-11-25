"""Food court furniture from the concourse leasing plan.

The Urban Eatery sheet draws every table and chair. The page is rendered at a
high resolution and every small closed outline inside the common area is
classified by size and shape:
  round table   circle 2.2-4.5 ft across
  table         rectangle with both sides >= 2 ft (communal tables up to 14 ft)
  chair         closed shape 0.9-2 ft across (round or square)
Positions are converted to plan feet (u north of Queen St, v west of Yonge)
with the concourse registration from extract.py.

Output: src/server/World/EatonCentre/Data/Furniture.lua
Usage: python tools/eaton/furniture.py <leasing pdf>
"""
import json
import math
import os
import sys

import cv2
import numpy as np
import pymupdf as fitz

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import to_lua as T  # noqa: E402

OUT = os.path.join(HERE, "out")
DEST = os.path.join(HERE, "..", "..", "src", "server", "World", "EatonCentre", "Data", "Furniture.lua")
PX_PER_FT = 10


def main(pdf):
    doc = fitz.open(pdf)
    J = json.load(open(os.path.join(OUT, "concourse.json")))
    page = doc[J["page"] - 1]
    s = J["ptPerFt"]
    q, y = J["registration"]["queenPx"] / 2, J["registration"]["yongePx"] / 2  # page feet
    zoom = PX_PER_FT / s
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
    img = np.frombuffer(pix.samples, np.uint8).reshape(pix.h, pix.w, pix.n)[:, :, :3]
    grey = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    ink = (grey < 215).astype(np.uint8)  # hairlines render faint; common-area grey is ~235
    # Seating sits on open floor: inside the concourse, outside every shop unit
    # (the seating islands are drawn as white platforms, not common area).
    floor = T.raster(J["footprint"])
    for un in J["units"]:
        floor &= ~T.raster(un["polys"])
    # Structural columns are drawn as circles too: keep away from the column grid.
    import extract as X
    cols = X.grid_features(page, s)
    col_uv = [(cx - q, y - cy) for cx, cy in cols]

    def plan(px, py):
        return px / PX_PER_FT - q, y - py / PX_PER_FT

    items = []
    cs, hier = cv2.findContours(ink, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    for i, c in enumerate(cs):
        if hier[0][i][3] == -1:
            continue  # only the insides of drawn outlines
        (cx, cy), (w, h), ang = cv2.minAreaRect(c)
        wf, hf = w / PX_PER_FT, h / PX_PER_FT
        big, small = max(wf, hf), min(wf, hf)
        if big < 0.8 or big > 14:
            continue
        u, v = plan(cx, cy)
        if not T.at(floor, u, v):
            continue
        if any(math.hypot(u - cu, v - cv) < 1.2 for cu, cv in col_uv):
            continue
        area = cv2.contourArea(c)
        circ = 4 * math.pi * area / max(cv2.arcLength(c, True) ** 2, 1e-6)
        if 2.2 <= big <= 4.5 and circ > 0.8:
            kind = "round"
        elif 3.8 <= big <= 7.5 and small >= 3.4 and 0.25 <= circ <= 0.8:
            kind = "roundset"  # a round table drawn joined to its four chairs
        elif small >= 1.9 and big >= 2.2:
            kind = "table"
        elif 0.8 <= big <= 2.0 and small >= 0.7:
            kind = "chair"
        else:
            continue
        # Angle of the long side, in plan terms (page x -> u, page y -> -v).
        if w < h:
            ang += 90
        a = -math.radians(ang)
        items.append({"kind": kind, "u": round(u, 1), "v": round(v, 1), "w": round(big, 1), "d": round(small, 1), "a": round(a, 2)})
    # Drop near duplicates (an outline's inner and outer edge).
    kept = []
    for it in sorted(items, key=lambda t: -t["w"]):
        if any(k["kind"] == it["kind"] and math.hypot(k["u"] - it["u"], k["v"] - it["v"]) < 0.6 for k in kept):
            continue
        kept.append(it)
    # Tables hidden between their chairs: a small cluster of chairs (2-6, each
    # within 3.2 ft of another) with no table among them gets one at its centre.
    chairs = [k for k in kept if k["kind"] == "chair"]
    tables = [k for k in kept if k["kind"] != "chair"]
    seen = set()
    for i, c in enumerate(chairs):
        if i in seen:
            continue
        group, stack = [i], [i]
        seen.add(i)
        while stack:
            j = stack.pop()
            for k2, c2 in enumerate(chairs):
                if k2 not in seen and math.hypot(c2["u"] - chairs[j]["u"], c2["v"] - chairs[j]["v"]) < 3.2:
                    seen.add(k2)
                    group.append(k2)
                    stack.append(k2)
        if not 2 <= len(group) <= 6:
            continue
        us = [chairs[g]["u"] for g in group]
        vs = [chairs[g]["v"] for g in group]
        cu, cv = sum(us) / len(us), sum(vs) / len(vs)
        if any(abs(t["u"] - cu) < max(t["w"], 2) and abs(t["v"] - cv) < max(t["w"], 2) for t in tables):
            continue
        w_ = max(2.5, max(us) - min(us) - 1.2)
        d_ = max(2.5, max(vs) - min(vs) - 1.2)
        kept.append({"kind": "table", "u": round(cu, 1), "v": round(cv, 1), "w": round(max(w_, d_), 1), "d": round(min(w_, d_), 1),
                     "a": 0.0 if w_ >= d_ else round(math.pi / 2, 2), "inferred": True})
    lines = ["-- Generated by tools/eaton/furniture.py: the Urban Eatery's tables and chairs as",
             "-- drawn on the concourse leasing plan (plan feet; a = angle of the long side).", "return {"]
    for it in kept:
        lines.append("\t{ " + ", ".join(f"{k} = {json.dumps(v)}" for k, v in it.items()) + " },")
    lines += ["}", ""]
    with open(DEST, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    from collections import Counter
    print(len(kept), dict(Counter(k["kind"] for k in kept)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/TECON20_LEASING.pdf"))
