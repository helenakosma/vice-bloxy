# Assets that would make the Eaton Centre less blocky

The interiors are built from Roblox parts at runtime. Plain parts, even rounded
ones, can only go so far. Two kinds of asset would make the biggest difference.

## 1. Textures — ready now, just import them

I've drawn 16 textures for the mall. They're in `assets/textures/mall/`, made
by `tools/make_mall_textures.py`:

| File | Used on |
|---|---|
| `mall_floor_tile` | the mall's corridor floors (large porcelain tiles) |
| `mall_wood` | wood floors and wood-panelled walls in stores (tinted per store) |
| `mall_marble` | marble and stone floors and walls, cash desk tops |
| `mall_terrazzo` | the terrazzo plinths in the Sorrel Studio flagship |
| `mall_concrete` | polished concrete floors (Zara, Nike, Hot Topic stand-ins and others) |
| `mall_carpet` | carpeted floors |
| `mall_subway_tile` | the food hall's stall walls and counters |
| `mall_slatwall` | plain store walls (the grooved display wall look) |
| `mall_brushed_metal` | reserved for metal fixtures (not yet wired) |
| `mall_fabric` | fabric-covered walls |
| `mall_ceiling_tile` | store ceilings |
| `mall_wood_slats` | reserved for the slat ceilings (not yet wired) |
| `mall_poster_autumn`, `_denim`, `_sport`, `_sale` | campaign posters in the Sorrel Studio windows (made-up campaigns) |

**To import:**
1. In Studio, open **Asset Manager → Bulk Import** and select every PNG in
   `assets/textures/mall/`.
2. For each image, right-click → **Copy Asset ID**, and paste the number over
   the `0` next to its name in `src/shared/Assets.lua` (the `mall_…` entries at
   the bottom).
3. Restart the playtest. Anything still at `0` keeps its plain material.

Most of the textures are pale grey on purpose: the game tints each one to the
store's own colours, so one wood texture covers every wood floor.

## 2. Meshes — these need you (Blender or your own drawings)

Smooth objects need real meshes, which I can't make inside Roblox. These would
help most, roughly in order of impact. Keep each one simple: a few hundred
triangles, real-world size, about 1 stud = 1 foot.

| Name to give it | What | Notes |
|---|---|---|
| `Mannequin` | a display mannequin (head to toe, about 6.5 ft, standing) | one plain white mesh; the game puts clothes on it |
| `Hanger` | a clothes hanger with a hook | tiny; there are thousands of them |
| `ShirtHanging` | a shirt/top hanging on a hanger, side view matters | separate meshes for `CoatHanging`, `DressHanging` and `TrousersHanging` are a bonus |
| `FoldedStack` | a stack of 4–5 folded tops | for tables and shelves |
| `FoodCourtChair` | the red moulded chair from your photos | one mesh, tinted in game |
| `PendantLamp` | a globe or cone pendant lamp | used everywhere |
| `PlanterPalm` | a potted palm/yucca | for the bridges and balconies |
| `Sneaker`, `Handbag` | one each | shoe and bag stores |

**To hand them over:**
1. Import each mesh in Studio (**Asset Manager → Import 3D**).
2. Make a folder called `MallAssets` inside **ServerStorage**.
3. Put each MeshPart in it, named exactly as above.

Tell me when they're in. I'll wire them so the game uses your mesh wherever it
exists, and falls back to the current shapes where it doesn't.

**Drawings:** if you'd rather sketch store fronts, logos for the made-up
brands, posters or menu boards, export them as PNGs (around 512–1024 px). I'll
add them the same way as the textures. Keep them original: no real brand
logos.
