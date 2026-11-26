-- Store fit-outs for the Eaton Centre: one design per kind of real store, so a
-- unit reads as what's really there (a fast-fashion floor, a tech flagship, a
-- beauty hall, a bookstore...) under its made-up name. Interiors.lua decides where
-- things go (the storefront box, the field spots across the floor, the wall runs);
-- this module decides what they look like.
--
--   Stores.design(tenant)                       -> design (archetype + palette)
--   Stores.front(shop, at, W, D, rng, design, key, tenant)   the storefront fit-out
--   Stores.field(shop, cf, rng, k, design, key)  one fixture on the sales floor
--   Stores.wall(shop, mid, along, inward, len, rng, design, key)   a wall run
--   Stores.registry[key] = { name, colour, centre, radius, design }  for Services/Shopping
--
-- Shopping hooks (read by Services/Shopping): a featured item on each fixture is
-- tagged "ShopProduct" (attributes Product, Store); each till's counter is tagged
-- "ShopTill" (Store); a cashier stands at a part tagged "ShopCashier" (Store), and
-- shoppers browse between parts tagged "ShopSpot" (Store).
--
-- Detail: `d` (0..1) thins out the small items. The storefront fit-out and the
-- walls are full detail, the deep sales floor lighter, so a 25,000 sq ft store
-- doesn't cost ten times a boutique.
local CollectionService = game:GetService("CollectionService")

local Util = require(script.Parent.Parent.Util)
local Billboards = require(script.Parent.Parent.Billboards)

local Stores = {}
Stores.registry = {}

local V3 = Vector3.new
local CF = CFrame.new
local M = Enum.Material
local C = Color3.fromRGB
local rad = math.rad

---------------------------------------------------------------------------
-- Palettes and designs
---------------------------------------------------------------------------
local PAL = {
	white = { floor = C(222, 220, 214), floorMat = M.Concrete, wall = C(246, 246, 244), fixture = C(240, 240, 238), accent = C(30, 30, 32), metal = C(46, 46, 50), wood = C(200, 168, 128) },
	redwhite = { floor = C(226, 224, 220), floorMat = M.Concrete, wall = C(248, 248, 246), fixture = C(244, 244, 242), accent = C(196, 28, 40), metal = C(60, 60, 64), wood = C(206, 176, 136) },
	minimal = { floor = C(196, 194, 190), floorMat = M.Concrete, wall = C(236, 234, 230), fixture = C(30, 30, 32), accent = C(18, 18, 20), metal = C(22, 22, 24), wood = C(150, 130, 110) },
	navywood = { floor = C(170, 128, 88), floorMat = M.WoodPlanks, wall = C(234, 230, 220), fixture = C(176, 138, 98), accent = C(28, 48, 92), metal = C(50, 52, 58), wood = C(176, 138, 98) },
	denim = { floor = C(150, 112, 78), floorMat = M.WoodPlanks, wall = C(228, 226, 220), fixture = C(120, 90, 64), accent = C(44, 74, 124), metal = C(70, 70, 74), wood = C(150, 112, 78) },
	warmwood = { floor = C(196, 162, 120), floorMat = M.WoodPlanks, wall = C(240, 234, 222), fixture = C(214, 186, 146), accent = C(150, 120, 70), metal = C(196, 164, 96), wood = C(196, 162, 120) },
	dark = { floor = C(70, 52, 40), floorMat = M.WoodPlanks, wall = C(52, 44, 38), fixture = C(84, 62, 46), accent = C(200, 180, 140), metal = C(30, 30, 30), wood = C(84, 62, 46) },
	pink = { floor = C(236, 226, 224), floorMat = M.Marble, wall = C(246, 214, 222), fixture = C(250, 240, 242), accent = C(214, 90, 140), metal = C(220, 196, 170), wood = C(240, 220, 210) },
	premium = { floor = C(120, 84, 56), floorMat = M.WoodPlanks, wall = C(92, 64, 44), fixture = C(110, 78, 52), accent = C(196, 168, 110), metal = C(196, 164, 96), wood = C(110, 78, 52) },
	sport = { floor = C(54, 54, 58), floorMat = M.Concrete, wall = C(34, 34, 38), fixture = C(220, 220, 220), accent = C(240, 110, 30), metal = C(20, 20, 22), wood = C(170, 140, 110) },
	sportblue = { floor = C(60, 62, 70), floorMat = M.Concrete, wall = C(40, 44, 54), fixture = C(230, 230, 232), accent = C(30, 110, 220), metal = C(20, 22, 26), wood = C(170, 140, 110) },
	lulu = { floor = C(212, 196, 172), floorMat = M.WoodPlanks, wall = C(248, 246, 242), fixture = C(222, 206, 180), accent = C(206, 30, 50), metal = C(60, 60, 60), wood = C(212, 196, 172) },
	outdoor = { floor = C(130, 124, 116), floorMat = M.Slate, wall = C(110, 86, 64), fixture = C(140, 108, 76), accent = C(220, 80, 40), metal = C(40, 40, 40), wood = C(140, 108, 76) },
	tech = { floor = C(214, 210, 204), floorMat = M.Limestone, wall = C(244, 244, 242), fixture = C(222, 196, 156), accent = C(40, 40, 44), metal = C(170, 172, 176), wood = C(222, 196, 156) },
	beauty = { floor = C(240, 240, 238), floorMat = M.Marble, wall = C(20, 20, 22), fixture = C(250, 250, 250), accent = C(18, 18, 20), metal = C(200, 200, 204), wood = C(60, 50, 44) },
	rustic = { floor = C(130, 100, 72), floorMat = M.WoodPlanks, wall = C(40, 40, 40), fixture = C(150, 116, 80), accent = C(60, 140, 80), metal = C(40, 40, 40), wood = C(150, 116, 80) },
	apothecary = { floor = C(110, 84, 60), floorMat = M.WoodPlanks, wall = C(70, 54, 40), fixture = C(92, 70, 50), accent = C(180, 120, 50), metal = C(170, 140, 80), wood = C(92, 70, 50) },
	jewelred = { floor = C(236, 226, 214), floorMat = M.Marble, wall = C(140, 20, 30), fixture = C(40, 18, 18), accent = C(214, 176, 80), metal = C(214, 176, 80), wood = C(70, 30, 26) },
	jewelwhite = { floor = C(244, 242, 240), floorMat = M.Marble, wall = C(250, 250, 250), fixture = C(250, 250, 250), accent = C(30, 30, 36), metal = C(200, 200, 206), wood = C(220, 210, 200) },
	leather = { floor = C(226, 216, 200), floorMat = M.Marble, wall = C(236, 226, 210), fixture = C(140, 96, 60), accent = C(120, 80, 46), metal = C(196, 164, 96), wood = C(140, 96, 60) },
	books = { floor = C(150, 116, 84), floorMat = M.WoodPlanks, wall = C(236, 230, 218), fixture = C(120, 84, 56), accent = C(30, 80, 60), metal = C(40, 40, 40), wood = C(120, 84, 56) },
	toys = { floor = C(236, 236, 236), floorMat = M.SmoothPlastic, wall = C(250, 250, 250), fixture = C(250, 250, 250), accent = C(230, 60, 80), metal = C(80, 80, 84), wood = C(230, 200, 160) },
	pharmacy = { floor = C(230, 230, 228), floorMat = M.Marble, wall = C(246, 246, 246), fixture = C(250, 250, 250), accent = C(200, 30, 40), metal = C(150, 150, 156), wood = C(200, 170, 130) },
	optical = { floor = C(226, 222, 216), floorMat = M.WoodPlanks, wall = C(244, 244, 240), fixture = C(232, 214, 190), accent = C(30, 60, 90), metal = C(60, 60, 64), wood = C(232, 214, 190) },
	cafe = { floor = C(120, 90, 66), floorMat = M.WoodPlanks, wall = C(224, 214, 196), fixture = C(70, 50, 38), accent = C(30, 90, 60), metal = C(180, 182, 186), wood = C(150, 110, 76) },
	bubble = { floor = C(240, 236, 230), floorMat = M.Marble, wall = C(250, 246, 240), fixture = C(250, 250, 250), accent = C(214, 130, 60), metal = C(190, 190, 194), wood = C(220, 190, 150) },
	dessert = { floor = C(250, 240, 236), floorMat = M.Marble, wall = C(250, 226, 230), fixture = C(250, 250, 250), accent = C(200, 80, 110), metal = C(200, 200, 204), wood = C(230, 200, 170) },
	quick = { floor = C(200, 196, 190), floorMat = M.Concrete, wall = C(60, 60, 64), fixture = C(190, 190, 194), accent = C(214, 60, 30), metal = C(180, 182, 186), wood = C(150, 110, 76) },
	restaurant = { floor = C(110, 80, 58), floorMat = M.WoodPlanks, wall = C(70, 54, 44), fixture = C(90, 64, 46), accent = C(200, 150, 80), metal = C(170, 140, 80), wood = C(90, 64, 46) },
	bank = { floor = C(200, 204, 210), floorMat = M.Marble, wall = C(236, 238, 242), fixture = C(240, 242, 246), accent = C(0, 100, 180), metal = C(170, 172, 176), wood = C(180, 150, 120) },
	telco = { floor = C(232, 232, 232), floorMat = M.SmoothPlastic, wall = C(250, 250, 250), fixture = C(250, 250, 250), accent = C(30, 90, 200), metal = C(160, 160, 166), wood = C(220, 200, 170) },
	dept = { floor = C(232, 228, 222), floorMat = M.Marble, wall = C(246, 244, 240), fixture = C(236, 236, 234), accent = C(20, 20, 22), metal = C(60, 60, 64), wood = C(196, 168, 130) },
	records = { floor = C(60, 58, 56), floorMat = M.Concrete, wall = C(30, 30, 34), fixture = C(120, 90, 64), accent = C(230, 200, 40), metal = C(30, 30, 30), wood = C(120, 90, 64) },
}

