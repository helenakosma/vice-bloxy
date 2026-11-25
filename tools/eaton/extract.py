"""Extract CF Toronto Eaton Centre geometry from the leasing plans (vector PDF).

Each level's page is redrawn from its vector paths without text, in paint order,
then read back as a raster:
  * grey (0.92) fill  -> retail common area (corridors, courts)
  * white             -> open floor: unit interiors, voids, outside
  * hairline strokes  -> walls / lease lines
Units are flood-filled from their own label (NAME / UNIT / SQ FT), and the traced
area is checked against the printed square footage. Nothing is guessed: anything
that can't be traced cleanly is reported, not invented.

Output (plan feet; u = north from the level's Queen St wall, v = west from the
Yonge St wall):
  tools/eaton/out/<level>.json     geometry for the Roblox builder
  tools/eaton/out/<level>.png      overlay to compare against the PDF
  tools/eaton/out/report.txt       per-unit area check

Usage: python tools/eaton/extract.py <path to TECON20_LEASING.pdf>
"""
import json
import math
import os
import re
import sys

import cv2
import numpy as np
import pymupdf as fitz

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

RES = 2.0  # raster pixels per plan foot (0.5 ft per pixel)
MIN_STROKE_FT = float(os.environ.get("MIN_STROKE_FT", "0"))  # skip shorter strokes (fixtures, underlines)

# Page index in the leasing PDF for each level we build.
LEVELS = {
    "L1": 1,  # first: the concourse is registered to it
    "concourse": 0,
    "L2": 2,
    "L3": 5,
    "L5": 7,  # roof level: the galleria skylight is labelled as a void here
    "L2B": 4,  # the small mezzanine by 250 Yonge Street
    "L4": 6,  # the partial fourth floor over the north end
}

# Sheets whose printed scale bar disagrees with the drawing: a factor on the
# bar's pt/ft. Level 2B's units trace at ~2.45x their printed areas against the
# bar (linear 1.56; traced areas usually run ~4% under printed, hence 1.597),
# and with that factor Roots' frontage (54 ft) matches its 56 ft on Level 3.
SCALE_FIX = {"L2B": 1.597}
# Sheets with too few columns to register by the grid: a fixed offset (feet,
# page -> Level 1 page) found by lining a shared unit up across levels.
REG_FIX = {"L2B": (734.0, 751.0)}  # Roots C032A centred on its Level 3 unit, Yonge wall on v = 0

UNIT_RE = re.compile(r"^[A-Z0-9]{2,8}[A-Z]?$")
AREA_RE = re.compile(r"^\d{1,3}(,\d{3})*$")

# Pixel classes in the redrawn raster.
EMPTY, LINE, COMMON, OTHER = 0, 1, 2, 3


def scale_bar(page):
    """pt per foot, from the centres of the scale bar's '0' and the largest foot label."""
    M = page.rotation_matrix
    words = [(w[4], fitz.Rect(w[:4]) * M) for w in page.get_text("words")]
    ft = [r for t, r in words if t == "[ft]"]
    if not ft:
        raise RuntimeError("no scale bar")
    fy = ft[0].y0
    row = [(t, r) for t, r in words if abs(r.y0 - (fy + 4)) < 6 and r.x0 > ft[0].x0 and t.isdigit()]
    zero = [r for t, r in row if t == "0"][0]
    top = max(row, key=lambda tr: int(tr[0]))
    return ((top[1].x0 + top[1].x1) / 2 - (zero.x0 + zero.x1) / 2) / int(top[0])


def flatten(items, M):
    """Path items -> list of subpaths (lists of points) in derotated page space."""
    subs, cur = [], []

    def add(pt):
        nonlocal cur
        if cur and (abs(cur[-1][0] - pt.x) > 1e-3 or abs(cur[-1][1] - pt.y) > 1e-3):
            subs.append(cur)
            cur = []
        cur.append((pt.x, pt.y))

    for it in items:
        k = it[0]
        if k == "l":
            a, b = it[1] * M, it[2] * M
            if not cur or abs(cur[-1][0] - a.x) > 1e-3 or abs(cur[-1][1] - a.y) > 1e-3:
                if cur:
                    subs.append(cur)
                cur = [(a.x, a.y)]
            cur.append((b.x, b.y))
        elif k == "c":
            p0, p1, p2, p3 = (q * M for q in it[1:5])
            if not cur or abs(cur[-1][0] - p0.x) > 1e-3 or abs(cur[-1][1] - p0.y) > 1e-3:
                if cur:
                    subs.append(cur)
                cur = [(p0.x, p0.y)]
            for i in range(1, 9):
                t = i / 8
                mt = 1 - t
                x = mt**3 * p0.x + 3 * mt * mt * t * p1.x + 3 * mt * t * t * p2.x + t**3 * p3.x
                y = mt**3 * p0.y + 3 * mt * mt * t * p1.y + 3 * mt * t * t * p2.y + t**3 * p3.y
                cur.append((x, y))
        elif k == "re":
            if cur:
                subs.append(cur)
                cur = []
            r = it[1]
            pts = [fitz.Point(r.x0, r.y0), fitz.Point(r.x1, r.y0), fitz.Point(r.x1, r.y1), fitz.Point(r.x0, r.y1)]
            pts.append(pts[0])
            subs.append([((q * M).x, (q * M).y) for q in pts])
        elif k == "qu":
            if cur:
                subs.append(cur)
                cur = []
            q = it[1]
            pts = [q.ul, q.ur, q.lr, q.ll, q.ul]
            subs.append([((p * M).x, (p * M).y) for p in pts])
    if cur:
        subs.append(cur)
    return subs


