"""Tenant registry for the rebuilt Eaton Centre.

For every traced unit: its unit number and level (from the leasing plans), the
real tenant as a reference (the current CF directory where it lists the unit,
otherwise the plan's tenant), a category, and the ORIGINAL store name shown in
the game. Real brands are never shown in game: names are made up from the
category's word lists, deterministically per unit.

Inputs: tools/eaton/out/<level>.json, tools/eaton/directory.txt (the CF store
directory: one slug per store, ending in its unit number).
Output: src/shared/Catalog/EatonTenants.lua

Usage: python tools/eaton/tenants.py
"""
import hashlib
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
DEST = os.path.join(HERE, "..", "..", "src", "shared", "Catalog", "EatonTenants.lua")

LEVELS = {"concourse": 0, "L1": 1, "L2": 2, "L3": 3, "L4": 4}

# Units the current directory lists under a new number: the plan unit -> the
# directory's unit. Simons took over the former Nordstrom floor (Y002A on the
# 2023 plans, Y005A in the current directory).
RENUMBERED = {"Y002A": "Y005A"}

# Our own businesses already placed in the mall (Services/Work).
OURS = {"D106": ("Grind Coffee", "cafe"), "N132A": ("Metro Threads", "fashion")}

# Category by keywords in the real tenant's name (first match wins).
CATEGORIES = [
    ("services", ["BANK", "TD CANADA", "BMO", "CALFOREX", "CURRENCY", "DENTAL", "GUEST SERVICES", "CAR CARE", "KLINIK", "REPAIR",
                  "ALTERATION", "BACK RUB", "CADILLAC FAIRVIEW", "GDI SERVICES", "WASHROOM", "STRATEGIC HEALTH", "ATM", "WIRELESS FIX"]),
    ("optical", ["LENSCRAFTERS", "OPTICAL", "ZEISS", "BONLOOK", "WARBY", "BAILEY NELSON", "SUNGLASS", "RAY-BAN", "RAY BAN"]),
    ("pharmacy", ["SHOPPERS DRUG", "NUTRITION", "HEAL WELLNESS", "SAJE", "FRESH FRESH"]),
    ("cafe", ["COFFEE", "STARBUCKS", "TEA", "BUBBLE", "JUICE", "CAFE", "CAFÉ", "GONG CHA", "HEYTEA", "MACHI", "NESPRESSO", "BAKERY",
              "PASTRY", "COOKIE", "CHOCOLAT", "LINDT", "PURDY", "LADERACH", "LÄDERACH", "YOGEN", "BASKIN", "KERNELS", "POPCORN", "SECOND CUP",
              "REFUEL", "KANDY", "CREPE", "GELATO", "PRETZEL", "MOCHI", "TANGHULU", "FRESHLY SQUEEZED", "ARABICA", "CRAIG", "SAINT-GERMAIN",
              "SAINT GERMAIN", "DANISH", "WETZEL", "ROCKY MOUNTAIN", "FRUZ", "FROSHBERG", "SAD NUGGIE"]),
    ("food", ["FOOD", "KITCHEN", "EXPRESS", "SUSHI", "BURRITO", "PIZZA", "SBARRO", "MCDONALD", "KFC", "KENTUCKY", "CHICKEN", "GRILL",
              "NOODLE", "RAMEN", "THAI", "GREEK", "A & W", "A&W", "SUBWAY", "FRIES", "TIM HORTON", "OSMOW", "KORYO", "BBQ", "CHICK-FIL-A",
              "AMAYA", "VILLA MADINA", "MUCHO", "TERIYAKI", "BURGER", "POULET", "PATTIES", "CANTINA", "DELI", "HUMMUS", "CHIPPERIE",
              "JOEY", "MILESTONES", "EATALY", "MERCATTO", "LIBRETTO", "CURRYOSITY", "SAUCE", "CROSSBAR", "AKASHIRO", "SANSOTEI", "HERBIVORE",
              "SMOKE", "BOURBON", "SZECHUAN", "SHANGHAI", "RICHTREE", "MARKET", "FOOD HALL", "CORNICHON", "CAPTAIN NEON", "TANGLE", "IQ",
              "RESTAURANT", "EATERY", "PETIT"]),
    ("electronics", ["APPLE", "BEST BUY", "ROGERS", "BELL", "TELUS", "FIDO", "KOODO", "FREEDOM", "VIRGIN", "LUCKY", "WIRELESS", "MOBILE",
                     "GADGETS", "THE SOURCE", "MICROSOFT", "FUTURE TECH", "TBOOTH", "XPRESS", "SHOWCASE", "BATTERIES", "CANADIAN TIRE"]),
    ("beauty", ["SEPHORA", "MAC", "BODY SHOP", "BATH & BODY", "LUSH", "AVEDA", "KIEHL", "JO MALONE", "AESOP", "OCCITANE", "MAKEUP",
                "NYX", "COSMETICS", "FACESHOP", "TRADE SECRETS", "BOTANIC"]),
    ("jewellery", ["PANDORA", "PEOPLES", "SWAROVSKI", "CLAIRE", "LOVISA", "CHOW TAI FOOK", "GEMLET", "SWATCH", "FOSSIL", "JEWEL",
                   "TUMI", "COACH", "MICHAEL KORS", "KATE SPADE", "TED BAKER", "LACO SAC", "HERSCHEL", "BENTLEY", "CALL IT SPRING", "ALDO ACCESSORIES"]),
    ("footwear", ["FOOT LOCKER", "SOFTMOC", "SOFT MOC", "ALDO", "LITTLE BURGUNDY", "STEVE MADDEN", "SKECHERS", "ECCO", "GEOX", "JOURNEYS",
                  "DOLCE VITA", "HOKA", "COLE HAAN", "SPRING", "KIDS FOOT"]),
    ("sports", ["SPORT CHEK", "NIKE", "ADIDAS", "UNDER ARMOUR", "LULULEMON", "ALO YOGA", "ATHLETA", "NORTH FACE", "ARC'TERYX", "ARCTERYX",
                "CANADA GOOSE", "JD SPORTS", "ZUMIEZ", "CHAMPS", "MOOSE KNUCKLES", "ROOTS", "LIDS", "MACKAGE"]),
    ("books", ["INDIGO", "LEGO", "TOYS", "MINISO", "POP MART", "CONSPIRACY", "TREEHOUSE", "FLYING TIGER", "GAMESTOP", "EB GAMES",
               "CANADIAN NATURALIST", "TOKYO SMOKE", "TRADING", "CHRISTMAS", "SANTA", "HAPPY", "OFFLINE"]),
    ("department", ["HUDSON", "SAKS", "NORDSTROM", "SIMONS", "WINNERS", "MARKS"]),
]
BACK_OF_HOUSE = re.compile(r"^(STO|RR|BK|NLA|RCA|VDA|TEC|SL|LOT|P10|G10|G20|G30|P30|S22|O30)")
VACANT_WORDS = ("VACANT", "LEASED", "UNKNOWN", "")