-- Which design a real store gets (keywords in the tenant's real name), then a
-- fallback by category. The store keeps its made-up name; only the look follows.
local BY_NAME = {
	{ "h m", "fashion", "redwhite" }, { "h & m", "fashion", "redwhite" }, { "uniqlo", "fashion", "redwhite" },
	{ "old navy", "fashion", "navywood" }, { "gap", "fashion", "navywood" }, { "zara", "fashion", "minimal" },
	{ "mango", "fashion", "minimal" }, { "aritzia", "fashion", "warmwood" }, { "wilfred", "fashion", "warmwood" },
	{ "club monaco", "premium", "warmwood" }, { "banana republic", "premium", "warmwood" },
	{ "abercrombie", "fashion", "dark" }, { "hollister", "fashion", "dark" }, { "american eagle", "fashion", "denim" },
	{ "levis", "fashion", "denim" }, { "garage", "fashion", "pink" }, { "dynamite", "fashion", "minimal" },
	{ "victorias secret", "intimates", "pink" }, { "la vie en rose", "intimates", "pink" }, { "aerie", "intimates", "pink" },
	{ "bath body", "beauty", "pink" }, { "harry rosen", "premium", "premium" }, { "hugo boss", "premium", "premium" },
	{ "lacoste", "premium", "warmwood" }, { "browns", "footwear", "premium" }, { "mackage", "premium", "minimal" },
	{ "moose knuckles", "premium", "minimal" }, { "canada goose", "outdoor", "outdoor" }, { "octobers very own", "premium", "minimal" },
	{ "nike", "sports", "sport" }, { "adidas", "sports", "sportblue" }, { "under armour", "sports", "sport" },
	{ "sport chek", "sports", "sportblue" }, { "champs", "sports", "sport" }, { "zumiez", "sports", "sport" },
	{ "lids", "sports", "sport" }, { "lululemon", "sports", "lulu" }, { "athleta", "sports", "lulu" },
	{ "north face", "outdoor", "outdoor" }, { "arcteryx", "outdoor", "outdoor" }, { "roots", "outdoor", "outdoor" },
	{ "apple", "tech", "tech" }, { "bell", "telco", "telco" }, { "telus", "telco", "telco" }, { "rogers", "telco", "telco" },
	{ "fido", "telco", "telco" }, { "koodo", "telco", "telco" }, { "freedom", "telco", "telco" }, { "virgin", "telco", "telco" },
	{ "lucky mobile", "telco", "telco" }, { "sephora", "beauty", "beauty" }, { "mac", "beauty", "beauty" },
	{ "lush", "beauty", "rustic" }, { "body shop", "beauty", "rustic" }, { "aesop", "beauty", "apothecary" },
	{ "kiehls", "beauty", "apothecary" }, { "jo malone", "beauty", "apothecary" }, { "aveda", "beauty", "apothecary" },
	{ "chow tai fook", "jewellery", "jewelred" }, { "pandora", "jewellery", "jewelwhite" }, { "swarovski", "jewellery", "jewelwhite" },
	{ "swatch", "jewellery", "jewelwhite" }, { "fossil", "jewellery", "leather" }, { "claires", "jewellery", "pink" },
	{ "coach", "bags", "leather" }, { "michael kors", "bags", "leather" }, { "kate spade", "bags", "pink" },
	{ "tumi", "bags", "minimal" }, { "herschel", "bags", "warmwood" }, { "laco sac", "bags", "leather" },
	{ "call it spring", "footwear", "pink" }, { "aldo", "footwear", "minimal" }, { "indigo", "books", "books" },
	{ "canadian naturalist", "books", "books" }, { "miniso", "toys", "toys" }, { "pop mart", "toys", "toys" },
	{ "flying tiger", "toys", "toys" }, { "treehouse", "toys", "toys" }, { "sunrise records", "records", "records" },
	{ "shoppers", "pharmacy", "pharmacy" }, { "nutrition house", "pharmacy", "pharmacy" }, { "heal wellness", "pharmacy", "pharmacy" },
	{ "starbucks", "cafe", "cafe" }, { "vereda", "cafe", "cafe" }, { "danish pastry", "cafe", "dessert" },
	{ "saint germain", "cafe", "dessert" }, { "tim hortons", "quick", "quick" }, { "chick fil a", "quick", "redwhite" }, { "gong cha", "bubble", "bubble" },
	{ "heytea", "bubble", "bubble" }, { "machi", "bubble", "bubble" }, { "real fruit", "bubble", "bubble" },
	{ "laderach", "dessert", "premium" }, { "purdys", "dessert", "premium" }, { "craigs cookies", "dessert", "dessert" },
	{ "baskin", "dessert", "dessert" }, { "yogen", "dessert", "dessert" }, { "crepe", "dessert", "dessert" },
	{ "tanghulu", "dessert", "dessert" }, { "kernels", "dessert", "dessert" }, { "wetzels", "quick", "quick" },
	{ "milestones", "restaurant", "restaurant" }, { "mercatto", "restaurant", "restaurant" },
	{ "bank of montreal", "bank", "bank" }, { "bmo", "bank", "bank" }, { "td canada", "bank", "bank" },
	{ "calforex", "bank", "bank" }, { "simons", "dept", "dept" },
}
local BY_CATEGORY = {
	fashion = { "fashion", "white" }, sports = { "sports", "sport" }, footwear = { "footwear", "white" },
	electronics = { "telco", "telco" }, beauty = { "beauty", "beauty" }, jewellery = { "jewellery", "jewelwhite" },
	optical = { "optical", "optical" }, books = { "books", "books" }, pharmacy = { "pharmacy", "pharmacy" },
	cafe = { "cafe", "cafe" }, food = { "quick", "quick" }, services = { "bank", "bank" }, department = { "dept", "dept" },
}
-- Telco and bank accent colours by brand (a generic colour, never a logo).
local ACCENT = {
	bell = C(0, 90, 180), telus = C(90, 40, 140), rogers = C(214, 30, 40), fido = C(240, 190, 30),
	koodo = C(60, 170, 80), freedom = C(240, 120, 30), virgin = C(200, 20, 50), ["lucky mobile"] = C(240, 200, 40),
	["bank of montreal"] = C(0, 110, 190), bmo = C(0, 110, 190), ["td canada"] = C(40, 150, 60),
}

local function lower(s)
	return string.lower(s or ""):gsub("[^%w& ]", "")
end


---------------------------------------------------------------------------
-- Brand styles: what each store's clothes look like (colours and garment
-- kinds on its rails, tables and mannequins) and how its front is finished,
-- matched on the real tenant (never shown) so each reads like the real store.
--   clothes: colours; kinds: garment kinds (see garment); front: overrides for
--   Stores.storefront { pier, pierMat, band, bandMat, ink, font, extra }
---------------------------------------------------------------------------
local K = {
	black = C(24, 24, 26), charcoal = C(54, 54, 58), grey = C(128, 128, 132), ash = C(184, 182, 178),
	white = C(242, 240, 236), cream = C(232, 222, 202), oat = C(214, 200, 176), camel = C(184, 144, 98),
	tan = C(160, 120, 80), brown = C(98, 66, 46), oxblood = C(96, 28, 32), bone = C(226, 216, 196),
	navy = C(30, 40, 70), denim = C(62, 88, 130), lightdenim = C(120, 150, 190), red = C(196, 32, 40),
	pink = C(236, 150, 180), blush = C(240, 200, 196), rose = C(206, 110, 130), sage = C(156, 172, 140),
	olive = C(98, 104, 64), forest = C(44, 72, 52), mustard = C(212, 168, 60), sky = C(140, 186, 226),
	royal = C(40, 70, 170), lime = C(170, 220, 60), orange = C(236, 120, 40), purple = C(110, 70, 150),
	teal = C(40, 130, 140), lilac = C(196, 176, 220),
}
local BRANDS = {
	{ "allsaints", clothes = { K.black, K.black, K.charcoal, K.grey, K.oxblood, K.bone }, kinds = { "leather", "leather", "tee", "knit", "coat", "trousers" },
		front = { pier = C(40, 36, 34), pierMat = M.Brick, band = K.black, ink = K.bone, font = Enum.Font.Antique, extra = "machines" } },
	{ "aritzia", clothes = { K.cream, K.oat, K.camel, K.black, K.sage, K.white, K.brown }, kinds = { "coat", "knit", "knit", "dress", "trousers", "tee" },
		front = { pier = C(206, 194, 176), pierMat = M.Limestone, band = C(236, 228, 214), ink = C(40, 36, 32), font = Enum.Font.Garamond, extra = "wood" } },
	{ "wilfred", clothes = { K.cream, K.oat, K.camel, K.black, K.blush }, kinds = { "knit", "dress", "coat", "trousers" } },
	{ "babaton", clothes = { K.black, K.cream, K.camel, K.grey }, kinds = { "coat", "knit", "trousers", "suit" } },
	{ "uniqlo", clothes = { K.white, K.navy, K.grey, K.red, K.oat, K.black, K.sky }, kinds = { "tee", "tee", "knit", "shirt", "trousers", "coat" } },
	{ "h m", clothes = { K.camel, K.cream, K.black, K.brown, K.sage, K.denim } , kinds = { "tee", "knit", "knit", "trousers", "dress", "coat" } },
	{ "zara", clothes = { K.black, K.white, K.camel, K.ash, K.charcoal, K.cream }, kinds = { "coat", "suit", "dress", "trousers", "knit", "shirt" },
		front = { pier = C(60, 60, 62), pierMat = M.Slate, band = C(30, 30, 32), ink = K.white, font = Enum.Font.Bodoni } },
	{ "mango", clothes = { K.cream, K.camel, K.black, K.rose, K.oat }, kinds = { "dress", "coat", "knit", "trousers" },
		front = { pier = C(232, 226, 216), band = C(236, 232, 224), ink = K.black, font = Enum.Font.Bodoni } },
	{ "massimo", clothes = { K.camel, K.navy, K.cream, K.brown }, kinds = { "coat", "suit", "knit" } },
	{ "sandro", clothes = { K.black, K.navy, K.cream, K.red }, kinds = { "suit", "coat", "dress", "knit" } },
	{ "maje", clothes = { K.black, K.blush, K.cream, K.red }, kinds = { "dress", "dress", "coat", "knit" } },
	{ "lululemon", clothes = { K.black, K.black, K.navy, K.sage, K.rose, K.white, K.charcoal }, kinds = { "leggings", "leggings", "hoodie", "sport", "tee", "coat" },
		front = { pier = C(196, 160, 120), pierMat = M.WoodPlanks, band = C(244, 242, 238), ink = C(204, 30, 40), font = Enum.Font.GothamMedium, extra = "wood" } },
	{ "athleta", clothes = { K.black, K.navy, K.teal, K.lilac, K.white }, kinds = { "leggings", "hoodie", "sport", "tee" } },
	{ "adidas", clothes = { K.black, K.white, K.black, K.royal, K.grey, K.red }, kinds = { "sport", "sport", "hoodie", "leggings", "tee" },
		front = { pier = K.black, pierMat = M.Metal, band = K.black, ink = K.white, font = Enum.Font.GothamBlack, extra = "bars" } },
	{ "nike", clothes = { K.black, K.white, K.grey, K.orange, K.lime, K.royal }, kinds = { "sport", "hoodie", "leggings", "tee", "sport" },
		front = { pier = C(30, 30, 32), pierMat = M.Metal, band = C(30, 30, 32), ink = K.white, font = Enum.Font.GothamBlack, extra = "screens" } },
	{ "under armour", clothes = { K.black, K.charcoal, K.red, K.white, K.royal }, kinds = { "sport", "hoodie", "leggings" },
		front = { pier = C(30, 30, 32), pierMat = M.Metal, band = C(30, 30, 32), ink = K.white, font = Enum.Font.GothamBlack } },
	{ "sport chek", clothes = { K.black, K.red, K.royal, K.white, K.lime }, kinds = { "sport", "hoodie", "leggings", "coat" } },
	{ "champs", clothes = { K.black, K.white, K.royal, K.red }, kinds = { "sport", "hoodie", "tee" } },
	{ "foot locker", clothes = { K.black, K.white, K.red }, kinds = { "sport", "hoodie", "tee" },
		front = { pier = C(30, 30, 32), pierMat = M.Metal, band = C(30, 30, 32), ink = K.white, font = Enum.Font.GothamBlack, extra = "stripes" } },
	{ "zumiez", clothes = { K.black, K.mustard, K.forest, K.denim, K.white, K.orange }, kinds = { "graphic", "graphic", "hoodie", "trousers" },
		front = { pier = C(70, 66, 62), pierMat = M.Concrete, band = K.black, ink = K.white, font = Enum.Font.Arcade, extra = "stickers" } },
	{ "hot topic", clothes = { K.black, K.black, K.purple, K.red, K.charcoal }, kinds = { "graphic", "graphic", "hoodie", "leather" },
		front = { pier = K.black, pierMat = M.Metal, band = K.black, ink = C(220, 40, 60), font = Enum.Font.Antique, extra = "stickers" } },
	{ "urban customz", clothes = { K.black, K.white, K.red, K.mustard }, kinds = { "graphic", "hoodie", "sport" } },
	{ "gap", clothes = { K.navy, K.denim, K.lightdenim, K.white, K.grey, K.red }, kinds = { "tee", "shirt", "trousers", "hoodie", "knit" },
		front = { pier = C(236, 236, 232), band = K.navy, ink = K.white, font = Enum.Font.Garamond } },
	{ "old navy", clothes = { K.navy, K.red, K.white, K.denim, K.mustard, K.sky }, kinds = { "tee", "tee", "trousers", "hoodie", "dress" },
		front = { pier = C(236, 236, 232), band = K.navy, ink = K.white, font = Enum.Font.GothamBlack } },
	{ "american eagle", clothes = { K.denim, K.lightdenim, K.navy, K.white, K.olive, K.grey }, kinds = { "trousers", "trousers", "tee", "hoodie", "shirt" },
		front = { pier = C(110, 80, 56), pierMat = M.WoodPlanks, band = K.navy, ink = K.white, font = Enum.Font.Garamond, extra = "wood" } },
	{ "aerie", clothes = { K.blush, K.white, K.sky, K.lilac, K.oat }, kinds = { "leggings", "hoodie", "tee", "knit" } },
	{ "levis", clothes = { K.denim, K.lightdenim, K.navy, K.white, K.red }, kinds = { "trousers", "trousers", "trousers", "shirt", "tee" },
		front = { pier = C(120, 84, 56), pierMat = M.WoodPlanks, band = C(186, 30, 40), ink = K.white, font = Enum.Font.GothamBlack, extra = "wood" } },
	{ "abercrombie", clothes = { K.navy, K.olive, K.cream, K.grey, K.denim }, kinds = { "knit", "shirt", "trousers", "coat", "hoodie" },
		front = { pier = C(60, 46, 36), pierMat = M.WoodPlanks, band = C(46, 36, 30), ink = K.cream, font = Enum.Font.Garamond, extra = "louvers" } },
	{ "hollister", clothes = { K.navy, K.sky, K.white, K.coral or K.rose, K.olive }, kinds = { "tee", "hoodie", "trousers", "shirt" },
		front = { pier = C(80, 60, 44), pierMat = M.WoodPlanks, band = C(70, 52, 40), ink = K.cream, font = Enum.Font.Garamond, extra = "louvers" } },
	{ "garage", clothes = { K.black, K.pink, K.white, K.denim, K.lilac }, kinds = { "tee", "dress", "trousers", "hoodie" },
		front = { pier = C(236, 236, 236), band = K.black, ink = C(255, 120, 180), font = Enum.Font.GothamBold, extra = "neon" } },
	{ "dynamite", clothes = { K.black, K.cream, K.camel, K.white, K.red }, kinds = { "dress", "trousers", "coat", "knit" },
		front = { pier = K.black, pierMat = M.Slate, band = K.black, ink = K.white, font = Enum.Font.Bodoni } },
	{ "banana republic", clothes = { K.navy, K.camel, K.cream, K.charcoal, K.olive }, kinds = { "suit", "shirt", "coat", "trousers", "knit" },
		front = { pier = C(214, 198, 166), pierMat = M.Limestone, band = C(40, 40, 42), ink = K.white, font = Enum.Font.Garamond } },
	{ "club monaco", clothes = { K.black, K.navy, K.white, K.camel }, kinds = { "suit", "shirt", "knit", "coat" } },
	{ "harry rosen", clothes = { K.navy, K.charcoal, K.camel, K.white }, kinds = { "suit", "suit", "shirt", "coat" },
		front = { pier = C(60, 46, 36), pierMat = M.WoodPlanks, band = C(26, 30, 44), ink = C(214, 184, 120), font = Enum.Font.Garamond } },
	{ "hugo boss", clothes = { K.black, K.charcoal, K.navy, K.white }, kinds = { "suit", "suit", "shirt", "coat" },
		front = { pier = K.black, pierMat = M.Slate, band = K.black, ink = K.white, font = Enum.Font.GothamMedium } },
	{ "jack jones", clothes = { K.denim, K.black, K.olive, K.white }, kinds = { "trousers", "tee", "shirt", "hoodie" } },
	{ "frank & oak", clothes = { K.navy, K.forest, K.oat, K.brown }, kinds = { "shirt", "knit", "coat", "trousers" } },
	{ "lacoste", clothes = { K.white, K.forest, K.navy, K.red, K.sky }, kinds = { "shirt", "shirt", "knit", "tee" },
		front = { pier = C(240, 240, 236), band = C(24, 72, 52), ink = K.white, font = Enum.Font.Garamond } },
	{ "psycho bunny", clothes = { K.navy, K.white, K.sky, K.black }, kinds = { "shirt", "shirt", "tee" } },
	{ "octobers very own", clothes = { K.black, K.black, K.mustard, K.oat }, kinds = { "hoodie", "hoodie", "graphic", "coat" },
		front = { pier = K.black, pierMat = M.Slate, band = K.black, ink = C(214, 184, 120), font = Enum.Font.Garamond } },
	{ "roots", clothes = { K.forest, K.grey, K.ash, K.navy, K.brown }, kinds = { "hoodie", "hoodie", "trousers", "knit", "coat" },
		front = { pier = C(120, 86, 56), pierMat = M.WoodPlanks, band = C(36, 60, 44), ink = K.cream, font = Enum.Font.Garamond, extra = "wood" } },
	{ "canada goose", clothes = { K.black, K.red, K.navy, K.olive, K.camel }, kinds = { "parka", "parka", "parka", "knit" },
		front = { pier = C(40, 40, 42), pierMat = M.Slate, band = C(40, 40, 42), ink = K.white, font = Enum.Font.GothamMedium } },
	{ "moose knuckles", clothes = { K.black, K.oxblood, K.charcoal }, kinds = { "parka", "parka", "leather" } },
	{ "mackage", clothes = { K.black, K.camel, K.cream }, kinds = { "parka", "leather", "coat" } },
	{ "rudsak", clothes = { K.black, K.brown, K.camel }, kinds = { "leather", "parka", "coat" } },
	{ "north face", clothes = { K.black, K.red, K.mustard, K.navy, K.olive }, kinds = { "parka", "parka", "hoodie", "coat" },
		front = { pier = C(36, 36, 38), pierMat = M.Metal, band = C(36, 36, 38), ink = K.white, font = Enum.Font.GothamBlack } },
	{ "arcteryx", clothes = { K.black, K.teal, K.orange, K.grey, K.lime }, kinds = { "parka", "coat", "hoodie" },
		front = { pier = C(52, 52, 56), pierMat = M.Slate, band = C(30, 30, 32), ink = K.white, font = Enum.Font.GothamMedium } },
	{ "victorias secret", clothes = { K.pink, K.blush, K.black, K.rose, K.white }, kinds = { "dress", "tee", "hoodie", "leggings" },
		front = { pier = C(250, 220, 230), band = C(240, 170, 196), ink = K.white, font = Enum.Font.Bodoni, extra = "neon" } },
	{ "la vie en rose", clothes = { K.blush, K.rose, K.black, K.white, K.lilac }, kinds = { "dress", "tee", "knit" } },
	{ "la senza", clothes = { K.pink, K.black, K.purple, K.blush }, kinds = { "dress", "tee" } },
	{ "torrid", clothes = { K.black, K.purple, K.red, K.denim }, kinds = { "dress", "tee", "trousers" } },
	{ "reitmans", clothes = { K.navy, K.cream, K.camel, K.rose }, kinds = { "shirt", "trousers", "dress", "knit" } },
	{ "ever new", clothes = { K.blush, K.cream, K.sage, K.sky }, kinds = { "dress", "dress", "coat" } },
	{ "tna", clothes = { K.black, K.grey, K.oat, K.olive }, kinds = { "hoodie", "parka", "tee" } },
	{ "simons", clothes = { K.cream, K.black, K.sage, K.camel, K.rose, K.denim }, kinds = { "coat", "knit", "dress", "trousers", "shirt" } },
	-- not clothing: just their fronts
	{ "sephora", front = { pier = K.black, band = K.black, ink = K.white, font = Enum.Font.GothamMedium, extra = "stripes" } },
	{ "apple", front = { pier = C(206, 208, 212), pierMat = M.Metal, band = C(240, 240, 240), ink = C(90, 90, 96), font = Enum.Font.GothamMedium } },
	{ "lush", front = { pier = K.black, band = K.black, ink = K.white, font = Enum.Font.FredokaOne, extra = "wood" } },
	{ "indigo", front = { pier = C(110, 78, 52), pierMat = M.WoodPlanks, band = C(150, 30, 40), ink = K.cream, font = Enum.Font.Garamond, extra = "wood" } },
	{ "bath body", front = { pier = K.white, band = C(40, 70, 140), ink = K.white, font = Enum.Font.Garamond } },
	{ "pandora", front = { pier = K.white, band = C(250, 244, 244), ink = K.black, font = Enum.Font.Bodoni } },
	{ "swarovski", front = { pier = K.black, pierMat = M.Slate, band = K.black, ink = K.white, font = Enum.Font.GothamMedium } },
	{ "mac", front = { pier = K.black, band = K.black, ink = K.white, font = Enum.Font.GothamBlack } },
	{ "starbucks", front = { pier = C(110, 78, 52), pierMat = M.WoodPlanks, band = C(0, 98, 65), ink = K.white, font = Enum.Font.GothamBold } },
	{ "tim hortons", front = { pier = C(120, 86, 56), pierMat = M.WoodPlanks, band = C(200, 16, 46), ink = K.white, font = Enum.Font.Garamond } },
	{ "miniso", front = { pier = K.white, band = C(220, 30, 40), ink = K.white, font = Enum.Font.GothamBlack } },
	{ "pop mart", front = { pier = K.white, band = K.black, ink = K.white, font = Enum.Font.GothamBlack, extra = "stickers" } },
	{ "sunrise records", front = { pier = K.black, band = K.black, ink = C(250, 200, 40), font = Enum.Font.Arcade, extra = "stickers" } },
	{ "bell", front = { pier = K.white, band = C(0, 84, 164), ink = K.white, font = Enum.Font.GothamBold } },
	{ "rogers", front = { pier = K.white, band = C(218, 41, 28), ink = K.white, font = Enum.Font.GothamBold } },
	{ "telus", front = { pier = K.white, band = C(75, 40, 109), ink = C(102, 204, 0), font = Enum.Font.GothamBold } },
	{ "loccitane", front = { pier = C(236, 222, 180), pierMat = M.Limestone, band = C(250, 214, 60), ink = C(60, 40, 30), font = Enum.Font.Garamond } },
	{ "davidstea", front = { pier = K.white, band = C(120, 200, 180), ink = K.white, font = Enum.Font.GothamBold } },
	{ "lids", front = { pier = K.black, pierMat = M.Metal, band = C(0, 70, 140), ink = K.white, font = Enum.Font.GothamBlack } },
}

-- Interiors (floor, floorMat, wall, wallMat, fixture, metal, wood, ceiling
-- "white"/"dark", lights "track"/"linear"/"panel"/"chandelier"/"pendant").
local INSIDE = {
	allsaints = { floor = C(64, 48, 38), floorMat = M.WoodPlanks, wall = C(112, 72, 58), wallMat = M.Brick, fixture = C(40, 38, 36), metal = C(70, 64, 58), ceiling = "dark", lights = "pendant" },
	aritzia = { floor = C(222, 208, 186), floorMat = M.Limestone, wall = C(238, 230, 216), wallMat = M.Limestone, fixture = C(184, 146, 104), metal = C(190, 170, 130), ceiling = "white", lights = "pendant" },
	lululemon = { floor = C(206, 176, 136), floorMat = M.WoodPlanks, wall = C(244, 242, 238), fixture = C(196, 164, 124), metal = C(60, 60, 64), ceiling = "white", lights = "track" },
	zara = { floor = C(176, 174, 170), floorMat = M.Concrete, wall = C(242, 242, 240), fixture = C(30, 30, 32), metal = C(30, 30, 32), ceiling = "white", lights = "linear" },
	uniqlo = { floor = C(210, 180, 140), floorMat = M.WoodPlanks, wall = C(246, 246, 244), fixture = C(244, 244, 242), metal = C(190, 190, 194), ceiling = "white", lights = "panel" },
	nike = { floor = C(96, 96, 100), floorMat = M.Concrete, wall = C(44, 44, 48), wallMat = M.Concrete, fixture = C(36, 36, 38), metal = C(30, 30, 30), accent = C(236, 120, 40), ceiling = "dark", lights = "linear" },
	adidas = { floor = C(150, 150, 154), floorMat = M.Concrete, wall = C(240, 240, 240), fixture = C(30, 30, 32), metal = C(30, 30, 32), ceiling = "dark", lights = "linear" },
	apple = { floor = C(214, 206, 192), floorMat = M.Limestone, wall = C(246, 246, 244), fixture = C(206, 168, 118), metal = C(200, 202, 206), ceiling = "white", lights = "panel" },
	sephora = { floor = C(36, 36, 38), floorMat = M.Marble, wall = C(30, 30, 32), fixture = C(244, 244, 244), metal = C(30, 30, 30), ceiling = "dark", lights = "linear" },
	abercrombie = { floor = C(70, 50, 36), floorMat = M.WoodPlanks, wall = C(60, 46, 36), wallMat = M.WoodPlanks, fixture = C(90, 66, 48), metal = C(50, 44, 40), ceiling = "dark", lights = "pendant" },
	hollister = { floor = C(80, 58, 42), floorMat = M.WoodPlanks, wall = C(70, 54, 42), wallMat = M.WoodPlanks, fixture = C(96, 72, 52), ceiling = "dark", lights = "pendant" },
	["harry rosen"] = { floor = C(80, 56, 40), floorMat = M.WoodPlanks, wall = C(36, 44, 66), wallMat = M.Fabric, fixture = C(90, 64, 44), metal = C(190, 160, 100), ceiling = "dark", lights = "chandelier" },
	roots = { floor = C(150, 108, 72), floorMat = M.WoodPlanks, wall = C(160, 120, 84), wallMat = M.WoodPlanks, fixture = C(120, 86, 58), ceiling = "dark", lights = "pendant" },
	["canada goose"] = { floor = C(70, 70, 74), floorMat = M.Concrete, wall = C(58, 58, 62), wallMat = M.Slate, fixture = C(40, 40, 42), ceiling = "dark", lights = "linear" },
	indigo = { floor = C(150, 110, 76), floorMat = M.WoodPlanks, wall = C(236, 226, 206), fixture = C(140, 100, 66), ceiling = "white", lights = "pendant" },
	lush = { floor = C(110, 108, 104), floorMat = M.Concrete, wall = C(30, 30, 32), fixture = C(120, 90, 60), ceiling = "dark", lights = "pendant" },
	["victorias secret"] = { floor = C(30, 28, 30), floorMat = M.Marble, wall = C(240, 190, 206), wallMat = M.Fabric, fixture = C(250, 230, 236), metal = C(200, 170, 110), ceiling = "white", lights = "chandelier" },
	["hot topic"] = { floor = C(90, 90, 94), floorMat = M.Concrete, wall = C(26, 26, 28), wallMat = M.Brick, fixture = C(30, 30, 32), ceiling = "dark", lights = "track" },
	gap = { floor = C(190, 160, 120), floorMat = M.WoodPlanks, wall = C(246, 246, 244), fixture = C(240, 240, 238), ceiling = "white", lights = "track" },
	levis = { floor = C(130, 96, 66), floorMat = M.WoodPlanks, wall = C(140, 84, 64), wallMat = M.Brick, fixture = C(110, 80, 56), ceiling = "dark", lights = "pendant" },
	["american eagle"] = { floor = C(150, 110, 76), floorMat = M.WoodPlanks, wall = C(226, 220, 210), fixture = C(140, 104, 70), ceiling = "white", lights = "track" },
	["hugo boss"] = { floor = C(40, 40, 42), floorMat = M.Marble, wall = C(54, 54, 58), fixture = C(30, 30, 32), metal = C(180, 180, 186), ceiling = "dark", lights = "linear" },
	["north face"] = { floor = C(110, 110, 112), floorMat = M.Concrete, wall = C(150, 110, 76), wallMat = M.WoodPlanks, fixture = C(40, 40, 42), ceiling = "dark", lights = "linear" },
	starbucks = { floor = C(120, 86, 60), floorMat = M.WoodPlanks, wall = C(40, 60, 50), fixture = C(110, 80, 56), ceiling = "dark", lights = "pendant" },
	garage = { floor = C(236, 236, 236), floorMat = M.Marble, wall = C(246, 220, 230), fixture = C(250, 250, 250), metal = C(200, 170, 110), ceiling = "white", lights = "chandelier" },
	zumiez = { floor = C(100, 96, 92), floorMat = M.Concrete, wall = C(70, 66, 62), wallMat = M.Concrete, fixture = C(120, 90, 60), ceiling = "dark", lights = "track" },
	["foot locker"] = { floor = C(40, 40, 42), floorMat = M.WoodPlanks, wall = C(30, 30, 32), fixture = C(244, 244, 244), ceiling = "dark", lights = "linear" },
}