def grey(c):
    return c is not None and len(c) == 3 and abs(c[0] - 0.92) < 0.02 and abs(c[1] - 0.92) < 0.02 and abs(c[2] - 0.92) < 0.02


def white(c):
    return c is not None and len(c) == 3 and min(c) > 0.98


def redraw(page, px_per_pt, min_len_pt=0.0):
    M = page.rotation_matrix
    w = int(page.rect.width * px_per_pt) + 2
    h = int(page.rect.height * px_per_pt) + 2
    img = np.zeros((h, w), np.uint8)
    for g in page.get_drawings():
        subs = flatten(g["items"], M)
        polys = [np.round(np.array(s) * px_per_pt).astype(np.int32) for s in subs if len(s) >= 2]
        if not polys:
            continue
        fill = g.get("fill")
        if fill is not None:
            val = COMMON if grey(fill) else (EMPTY if white(fill) else OTHER)
            closed = [p for p in polys if len(p) >= 3]
            if closed:
                cv2.fillPoly(img, closed, val)
        col = g.get("color")
        if g["type"] in ("s", "fs") and col is not None and len(col) == 3 and sum(col) / 3 < 0.8:
            if min_len_pt > 0:
                total = sum(math.hypot(s2[i + 1][0] - s2[i][0], s2[i + 1][1] - s2[i][1]) for s2 in subs for i in range(len(s2) - 1))
                if total < min_len_pt:
                    continue
            cv2.polylines(img, polys, False, LINE, 1)
    return img


def kind_size_skip(size, unit):
    """Unit labels in tiny type belong to inset details; area labels are always tiny."""
    return size < 3 and unit not in ("RCA", "NLA", "VDA")


def labels(page):
    """Text blocks that look like NAME / UNIT / AREA, plus special areas."""
    M = page.rotation_matrix
    out = []
    lone = []  # blocks that are just a square-footage number
    for b in page.get_text("dict")["blocks"]:
        if b.get("type") != 0:
            continue
        # Work span by span: a unit number can share a line with the previous
        # tenant's name ("JUGO JUICE  N116").
        raw = [(sp["text"].strip(), fitz.Rect(sp["bbox"]) * M, sp["size"]) for l in b["lines"] for sp in l["spans"]]
        raw = [t for t in raw if t[0]]
        lines = [t[0] for t in raw]
        if not raw:
            continue

        def is_unit(l):
            return l in ("RCA", "NLA", "VDA") or (UNIT_RE.match(l) and any(ch.isdigit() for ch in l) and not AREA_RE.match(l))

        idx = [i for i, l in enumerate(lines) if is_unit(l)]
        if not idx:
            if len(lines) == 1 and AREA_RE.match(lines[0]):
                r2 = raw[0][1]
                lone.append((int(lines[0].replace(",", "")), (r2.x0 + r2.x1) / 2, (r2.y0 + r2.y1) / 2))
            continue
        # One block can hold several labels (NAME / UNIT / AREA, NAME / UNIT /
        # AREA ...): split it, and place each label by its own lines.
        start = 0
        for k, i in enumerate(idx):
            unit = lines[i]
            j = i + 1
            area = None
            if j < len(lines) and AREA_RE.match(lines[j]):
                area = int(lines[j].replace(",", ""))
                j += 1
            name = " ".join(lines[start:i]).strip()
            group = raw[start:j]
            start = j
            size = max(t[2] for t in group)
            if kind_size_skip(size, unit):
                continue
            r = group[0][1]
            for t in group[1:]:
                r = r | t[1]
            kind = {"RCA": "common", "NLA": "service", "VDA": "void"}.get(unit, "unit")
            out.append({"name": name, "unit": unit, "area": area, "kind": kind, "x": (r.x0 + r.x1) / 2, "y": (r.y0 + r.y1) / 2})
    # Rotated labels often keep the square footage in its own text block: give
    # each unit without one the nearest unused area figure.
    used = set()
    nums = lone
    for o in out:
        if o["area"] is None and o["kind"] == "unit":
            best = None
            for i, (val, x, y) in enumerate(nums):
                if i in used:
                    continue
                dd = math.hypot(x - o["x"], y - o["y"])
                if dd < 30 and (best is None or dd < best[0]):
                    best = (dd, i, val)
            if best:
                used.add(best[1])
                o["area"] = best[2]
    return out


