"""Turn the extracted Eaton Centre plans (tools/eaton/out/*.json) into compact Lua
data for the Roblox builder: src/server/World/EatonCentre/Data/<level>.lua

Everything stays in plan feet (u = north from the Queen St wall, v = west from
the Yonge St wall); the builder converts to studs. Per level:
  slabs     floor rectangles {u0, v0, u1, v1} (footprint minus floor openings)
  walls     {u0, v0, u1, v1, kind}: 1 unit wall, 2 storefront, 3 exterior, 4 entrance
  rails     floor-opening edges {u0, v0, u1, v1}
  units     {unit, name, area, u, v, inferred}
  lifts / escalators / stairs (public only)
Shared: columns {u, v}, vault strips {u0, u1, v0, v1}.

Usage: python tools/eaton/to_lua.py <leasing pdf>
"""
import json
import math
import os
import sys

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import extract as X  # noqa: E402

OUT = os.path.join(HERE, "out")
DEST = os.path.join(HERE, "..", "..", "src", "server", "World", "EatonCentre", "Data")

U0, U1 = -8, 1422  # plan clip: Queen St wall to Dundas St (with a margin for facade steps)
V0, V1 = -12, 326  # Yonge St wall to James St (the Yonge facade steps out ~4 ft)
G = 1.0  # raster grid, feet


def raster(polys, holes_ok=True):
    m = np.zeros((int((V1 - V0) / G) + 1, int((U1 - U0) / G) + 1), np.uint8)
    for p in polys:
        o = np.array([[(x - U0) / G, (V1 - y) / G] for x, y in p["outer"]], np.int32)
        cv2.fillPoly(m, [o], 1)
        if holes_ok:
            for hh in p["holes"]:
                hp = np.array([[(x - U0) / G, (V1 - y) / G] for x, y in hh], np.int32)
                cv2.fillPoly(m, [hp], 0)
    return m.astype(bool)


def at(mask, u, v):
    c = int(round((u - U0) / G))
    r = int(round((V1 - v) / G))
    if 0 <= r < mask.shape[0] and 0 <= c < mask.shape[1]:
        return bool(mask[r, c])
    return False


def rects(mask, cell=2):
    """Greedy rectangles covering mask (downsampled to `cell` ft)."""
    h, w = mask.shape
    hh, ww = h // cell, w // cell
    m = mask[: hh * cell, : ww * cell].reshape(hh, cell, ww, cell).mean(axis=(1, 3)) >= 0.5
    used = np.zeros_like(m)
    out = []
    for r in range(hh):
        c = 0
        while c < ww:
            if not m[r, c] or used[r, c]:
                c += 1
                continue
            c1 = c
            while c1 + 1 < ww and m[r, c1 + 1] and not used[r, c1 + 1]:
                c1 += 1
            r1 = r
            while r1 + 1 < hh and m[r1 + 1, c:c1 + 1].all() and not used[r1 + 1, c:c1 + 1].any():
                r1 += 1
            used[r:r1 + 1, c:c1 + 1] = True
            # back to plan feet: column -> u, row -> v (row 0 is v = V1)
            u0 = U0 + c * cell * G
            u1 = U0 + (c1 + 1) * cell * G
            va = V1 - (r1 + 1) * cell * G
            vb = V1 - r * cell * G
            out.append((round(u0, 1), round(va, 1), round(u1, 1), round(vb, 1)))
            c = c1 + 1
    return out


def edges(poly):
    pts = poly["outer"]
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n)) / 2
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1.0:
            continue
        # outward normal (u, v axes): for CCW polygons the outside is to the right
        dx, dy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        nx, ny = (dy, -dx) if area > 0 else (-dy, dx)
        yield a, b, L, (nx, ny)


def inside_clip(u, v):
    return U0 <= u <= U1 and V0 <= v <= V1


def lua_value(x):
    if x is None:
        return "nil"
    if isinstance(x, bool):
        return "true" if x else "false"
    if isinstance(x, (int, float)):
        return repr(round(float(x), 1)).rstrip("0").rstrip(".") if isinstance(x, float) else str(x)
    if isinstance(x, str):
        return json.dumps(x, ensure_ascii=False)
    if isinstance(x, dict):
        return "{ " + ", ".join(f"{k} = {lua_value(v)}" for k, v in x.items()) + " }"
    if isinstance(x, (list, tuple)):
        return "{ " + ", ".join(lua_value(v) for v in x) + " }"
    raise TypeError(type(x))