-- Whether a store's real name (lower case) names this key: short keys must
-- be whole words ("mac" is not "machi", "gap" is not "singapore").
local function names(real, key)
	if #key <= 4 then
		local escaped = key:gsub("%p", "%%%0")
		return real:find("%f[%w]" .. escaped .. "%f[%W]") ~= nil
	end
	return real:find(key, 1, true) ~= nil
end

-- The style for a store, by its real name (lower case), or nil. Brands that
-- only have an interior are given one here too.
for key, inside in pairs(INSIDE) do
	local found = false
	for _, b in ipairs(BRANDS) do
		if b[1] == key then
			b.inside = inside
			found = true
		end
	end
	if not found then
		table.insert(BRANDS, { key, inside = inside })
	end
end
local function brandFor(real)
	for _, b in ipairs(BRANDS) do
		if names(real, b[1]) then
			return b
		end
	end
	return nil
end

function Stores.design(tenant)
	local real = lower(tenant.real)
	local arch, palName
	for _, row in ipairs(BY_NAME) do
		if names(real, row[1]) then
			arch, palName = row[2], row[3]
			break
		end
	end
	if not arch then
		local fb = BY_CATEGORY[tenant.category] or BY_CATEGORY.fashion
		arch, palName = fb[1], fb[2]
	end
	local pal = table.clone(PAL[palName] or PAL.white)
	for word, colour in pairs(ACCENT) do
		if names(real, word) then
			pal.accent = colour
		end
	end
	local brand = brandFor(real)
	-- the brand's own interior: floor, walls and fixtures
	local inside = brand and brand.inside
	if inside then
		for _, k in ipairs({ "floor", "floorMat", "wall", "fixture", "metal", "wood", "accent" }) do
			if inside[k] ~= nil then
				pal[k] = inside[k]
			end
		end
	end
	return { arch = arch, pal = pal, palName = palName, name = tenant.name or "", real = real, brand = brand }
end

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------
local function solid(f, size, cf, colour, material)
	return Util.solid(f, size, cf, colour, material or M.SmoothPlastic)
end
local function deco(f, size, cf, colour, material)
	local p = Util.deco(f, size, cf, colour, material or M.SmoothPlastic)
	p.CastShadow = false
	return p
end
-- Light sources: long strips and panels are matte (a lit diffuser, no bloom);
-- only small bulbs and lenses are neon, and toned down, so the mall doesn't glow.
local function softLight(p, colour)
	local s = p.Size
	if math.max(s.X, s.Y, s.Z) >= 2.5 then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = colour
	else
		p.Material = Enum.Material.Neon
		p.Color = colour:Lerp(Color3.fromRGB(128, 118, 108), 0.35)
	end
	p.CastShadow = false
	return p