def contour_polys(mask, ppf, simplify_ft=0.75):
    cs, hier = cv2.findContours(mask.astype(np.uint8), cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    out = []
    if hier is None:
        return out
    for i, c in enumerate(cs):
        if hier[0][i][3] != -1:
            continue  # holes are attached to their parent below
        outer = cv2.approxPolyDP(c, simplify_ft * ppf, True).reshape(-1, 2)
        holes = []
        j = hier[0][i][2]
        while j != -1:
            hole = cv2.approxPolyDP(cs[j], simplify_ft * ppf, True).reshape(-1, 2)
            if cv2.contourArea(cs[j]) > (4 * ppf) ** 2:
                holes.append(hole)
            j = hier[0][j][0]
        if cv2.contourArea(c) > (3 * ppf) ** 2:
            out.append((outer, holes))
    return out


def street_walls(page, pt_per_ft):
    """Wall lines nearest the JAMES / YONGE / QUEEN STREET labels, in page points.
    Returns (queen_x, james_y, yonge_y) or None for any it can't find."""
    M = page.rotation_matrix
    words = [(w[4].upper(), fitz.Rect(w[:4]) * M) for w in page.get_text("words")]

    def label(name):
        rs = [r for t, r in words if t == name]
        return max(rs, key=lambda r: r.width * r.height) if rs else None

    hor, ver = [], []
    for g in page.get_drawings():
        col = g.get("color")
        if col is None or len(col) != 3 or sum(col) / 3 > 0.8:
            continue
        for it in g["items"]:
            if it[0] != "l":
                continue
            a, b = it[1] * M, it[2] * M
            if abs(a.y - b.y) < 0.3 and abs(a.x - b.x) > 20 * pt_per_ft:
                hor.append((round((a.y + b.y) / 2, 1), abs(a.x - b.x), min(a.x, b.x), max(a.x, b.x)))
            elif abs(a.x - b.x) < 0.3 and abs(a.y - b.y) > 20 * pt_per_ft:
                ver.append((round((a.x + b.x) / 2, 1), abs(a.y - b.y), min(a.y, b.y), max(a.y, b.y)))

    def best(lines, lo, hi, outer):
        """The outermost long wall line in [lo, hi]: of the lines carrying at
        least a third of the longest one's length, the one nearest the street
        (outer = "low" or "high" end of the range)."""
        tot = {}
        for pos, length, *_ in lines:
            if lo <= pos <= hi:
                key = round(pos)
                tot[key] = tot.get(key, 0) + length
        if not tot:
            return None
        top = max(tot.values())
        strong = [k for k, v in tot.items() if v >= top / 3]
        k = min(strong) if outer == "low" else max(strong)
        sel = [pos for pos, *_ in lines if abs(pos - k) <= 1]
        return sum(sel) / len(sel)

    j, y, q = label("JAMES"), label("YONGE"), label("QUEEN")
    james = best(hor, j.y1, j.y1 + 30, "low") if j else None
    yonge = best(hor, y.y0 - 30, y.y0, "high") if y else None
    if q and q.height > q.width:  # rotated label: the street runs up the page
        queen = best(ver, q.x1, q.x1 + 40, "low")
    elif q:
        queen = best(ver, q.x1 - 10, q.x1 + 60, "low")
    else:
        queen = None
    return queen, james, yonge


def circulation(page, pt_per_ft):
    """Escalators, stairs and lifts from their plan symbols, in page feet.

    Treads: runs of 8+ parallel, equal-length lines (3-14 ft long) about a foot
    apart. A narrow run (5 ft or less) at least 18 ft long is an escalator; the
    rest are stairs. Lifts: an X (two equal diagonals, 5-14 ft, crossing at their
    midpoints) - the usual elevator-shaft symbol."""
    M = page.rotation_matrix
    segs = []
    for g in page.get_drawings():
        col = g.get("color")
        if col is None or len(col) != 3 or sum(col) / 3 > 0.8:
            continue
        for it in g["items"]:
            if it[0] == "l":
                a, b = it[1] * M, it[2] * M
                ax, ay, bx, by = a.x / pt_per_ft, a.y / pt_per_ft, b.x / pt_per_ft, b.y / pt_per_ft
                L = math.hypot(bx - ax, by - ay)
                if 3 <= L <= 14:
                    ang = math.degrees(math.atan2(by - ay, bx - ax)) % 180
                    segs.append((ax, ay, bx, by, L, ang))
    out = []
    # Treads.
    groups = {}
    for sg in segs:
        groups.setdefault((round(sg[5] / 3), round(sg[4] * 2)), []).append(sg)
    for (_, _), group in groups.items():
        if len(group) < 8:
            continue
        ang = math.radians(sum(g[5] for g in group) / len(group))
        dx, dy = math.cos(ang), math.sin(ang)  # along the tread
        nx, ny = -dy, dx  # across treads (direction of travel)
        pts = [((g[0] + g[2]) / 2, (g[1] + g[3]) / 2) for g in group]
        along = [p[0] * dx + p[1] * dy for p in pts]
        across = [p[0] * nx + p[1] * ny for p in pts]
        order = sorted(range(len(group)), key=lambda i: (round(along[i]), across[i]))
        used = set()
        for i in order:
            if i in used:
                continue
            run = [i]
            used.add(i)
            while True:
                last = run[-1]
                nxt = None
                for j in order:
                    if j in used or abs(along[j] - along[last]) > 0.5:
                        continue
                    gap = across[j] - across[last]
                    if 0.6 <= gap <= 2.2 and (nxt is None or gap < across[nxt] - across[last]):
                        nxt = j
                if nxt is None:
                    break
                run.append(nxt)
                used.add(nxt)
            if len(run) >= 8:
                width = sum(group[k][4] for k in run) / len(run)
                length = across[run[-1]] - across[run[0]]
                cxa = sum(along[k] for k in run) / len(run)
                cxc = (across[run[0]] + across[run[-1]]) / 2
                cx, cy = cxa * dx + cxc * nx, cxa * dy + cxc * ny
                kind = "escalator" if width <= 5.0 and length >= 18 else "stairs"
                out.append({"kind": kind, "cx": cx, "cy": cy, "width": round(width, 1), "length": round(length, 1),
                            "dir": [round(nx, 3), round(ny, 3)], "treads": len(run)})
    # Escalator hatching breaks where text or step outlines cross it: join runs
    # that line up end to end (same direction, same line, gap up to 6 ft), and
    # drop exact duplicates, then classify again by the joined length.
    runs = [o for o in out]
    merged = True
    while merged:
        merged = False
        for i in range(len(runs)):
            for j in range(i + 1, len(runs)):
                a, b = runs[i], runs[j]
                if abs(a["dir"][0] * b["dir"][0] + a["dir"][1] * b["dir"][1]) < 0.98:
                    continue
                dx, dy = b["cx"] - a["cx"], b["cy"] - a["cy"]
                along = dx * a["dir"][0] + dy * a["dir"][1]
                lateral = abs(-dx * a["dir"][1] + dy * a["dir"][0])
                if lateral > 1.5 or abs(a["width"] - b["width"]) > 1.5:
                    continue
                gap = abs(along) - (a["length"] + b["length"]) / 2
                if gap > 6:
                    continue
                # Join: span both runs along the shared direction.
                ends = []
                for r in (a, b):
                    for sgn in (-1, 1):
                        ends.append((r["cx"] + sgn * r["length"] / 2 * a["dir"][0], r["cy"] + sgn * r["length"] / 2 * a["dir"][1]))
                proj = [e[0] * a["dir"][0] + e[1] * a["dir"][1] for e in ends]
                lo, hi = ends[proj.index(min(proj))], ends[proj.index(max(proj))]
                length = max(proj) - min(proj)
                runs[i] = {"kind": "stairs", "cx": (lo[0] + hi[0]) / 2, "cy": (lo[1] + hi[1]) / 2, "width": max(a["width"], b["width"]),
                           "length": round(length, 1), "dir": a["dir"], "treads": (a.get("treads") or 0) + (b.get("treads") or 0)}
                runs.pop(j)
                merged = True
                break
            if merged:
                break
    for r in runs:
        r["kind"] = "escalator" if r["width"] <= 8.0 and r["length"] >= 18 else "stairs"
    out = runs

    # Lifts: two crossing diagonals of equal length.
    diag = [sg for sg in segs if 5 <= sg[4] <= 14 and 20 < sg[5] % 90 < 70]
    seen = []
    for i in range(len(diag)):
        a = diag[i]
        ma = ((a[0] + a[2]) / 2, (a[1] + a[3]) / 2)
        for j in range(i + 1, len(diag)):
            b = diag[j]
            if abs(a[4] - b[4]) > 0.6 or abs(((a[5] - b[5]) % 180) - 90) > 35:
                continue
            mb = ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
            if math.hypot(ma[0] - mb[0], ma[1] - mb[1]) > 0.5:
                continue
            xs = [a[0], a[2], b[0], b[2]]
            ys = [a[1], a[3], b[1], b[3]]
            w_, h_ = max(xs) - min(xs), max(ys) - min(ys)
            if not (4 <= w_ <= 12 and 4 <= h_ <= 12):
                continue
            c = (ma[0], ma[1])
            if any(math.hypot(c[0] - q[0], c[1] - q[1]) < 3 for q in seen):
                continue
            seen.append(c)
            out.append({"kind": "lift", "cx": c[0], "cy": c[1], "width": round(w_, 1), "length": round(h_, 1), "dir": [1, 0]})
    return out


def grid_features(page, pt_per_ft):
    """Column symbols (small circles and squares), in page feet."""
    M = page.rotation_matrix
    out = []
    for g in page.get_drawings():
        its = g["items"]
        r = g["rect"] * M
        wft, hft = r.width / pt_per_ft, r.height / pt_per_ft
        circle = len(its) >= 4 and all(i[0] == "c" for i in its) and 1.8 < wft < 3.8
        square = len(its) == 1 and its[0][0] == "re" and 1.5 < wft < 3.5
        if (circle or square) and abs(wft - hft) < 0.3:
            out.append(((r.x0 + r.x1) / 2 / pt_per_ft, (r.y0 + r.y1) / 2 / pt_per_ft))
    return np.unique(np.round(np.array(out), 1), axis=0)


def match_columns(a, b):
    """Translation (feet) that lays column set a onto column set b. Columns sit on a
    regular grid, so votes are close; the best-scoring offset is checked
    separately (concourse escalators land under the Level 1 escalators)."""
    from collections import Counter
    votes = Counter()
    for p in a:
        for t in np.round(b - p).astype(int):
            votes[tuple(t)] += 1
    best = None
    for t, _ in votes.most_common(60):
        t = np.array(t, float)
        score = sum(1 for p in a if np.linalg.norm(b - (p + t), axis=1).min() < 1.2)
        if best is None or score > best[0]:
            best = (score, t)
    return best[1], best[0], len(a)


def run(pdf_path):
    os.makedirs(OUT, exist_ok=True)
    doc = fitz.open(pdf_path)
    report = []
    ref = {}
    for level, pi in LEVELS.items():
        page = doc[pi]
        pt_per_ft = scale_bar(page) * SCALE_FIX.get(level, 1.0)
        ppt = RES / pt_per_ft  # raster px per pt
        img = redraw(page, ppt, MIN_STROKE_FT * pt_per_ft)
        h, w = img.shape
        # Close 1-px gaps where hairlines meet at angles so floods don't leak.
        lines = (img == LINE).astype(np.uint8)
        lines = cv2.dilate(lines, np.ones((2, 2), np.uint8))
        free = ((img == EMPTY) & (lines == 0)).astype(np.uint8)

        # Outside: open floor connected to the page edge. Doors and storefronts
        # leave gaps in the outer walls, so gaps up to 6 ft are closed first; the
        # outside region is then grown back to the walls and cut out of the floor
        # before the floor is split into faces.
        k = int(6 * RES) | 1
        closed = (free == 1) & (cv2.dilate(lines, np.ones((k, k), np.uint8)) == 0)
        n2, comp2 = cv2.connectedComponents(closed.astype(np.uint8), connectivity=4)
        border2 = set(int(i) for i in np.unique(np.concatenate([comp2[0], comp2[-1], comp2[:, 0], comp2[:, -1]]))) - {0}
        outside_px = np.isin(comp2, list(border2))
        outside_px = cv2.dilate(outside_px.astype(np.uint8), np.ones((k + 2, k + 2), np.uint8)).astype(bool) & (img != COMMON)
        free = (free.astype(bool) & ~outside_px).astype(np.uint8)
        n, comp = cv2.connectedComponents(free, connectivity=4)
        border = {0}
        outside = outside_px

        labs = labels(page)
        units, specials, misses = [], [], []
        Mrot = page.rotation_matrix
        segments = []
        for g in page.get_drawings():
            col = g.get("color")
            if col is None or len(col) != 3 or sum(col) / 3 > 0.8:
                continue
            for it in g["items"]:
                if it[0] == "l":
                    a2, b2 = it[1] * Mrot, it[2] * Mrot
                    segments.append((a2.x, a2.y, b2.x, b2.y))
        segments = np.array(segments) if segments else np.zeros((0, 4))

        def leader_end(lab):
            """Far end of a leader line starting at the label (page points), or None."""
            x, y = lab["x"], lab["y"]
            best = None
            for x1, y1, x2, y2 in segments:
                for (ax, ay, bx, by) in ((x1, y1, x2, y2), (x2, y2, x1, y1)):
                    near = math.hypot(ax - x, ay - y)
                    length = math.hypot(bx - ax, by - ay)
                    if near < 14 and length > 8 and (best is None or length > best[0]):
                        best = (length, bx, by)
            return None if best is None else (best[1], best[2])

        # Faces: open regions between lines. Measure each and find which faces
        # touch across a single line (shared border length in pixels).
        face_area = np.bincount(comp.ravel(), minlength=n).astype(float) / (RES * RES)
        is_out = np.zeros(n, bool)
        is_out[list(border - {0})] = True
        adj = {}
        line_px = (free == 0)
        for dy, dx in ((0, 3), (3, 0), (2, 2), (2, -2)):
            a = comp[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)]
            b = comp[max(0, dy):, max(0, dx):][:a.shape[0], :a.shape[1]]
            mid = line_px[max(0, -dy) + dy // 2:, max(0, -dx) + dx // 2:][:a.shape[0], :a.shape[1]]
            sel = (a != b) & (a > 0) & (b > 0) & mid
            pa, pb = a[sel], b[sel]
            keys = np.minimum(pa, pb).astype(np.int64) * (n + 1) + np.maximum(pa, pb)
            uk, cnt = np.unique(keys, return_counts=True)
            for k, c in zip(uk, cnt):
                i, j = int(k // (n + 1)), int(k % (n + 1))
                adj.setdefault(i, {})[j] = adj.get(i, {}).get(j, 0) + int(c)
                adj.setdefault(j, {})[i] = adj.get(j, {}).get(i, 0) + int(c)

        def candidates(lab, max_rad, taken=()):
            """Faces near the label: (face, distance in px)."""
            sx, sy = int(lab["x"] * ppt), int(lab["y"] * ppt)
            if not (0 <= sx < w and 0 <= sy < h):
                return []
            for rad in [min(12, max_rad)] + list(range(13, max_rad)):
                y0, x0 = max(0, sy - rad), max(0, sx - rad)
                win = comp[y0:sy + rad + 1, x0:sx + rad + 1]
                ids = [int(i) for i in np.unique(win) if i != 0 and not is_out[i] and int(i) not in taken]
                if ids:
                    out = []
                    for i in ids:
                        ys, xs = np.nonzero(win == i)
                        out.append((i, float(np.min(np.hypot(ys + y0 - sy, xs + x0 - sx)))))
                    return out
            return []

        # Pick each label's starting face, smallest units first: the free face
        # near the label whose size best fits the printed area (a small shop
        # beside a big one takes its own small face, not the neighbour's).
        seeds = {}
        taken_faces = set()
        order = sorted(labs, key=lambda l: (l["kind"] != "unit", l["area"] or 1e9))
        for lab in order:
            cands = candidates(lab, 40 if lab["kind"] == "unit" else 4, taken_faces)
            target = lab["area"] or None
            if target:
                # A face several times the unit's size belongs to something else
                # (a neighbour, or an atrium void beside a kiosk's label).
                cands = [c for c in cands if face_area[c[0]] <= target * 3]
            if not cands:
                misses.append((lab, "no open floor at label"))
                continue

            def cost(c):
                fa = max(face_area[c[0]], 1)
                fit = abs(math.log(fa / target)) if target else -math.log(fa)
                if target and fa > target * 1.15:
                    fit += 1.0  # a face bigger than the whole unit is a neighbour's
                return fit + c[1] / (6 * RES)

            f = min(cands, key=cost)[0]
            if target and face_area[f] < target * 0.05 and lab["kind"] == "unit":
                # The label points at its unit with a leader line: follow it.
                end = leader_end(lab)
                moved = None
                if end:
                    probe = dict(lab, x=end[0], y=end[1])
                    near = [c for c in candidates(probe, 10, taken_faces) if face_area[c[0]] <= target * 3]
                    near = [c for c in near if face_area[c[0]] >= target * 0.05]
                    if near:
                        moved = min(near, key=cost)[0]
                if moved is None:
                    misses.append((lab, "label outside its unit (leader line)"))
                    continue
                f = moved
                lab["leader"] = True
            seeds[id(lab)] = f
            taken_faces.add(f)
        owner = {f: k for k, f in seeds.items()}
        assigned = {}  # face -> label key

        # Grow units from their label face toward the printed area, biggest units
        # first; never take a face that holds another label.
        for lab in sorted([l for l in labs if id(l) in seeds], key=lambda l: -(l["area"] or 0)):
            key = id(lab)
            start = seeds[key]
            if start in assigned:
                misses.append((lab, "label face already taken"))
                continue
            target = lab["area"] or face_area[start]
            got = {start}
            total = face_area[start]
            assigned[start] = key
            frontier = dict(adj.get(start, {}))
            while total < target * 0.97 and frontier:
                # Prefer the neighbour sharing the longest border with the region.
                cand = sorted(frontier.items(), key=lambda kv: -kv[1])
                picked = None
                for f, _ in cand:
                    if f in assigned or is_out[f] or (f in owner and owner[f] != key):
                        frontier.pop(f, None)
                        continue
                    if total + face_area[f] > target * 1.08 and face_area[f] > 40:
                        frontier.pop(f, None)
                        continue
                    picked = f
                    break
                if picked is None:
                    break
                frontier.pop(picked)
                got.add(picked)
                assigned[picked] = key
                total += face_area[picked]
                for g2, c in adj.get(picked, {}).items():
                    if g2 not in got:
                        frontier[g2] = frontier.get(g2, 0) + c
            region = np.isin(comp, list(got))
            region = cv2.morphologyEx(region.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool)
            rec = dict(lab)
            rec["traced"] = int(round(float(region.sum()) / (RES * RES)))
            rec["polys"] = contour_polys(region, RES)
            (units if lab["kind"] == "unit" else specials).append(rec)

        # Kiosks in the corridors have no outline of their own on the plan: place
        # them at their label as a square of the printed area (marked inferred).
        for lab, why in list(misses):
            if lab["kind"] == "unit" and lab["area"] and lab["area"] <= 400 and why == "no open floor at label":
                side = math.sqrt(lab["area"])
                cx, cy = lab["x"] * ppt, lab["y"] * ppt
                half = side * RES / 2
                sq_poly = np.array([[cx - half, cy - half], [cx + half, cy - half], [cx + half, cy + half], [cx - half, cy + half]]).astype(np.int32)
                rec = dict(lab)
                rec["traced"] = int(lab["area"])
                rec["polys"] = [(sq_poly, [])]
                rec["inferred"] = "kiosk: placed at its label, size from printed area"
                units.append(rec)
                misses.remove((lab, why))

        # Openings: open floor that no unit claimed and that sits inside the
        # corridors (most of its border is common area) - atrium voids and
        # escalator wells, whether or not the plan labelled them.
        commonmask = (img == COMMON)
        ring = cv2.dilate(commonmask.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
        openings = []
        for f in range(1, n):
            if is_out[f] or f in assigned or face_area[f] < 150:
                continue
            m = comp == f
            edge = cv2.dilate(m.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool) & ~m
            if edge.sum() == 0:
                continue
            share = (edge & ring).sum() / edge.sum()
            if share > 0.6:
                openings.append(m)
        void_mask = np.zeros_like(free, bool)
        for m in openings:
            void_mask |= m
        for sp in specials:
            if sp["kind"] == "void":
                for o, hs in sp["polys"]:
                    cv2.fillPoly(void_mask.view(np.uint8), [o.reshape(-1, 1, 2)], 1)
        voids = contour_polys(void_mask, RES, 1.0)

        common = contour_polys((img == COMMON) & ~outside, RES, 1.0)
        footprint = contour_polys(~outside & (img != OTHER), RES, 1.5)

        # Registration: the main block's Yonge wall (largest v) and Queen wall
        # (smallest u) from the footprint's dominant straight edges.
        fp = ~outside
        cols = np.nonzero(fp.any(axis=0))[0]
        # Yonge wall: the most common bottom edge across columns.
        # The long Yonge and James walls are the most common bottom and top edges
        # of the footprint (histogram peaks, so the Bay and Dundas buildings, which
        # stick out further, don't pull them).
        bottoms = np.array([np.nonzero(fp[:, c])[0].max() for c in cols])
        tops = np.array([np.nonzero(fp[:, c])[0].min() for c in cols])

        def peak(vals):
            hist = np.bincount(vals // 4)
            k = int(np.argmax(hist))
            sel = vals[(vals // 4 >= k - 1) & (vals // 4 <= k + 1)]
            return int(np.median(sel))

        yonge_px = peak(bottoms)
        james_px = peak(tops)
        sq, sj, sy = street_walls(page, pt_per_ft)
        if level == "L1":
            ref = {"cols": grid_features(page, pt_per_ft), "queen_ft": None, "yonge_ft": None}
        concourse_note = None
        if level != "L1" and ref:
            t, score, total = match_columns(grid_features(page, pt_per_ft), ref["cols"])
            if level in REG_FIX:
                t, score, total = np.array(REG_FIX[level], float), 0, 0
            # page-ft here + t = L1 page-ft; express Queen/Yonge walls in this raster.
            sq = (ref["queen_ft"] - t[0]) * pt_per_ft
            sy = (ref["yonge_ft"] - t[1]) * pt_per_ft
            sj = (ref["james_ft"] - t[1]) * pt_per_ft
            concourse_note = f"registered to Level 1 by column grid: offset {t[0]:.0f},{t[1]:.0f} ft, {score}/{total} columns match"
            if level in REG_FIX:
                concourse_note = f"registered by a unit shared with another level (REG_FIX): offset {t[0]:.0f},{t[1]:.0f} ft"
            reg_t, reg_score = t, score
        if sj is not None:
            james_px = int(round(sj * ppt))
        if sy is not None:
            yonge_px = int(round(sy * ppt))
        # Queen wall: first column where the footprint spans most of the Yonge-James depth.
        span = (yonge_px - james_px)
        full = [c for c in cols if fp[james_px + span // 4: yonge_px - span // 4, c].mean() > 0.9]
        queen_px = min(full) if full else int(cols.min())
        if sq is not None:
            queen_px = int(round(sq * ppt))

        if level == "L1":
            ref["queen_ft"] = queen_px / RES
            ref["yonge_ft"] = yonge_px / RES
            ref["james_ft"] = james_px / RES

        def to_plan(p):
            return [round(float(p[0] - queen_px) / RES, 1), round(float(yonge_px - p[1]) / RES, 1)]

        def pack(polys):
            return [{"outer": [to_plan(p) for p in o], "holes": [[to_plan(p) for p in hh] for hh in hs]} for o, hs in polys]

        circ = []
        raw_circ = circulation(page, pt_per_ft)
        # Escalator banks: floor openings with tread hatching inside them. Every
        # escalator between two floors sits in an opening of the upper floor.
        banks = []
        # Treads split an opening into pieces, so group openings within 6 ft.
        grow = int(6 * RES) | 1
        grouped = cv2.dilate(void_mask.astype(np.uint8), np.ones((grow, grow), np.uint8))
        ng, gl = cv2.connectedComponents(grouped, connectivity=8)
        for gi in range(1, ng):
            ys_, xs_ = np.nonzero(gl == gi)
            hull = cv2.convexHull(np.stack([xs_, ys_], 1).astype(np.int32))
            inside = []
            for c in raw_circ:
                if c["kind"] == "lift":
                    continue
                pt = (float(c["cx"] * RES), float(c["cy"] * RES))
                if cv2.pointPolygonTest(hull, pt, False) >= 0:
                    inside.append(c)
            treads = sum(c.get("treads") or 0 for c in inside)
            if treads < 12:
                continue
            # Direction of travel: the direction carrying the most treads.
            dirs = {}
            for c in inside:
                key = (round(abs(c["dir"][0]), 1), round(abs(c["dir"][1]), 1), 1 if c["dir"][0] * c["dir"][1] >= 0 else -1)
                dirs[key] = dirs.get(key, 0) + (c.get("treads") or 0)
            dk = max(dirs, key=dirs.get)
            d0 = np.array([dk[0], dk[1] * dk[2]], float)
            d0 /= np.linalg.norm(d0)
            n0 = np.array([-d0[1], d0[0]])
            ends = []
            for c in inside:
                cvec = np.array([c["cx"], c["cy"]])
                for sgn in (-1, 1):
                    e = cvec + sgn * c["length"] / 2 * d0
                    for wsg in (-1, 1):
                        ends.append(e + wsg * c["width"] / 2 * n0)
            ends = np.array(ends)
            a = ends @ d0
            b = ends @ n0
            centre = d0 * (a.min() + a.max()) / 2 + n0 * (b.min() + b.max()) / 2
            u, v = to_plan((centre[0] * RES, centre[1] * RES))
            banks.append({"u": u, "v": v, "dir": [round(float(d0[0]), 3), round(float(-d0[1]), 3)],
                          "length": round(float(a.max() - a.min()), 1), "width": round(float(b.max() - b.min()), 1), "treads": int(treads)})
        # Escalators marked with UP / DN text (the Yonge St escalator hall, some
        # court escalators): one bank per cluster of labels within 25 ft.
        marks = []
        for wd in page.get_text("words"):
            t = wd[4].upper().strip(".")
            if t in ("UP", "DN", "DOWN"):
                r = fitz.Rect(wd[:4]) * page.rotation_matrix
                marks.append(((r.x0 + r.x1) / 2 / pt_per_ft, (r.y0 + r.y1) / 2 / pt_per_ft))
        clusters = []
        for m in marks:
            for cl in clusters:
                if any(math.hypot(m[0] - q[0], m[1] - q[1]) < 25 for q in cl):
                    cl.append(m)
                    break
            else:
                clusters.append([m])
        for cl in clusters:
            cx = sum(q[0] for q in cl) / len(cl)
            cy = sum(q[1] for q in cl) / len(cl)
            u, v = to_plan((cx * RES, cy * RES))
            if any(math.hypot(u - b["u"], v - b["v"]) < 45 for b in banks):
                continue
            near = [c for c in raw_circ if c["kind"] != "lift" and math.hypot(c["cx"] - cx, c["cy"] - cy) < 30]
            d0 = max(near, key=lambda c: c.get("treads") or 0)["dir"] if near else [1, 0]
            banks.append({"u": u, "v": v, "dir": [round(d0[0], 3), round(-d0[1], 3)], "length": None, "width": None,
                          "treads": None, "source": "UP/DN labels"})
        for bk in banks:
            bk.setdefault("source", "tread hatching in a floor opening")

        for c in raw_circ:
            px, py = c["cx"] * RES, c["cy"] * RES  # page feet -> raster px
            ix, iy = int(px), int(py)
            inside = 0 <= iy < h and 0 <= ix < w and not outside[iy, ix]
            if not inside:
                continue
            public = 0 <= iy < h and 0 <= ix < w and (img[max(0, iy - 6):iy + 7, max(0, ix - 6):ix + 7] == COMMON).any() or bool(void_mask[iy, ix])
            u, v = to_plan((px, py))
            circ.append({"kind": c["kind"], "u": u, "v": v, "width": c["width"], "length": c["length"],
                         "dir": [c["dir"][0], -c["dir"][1]], "public": bool(public), "treads": c.get("treads")})

        data = {
            "level": level,
            "page": pi + 1,
            "ptPerFt": round(pt_per_ft, 4),
            "registration": {"queenPx": int(queen_px), "yongePx": int(yonge_px), "jamesPx": int(james_px), "widthFt": round(float(span) / RES, 1),
                             "method": "street walls" if level == "L1" else ("shared unit" if level in REG_FIX else "column grid to Level 1"), "note": concourse_note},
            "footprint": pack(footprint),
            "common": pack(common),
            "voids": pack(voids),
            "circulation": circ,
            "escalatorBanks": banks,
            "units": [{"unit": u["unit"], "name": u["name"], "area": u["area"], "traced": u["traced"], "polys": pack(u["polys"]),
                       "inferred": u.get("inferred"), "leader": u.get("leader", False)} for u in units],
            "specials": [{"kind": s["kind"], "unit": s["unit"], "area": s["area"], "traced": s["traced"], "polys": pack(s["polys"])} for s in specials],
            "misses": [{"unit": m[0]["unit"], "name": m[0]["name"], "why": m[1]} for m in misses],
        }
        with open(os.path.join(OUT, level + ".json"), "w") as f:
            json.dump(data, f)

        # Overlay image: PDF render underneath, traced shapes on top.
        pix = page.get_pixmap(matrix=fitz.Matrix(ppt, ppt).prerotate(0))
        base = np.frombuffer(pix.samples, np.uint8).reshape(pix.h, pix.w, pix.n)[:, :, :3].copy()
        if base.shape[:2] != img.shape:
            base = cv2.resize(base, (w, h))
        over = base.copy()
        rng = np.random.default_rng(7)
        for u in units:
            ok = u["area"] and abs(u["traced"] - u["area"]) / u["area"] <= 0.10
            col = tuple(int(c) for c in (rng.integers(60, 200), 200 if ok else 60, 90 if ok else 230))
            for o, hs in u["polys"]:
                cv2.fillPoly(over, [o.reshape(-1, 1, 2)], col)
        for o, hs in common:
            cv2.polylines(over, [o.reshape(-1, 1, 2)], True, (230, 140, 0), 2)
        for o, hs in voids:
            cv2.fillPoly(over, [o.reshape(-1, 1, 2)], (255, 90, 200))
        for bk in banks:
            if bk["length"] is None:
                cv2.drawMarker(over, (int(bk["u"] * RES + queen_px), int(yonge_px - bk["v"] * RES)), (200, 0, 0), cv2.MARKER_SQUARE, 30, 3)
                continue
            cxp, cyp = bk["u"] * RES + queen_px, yonge_px - bk["v"] * RES
            d = np.array([bk["dir"][0], -bk["dir"][1]])
            nrm = np.array([-d[1], d[0]])
            corners = [np.array([cxp, cyp]) + sa * bk["length"] / 2 * RES * d + sb * bk["width"] / 2 * RES * nrm for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            cv2.polylines(over, [np.array(corners, np.int32).reshape(-1, 1, 2)], True, (200, 0, 0), 3)
        for c in circ:
            px = c["u"] * RES + queen_px
            py = yonge_px - c["v"] * RES
            col = {"escalator": (220, 0, 0), "stairs": (240, 140, 0), "lift": (0, 90, 230)}[c["kind"]]
            cv2.circle(over, (int(px), int(py)), int(4 * RES), col, -1 if c["public"] else 2)
        out_img = cv2.addWeighted(base, 0.45, over, 0.55, 0)
        cv2.line(out_img, (queen_px, 0), (queen_px, h), (0, 0, 255), 2)
        cv2.line(out_img, (0, yonge_px), (w, yonge_px), (0, 0, 255), 2)
        cv2.line(out_img, (0, james_px), (w, james_px), (255, 0, 0), 2)
        cv2.imwrite(os.path.join(OUT, level + ".png"), cv2.cvtColor(out_img, cv2.COLOR_RGB2BGR))

        good = sum(1 for u in units if u["area"] and abs(u["traced"] - u["area"]) / u["area"] <= 0.10)
        report.append(f"== {level} (page {pi + 1}) scale {pt_per_ft:.4f} pt/ft, building {span / RES:.0f} ft James-Yonge")
        if concourse_note:
            report.append("   " + concourse_note)
        report.append(f"   escalator banks (openings with treads): {len(banks)}: " + "; ".join(f"u{b['u']:.0f} v{b['v']:.0f} ({b['source']})" for b in banks))
        report.append("   circulation: " + ", ".join(f"{k} {sum(1 for c in circ if c['kind'] == k)} ({sum(1 for c in circ if c['kind'] == k and c['public'])} public)" for k in ("escalator", "stairs", "lift")))
        report.append(f"   units traced {len(units)}, within 10% of printed area {good}, specials {len(specials)}, misses {len(misses)}")
        for u in sorted(units, key=lambda u: -(u["area"] or 0)):
            err = (u["traced"] - u["area"]) / u["area"] * 100 if u["area"] else float("nan")
            tag = "  [kiosk, inferred]" if u.get("inferred") else ("  [via leader line]" if u.get("leader") else "")
            report.append(f"   {u['unit']:<8} {u['name'][:28]:<28} printed {u['area'] or '-':>7}  traced {u['traced']:>7}  {err:+6.1f}%{tag}")
        for m in misses:
            report.append(f"   MISS {m[0]['unit']:<8} {m[0]['name'][:28]:<28} {m[1]}")
    with open(os.path.join(OUT, "report.txt"), "w") as f:
        f.write("\n".join(report))
    print("\n".join(l for l in report if l.startswith("==") or l.startswith("   units")))


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/TECON20_LEASING.pdf"))
