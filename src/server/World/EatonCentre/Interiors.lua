-- Shop interiors for the Eaton Centre, and the Urban Eatery's seating.
--
-- Every shop gets a fit-out for its category inside its "box": the largest
-- rectangle in its traced unit, measured from its storefront (tools/eaton
-- to_lua.py). Coordinates here are in that box's frame: x across the front
-- (-W/2..W/2), z inward from the front (0..D). The first few feet inside the
-- door and an aisle down the middle always stay clear, so every shop can be
-- walked into and through.
--
-- The food court's tables and chairs are placed where the concourse plan draws
-- them (Data/Furniture.lua). The food hall (the old Richtree unit) has no stall
-- plan, so its stall ring is laid out to fill the unit (inferred).
local Util = require(script.Parent.Parent.Util)
-- Detailed store designs (one per kind of real store); the simple fixtures below
-- remain as the fallback if a design fails.
local Stores = require(script.Parent.Stores)
local Lazy = require(script.Parent.Lazy)

local Interiors = {}

local V3 = Vector3.new
local M = Enum.Material
local C = Color3.fromRGB

local WOOD = C(176, 140, 100)
local DARK = C(40, 42, 48)
local STEEL = C(196, 198, 202)
local WHITE = C(242, 242, 240)
local GLASS = C(200, 224, 234)
local GARMENTS = { C(200, 60, 60), C(40, 70, 130), C(236, 236, 232), C(30, 30, 34), C(120, 150, 90), C(230, 180, 60), C(150, 110, 170), C(90, 120, 150) }

local CLEAR_FRONT = 6 -- keep the doorway area open (studs)
local AISLE = 3.5 -- half-width of the clear aisle down the middle

-- A shop's frame: f(x, y, z) -> CFrame facing into the shop.
local function frame(origin, across, inward)
	local look = CFrame.lookAt(origin, origin + inward)
	return function(x, y, z, yaw)
		local p = origin + across * x + inward * z + V3(0, y, 0)
		local cf = CFrame.lookAt(p, p + inward)
		if yaw then
			cf = cf * CFrame.Angles(0, yaw, 0)
		end
		return cf
	end, look
end

local function block(folder, size, cf, colour, material, collide)
	if collide == false then
		return Util.deco(folder, size, cf, colour, material or M.SmoothPlastic)
	end
	return Util.solid(folder, size, cf, colour, material or M.SmoothPlastic)
end