end
-- Round shapes without assets: an ellipsoid (SpecialMesh "Sphere" stretched to
-- the part's size), a head shape, and a tube along local Y.
local function ellipsoid(f, size, cf, colour, material)
	local p = deco(f, size, cf, colour, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
local function headShape(f, size, cf, colour)
	local p = deco(f, size, cf, colour, M.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Parent = p
	return p
end
local function tube(f, len, dia, cf, colour, material)
	-- a cylinder whose axis is the CFrame's Y
	local p = deco(f, V3(len, dia, dia), cf * CFrame.Angles(0, 0, math.rad(90)), colour, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function glow(f, size, cf, colour)
	return softLight(deco(f, size, cf, colour, M.Neon), colour)
end
-- An imported texture over a part's face, tinted (no-op until imported:
-- Shared/Assets, tools/make_mall_textures.py).
local function skin(part, name, studs, tint, face)
	if not part then
		return nil
	end
	local t = Util.texture(part, face or Enum.NormalId.Top, name, studs or 8, studs or 8)
	if t and tint then
		t.Color3 = tint
	end
	return t
end
local FLOOR_TEXTURE = {
	[M.WoodPlanks] = "mall_wood", [M.Wood] = "mall_wood", [M.Marble] = "mall_marble", [M.Limestone] = "mall_marble",
	[M.Concrete] = "mall_concrete", [M.Fabric] = "mall_carpet", [M.SmoothPlastic] = "mall_floor_tile", [M.Slate] = "mall_concrete",
}
local WALL_TEXTURE = {
	[M.WoodPlanks] = "mall_wood", [M.Fabric] = "mall_fabric", [M.Marble] = "mall_marble", [M.Limestone] = "mall_marble",
	[M.SmoothPlastic] = "mall_slatwall", [M.Concrete] = "mall_concrete",
}
Stores.skin = skin
local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end
local function tag(part, name, attrs)
	for k, v in pairs(attrs or {}) do
		part:SetAttribute(k, v)
	end
	CollectionService:AddTag(part, name)
	return part
end
-- A featured item customers can pick up.
local function product(part, productId, key)
	if part and key and productId then
		tag(part, "ShopProduct", { Product = productId, Store = key })
	end
	return part
end
-- A point shoppers walk to and browse at.
local function spot(f, cf, key)
	if not key then
		return
	end
	local p = Util.deco(f, V3(1, 1, 1), cf * CF(0, 0.5, 0), C(255, 255, 255), M.SmoothPlastic)
	p.Transparency = 1
	p.Name = "ShopSpot"
	tag(p, "ShopSpot", { Store = key })
end

local GARMENTS = {
	C(200, 60, 60), C(40, 70, 130), C(236, 236, 232), C(30, 30, 34), C(120, 150, 90), C(230, 180, 60),
	C(150, 110, 170), C(90, 120, 150), C(200, 170, 140), C(120, 80, 60), C(240, 200, 200), C(60, 60, 70),
}
local NEUTRALS = { C(236, 236, 232), C(30, 30, 34), C(200, 190, 176), C(120, 110, 100), C(60, 66, 80), C(160, 160, 164) }
-- The brand being fitted out right now (set by the public builders below), so
-- rails, piles and mannequins pick its clothes when no colours are given.
local BRAND = nil
-- Fully detailed garments per store (the rest are a hook and a body): keeps a
-- big store's fit-out to a few thousand parts.
local FINE_PER_STORE = 50
local FINE_LEFT = FINE_PER_STORE
local FINE_KEY = nil
local function beginStore(key)
	if key ~= FINE_KEY then
		FINE_KEY = key
		FINE_LEFT = FINE_PER_STORE
	end
end
local function clothes(colours)
	return colours or (BRAND and BRAND.clothes) or GARMENTS
end
local BRIGHTS = { C(230, 60, 80), C(250, 200, 40), C(60, 170, 220), C(120, 200, 90), C(240, 130, 40), C(170, 90, 200), C(250, 250, 250) }
local BOOKS = { C(150, 40, 40), C(40, 70, 120), C(220, 200, 160), C(60, 110, 70), C(30, 30, 34), C(230, 180, 60), C(200, 90, 50), C(90, 60, 110), C(240, 236, 226) }

-- One hanging garment on a rail running along local X: a hanger and the
-- garment below it, flat face across the rail (side-hung, as on real rails).
-- Kinds: tee, shirt, knit, dress, coat, trousers; some striped. Up close (d >
-- 0.7) each is its own model tagged "Sway", so it can swing on its hanger
-- (client: ShopMotion), with sleeves, collar, placket, rib hems and buttons.
local GARMENT_KINDS = { "tee", "tee", "shirt", "knit", "knit", "dress", "coat", "trousers" }
local function garment(f, cf, colour, long, d, rng)
	local kinds = (BRAND and BRAND.kinds) or GARMENT_KINDS
	local kind = rng and kinds[rng:NextInteger(1, #kinds)] or (long and "coat" or "tee")
	if long and kind ~= "dress" and not BRAND then
		kind = "coat"
	end
	-- brand kinds that are variations on the basic ones
	local variant = nil
	if kind == "hoodie" or kind == "leggings" or kind == "leather" or kind == "suit" or kind == "graphic" or kind == "sport" or kind == "parka" then
		variant = kind
		kind = ({ hoodie = "knit", leggings = "trousers", leather = "coat", suit = "coat", graphic = "tee", sport = "tee", parka = "coat" })[kind]
	end
	local h = (kind == "coat" or kind == "dress") and 4.2 or (kind == "trousers" and 3.6 or 3)
	if variant == "suit" or variant == "leather" then
		h = 3.2
	elseif variant == "parka" then
		h = 3.9
	elseif variant == "leggings" then
		h = 3.8
	end
	local fine = d > 0.7 and FINE_LEFT > 0
	if fine then
		FINE_LEFT -= 1
	end
	local parent = f
	if fine then
		parent = Instance.new("Model")
		parent.Name = "Garment"
		parent.Parent = f
	end
	local dark = colour:Lerp(C(0, 0, 0), 0.25)
	local light = colour:Lerp(C(255, 255, 255), 0.25)
	-- hanger: hook and bar
	deco(parent, V3(0.08, 0.45, 0.08), cf * CF(0, -0.22, 0), C(40, 40, 44), M.Metal)
	local top = cf * CF(0, -0.55, 0) -- where the garment hangs from
	if fine and kind ~= "trousers" then
		-- rounded shoulders over the hanger
		ellipsoid(parent, V3(0.42, 0.42, 1.78), top * CF(0, -0.12, 0), colour, M.Fabric)
	end
	local body
	if kind == "trousers" then
		local legW = variant == "leggings" and 0.5 or 0.72
		local legZ = variant == "leggings" and 0.3 or 0.42
		for _, z in ipairs({ -legZ, legZ }) do
			body = deco(parent, V3(0.24, h - 0.3, legW), top * CF(0, -0.3 - (h - 0.3) / 2, z), colour, M.Fabric)
		end
		deco(parent, V3(0.26, 0.4, 1.7), top * CF(0, -0.2, 0), colour, M.Fabric)
		if fine then
			deco(parent, V3(0.28, 0.1, 1.72), top * CF(0, -0.05, 0), dark, M.Fabric) -- waistband
		end
	elseif kind == "dress" then
		body = deco(parent, V3(0.26, 1.6, 1.3), top * CF(0, -0.8, 0), colour, M.Fabric)
		deco(parent, V3(0.24, h - 1.5, 2.0), top * CF(0, -1.5 - (h - 1.5) / 2, 0), colour, M.Fabric)
		if fine then
			deco(parent, V3(0.3, 0.14, 1.32), top * CF(0, -1.5, 0), dark, M.Fabric) -- waist tie
		end
	else
		local wid = rng and rng:NextNumber(1.55, 1.8) or 1.7
		body = deco(parent, V3(0.28, h, wid), top * CF(0, -h / 2, 0), colour, M.Fabric)
		if fine then
			-- sleeves down the sides
			local sl = kind == "tee" and 1 or h * 0.8
			for _, z in ipairs({ -1, 1 }) do
				deco(parent, V3(0.24, sl, 0.42), top * CF(0, -0.1 - sl / 2, z * 1.02) * CFrame.Angles(rad(z * 6), 0, 0), colour, M.Fabric)
			end
			if kind == "knit" then
				deco(parent, V3(0.3, 0.35, 1.72), top * CF(0, -h + 0.17, 0), dark, M.Fabric) -- rib hem
			elseif kind == "shirt" then
				deco(parent, V3(0.3, 0.2, 0.7), top * CF(0, -0.05, 0), light, M.Fabric) -- collar
				deco(parent, V3(0.31, h - 0.3, 0.1), top * CF(0, -0.15 - (h - 0.3) / 2, 0), light, M.Fabric) -- placket
			elseif kind == "coat" then
				for _, z in ipairs({ -1, 1 }) do
					deco(parent, V3(0.34, 1.4, 0.18), top * CF(0, -0.75, z * 0.3) * CFrame.Angles(rad(-z * 14), 0, 0), dark, M.Fabric) -- lapels
				end
				deco(parent, V3(0.32, h - 1.6, 0.1), top * CF(0, -1.2 - (h - 1.6) / 2, -0.25), C(30, 28, 26), M.SmoothPlastic) -- buttons
			else -- tee: a contrasting collar rib and maybe a chest print
				deco(parent, V3(0.3, 0.12, 0.55), top * CF(0, -0.05, 0), dark, M.Fabric)
				if rng and rng:NextNumber() < 0.4 then
					deco(parent, V3(0.31, 0.5, 0.6), top * CF(0, -1, 0), pick(rng, { C(250, 250, 250), C(20, 20, 24), C(220, 40, 50) }), M.SmoothPlastic)
				end
			end
			-- the brand variants
			if variant == "hoodie" then
				deco(parent, V3(0.5, 0.75, 0.95), top * CF(0.12, -0.25, 0), colour, M.Fabric) -- hood
				deco(parent, V3(0.03, 0.7, 1.05), top * CF(0.16, -h + 1.0, 0), dark, M.Fabric) -- pocket

			elseif variant == "leather" then
				body.Material = M.Leather
				body.Reflectance = 0.06
				deco(parent, V3(0.31, h - 0.3, 0.05), top * CF(0, -h / 2, 0.1), C(170, 170, 176), M.Metal) -- zip
			elseif variant == "suit" then
				deco(parent, V3(0.31, 0.16, 0.18), top * CF(0, -0.9, -0.55), C(236, 236, 232), M.Fabric) -- pocket square
			elseif variant == "graphic" then
				local ink = pick(rng, { C(250, 250, 250), C(230, 60, 60), C(250, 210, 60), C(80, 200, 220) })
				deco(parent, V3(0.31, 0.95, 1.05), top * CF(0, -1.2, 0), ink, M.SmoothPlastic) -- print
			elseif variant == "sport" then
				local ink = colour:Lerp(C(255, 255, 255), 0.75)
				for _, z in ipairs({ -0.72, 0.72 }) do
					deco(parent, V3(0.31, h - 0.4, 0.1), top * CF(0, -h / 2, z), ink, M.Fabric) -- side panels
				end
			elseif variant == "parka" then
				for k = 1, 2 do
					deco(parent, V3(0.31, 0.08, 1.72), top * CF(0, -k * h / 3, 0), dark, M.Fabric) -- quilting
				end
				deco(parent, V3(0.4, 0.35, 1.1), top * CF(0.05, -0.1, 0), C(226, 214, 190), M.Fabric) -- fur trim
			end
			-- stripes on some
			if rng and kind ~= "coat" and not variant and rng:NextNumber() < 0.25 then
				local sc = colour:Lerp(C(255, 255, 255), 0.7)
				for k = 1, 2 do
					deco(parent, V3(0.3, 0.14, 1.72), top * CF(0, -0.5 - k * (h - 0.8) / 3, 0), sc, M.Fabric)
				end
			end
		end
	end
	if variant == "leather" and body then
		body.Material = M.Leather
	end
	if fine then
		parent.WorldPivot = cf
		CollectionService:AddTag(parent, "Sway")
	end
	return body
end

-- A clothing rail: plinth, uprights, bar, garments along it.
local function rail(f, cf, len, rng, pal, d, colours, key, productId)
	solid(f, V3(len, 0.3, 1.8), cf * CF(0, 0.15, 0), pal.fixture)
	for _, s in ipairs({ -1, 1 }) do
		tube(f, 5.1, 0.2, cf * CF(s * (len / 2 - 0.3), 2.85, 0), pal.metal, M.Metal)
		local foot = deco(f, V3(0.08, 0.8, 0.8), cf * CF(s * (len / 2 - 0.3), 0.34, 0) * CFrame.Angles(0, 0, rad(90)), pal.metal, M.Metal)
		foot.Shape = Enum.PartType.Cylinder
	end
	local bar = deco(f, V3(len, 0.16, 0.16), cf * CF(0, 5.3, 0), pal.metal, M.Metal)
	bar.Shape = Enum.PartType.Cylinder
	local n = math.max(2, math.floor(len / 0.95 * d))
	local base = pick(rng, clothes(colours))
	for k = 1, n do
		-- uneven spacing and a slight twist on each hanger, so a rail reads as
		-- clothes rather than a row of identical slabs
		local x = -len / 2 + 0.5 + (k - 0.5) * (len - 1) / n + rng:NextNumber(-0.12, 0.12)
		local colour = rng:NextNumber() < 0.6 and base or pick(rng, clothes(colours))
		garment(f, cf * CF(x, 5.3, 0) * CFrame.Angles(0, rad(rng:NextNumber(-9, 9)), 0), colour, rng:NextNumber() < 0.2, d, rng)
		if k == math.ceil(n / 2) then
			-- the featured garment
			local hit = deco(f, V3(0.3, 3, 1.7), cf * CF(x, 3.4, 0), colour, M.Fabric)
			hit.Transparency = 1
			product(hit, productId or "tee", key)
		end
	end
end

-- A pile of folded clothes.
local function pile(f, cf, rng, colours, n)
	local c = pick(rng, clothes(colours))
	local h = n * 0.21
	deco(f, V3(1.3, h - 0.06, 1), cf * CF(0, (h - 0.06) / 2, 0), c:Lerp(C(0, 0, 0), 0.12), M.Fabric)
	return deco(f, V3(1.32, 0.08, 1.02), cf * CF(rng:NextNumber(-0.03, 0.03), h - 0.04, 0), c, M.Fabric)
end

-- A display table of folded stock: a top on a plinth, piles in a grid.
local function foldTable(f, cf, w, dep, rng, pal, d, colours, key, productId, height)
	height = height or 2.8
	solid(f, V3(w, height - 0.2, dep), cf * CF(0, (height - 0.2) / 2, 0), pal.wood or pal.fixture, M.Wood)
	solid(f, V3(w + 0.2, 0.2, dep + 0.2), cf * CF(0, height - 0.1, 0), pal.fixture)
	-- rounded long edges and a recessed plinth line
	for _, z in ipairs({ -(dep + 0.2) / 2, (dep + 0.2) / 2 }) do
		tube(f, w + 0.2, 0.22, cf * CF(0, height - 0.1, z) * CFrame.Angles(0, 0, rad(90)), pal.fixture, M.SmoothPlastic)
	end
	deco(f, V3(w - 0.4, 0.3, dep - 0.4), cf * CF(0, 0.15, 0), (pal.wood or pal.fixture):Lerp(C(0, 0, 0), 0.35), M.SmoothPlastic)
	local nx = math.max(1, math.floor(w / 1.6))
	local nz = math.max(1, math.floor(dep / 1.3))
	local first
	for i = 1, nx do
		for j = 1, nz do
			if rng:NextNumber() < 0.5 + 0.5 * d then
				local x = -w / 2 + (i - 0.5) * w / nx
				local z = -dep / 2 + (j - 0.5) * dep / nz
				local top = pile(f, cf * CF(x, height, z), rng, colours, rng:NextInteger(2, 2 + math.floor(3 * d)))
				first = first or top
			end
		end
	end
	product(first, productId or "tee", key)
end

-- A mannequin: plinth, legs, torso, arms and a head, dressed in an outfit:
-- trousers or a skirt, a top, often a jacket worn open over it, a belt, shoes,
-- and sometimes a scarf, a bag on the arm or a hat. Returns its model.
local function mannequin(f, cf, rng, pal, pose, top, bottom)
	-- A display mannequin in smooth shapes: a round base on a rod, tube legs
	-- and arms, a two-part torso with rounded shoulders, an egg head, rounded
	-- shoes; dressed in trousers or a skirt, a top, often an open jacket, a
	-- belt, sometimes a scarf, a bag on the arm or a hat.
	local m = Instance.new("Model")
	m.Name = "Mannequin"
	m.Parent = f
	local skin = C(236, 234, 230)
	top = top or pick(rng, clothes(nil))
	bottom = bottom or pick(rng, BRAND and BRAND.clothes or NEUTRALS)
	local jacket = rng:NextNumber() < 0.55 and pick(rng, BRAND and BRAND.clothes or NEUTRALS) or nil
	local skirt = rng:NextNumber() < 0.3
	local base = solid(m, V3(0.3, 2.2, 2.2), cf * CF(0, 0.15, 0) * CFrame.Angles(0, 0, rad(90)), pal.fixture)
	base.Shape = Enum.PartType.Cylinder
	tube(m, 0.6, 0.12, cf * CF(0, 0.55, 0.35), pal.metal, M.Metal)
	local lean = pose == 1 and 6 or (pose == 2 and -6 or 0)
	local body = cf * CF(0, 0.5, 0) * CFrame.Angles(0, 0, rad(lean / 2))
	local shoeC = pick(rng, { C(30, 30, 32), C(236, 236, 232), C(120, 80, 56) })
	for _, s in ipairs({ -1, 1 }) do
		local leg = body * CF(s * 0.33, 1.75, 0) * CFrame.Angles(0, 0, rad(s * 3))
		tube(m, 3.0, 0.56, leg, skirt and skin or bottom, M.Fabric)
		ellipsoid(m, V3(0.5, 0.36, 1.0), body * CF(s * 0.4, 0.2, -0.15), shoeC, M.SmoothPlastic)
	end
	-- hips, waist, chest, rounded shoulders
	ellipsoid(m, V3(1.35, 0.8, 0.85), body * CF(0, 3.25, 0), skirt and bottom or bottom, M.Fabric)
	if skirt then
		local sk = deco(m, V3(1.6, 1.5, 1.05), body * CF(0, 2.55, 0), bottom, M.Fabric)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Cylinder
		mesh.Parent = sk
	end
	deco(m, V3(1.2, 1.1, 0.76), body * CF(0, 3.85, 0), top, M.Fabric)
	deco(m, V3(1.5, 1.3, 0.86), body * CF(0, 4.75, 0), top, M.Fabric)
	ellipsoid(m, V3(1.75, 0.6, 0.9), body * CF(0, 5.35, 0), jacket or top, M.Fabric)
	deco(m, V3(1.24, 0.18, 0.8), body * CF(0, 3.35, 0), C(50, 36, 28), M.Leather) -- belt
	deco(m, V3(0.18, 0.16, 0.05), body * CF(0, 3.35, -0.42), C(200, 180, 120), M.Metal) -- buckle
	if jacket then
		for _, s in ipairs({ -1, 1 }) do
			deco(m, V3(0.58, 2.5, 0.94), body * CF(s * 0.5, 4.3, 0.02), jacket, M.Fabric)
			deco(m, V3(0.06, 1.1, 0.3), body * CF(s * 0.32, 4.95, -0.48) * CFrame.Angles(0, 0, rad(-s * 18)), jacket:Lerp(C(0, 0, 0), 0.2), M.Fabric) -- lapel
		end
	end
	local sleeve = jacket or top
	for _, s in ipairs({ -1, 1 }) do
		local swing = pose == 1 and s * 18 or (pose == 2 and 8 or s * 6)
		local arm = body * CF(s * 0.92, 5.35, 0) * CFrame.Angles(rad(swing), 0, rad(s * 6))
		tube(m, 2.3, 0.42, arm * CF(0, -1.1, 0), sleeve, M.Fabric)
		local hand = ellipsoid(m, V3(0.3, 0.45, 0.22), arm * CF(0, -2.4, 0), skin, M.SmoothPlastic)
		if s == 1 and rng:NextNumber() < 0.35 then
			-- a bag on the arm, with a strap
			local bagC = pick(rng, { C(120, 80, 56), C(30, 30, 32), C(200, 170, 140), C(170, 40, 50) })
			local bag = deco(m, V3(0.42, 0.95, 1.25), hand.CFrame * CF(0.3, -0.7, 0), bagC, M.Leather)
			local bm = Instance.new("SpecialMesh")
			bm.MeshType = Enum.MeshType.Brick
			bm.Scale = V3(1, 1, 1)
			bm.Parent = bag
			tube(m, 0.75, 0.07, hand.CFrame * CF(0.3, -0.05, 0.3) * CFrame.Angles(rad(35), 0, 0), bagC:Lerp(C(0, 0, 0), 0.3), M.Leather)
			tube(m, 0.75, 0.07, hand.CFrame * CF(0.3, -0.05, -0.3) * CFrame.Angles(rad(-35), 0, 0), bagC:Lerp(C(0, 0, 0), 0.3), M.Leather)
		end
	end
	tube(m, 0.45, 0.36, body * CF(0, 5.75, 0), skin, M.SmoothPlastic) -- neck
	if rng:NextNumber() < 0.3 then
		local sc = pick(rng, BRIGHTS)
		ellipsoid(m, V3(0.95, 0.4, 0.8), body * CF(0, 5.62, 0), sc, M.Fabric) -- scarf
		deco(m, V3(0.3, 1.2, 0.08), body * CF(0.25, 4.95, -0.45), sc, M.Fabric)
	end
	headShape(m, V3(0.85, 1.1, 0.95), body * CF(0, 6.45, 0), skin)
	if rng:NextNumber() < 0.2 then
		local hat = pick(rng, { C(30, 30, 32), C(160, 120, 80), C(200, 60, 60) })
		local brim = deco(m, V3(0.08, 1.5, 1.5), body * CF(0, 6.8, 0) * CFrame.Angles(0, 0, rad(90)), hat, M.Fabric)
		brim.Shape = Enum.PartType.Cylinder
		local crown = deco(m, V3(0.6, 0.95, 0.95), body * CF(0, 7.05, 0) * CFrame.Angles(0, 0, rad(90)), hat, M.Fabric)
		crown.Shape = Enum.PartType.Cylinder
	end
	m.WorldPivot = cf
	return m
end
Stores.mannequin = mannequin
function Stores.useBrand(real)
	BRAND = real and brandFor(string.lower(real)) or nil
end
Stores.garment = garment
Stores.GARMENTS = GARMENTS
Stores.NEUTRALS = NEUTRALS
Stores.BRIGHTS = BRIGHTS

-- A shoe (sole + upper), pointing along local -Z.
local function shoe(f, cf, colour, d)
	deco(f, V3(0.55, 0.18, 1.3), cf * CF(0, 0.09, 0), C(236, 236, 232))
	local up = deco(f, V3(0.52, 0.42, 1.05), cf * CF(0, 0.38, 0.1), colour, M.Fabric)
	if d > 0.7 then
		deco(f, V3(0.5, 0.06, 0.4), cf * CF(0, 0.6, -0.15), colour:Lerp(C(255, 255, 255), 0.4))
	end
	return up
end

-- A wall bay: a back panel with shelves or rails and stock, facing inward.
--   cf: at floor level on the wall line, looking into the store; len along local X.
local function wallBay(f, cf, len, h, rng, pal, d, kind, key, productId)
	deco(f, V3(len, h, 0.3), cf * CF(0, h / 2, 0.15), pal.wall)
	glow(f, V3(len, 0.15, 0.15), cf * CF(0, h - 0.2, -0.2), C(255, 244, 226))
	local first
	if kind == "hang" then
		deco(f, V3(len, 0.15, 0.15), cf * CF(0, 6.6, -1), pal.metal, M.Metal)
		local n = math.max(2, math.floor(len / 0.7 * d))
		local c = pick(rng, GARMENTS)
		for k = 1, n do
			local x = -len / 2 + (k - 0.5) * len / n
			-- side-hung along the wall: rotate so the garment faces into the store
			local g = cf * CF(x, 6.6, -1) * CFrame.Angles(0, rad(90), 0)
			garment(f, g, rng:NextNumber() < 0.5 and c or pick(rng, clothes(nil)), false, d, rng)
		end
		for k = 0, math.floor(len / 2.4) - 1 do
			local x = -len / 2 + 1.2 + k * 2.4
			first = first or pile(f, cf * CF(x, 1.2, -0.8), rng, nil, 3)
			deco(f, V3(2.2, 0.15, 1.4), cf * CF(x, 1.1, -0.8), pal.fixture)
		end
	elseif kind == "shoes" or kind == "bags" or kind == "boxes" or kind == "bottles" or kind == "books" or kind == "toys" or kind == "frames" then
		local rows = kind == "books" and 6 or (kind == "bags" and 3 or 5)
		local gap = (h - 1.2) / rows
		for r = 0, rows - 1 do
			local y = 0.9 + r * gap
			deco(f, V3(len, 0.15, 1.3), cf * CF(0, y, -0.65), pal.fixture)
			local step = kind == "books" and 0.38 or (kind == "bottles" and 0.55 or (kind == "frames" and 0.9 or 1.3))
			local n = math.floor(len / step * (0.6 + 0.4 * d))
			for k = 1, n do
				local x = -len / 2 + (k - 0.5) * len / n
				local at = cf * CF(x, y + 0.08, -0.65)
				local p
				if kind == "shoes" then
					p = shoe(f, at * CFrame.Angles(0, rad(90 + rng:NextNumber(-10, 10)), 0), pick(rng, GARMENTS), d)
				elseif kind == "bags" then
					local c = pick(rng, { C(120, 80, 50), C(30, 30, 32), C(200, 170, 130), C(150, 40, 40), C(236, 226, 210) })
					p = deco(f, V3(1, 0.8, 0.45), at * CF(0, 0.4, 0), c, M.Leather)
					deco(f, V3(0.7, 0.35, 0.06), at * CF(0, 0.95, 0), c, M.Leather)
				elseif kind == "books" then
					local bh = rng:NextNumber(0.7, 1.15)
					p = deco(f, V3(0.32, bh, 0.9), at * CF(0, bh / 2, 0), pick(rng, BOOKS))
				elseif kind == "toys" then
					local s = rng:NextNumber(0.5, 0.9)
					p = deco(f, V3(s, s, s), at * CF(0, s / 2, 0), pick(rng, BRIGHTS))
				elseif kind == "frames" then
					p = deco(f, V3(0.7, 0.22, 0.06), at * CF(0, 0.5, -0.4), pick(rng, { C(20, 20, 20), C(120, 80, 50), C(200, 180, 120), C(80, 30, 30) }))
				elseif kind == "bottles" then
					local bh = rng:NextNumber(0.4, 0.8)
					p = deco(f, V3(0.32, bh, 0.32), at * CF(0, bh / 2, 0), pick(rng, { C(250, 240, 230), C(220, 120, 160), C(40, 40, 44), C(180, 140, 80), C(200, 220, 230) }), M.Glass)
				else -- boxes
					local bw = rng:NextNumber(0.8, 1.2)
					p = deco(f, V3(bw, rng:NextNumber(0.6, 1), 0.8), at * CF(0, 0.45, 0), pick(rng, BRIGHTS))
				end
				first = first or p
			end
		end
	elseif kind == "devices" then
		deco(f, V3(len, 0.12, 1.2), cf * CF(0, 4.2, -0.6), pal.fixture)
		local n = math.floor(len / 1.6)
		for k = 1, n do
			local x = -len / 2 + (k - 0.5) * len / n
			deco(f, V3(0.9, 1.2, 0.12), cf * CF(x, 3.2, -0.3), C(20, 20, 24))
			local box = deco(f, V3(0.9, 0.6, 0.9), cf * CF(x, 4.6, -0.6), C(250, 250, 250))
			first = first or box
		end
	elseif kind == "food" then
		-- a back counter: fridges with drinks
		deco(f, V3(len, 6, 1.8), cf * CF(0, 3, -0.9), C(200, 204, 208), M.Metal)
		local door = deco(f, V3(len - 0.4, 5.2, 0.1), cf * CF(0, 3.2, -1.85), C(200, 230, 240), M.Glass)
		door.Transparency = 0.6
		local n = math.floor(len / 0.5)
		for r = 0, 3 do
			for k = 1, n, 2 do
				local x = -len / 2 + (k - 0.5) * len / n
				deco(f, V3(0.3, 0.8, 0.3), cf * CF(x, 1.2 + r * 1.2, -1.2), pick(rng, { C(200, 40, 40), C(240, 240, 240), C(40, 120, 200), C(250, 180, 30) }))
			end
		end
	end
	product(first, productId, key)
end

-- A till: a counter with tills, a card reader and a stack of the store's bags.
local function cashWrap(f, cf, w, pal, key, accent)
	local counter = solid(f, V3(w, 3.4, 2.4), cf * CF(0, 1.7, 0), pal.fixture)
	local slab = deco(f, V3(w + 0.2, 0.15, 2.6), cf * CF(0, 3.45, 0), C(236, 234, 230), M.Marble)
	skin(slab, "mall_marble", 6)
	tube(f, w + 0.2, 0.2, cf * CF(0, 3.45, 1.3) * CFrame.Angles(0, 0, rad(90)), C(236, 234, 230), M.Marble) -- rounded front edge
	deco(f, V3(w - 0.3, 0.35, 0.2), cf * CF(0, 0.18, 1.22), C(30, 30, 32), M.SmoothPlastic) -- kick recess
	deco(f, V3(w - 0.4, 1, 0.1), cf * CF(0, 2.4, 1.25), accent or pal.accent)
	for _, x in ipairs({ -w / 4, w / 4 }) do
		deco(f, V3(0.3, 0.8, 0.3), cf * CF(x, 3.8, 0.3), C(40, 40, 44), M.Metal)
		local screen = deco(f, V3(1.4, 1, 0.12), cf * CF(x, 4.4, 0.25) * CFrame.Angles(rad(-15), 0, 0), C(20, 22, 26))
		glow(f, V3(1.2, 0.8, 0.02), screen.CFrame * CF(0, 0, -0.07), C(120, 180, 230))
		deco(f, V3(0.4, 0.15, 0.6), cf * CF(x + 0.9, 3.6, 0.8), C(30, 30, 34)) -- card reader
	end
	for k = 0, 3 do
		deco(f, V3(1.2, 0.08, 0.9), cf * CF(w / 2 - 0.9, 3.56 + k * 0.08, 0.3), accent or pal.accent, M.Fabric)
	end
	if key then
		tag(counter, "ShopTill", { Store = key })
		local stand = Util.deco(f, V3(1, 1, 1), cf * CF(0, 0.5, -2.4) * CFrame.Angles(0, math.pi, 0), C(255, 255, 255), M.SmoothPlastic)
		stand.Transparency = 1
		stand.Name = "CashierSpot"
		tag(stand, "ShopCashier", { Store = key })
	end
	return counter
end

-- Fitting rooms along local X: partitions, curtains, a mirror and a seat inside.
local function fittingRooms(f, cf, n, pal, rng)
	local w = 3.6
	for k = 0, n - 1 do
		local x = -(n * w) / 2 + w / 2 + k * w
		solid(f, V3(0.2, 7.5, 4), cf * CF(x - w / 2, 3.75, 2), pal.wall)
		deco(f, V3(w - 0.2, 6.6, 0.15), cf * CF(x, 3.8, 0.1), pick(rng, { pal.accent, C(120, 110, 100), C(70, 60, 56) }), M.Fabric)
		deco(f, V3(1.4, 5, 0.1), cf * CF(x, 3.4, 3.9), C(200, 220, 230), M.Glass).Reflectance = 0.6
		solid(f, V3(1.6, 1.4, 1), cf * CF(x + 1, 0.7, 3.4), pal.wood, M.Wood)
	end
	solid(f, V3(0.2, 7.5, 4), cf * CF((n * w) / 2, 3.75, 2), pal.wall)
end

-- A lit feature wall at the back of the storefront area.
local function featureWall(f, cf, w, pal, rng, video)
	deco(f, V3(w, 10, 0.4), cf * CF(0, 5, 0), pal.accent)
	glow(f, V3(w, 0.2, 0.2), cf * CF(0, 10, -0.3), C(255, 244, 226)) -- cf faces the customers
	if video and w >= 12 then
		local screen = deco(f, V3(math.min(w - 4, 24), math.min(w - 4, 24) * 0.5, 0.2), cf * CF(0, 5.6, -0.35), C(10, 10, 12))
		Billboards.face(screen, Enum.NormalId.Front, Billboards.pick(rng), true)
	end
end

local function floorFinish(f, at, W, D, pal)
	local p = deco(f, V3(W - 0.4, 0.06, D - 0.4), at(0, 0.03, D / 2), pal.floor, pal.floorMat)
	p.Name = "FloorFinish"
	return p
end

local function pendant(f, cf, pal, lit)
	deco(f, V3(0.08, 3, 0.08), cf * CF(0, 1.5, 0), pal.metal, M.Metal)
	local shade = deco(f, V3(1.6, 0.8, 1.6), cf, pal.metal, M.Metal)
	shade.Shape = Enum.PartType.Cylinder
	shade.CFrame = cf * CFrame.Angles(0, 0, rad(90))
	local bulb = glow(f, V3(0.6, 0.3, 0.6), cf * CF(0, -0.45, 0), C(255, 236, 200))
	if lit then
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Brightness = 0.55
		light.Color = C(255, 236, 210)
		light.Shadows = false
		light.Parent = bulb
	end
end

local function plant(f, cf)
	Util.cylinder(f, 1.6, 1.8, cf * CF(0, 0.8, 0), C(236, 234, 228), M.SmoothPlastic, true)
	local crown = deco(f, V3(2.6, 2.8, 2.6), cf * CF(0, 3, 0), C(70, 120, 60), M.LeafyGrass)
	crown.Shape = Enum.PartType.Ball
end

local function bench(f, cf, w, pal)
	solid(f, V3(w, 1.5, 1.6), cf * CF(0, 0.75, 0), pal.accent:Lerp(C(80, 80, 84), 0.5), M.Fabric)
end

local function mirror(f, cf, pal)
	solid(f, V3(2.2, 6.4, 0.3), cf * CF(0, 3.4, 0), pal.wood, M.Wood)
	deco(f, V3(1.9, 6, 0.1), cf * CF(0, 3.4, -0.2), C(210, 226, 234), M.Glass).Reflectance = 0.7
end

-- Long wooden demo table with laptops, tablets and phones (tech flagship).
local function techTable(f, cf, len, pal, rng, d, key)
	solid(f, V3(len, 0.35, 4), cf * CF(0, 2.9, 0), pal.wood, M.Wood)
	for _, s in ipairs({ -1, 1 }) do
		solid(f, V3(0.5, 2.8, 3.4), cf * CF(s * (len / 2 - 1.5), 1.4, 0), pal.wood, M.Wood)
	end
	local n = math.floor(len / 2.6)
	local first
	for k = 1, n do
		local x = -len / 2 + (k - 0.5) * len / n
		for _, side in ipairs({ -1, 1 }) do
			local kind = (k + (side > 0 and 1 or 0)) % 3
			local at = cf * CF(x, 3.08, side * 1.1) * CFrame.Angles(0, side > 0 and math.pi or 0, 0)
			local p
			if kind == 0 then -- laptop
				deco(f, V3(1.6, 0.08, 1.1), at, pal.metal, M.Metal)
				local lid = deco(f, V3(1.6, 1.05, 0.06), at * CF(0, 0.5, 0.55) * CFrame.Angles(rad(-15), 0, 0), pal.metal, M.Metal)
				p = glow(f, V3(1.45, 0.9, 0.02), lid.CFrame * CF(0, 0, -0.04), pick(rng, { C(80, 140, 220), C(220, 120, 160), C(90, 200, 140) }))
				p = product(p, "laptop", key)
			elseif kind == 1 then -- tablet on a stand
				deco(f, V3(0.2, 0.3, 0.6), at * CF(0, 0.15, 0.3), pal.metal, M.Metal)
				local t = deco(f, V3(1.3, 0.95, 0.05), at * CF(0, 0.6, 0.25) * CFrame.Angles(rad(-20), 0, 0), C(30, 30, 32))
				p = product(glow(f, V3(1.2, 0.85, 0.02), t.CFrame * CF(0, 0, -0.03), C(240, 170, 90)), "tablet", key)
			else -- phones
				for j = -1, 1 do
					local ph = deco(f, V3(0.38, 0.78, 0.04), at * CF(j * 0.5, 0.42, 0.2) * CFrame.Angles(rad(-25), 0, 0), C(30, 30, 32))
					local s = glow(f, V3(0.33, 0.7, 0.02), ph.CFrame * CF(0, 0, -0.03), pick(rng, { C(60, 120, 230), C(230, 90, 140), C(80, 200, 150), C(240, 200, 80) }))
					if j == 0 then
						p = product(s, "phone", key)
					end
				end
			end
			first = first or p
		end
		if d > 0.6 then
			for _, side in ipairs({ -1, 1 }) do
				solid(f, V3(1.1, 2.4, 1.1), cf * CF(x, 1.2, side * 3), C(230, 230, 228)) -- stool
			end
		end
	end
	return first
end

-- A beauty gondola: tiered shelves of small products, a lit header, testers.
local function beautyGondola(f, cf, len, pal, rng, d, key, goods)
	solid(f, V3(len, 4.8, 2.6), cf * CF(0, 2.4, 0), pal.fixture)
	glow(f, V3(len, 0.2, 2.8), cf * CF(0, 4.9, 0), C(255, 250, 240))
	local first
	for _, side in ipairs({ -1, 1 }) do
		for r = 0, 2 do
			local y = 1.6 + r * 1.1
			deco(f, V3(len - 0.3, 0.1, 0.5), cf * CF(0, y, side * 1.5), pal.fixture)
			local n = math.floor((len - 0.6) / 0.35 * (0.5 + 0.5 * d))
			for k = 1, n do
				local x = -len / 2 + 0.3 + (k - 0.5) * (len - 0.6) / n
				local h = rng:NextNumber(0.35, 0.75)
				local p = deco(f, V3(0.24, h, 0.24), cf * CF(x, y + 0.05 + h / 2, side * 1.5), pick(rng, goods or { C(220, 120, 160), C(240, 200, 200), C(180, 60, 90), C(250, 240, 230), C(40, 40, 44), C(200, 160, 120) }))
				first = first or p
			end
		end
	end
	-- a mirror on the end, a tester tray on top
	deco(f, V3(0.1, 2.2, 1.8), cf * CF(len / 2 + 0.06, 6.1, 0), C(210, 226, 234), M.Glass).Reflectance = 0.7
	product(first, "lipstick", key)
end

-- A jewellery case: dark body, glass top, a velvet tray of rings and pendants.
local function jewelCase(f, cf, len, pal, rng, key, productId)
	solid(f, V3(len, 3, 2.2), cf * CF(0, 1.5, 0), pal.fixture)
	deco(f, V3(len - 0.2, 0.1, 2), cf * CF(0, 3.05, 0), pal.accent:Lerp(C(30, 30, 30), 0.5), M.Fabric)
	local first
	local n = math.floor(len / 0.6)
	for k = 1, n do
		local x = -len / 2 + (k - 0.5) * len / n
		local z = (k % 2 == 0) and 0.4 or -0.4
		local item = glow(f, V3(0.22, 0.22, 0.22), cf * CF(x, 3.2, z), pick(rng, { C(255, 220, 120), C(240, 240, 250), C(200, 230, 255), C(255, 180, 200) }))
		item.Shape = Enum.PartType.Ball
		first = first or item
	end
	local g = deco(f, V3(len, 1.2, 2.2), cf * CF(0, 3.65, 0), C(220, 236, 244), M.Glass)
	g.Transparency = 0.75
	product(first, productId or "ring", key)
end

-- A double-sided shelving gondola of boxed goods (pharmacy, toys, books).
local function gondola(f, cf, len, pal, rng, d, kind, key, productId)
	solid(f, V3(len, 5.6, 0.6), cf * CF(0, 2.8, 0), pal.fixture)
	deco(f, V3(len, 0.6, 0.8), cf * CF(0, 6, 0), pal.accent)
	local first
	for _, side in ipairs({ -1, 1 }) do
		for r = 0, 3 do
			local y = 0.5 + r * 1.3
			deco(f, V3(len, 0.12, 1.2), cf * CF(0, y, side * 0.9), pal.fixture)
			local step = kind == "books" and 0.38 or 0.9
			local n = math.floor(len / step * (0.5 + 0.5 * d))
			for k = 1, n do
				local x = -len / 2 + (k - 0.5) * len / n
				local p
				if kind == "books" then
					local h = rng:NextNumber(0.7, 1.1)
					p = deco(f, V3(0.32, h, 0.9), cf * CF(x, y + 0.06 + h / 2, side * 0.9), pick(rng, BOOKS))
				else
					local h = rng:NextNumber(0.5, 1)
					p = deco(f, V3(0.8, h, 0.7), cf * CF(x, y + 0.06 + h / 2, side * 0.9), pick(rng, kind == "toys" and BRIGHTS or { C(250, 250, 250), C(80, 140, 200), C(220, 80, 80), C(120, 190, 140), C(250, 210, 80) }))
				end
				first = first or p
			end
		end
	end
	product(first, productId, key)
end

-- A café/food counter: base, top, a glass case of treats, machines, a menu board.
local function foodCounter(f, cf, w, pal, rng, key, productId, kind)
	solid(f, V3(w, 3.6, 2.6), cf * CF(0, 1.8, 0), pal.fixture, M.Wood)
	deco(f, V3(w + 0.2, 0.15, 2.8), cf * CF(0, 3.65, 0), pal.accent)
	-- the glass case
	local caseW = math.min(6, w / 2)
	deco(f, V3(caseW, 1.6, 2.2), cf * CF(-w / 4, 4.5, 0), C(220, 236, 244), M.Glass).Transparency = 0.6
	local first
	for k = 0, 5 do
		local item = deco(f, V3(0.7, 0.4, 0.7), cf * CF(-w / 4 - caseW / 2 + 0.6 + k * (caseW - 1.2) / 5, 3.95, (k % 2 == 0) and -0.4 or 0.4), pick(rng, { C(214, 160, 90), C(190, 140, 80), C(240, 220, 180), C(120, 70, 40), C(240, 200, 210) }))
		first = first or item
	end
	-- machines on the back side
	if kind == "coffee" then
		local m = solid(f, V3(2.4, 1.8, 1.4), cf * CF(w / 4, 4.6, 0.4), C(190, 192, 196), M.Metal)
		for k = -1, 1, 2 do
			deco(f, V3(0.3, 0.4, 0.3), m.CFrame * CF(k * 0.6, -0.9, -0.7), C(40, 40, 44), M.Metal)
		end
		deco(f, V3(0.8, 1.4, 0.8), cf * CF(w / 4 + 1.8, 4.4, 0.4), C(30, 30, 32), M.Metal) -- grinder
	elseif kind == "tea" then
		for k = 0, 3 do
			deco(f, V3(0.7, 1.4, 0.7), cf * CF(w / 4 - 1.2 + k * 0.9, 4.4, 0.6), pick(rng, { C(214, 180, 140), C(240, 220, 200), C(120, 170, 90), C(220, 120, 140) }), M.Glass)
		end
	else
		deco(f, V3(2.6, 1.4, 1.6), cf * CF(w / 4, 4.4, 0.4), C(170, 172, 176), M.Metal) -- grill / fryer
		glow(f, V3(2.4, 0.2, 1.4), cf * CF(w / 4, 6.2, 0.4), C(255, 150, 80)) -- heat lamp
	end
	product(first, productId, key)
end

local function menuBoard(f, cf, w, pal, rng)
	local board = deco(f, V3(w, 3.2, 0.3), cf, C(20, 20, 22))
	for k = 0, 2 do
		glow(f, V3(w / 3 - 0.4, 2.6, 0.05), board.CFrame * CF(-w / 3 + k * w / 3, 0, -0.18), pick(rng, { C(240, 120, 60), C(250, 220, 120), C(200, 230, 255), C(250, 250, 250) }))
	end
end

-- A dining set: a table with two to four chairs.
local function diningSet(f, cf, pal, rng, seats)
	solid(f, V3(2.8, 0.2, 2.8), cf * CF(0, 2.6, 0), pal.wood, M.Wood)
	deco(f, V3(0.4, 2.5, 0.4), cf * CF(0, 1.25, 0), pal.metal, M.Metal)
	for k = 0, (seats or 2) - 1 do
		local a = k * math.pi * 2 / (seats or 2)
		local c = cf * CFrame.Angles(0, a, 0) * CF(0, 0, 2.3)
		solid(f, V3(1.4, 0.2, 1.4), c * CF(0, 1.6, 0), pal.accent:Lerp(pal.wood, 0.5), M.Fabric)
		deco(f, V3(1.4, 1.6, 0.2), c * CF(0, 2.4, 0.6), pal.accent:Lerp(pal.wood, 0.5), M.Fabric)
	end
end

-- A booth: two benches with backs and a table between.
local function booth(f, cf, pal)
	for _, s in ipairs({ -1, 1 }) do
		solid(f, V3(5, 1.6, 2), cf * CF(0, 0.8, s * 2.4), pal.accent:Lerp(C(60, 30, 26), 0.5), M.Leather)
		solid(f, V3(5, 3, 0.6), cf * CF(0, 2.6, s * 3.3), pal.accent:Lerp(C(60, 30, 26), 0.5), M.Leather)
	end
	solid(f, V3(4.4, 0.25, 2.2), cf * CF(0, 2.7, 0), pal.wood, M.Wood)
	deco(f, V3(0.5, 2.6, 0.5), cf * CF(0, 1.3, 0), pal.metal, M.Metal)
end

-- An ATM.
local function atm(f, cf, pal)
	solid(f, V3(2.4, 5.6, 1.6), cf * CF(0, 2.8, 0), C(70, 74, 80), M.Metal)
	glow(f, V3(1.4, 1, 0.05), cf * CF(0, 4, -0.82), C(120, 190, 240))
	deco(f, V3(1.2, 0.5, 0.4), cf * CF(0, 3, -0.9), C(40, 40, 44))
	deco(f, V3(2.4, 0.6, 1.7), cf * CF(0, 5.9, 0), pal.accent)
end

-- A record bin of LPs.
local function recordBin(f, cf, len, rng, d, key)
	solid(f, V3(len, 2.6, 2.4), cf * CF(0, 1.3, 0), C(120, 90, 64), M.Wood)
	local n = math.floor(len / 0.18 * (0.4 + 0.6 * d))
	local first
	for k = 1, n do
		local x = -len / 2 + 0.2 + (k - 0.5) * (len - 0.4) / n
		local p = deco(f, V3(0.06, 1.2, 1.2), cf * CF(x, 3.1, 0) * CFrame.Angles(0, 0, rad(rng:NextNumber(-6, 6))), pick(rng, BRIGHTS))
		first = first or p
	end
	product(first, "vinyl", key)
end

---------------------------------------------------------------------------
-- What each kind of store sells and how its floor is laid out
---------------------------------------------------------------------------
local SELLS = {
	fashion = { "tee", "jeans", "hoodie", "dress", "jacket", "shirt" },
	premium = { "suit", "shirt", "tie", "jacket" },
	intimates = { "lingerie", "perfume", "tee" },
	sports = { "sneakers", "hoodie", "leggings", "cap", "jacket" },
	outdoor = { "parka", "jacket", "backpack", "boots" },
	footwear = { "sneakers", "boots", "heels" },
	tech = { "phone", "laptop", "tablet", "earbuds", "phonecase" },
	telco = { "phone", "phonecase", "charger", "earbuds" },
	beauty = { "lipstick", "perfume", "skincare", "soap", "candle" },
	jewellery = { "ring", "necklace", "charm", "watch" },
	bags = { "handbag", "backpack", "suitcase" },
	books = { "book", "notebook", "toy" },
	toys = { "toy", "blindbox", "plush" },
	records = { "vinyl" },
	pharmacy = { "vitamins", "snacks", "water", "skincare" },
	optical = { "glasses", "sunglasses" },
	cafe = { "latte", "coffee", "pastry" },
	bubble = { "bubbletea" },
	dessert = { "cookie", "chocolate", "gelato", "popcorn", "pastry" },
	quick = { "meal", "burger", "pizza", "noodles", "sushi" },
	restaurant = { "meal" },
	bank = {},
	dept = { "jacket", "dress", "perfume", "handbag", "shirt" },
}
Stores.SELLS = SELLS

local function sells(design, rng)
	local list = SELLS[design.arch] or SELLS.fashion
	if #list == 0 then
		return nil
	end
	return pick(rng, list)
end

local function registerStore(key, design, at, W, D, tenant)
	if not key then
		return
	end
	local centre = at(0, 0, D / 2).Position
	Stores.registry[key] = {
		name = tenant and tenant.name or design.name,
		colour = design.pal.accent,
		centre = centre,
		radius = math.max(W, D) / 2 + 8,
		arch = design.arch,
	}
end

-- The storefront fit-out for one store, in the box frame from Interiors:
-- at(x, y, z) with x across the front (-W/2..W/2) and z inward (0..D).
function Stores.front(shop, at, W, D, rng, design, key, tenant)
	BRAND = design and design.brand or nil
	beginStore(key)
	local pal, arch = design.pal, design.arch
	registerStore(key, design, at, W, D, tenant)
	floorFinish(shop, at, W, D, pal)
	local clear = 6 -- doorway kept open
	local aisle = 3.5
	local backZ = math.max(clear + 4, D - 1.5)
	local wide = W >= 16

	-- Pendant lights over the storefront area (two cast light).
	for k = -1, 1, 2 do
		if W >= 10 then
			pendant(shop, at(k * W / 4, 13, math.min(D * 0.45, 20)), pal, true)
		end
	end
	spot(shop, at(0, 0, math.min(D - 3, clear + 4)), key)

	if arch == "quick" or arch == "cafe" or arch == "bubble" or arch == "dessert" then
		local kind = (arch == "cafe") and "coffee" or (arch == "bubble" and "tea" or "food")
		local counterZ = math.min(D - 3, math.max(clear + 2, D * 0.45))
		foodCounter(shop, at(0, 0, counterZ) * CFrame.Angles(0, math.pi, 0), math.min(W - 2, 16), pal, rng, key, sells(design, rng), kind)
		cashWrap(shop, at(math.min(W / 2 - 3, 7), 0, counterZ - 3.2), 4, pal, key)
		menuBoard(shop, at(0, 9, math.min(D - 0.6, counterZ + 4)) * CFrame.Angles(0, math.pi, 0), math.min(W - 2, 14), pal, rng)
		if D > counterZ + 6 then
			deco(shop, V3(math.min(W - 2, 16), 6, 2), at(0, 3, counterZ + 3.5), C(190, 192, 196), M.Metal) -- back kitchen line
		end
		if arch ~= "quick" and W >= 14 then
			for k = -1, 1, 2 do
				diningSet(shop, at(k * (W / 2 - 3), 0, clear + 1), pal, rng, 2)
			end
		end
		return
	end
	if arch == "restaurant" then
		cashWrap(shop, at(-W / 2 + 4, 0, clear + 1), 4, pal, key) -- host stand / till
		local rows = math.floor((D - clear - 6) / 8)
		for r = 0, rows - 1 do
			for _, s in ipairs({ -1, 1 }) do
				if W / 2 - 4 > aisle + 2 then
					booth(shop, at(s * (W / 2 - 4), 0, clear + 6 + r * 8), pal)
				end
			end
		end
		-- the bar along the back
		solid(shop, V3(math.min(W - 4, 20), 3.6, 2.4), at(0, 1.8, backZ - 3), pal.wood, M.Wood)
		deco(shop, V3(math.min(W - 4, 20), 7, 1), at(0, 4.5, backZ - 0.2), pal.accent:Lerp(C(30, 20, 16), 0.6))
		for k = 0, math.floor(math.min(W - 4, 20) / 0.6) - 1 do
			deco(shop, V3(0.3, 1, 0.3), at(-math.min(W - 4, 20) / 2 + 0.4 + k * 0.6, 5.4, backZ - 0.8), pick(rng, { C(90, 140, 70), C(150, 60, 40), C(200, 170, 90), C(60, 40, 30) }), M.Glass)
		end
		return
	end
	if arch == "bank" then
		local n = math.max(1, math.floor((W - 4) / 6))
		for k = 0, n - 1 do
			local x = -W / 2 + 3 + (k + 0.5) * (W - 6) / n
			solid(shop, V3(5, 3.6, 2.4), at(x, 1.8, backZ - 2), pal.fixture)
			deco(shop, V3(4.6, 3, 0.15), at(x, 5.2, backZ - 2.6), C(220, 236, 244), M.Glass).Transparency = 0.6
			glow(shop, V3(1.2, 0.8, 0.05), at(x, 4.3, backZ - 1.1), C(120, 190, 240))
		end
		for k = -1, 1, 2 do
			if W >= 12 then
				atm(shop, at(k * (W / 2 - 2), 0, clear + 1), pal)
			end
		end
		deco(shop, V3(math.min(W - 2, 16), 1.2, 0.3), at(0, 9, backZ - 0.3), pal.accent)
		return
	end

	-- Retail: a window display up front, the till, fixtures on either side of the
	-- aisle, a feature wall at the back.
	local item = sells(design, rng)
	local tillW = math.min(8, math.max(4, W / 4))
	local tillX = W / 2 - tillW / 2 - 1
	cashWrap(shop, at(tillX, 0, math.max(clear + 3, backZ - 6)), tillW, pal, key)
	featureWall(shop, at(-tillW / 2, 0, backZ) * CFrame.Angles(0, math.pi, 0), math.max(6, W - tillW - 4), pal, rng, arch == "sports" or arch == "tech" or arch == "telco" or arch == "fashion")

	-- window display: mannequins (fashion), a product plinth otherwise
	if arch == "fashion" or arch == "premium" or arch == "intimates" or arch == "sports" or arch == "outdoor" or arch == "dept" then
		for k = -1, 1, 2 do
			if W >= 14 then
				mannequin(shop, at(k * (W / 2 - 3), 0, 2.4) * CFrame.Angles(0, math.pi, 0), rng, pal, (k + 3) % 3)
			end
		end
	end

	-- the floor: rows of fixtures either side of the aisle
	local z = clear + 2
	local side = W / 2 - aisle
	local row = 0
	while z < backZ - 7 and side > 3 do
		for _, s in ipairs({ -1, 1 }) do
			local x = s * (aisle + side / 2)
			if s > 0 and z > math.max(clear + 3, backZ - 6) - 4 then
				continue -- keep clear of the till
			end
			local cf = at(x, 0, z + 2)
			local len = math.min(side - 1, 9)
			if arch == "tech" then
				techTable(shop, cf, len, pal, rng, 1, key)
			elseif arch == "telco" then
				techTable(shop, cf, math.min(len, 6), pal, rng, 0.5, key)
			elseif arch == "beauty" then
				beautyGondola(shop, cf, len, pal, rng, 1, key, design.palName == "rustic" and { C(120, 180, 90), C(230, 120, 160), C(240, 200, 90), C(90, 150, 200) } or nil)
			elseif arch == "jewellery" then
				jewelCase(shop, cf, math.min(len, 6), pal, rng, key, item)
			elseif arch == "bags" then
				foldTable(shop, cf, math.min(len, 6), 3, rng, pal, 1, nil, key, item, 3)
			elseif arch == "books" then
				gondola(shop, cf, len, pal, rng, 1, "books", key, "book")
			elseif arch == "toys" then
				gondola(shop, cf, len, pal, rng, 1, "toys", key, item)
			elseif arch == "records" then
				recordBin(shop, cf, math.min(len, 6), rng, 1, key)
			elseif arch == "pharmacy" then
				gondola(shop, cf, len, pal, rng, 1, "boxes", key, item)
			elseif arch == "optical" then
				foldTable(shop, cf, math.min(len, 5), 2.6, rng, pal, 1, { C(20, 20, 20), C(120, 80, 50) }, key, "glasses", 3)
				mirror(shop, cf * CF(0, 0, 2.2), pal)
			elseif arch == "footwear" then
				foldTable(shop, cf, math.min(len, 6), 3, rng, pal, 1, nil, key, "sneakers", 1.8)
				bench(shop, cf * CF(0, 0, 3), math.min(len, 5), pal)
			elseif row % 2 == 0 then
				rail(shop, cf, len, rng, pal, 1, nil, key, item)
			else
				foldTable(shop, cf, math.min(len, 6), 3.2, rng, pal, 1, nil, key, item)
			end
			spot(shop, cf * CF(0, 0, -2.6), key)
		end
		z += 8
		row += 1
	end
	-- fitting rooms for clothing stores with the depth for them
	if (arch == "fashion" or arch == "premium" or arch == "intimates" or arch == "sports" or arch == "dept") and W >= 18 and D >= 26 then
		fittingRooms(shop, at(-W / 2 + 6, 0, backZ - 5) * CFrame.Angles(0, math.pi, 0), 3, pal, rng)
	end
	if W >= 12 then
		plant(shop, at(-W / 2 + 1.6, 0, clear + 0.5))
	end
end

-- One fixture on the deep sales floor (lighter detail).
function Stores.field(shop, cf, rng, k, design, key)
	BRAND = design and design.brand or nil
	beginStore(key)
	local pal, arch = design.pal, design.arch
	local d = 0.5
	local item = sells(design, rng)
	if k % 6 == 0 then
		spot(shop, cf * CF(0, 0, -3), key)
	end
	if arch == "tech" then
		techTable(shop, cf, 6, pal, rng, d, key)
	elseif arch == "telco" then
		techTable(shop, cf, 4, pal, rng, d, key)
	elseif arch == "beauty" then
		beautyGondola(shop, cf, 5, pal, rng, d, key)
	elseif arch == "jewellery" then
		jewelCase(shop, cf, 4, pal, rng, key, item)
	elseif arch == "books" then
		gondola(shop, cf, 5, pal, rng, d, "books", key, "book")
	elseif arch == "toys" then
		gondola(shop, cf, 5, pal, rng, d, "toys", key, item)
	elseif arch == "pharmacy" then
		gondola(shop, cf, 5.5, pal, rng, d, "boxes", key, item)
	elseif arch == "records" then
		recordBin(shop, cf, 5, rng, d, key)
	elseif arch == "optical" then
		foldTable(shop, cf, 4, 2.4, rng, pal, d, { C(20, 20, 20), C(120, 80, 50) }, key, "glasses", 3)
	elseif arch == "footwear" then
		foldTable(shop, cf, 5, 2.8, rng, pal, d, nil, key, "sneakers", 1.8)
	elseif arch == "quick" or arch == "cafe" or arch == "bubble" or arch == "dessert" or arch == "restaurant" then
		diningSet(shop, cf, pal, rng, 4)
	elseif arch == "bank" then
		bench(shop, cf, 5, pal)
	elseif arch == "dept" and k % 4 == 3 then
		beautyGondola(shop, cf, 5, pal, rng, d, key)
	elseif k % 5 == 4 and (arch == "fashion" or arch == "sports" or arch == "dept" or arch == "premium") then
		mannequin(shop, cf, rng, pal, k % 3)
	elseif k % 3 == 2 then
		foldTable(shop, cf, 5, 3, rng, pal, d, nil, key, item)
	else
		rail(shop, cf, 6, rng, pal, d, nil, key, item)
	end
end

---------------------------------------------------------------------------
-- The shell of a store: floor, ceiling, wall finishes and its lighting
---------------------------------------------------------------------------
-- How each kind of store is finished and lit.
--   ceiling: the dropped ceiling's tone; wallMat: the inner walls' finish;
--   lights: "track" spots on rails, "linear" LED strips, "panel" flat panels,
--   "chandelier" or "pendant" fittings.
local SHELL = {
	fashion = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "track" },
	intimates = { ceiling = "white", wallMat = M.Fabric, lights = "chandelier" },
	premium = { ceiling = "dark", wallMat = M.WoodPlanks, lights = "pendant" },
	dept = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "track" },
	sports = { ceiling = "dark", wallMat = M.Concrete, lights = "linear" },
	outdoor = { ceiling = "dark", wallMat = M.WoodPlanks, lights = "pendant" },
	footwear = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "track" },
	tech = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "panel" },
	telco = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "linear" },
	beauty = { ceiling = "dark", wallMat = M.SmoothPlastic, lights = "linear" },
	jewellery = { ceiling = "white", wallMat = M.Marble, lights = "chandelier" },
	bags = { ceiling = "white", wallMat = M.Marble, lights = "track" },
	books = { ceiling = "white", wallMat = M.WoodPlanks, lights = "pendant" },
	toys = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "panel" },
	records = { ceiling = "dark", wallMat = M.Brick, lights = "pendant" },
	pharmacy = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "panel" },
	optical = { ceiling = "white", wallMat = M.WoodPlanks, lights = "track" },
	cafe = { ceiling = "dark", wallMat = M.Brick, lights = "pendant" },
	bubble = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "pendant" },
	dessert = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "pendant" },
	quick = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "panel" },
	restaurant = { ceiling = "dark", wallMat = M.WoodPlanks, lights = "pendant" },
	bank = { ceiling = "white", wallMat = M.Marble, lights = "panel" },
}
-- A few stores get their own look (matched on the real tenant, never shown):
-- the H&M stand-in's terracotta ceiling baffles strung with bulbs over a warm
-- peach floor; the Uniqlo stand-in's pale wood floor under bright panels.
local SHELL_BY_REAL = {
	["h m"] = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "baffle", floor = C(238, 214, 190), floorMat = M.SmoothPlastic },
	["h & m"] = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "baffle", floor = C(238, 214, 190), floorMat = M.SmoothPlastic },
	["uniqlo"] = { ceiling = "white", wallMat = M.SmoothPlastic, lights = "panel", floor = C(206, 172, 132), floorMat = M.WoodPlanks },
}
local REAL_LIGHTS = 4 -- PointLights per store; the other fittings just glow
local LIGHT_EVERY = 13 -- studs between ceiling fittings