# Original names, made up per category (adjective/place + noun). Kept odd on
# purpose so they don't land on real brands.
WORDS = {
    "fashion": (["Ravine", "Kensal", "Lakeshore", "Corktown", "Northwind", "Juniper", "Halden", "Carrow", "Wexley", "Marlow", "Ossian",
                 "Tamsin", "Verity", "Pellam", "Linden", "Brisa", "Harlowe", "Quillon", "Arden", "Sorrel"],
                ["Threadworks", "Atelier", "Outfitters", "Clothing Co.", "Wardrobe", "Studio", "Denim", "& Thread", "Tailors", "Collective"]),
    "footwear": (["Cobble", "Strider", "Laceway", "Heelhouse", "Kerbstone", "Trailmark", "Solemate", "Paceline", "Bootcamp", "Stepwell"],
                 ["Shoes", "Footwear", "Boot Co.", "Sneakers", "Shoe Bar"]),
    "sports": (["Peakline", "Ridgeback", "Sprintway", "Northbound", "Altitude", "Fieldhouse", "Tidal", "Summit", "Huron", "Fastbreak"],
               ["Sport", "Athletics", "Outdoor", "Performance", "Active"]),
    "electronics": (["Circuit", "Pixelry", "Signal", "Voltage", "Byteline", "Nimbus", "Kilowatt", "Lumen", "Relay", "Quanta"],
                    ["Mobile", "Tech", "Electronics", "Wireless", "Labs"]),
    "beauty": (["Petal", "Lustre", "Bloomwell", "Silk & Sage", "Glowhaus", "Velour", "Amberly", "Rosewater", "Dewdrop", "Saffira"],
               ["Beauty", "Apothecary", "Cosmetics", "Skin Bar", "Botanicals"]),
    "jewellery": (["Aurelia", "Gilded", "Facet", "Opaline", "Carat & Co", "Lumiere", "Brilliant", "Argent", "Halo", "Garnet"],
                  ["Jewellers", "Accessories", "Atelier", "Leather", "Watches"]),
    "food": (["Yonge Street", "Dundas", "Queen's", "Harbourfront", "Spadina", "Danforth", "Bloor", "Kensington", "Ossington", "Roncy"],
             ["Noodle Bar", "Grill", "Kitchen", "Dumplings", "Shawarma", "Burger Co.", "Pizza", "Tacos", "Bowl", "Fried Chicken", "Sushi", "Curry House"]),
    "cafe": (["Ember", "Steamwhistle", "Crema", "Honeycomb", "Saltcellar", "Copperpot", "Maplewood", "Biscotti", "Little Pear", "Sundial"],
             ["Coffee", "Tea House", "Bakery", "Sweets", "Juice Bar", "Creamery"]),
    "optical": (["Clearview", "Focal", "Iris & Co", "Spectra", "Brightline"], ["Optical", "Eyewear", "Vision"]),
    "pharmacy": (["Wellcare", "Corner", "Greenleaf", "Remedy", "Citywell"], ["Pharmacy", "Wellness", "Health"]),
    "books": (["Paper Lantern", "Curio", "Playtime", "Hobbyhorse", "Chapterhouse", "Kite & Key", "Marble Run", "Odds & Ends"],
              ["Books", "Toys", "Games", "Gifts", "Hobbies"]),
    "department": (["Maison", "The Arcade", "Bellwood", "Harrowgate", "Queensway", "Concord"], ["Department Store", "& Co.", "House", "Stores"]),
    "services": (["City", "Downtown", "Metro", "Yonge"], ["Services", "Repair", "Exchange", "Bank"]),
}


