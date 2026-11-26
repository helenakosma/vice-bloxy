-- The Yonge & Dundas corner's shop windows and sidewalk: the fashion anchor's
-- block (Exterior.lua builds its facade) gets dressed display windows behind
-- its street glass, a live window where a staff member folds clothes, and the
-- sidewalk outside gets planters, bike posts, newspaper boxes, an A-frame sign
-- and a hot-dog cart with its vendor.
--
-- At street level the whole block is the store (as at the real corner): the
-- corner doors open straight into it, a wall with a store front closes it off
-- from the mall's own entrance (the drum on Yonge), and its floor runs on into
-- the anchor's unit behind (B212, whose front on to the old corner hall
-- init.lua leaves out).
--
-- The window bays follow Exterior.lua's outline of the block (plan feet; kept
-- in step with its BOX_* / KC* constants by hand).
--
-- Motion (client, ShopMotion): models tagged "Spin" turn on their pivot,
-- garments tagged "Sway" swing on their hangers, parts tagged "Fold" are folded
-- and stacked over and over. The vendor and the folding staff member are
-- "ShopCashier" spots, so ShopNPCs puts someone there when a player is near.
local CollectionService = game:GetService("CollectionService")

local Util = require(script.Parent.Parent.Util)
local Stores = require(script.Parent.Stores)

local Corner = {}

local V3 = Vector3.new
local CF = CFrame.new
local M = Enum.Material
local C = Color3.fromRGB
local rad = math.rad

-- Exterior.lua's block outline.
local BOX_U0, BOX_YV = 1338, -7.5
local KCU, KCV, KR = 1388, 19, 26.5
local BOX_DU, BOX_STEP_V = KCU + KR, 55
local DUNDAS_FACE, DUNDAS_V1 = 1393.5, 200

local PAL = { fixture = C(242, 238, 232), metal = C(196, 196, 200) }
local CAMPAIGN = {
	{ wall = C(232, 196, 168), text = "AUTUMN EDIT", ink = C(120, 52, 36), poster = "mall_poster_autumn" },
	{ wall = C(196, 92, 64), text = "NEW IN", ink = C(255, 246, 236) },
	{ wall = C(240, 234, 224), text = "KNITWEAR", ink = C(150, 70, 50) },
	{ wall = C(168, 186, 160), text = "ESSENTIALS", ink = C(40, 56, 40) },
	{ wall = C(40, 40, 44), text = "THE DENIM SHOP", ink = C(236, 236, 232), poster = "mall_poster_denim" },
	{ wall = C(214, 20, 30), text = "UP TO 50% OFF", ink = C(255, 255, 255), poster = "mall_poster_sale" },
}
local OUTFITS = {
	{ C(120, 52, 36), C(220, 200, 170) },
	{ C(236, 232, 224), C(40, 56, 90) },
	{ C(176, 120, 60), C(60, 50, 44) },
	{ C(40, 40, 44), C(196, 92, 64) },
	{ C(150, 70, 50), C(236, 232, 224) },
	{ C(90, 110, 80), C(220, 210, 190) },
}

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
local function glow(f, size, cf, colour)
	colour = colour or C(255, 238, 214)
	return softLight(deco(f, size, cf, colour, M.Neon), colour)