-- Fixtures ------------------------------------------------------------------
local function rack(folder, at, x, z, len, rng)
	-- A clothes rail on two posts with garments hanging (along z).
	block(folder, V3(0.3, 0.3, len), at(x, 5.2, z), STEEL, M.Metal, false)
	for _, dz in ipairs({ -len / 2 + 0.3, len / 2 - 0.3 }) do
		block(folder, V3(0.3, 5.2, 0.3), at(x, 2.6, z + dz), STEEL, M.Metal)
	end
	block(folder, V3(1.6, 3.2, len - 0.8), at(x, 3.4, z), GARMENTS[rng:NextInteger(1, #GARMENTS)], M.Fabric, false)
end

local function tableTop(folder, at, x, z, w, d, colour, h)
	h = h or 3
	block(folder, V3(w, h, d), at(x, h / 2, z), colour or WOOD, M.Wood)
end

local function shelfWall(folder, at, x, z, len, colour, goods, rng)
	-- A tall shelving unit against a side wall (along z) with goods on it.
	block(folder, V3(1.4, 7.5, len), at(x, 3.75, z), colour or WHITE, M.SmoothPlastic)
	for _, y in ipairs({ 2, 3.8, 5.6 }) do
		block(folder, V3(1.2, 1, len - 0.6), at(x, y + 0.5, z), goods[rng:NextInteger(1, #goods)], M.SmoothPlastic, false)
	end
end

local function counter(folder, at, x, z, w, colour)
	block(folder, V3(w, 3.6, 2.2), at(x, 1.8, z), colour or DARK, M.SmoothPlastic)
	block(folder, V3(w + 0.2, 0.2, 2.4), at(x, 3.7, z), C(230, 228, 222), M.Marble)
	block(folder, V3(1.2, 1, 0.9), at(x - w / 2 + 1.2, 4.3, z), DARK, M.SmoothPlastic, false)
end

local function fittingRooms(folder, at, W, D, n)
	-- A row of booths against the back wall with curtains.
	local bw = 4
	local start = W / 2 - n * bw
	for i = 0, n - 1 do
		local x = start + bw * (i + 0.5)
		block(folder, V3(0.3, 8, 4), at(x - bw / 2, 4, D - 2), WHITE)
		block(folder, V3(bw - 0.4, 6.5, 0.15), at(x, 3.8, D - 4), C(120, 30, 40), M.Fabric, false)
	end
	block(folder, V3(0.3, 8, 4), at(start + bw * n, 4, D - 2), WHITE)
end

-- Category templates --------------------------------------------------------
local TEMPLATES = {}

function TEMPLATES.fashion(folder, at, W, D, rng, accent)
	local rows = math.max(1, math.floor((W / 2 - AISLE - 1) / 4))
	for side = -1, 1, 2 do
		for r = 1, rows do
			local x = side * (AISLE + 1 + (r - 0.5) * 4)
			local z0, z1 = CLEAR_FRONT + 3, D - (D > 30 and 8 or 3)
			local z = z0
			while z + 6 <= z1 do
				rack(folder, at, x, z + 3, 6, rng)
				z += 8
			end
		end
	end
	if W >= 18 then
		tableTop(folder, at, -W / 4, CLEAR_FRONT, 5, 3, accent)
		tableTop(folder, at, W / 4, CLEAR_FRONT, 5, 3, accent)
	end
	if D > 30 and W >= 20 then
		fittingRooms(folder, at, W, D, math.min(4, math.floor(W / 2 / 4)))
	end
	counter(folder, at, -W / 2 + 4, math.max(CLEAR_FRONT + 6, D - 6), 6, accent)
	-- A tall mirror on a side wall.
	block(folder, V3(0.2, 7, 3), at(W / 2 - 0.3, 4, CLEAR_FRONT + 2), C(200, 220, 230), M.Glass).Reflectance = 0.4
end

TEMPLATES.sports = TEMPLATES.fashion
TEMPLATES.department = TEMPLATES.fashion

function TEMPLATES.footwear(folder, at, W, D, rng, accent)
	local goods = { C(230, 230, 226), C(40, 40, 44), C(180, 120, 80), C(200, 60, 60), C(60, 90, 160) }
	for side = -1, 1, 2 do
		shelfWall(folder, at, side * (W / 2 - 0.8), (CLEAR_FRONT + D) / 2, D - CLEAR_FRONT - 2, WHITE, goods, rng)
	end
	for z = CLEAR_FRONT + 4, D - 6, 8 do
		for side = -1, 1, 2 do
			if W >= 16 then
				block(folder, V3(3, 1.6, 2), at(side * (AISLE + 2), 0.8, z), C(70, 70, 76), M.Fabric) -- fitting bench
			end
		end
	end
	counter(folder, at, 0, math.max(CLEAR_FRONT + 6, D - 4), math.min(8, W - 6), accent)
end

function TEMPLATES.electronics(folder, at, W, D, rng, accent)
	for z = CLEAR_FRONT + 3, D - 8, 9 do
		for side = -1, 1, 2 do
			if W >= 16 then
				tableTop(folder, at, side * (AISLE + 3), z, 5, 3, WHITE, 3)
				for k = -1, 1 do
					block(folder, V3(1.2, 0.1, 0.8), at(side * (AISLE + 3) + k * 1.6, 3.05, z), DARK, M.Glass, false)
				end
			end
		end
	end
	-- Screen wall at the back.
	local sw = math.min(W - 4, 16)
	local screen = block(folder, V3(sw, 6, 0.4), at(0, 6, D - 0.6), C(20, 24, 34), M.Neon, false)
	screen.Transparency = 0.1
	counter(folder, at, -W / 2 + 4, math.max(CLEAR_FRONT + 6, D - 6), 6, accent)
end

function TEMPLATES.beauty(folder, at, W, D, rng, accent)
	local goods = { C(230, 170, 190), C(240, 230, 220), C(40, 40, 44), C(200, 120, 140), C(250, 214, 160) }
	for side = -1, 1, 2 do
		shelfWall(folder, at, side * (W / 2 - 0.8), (CLEAR_FRONT + D) / 2, D - CLEAR_FRONT - 2, WHITE, goods, rng)
	end
	for z = CLEAR_FRONT + 4, D - 6, 9 do
		if W >= 14 then
			tableTop(folder, at, -AISLE - 2.5, z, 3, 5, accent, 3.4)
			block(folder, V3(2.5, 2, 0.1), at(-AISLE - 2.5, 4.6, z), C(200, 220, 230), M.Glass, false)
		end
	end
	counter(folder, at, AISLE + 3, math.max(CLEAR_FRONT + 6, D - 5), 5, accent)
end

function TEMPLATES.jewellery(folder, at, W, D, rng, accent)
	-- Glass cases in a U round the shop.
	for side = -1, 1, 2 do
		for z = CLEAR_FRONT + 2, D - 4, 6 do
			block(folder, V3(2.2, 3, 5), at(side * (W / 2 - 1.6), 1.5, z), DARK, M.SmoothPlastic)
			local g = block(folder, V3(2.2, 1.2, 5), at(side * (W / 2 - 1.6), 3.6, z), GLASS, M.Glass)
			g.Transparency = 0.6
		end
	end
	counter(folder, at, 0, math.max(CLEAR_FRONT + 6, D - 3), math.min(8, W - 6), accent)
end

TEMPLATES.optical = TEMPLATES.jewellery

function TEMPLATES.books(folder, at, W, D, rng, accent)
	local goods = { C(180, 60, 50), C(40, 80, 140), C(230, 200, 120), C(60, 120, 80), C(120, 90, 160) }
	for z = CLEAR_FRONT + 4, D - 4, 7 do
		for side = -1, 1, 2 do
			if W >= 16 then
				block(folder, V3(W / 2 - AISLE - 2, 6, 1.2), at(side * (AISLE + 1 + (W / 2 - AISLE - 2) / 2), 3, z), WOOD, M.Wood)
				block(folder, V3(W / 2 - AISLE - 2.4, 4.8, 1.3), at(side * (AISLE + 1 + (W / 2 - AISLE - 2) / 2), 3, z), goods[rng:NextInteger(1, #goods)], M.SmoothPlastic, false)
			end
		end
	end
	counter(folder, at, -W / 2 + 4, CLEAR_FRONT + 2, 6, accent)
end

function TEMPLATES.pharmacy(folder, at, W, D, rng, accent)
	local goods = { C(240, 240, 236), C(200, 60, 60), C(60, 120, 200), C(240, 200, 80) }
	for x = -W / 2 + 5, W / 2 - 5, 7 do
		if math.abs(x) > AISLE + 1 then
			block(folder, V3(2.4, 6, math.max(4, D - CLEAR_FRONT - 12)), at(x, 3, (CLEAR_FRONT + D - 6) / 2), WHITE)
			block(folder, V3(2.6, 4.6, math.max(3.6, D - CLEAR_FRONT - 12.4)), at(x, 3, (CLEAR_FRONT + D - 6) / 2), goods[rng:NextInteger(1, #goods)], M.SmoothPlastic, false)
		end
	end
	counter(folder, at, 0, math.max(CLEAR_FRONT + 6, D - 3), math.min(12, W - 6), accent)
end

function TEMPLATES.food(folder, at, W, D, rng, accent)
	-- Service counter across the front, kitchen behind, menu board above.
	local cz = math.min(CLEAR_FRONT, D * 0.3)
	local cw = math.max(4, W - 4)
	block(folder, V3(cw, 3.6, 2.4), at(0, 1.8, cz), accent or DARK, M.SmoothPlastic)
	block(folder, V3(cw + 0.2, 0.2, 2.6), at(0, 3.7, cz), STEEL, M.Metal)
	local menu = block(folder, V3(cw, 2.6, 0.3), at(0, 9.5, cz + 2), C(24, 24, 28), M.SmoothPlastic, false)
	Util.sign(menu, Enum.NormalId.Back, "MENU  ·  COMBOS  ·  SIDES  ·  DRINKS", C(255, 230, 160), Enum.Font.GothamBold).LightInfluence = 0
	-- Kitchen line along the back wall.
	local kz = math.max(cz + 5, D - 2)
	for x = -W / 2 + 2.5, W / 2 - 2.5, 4 do
		block(folder, V3(3.6, 3.4, 2.4), at(x, 1.7, kz), STEEL, M.Metal)
	end
	if D >= 12 then
		block(folder, V3(2, 6.5, 2), at(W / 2 - 1.5, 3.25, kz - 3), WHITE) -- fridge
	end
end

function TEMPLATES.cafe(folder, at, W, D, rng, accent)
	local cz = math.min(CLEAR_FRONT + 2, D * 0.5)
	block(folder, V3(math.max(4, W * 0.6), 3.6, 2.4), at(-W * 0.15, 1.8, cz), accent or WOOD, M.Wood)
	local case = block(folder, V3(3, 1.4, 2.2), at(-W * 0.15 + math.max(4, W * 0.6) / 2 - 2, 4.3, cz), GLASS, M.Glass, false)
	case.Transparency = 0.5
	block(folder, V3(2.2, 2, 1.6), at(-W * 0.15, 1, math.max(cz + 3.5, D - 1.2)), STEEL, M.Metal) -- espresso / ovens
	-- A few small tables where there's room.
	for z = cz + 6, D - 3, 6 do
		if W >= 14 then
			tableTop(folder, at, W / 2 - 3, z, 2.5, 2.5, WOOD, 2.6)
		end
	end
end

function TEMPLATES.services(folder, at, W, D, rng, accent)
	counter(folder, at, 0, math.max(CLEAR_FRONT, D - 3), math.min(10, W - 4), accent)
	for x = -W / 2 + 3, W / 2 - 3, 4 do
		if math.abs(x) > 2 and D > 12 then
			block(folder, V3(1.6, 1.6, 1.6), at(x, 0.8, CLEAR_FRONT - 2), C(70, 74, 84), M.Fabric)
		end
	end
end

-- The food hall: stalls round the walls, long communal tables in the middle.
-- The food hall (FA100, the stand-in for the real Queen's Cross Food Hall at
-- the south end of the lower level): from photos of the real one, a dark
-- wood-slat ceiling, stalls round the walls with tiled counters and neon
-- names, a café-bar island in the middle, bright green communal tables with
-- stools and globe pendants, and outside, a black "transit map" sign with
-- yellow stops. Stalls go along the unit's inner walls (Data: shelves), tables
-- on its fill grid, the ceiling over its floor (Data: floor).
local STALLS = {
	{ "Bao Down", C(220, 170, 50) }, { "Noodle Cross", C(230, 100, 80) }, { "Smash Patty", C(40, 140, 140) },
	{ "Little Curry", C(236, 120, 170) }, { "Poke Lab", C(70, 150, 90) }, { "Pasta Fresca", C(236, 222, 196) },
	{ "Rotisserie Row", C(50, 90, 190) }, { "Crisp Chicken", C(236, 130, 50) }, { "Sushi Line", C(200, 60, 70) },
	{ "Banh Mi Bar", C(120, 180, 90) }, { "Dumpling Dept.", C(240, 200, 80) }, { "Fry Society", C(90, 70, 160) },
	{ "Queen St Pizza", C(220, 60, 40) }, { "Gelato Co.", C(250, 190, 200) }, { "Taco Libre", C(40, 170, 160) },
	{ "Churro Cart", C(210, 140, 60) },
}
local HALL_GREEN = C(64, 150, 84)

local function foodHall(folder, at, W, D, rng, u, P, S, y)
	-- the transit-map sign over the way in
	do
		local sign = at(0, 12.5, -1)
		block(folder, V3(10, 3, 0.6), sign, C(246, 244, 238), M.SmoothPlastic, false)
		local plate = block(folder, V3(9, 2.4, 0.05), sign * CFrame.new(0, 0, -0.33), C(246, 244, 238), M.SmoothPlastic, false)
		plate.Transparency = 1
		Util.sign(plate, Enum.NormalId.Front, "QUEEN STREET\nMARKET HALL", C(26, 26, 28), Enum.Font.GothamBlack).LightInfluence = 0
		block(folder, V3(10.6, 3.6, 0.3), sign * CFrame.new(0, 0, 0.3), C(20, 20, 22), M.Metal, false)
		-- black "lines" out from it with yellow stops
		local lines = { { -9, 3, 30 }, { 9, 3, -30 }, { -8, -2.5, -20 }, { 8, -2.5, 20 } }
		for _, l in ipairs(lines) do
			local a = sign * CFrame.new(l[1] * 0.55, l[2] * 0.6, 0)
			local cf = a * CFrame.Angles(0, 0, math.rad(l[3]))
			block(folder, V3(math.abs(l[1]), 0.35, 0.35), cf * CFrame.new(l[1] / 2 * (l[1] > 0 and 0.5 or -0.5), 0, 0), C(20, 20, 22), M.Metal, false)
			local dot = block(folder, V3(0.3, 1.1, 1.1), (cf * CFrame.new(l[1] * 0.5, 0, -0.1)) * CFrame.Angles(0, math.rad(90), 0), C(250, 204, 40), M.SmoothPlastic, false)
			dot.Shape = Enum.PartType.Cylinder
		end
		for _, x in ipairs({ -3, 3 }) do
			block(folder, V3(0.12, 4, 0.12), sign * CFrame.new(x, 3.5, 0), C(30, 30, 32), M.Metal, false)
		end
	end
	if not (u and P) then
		return
	end
	-- ceiling height over the hall
	local function ceilingAt(p)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder }
		local hit = workspace:Raycast(p + V3(0, 2, 0), V3(0, 40, 0), params)
		return math.clamp(hit and (hit.Position.Y - p.Y) or 18, 11, 22)
	end
	local origin = P(0, 0, y)
	-- the dark slat ceiling
	for _, r in ipairs(u.floor or {}) do
		local du, dv = (r[3] - r[1]) * S, (r[4] - r[2]) * S
		if du * dv >= 120 then
			local a, b = P(r[1], r[2], y), P(r[3], r[4], y)
			local mid = (a + b) / 2
			local h = ceilingAt(mid) - 1.4
			local sx, sz = math.abs(b.X - a.X), math.abs(b.Z - a.Z)
			block(folder, V3(sx, 0.2, sz), CFrame.new(mid.X, y + h + 1.1, mid.Z), C(26, 24, 24), M.SmoothPlastic, false)
			-- slats run along the longer side
			if sx >= sz then
				for z = -sz / 2 + 0.6, sz / 2 - 0.6, 1.6 do
					block(folder, V3(sx, 0.9, 0.35), CFrame.new(mid.X, y + h + 0.45, mid.Z + z), C(74, 52, 38), M.Wood, false)
				end
			else
				for x = -sx / 2 + 0.6, sx / 2 - 0.6, 1.6 do
					block(folder, V3(0.35, 0.9, sz), CFrame.new(mid.X + x, y + h + 0.45, mid.Z), C(74, 52, 38), M.Wood, false)
				end
			end
		end
	end
	-- stalls along the walls
	local n = 0
	for _, w in ipairs(u.shelves or {}) do
		local a, b = P(w[1], w[2], y), P(w[3], w[4], y)
		local inward = P(w[5], w[6], y) - origin
		inward = V3(inward.X, 0, inward.Z).Unit
		local along = b - a
		local len = along.Magnitude
		if len >= 11 then
			local count = math.floor(len / 12)
			local sw = len / count
			for k = 0, count - 1 do
				n += 1
				local stall = STALLS[(n - 1) % #STALLS + 1]
				local colour = stall[2]
				local c0 = a + along.Unit * (sw * (k + 0.5))
				local cf = CFrame.lookAt(c0, c0 + inward) -- -Z into the hall, X along the wall
				local h = ceilingAt(c0) - 1.6
				-- back wall in the stall's colour, tiled, with a menu board
				Stores.skin(block(folder, V3(sw - 0.4, h, 0.3), cf * CFrame.new(0, h / 2, 0.1), colour, M.CeramicTiles, false), "mall_subway_tile", 4, colour, Enum.NormalId.Front)
				local menu = block(folder, V3(sw - 2.4, 2.6, 0.15), cf * CFrame.new(0, 9, -0.15), C(22, 22, 24), M.SmoothPlastic, false)
				menu.Name = "MenuBoard"
				for row = 0, 2 do
					Stores.softLight(block(folder, V3(sw - 3.4, 0.12, 0.05), cf * CFrame.new(0, 9.7 - row * 0.6, -0.25), C(236, 230, 210), M.Neon, false), C(236, 230, 210))
				end
				-- back counter with kit, then the serving counter: tiled front, steel top
				block(folder, V3(sw - 1, 3, 1.8), cf * CFrame.new(0, 1.5, -1.1), C(190, 192, 196), M.Metal)
				for x = -sw / 2 + 1.6, sw / 2 - 1.6, 2.2 do
					block(folder, V3(1.4, 1.2, 1.2), cf * CFrame.new(x, 3.6, -1.1), C(40, 40, 44), M.Metal, false)
				end
				Stores.skin(block(folder, V3(sw - 1, 3.4, 1.6), cf * CFrame.new(0, 1.7, -5), C(240, 238, 232), M.CeramicTiles), "mall_subway_tile", 3, nil, Enum.NormalId.Front)
				block(folder, V3(sw - 0.9, 0.15, 1.8), cf * CFrame.new(0, 3.48, -5), C(196, 198, 202), M.Metal, false)
				block(folder, V3(sw - 1, 0.3, 0.1), cf * CFrame.new(0, 3.1, -5.82), colour, M.SmoothPlastic, false)
				local glass = block(folder, V3(sw - 3, 1.2, 0.1), cf * CFrame.new(0, 4.2, -5.6), C(210, 226, 234), M.Glass, false)
				glass.Transparency = 0.6
				for x = -sw / 2 + 2, sw / 2 - 2, 1.4 do
					block(folder, V3(0.9, 0.25, 0.9), cf * CFrame.new(x, 3.68, -5), C(230, 190, 120), M.SmoothPlastic, false)
				end
				-- the neon name on a dark fascia over the counter
				local fascia = block(folder, V3(sw - 0.4, 2, 0.4), cf * CFrame.new(0, h - 1.2, -5.5), C(30, 30, 32), M.SmoothPlastic, false)
				local plate = block(folder, V3(sw - 2, 1.4, 0.05), cf * CFrame.new(0, h - 1.2, -5.75), C(30, 30, 32), M.SmoothPlastic, false)
				plate.Transparency = 1
				Util.sign(plate, Enum.NormalId.Front, stall[1], colour:Lerp(C(255, 255, 255), 0.25), Enum.Font.GothamBold).LightInfluence = 0
				fascia.Name = "StallSign"
				-- side walls between stalls, pendants over the counter
				block(folder, V3(0.3, h, 5.8), cf * CFrame.new(-sw / 2 + 0.15, h / 2, -2.8), C(36, 36, 38), M.SmoothPlastic)
				for _, x in ipairs({ -sw / 4, sw / 4 }) do
					block(folder, V3(0.05, 2.5, 0.05), cf * CFrame.new(x, h - 1.25, -5), C(30, 30, 30), M.SmoothPlastic, false)
					local globe = block(folder, V3(0.9, 0.9, 0.9), cf * CFrame.new(x, h - 2.9, -5), C(255, 236, 200), M.Neon, false)
					globe.Shape = Enum.PartType.Ball
					Stores.softLight(globe, C(255, 236, 200))
				end
			end
		end
	end
	-- tables on the fill grid: green communal tables with stools, a few round
	-- ones, and the café-bar island at the spot nearest the middle
	local spots = u.fill or {}
	local cu, cv, nSp = 0, 0, 0
	for _, pt in ipairs(spots) do
		cu += pt[1]
		cv += pt[2]
		nSp += 1
	end
	local barAt = nil
	if nSp > 0 then
		cu, cv = cu / nSp, cv / nSp
		local best = math.huge
		for i, pt in ipairs(spots) do
			local d = (pt[1] - cu) ^ 2 + (pt[2] - cv) ^ 2
			if d < best then
				best, barAt = d, i
			end
		end
	end
	local axis = u.fillAxis
	local inward = axis and V3(-axis[4], 0, -axis[3]) or V3(0, 0, 1)
	if inward.Magnitude < 0.5 then
		inward = V3(0, 0, 1)
	end
	inward = inward.Unit
	for i, pt in ipairs(spots) do
		local p = P(pt[1], pt[2], y)
		local cf = CFrame.lookAt(p, p + inward)
		if i == barAt then
			-- the café-bar: a long counter ring with stools and a back bar
			block(folder, V3(12, 3.6, 2), cf * CFrame.new(0, 1.8, -3), C(36, 36, 38), M.SmoothPlastic)
			block(folder, V3(12, 3.6, 2), cf * CFrame.new(0, 1.8, 3), C(36, 36, 38), M.SmoothPlastic)
			block(folder, V3(12.4, 0.2, 2.4), cf * CFrame.new(0, 3.7, -3), C(200, 170, 120), M.Wood, false)
			block(folder, V3(12.4, 0.2, 2.4), cf * CFrame.new(0, 3.7, 3), C(200, 170, 120), M.Wood, false)
			block(folder, V3(4, 6, 1.2), cf * CFrame.new(0, 3, 0), C(60, 46, 36), M.Wood)
			for k = -1, 1 do
				for row = 0, 2 do
					local bottle = block(folder, V3(0.3, 0.8, 0.3), cf * CFrame.new(k * 1.1 + rng:NextNumber(-0.3, 0.3), 3.8 + row * 1.2, -0.7), ({ C(60, 120, 60), C(160, 90, 40), C(220, 220, 230), C(120, 40, 50) })[rng:NextInteger(1, 4)], M.Glass, false)
					bottle.Transparency = 0.2
				end
			end
			for _, z in ipairs({ -4.6, 4.6 }) do
				for x = -5, 5, 2 do
					Util.cylinder(folder, 2.6, 1, cf * CFrame.new(x, 1.3, z), HALL_GREEN, M.Metal, false)
				end
			end
			local neon = block(folder, V3(5, 1.2, 0.1), cf * CFrame.new(0, 7.2, 0), C(30, 30, 32), M.SmoothPlastic, false)
			Util.sign(neon, Enum.NormalId.Front, "CAFÉ · BAR", C(250, 210, 80), Enum.Font.GothamBold).LightInfluence = 0
		elseif i % 4 == 0 then
			-- a round table with four chairs
			Util.cylinder(folder, 0.15, 3.2, cf * CFrame.new(0, 2.8, 0), C(236, 232, 224), M.SmoothPlastic, true)
			Util.cylinder(folder, 2.7, 0.3, cf * CFrame.new(0, 1.4, 0), C(30, 30, 32), M.Metal, false)
			for k = 0, 3 do
				local a = k * math.pi / 2 + 0.4
				local c = cf * CFrame.new(math.cos(a) * 2.4, 0, math.sin(a) * 2.4)
				block(folder, V3(1.4, 0.2, 1.4), c * CFrame.new(0, 1.7, 0), HALL_GREEN, M.SmoothPlastic)
				block(folder, V3(0.12, 1.6, 0.12), c * CFrame.new(0, 0.8, 0), C(30, 30, 32), M.Metal, false)
			end
		else
			-- a long green communal table with stools both sides, a pendant over it
			block(folder, V3(8, 0.25, 2.8), cf * CFrame.new(0, 2.8, 0), HALL_GREEN, M.SmoothPlastic)
			for _, x in ipairs({ -3.4, 3.4 }) do
				block(folder, V3(0.3, 2.7, 2.2), cf * CFrame.new(x, 1.35, 0), C(30, 30, 32), M.Metal)
			end
			for _, z in ipairs({ -2.1, 2.1 }) do
				for x = -3, 3, 2 do
					Util.cylinder(folder, 1.8, 1, cf * CFrame.new(x, 0.9, z), HALL_GREEN:Lerp(C(30, 30, 30), 0.2), M.SmoothPlastic, false)
				end
			end
			local h = ceilingAt(p) - 1.6
			block(folder, V3(0.05, h - 8, 0.05), cf * CFrame.new(0, 8 + (h - 8) / 2, 0), C(30, 30, 30), M.SmoothPlastic, false)
			local globe = block(folder, V3(1.2, 1.2, 1.2), cf * CFrame.new(0, 7.6, 0), C(255, 236, 200), M.Neon, false)
			globe.Shape = Enum.PartType.Ball
			Stores.softLight(globe, C(255, 236, 200))
			if i % 3 == 0 then
				local l = Instance.new("PointLight")
				l.Range = 18
				l.Brightness = 0.6
				l.Color = C(255, 228, 190)
				l.Shadows = false
				l.Parent = globe
			end
		end
	end
end

-- Lazy fit-outs (Lazy.lua): a store's contents are built when a player is near.
local function shopFolder(folder, name)
	local shop = folder:FindFirstChild(name)
	if not shop then
		shop = Instance.new("Folder")
		shop.Name = name
		shop.Parent = folder
	end
	return shop
end
local function unitCentre(u, P, y)
	if u.u and u.v then
		return P(u.u, u.v, y)
	end
	return P(u.box.cu, u.box.cv, y)
end
local function unitRadius(u, S)
	if u.umin then
		return 0.5 * math.max(u.umax - u.umin, u.vmax - u.vmin) * S
	end
	return 30
end
-- A seed per store and pass, so a store is the same every time it's built.
local function storeSeed(levelIdx, unit, pass)
	local h = levelIdx * 7919 + pass * 104729
	for i = 1, #unit do
		h = (h * 31 + string.byte(unit, i)) % 2147483647
	end
	return h
end

-- Furnish every shop on one level.
--   units: the level's unit records (with .box and .front)
--   P(u, v, y) -> Vector3; S: studs per foot; y: floor height
--   tenants: "<level>:<unit>" -> record; skip: units to leave empty
function Interiors.furnish(folder, levelIdx, units, P, S, y, tenants, skip, seed)
	local rng = Random.new(seed or 7)
	local count = 0
	for _, u in ipairs(units) do
		local t = tenants[levelIdx .. ":" .. u.unit]
		local box, front = u.box, u.front
		if t and t.status == "open" and box and front and not skip[u.unit] and string.sub(u.unit, 1, 1) ~= "Z" then
			local origin = P(box.cu, box.cv, y)
			local across = (P(box.cu + box.au, box.cv + box.av, y) - origin).Unit
			local inward = (P(box.cu - front[5], box.cv - front[6], y) - origin).Unit
			local W, D = box.width * S, box.depth * S
			local at = frame(origin, across, inward)
			local shopRoot = shopFolder(folder, u.unit)
			Lazy.add(shopRoot, unitCentre(u, P, y), unitRadius(u, S), function(shop)
				local rng = Random.new(storeSeed(levelIdx, u.unit, 1))
				local accent = nil
				if u.unit == "FA100" then
					foodHall(shop, at, W, D, rng, u, P, S, y)
				else
					local key = levelIdx .. ":" .. u.unit
					local ok, err = pcall(Stores.front, shop, at, W, D, rng, Stores.design(t), key, t)
					if not ok then
						warn("[Interiors] " .. key .. " design failed: " .. tostring(err))
						local template = TEMPLATES[t.category] or TEMPLATES.fashion
						pcall(template, shop, at, W, D, rng, accent)
					end
				end
			end)
			count += 1
		end
	end
	return count
end

-- Field fixtures: the rest of each shop's floor, beyond the storefront fit-out,
-- on the grid of spots to_lua.py lays over the whole unit (Data: fill,
-- fillAxis). About three parts each, so a 25,000 sq ft store reads as one.
local FIELD = {}

local function apparel(f, cf, rng, k)
	if k % 3 == 2 then
		-- A display table with folded stock.
		block(f, V3(6, 2.8, 3.4), cf * CFrame.new(0, 1.4, 0), WOOD, M.Wood)
		block(f, V3(5, 0.6, 2.6), cf * CFrame.new(0, 3.1, 0), GARMENTS[rng:NextInteger(1, #GARMENTS)], M.Fabric, false)
	else
		-- A double-sided rail of garments on a low plinth.
		block(f, V3(6.4, 0.4, 2), cf * CFrame.new(0, 0.2, 0), DARK, M.SmoothPlastic)
		block(f, V3(6.4, 0.25, 0.25), cf * CFrame.new(0, 5.3, 0), STEEL, M.Metal, false)
		block(f, V3(6, 3.4, 1.8), cf * CFrame.new(0, 3.4, 0), GARMENTS[rng:NextInteger(1, #GARMENTS)], M.Fabric, false)
	end
end
FIELD.fashion = apparel
FIELD.sports = apparel
FIELD.department = function(f, cf, rng, k)
	if k % 4 == 3 then
		FIELD.beauty(f, cf, rng, k)
	else
		apparel(f, cf, rng, k)
	end
end
FIELD.footwear = function(f, cf, rng)
	block(f, V3(6, 1.6, 3.4), cf * CFrame.new(0, 0.8, 0), WHITE)
	block(f, V3(5, 0.7, 2.6), cf * CFrame.new(0, 1.95, 0), ({ C(230, 230, 226), C(40, 40, 44), C(180, 120, 80), C(200, 60, 60) })[rng:NextInteger(1, 4)], M.SmoothPlastic, false)
	block(f, V3(2.2, 1.4, 1.4), cf * CFrame.new(0, 0.7, 2.8), C(70, 70, 76), M.Fabric) -- fitting bench
end
FIELD.beauty = function(f, cf, rng)
	-- A gondola: a shelving island stocked on both sides.
	block(f, V3(6, 5, 2.4), cf * CFrame.new(0, 2.5, 0), WHITE)
	local goods = { C(220, 120, 160), C(240, 200, 200), C(180, 60, 90), C(250, 240, 230), C(120, 80, 140) }
	block(f, V3(5.6, 3.6, 2.8), cf * CFrame.new(0, 2.6, 0), goods[rng:NextInteger(1, #goods)], M.SmoothPlastic, false)
end
local function gondola(colours)
	return function(f, cf, rng)
		block(f, V3(6, 5.5, 2.4), cf * CFrame.new(0, 2.75, 0), WHITE)
		block(f, V3(5.6, 4, 2.8), cf * CFrame.new(0, 2.8, 0), colours[rng:NextInteger(1, #colours)], M.SmoothPlastic, false)
	end
end
FIELD.pharmacy = gondola({ C(250, 250, 248), C(80, 140, 200), C(220, 80, 80), C(120, 190, 140) })
FIELD.books = gondola({ C(150, 40, 40), C(40, 70, 120), C(220, 200, 160), C(60, 110, 70), C(30, 30, 34) })
FIELD.services = gondola({ C(220, 222, 226), C(90, 110, 140) })
FIELD.optical = function(f, cf)
	block(f, V3(5, 3.4, 2.4), cf * CFrame.new(0, 1.7, 0), WHITE)
	block(f, V3(4.6, 0.6, 2), cf * CFrame.new(0, 3.7, 0), DARK, M.SmoothPlastic, false)
end
FIELD.jewellery = function(f, cf)
	-- A lit glass showcase.
	block(f, V3(5, 3, 2.2), cf * CFrame.new(0, 1.5, 0), DARK)
	local g = block(f, V3(5, 1, 2.2), cf * CFrame.new(0, 3.5, 0), GLASS, M.Glass, false)
	g.Transparency = 0.5
end
FIELD.electronics = function(f, cf, rng)
	-- A long demo table with devices.
	block(f, V3(6.5, 3, 3), cf * CFrame.new(0, 1.5, 0), C(230, 230, 228), M.Wood)
	for _, dx in ipairs({ -1.8, 1.8 }) do
		block(f, V3(1.4, 0.15, 1), cf * CFrame.new(dx, 3.1, 0), DARK, M.Glass, false)
	end
end
local function dining(f, cf)
	-- A table with two chairs.
	block(f, V3(3, 2.6, 3), cf * CFrame.new(0, 1.3, 0), WOOD, M.Wood)
	for _, dz in ipairs({ -2.6, 2.6 }) do
		block(f, V3(1.6, 1.6, 1.6), cf * CFrame.new(0, 0.8, dz), DARK, M.Fabric)
	end
end
FIELD.food = dining
FIELD.cafe = dining

function Interiors.fill(folder, levelIdx, units, P, S, y, tenants, skip, seed)
	local rng = Random.new(seed or 11)
	local placed = 0
	for _, u in ipairs(units) do
		local t = tenants[levelIdx .. ":" .. u.unit]
		local spots, axis = u.fill, u.fillAxis
		if t and t.status == "open" and spots and axis and #spots > 0 and not skip[u.unit] and string.sub(u.unit, 1, 1) ~= "Z" and u.unit ~= "FA100" then
			local fixture = FIELD[t.category] or apparel
			local shopRoot = shopFolder(folder, u.unit)
			local origin = P(0, 0, y)
			local inward = (P(axis[3], axis[4], y) - origin)
			inward = V3(inward.X, 0, inward.Z).Unit
			local design = Stores.design(t)
			local key = levelIdx .. ":" .. u.unit
			placed += #spots
			Lazy.add(shopRoot, unitCentre(u, P, y), unitRadius(u, S), function(shop)
				local rng = Random.new(storeSeed(levelIdx, u.unit, 2))
				-- The flagship (the H&M stand-in) gets its own hand-planned floor.
				if Stores.isFlagship(design) then
					-- keep the fit-out clear of the store's escalator wells (this floor's
					-- cut, and the escalators' run on the floor below the one above)
					local clear = {}
					for _, pt in ipairs(spots) do
						if not Stores.inWell(levelIdx, pt[1], pt[2], 5) and not Stores.inWell(levelIdx + 1, pt[1], pt[2], 5) then
							table.insert(clear, pt)
						end
					end
					local fitted = setmetatable({ fill = clear }, { __index = u })
					local okF, res = pcall(Stores.flagship, shop, fitted, P, S, y, design, key, rng)
					if okF then
						placed += res
						return
					end
					warn("[Interiors] " .. key .. " flagship failed: " .. tostring(res))
				end
				for k, pt in ipairs(spots) do
					local p = P(pt[1], pt[2], y)
					local cf = CFrame.lookAt(p, p + inward)
					local ok = pcall(Stores.field, shop, cf, rng, k, design, key)
					if not ok then
						ok = pcall(fixture, shop, cf, rng, k)
					end
					if ok then
						placed += 1
					end
				end
			end)
		end
	end
	return placed
end

-- Wall displays along each shop's inner walls (Data: shelves = { u0, v0, u1,
-- v1, nx, ny } already set in off the wall, n pointing into the shop). Two
-- parts per run: the fixture and its stock.
local WALL = {
	fashion = { h = 7, d = 1.6, colour = WHITE, stock = GARMENTS, stockH = 4.4, stockD = 1.4, material = M.Fabric },
	books = { h = 7.5, d = 1.6, colour = WOOD, stock = { C(150, 40, 40), C(40, 70, 120), C(220, 200, 160), C(60, 110, 70) }, stockH = 5.6, stockD = 1.2 },
	beauty = { h = 7, d = 1.4, colour = WHITE, stock = { C(220, 120, 160), C(240, 200, 200), C(250, 240, 230) }, stockH = 4.6, stockD = 1.2 },
	electronics = { h = 6, d = 1.2, colour = C(236, 236, 234), stock = { DARK }, stockH = 2.4, stockD = 0.3 },
	jewellery = { h = 3.4, d = 1.8, colour = DARK, stock = { GLASS }, stockH = 1, stockD = 1.6, glass = true },
	food = { h = 3.6, d = 2.4, colour = C(70, 72, 78), stock = { C(220, 220, 216) }, stockH = 0.3, stockD = 2.6 },
}
WALL.sports, WALL.department, WALL.footwear = WALL.fashion, WALL.fashion, WALL.fashion
WALL.pharmacy, WALL.optical, WALL.services = WALL.beauty, WALL.jewellery, WALL.beauty
WALL.cafe = WALL.food

function Interiors.walls(folder, levelIdx, units, P, S, y, tenants, skip, seed)
	local rng = Random.new(seed or 13)
	local runs = 0
	for _, u in ipairs(units) do
		local t = tenants[levelIdx .. ":" .. u.unit]
		if t and t.status == "open" and (u.shelves or u.floor) and not skip[u.unit] and string.sub(u.unit, 1, 1) ~= "Z" and u.unit ~= "FA100" then
			local spec = WALL[t.category] or WALL.fashion
			local shopRoot = shopFolder(folder, u.unit)
			local design = Stores.design(t)
			local key = levelIdx .. ":" .. u.unit
			runs += #(u.shelves or {})
			Lazy.add(shopRoot, unitCentre(u, P, y), unitRadius(u, S), function(shop)
				local rng = Random.new(storeSeed(levelIdx, u.unit, 3))
				-- The store's shell first (floor, ceiling, wall finishes, lighting): its
				-- inner walls are the wall runs' line moved back 1.4 ft to the wall.
				local wallLines = {}
				for _, w in ipairs(u.shelves or {}) do
					local inward = P(w[5], w[6], y) - P(0, 0, y)
					inward = V3(inward.X, 0, inward.Z).Unit
					table.insert(wallLines, { a = P(w[1], w[2], y) - inward * 1.4 * S, b = P(w[3], w[4], y) - inward * 1.4 * S, inward = inward })
				end
				-- the store's floor and ceiling finish leave the escalator wells open
				local shellUnit = u
				if u.floor and (Stores.WELLS[levelIdx] or Stores.WELLS[levelIdx + 1]) then
					shellUnit = setmetatable({ floor = Stores.clipWells(u.floor, levelIdx, levelIdx + 1) }, { __index = u })
				end
				local okS, errS = pcall(Stores.shell, shop, shellUnit, P, S, y, design, key, wallLines, rng)
				if not okS then
					warn("[Interiors] " .. key .. " shell failed: " .. tostring(errS))
				end
				-- The flagship's longest wall is a red slatted feature wall.
				local slatRun = nil
				if Stores.isFlagship(design) then
					local best = 30
					for wi, w in ipairs(u.shelves or {}) do
						local l = (P(w[3], w[4], y) - P(w[1], w[2], y)).Magnitude
						if l > best then
							best, slatRun = l, wi
						end
					end
				end
				for wi, w in ipairs(u.shelves or {}) do
					local a, b = P(w[1], w[2], y), P(w[3], w[4], y)
					local len = (b - a).Magnitude - 2
					local detailed = false
					if wi == slatRun then
						local inward = P(w[5], w[6], y) - P(0, 0, y)
						inward = V3(inward.X, 0, inward.Z).Unit
						local okW = pcall(Stores.slatWall, shop, (a + b) / 2, (b - a).Unit, inward, len, rng)
						if okW then
							runs += 1
							continue
						end
					end
					if len >= 4 then
						local inward = P(w[5], w[6], y) - P(0, 0, y)
						inward = V3(inward.X, 0, inward.Z).Unit
						local okD, res = pcall(Stores.wall, shop, (a + b) / 2, (b - a).Unit, inward, len, rng, design, key)
						detailed = okD and res
					end
					if len >= 4 and detailed then
						runs += 1
					elseif len >= 4 then
						local inward = P(w[5], w[6], y) - P(0, 0, y)
						inward = V3(inward.X, 0, inward.Z).Unit
						local mid = (a + b) / 2 + inward * (spec.d / 2)
						local cf = CFrame.lookAt(mid, mid + (b - a))
						block(shop, V3(spec.d, spec.h, len), cf * CFrame.new(0, spec.h / 2, 0), spec.colour, spec.material and M.SmoothPlastic or M.SmoothPlastic)
						local stock = block(shop, V3(spec.stockD, spec.stockH, len - 0.6), cf * CFrame.new(0, spec.h - spec.stockH / 2 - 0.6, 0) + inward * (spec.d / 2), spec.stock[rng:NextInteger(1, #spec.stock)], spec.material or M.SmoothPlastic, false)
						if spec.glass then
							stock.Transparency = 0.5
						end
						runs += 1
					end
				end
			end)
		end
	end
	return runs
end

-- The Urban Eatery's tables and chairs, where the concourse plan draws them.
function Interiors.foodCourt(folder, items, P, S, y)
	-- From the photos: white tables on chrome pedestals, red moulded chairs with
	-- curved backs on a chrome stem, facing their table.
	local seat = C(204, 36, 40)
	local top = C(244, 242, 238)
	local CHROME = C(196, 198, 204)
	local tables = {}
	for _, it in ipairs(items) do
		if it.kind ~= "chair" then
			table.insert(tables, P(it.u, it.v, y))
		end
	end
	local function nearestTable(p)
		local best, bd = nil, math.huge
		for _, t in ipairs(tables) do
			local d = (t - p).Magnitude
			if d < bd then
				best, bd = t, d
			end
		end
		return best, bd
	end
	local n = 0
	for _, it in ipairs(items) do
		local p = P(it.u, it.v, y)
		local cf = CFrame.new(p) * CFrame.Angles(0, it.a or 0, 0)
		if it.kind == "chair" then
			local t, d = nearestTable(p)
			local face = CFrame.new(p)
			if t and d < 12 and (V3(t.X, p.Y, t.Z) - p).Magnitude > 0.1 then
				face = CFrame.lookAt(p, V3(t.X, p.Y, t.Z))
			end
			Util.solid(folder, V3(1.7, 0.3, 1.6), face * CFrame.new(0, 1.65, 0), seat, M.SmoothPlastic)
			Util.deco(folder, V3(1.7, 1.7, 0.25), face * CFrame.new(0, 2.55, 0.8) * CFrame.Angles(math.rad(-10), 0, 0), seat, M.SmoothPlastic)
			Util.cylinder(folder, 1.5, 0.25, face * CFrame.new(0, 0.75, 0), CHROME, M.Metal, false)
			Util.cylinder(folder, 0.1, 1.3, face * CFrame.new(0, 0.05, 0), CHROME, M.Metal, false)
		elseif it.kind == "round" or it.kind == "roundset" then
			local d = (it.kind == "roundset" and 3 or it.w) * S + 0.6
			Util.cylinder(folder, 0.2, d, cf * CFrame.new(0, 2.9, 0), top, M.SmoothPlastic, true)
			Util.cylinder(folder, 2.8, 0.35, cf * CFrame.new(0, 1.4, 0), CHROME, M.Metal, false)
			Util.cylinder(folder, 0.1, 1.8, cf * CFrame.new(0, 0.05, 0), CHROME, M.Metal, false)
			if it.kind == "roundset" then
				for k = 0, 3 do
					local a = k * math.pi / 2
					local cp = p + V3(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
					local face = CFrame.lookAt(cp, p)
					Util.solid(folder, V3(1.7, 0.3, 1.6), face * CFrame.new(0, 1.65, 0), seat, M.SmoothPlastic)
					Util.deco(folder, V3(1.7, 1.7, 0.25), face * CFrame.new(0, 2.55, 0.8) * CFrame.Angles(math.rad(-10), 0, 0), seat, M.SmoothPlastic)
					Util.cylinder(folder, 1.5, 0.25, face * CFrame.new(0, 0.75, 0), CHROME, M.Metal, false)
				end
			end
		else
			Util.solid(folder, V3(it.w * S, 0.2, it.d * S), cf * CFrame.new(0, 2.9, 0), top, M.SmoothPlastic)
			for _, sx in ipairs({ -1, 1 }) do
				local x = sx * math.max(0, it.w * S / 2 - 1)
				Util.cylinder(folder, 2.8, 0.3, cf * CFrame.new(x, 1.4, 0), CHROME, M.Metal, false)
			end
		end
		n += 1
	end
	return n
end

return Interiors
