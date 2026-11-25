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
local function foodHall(folder, at, W, D, rng)
	local stallW = 12
	local names = { "Noodles", "Tacos", "Pizza", "Grill", "Dumplings", "Bakery", "Sushi", "Bao", "Burgers", "Juice", "Curry", "Deli" }
	local n = 0
	for _, side in ipairs({ -1, 1 }) do
		for z = CLEAR_FRONT + 4, D - 10, stallW + 2 do
			n += 1
			local x = side * (W / 2 - 4)
			block(folder, V3(3, 3.6, stallW), at(x - side * 1.5, 1.8, z + stallW / 2), C(60, 48, 40), M.Wood)
			block(folder, V3(3.2, 0.2, stallW + 0.2), at(x - side * 1.5, 3.7, z + stallW / 2), STEEL, M.Metal)
			local sign = block(folder, V3(0.3, 2, stallW - 2), at(x - side * 1.5, 10, z + stallW / 2), C(30, 30, 34), M.SmoothPlastic, false)
			local face = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
			Util.sign(sign, face, string.upper(names[(n - 1) % #names + 1]), C(255, 220, 150), Enum.Font.GothamBold).LightInfluence = 0
		end
	end
	for z = CLEAR_FRONT + 8, D - 12, 10 do
		for _, x in ipairs({ -W / 6, W / 6 }) do
			if math.abs(x) > AISLE + 2 then
				tableTop(folder, at, x, z, 3, 10, WOOD, 3)
				for _, sx in ipairs({ -2.4, 2.4 }) do
					block(folder, V3(1.2, 1.8, 9), at(x + sx, 0.9, z), C(90, 70, 52), M.Wood)
				end
			end
		end
	end
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
		if t and t.status == "open" and box and front and not skip[u.unit] then
			local origin = P(box.cu, box.cv, y)
			local across = (P(box.cu + box.au, box.cv + box.av, y) - origin).Unit
			local inward = (P(box.cu - front[5], box.cv - front[6], y) - origin).Unit
			local W, D = box.width * S, box.depth * S
			local at = frame(origin, across, inward)
			local shop = Instance.new("Folder")
			shop.Name = u.unit
			shop.Parent = folder
			local accent = nil
			if u.unit == "FA100" then
				foodHall(shop, at, W, D, rng)
			else
				local key = levelIdx .. ":" .. u.unit
				local ok, err = pcall(Stores.front, shop, at, W, D, rng, Stores.design(t), key, t)
				if not ok then
					warn("[Interiors] " .. key .. " design failed: " .. tostring(err))
					local template = TEMPLATES[t.category] or TEMPLATES.fashion
					pcall(template, shop, at, W, D, rng, accent)
				end
			end
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
		if t and t.status == "open" and spots and axis and #spots > 0 and not skip[u.unit] and u.unit ~= "FA100" then
			local fixture = FIELD[t.category] or apparel
			local shop = folder:FindFirstChild(u.unit)
			if not shop then
				shop = Instance.new("Folder")
				shop.Name = u.unit
				shop.Parent = folder
			end
			local origin = P(0, 0, y)
			local inward = (P(axis[3], axis[4], y) - origin)
			inward = V3(inward.X, 0, inward.Z).Unit
			local design = Stores.design(t)
			local key = levelIdx .. ":" .. u.unit
			-- The flagship (the H&M stand-in) gets its own hand-planned floor.
			if Stores.isFlagship(design) then
				local okF, res = pcall(Stores.flagship, shop, u, P, S, y, design, key, rng)
				if okF then
					placed += res
					continue
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
		if t and t.status == "open" and (u.shelves or u.floor) and not skip[u.unit] and u.unit ~= "FA100" then
			local spec = WALL[t.category] or WALL.fashion
			local shop = folder:FindFirstChild(u.unit)
			if not shop then
				shop = Instance.new("Folder")
				shop.Name = u.unit
				shop.Parent = folder
			end
			local design = Stores.design(t)
			local key = levelIdx .. ":" .. u.unit
			-- The store's shell first (floor, ceiling, wall finishes, lighting): its
			-- inner walls are the wall runs' line moved back 1.4 ft to the wall.
			local wallLines = {}
			for _, w in ipairs(u.shelves or {}) do
				local inward = P(w[5], w[6], y) - P(0, 0, y)
				inward = V3(inward.X, 0, inward.Z).Unit
				table.insert(wallLines, { a = P(w[1], w[2], y) - inward * 1.4 * S, b = P(w[3], w[4], y) - inward * 1.4 * S, inward = inward })
			end
			local okS, errS = pcall(Stores.shell, shop, u, P, S, y, design, key, wallLines, rng)
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
		end
	end
	return runs
end

-- The Urban Eatery's tables and chairs, where the concourse plan draws them.
function Interiors.foodCourt(folder, items, P, S, y)
	local seat = C(196, 60, 46)
	local top = C(236, 232, 224)
	local n = 0
	for _, it in ipairs(items) do
		local p = P(it.u, it.v, y)
		local cf = CFrame.new(p) * CFrame.Angles(0, it.a or 0, 0)
		if it.kind == "chair" then
			Util.solid(folder, V3(1.5 * S + 0.3, 1.6, 1.5 * S + 0.3), cf * CFrame.new(0, 0.8, 0), seat, M.SmoothPlastic)
		elseif it.kind == "round" or it.kind == "roundset" then
			local d = (it.kind == "roundset" and 3 or it.w) * S + 0.6
			Util.cylinder(folder, 0.25, d, cf * CFrame.new(0, 2.9, 0), top, M.Marble, true)
			Util.cylinder(folder, 2.8, 0.4, cf * CFrame.new(0, 1.4, 0), C(60, 62, 68), M.Metal, false)
			if it.kind == "roundset" then
				for k = 0, 3 do
					local a = k * math.pi / 2
					Util.solid(folder, V3(1.6, 1.6, 1.6), cf * CFrame.new(math.cos(a) * 2.6, 0.8, math.sin(a) * 2.6), seat, M.SmoothPlastic)
				end
			end
		else
			Util.solid(folder, V3(it.w * S, 0.25, it.d * S), cf * CFrame.new(0, 2.9, 0), top, M.Marble)
			Util.deco(folder, V3(0.5, 2.8, 0.5), cf * CFrame.new(0, 1.4, 0), C(60, 62, 68), M.Metal)
		end
		n += 1
	end
	return n
end

return Interiors