-- How high this store's ceiling is: the underside of whatever is above its floor.
local function ceilingHeight(shop, centre)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shop }
	local hit = workspace:Raycast(centre + V3(0, 3, 0), V3(0, 30, 0), params)
	local h = hit and (hit.Position.Y - centre.Y) or 18
	return math.clamp(h - 1.2, 10, 17)
end

-- One ceiling fitting of the store's lighting scheme, hung from height `at`.
local function fitting(f, at, style, pal, lit, rng)
	local light
	if style == "track" then
		deco(f, V3(8, 0.2, 0.2), at, C(40, 40, 44), M.Metal)
		for k = -1, 1 do
			local can = tube(f, 0.9, 0.5, at * CF(k * 3, -0.6, 0) * CFrame.Angles(rad(k == 0 and 20 or -25 * k), 0, 0), C(30, 30, 32), M.Metal)
			-- the can's axis is its local X (a cylinder): the lens sits on its end
			local lens = glow(f, V3(0.05, 0.42, 0.42), can.CFrame * CF(-0.47, 0, 0), C(255, 240, 214))
			lens.Shape = Enum.PartType.Cylinder
			if k == 0 then
				light = lens
			end
		end
	elseif style == "baffle" then
		-- A terracotta felt baffle on rods, with bulbs dropping on cords below it.
		local tone = pick(rng, { C(206, 120, 84), C(184, 98, 70), C(222, 150, 112), C(150, 84, 64) })
		for _, s in ipairs({ -3.5, 3.5 }) do
			deco(f, V3(0.06, 1.2, 0.06), at * CF(s, -0.6, 0), C(220, 220, 220), M.Metal)
		end
		deco(f, V3(10, 0.5, 2.6), at * CF(0, -1.45, 0), tone, M.Fabric)
		for k = -2, 2 do
			local drop = 1.9 + ((k * 7) % 3) * 0.45
			deco(f, V3(0.04, drop - 1.7, 0.04), at * CF(k * 2, -1.7 - (drop - 1.7) / 2, 0.6), C(40, 40, 40), M.SmoothPlastic)
			local bulb = glow(f, V3(0.4, 0.4, 0.4), at * CF(k * 2, -drop - 0.1, 0.6), C(255, 232, 196))
			bulb.Shape = Enum.PartType.Ball
			if k == 0 then
				light = bulb
			end
		end
	elseif style == "linear" then
		deco(f, V3(10.2, 0.15, 0.8), at, C(40, 40, 44), M.Metal)
		light = glow(f, V3(10, 0.25, 0.6), at * CF(0, -0.15, 0), C(236, 244, 255))
	elseif style == "panel" then
		deco(f, V3(4.2, 0.15, 4.2), at, C(220, 220, 220), M.Metal)
		light = glow(f, V3(3.8, 0.08, 3.8), at * CF(0, -0.1, 0), C(248, 250, 255))
	elseif style == "chandelier" then
		deco(f, V3(0.08, 2, 0.08), at * CF(0, -1, 0), pal.metal, M.Metal)
		local ring = deco(f, V3(0.3, 3.4, 3.4), at * CF(0, -2.1, 0) * CFrame.Angles(0, 0, rad(90)), pal.metal, M.Metal)
		ring.Shape = Enum.PartType.Cylinder
		for k = 0, 7 do
			local a = k * math.pi / 4
			local drop = glow(f, V3(0.2, 0.6, 0.2), at * CF(math.cos(a) * 1.5, -2.6, math.sin(a) * 1.5), C(255, 246, 220))
			light = light or drop
		end
		for k = 0, 5 do
			local a = k * math.pi / 3 + 0.3
			deco(f, V3(0.12, 0.9, 0.12), at * CF(math.cos(a) * 0.9, -2.9 - (k % 2) * 0.4, math.sin(a) * 0.9), C(230, 240, 250), M.Glass)
		end
	else -- pendant
		deco(f, V3(0.06, 2.4, 0.06), at * CF(0, -1.2, 0), pal.metal, M.Metal)
		local shade = deco(f, V3(1.2, 1.6, 1.6), at * CF(0, -2.8, 0) * CFrame.Angles(0, 0, rad(90)), pick(rng, { pal.metal, pal.accent, C(30, 30, 32) }), M.Metal)
		shade.Shape = Enum.PartType.Cylinder
		light = glow(f, V3(0.7, 0.3, 0.7), at * CF(0, -3.55, 0), C(255, 226, 180))
	end
	if lit and light then
		local l = Instance.new("PointLight")
		l.Range = 24
		l.Brightness = 0.55
		l.Color = (style == "linear" or style == "panel") and C(236, 242, 255) or C(255, 234, 204)
		l.Shadows = false
		l.Parent = light
	end