def entrance_arrows(page, level):
    """The plans mark street entrances with small black arrows just outside the
    walls. Returns their positions (plan feet), one per cluster."""
    M = page.rotation_matrix
    s = level["ptPerFt"]
    q, y = level["registration"]["queenPx"] / X.RES, level["registration"]["yongePx"] / X.RES
    pts = []
    for g in page.get_drawings():
        f = g.get("fill")
        if f is None or max(f) > 0.1:
            continue
        r = g["rect"] * M
        w, h = r.width / s, r.height / s
        if not (3 < max(w, h) < 16):
            continue
        u = (r.x0 + r.x1) / 2 / s - q
        v = y - (r.y0 + r.y1) / 2 / s
        if -45 < u < 1460 and -45 < v < 365 and not (5 < u < 1405 and 5 < v < 315):
            pts.append((u, v))
    clusters = []
    for p in pts:
        for c in clusters:
            if math.hypot(c[0][0] - p[0], c[0][1] - p[1]) < 15:
                c.append(p)
                break
        else:
            clusters.append([p])
    return [(sum(a for a, _ in c) / len(c), sum(b for _, b in c) / len(c)) for c in clusters]


def labelled(page, level, words):
    """Positions (plan feet) of words like WASHROOM on a level's sheet."""
    import pymupdf as fitz
    M = page.rotation_matrix
    s = level["ptPerFt"]
    q, y = level["registration"]["queenPx"] / X.RES, level["registration"]["yongePx"] / X.RES
    out = []
    for w in page.get_text("words"):
        if w[4].upper().strip(".,") in words:
            r = fitz.Rect(w[:4]) * M
            u = (r.x0 + r.x1) / 2 / s - q
            v = y - (r.y0 + r.y1) / 2 / s
            if inside_clip(u, v) and not any(math.hypot(u - a, v - b) < 15 for a, b in out):
                out.append((round(u, 1), round(v, 1)))
    return out


def interior_box(poly, front):
    """The largest rectangle inside a unit, measured from its storefront: in the
    front's frame (across the front, and inward from it). Returns
    {cu, cv, au, av, width, depth}: the centre of the rectangle's front edge, the
    direction along the front, and the size in feet; None if there's no room."""
    m = raster([poly])
    fu0, fv0, fu1, fv1, nx, ny = front
    au, av = fu1 - fu0, fv1 - fv0
    L = math.hypot(au, av)
    if L < 4:
        return None
    au, av = au / L, av / L
    iu, iv = -nx, -ny  # inward
    mu, mv = (fu0 + fu1) / 2, (fv0 + fv1) / 2
    lefts, rights = [], []
    for d in range(1, 200):
        cu, cv = mu + iu * d, mv + iv * d
        if not at(m, cu, cv):
            break
        lo = 0
        while lo > -300 and at(m, cu + au * (lo - 1), cv + av * (lo - 1)):
            lo -= 1
        hi = 0
        while hi < 300 and at(m, cu + au * (hi + 1), cv + av * (hi + 1)):
            hi += 1
        lefts.append(lo)
        rights.append(hi)
    best = None
    left, right = -1e9, 1e9
    for k in range(len(lefts)):
        left, right = max(left, lefts[k]), min(right, rights[k])
        width, depth = right - left, k + 1
        if width >= 6 and depth >= 6 and (best is None or width * depth > best[0]):
            best = (width * depth, left, right, depth)
    if not best:
        return None
    _, left, right, depth = best
    c = (left + right) / 2
    return {"cu": round(mu + au * c + iu * 0.8, 1), "cv": round(mv + av * c + iv * 0.8, 1), "au": round(au, 3), "av": round(av, 3),
            "width": round(right - left - 1, 1), "depth": round(depth - 1.5, 1)}