end
local function cylinder(f, h, dia, cf, colour, material)
	local p = deco(f, V3(h, dia, dia), cf * CFrame.Angles(0, 0, rad(90)), colour, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function textOn(part, face, text, colour, font)
	local gui = Util.sign(part, face, text, colour, font or Enum.Font.GothamBold)
	gui.LightInfluence = 0
	return gui
end

---------------------------------------------------------------------------
-- One display window. cf: on the glass line at street level, -Z out to the
-- street, +Z into the window; w wide, `depth` deep.
---------------------------------------------------------------------------
local function rail(f, cf, len, rng)
	for _, s in ipairs({ -1, 1 }) do
		deco(f, V3(0.15, 6, 0.15), cf * CF(s * len / 2, 3, 0), PAL.metal, M.Metal)
	end
	deco(f, V3(len + 0.3, 0.12, 0.12), cf * CF(0, 6, 0), PAL.metal, M.Metal)
	local base = OUTFITS[rng:NextInteger(1, #OUTFITS)]
	for x = -len / 2 + 0.5, len / 2 - 0.5, 0.7 do
		local colour = rng:NextNumber() < 0.6 and base[rng:NextInteger(1, 2)] or Stores.GARMENTS[rng:NextInteger(1, #Stores.GARMENTS)]
		Stores.garment(f, cf * CF(x, 6, 0), colour, false, 1, rng)
	end
end

local function pile(f, cf, n, colour)
	for k = 0, n - 1 do
		deco(f, V3(1.3, 0.2, 1.0), cf * CF((k % 2) * 0.03, 0.1 + k * 0.21, 0), colour, M.Fabric)
	end
end

local function window(f, cf, w, depth, k, rng, opts)
	local camp = CAMPAIGN[(k - 1) % #CAMPAIGN + 1]
	local d0 = 0.8 -- clear of the glass
	local zc = d0 + depth / 2
	-- platform, back wall with the campaign, light strip and a spot
	deco(f, V3(w - 0.4, 0.8, depth), cf * CF(0, 0.4, zc), C(244, 240, 234), M.SmoothPlastic)
	deco(f, V3(w - 0.4, 0.1, 0.2), cf * CF(0, 0.82, d0 + 0.1), C(196, 92, 64), M.SmoothPlastic)
	local back = deco(f, V3(w - 0.6, 5.6, 0.2), cf * CF(0, 11.3, d0 + depth + 0.1), camp.wall, M.SmoothPlastic)
	back.Name = "WindowBanner"
	for _, s in ipairs({ -1, 1 }) do
		deco(f, V3(0.05, 0.8, 0.05), cf * CF(s * (w / 2 - 0.8), 14.5, d0 + depth + 0.1), C(60, 60, 60), M.Metal)
	end
	local poster = deco(f, V3(math.min(w - 2, 7), 2.4, 0.05), cf * CF(0, 10.6, d0 + depth - 0.05), camp.wall, M.SmoothPlastic)
	poster.Transparency = 1
	textOn(poster, Enum.NormalId.Front, camp.text, camp.ink, Enum.Font.GothamBlack)
	local small = deco(f, V3(3.4, 0.7, 0.05), cf * CF(0, 9.1, d0 + depth - 0.05), camp.wall, M.SmoothPlastic)
	small.Transparency = 1
	textOn(small, Enum.NormalId.Front, opts.brand, camp.ink, Enum.Font.Bodoni)
	-- the campaign's poster image on the banner, once imported (it carries its
	-- own headline, so the drawn text goes)
	if camp.poster and Util.decal(back, Enum.NormalId.Front, camp.poster) then
		poster:Destroy()
		small:Destroy()
	end
	glow(f, V3(w - 0.6, 0.12, 0.25), cf * CF(0, 14.1, d0 + 0.3))
	local lamp = deco(f, V3(0.6, 0.3, 0.6), cf * CF(0, 14, zc), C(30, 30, 32), M.Metal)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 80
	spot.Range = 16
	spot.Brightness = 1.3
	spot.Color = C(255, 236, 210)
	spot.Shadows = false
	spot.Parent = lamp

	local floor = cf * CF(0, 0.8, 0)
	local outfit = function()
		local o = OUTFITS[rng:NextInteger(1, #OUTFITS)]
		return o[1], o[2]
	end
	local style = opts.style or (k % 4)
	if style == "live" then
		-- A staff member folding clothes at a table behind the glass.
		local tz = d0 + depth * 0.45
		Util.solid(f, V3(5, 2.6, 2.6), floor * CF(0, 1.3, tz), C(226, 206, 186), M.Wood)
		deco(f, V3(5.2, 0.15, 2.8), floor * CF(0, 2.65, tz), C(214, 196, 176), M.Marble)
		for i, x in ipairs({ -1.7, 1.7 }) do
			pile(f, floor * CF(x, 2.72, tz), 3 + i, OUTFITS[i][1])
		end
		local cloth = deco(f, V3(1.6, 0.1, 2.2), floor * CF(0, 2.78, tz), C(196, 92, 64), M.Fabric)
		cloth.Name = "FoldCloth"
		cloth:SetAttribute("StackTo", V3(1.7, 1.1, 0)) -- local offset of the right pile's top
		CollectionService:AddTag(cloth, "Fold")
		local staff = deco(f, V3(1, 0.2, 1), floor * CF(0, 0, tz + 2.4), C(255, 255, 255))
		staff.Transparency = 1
		staff.Name = "StaffSpot"
		staff:SetAttribute("Store", opts.key)
		CollectionService:AddTag(staff, "ShopCashier")
		Stores.mannequin(f, floor * CF(-(w / 2 - 1.8), 0, d0 + 1.6), rng, PAL, 1, outfit())
	elseif style == 0 then
		-- A group of three, turned slightly to each other.
		for i, x in ipairs({ -w / 3.4, 0, w / 3.4 }) do
			local top, bottom = outfit()
			Stores.mannequin(f, floor * CF(x, 0, zc + (i == 2 and 0.8 or -0.4)) * CFrame.Angles(0, rad((i - 2) * -14), 0), rng, PAL, (i + k) % 3, top, bottom)
		end
	elseif style == 1 then
		-- A turntable with a mannequin on it, turning slowly.
		local m = Instance.new("Model")
		m.Name = "Turntable"
		m.Parent = f
		local at = floor * CF(0, 0, zc)
		cylinder(m, 0.35, 3.6, at * CF(0, 0.18, 0), C(196, 92, 64), M.SmoothPlastic)
		cylinder(m, 0.06, 3.7, at * CF(0, 0.38, 0), C(240, 234, 224), M.SmoothPlastic)
		local top, bottom = outfit()
		local q = Stores.mannequin(m, at * CF(0, 0.4, 0), rng, PAL, k % 3, top, bottom)
		q.Parent = m
		m.WorldPivot = at
		m:SetAttribute("Speed", 18)
		CollectionService:AddTag(m, "Spin")
		for _, s in ipairs({ -1, 1 }) do
			if w >= 8 then
				local plinth = deco(f, V3(1.6, 1.6 + (s + 1) * 0.6, 1.6), floor * CF(s * (w / 2 - 1.6), 0.8 + (s + 1) * 0.3, zc), C(226, 206, 186), M.Marble)
				pile(f, plinth.CFrame * CF(0, plinth.Size.Y / 2, 0), 3, OUTFITS[rng:NextInteger(1, #OUTFITS)][1])
			end
		end
	elseif style == 2 then
		-- A rail of garments with a mannequin beside it.
		rail(f, floor * CF(-w / 8, 0, d0 + depth - 1.2), math.max(3, w * 0.55), rng)
		local top, bottom = outfit()
		Stores.mannequin(f, floor * CF(w / 2 - 1.9, 0, zc - 0.4) * CFrame.Angles(0, rad(-12), 0), rng, PAL, 2, top, bottom)
	else
		-- Stacked cubes of folded stock, shopping bags and a plant.
		for i, x in ipairs({ -w / 2 + 1.5, -w / 2 + 3.3, w / 2 - 1.5 }) do
			local h = 1 + (i % 3) * 0.9
			local cube = deco(f, V3(1.7, h, 1.7), floor * CF(x, h / 2, d0 + depth - 1.3), i == 2 and C(196, 92, 64) or C(240, 234, 224), M.SmoothPlastic)
			pile(f, cube.CFrame * CF(0, h / 2, 0), 2 + i, OUTFITS[rng:NextInteger(1, #OUTFITS)][rng:NextInteger(1, 2)])
		end
		for i = 0, 2 do
			local bag = deco(f, V3(1.2, 1.5, 0.5), floor * CF(-0.8 + i * 0.9, 0.75, d0 + 1.2) * CFrame.Angles(0, rad(i * 17 - 15), 0), i == 1 and C(214, 20, 30) or C(244, 240, 234), M.SmoothPlastic)
			deco(f, V3(0.6, 0.5, 0.04), bag.CFrame * CF(0, 0.95, 0), C(40, 40, 44), M.Fabric)
		end
		local pot = cylinder(f, 1.2, 1.3, floor * CF(w / 2 - 3.6, 0.6, d0 + depth - 1.4), C(60, 58, 56), M.Concrete)
		for i = 0, 4 do
			local leaf = deco(f, V3(0.9, 0.9, 0.9), pot.CFrame * CF(rng:NextNumber(-0.4, 0.4), 1 + i * 0.45, rng:NextNumber(-0.4, 0.4)), C(70, 120, 60), M.Grass)
			leaf.Shape = Enum.PartType.Ball
		end
		local top, bottom = outfit()
		Stores.mannequin(f, floor * CF(w / 6, 0, zc), rng, PAL, 0, top, bottom)
	end
end

---------------------------------------------------------------------------
-- Sidewalk furniture.
---------------------------------------------------------------------------
local function planter(f, cf, rng)
	Util.solid(f, V3(5, 2.4, 2.6), cf * CF(0, 1.2, 0), C(150, 146, 140), M.Concrete)
	deco(f, V3(4.6, 0.2, 2.2), cf * CF(0, 2.35, 0), C(70, 52, 40), M.Ground)
	for i = 0, 5 do
		local b = deco(f, V3(1.4, 1.2, 1.4), cf * CF(-1.8 + i * 0.72, 2.9 + rng:NextNumber(0, 0.5), rng:NextNumber(-0.5, 0.5)), C(64, 110, 56):Lerp(C(110, 140, 60), rng:NextNumber()), M.Grass)
		b.Shape = Enum.PartType.Ball
	end
end

local function bikePost(f, cf)
	Util.solid(f, V3(0.3, 3, 0.3), cf * CF(0, 1.5, 0), C(30, 30, 32), M.Metal)
	local ring = deco(f, V3(0.2, 2, 2), cf * CF(0, 2.4, 0) * CFrame.Angles(0, rad(90), 0) * CFrame.Angles(0, 0, 0), C(30, 30, 32), M.Metal)
	ring.Shape = Enum.PartType.Cylinder
end

local function paperBox(f, cf, colour, label)
	Util.solid(f, V3(1.8, 3.4, 1.6), cf * CF(0, 1.7, 0), colour, M.Metal)
	local window = deco(f, V3(1.3, 0.9, 0.05), cf * CF(0, 2.6, -0.82), C(200, 214, 220), M.Glass)
	window.Transparency = 0.3
	local plate = deco(f, V3(1.6, 0.5, 0.05), cf * CF(0, 1.6, -0.82), colour, M.SmoothPlastic)
	textOn(plate, Enum.NormalId.Front, label, C(255, 255, 255), Enum.Font.GothamBlack)
	deco(f, V3(1.9, 0.2, 1.7), cf * CF(0, 3.45, 0), colour:Lerp(C(0, 0, 0), 0.3), M.Metal)
end

local function aFrame(f, cf, brand)
	for _, s in ipairs({ -1, 1 }) do
		local board = deco(f, V3(2, 3.2, 0.1), cf * CF(0, 1.55, s * 0.35) * CFrame.Angles(rad(s * 12), 0, 0), C(30, 30, 32), M.Wood)
		local face = s < 0 and Enum.NormalId.Front or Enum.NormalId.Back
		textOn(board, face, "NEW IN\n" .. brand .. "\n→", C(255, 246, 236), Enum.Font.GothamBold)
	end
end

local function hotDogCart(f, cf, key)
	local steel = C(200, 202, 206)
	Util.solid(f, V3(6, 3, 2.8), cf * CF(0, 1.9, 0), steel, M.DiamondPlate)
	deco(f, V3(6.1, 0.3, 2.9), cf * CF(0, 3.45, 0), C(180, 182, 186), M.Metal)
	for _, x in ipairs({ -2.2, 2.2 }) do
		cylinder(f, 0.4, 1.2, cf * CF(x, 0.6, -1.45) * CFrame.Angles(0, rad(90), 0), C(30, 30, 32), M.Rubber)
	end
	-- lids, condiments and a few buns
	for i, x in ipairs({ -1.8, -0.6, 0.6 }) do
		deco(f, V3(1.0, 0.25, 1.4), cf * CF(x, 3.7, 0.3), C(220, 222, 226), M.Metal)
		local bottle = cylinder(f, 0.9, 0.35, cf * CF(1.6 + i * 0.4, 4.05, -0.6), ({ C(220, 40, 30), C(240, 200, 40), C(70, 110, 40) })[i], M.SmoothPlastic)
		bottle.Name = "Condiment"
	end
	for i = 0, 2 do
		deco(f, V3(0.9, 0.3, 0.35), cf * CF(-1.6 + i * 0.5, 3.75, -0.9), C(220, 170, 110), M.SmoothPlastic)
	end
	-- the umbrella
	deco(f, V3(0.15, 6, 0.15), cf * CF(2.6, 6.4, 0.9), C(200, 200, 204), M.Metal)
	local cols = { C(230, 50, 40), C(250, 220, 60) }
	for k = 0, 7 do
		local a = k * math.pi / 4
		local panel = deco(f, V3(3.2, 0.12, 2.6), cf * CF(2.6, 9.3, 0.9) * CFrame.Angles(0, a, 0) * CF(1.5, 0, 0) * CFrame.Angles(0, 0, rad(-14)), cols[k % 2 + 1], M.Fabric)
		panel.Name = "Umbrella"
	end
	local sign = deco(f, V3(4.5, 1, 0.1), cf * CF(-0.5, 2.4, -1.45), C(230, 50, 40), M.SmoothPlastic)
	textOn(sign, Enum.NormalId.Front, "HOT DOGS · SAUSAGES", C(255, 255, 255), Enum.Font.GothamBlack)
	-- the vendor stands behind it
	local spot = deco(f, V3(1, 0.2, 1), cf * CF(0, 0, 2.6), C(255, 255, 255))
	spot.Transparency = 1
	spot.Name = "VendorSpot"
	spot:SetAttribute("Store", key)
	CollectionService:AddTag(spot, "ShopCashier")
end


---------------------------------------------------------------------------
-- The store in the corner: floor and lit ceiling (Stores.shell), the flagship
-- fit-out on a grid with an aisle straight in from the corner doors, the wall
-- to the mall's entrance with a store front on its far side, and a cash desk.
---------------------------------------------------------------------------
local PARTITION_U = BOX_U0 -- the drum's north end
local B212_FRONT_V = 54.4

local function cornerStore(parent, P, base, tenant, rng)
	local design = Stores.design(tenant)
	local key = "3:CORNER"
	local f = Instance.new("Folder")
	f.Name = "CornerStore"
	f.Parent = parent
	-- the floor, in plan rects: the block's main square, the strip by the short
	-- Dundas face, and the rounded corner in 2 ft strips
	local rects = {
		{ PARTITION_U, BOX_YV, KCU, B212_FRONT_V },
		{ KCU, KCV, BOX_DU, B212_FRONT_V },
	}
	for u = KCU, BOX_DU - 2, 2 do
		local du = u + 2 - KCU
		local vmin = KCV - math.sqrt(math.max(0, KR * KR - du * du))
		table.insert(rects, { u, vmin, u + 2, KCV })
	end
	local towardStore = (P(PARTITION_U + 1, 0, 0) - P(PARTITION_U, 0, 0)).Unit
	local wallA, wallB = P(PARTITION_U + 0.6, BOX_YV, base), P(PARTITION_U + 0.6, B212_FRONT_V, base)
	local unit = { floor = rects }
	-- (no wall cladding on the dividing wall: it has the store's windows and door)
	local ok, err = pcall(Stores.shell, f, unit, P, 1, base, design, key, {}, rng)
	if not ok then
		warn("[Corner] shell: " .. tostring(err))
	end

	-- The wall to the mall entrance: solid where it isn't glass; on its far
	-- side a store front with windows, a doorway and the name.
	local h = 20
	local function wallPiece(v0, v1, y0, y1, colour, material)
		local a, b = P(PARTITION_U, v0, base), P(PARTITION_U, v1, base)
		local mid = (a + b) / 2 + V3(0, (y0 + y1) / 2, 0)
		return Util.solid(f, V3(0.8, y1 - y0, (b - a).Magnitude), CFrame.lookAt(mid, mid + (b - a)), colour, material or M.SmoothPlastic)
	end
	local door0, door1 = 18, 34
	wallPiece(BOX_YV, door0, 13, h, C(244, 242, 238))
	wallPiece(door0, door1, 13, h, C(244, 242, 238))
	wallPiece(door1, B212_FRONT_V, 13, h, C(244, 242, 238))
	wallPiece(BOX_YV, BOX_YV + 2, 0, 13, C(244, 242, 238))
	wallPiece(B212_FRONT_V - 2, B212_FRONT_V, 0, 13, C(244, 242, 238))
	for _, seg in ipairs({ { BOX_YV + 2, door0 }, { door1, B212_FRONT_V - 2 } }) do
		local a, b = P(PARTITION_U, seg[1], base), P(PARTITION_U, seg[2], base)
		local mid = (a + b) / 2 + V3(0, 6.5, 0)
		local g = Util.solid(f, V3(0.3, 13, (b - a).Magnitude), CFrame.lookAt(mid, mid + (b - a)), C(210, 226, 234), M.Glass)
		g.Transparency = 0.7
		g.CastShadow = false
		g.Name = "ShopWindow"
		for v = seg[1], seg[2], 8 do
			deco(f, V3(0.5, 13, 0.5), CF(P(PARTITION_U, v, base + 6.5)), C(200, 200, 204), M.Metal)
		end
	end
	-- the dressed store front on the mall side (Stores.storefront: piers,
	-- sign band and lettering, blade sign, display plinths, mat)
	do
		local out = -towardStore
		local okF, errF = pcall(Stores.storefront, f, P(PARTITION_U - 0.4, BOX_YV + 1, base), P(PARTITION_U - 0.4, B212_FRONT_V - 1, base), out, base, h, 13, design, tenant.name, true, true)
		if not okF then
			warn("[Corner] front: " .. tostring(errF))
		end
	end

	-- The cash desk against the wall near the back, a terracotta wall with the
	-- name lit up behind it.
	do
		local p = P(PARTITION_U + 5.5, 44, base)
		local cf = CFrame.lookAt(p, p - towardStore) -- the cashier stands on the wall side
		Stores.cashWrap(f, cf, 9, { fixture = Stores.FLAG.terrazzo, accent = Stores.FLAG.terracotta }, key, Stores.FLAG.terracotta)
		local wp = P(PARTITION_U + 0.75, 44, base + 7)
		local wcf = CFrame.lookAt(wp, wp + towardStore)
		deco(f, V3(16, 12, 0.3), wcf, Stores.FLAG.terracotta, M.SmoothPlastic)
		for x = -7.5, 7.5, 1.5 do
			deco(f, V3(0.5, 12, 0.2), wcf * CF(x, 0, -0.2), Stores.FLAG.terracotta:Lerp(C(0, 0, 0), 0.1), M.Wood)
		end
		local sign = deco(f, V3(7, 2.2, 0.1), wcf * CF(0, 2.6, -0.4), C(255, 255, 255))
		sign.Transparency = 1
		textOn(sign, Enum.NormalId.Front, string.lower(string.split(tenant.name, " ")[1] or tenant.name), C(255, 246, 236), Enum.Font.GothamBold)
		glow(f, V3(7.5, 0.1, 0.1), wcf * CF(0, 1.2, -0.4), C(255, 238, 220))
	end

	-- The fit-out: a 9 ft grid over the floor, clear of the windows, the wall,
	-- the cash desk and the rounded corner's doors, with the aisle running
	-- straight in from the corner doors toward the back.
	local doorU, doorV = KCU + KR * math.cos(math.rad(45)), KCV - KR * math.sin(math.rad(45))
	local inU, inV = -math.sqrt(0.5), math.sqrt(0.5)
	local spots = {}
	for u = PARTITION_U + 8, BOX_DU - 7, 9 do
		for v = BOX_YV + 8, B212_FRONT_V + 30, 9 do
			local ok = true
			if u > KCU and v < KCV then
				local du, dv = u - KCU, v - KCV
				ok = math.sqrt(du * du + dv * dv) < KR - 8
			end
			if v > B212_FRONT_V - 1 and u > 1384 then
				ok = false -- the unit behind is narrower than the block
			end
			if u < PARTITION_U + 16 and v > 34 and v < 54 then
				ok = false -- the cash desk
			end
			if u > BOX_DU - 8 then
				ok = false
			end
			if ok then
				table.insert(spots, { u, v })
			end
		end
	end
	local fitted = {
		fill = spots,
		fillAxis = { -inV, inU, inU, inV },
		aisle = { doorU, doorV, inU, inV, 5.5 },
	}
	local okF, errF = pcall(Stores.flagship, f, fitted, P, 1, base, design, key, rng)
	if not okF then
		warn("[Corner] fit-out: " .. tostring(errF))
	end
	local c = P((PARTITION_U + BOX_DU) / 2, (BOX_YV + B212_FRONT_V) / 2, base)
	Stores.registry[key] = { name = tenant.name, colour = design.pal.accent, centre = c, radius = 48, arch = "fashion" }
	return f
end

---------------------------------------------------------------------------
-- Build. P(u, v, y) -> world; base = street level; brand = the anchor's
-- tenant record (its made-up name; real one for the look); corner = Exterior's YongeDundasCorner folder (its ShopWindow
-- glass is made clearer so the displays read from the street).
---------------------------------------------------------------------------
function Corner.build(parent, P, base, tenant, corner)
	local f = Instance.new("Folder")
	f.Name = "CornerWindows"
	f.Parent = parent
	local rng = Random.new(2412)
	local brand = tenant and tenant.name or "Sorrel Studio"
	Stores.useBrand(tenant and tenant.real) -- the windows' clothes in the store's style
	if tenant then
		local ok, err = pcall(cornerStore, parent, P, base, tenant, rng)
		if not ok then
			warn("[Corner] store: " .. tostring(err))
		end
	end

	if corner then
		for _, p in ipairs(corner:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == "ShopWindow" then
				p.Transparency = 0.8
				p.Color = C(214, 228, 234)
				p.Reflectance = 0.12
			end
		end
	end

	local function bay(a, b, inward, depth, k, opts)
		local pa, pb = P(a[1], a[2], base), P(b[1], b[2], base)
		local mid = (pa + pb) / 2
		local w = (pb - pa).Magnitude
		local inW = (P(a[1] + inward[1], a[2] + inward[2], 0) - P(a[1], a[2], 0)).Unit
		local cf = CFrame.lookAt(mid, mid - inW) -- -Z out to the street
		opts = opts or {}
		opts.brand, opts.key = brand, "SORREL_WINDOW"
		local ok, err = pcall(window, f, cf, w, depth, k, rng, opts)
		if not ok then
			warn("[Corner] window: " .. tostring(err))
		end
	end
	local function run(a, b, n, inward, depth, k0, live)
		for k = 0, n - 1 do
			local pa = { a[1] + (b[1] - a[1]) * k / n, a[2] + (b[2] - a[2]) * k / n }
			local pb = { a[1] + (b[1] - a[1]) * (k + 1) / n, a[2] + (b[2] - a[2]) * (k + 1) / n }
			bay(pa, pb, inward, depth, k0 + k, (live and k == live) and { style = "live" } or nil)
		end
	end

	-- Yonge face (its middle window is the live one).
	run({ BOX_U0, BOX_YV }, { KCU, BOX_YV }, 5, { 0, 1 }, 5.4, 1, 2)
	-- The rounded corner: its two end segments and the outer bays of the bank.
	local SEG = 8
	local function cp(t)
		local th = math.pi / 2 * (1 - t)
		return { KCU + KR * math.cos(th), KCV - KR * math.sin(th) }
	end
	local function toCentre(p)
		local du, dv = KCU - p[1], KCV - p[2]
		local l = math.sqrt(du * du + dv * dv)
		return { du / l, dv / l }
	end
	local corners = {
		{ cp(0), cp(1 / SEG) },
		{ cp(1 - 1 / SEG), cp(1) },
	}
	local a1, b1 = cp(1 / SEG), cp(1 - 1 / SEG)
	local function jamb(t)
		return { a1[1] + (b1[1] - a1[1]) * t, a1[2] + (b1[2] - a1[2]) * t }
	end
	table.insert(corners, { jamb(0), jamb(0.25) })
	table.insert(corners, { jamb(0.75), jamb(1) })
	for i, seg in ipairs(corners) do
		local m = { (seg[1][1] + seg[2][1]) / 2, (seg[1][2] + seg[2][2]) / 2 }
		bay(seg[1], seg[2], toCentre(m), 3.6, 10 + i)
	end
	-- Short Dundas face, then the long one (shallow windows in front of the store).
	run({ BOX_DU, KCV }, { BOX_DU, BOX_STEP_V }, 4, { -1, 0 }, 5.4, 20)
	run({ DUNDAS_FACE, BOX_STEP_V + 6 }, { DUNDAS_FACE, DUNDAS_V1 }, 12, { -1, 0 }, 3.2, 30)

	-- Sidewalk.
	local side = Instance.new("Folder")
	side.Name = "Sidewalk"
	side.Parent = f
	local function at(u, v, facingU, facingV)
		local p = P(u, v, base)
		local d = (P(u + facingU, v + facingV, base) - p).Unit
		return CFrame.lookAt(p, p + d)
	end
	local ok, err = pcall(function()
		planter(side, at(1342, -12.5, 1, 0), rng)
		planter(side, at(1381, -12.5, 1, 0), rng)
		for _, u in ipairs({ 1352, 1356, 1360 }) do
			bikePost(side, at(u, -13, 1, 0))
		end
		paperBox(side, at(1346.5, -11.2, 0, -1), C(40, 90, 170), "DAILY")
		paperBox(side, at(1348.6, -11.2, 0, -1), C(190, 40, 40), "METRO")
		aFrame(side, at(1366, -10.5, 0, -1), string.upper(brand))
		hotDogCart(side, at(1372, -13.5, 0, -1), "HOTDOG_CART")
		planter(side, at(1419, 40, 0, 1), rng)
		-- uplights washing the facade
		for u = BOX_U0 + 5, KCU - 2, 10 do
			glow(side, V3(1.4, 0.15, 0.6), at(u, BOX_YV - 0.8, 1, 0) * CF(0, 0.08, 0), C(255, 236, 206))
		end
	end)
	if not ok then
		warn("[Corner] sidewalk: " .. tostring(err))
	end
	return f
end

return Corner