end

-- A store's floor, ceiling, wall finishes and lighting, from its traced floor
-- (unit.floor: rects {u0, v0, u1, v1} in plan feet) and its inner walls.
--   walls: { { a = Vector3, b = Vector3, inward = Vector3 } } on the wall line
function Stores.shell(shop, unit, P, S, y, design, key, walls, rng)
	local spec = SHELL_BY_REAL[design.real or ""] or SHELL[design.arch] or SHELL.fashion
	local inside = design.brand and design.brand.inside
	if inside then
		spec = table.clone(spec)
		spec.ceiling = inside.ceiling or spec.ceiling
		spec.wallMat = inside.wallMat or spec.wallMat
		spec.lights = inside.lights or spec.lights
		spec.floor = inside.floor or spec.floor
		spec.floorMat = inside.floorMat or spec.floorMat
	end
	local pal = design.pal
	local rects = unit.floor or {}
	if #rects == 0 then
		return 0
	end
	local big, bigA = rects[1], 0
	for _, r in ipairs(rects) do
		local a = (r[3] - r[1]) * (r[4] - r[2])
		if a > bigA then
			big, bigA = r, a
		end
	end
	local centre = P((big[1] + big[3]) / 2, (big[2] + big[4]) / 2, y)
	local h = ceilingHeight(shop, centre)
	local ceilingY = y + h
	local ceilingColour = spec.ceiling == "dark" and C(34, 34, 38) or C(232, 225, 214)
	local parts = 0

	local shell = Instance.new("Folder")
	shell.Name = "Shell"
	shell.Parent = shop
	local lit = 0
	for _, r in ipairs(rects) do
		local a, b = P(r[1], r[2], y), P(r[3], r[4], y)
		local sizeX, sizeZ = math.abs(b.X - a.X), math.abs(b.Z - a.Z)
		if sizeX >= 0.5 and sizeZ >= 0.5 then
			local mid = (a + b) / 2
			local fl = deco(shell, V3(sizeX, 0.08, sizeZ), CF(mid.X, y + 0.04, mid.Z), spec.floor or pal.floor, spec.floorMat or pal.floorMat)
			fl.Name = "StoreFloor"
			local floorMat = spec.floorMat or pal.floorMat
			skin(fl, FLOOR_TEXTURE[floorMat] or "mall_floor_tile", floorMat == M.WoodPlanks and 10 or 12, spec.floor or pal.floor)
			local ce = deco(shell, V3(sizeX, 0.3, sizeZ), CF(mid.X, ceilingY + 0.15, mid.Z), ceilingColour, M.SmoothPlastic)
			ce.Name = "StoreCeiling"
			if spec.ceiling ~= "dark" then
				skin(ce, "mall_ceiling_tile", 4, ceilingColour, Enum.NormalId.Bottom)
			end
			parts += 2
			if sizeX >= 6 and sizeZ >= 6 then
				local nx = math.max(1, math.floor(sizeX / LIGHT_EVERY))
				local nz = math.max(1, math.floor(sizeZ / LIGHT_EVERY))
				for i = 1, nx do
					for j = 1, nz do
						local px = mid.X - sizeX / 2 + (i - 0.5) * sizeX / nx
						local pz = mid.Z - sizeZ / 2 + (j - 0.5) * sizeZ / nz
						local real = lit < REAL_LIGHTS and (i + j) % 2 == 0
						if real then
							lit += 1
						end
						fitting(shell, CF(px, ceilingY, pz), spec.lights, pal, real, rng)
						parts += 6
					end
				end
			end
		end
	end

	-- Inner walls: cladding up to the ceiling, a baseboard, a top trim and a
	-- cove light under it.
	for _, w in ipairs(walls or {}) do
		local len = (w.b - w.a).Magnitude
		if len >= 3 then
			local mid = (w.a + w.b) / 2 + w.inward * 0.15
			local cf = CFrame.lookAt(mid, mid + w.inward) -- -Z into the store
			local wallC = pal.wall:Lerp(C(214, 198, 176), 0.22)
			local clad = deco(shell, V3(len, h, 0.2), cf * CF(0, h / 2, 0), wallC, spec.wallMat)
			skin(clad, WALL_TEXTURE[spec.wallMat] or "mall_slatwall", spec.wallMat == M.SmoothPlastic and 6 or 8, wallC, Enum.NormalId.Front)
			deco(shell, V3(len, 0.7, 0.3), cf * CF(0, 0.35, -0.12), pal.wall:Lerp(C(20, 20, 22), 0.5))
			deco(shell, V3(len, 0.4, 0.4), cf * CF(0, h - 0.2, -0.15), pal.wall:Lerp(C(255, 255, 255), 0.3))
			glow(shell, V3(len, 0.1, 0.1), cf * CF(0, h - 0.5, -0.3), C(255, 240, 220))
			parts += 4
		end
	end

	-- Floor decor: a rug and ottomans in clothing and premium stores, hanging
	-- banners in sports stores.
	if (design.arch == "premium" or design.arch == "intimates" or design.arch == "fashion" or design.arch == "dept") and bigA >= 400 then
		deco(shell, V3(8, 0.06, 6), CF(centre.X, y + 0.11, centre.Z), pal.accent:Lerp(C(240, 236, 230), 0.6), M.Fabric).Name = "Rug"
		for _, s in ipairs({ -1, 1 }) do
			solid(shell, V3(2.4, 1.6, 2.4), CF(centre.X + s * 2.4, y + 0.8, centre.Z), pal.accent:Lerp(C(80, 70, 66), 0.5), M.Fabric).Name = "Ottoman"
		end
		parts += 3
	elseif design.arch == "sports" and bigA >= 400 then
		for _, s in ipairs({ -1, 1 }) do
			deco(shell, V3(0.2, 6, 4), CF(centre.X + s * 6, ceilingY - 4, centre.Z), pal.accent, M.Fabric).Name = "Banner"
		end
		parts += 2
	end
	return parts