def main(pdf):
    os.makedirs(DEST, exist_ok=True)
    import pymupdf as fitz

    doc = fitz.open(pdf)
    levels = {k: json.load(open(os.path.join(OUT, k + ".json"))) for k in ("L1", "L2", "L3", "L4", "concourse")}
    # Where the concourse lies under Level 1, Level 1's floor openings are real
    # (escalators and light wells down to the Urban Eatery); elsewhere Level 1
    # sits on solid ground.
    under = raster(levels["concourse"]["footprint"])

    # Level 4's sheet has a heavy border frame, so its traced footprint is the
    # whole clip window. The sheet shows Level 4 across the building's full width
    # from u 429 north (parking along Yonge, then Indigo, Zara, Simons, BMO,
    # Uniqlo), so it takes Level 3's outline there, except the strip along Yonge
    # at the corner (u > 1276, v < 22) where the drum and the anchor's block are
    # three storeys tall.
    def l4_footprint():
        m = raster(levels["L3"]["footprint"]).copy()
        uu = U0 + (np.arange(m.shape[1]) + 0.5) * G
        vv = V1 - (np.arange(m.shape[0]) + 0.5) * G
        m[:, uu < 429] = False
        m[np.ix_(vv < 22, uu > 1276)] = False
        return m
    L4_FOOT = l4_footprint()

    # The dig: how far the three levels below the street (concourse, Levels 1-2)
    # reach. Street-level caps cover it wherever Level 3 doesn't (entrance courts,
    # recesses, the sidewalk strip past the walls).
    below = raster(levels["L1"]["footprint"]) | raster(levels["L2"]["footprint"])
    c0 = raster(levels["concourse"]["footprint"]).copy()
    c0[int(V1 / G) + 1:, :] = False  # the concourse stops at the Yonge wall
    below |= c0
    rows, cols = np.nonzero(below)
    dig = [round(U0 + cols.min() * G, 1), round(max(0.0, V1 - (rows.max() + 1) * G), 1),
           round(U0 + (cols.max() + 1) * G, 1), round(V1 - rows.min() * G, 1)]
    foot3 = raster(levels["L3"]["footprint"])
    box = np.zeros_like(foot3)
    r_lo, r_hi = int((V1 - dig[3]) / G), int((V1 - dig[1]) / G)
    c_lo, c_hi = int((dig[0] - U0) / G), int((dig[2] - U0) / G)
    box[r_lo:r_hi, c_lo:c_hi] = True
    cap_mask = box & ~foot3
    caps = rects(cap_mask)

    summary = []
    summary.append(f"dig {dig}, {len(caps)} street caps")

    # Columns: from Level 1 (they run through every floor), kept where they
    # stand in public space on some level (corridors, courts, openings).
    l1 = levels["L1"]
    page = doc[l1["page"] - 1]
    cols = X.grid_features(page, l1["ptPerFt"])
    q, y = l1["registration"]["queenPx"] / X.RES, l1["registration"]["yongePx"] / X.RES
    public = np.zeros_like(raster([]))
    for d in levels.values():
        public |= raster(d["common"]) | raster(d["voids"])
    foot1 = raster(l1["footprint"])
    columns = []
    for cx, cy in cols:
        u, v = cx - q, y - cy
        if inside_clip(u, v) and at(foot1, u, v) and at(public, u, v):
            columns.append((round(u, 1), round(v, 1)))

    arrows = {name: entrance_arrows(doc[d["page"] - 1], d) for name, d in levels.items()}

    # Escalators (src/server/World/EatonCentre/Data/Circulation.lua, read off the
    # plans). On the plans each escalator is its own outlined shape inside a floor
    # opening, which the trace counts as floor; here the upper floor is cut open
    # over each escalator (except over its low end, where there's headroom), with
    # balustrades along the cut, and the foot gets a patch of floor if it lands
    # over an opening. The top end is the drawn end that leads on to corridor on
    # the upper floor; the run is long enough for a 30-degree climb at our storey
    # heights (Level 1 0.75, Levels 2-3 every 20 studs, concourse -17).
    import re as _re
    circ_src = open(os.path.join(DEST, "Circulation.lua"), encoding="utf-8").read()
    banks = []
    for m in _re.finditer(r"\{ from = (\d), to = (\d), u = ([-\d.]+), v = ([-\d.]+), axis = \{ ([-\d.]+), ([-\d.]+) \}, length = ([-\d.]+)", circ_src):
        banks.append(dict(zip(("from", "to", "u", "v", "au", "av", "length"), (int(m.group(1)), int(m.group(2)), *map(float, m.group(3, 4, 5, 6, 7))))))
    level_names = {0: "concourse", 1: "L1", 2: "L2", 3: "L3", 4: "L4"}
    level_y = {0: -54.75, 1: -37.0, 2: -17.0, 3: 0.75, 4: 20.75}
    STUDS_PER_FT = 1.0  # TorontoLayout.EATON_SCALE (true scale)
    PAIR_HALF_FT = 13 / 2 / STUDS_PER_FT + 1  # an up/down pair is 13 studs wide, plus a margin
    HEADROOM_FT = 20  # floor can stay over the lowest 20 ft of the run
    esc_cuts = {k: [] for k in levels}  # level -> oriented boxes to open
    esc_patches = {k: [] for k in levels}  # level -> oriented boxes to fill
    esc_rails = {k: [] for k in levels}
    esc_paths = {k: [] for k in levels}  # level -> the escalator's whole footprint
    esc_list = []

    def box_mask(cu, cv, au, av, half_along, half_across):
        m = np.zeros_like(raster([]))
        pts = []
        for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            u = cu + sa * half_along * au - sb * half_across * av
            v = cv + sa * half_along * av + sb * half_across * au
            pts.append([(u - U0) / G, (V1 - v) / G])
        cv2.fillPoly(m.view(np.uint8), [np.array(pts, np.int32)], 1)
        return m

    for bk in banks:
        nrm = math.hypot(bk["au"], bk["av"])
        au, av = bk["au"] / nrm, bk["av"] / nrm
        upper = levels[level_names[bk["to"]]]
        up_common = raster(upper["common"])
        up_foot = raster(upper["footprint"])
        rise = level_y[bk["to"]] - level_y[bk["from"]]
        run = max(bk["length"], rise / math.tan(math.radians(30)) / STUDS_PER_FT)
        best = None
        for sgn in (1, -1):
            eu, ev = bk["u"] + sgn * au * bk["length"] / 2, bk["v"] + sgn * av * bk["length"] / 2
            # How much corridor lies just beyond this end on the upper floor?
            score = sum(1 for d in range(2, 14, 2) if at(up_common, eu + sgn * au * d, ev + sgn * av * d))
            if best is None or score > best[0]:
                best = (score, sgn, eu, ev)
        _, sgn, tu, tv = best
        du, dv = sgn * au, sgn * av
        bu, bv = tu - du * run, tv - dv * run
        esc_list.append({"from": bk["from"], "to": bk["to"], "bottom": [round(bu, 1), round(bv, 1)], "top": [round(tu, 1), round(tv, 1)]})
        # Open the upper floor over the escalator, from the top end back to where
        # the steps are low enough to pass under it.
        cut_len = max(10.0, run - HEADROOM_FT)
        cu, cv = tu - du * cut_len / 2, tv - dv * cut_len / 2
        esc_cuts[level_names[bk["to"]]].append(box_mask(cu, cv, du, dv, cut_len / 2, PAIR_HALF_FT))
        # Balustrades: both long sides and the low end of the cut (not the top end).
        corners = {}
        for name_, sa, sb in (("bl", -1, -1), ("tl", 1, -1), ("tr", 1, 1), ("br", -1, 1)):
            corners[name_] = (cu + sa * cut_len / 2 * du - sb * PAIR_HALF_FT * dv, cv + sa * cut_len / 2 * dv + sb * PAIR_HALF_FT * du)
        for a_, b_ in (("bl", "tl"), ("br", "tr"), ("bl", "br")):
            esc_rails[level_names[bk["to"]]].append((corners[a_], corners[b_]))
        # Keep walls and columns out of the escalator's path on both floors.
        path = box_mask((tu + bu) / 2, (tv + bv) / 2, du, dv, run / 2 + 4, PAIR_HALF_FT - 1)
        esc_paths[level_names[bk["to"]]].append(path)
        esc_paths[level_names[bk["from"]]].append(path)
        # A floor patch under the foot (and the comb plate) on the lower floor.
        esc_patches[level_names[bk["from"]]].append(box_mask(bu - du * 4, bv - dv * 4, du, dv, 8, PAIR_HALF_FT))

    # Columns that would stand in an escalator's way are left out.
    columns = [c for c in columns if not any(at(pm, *c) for lst in esc_paths.values() for pm in lst)]

    for name, d in levels.items():
        foot = raster(d["footprint"]) if name != "L4" else L4_FOOT.copy()
        if name == "concourse":
            # The concourse plan runs on under the Yonge St roadway; the building's
            # concourse stops at the Yonge wall (v = 0), clear of the subway tunnel.
            foot[int(V1 / G) + 1:, :] = False
        common = raster(d["common"])
        voids = raster(d["voids"])
        if name == "L1":
            voids = voids & under
        slab = foot & ~voids if name != "concourse" else foot.copy()
        for pm in esc_patches[name]:
            slab |= pm & foot
        for cm in esc_cuts[name]:
            slab &= ~cm
        slabs = rects(slab)

        walls = []
        # Exterior: the outline of the footprint as rasterised and clipped to the
        # block (so walls always sit on the real building edge, and anything the
        # plan draws past the block line is closed off at the boundary). Entrances
        # on Level 1 where the plan puts its entrance arrows.
        solid_foot = cv2.morphologyEx(foot.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
        outline = []
        cs, _ = cv2.findContours(solid_foot, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for c in cs:
            if cv2.contourArea(c) < 400:
                continue
            poly = cv2.approxPolyDP(c, 1.5 / G, True).reshape(-1, 2)
            outline.append({"outer": [[U0 + x * G, V1 - y * G] for x, y in poly], "holes": []})
        for p in outline:
            for a, b, L, (nx, ny) in edges(p):
                steps = max(1, int(L / 2))
                flags = []
                for k in range(steps + 1):
                    t = k / steps
                    u, v = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                    # An entrance: corridor just inside the wall, next to one of the
                    # plan's entrance arrows.
                    inside_common = at(common, u - nx * 4, v - ny * 4)
                    near = any(math.hypot(u - au, v - av) < 35 for au, av in arrows[name])
                    # Level 3 (street): also where its corridor meets a street cap
                    # that the plan's arrow leads into (an entrance court).
                    court = (name == "L3" and at(cap_mask, u + nx * 4, v + ny * 4)
                             and any(math.hypot(u - au, v - av) < 80 for au, av in arrows[name]))
                    flags.append(name in ("L1", "L2", "L3") and inside_common and (near or court))
                # Door runs as t-intervals, widened to at least 16 ft (8 studs).
                doors, k = [], 0
                while k <= steps:
                    if flags[k]:
                        k0 = k
                        while k + 1 <= steps and flags[k + 1]:
                            k += 1
                        t0, t1 = k0 / steps, k / steps
                        need = 16 / L
                        if t1 - t0 < need:
                            mid = (t0 + t1) / 2
                            t0, t1 = max(0.0, mid - need / 2), min(1.0, mid + need / 2)
                        doors.append((t0, t1))
                    k += 1
                cuts, last = [], 0.0
                for t0, t1 in doors:
                    if t0 > last:
                        cuts.append((last, t0, 3))
                    cuts.append((max(t0, last), t1, 4))
                    last = t1
                if last < 1:
                    cuts.append((last, 1.0, 3))
                for t0, t1, kind in cuts:
                    ua, va = a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0
                    ub, vb = a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1
                    if math.hypot(ub - ua, vb - va) >= 1:
                        walls.append((round(ua, 1), round(va, 1), round(ub, 1), round(vb, 1), kind))
        # Doors narrower than 6 ft are service doors: keep them as wall.
        walls = [w if not (w[4] == 4 and math.hypot(w[2] - w[0], w[3] - w[1]) < 6) else (*w[:4], 3) for w in walls]

        units = []
        for un in d["units"]:
            for p in un["polys"]:
                pts = p["outer"]
                cu = sum(x for x, _ in pts) / len(pts)
                cv = sum(y for _, y in pts) / len(pts)
                if not inside_clip(cu, cv):
                    continue
                rec = {"unit": un["unit"], "name": un["name"], "area": un["area"], "u": round(cu, 1), "v": round(cv, 1),
                       "umin": round(min(x for x, _ in pts), 1), "umax": round(max(x for x, _ in pts), 1),
                       "vmin": round(min(y for _, y in pts), 1), "vmax": round(max(y for _, y in pts), 1),
                       "inferred": bool(un.get("inferred")), "front": None}
                units.append(rec)
                rec["_poly"] = p
                best_front = 0
                for a, b, L, (nx, ny) in edges(p):
                    mu, mv = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                    ou, ov = mu + nx * 2.5, mv + ny * 2.5
                    if not at(foot, ou, ov):
                        continue  # the exterior wall covers it
                    kind = 2 if (at(common, ou, ov) or at(voids, ou, ov)) else 1
                    # How much open floor lies in front of this edge (up to 30 ft)?
                    # Shops don't front narrow service passages: under 10 ft it's a wall.
                    depth = 0
                    if kind == 2:
                        for dd in range(3, 33):
                            if at(common, mu + nx * dd, mv + ny * dd) or at(voids, mu + nx * dd, mv + ny * dd):
                                depth = dd
                            else:
                                break
                        if depth < 10:
                            kind = 1
                    score = L * min(1.0, depth / 20.0)
                    if kind == 2 and score > best_front:
                        best_front = score
                        rec["front"] = [round(a[0], 1), round(a[1], 1), round(b[0], 1), round(b[1], 1), round(nx, 2), round(ny, 2)]
                    # Pull unit walls in a little so neighbours' walls don't overlap.
                    pull = 0.4
                    w_ = (round(a[0] - nx * pull, 1), round(a[1] - ny * pull, 1), round(b[0] - nx * pull, 1), round(b[1] - ny * pull, 1), kind)
                    if kind == 2:
                        # Storefronts carry their unit, and which way is out (to the corridor).
                        w_ = w_ + (un["unit"], round(nx, 2), round(ny, 2))
                    walls.append(w_)

        def in_path(w):
            mu, mv = (w[0] + w[2]) / 2, (w[1] + w[3]) / 2
            return any(at(pm, mu, mv) for pm in esc_paths[name])
        walls = [w for w in walls if not in_path(w)]

        # Furnishing room inside each shop (for the interior templates).
        for rec in units:
            poly = rec.pop("_poly", None)
            rec["box"] = interior_box(poly, rec["front"]) if poly and rec.get("front") else None

        rails = []
        if name != "concourse":
            for p in d["voids"]:
                for a, b, L, _ in edges(p):
                    mid_u, mid_v = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                    if any(at(cm, mid_u, mid_v) for cm in esc_cuts[name] + esc_patches[name]):
                        continue
                    if inside_clip(*a) and inside_clip(*b) and (name != "L1" or (at(under, *a) and at(under, *b))):
                        rails.append((round(a[0], 1), round(a[1], 1), round(b[0], 1), round(b[1], 1)))

        for (ra, rb) in esc_rails[name]:
            # Only where there's floor beside the cut to fall from.
            mid = ((ra[0] + rb[0]) / 2, (ra[1] + rb[1]) / 2)
            rails.append((round(ra[0], 1), round(ra[1], 1), round(rb[0], 1), round(rb[1], 1)))
        lifts = [{"u": c["u"], "v": c["v"], "w": c["width"], "d": c["length"]} for c in d["circulation"]
                 if c["kind"] == "lift" and c["public"] and inside_clip(c["u"], c["v"])]
        escalators = [{"u": b["u"], "v": b["v"], "dir": b["dir"], "length": b["length"], "width": b["width"], "source": b["source"]}
                      for b in d.get("escalatorBanks", []) if inside_clip(b["u"], b["v"])]

        body = [
            "-- Generated by tools/eaton/to_lua.py from the CF Toronto Eaton Centre leasing",
            f"-- plan ({name}, page {d['page']}). Plan feet: u = north from the Queen St wall,",
            "-- v = west from the Yonge St wall. Do not edit by hand; re-run the tool.",
            "return {",
            f"\tlevel = {lua_value(name)},",
            "\tslabs = {",
        ]
        body += [f"\t\t{lua_value(r)}," for r in slabs]
        body += ["\t},", "\twalls = {"]
        body += [f"\t\t{lua_value(w)}," for w in walls]
        body += ["\t},", "\trails = {"]
        body += [f"\t\t{lua_value(r)}," for r in rails]
        body += ["\t},", "\tunits = {"]
        body += [f"\t\t{lua_value(u)}," for u in units]
        body += ["\t},", f"\tentranceArrows = {lua_value([[round(a, 1), round(b, 1)] for a, b in arrows[name]])},"]
        washrooms = [list(p) for p in labelled(doc[d["page"] - 1], d, ("WASHROOM", "WASHROOMS"))]
        # Downlights over the walkways (a 28 ft grid, at least 4 ft from any wall
        # or opening), and benches with planters where a walkway is at least 28 ft
        # wide (so they never pinch it).
        walk = (common & ~voids).astype(np.uint8)
        inner = cv2.erode(walk, np.ones((int(7 / G), int(7 / G)), np.uint8)).astype(bool)
        wide = cv2.erode(walk, np.ones((int(21 / G), int(21 / G)), np.uint8)).astype(bool)

        def spaced(mask, step, gap):
            pts = []
            for uu in range(int(U0) + 4, int(U1), step):
                for vv in range(int(V0) + 4, int(V1), step):
                    if at(mask, uu, vv) and all((uu - a) ** 2 + (vv - b) ** 2 >= gap * gap for a, b in pts):
                        pts.append([uu, vv])
            return pts

        lights = spaced(inner, 6, 22)
        seats = spaced(wide, 8, 45)
        body += [f"\twashrooms = {lua_value(washrooms)},"]
        body += [f"\tlights = {lua_value(lights)},", f"\tbenches = {lua_value(seats)},"]
        body += [f"\tlifts = {lua_value(lifts)},", f"\tescalators = {lua_value(escalators)},", "}", ""]
        with open(os.path.join(DEST, name + ".lua"), "w", encoding="utf-8") as f:
            f.write("\n".join(body))
        summary.append(f"{name}: {len(slabs)} slabs, {len(walls)} walls ({sum(1 for w in walls if w[4] == 4)} entrance pieces), "
                       f"{len(rails)} rail edges, {len(units)} units, {len(lifts)} lifts, {len(escalators)} escalator banks")

    # Galleria skylight: the roof-level void, as strips along u.
    vault = []
    l5 = os.path.join(OUT, "L5.json")
    if os.path.exists(l5):
        d5 = json.load(open(l5))
        sky = raster([v for v in d5["voids"] if abs(v["outer"][0][0]) < 2000])
        sky &= raster(levels["L3"]["footprint"])
        # Level 3's public area (walkways and openings): the real vault spans the
        # galleria from storefront line to storefront line, not just the opening
        # traced on the roof plan, so each slice is widened across it.
        public3 = raster(levels["L3"]["common"]) | raster(levels["L3"]["voids"])
        foot4 = L4_FOOT
        void4 = raster(levels["L4"]["voids"])
        WIDEN_MAX = 34  # ft per side, so side corridors don't pull the vault off
        step = 8
        for u in range(int(U0), int(U1), step):
            c0, c1 = int((u - U0) / G), int((u + step - U0) / G)
            cols_any = sky[:, c0:c1].any(axis=1)
            rows = np.nonzero(cols_any)[0]
            if len(rows) == 0:
                continue
            # the widest continuous run in this slice
            runs, start = [], rows[0]
            for i in range(1, len(rows) + 1):
                if i == len(rows) or rows[i] != rows[i - 1] + 1:
                    runs.append((start, rows[i - 1]))
                    if i < len(rows):
                        start = rows[i]
            r0, r1 = max(runs, key=lambda r: r[1] - r[0])
            if (r1 - r0) * G < 12:
                continue
            # Grow outwards while the whole slice is public on Level 3.
            full = public3[:, c0:c1].all(axis=1)
            lim = int(WIDEN_MAX / G)
            a = r0
            while a - 1 >= 0 and r0 - (a - 1) <= lim and full[a - 1]:
                a -= 1
            b = r1
            while b + 1 < len(full) and (b + 1) - r1 <= lim and full[b + 1]:
                b += 1
            # Stop a little short of the storefronts (the clerestory sits on them).
            pad = int(1 / G)
            r0 = min(r0, a + pad) if a < r0 else r0
            r1 = max(r1, b - pad) if b > r1 else r1
            hi = 0
            if foot4[r0:r1 + 1, c0:c1].any():
                # Level 4 here: fit the vault to Level 4's opening across this slice.
                hi = 1
                open4 = void4[:, c0:c1].all(axis=1)
                runs4, k = [], 0
                while k < len(open4):
                    if open4[k]:
                        j = k
                        while j + 1 < len(open4) and open4[j + 1]:
                            j += 1
                        runs4.append((k, j))
                        k = j + 1
                    else:
                        k += 1
                over = [(a_, b_) for a_, b_ in runs4 if b_ >= r0 and a_ <= r1 and (b_ - a_) * G >= 12]
                if over:
                    r0, r1 = max(over, key=lambda r: min(r[1], r1) - max(r[0], r0))
            vault.append((u, u + step, round(V1 - (r1 + 1) * G, 1), round(V1 - r0 * G, 1), hi))
    # Roof: Level 3's footprint, solid except over the skylight (vault) and over
    # Level 3's floor openings (flat glass where the vault doesn't reach).
    foot3 = raster(levels["L3"]["footprint"])
    vmask = np.zeros_like(foot3)
    for u0, u1, va, vb, _ in vault:
        c0, c1 = int((u0 - U0) / G), int((u1 - U0) / G)
        r0, r1 = int((V1 - vb) / G), int((V1 - va) / G)
        vmask[r0:r1 + 1, c0:c1] = True
    open3 = raster(levels["L3"]["voids"])
    foot4 = L4_FOOT & foot3
    open4 = raster(levels["L4"]["voids"])
    # Level 3's roof where Level 4 doesn't stand on it; Level 4's own roof above.
    roof = rects(foot3 & ~foot4 & ~vmask & ~open3)
    glass = rects(open3 & ~foot4 & ~vmask & foot3)
    roof4 = rects(foot4 & ~vmask & ~open4)
    glass4 = rects(open4 & ~vmask & foot4)
    summary.append(f"roof: {len(roof)} + {len(roof4)} (Level 4) solid pieces, {len(glass)} + {len(glass4)} flat skylights")

    shared = ["-- Generated by tools/eaton/to_lua.py. Columns (from Level 1, public spaces only)",
              "-- and the galleria skylight strips {u0, u1, v0, v1, hi}, in plan feet (hi = 1:",
              "-- Level 4 runs alongside, the vault covers its opening and springs above it).",
              "-- roof/skylights sit on Level 3, roof4/skylights4 on Level 4.",
              "return {", "\tcolumns = {"]
    shared += [f"\t\t{lua_value(c)}," for c in columns]
    shared += ["\t},", "\tvault = {"]
    shared += [f"\t\t{lua_value(v)}," for v in vault]
    shared += ["\t},", "\troof = {"]
    shared += [f"\t\t{lua_value(r)}," for r in roof]
    shared += ["\t},", "\tescalators = {"]
    shared += [f"\t\t{lua_value(e)}," for e in esc_list]
    shared += ["\t},", "\tskylights = {"]
    shared += [f"\t\t{lua_value(r)}," for r in glass]
    shared += ["\t},", f"\tdig = {lua_value(dig)},", "\tcaps = {"]
    shared += [f"\t\t{lua_value(r)}," for r in caps]
    shared += ["\t},", "\troof4 = {"]
    shared += [f"\t\t{lua_value(r)}," for r in roof4]
    shared += ["\t},", "\tskylights4 = {"]
    shared += [f"\t\t{lua_value(r)}," for r in glass4]
    shared += ["\t},", "}", ""]
    with open(os.path.join(DEST, "Shared.lua"), "w", encoding="utf-8") as f:
        f.write("\n".join(shared))
    summary.append(f"shared: {len(columns)} columns, {len(vault)} vault strips")
    print("\n".join(summary))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/TECON20_LEASING.pdf"))
