"""Tenant registry for the Eaton Centre reconstruction: one row per traced unit
per level, from the leasing-plan extraction (out/<level>.json), the generated
level data (src/.../EatonCentre/Data/<level>.lua: storefront edges) and the
tenant catalogue (src/shared/Catalog/EatonTenants.lua: categories, in-game
names). Writes docs/eaton/tenant_registry.csv and .json.

Fields: level, unit, tenant (as printed on the 2023 plan), in-game name,
category, status, printed and traced area (and the error), footprint bounding
box and centroid in plan feet (u north of Queen St, v west of Yonge St), the
storefront edge the build uses (and which way it faces), adjacent units (sharing
a wall, within 1.5 ft), interior status, and whether the level is built yet."""
import csv, json, os, re
from shapely.geometry import Polygon
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
ROOT = os.path.join(HERE, "..", "..")
DATA = os.path.join(ROOT, "src", "server", "World", "EatonCentre", "Data")
DEST = os.path.join(ROOT, "docs", "eaton")
LEVELS = [("concourse", 0, True), ("L1", 1, True), ("L2", 2, True), ("L2B", 2.5, False), ("L3", 3, True), ("L4", 4, False)]
NUM = r"-?[\d.]+"

cat = {}
src = open(os.path.join(ROOT, "src", "shared", "Catalog", "EatonTenants.lua"), encoding="utf-8").read()
for m in re.finditer(r'\{ unit = "([^"]+)", level = (\d), area = (\d+), status = "(\w+)", category = "(\w+)", name = (nil|"[^"]*"), real = (nil|"[^"]*")', src):
    unit, lvl, _, status, category, name, real = m.groups()
    cat[(int(lvl), unit)] = {"status": status, "category": category, "name": None if name == "nil" else name.strip('"')}

def fronts(level):
    path = os.path.join(DATA, level + ".lua")
    if not os.path.exists(path):
        return {}
    out = {}
    for m in re.finditer(r'unit = "([^"]+)".*?front = (nil|\{ (' + NUM + '), (' + NUM + '), (' + NUM + '), (' + NUM + '), (' + NUM + '), (' + NUM + r') \})', open(path, encoding="utf-8").read()):
        if m.group(2) != "nil":
            a = list(map(float, m.groups()[2:8]))
            out[m.group(1)] = a
    return out

FACING = {(0, 1): "west", (0, -1): "east", (1, 0): "north", (-1, 0): "south"}
def facing(nx, ny):
    best = max(FACING, key=lambda k: k[0] * nx + k[1] * ny)
    return FACING[best]

rows = []
for level, idx, built in LEVELS:
    d = json.load(open(os.path.join(OUT, level + ".json")))
    fr = fronts(level)
    polys = {}
    for u in d["units"]:
        ps = [Polygon(p["outer"], p.get("holes") or []).buffer(0) for p in u.get("polys", []) if len(p["outer"]) >= 3]
        if ps:
            polys.setdefault(u["unit"], []).append((u, unary_union(ps)))
    for unit, entries in polys.items():
        for u, g in entries:
            others = [o for o, lst in polys.items() if o != unit for _, og in lst if og.distance(g) < 1.5]
            minx, miny, maxx, maxy = g.bounds
            c = cat.get((int(idx), unit), {})
            status = c.get("status") or ("vacant" if u["name"] in ("VACANT", "") else "open")
            f = fr.get(unit)
            interior = ("not built (level pending)" if not built else
                        {"open": "fitted out", "vacant": "hoarding", "back": "back of house"}.get(status, status))
            rows.append({
                "level": level, "unit": unit, "tenant_2023": u["name"] or "",
                "game_name": c.get("name") or "", "category": c.get("category") or "",
                "status": status, "printed_sqft": u["area"], "traced_sqft": u["traced"],
                "area_error_pct": round(100 * (u["traced"] - u["area"]) / u["area"], 1) if u["area"] else None,
                "u_min": round(minx, 1), "u_max": round(maxx, 1), "v_min": round(miny, 1), "v_max": round(maxy, 1),
                "centroid_u": round(g.centroid.x, 1), "centroid_v": round(g.centroid.y, 1),
                "storefront": "" if not f else f"({f[0]:g},{f[1]:g})-({f[2]:g},{f[3]:g}) facing {facing(f[4], f[5])}",
                "adjacent": " ".join(sorted(set(others))),
                "interior": interior, "inferred": bool(u.get("inferred")), "built": built,
            })

os.makedirs(DEST, exist_ok=True)
keys = list(rows[0].keys())
with open(os.path.join(DEST, "tenant_registry.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=keys)
    w.writeheader()
    w.writerows(rows)
with open(os.path.join(DEST, "tenant_registry.json"), "w", encoding="utf-8") as fh:
    fh.write("[\n" + ",\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n]\n")
print(len(rows), "rows;", {lv: sum(1 for r in rows if r["level"] == lv) for lv, _, _ in LEVELS})