end

-- A wall run (full detail): mid point on the wall line, along it, inward.
local WALL_KIND = {
	fashion = "hang", premium = "hang", intimates = "hang", sports = "shoes", outdoor = "hang", dept = "hang",
	footwear = "shoes", tech = "devices", telco = "devices", beauty = "bottles", jewellery = "bags", bags = "bags",
	books = "books", toys = "toys", records = "books", pharmacy = "boxes", optical = "frames",
	cafe = "food", bubble = "food", dessert = "food", quick = "food", restaurant = "food", bank = nil,
}
function Stores.wall(shop, mid, along, inward, len, rng, design, key)
	BRAND = design and design.brand or nil
	beginStore(key)
	local kind = WALL_KIND[design.arch]
	if not kind or len < 3 then
		return false
	end
	local cf = CFrame.lookAt(mid, mid + inward) -- local X along the wall, -Z into the store
	local h = (kind == "books" or kind == "hang") and 8 or 7
	local productId = sells(design, rng)
	if kind == "shoes" then
		productId = "sneakers"
	elseif kind == "books" then
		productId = design.arch == "records" and "vinyl" or "book"
	elseif kind == "frames" then
		productId = "glasses"
	end
	wallBay(shop, cf, len, h, rng, design.pal, 1, kind, key, productId)
	return true
end


