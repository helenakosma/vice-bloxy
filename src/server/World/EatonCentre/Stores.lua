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
	{ "saint germain", "cafe", "dessert" }, { "tim hortons", "quick", "quick" }, { "gong cha", "bubble", "bubble" },
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

function Stores.design(tenant)
	local real = lower(tenant.real)
	local arch, palName
	for _, row in ipairs(BY_NAME) do
		if real:find(row[1], 1, true) then
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
		if real:find(word, 1, true) then
			pal.accent = colour
		end
	end
	return { arch = arch, pal = pal, palName = palName, name = tenant.name or "", real = real }
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
local function glow(f, size, cf, colour)
	local p = deco(f, size, cf, colour, M.Neon)
	return p
end
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
local BRIGHTS = { C(230, 60, 80), C(250, 200, 40), C(60, 170, 220), C(120, 200, 90), C(240, 130, 40), C(170, 90, 200), C(250, 250, 250) }
local BOOKS = { C(150, 40, 40), C(40, 70, 120), C(220, 200, 160), C(60, 110, 70), C(30, 30, 34), C(230, 180, 60), C(200, 90, 50), C(90, 60, 110), C(240, 236, 226) }

-- One hanging garment on a rail running along local X: a hanger and the
-- garment below it, flat face across the rail (side-hung, as on real rails).
-- Kinds: tee, shirt, knit, dress, coat, trousers; some striped. Up close (d >
-- 0.7) each is its own model tagged "Sway", so it can swing on its hanger
-- (client: ShopMotion), with sleeves, collar, placket, rib hems and buttons.
local GARMENT_KINDS = { "tee", "tee", "shirt", "knit", "knit", "dress", "coat", "trousers" }
local function garment(f, cf, colour, long, d, rng)
	local kind = rng and GARMENT_KINDS[rng:NextInteger(1, #GARMENT_KINDS)] or (long and "coat" or "tee")
	if long and kind ~= "dress" then
		kind = "coat"
	end
	local h = (kind == "coat" or kind == "dress") and 4.2 or (kind == "trousers" and 3.6 or 3)
	local fine = d > 0.7
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
	if fine then
		deco(parent, V3(0.1, 0.12, 1.55), cf * CF(0, -0.5, 0), C(200, 180, 150), M.Wood)
	end
	local top = cf * CF(0, -0.55, 0) -- where the garment hangs from
	local body
	if kind == "trousers" then
		for _, z in ipairs({ -0.42, 0.42 }) do
			body = deco(parent, V3(0.24, h - 0.3, 0.72), top * CF(0, -0.3 - (h - 0.3) / 2, z), colour, M.Fabric)
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
		body = deco(parent, V3(0.28, h, 1.7), top * CF(0, -h / 2, 0), colour, M.Fabric)
		if fine then
			-- sleeves down the sides
			local sl = kind == "tee" and 1 or h * 0.8
			for _, z in ipairs({ -1, 1 }) do
				deco(parent, V3(0.24, sl, 0.42), top * CF(0, -0.1 - sl / 2, z * 1.02) * CFrame.Angles(rad(z * 6), 0, 0), colour, M.Fabric)
				if kind == "knit" then
					deco(parent, V3(0.26, 0.25, 0.44), top * CF(0, -0.1 - sl + 0.12, z * 1.06), dark, M.Fabric)
				end
			end
			if kind == "knit" then
				deco(parent, V3(0.3, 0.35, 1.72), top * CF(0, -h + 0.17, 0), dark, M.Fabric) -- rib hem
			elseif kind == "shirt" then
				deco(parent, V3(0.3, 0.2, 0.7), top * CF(0, -0.05, 0), light, M.Fabric) -- collar
				for _, x in ipairs({ -0.15, 0.15 }) do
					deco(parent, V3(0.02, h - 0.3, 0.1), top * CF(x, -0.15 - (h - 0.3) / 2, 0), light, M.Fabric) -- placket
				end
			elseif kind == "coat" then
				for _, x in ipairs({ -0.16, 0.16 }) do
					for _, z in ipairs({ -1, 1 }) do
						deco(parent, V3(0.03, 1.4, 0.18), top * CF(x, -0.75, z * 0.3) * CFrame.Angles(rad(-z * 14), 0, 0), dark, M.Fabric) -- lapels
					end
					for k = 1, 3 do
						local b = deco(parent, V3(0.05, 0.14, 0.14), top * CF(x, -1.4 - k * 0.6, -0.25), C(30, 28, 26), M.SmoothPlastic)
						b.Shape = Enum.PartType.Ball
					end
				end
			else -- tee: a contrasting collar rib and maybe a chest print
				deco(parent, V3(0.3, 0.12, 0.55), top * CF(0, -0.05, 0), dark, M.Fabric)
				if rng and rng:NextNumber() < 0.4 then
					for _, x in ipairs({ -0.15, 0.15 }) do
						deco(parent, V3(0.02, 0.5, 0.6), top * CF(x, -1, 0), pick(rng, { C(250, 250, 250), C(20, 20, 24), C(220, 40, 50) }), M.SmoothPlastic)
					end
				end
			end
			-- stripes on some
			if rng and kind ~= "coat" and rng:NextNumber() < 0.25 then
				local sc = colour:Lerp(C(255, 255, 255), 0.7)
				for k = 1, 3 do
					deco(parent, V3(0.3, 0.14, 1.72), top * CF(0, -0.5 - k * (h - 0.8) / 4, 0), sc, M.Fabric)
				end
			end
		end
	end
	if fine then
		parent.WorldPivot = cf
		CollectionService:AddTag(parent, "Sway")
	end
	return body
end

-- A clothing rail: plinth, uprights, bar, garments along it.
local function rail(f, cf, len, rng, pal, d, colours, key, productId)
	solid(f, V3(len, 0.4, 2), cf * CF(0, 0.2, 0), pal.fixture)
	for _, s in ipairs({ -1, 1 }) do
		deco(f, V3(0.2, 5.2, 0.2), cf * CF(s * (len / 2 - 0.3), 2.8, 0), pal.metal, M.Metal)
	end
	deco(f, V3(len, 0.16, 0.16), cf * CF(0, 5.3, 0), pal.metal, M.Metal)
	local n = math.max(2, math.floor(len / 0.75 * d))
	local base = pick(rng, colours or GARMENTS)
	for k = 1, n do
		local x = -len / 2 + 0.5 + (k - 0.5) * (len - 1) / n
		local colour = rng:NextNumber() < 0.6 and base or pick(rng, colours or GARMENTS)
		garment(f, cf * CF(x, 5.3, 0), colour, rng:NextNumber() < 0.2, d, rng)
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
	local c = pick(rng, colours or GARMENTS)
	for k = 0, n - 1 do
		local p = deco(f, V3(1.3, 0.2, 1), cf * CF(rng:NextNumber(-0.04, 0.04), 0.1 + k * 0.21, 0), c, M.Fabric)
		if k == n - 1 then
			return p
		end
	end
end

-- A display table of folded stock: a top on a plinth, piles in a grid.
local function foldTable(f, cf, w, dep, rng, pal, d, colours, key, productId, height)
	height = height or 2.8
	solid(f, V3(w, height - 0.2, dep), cf * CF(0, (height - 0.2) / 2, 0), pal.wood or pal.fixture, M.Wood)
	solid(f, V3(w + 0.2, 0.2, dep + 0.2), cf * CF(0, height - 0.1, 0), pal.fixture)
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
	local m = Instance.new("Model")
	m.Name = "Mannequin"
	m.Parent = f
	local skin = C(236, 234, 230)
	top = top or pick(rng, GARMENTS)
	bottom = bottom or pick(rng, NEUTRALS)
	local jacket = rng:NextNumber() < 0.55 and pick(rng, NEUTRALS) or nil
	local skirt = rng:NextNumber() < 0.3
	solid(m, V3(2.2, 0.5, 2.2), cf * CF(0, 0.25, 0), pal.fixture)
	deco(m, V3(0.12, 0.5, 0.12), cf * CF(0, 0.6, 0.3), pal.metal, M.Metal)
	local lean = pose == 1 and 6 or (pose == 2 and -6 or 0)
	local body = cf * CF(0, 0.5, 0) * CFrame.Angles(0, 0, rad(lean / 2))
	for _, s in ipairs({ -1, 1 }) do
		local leg = body * CF(s * 0.35, 1.75, 0) * CFrame.Angles(0, 0, rad(s * 3))
		deco(m, V3(0.55, 3.0, 0.55), leg, skirt and skin or bottom, M.Fabric)
		-- shoes
		deco(m, V3(0.5, 0.3, 0.95), body * CF(s * 0.42, 0.15, -0.15), pick(rng, { C(30, 30, 32), C(236, 236, 232), C(120, 80, 56) }), M.SmoothPlastic)
	end
	if skirt then
		deco(m, V3(1.5, 1.6, 1.0), body * CF(0, 2.6, 0), bottom, M.Fabric)
	end
	deco(m, V3(1.5, 2.4, 0.85), body * CF(0, 4.3, 0), top, M.Fabric)
	deco(m, V3(1.52, 0.2, 0.88), body * CF(0, 3.2, 0), C(50, 36, 28), M.Fabric) -- belt
	deco(m, V3(0.18, 0.16, 0.05), body * CF(0, 3.2, -0.46), C(200, 180, 120), M.Metal) -- buckle
	if jacket then
		for _, s in ipairs({ -1, 1 }) do
			deco(m, V3(0.6, 2.5, 0.92), body * CF(s * 0.5, 4.3, 0.02), jacket, M.Fabric)
			deco(m, V3(0.06, 1.1, 0.3), body * CF(s * 0.32, 4.95, -0.48) * CFrame.Angles(0, 0, rad(-s * 18)), jacket:Lerp(C(0, 0, 0), 0.2), M.Fabric) -- lapel
		end
	end
	local sleeve = jacket or top
	for _, s in ipairs({ -1, 1 }) do
		local swing = pose == 1 and s * 18 or (pose == 2 and 8 or s * 6)
		local arm = body * CF(s * 0.98, 5.4, 0) * CFrame.Angles(rad(swing), 0, rad(s * 6))
		deco(m, V3(0.42, 2.3, 0.42), arm * CF(0, -1.1, 0), sleeve, M.Fabric)
		local hand = deco(m, V3(0.32, 0.4, 0.32), arm * CF(0, -2.4, 0), skin)
		if s == 1 and rng:NextNumber() < 0.35 then
			-- a bag on the arm
			local bagC = pick(rng, { C(120, 80, 56), C(30, 30, 32), C(200, 170, 140), C(170, 40, 50) })
			deco(m, V3(0.4, 1.0, 1.3), hand.CFrame * CF(0.3, -0.7, 0), bagC, M.Leather)
			deco(m, V3(0.06, 0.6, 0.8), hand.CFrame * CF(0.3, 0, 0), bagC:Lerp(C(0, 0, 0), 0.3), M.Leather)
		end
	end
	deco(m, V3(0.35, 0.4, 0.35), body * CF(0, 5.7, 0), skin)
	if rng:NextNumber() < 0.3 then
		local sc = pick(rng, BRIGHTS)
		deco(m, V3(0.9, 0.35, 0.75), body * CF(0, 5.6, 0), sc, M.Fabric) -- scarf
		deco(m, V3(0.3, 1.2, 0.08), body * CF(0.25, 4.9, -0.45), sc, M.Fabric)
	end
	local head = deco(m, V3(0.9, 1.05, 0.9), body * CF(0, 6.4, 0), skin, M.SmoothPlastic)
	head.Shape = Enum.PartType.Ball
	if rng:NextNumber() < 0.2 then
		local hat = pick(rng, { C(30, 30, 32), C(160, 120, 80), C(200, 60, 60) })
		local brim = deco(m, V3(0.08, 1.5, 1.5), body * CF(0, 6.75, 0) * CFrame.Angles(0, 0, rad(90)), hat, M.Fabric)
		brim.Shape = Enum.PartType.Cylinder
		local crown = deco(m, V3(0.6, 0.95, 0.95), body * CF(0, 7.0, 0) * CFrame.Angles(0, 0, rad(90)), hat, M.Fabric)
		crown.Shape = Enum.PartType.Cylinder
	end
	m.WorldPivot = cf
	return m
end
Stores.mannequin = mannequin
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
			garment(f, g, rng:NextNumber() < 0.5 and c or pick(rng, GARMENTS), false, d, rng)
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
	deco(f, V3(w + 0.2, 0.15, 2.6), cf * CF(0, 3.45, 0), pal.accent)
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
		light.Range = 22
		light.Brightness = 0.8
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
			local can = deco(f, V3(0.5, 0.9, 0.5), at * CF(k * 3, -0.6, 0) * CFrame.Angles(rad(k == 0 and 20 or -25 * k), 0, 0), C(30, 30, 32), M.Metal)
			local lens = glow(f, V3(0.42, 0.05, 0.42), can.CFrame * CF(0, -0.47, 0), C(255, 240, 214))
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
		l.Range = 26
		l.Brightness = 0.9
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
	local ceilingColour = spec.ceiling == "dark" and C(34, 34, 38) or C(244, 244, 242)
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
			local ce = deco(shell, V3(sizeX, 0.3, sizeZ), CF(mid.X, ceilingY + 0.15, mid.Z), ceilingColour, M.SmoothPlastic)
			ce.Name = "StoreCeiling"
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
			deco(shell, V3(len, h, 0.2), cf * CF(0, h / 2, 0), pal.wall, spec.wallMat)
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

return Stores