def category_for(name):
    n = (name or "").upper()
    for cat, words in CATEGORIES:
        for w in words:
            # Short words must stand alone ("MAC", "TEA"); longer ones may run on
            # ("MCDONALD" in "MCDONALDS").
            tail = r"($|[^A-Z])" if len(w) <= 4 else ""
            if re.search(r"(^|[^A-Z])" + re.escape(w) + tail, n):
                return cat
    return "fashion"


def directory():
    out = {}
    path = os.path.join(HERE, "directory.txt")
    if not os.path.exists(path):
        return out
    for slug in open(path, encoding="utf-8").read().split():
        s = slug[:-2] if slug.endswith("-m") else slug
        unit = s.split("-")[-1].upper()
        name = " ".join(w for w in s.split("-")[:-1] if w).replace("  ", " ")
        name = re.sub(r"\blevel \d\b", "", name).strip().upper()
        out[unit] = name
    return out


NAMED = {}  # unit -> name, so a store on several levels keeps one name


def made_up(cat, unit, taken):
    if unit in NAMED:
        return NAMED[unit]
    first, second = WORDS.get(cat, WORDS["fashion"])
    h = int(hashlib.sha1(unit.encode()).hexdigest(), 16)
    for k in range(len(first) * len(second)):
        name = f"{first[(h + k) % len(first)]} {second[(h // 7 + k) % len(second)]}"
        if name not in taken:
            taken.add(name)
            NAMED[unit] = name
            return name
    return f"{first[h % len(first)]} {unit}"


def lua(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    return json.dumps(v, ensure_ascii=False)


def main():
    dir_names = directory()
    taken = set(n for n, _ in OURS.values())
    rows = []
    for level, idx in LEVELS.items():
        data = json.load(open(os.path.join(OUT, level + ".json")))
        for u in data["units"]:
            unit = u["unit"]
            plan_name = (u["name"] or "").strip().upper()
            current = dir_names.get(unit) or dir_names.get(RENUMBERED.get(unit, ""))
            if not current and plan_name in VACANT_WORDS:
                # A vacant plan unit now split into new ones (FA100 -> FA100A, FA100A1 ...).
                subs = sorted(k for k in dir_names if k.startswith(unit) and k != unit)
                if subs:
                    current = dir_names[subs[0]]
            real = current or plan_name
            if BACK_OF_HOUSE.match(unit) or "NON-LEASABLE" in plan_name or "COMMON AREA" in plan_name or plan_name.startswith("CADILLAC"):
                status, cat, name = "back", "services", None
            elif unit in OURS:
                name, cat = OURS[unit]
                status = "open"
            elif real in VACANT_WORDS and not current:
                status, cat, name = "vacant", None, None
            elif "FOOD HALL" in real.upper():
                status, cat, name = "open", "food", "Queen Street Market Hall"
            else:
                status = "open"
                cat = category_for(real)
                name = made_up(cat, unit, taken)
            rows.append({"unit": unit, "level": idx, "area": u["area"], "status": status, "category": cat, "name": name,
                         "real": real.title() if real else None, "source": "directory" if current else "plan"})
    lines = [
        "-- Generated by tools/eaton/tenants.py. Every traced unit of the Eaton Centre:",
        "-- unit number and level (leasing plans), the real tenant for reference only",
        "-- (CF directory where it lists the unit, else the plan), a category, and the",
        "-- made-up store name the game shows. Real brand names are never displayed.",
        "--   status: open | vacant | back (storage, service rooms: no storefront)",
        "return {",
    ]
    for r in rows:
        lines.append("\t{ " + ", ".join(f"{k} = {lua(v)}" for k, v in r.items()) + " },")
    lines += ["}", ""]
    os.makedirs(os.path.dirname(DEST), exist_ok=True)
    with open(DEST, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    from collections import Counter
    print(len(rows), "units:", dict(Counter(r["status"] for r in rows)), dict(Counter(r["category"] for r in rows if r["status"] == "open")))
    print("from directory:", sum(1 for r in rows if r["source"] == "directory"))


if __name__ == "__main__":
    main()