---------------------------------------------------------------------------
-- The flagship fit-out (the H&M stand-in's floors, from the store photos): a
-- cream aisle with a steel inlay through the middle, the floor either side in
-- zones of rails, terrazzo plinths of folded stock, peach podiums with
-- mannequins, white shelf units with arched mirrors and mannequins on top,
-- round racks; brown felt discs hung over the aisle; one long wall in red
-- vertical slats. Laid on the unit's fill grid (Data: fill, fillAxis), so it
-- never runs into the walls.
---------------------------------------------------------------------------
local FLAG = {
	knit = { C(120, 52, 36), C(176, 120, 60), C(206, 150, 60), C(60, 80, 56), C(40, 56, 90), C(236, 230, 218), C(150, 70, 50), C(90, 60, 50), C(200, 180, 150) },
	peach = C(232, 170, 130),
	terracotta = C(196, 92, 64),
	cream = C(246, 238, 226),
	terrazzo = C(226, 200, 186),
	red = C(186, 46, 36),
	felt = { C(120, 80, 64), C(150, 104, 84), C(196, 160, 132), C(90, 62, 52) },
}
local FLAG_PAL = { fixture = C(244, 240, 234), metal = C(200, 200, 204), wall = C(244, 240, 234), wood = C(230, 214, 192) }

function Stores.isFlagship(design)
	local r = design and design.real or ""
	return r == "h m" or r == "h & m"
end

-- Terrazzo: a speckled block (chips on its two long faces).
local function terrazzo(f, size, cf, rng)
	local b = solid(f, size, cf, FLAG.terrazzo, M.Marble)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		skin(b, "mall_terrazzo", 3, nil, face)
	end
	for _ = 1, 6 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local chip = deco(f, V3(0.22, 0.18, 0.04), cf * CF(rng:NextNumber(-size.X / 2 + 0.3, size.X / 2 - 0.3), rng:NextNumber(-size.Y / 2 + 0.3, size.Y / 2 - 0.3), side * (size.Z / 2 + 0.01)), pick(rng, { C(150, 70, 56), C(90, 60, 52), C(246, 240, 232), C(196, 120, 96) }))
		chip.Rotation = chip.Rotation + V3(0, 0, rng:NextNumber(0, 90))
	end
	return b
end

local FIX = {}
-- Two rails back to back.
function FIX.rails(f, cf, rng, d, key, pid)
	for _, s in ipairs({ -1, 1 }) do
		rail(f, cf * CF(0, 0, s * 1.15) * CFrame.Angles(0, s < 0 and 0 or math.pi, 0), 6.5, rng, FLAG_PAL, d, FLAG.knit, key, pid)
	end
end
-- A tall terrazzo plinth beside a low one, both stacked with folded knits.
function FIX.plinths(f, cf, rng, d, key, pid)
	local tall = terrazzo(f, V3(2.4, 3.6, 2.2), cf * CF(-1.9, 1.8, 0), rng)
	local low = terrazzo(f, V3(4, 2.4, 2.6), cf * CF(1.4, 1.2, 0), rng)
	deco(f, V3(2.5, 0.08, 2.3), cf * CF(-1.9, 3.64, 0), C(236, 226, 214), M.Wood)
	deco(f, V3(4.1, 0.08, 2.7), cf * CF(1.4, 2.44, 0), C(236, 226, 214), M.Wood)
	local first = pile(f, cf * CF(-1.9, 3.68, 0), rng, FLAG.knit, 4)
	for _, x in ipairs({ 0.4, 2.4 }) do
		for _, z in ipairs({ -0.6, 0.6 }) do
			pile(f, cf * CF(x, 2.48, z), rng, FLAG.knit, rng:NextInteger(2, 4))
		end
	end
	product(first, pid, key)
	return tall, low
end
-- A peach podium with a mannequin; some turn slowly.
function FIX.podium(f, cf, rng)
	local m = Instance.new("Model")
	m.Name = "Podium"
	m.Parent = f
	local disc = solid(m, V3(0.8, 3.2, 3.2), cf * CF(0, 0.4, 0) * CFrame.Angles(0, 0, rad(90)), FLAG.peach)
	disc.Shape = Enum.PartType.Cylinder
	for _, a in ipairs({ 0, 90 }) do
		deco(m, V3(3.4, 0.25, 0.5), cf * CF(0, 0.12, 0) * CFrame.Angles(0, rad(a), 0), FLAG.terracotta)
	end
	local o = pick(rng, FLAG.knit)
	mannequin(m, cf * CF(0, 0.8, 0) * CFrame.Angles(0, math.pi, 0), rng, { fixture = FLAG.peach, metal = FLAG_PAL.metal }, rng:NextInteger(0, 2), o, pick(rng, NEUTRALS))
	m.WorldPivot = cf
	if rng:NextNumber() < 0.3 then
		m:SetAttribute("Speed", 12)
		CollectionService:AddTag(m, "Spin")
	end
end
-- A white shelf unit: folded stock in cubbies, an arched mirror at one end,
-- a mannequin standing on top.
function FIX.shelfUnit(f, cf, rng, d, key, pid)
	local W, H, D = 6, 6.6, 1.8
	solid(f, V3(W, H, 0.2), cf * CF(0, H / 2, 0.8), FLAG_PAL.fixture)
	for _, x in ipairs({ -W / 2, -W / 6, W / 6, W / 2 }) do
		deco(f, V3(0.15, H, D), cf * CF(x, H / 2, 0), FLAG_PAL.fixture)
	end
	local first
	for k, yy in ipairs({ 0.2, 2.3, 4.4, H }) do
		deco(f, V3(W, 0.15, D), cf * CF(0, yy, 0), FLAG_PAL.fixture)
		if yy < H then
			for _, x in ipairs({ -W / 3, 0, W / 3 }) do
				if rng:NextNumber() < 0.5 + 0.4 * d then
					local p = pile(f, cf * CF(x, yy + 0.08, -0.1), rng, FLAG.knit, rng:NextInteger(3, 6))
					first = first or p
				end
			end
		end
	end
	glow(f, V3(W - 0.3, 0.06, 0.1), cf * CF(0, H - 0.2, -0.7), C(255, 240, 220))
	-- arched mirror on the end
	local mirror = deco(f, V3(0.12, 5, 2.2), cf * CF(W / 2 + 0.3, 2.9, 0), C(200, 214, 222), M.Glass)
	mirror.Reflectance = 0.5
	local top = deco(f, V3(0.12, 2.2, 2.2), cf * CF(W / 2 + 0.3, 5.4, 0) * CFrame.Angles(0, rad(90), 0), C(200, 214, 222), M.Glass)
	top.Shape = Enum.PartType.Cylinder
	top.Reflectance = 0.5
	deco(f, V3(0.2, 0.3, 2.4), cf * CF(W / 2 + 0.3, 0.25, 0), FLAG_PAL.wood, M.Wood)
	if d > 0.7 then
		mannequin(f, cf * CF(-W / 4, H + 0.05, 0), rng, FLAG_PAL, rng:NextInteger(0, 2), pick(rng, FLAG.knit), pick(rng, NEUTRALS))
	end
	product(first, pid, key)
end
-- A round rack: garments all the way round a ring.
function FIX.round(f, cf, rng, d, key, pid)
	local base = solid(f, V3(0.3, 3.8, 3.8), cf * CF(0, 0.15, 0) * CFrame.Angles(0, 0, rad(90)), C(220, 220, 222), M.Metal)
	base.Shape = Enum.PartType.Cylinder
	deco(f, V3(0.25, 4.6, 0.25), cf * CF(0, 2.6, 0), C(200, 200, 204), M.Metal)
	local ring = deco(f, V3(0.12, 3.6, 3.6), cf * CF(0, 4.9, 0) * CFrame.Angles(0, 0, rad(90)), C(200, 200, 204), M.Metal)
	ring.Shape = Enum.PartType.Cylinder
	local colour = pick(rng, FLAG.knit)
	local n = d > 0.7 and 10 or 6
	local first
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local g = garment(f, cf * CFrame.Angles(0, a, 0) * CF(0, 4.9, -1.7), rng:NextNumber() < 0.6 and colour or pick(rng, FLAG.knit), false, d, rng)
		first = first or g
	end
	local hit = deco(f, V3(3, 3, 3), cf * CF(0, 3.4, 0), colour)
	hit.Transparency = 1
	product(hit, pid, key)
end

local ORDER = { "rails", "plinths", "rails", "podium", "shelfUnit", "round" }

function Stores.flagship(shop, unit, P, S, y, design, key, rng)
	beginStore(key)
	BRAND = nil -- the flagship dresses its own floor (FLAG colours)
	local spots, axis = unit.fill, unit.fillAxis
	if not spots or not axis or #spots == 0 then
		return 0
	end
	local f = Instance.new("Folder")
	f.Name = "Flagship"
	f.Parent = shop
	local list = SELLS.fashion
	-- grid coordinates: across (axis[1], axis[2]) and inward (axis[3], axis[4])
	local pts, aMin, bMin = {}, math.huge, math.huge
	for _, pt in ipairs(spots) do
		local a = pt[1] * axis[1] + pt[2] * axis[2]
		local b = pt[1] * axis[3] + pt[2] * axis[4]
		table.insert(pts, { pt = pt, a = a, b = b })
		aMin, bMin = math.min(aMin, a), math.min(bMin, b)
	end
	local cols = {}
	for _, q in ipairs(pts) do
		q.col = math.floor((q.a - aMin) / 9 + 0.5)
		q.row = math.floor((q.b - bMin) / 9 + 0.5)
		cols[q.col] = true
	end
	local colList = {}
	for c in pairs(cols) do
		table.insert(colList, c)
	end
	table.sort(colList)
	local aisle = colList[math.max(1, math.ceil(#colList / 2))]
	local origin = P(0, 0, y)
	local inward = P(axis[3], axis[4], y) - origin
	inward = V3(inward.X, 0, inward.Z).Unit
	local fine = #pts <= 70
	local hCache = nil
	local parts = 0
	for k, q in ipairs(pts) do
		local p = P(q.pt[1], q.pt[2], y)
		local cf = CFrame.lookAt(p, p + inward)
		local near = (q.b - bMin) < 32 -- the floor nearest the front gets full detail
		local d = (fine or near) and 1 or 0.55
		local inAisle
		if unit.aisle then
			-- an explicit aisle: { u, v, du, dv, half width } (plan feet)
			local al = unit.aisle
			local du, dv = q.pt[1] - al[1], q.pt[2] - al[2]
			inAisle = math.abs(du * al[4] - dv * al[3]) <= al[5]
		else
			inAisle = q.col == aisle or q.row % 5 == 3
		end
		if inAisle then
			-- aisle: a cream runner with the steel inlay, felt discs overhead
			deco(f, V3(9.2 * S, 0.06, 9.2 * S), cf * CF(0, 0.11, 0), FLAG.cream, M.SmoothPlastic).Name = "AisleTile"
			if q.col == aisle or unit.aisle then
				deco(f, V3(0.3, 0.07, 9.2 * S), cf * CF(0, 0.12, 0), C(150, 150, 156), M.Metal).Name = "SteelInlay"
				if k % 2 == 0 then
					hCache = hCache or ceilingHeight(shop, p)
					for i, dx in ipairs({ -2.6, 0.4, 3.2 }) do
						local disc = deco(f, V3(0.2, 4.2 - i * 0.4, 4.2 - i * 0.4), cf * CF(dx, hCache - 2.6 - (i % 2) * 0.8, -1 + i) * CFrame.Angles(0, rad(90 + i * 25), 0), pick(rng, FLAG.felt), M.Fabric)
						disc.Shape = Enum.PartType.Cylinder
						deco(f, V3(0.04, 1.2 + (i % 2) * 0.8, 0.04), disc.CFrame * CF(0, disc.Size.Y / 2 + 0.4, 0), C(60, 60, 60))
					end
				end
			end
			parts += 1
		else
			local kind = ORDER[(q.row * 2 + q.col) % #ORDER + 1]
			local ok, err = pcall(FIX[kind], f, cf, rng, d, key, pick(rng, list))
			if ok then
				spot(f, cf * CF(0, 0, -3.2), key)
				parts += 1
			else
				warn("[Stores] flagship " .. kind .. ": " .. tostring(err))
			end
		end
	end
	return parts
end

-- One long wall in red vertical slats over a low white plinth, mannequins
-- standing along it. mid/along/inward as for Stores.wall.
function Stores.slatWall(shop, mid, along, inward, len, rng)
	local f = Instance.new("Folder")
	f.Name = "SlatWall"
	f.Parent = shop
	local cf = CFrame.lookAt(mid, mid + along) -- X across the wall, Z along
	local face = CFrame.fromMatrix(mid, along, V3(0, 1, 0), -inward) -- X along, -Z into the store
	local h = 9
	deco(f, V3(len, h, 0.3), face * CF(0, h / 2, 0.2), FLAG.red, M.SmoothPlastic)
	local n = math.min(60, math.floor(len / 0.7))
	for k = 0, n - 1 do
		local x = -len / 2 + (k + 0.5) * len / n
		deco(f, V3(0.28, h, 0.35), face * CF(x, h / 2, -0.1), FLAG.red:Lerp(C(0, 0, 0), 0.12), M.Wood)
	end
	solid(f, V3(len, 1.4, 2.2), face * CF(0, 0.7, -1.2), FLAG_PAL.fixture)
	for x = -len / 2 + 4, len / 2 - 4, math.max(6, len / 5) do
		mannequin(f, face * CF(x, 1.4, -1.2), rng, FLAG_PAL, rng:NextInteger(0, 2), pick(rng, FLAG.knit), pick(rng, NEUTRALS))
	end
	return cf ~= nil
end


Stores.cashWrap = cashWrap
Stores.FLAG = FLAG
Stores.FLAG_PAL = FLAG_PAL


---------------------------------------------------------------------------
-- Storefronts on the mall side (init.lua calls this for each shop front edge):
-- pilasters at the ends, a sign band over the opening with the name in
-- lettering, a dark reveal and the roll-down grille's housing under it,
-- mullions in the display glass with low plinths behind, a blade sign out over
-- the corridor, and an entry mat. Three looks, from the galleria photos:
--   stone: limestone piers, a dark bronze band with light lettering (fashion,
--          books, premium and the like)
--   metal: a dark metal portal, the band in the brand colour (sports, tech,
--          telecoms, toys, records)
--   white: white lacquer piers, a white band with the name in the brand
--          colour (beauty, pharmacy, food, banks; jewellery in marble)
---------------------------------------------------------------------------
local FRONT_LOOK = {
	fashion = "stone", premium = "charcoal", intimates = "stone", dept = "stone", outdoor = "stone", footwear = "stone",
	books = "stone", optical = "stone", bags = "charcoal",
	sports = "metal", tech = "metal", telco = "metal", toys = "metal", records = "metal",
	beauty = "white", pharmacy = "white", jewellery = "charcoal", bank = "white",
	cafe = "white", bubble = "white", dessert = "white", quick = "white", restaurant = "stone",
}
local LIMESTONE = C(214, 198, 166)
local BRONZE = C(52, 44, 38)

-- a, b: the front's ends on the floor (world); out: toward the corridor;
-- top: the storey's height; header: where the header starts; open: whether
-- the middle 60% is an opening (with display glass either side).
function Stores.storefront(parent, a, b, out, y, top, header, design, name, isSign, open)
	local len = (b - a).Magnitude
	if len < 4 then
		return false
	end
	local look = FRONT_LOOK[design.arch] or "stone"
	local pal = design.pal
	local f = Instance.new("Folder")
	f.Name = "Front"
	f.Parent = parent
	local mid = (a + b) / 2
	mid = V3(mid.X, y, mid.Z)
	local cf = CFrame.lookAt(mid, mid + out) -- X along the front, -Z out
	local pierC, pierM, bandC, ink
	if look == "metal" then
		pierC, pierM, bandC, ink = C(38, 40, 44), M.Metal, pal.accent, C(255, 255, 255)
	elseif look == "charcoal" then
		-- dark grey stone with gold lettering (the luxury fronts in the photos)
		pierC, pierM, bandC, ink = C(70, 70, 74), M.Slate, C(58, 58, 62), C(214, 184, 120)
	elseif look == "white" then
		pierC, pierM = design.arch == "jewellery" and C(236, 232, 226) or C(242, 242, 240), design.arch == "jewellery" and M.Marble or M.SmoothPlastic
		bandC, ink = C(246, 246, 244), pal.accent
	else
		pierC, pierM, bandC, ink = LIMESTONE, M.Limestone, BRONZE, C(236, 224, 196)
	end
	-- the brand's own finish, where it has one
	local bf = design.brand and design.brand.front
	local font = look == "stone" and Enum.Font.Bodoni or Enum.Font.GothamMedium
	if bf then
		pierC, pierM = bf.pier or pierC, bf.pierMat or (bf.pier and M.SmoothPlastic) or pierM
		bandC, ink, font = bf.band or bandC, bf.ink or ink, bf.font or font
		look = "brand"
	end
	local extra = bf and bf.extra
	if design.eatery then
		-- the Urban Eatery's counters (photos): stainless piers, a dark sign
		-- band with a light grid over it and a red line along the top, counters
		-- lit blue at the foot, menu screens behind
		pierC, pierM, bandC, ink, font = C(192, 194, 198), M.Metal, C(52, 58, 70), C(255, 255, 255), Enum.Font.GothamBold
		look, extra = "brand", "eatery"
	end
	local pierW = math.min(1.8, len * 0.12)
	-- piers
	for _, s in ipairs({ -1, 1 }) do
		local pier = Util.deco(f, V3(pierW, top - 0.2, 0.9), cf * CF(s * (len / 2 - pierW / 2), (top - 0.2) / 2, -0.35), pierC, pierM)
		if extra == "stripes" then
			-- referee stripes up the piers
			for k = 0, math.floor(pierW / 0.3) - 1 do
				if k % 2 == 0 then
					deco(f, V3(0.15, top - 0.4, 0.92), pier.CFrame * CF(-pierW / 2 + 0.15 + k * 0.3, 0, 0), C(244, 244, 244))
				end
			end
		elseif extra == "stickers" then
			for _ = 1, 10 do
				local sc = pick(Random.new(), { C(250, 210, 40), C(230, 60, 90), C(70, 200, 230), C(120, 220, 90), C(250, 250, 250) })
				local st = deco(f, V3(0.5, 0.5, 0.05), pier.CFrame * CF(math.random() * (pierW - 0.6) - (pierW - 0.6) / 2, math.random() * 8 - 2, -0.47) * CFrame.Angles(0, 0, math.rad(math.random(-25, 25))), sc)
				st.Name = "Sticker"
			end
		elseif extra == "screens" then
			local scr = deco(f, V3(pierW - 0.2, 6, 0.1), pier.CFrame * CF(0, 0, -0.48), C(10, 10, 12))
			pcall(function()
				Billboards.face(scr, Enum.NormalId.Front, Billboards.pick(Random.new()), true)
			end)
		end
		if look == "stone" then
			for yy = 3, top - 2, 3 do
				deco(f, V3(pierW + 0.04, 0.06, 0.94), cf * CF(s * (len / 2 - pierW / 2), yy, -0.35), C(186, 170, 140)) -- stone joints
			end
		end
	end
	local inner = len - pierW * 2
	-- sign band, reveal, grille housing
	local bandH = math.min(4.2, top - header - 0.3)
	local band = deco(f, V3(inner, bandH, 0.4), cf * CF(0, header + bandH / 2, -0.45), bandC, look == "metal" and M.Metal or M.SmoothPlastic)
	band.Name = "SignBand"
	deco(f, V3(inner, 0.35, 0.6), cf * CF(0, header - 0.1, -0.35), C(36, 36, 40), M.Metal)
	deco(f, V3(inner * (open and 0.62 or 0.9), 0.7, 0.8), cf * CF(0, header - 0.65, 0.45), C(70, 72, 78), M.Metal).Name = "GrilleBox"
	if isSign then
		local plate = deco(f, V3(math.min(inner * 0.8, 3 + #name * 0.9), bandH * 0.62, 0.05), cf * CF(0, header + bandH / 2, -0.7), bandC)
		plate.Transparency = 1
		local gui = Util.sign(plate, Enum.NormalId.Front, string.upper(name), ink, font)
		gui.LightInfluence = 0
		-- a soft wash down the band from a slim light bar
		deco(f, V3(inner * 0.9, 0.18, 0.35), cf * CF(0, header + bandH + 0.15, -1.0), C(60, 60, 64), M.Metal)
		softLight(deco(f, V3(inner * 0.88, 0.06, 0.2), cf * CF(0, header + bandH + 0.04, -1.0), C(255, 240, 220)), C(255, 240, 220))
		-- blade sign out over the corridor
		if len >= 14 then
			local bx = len / 2 - pierW - 1
			deco(f, V3(0.12, 0.12, 2.4), cf * CF(bx, header + 1.9, -1.6), C(40, 40, 44), M.Metal)
			local blade = deco(f, V3(0.3, 2, 2.2), cf * CF(bx, header + 0.75, -2.0), look == "white" and pal.accent or bandC, M.SmoothPlastic)
			blade.Name = "BladeSign"
			for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
				local g = Util.sign(blade, face, name, look == "white" and C(255, 255, 255) or ink, Enum.Font.GothamBold)
				g.LightInfluence = 0
			end
		end
	end
	-- brand extras on the band
	if extra == "eatery" then
		for x = -inner / 2 + 1.2, inner / 2 - 1.2, 1.2 do
			deco(f, V3(0.05, bandH, 0.05), cf * CF(x, header + bandH / 2, -0.68), C(140, 156, 180))
		end
		deco(f, V3(inner, 0.05, 0.05), cf * CF(0, header + bandH * 0.5, -0.68), C(140, 156, 180))
		deco(f, V3(inner + pierW * 2, 0.35, 0.3), cf * CF(0, top - 0.3, -0.6), C(200, 40, 40)).Name = "RedLine"
		-- menu screens on the back wall, seen over the counter
		for x = -inner / 3, inner / 3, inner / 3 do
			local scr = deco(f, V3(math.min(4, inner / 3.4), 2.2, 0.1), cf * CF(x, header - 3.2, 5.5), C(20, 24, 34))
			scr.Name = "MenuScreen"
			softLight(deco(f, V3(scr.Size.X - 0.3, 1.8, 0.03), scr.CFrame * CF(0, 0, -0.07), C(70, 120, 200)), C(70, 120, 200))
		end
	elseif extra == "neon" then
		for _, yy in ipairs({ header + 0.05, header + bandH - 0.05 }) do
			local n = deco(f, V3(inner, 0.12, 0.12), cf * CF(0, yy, -0.7), ink, M.Neon)
			n.Name = "NeonTrim"
		end
	elseif extra == "wood" then
		for x = -inner / 2 + 0.4, inner / 2 - 0.4, 0.8 do
			deco(f, V3(0.35, bandH, 0.25), cf * CF(x, header + bandH / 2, -0.75), C(176, 138, 98), M.Wood)
		end
	elseif extra == "bars" then
		for k = -1, 1, 2 do
			deco(f, V3(1.4, bandH * 0.9, 0.06), cf * CF(-inner / 2 + 2 + k * 0.9, header + bandH / 2, -0.7) * CFrame.Angles(0, 0, math.rad(-20)), C(244, 244, 244))
		end
	end
	-- mullions and display plinths in the glass either side of the opening
	if open then
		local opening = math.clamp(len * 0.6, 7, len - 4)
		for _, s in ipairs({ -1, 1 }) do
			local x0, x1 = s * (opening / 2), s * (inner / 2)
			local w = math.abs(x1 - x0)
			if w >= 2 then
				local xm = (x0 + x1) / 2
				deco(f, V3(w, 0.9, 2.2), cf * CF(xm, 0.45, 1.4), pal.fixture)
				if extra == "eatery" then
					-- counters, blue-lit at the foot
					Util.solid(f, V3(w, 3.4, 2.2), cf * CF(xm, 1.7, 1.4), C(236, 234, 230), M.SmoothPlastic)
					deco(f, V3(w, 0.15, 2.4), cf * CF(xm, 3.48, 1.4), C(190, 192, 196), M.Metal)
					local led = deco(f, V3(w, 0.18, 0.1), cf * CF(xm, 0.35, 0.25), C(60, 140, 255), M.Neon)
					led.Name = "CounterLED"
				end
				if extra == "machines" then
					-- old sewing machines along the window (the goth label's windows)
					for x = math.min(x0, x1) + 1.2, math.max(x0, x1) - 1.2, 2.4 do
						local m = cf * CF(x, 0.9, 1.4)
						deco(f, V3(1.4, 0.25, 0.7), m * CF(0, 0.13, 0), C(26, 24, 24), M.Metal)
						deco(f, V3(0.3, 0.8, 0.4), m * CF(0.5, 0.6, 0), C(26, 24, 24), M.Metal)
						deco(f, V3(1.2, 0.3, 0.4), m * CF(0, 1.05, 0), C(26, 24, 24), M.Metal)
						deco(f, V3(0.12, 0.5, 0.12), m * CF(-0.45, 0.65, 0), C(200, 170, 90), M.Metal)
						local wheel = deco(f, V3(0.1, 0.6, 0.6), m * CF(0.68, 0.95, 0) * CFrame.Angles(0, math.rad(90), 0), C(40, 36, 32), M.Metal)
						wheel.Shape = Enum.PartType.Cylinder
					end
				elseif extra == "louvers" then
					-- dark wooden shutters behind the glass
					for yy = 1, header - 1, 0.7 do
						deco(f, V3(w, 0.45, 0.08), cf * CF(xm, yy, 0.5) * CFrame.Angles(math.rad(35), 0, 0), C(60, 44, 32), M.Wood)
					end
				end
				deco(f, V3(w, 0.06, 2.2), cf * CF(xm, 0.93, 1.4), pal.accent:Lerp(C(255, 255, 255), 0.6))
				for x = math.min(x0, x1) + 3.5, math.max(x0, x1) - 1, 3.5 do
					deco(f, V3(0.14, header - 0.2, 0.25), cf * CF(x, (header - 0.2) / 2, 0), C(70, 72, 78), M.Metal)
				end
				-- door posts at the opening
				deco(f, V3(0.3, header - 0.2, 0.4), cf * CF(x0, (header - 0.2) / 2, 0), C(60, 62, 66), M.Metal)
			end
		end
		deco(f, V3(math.min(opening, 10), 0.05, 2.6), cf * CF(0, 0.03, 1.6), C(46, 46, 50), M.Fabric).Name = "EntryMat"
	end
	-- a tall fabric banner hung beside the sign on big fronts (photos: the book
	-- store's navy banners), the name running down it
	if isSign and len >= 24 and top >= 18 then
		local bx = -(len / 2 - pierW - 1.6)
		local bh = math.min(9, top - 3)
		local banner = deco(f, V3(2.4, bh, 0.12), cf * CF(bx, top - 1.2 - bh / 2, -1.3), look == "white" and pal.accent or (look == "stone" and C(34, 44, 74) or bandC), M.Fabric)
		banner.Name = "Banner"
		deco(f, V3(2.8, 0.15, 0.15), cf * CF(bx, top - 1.1, -1.3), C(40, 40, 44), M.Metal)
		deco(f, V3(0.1, 0.1, 1.2), cf * CF(bx, top - 1.1, -0.75), C(40, 40, 44), M.Metal)
		local letters = {}
		for ch in string.gmatch(string.upper(string.split(name, " ")[1] or name), ".") do
			table.insert(letters, ch)
		end
		local g = Util.sign(banner, Enum.NormalId.Front, table.concat(letters, string.char(10)), C(255, 255, 255), Enum.Font.GothamBold)
		g.LightInfluence = 0.3
		Util.sign(banner, Enum.NormalId.Back, table.concat(letters, string.char(10)), C(255, 255, 255), Enum.Font.GothamBold).LightInfluence = 0.3
	end
	-- the corridor's dark border band, a few feet out along the front (photos)
	local fb = deco(f, V3(len, 0.04, 1.6), cf * CF(0, 0.02, -3.4), C(82, 84, 90), M.Slate)
	fb.Name = "FloorBand"
	return true
end
Stores.softLight = softLight


---------------------------------------------------------------------------
-- Sorrel Studio's own escalators (unit B212: Levels 1-3, street Level 3 on top).
-- Two banks side by side along the store, scissor-fashion: Level 1 up to 2 in
-- one lane, Level 2 up to 3 in the next. WELLS: the floor cut out over each
-- (plan rects {u0, v0, u1, v1}, by level); the store's fit-out keeps clear.
---------------------------------------------------------------------------
-- Each bank sits in a lane the plans leave clear of the store's own inside
-- walls (stockrooms, fitting rooms) on every floor it passes: found by
-- rasterising B212's floor and walls on Levels 1-3 (44 x 15 ft lanes).
Stores.STORE_ESCALATORS = {
	{ from = 2, to = 3, bottom = { 1328, 139.5 }, top = { 1364, 139.5 } },
	{ from = 1, to = 2, bottom = { 1352, 109.5 }, top = { 1316, 109.5 } },
}
Stores.WELLS = {
	[3] = { { 1328, 133, 1364, 146 } },
	[2] = { { 1316, 103, 1352, 116 } },
	-- (not the store's) Level 1 down to the Urban Eatery at the north end of
	-- the concourse: an escalator pair and a staircase side by side, in a well
	-- that takes in the small opening the plan already has there.
	[1] = { { 1234, 88, 1270, 110 } }, -- clear of the concourse's north wall (u 1275-1277)
}
-- The mall's own escalators added here (with directories and the food court
-- sign like the plan's): Level 1 down to the Urban Eatery.
Stores.MALL_ESCALATORS = {
	{ from = 0, to = 1, bottom = { 1234, 95 }, top = { 1270, 95 } },
}
-- Stairs beside it: { from, to, bottom {u, v}, top {u, v}, width (ft) }.
Stores.MALL_STAIRS = {
	{ from = 0, to = 1, bottom = { 1234, 105.5 }, top = { 1270, 105.5 }, width = 6 },
}
-- Where an escalator arrives at a well's edge, that stretch has no railing.
local WELL_OPEN = {
	[3] = { { 1364, 133, 1364, 146 } },
	[2] = { { 1316, 103, 1316, 116 } },
	[1] = { { 1270, 88, 1270, 110 } },
}

-- Openings at an angle (plan feet): from (u, v), `len` along (du, dv), `half`
-- either side. The Yonge & Dundas entrance hall's escalator runs Level 2 up
-- to the street the other way round from the plan, so the street floor is cut
-- along its new upper half (from its top end, where you step off, down-slope).
Stores.ANGLED_WELLS = {
	[3] = { { u = 1301.2, v = 61.7, du = 0.852, dv = -0.523, len = 22, half = 7 } },
}
local function inAngled(level, u, v, margin)
	for _, w in ipairs(Stores.ANGLED_WELLS[level] or {}) do
		local a = (u - w.u) * w.du + (v - w.v) * w.dv
		local b = -(u - w.u) * w.dv + (v - w.v) * w.du
		if a >= -margin and a <= w.len + margin and math.abs(b) <= w.half + margin then
			return true
		end
	end
	return false
end

function Stores.inWell(level, u, v, margin)
	margin = margin or 0
	if inAngled(level, u, v, margin) then
		return true
	end
	for _, w in ipairs(Stores.WELLS[level] or {}) do
		if u >= w[1] - margin and u <= w[3] + margin and v >= w[2] - margin and v <= w[4] + margin then
			return true
		end
	end
	return false
end

-- Plan rects minus the wells on these levels.
function Stores.clipWells(rects, ...)
	local out = rects
	for _, level in ipairs({ ... }) do
		for _, h in ipairs(Stores.WELLS[level] or {}) do
			local nextOut = {}
			for _, r in ipairs(out) do
				if r[3] <= h[1] or r[1] >= h[3] or r[4] <= h[2] or r[2] >= h[4] then
					table.insert(nextOut, r)
				else
					if r[1] < h[1] then
						table.insert(nextOut, { r[1], r[2], h[1], r[4] })
					end
					if r[3] > h[3] then
						table.insert(nextOut, { h[3], r[2], r[3], r[4] })
					end
					local a, b = math.max(r[1], h[1]), math.min(r[3], h[3])
					if r[2] < h[2] then
						table.insert(nextOut, { a, r[2], b, h[2] })
					end
					if r[4] > h[4] then
						table.insert(nextOut, { a, h[4], b, r[4] })
					end
				end
			end
			out = nextOut
		end
		for _, w in ipairs(Stores.ANGLED_WELLS[level] or {}) do
			-- the opening's bounding box; inside it the floor goes in 1 ft cells,
			-- kept where a cell's centre is outside the opening
			local cu = { w.u, w.u + w.du * w.len }
			local cv = { w.v, w.v + w.dv * w.len }
			local pu, pv = -w.dv * w.half, w.du * w.half
			local u0 = math.floor(math.min(cu[1], cu[2]) - math.abs(pu)) - 1
			local u1 = math.ceil(math.max(cu[1], cu[2]) + math.abs(pu)) + 1
			local v0 = math.floor(math.min(cv[1], cv[2]) - math.abs(pv)) - 1
			local v1 = math.ceil(math.max(cv[1], cv[2]) + math.abs(pv)) + 1
			local nextOut = {}
			for _, r in ipairs(out) do
				if r[3] <= u0 or r[1] >= u1 or r[4] <= v0 or r[2] >= v1 then
					table.insert(nextOut, r)
				else
					if r[1] < u0 then
						table.insert(nextOut, { r[1], r[2], u0, r[4] })
					end
					if r[3] > u1 then
						table.insert(nextOut, { u1, r[2], r[3], r[4] })
					end
					local a, b = math.max(r[1], u0), math.min(r[3], u1)
					if r[2] < v0 then
						table.insert(nextOut, { a, r[2], b, v0 })
					end
					if r[4] > v1 then
						table.insert(nextOut, { a, v1, b, r[4] })
					end
					-- the part inside the box, row by row (runs of kept cells)
					local c0, c1 = math.max(r[2], v0), math.min(r[4], v1)
					local uu = a
					while uu < b do
						local ue = math.min(b, uu + 1)
						local run = nil
						local vv = c0
						while vv < c1 do
							local ve = math.min(c1, vv + 1)
							local keep = not inAngled(level, (uu + ue) / 2, (vv + ve) / 2, 0)
							if keep then
								run = run or vv
							elseif run then
								table.insert(nextOut, { uu, run, ue, vv })
								run = nil
							end
							vv = ve
						end
						if run then
							table.insert(nextOut, { uu, run, ue, c1 })
						end
						uu = ue
					end
				end
			end
			out = nextOut
		end
	end
	return out
end

-- Railing segments round the wells on a level (plan {u0, v0, u1, v1}), less
-- the stretches where an escalator arrives.
function Stores.wellRails(level)
	local out = {}
	for _, w in ipairs(Stores.ANGLED_WELLS[level] or {}) do
		for _, side in ipairs({ -1, 1 }) do
			local pu, pv = -w.dv * w.half * side, w.du * w.half * side
			table.insert(out, { w.u + pu, w.v + pv, w.u + w.du * w.len + pu, w.v + w.dv * w.len + pv })
		end
	end
	for _, w in ipairs(Stores.WELLS[level] or {}) do
		local edges = {
			{ w[1], w[2], w[3], w[2] },
			{ w[3], w[2], w[3], w[4] },
			{ w[3], w[4], w[1], w[4] },
			{ w[1], w[4], w[1], w[2] },
		}
		for _, e in ipairs(edges) do
			local segs = { e }
			for _, o in ipairs(WELL_OPEN[level] or {}) do
				local keep = {}
				for _, sgm in ipairs(segs) do
					-- only cuts along the same line (vertical edges at u = o[1])
					if sgm[1] == sgm[3] and o[1] == o[3] and math.abs(sgm[1] - o[1]) < 0.01 then
						local lo, hi = math.min(sgm[2], sgm[4]), math.max(sgm[2], sgm[4])
						if o[2] > lo then
							table.insert(keep, { sgm[1], lo, sgm[1], math.min(hi, o[2]) })
						end
						if o[4] < hi then
							table.insert(keep, { sgm[1], math.max(lo, o[4]), sgm[1], hi })
						end
					else
						table.insert(keep, sgm)
					end
				end
				segs = keep
			end
			for _, sgm in ipairs(segs) do
				if math.abs(sgm[1] - sgm[3]) + math.abs(sgm[2] - sgm[4]) > 0.5 then
					table.insert(out, sgm)
				end
			end
		end
	end
	return out
end

return Stores
