-- Fully furnished interiors for the hero block: a convenience store and a cafe.
-- Each fills the ground floor behind a Facade.storefront (which provides the glass
-- front and sliding doors). Purchases reuse the shared store system.
--
-- Building-local space: cf is the footprint's ground centre, the street is at -Z,
-- glassZ is the shopfront line and the room runs back to the rear wall.
local Util = require(script.Parent.Util)
local Stores = require(script.Parent.Stores)

local HeroInteriors = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front

local function shell(folder, cf, w, d, gh, glassZ, wallColor, floorColor, floorMaterial)
	local kerb = Util.WALK_TOP
	local backZ = d / 2 - 0.5
	local depth = backZ - glassZ
	local inner = w / 2 - 1.6
	local midZ = glassZ + depth / 2
	Util.solid(folder, V3(inner * 2, 0.4, depth), cf * CFrame.new(0, kerb - 0.15, midZ), floorColor, floorMaterial)
	Util.solid(folder, V3(inner * 2, gh, 1), cf * CFrame.new(0, gh / 2, backZ), wallColor, M.Plaster)
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(1, gh, depth), cf * CFrame.new(side * (inner + 0.5), gh / 2, midZ), wallColor, M.Plaster)
	end
	local ceilingY = gh - 3.2
	Util.deco(folder, V3(inner * 2, 0.3, depth), cf * CFrame.new(0, ceilingY + 0.15, midZ), Color3.fromRGB(236, 234, 228), M.SmoothPlastic)
	-- Block off the space above the ceiling.
	Util.solid(folder, V3(inner * 2, gh - ceilingY - 0.3, depth), cf * CFrame.new(0, (ceilingY + 0.3 + gh) / 2, midZ), wallColor, M.Concrete)
	return {
		kerb = kerb,
		floorY = kerb + 0.05,
		ceilingY = ceilingY,
		backZ = backZ - 0.5,
		frontZ = glassZ + 0.5,
		inner = inner - 0.5,
		depth = depth,
		midZ = midZ,
	}
end

local function lightPanel(folder, cf, x, y, z, color)
	local panel = Util.deco(folder, V3(5, 0.15, 2), cf * CFrame.new(x, y - 0.1, z), Color3.fromRGB(250, 250, 246), M.Neon)
	panel.CastShadow = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 14
	light.Angle = 110
	light.Brightness = 1.2
	light.Color = color or Color3.fromRGB(245, 248, 255)
	light.Parent = panel
end

local function poster(folder, cf, x, y, z, name, facing)
	local p = Util.deco(folder, V3(3.2, 4.8, 0.1), cf * CFrame.new(x, y, z) * CFrame.Angles(0, facing or 0, 0), Color3.fromRGB(220, 60, 60), M.SmoothPlastic)
	Util.decal(p, Front, name)
	return p
end

local function chair(folder, cf, color)
	Util.solid(folder, V3(1.8, 0.3, 1.8), cf * CFrame.new(0, 1.9, 0), color, M.Wood)
	Util.deco(folder, V3(1.8, 2.2, 0.25), cf * CFrame.new(0, 3.1, 0.8), color, M.Wood)
	for _, x in ipairs({ -0.75, 0.75 }) do
		for _, z in ipairs({ -0.75, 0.75 }) do
			Util.deco(folder, V3(0.2, 1.8, 0.2), cf * CFrame.new(x, 0.9, z), Color3.fromRGB(30, 30, 30), M.Metal)
		end
	end
end

local function cafeTable(folder, cf, top)
	Util.cylinder(folder, 0.25, 3.4, cf * CFrame.new(0, 3.05, 0), top, M.Marble, true)
	Util.cylinder(folder, 2.9, 0.35, cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(30, 30, 30), M.Metal, false)
	Util.cylinder(folder, 0.2, 1.8, cf * CFrame.new(0, 0.2, 0), Color3.fromRGB(30, 30, 30), M.Metal, false)
end

local function plant(folder, cf)
	Util.cylinder(folder, 2.2, 2, cf * CFrame.new(0, 1.1, 0), Color3.fromRGB(190, 120, 80), M.Slate, true)
	local leaves = Util.deco(folder, V3(3, 3.2, 3), cf * CFrame.new(0, 3.6, 0), Color3.fromRGB(60, 120, 60), M.LeafyGrass, Enum.PartType.Ball)
	leaves.CastShadow = false
end

---------------------------------------------------------------------------
-- Convenience store
---------------------------------------------------------------------------
function HeroInteriors.convenience(folder, cf, w, d, gh, glassZ, storeName)
	local s = shell(folder, cf, w, d, gh, glassZ, Color3.fromRGB(232, 230, 222), Color3.fromRGB(214, 210, 200), M.CeramicTiles)
	local y = s.floorY
	local function at(x, h, z)
		return cf * CFrame.new(x, y + h, z)
	end

	-- Checkout counter by the door, with register, card reader and impulse racks.
	local counterX = s.inner - 4.5
	local counterZ = s.frontZ + 6
	local counter = Util.solid(folder, V3(7, 3.6, 2.6), at(counterX, 1.8, counterZ), Color3.fromRGB(120, 84, 54), M.Wood)
	Util.deco(folder, V3(7.3, 0.2, 2.9), at(counterX, 3.7, counterZ), Color3.fromRGB(40, 40, 42), M.Granite)
	Util.deco(folder, V3(1.6, 1, 1.3), at(counterX - 1.5, 4.3, counterZ), Color3.fromRGB(30, 30, 32), M.Metal)
	Util.deco(folder, V3(1.2, 0.8, 0.1), at(counterX - 1.5, 5, counterZ - 0.6), Color3.fromRGB(40, 140, 200), M.Neon)
	Util.deco(folder, V3(0.5, 0.8, 0.4), at(counterX + 0.6, 4.2, counterZ - 0.8), Color3.fromRGB(20, 20, 22), M.Metal)
	local gum = Util.deco(folder, V3(3, 2.6, 0.6), at(counterX, 1.6, counterZ - 1.6), Color3.fromRGB(200, 200, 196), M.Metal)
	Util.texture(gum, Front, "shop_shelves", 3, 3)
	Stores.attachPurchase(counter, "bodega", storeName)
	-- Back bar behind the counter.
	local back = Util.deco(folder, V3(1, 7, 8), at(s.inner - 0.5, 3.5, counterZ), Color3.fromRGB(80, 80, 84), M.Metal)
	Util.texture(back, Enum.NormalId.Left, "shop_shelves", 6, 6)
	local lotto = Util.deco(folder, V3(0.1, 1.6, 4), at(s.inner - 1.05, 7.8, counterZ), Color3.fromRGB(240, 200, 40), M.Neon)
	Util.sign(lotto, Enum.NormalId.Left, "LOTTO · ATM · ICE", Color3.fromRGB(30, 30, 30), Enum.Font.GothamBlack).LightInfluence = 0

	-- Gondola aisles running toward the back.
	local aisleLen = math.max(8, s.depth - 16)
	local aisleZ = s.frontZ + 9 + aisleLen / 2
	local aisles = math.max(1, math.floor((s.inner * 2 - 12) / 7))
	for i = 1, aisles do
		local x = -s.inner + 4 + (i - 1) * 7
		local gondola = Util.solid(folder, V3(2.4, 6, aisleLen), at(x, 3, aisleZ), Color3.fromRGB(226, 226, 222), M.Metal)
		Util.texture(gondola, Enum.NormalId.Left, "shop_shelves", 6, 6)
		Util.texture(gondola, Enum.NormalId.Right, "shop_shelves", 6, 6)
		Util.deco(folder, V3(2.6, 0.3, aisleLen + 0.2), at(x, 6.1, aisleZ), Color3.fromRGB(196, 40, 40), M.SmoothPlastic)
		local tag = Util.deco(folder, V3(3, 1, 0.15), at(x, s.ceilingY - y - 1.5, aisleZ - aisleLen / 2), Color3.fromRGB(196, 40, 40), M.SmoothPlastic)
		local labels = { "SNACKS", "GROCERY", "HOUSEHOLD", "CANDY" }
		Util.sign(tag, Front, labels[(i - 1) % #labels + 1], Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold).LightInfluence = 0
	end

	-- Drink fridges along the back wall, glowing.
	local fridges = math.max(2, math.floor((s.inner * 2 - 8) / 4.5))
	for i = 1, fridges do
		local x = -s.inner + 2.6 + (i - 1) * 4.5
		local fridge = Util.solid(folder, V3(4.3, 8, 2.2), at(x, 4, s.backZ - 1.1), Color3.fromRGB(200, 204, 208), M.Metal)
		local door = Util.deco(folder, V3(4, 7.4, 0.1), at(x, 4, s.backZ - 2.25), Color3.fromRGB(200, 230, 245), M.Glass)
		if Util.decal(door, Front, "shop_fridge") then
			door.Material = M.SmoothPlastic
			door.Color = Color3.new(1, 1, 1)
		end
		if i % 2 == 1 then
			local glow = Instance.new("SurfaceLight")
			glow.Face = Front
			glow.Range = 8
			glow.Brightness = 0.6
			glow.Color = Color3.fromRGB(220, 240, 255)
			glow.Parent = fridge
		end
	end

	-- Ice chest, ATM, mop bucket, entrance mat, posters, staff door, lights.
	local chest = Util.solid(folder, V3(5, 3.2, 2.4), at(-s.inner + 3, 1.6, s.frontZ + 2), Color3.fromRGB(235, 235, 235), M.SmoothPlastic)
	Util.sign(chest, Front, "ICE", Color3.fromRGB(40, 120, 200), Enum.Font.GothamBlack)
	Util.solid(folder, V3(2.4, 5.5, 1.8), at(-s.inner + 7, 2.75, s.frontZ + 1.4), Color3.fromRGB(60, 64, 70), M.Metal)
	Util.deco(folder, V3(1.6, 1.2, 0.1), at(-s.inner + 7, 4.2, s.frontZ + 0.45), Color3.fromRGB(80, 200, 120), M.Neon)
	Util.cylinder(folder, 1.6, 1.8, at(s.inner - 2, 0.8, s.backZ - 5), Color3.fromRGB(240, 200, 30), M.SmoothPlastic, true)
	Util.deco(folder, V3(5, 0.05, 3.5), at(0, 0.03, s.frontZ + 2.2), Color3.fromRGB(40, 40, 44), M.Fabric)
	poster(folder, cf, -s.inner - 0.4, y + 6, s.midZ, "poster_cola", math.rad(-90))
	poster(folder, cf, -s.inner - 0.4, y + 6, s.midZ + 6, "poster_radio", math.rad(-90))
	local staff = Util.deco(folder, V3(4, 8, 0.2), at(s.inner - 3, 4, s.backZ - 0.05), Color3.fromRGB(110, 110, 112), M.Metal)
	Util.sign(staff, Front, "STAFF ONLY", Color3.fromRGB(240, 240, 240), Enum.Font.GothamBold)
	for z = s.frontZ + 5, s.backZ - 3, 10 do
		for _, x in ipairs({ -s.inner / 2, s.inner / 2 }) do
			lightPanel(folder, cf, x, s.ceilingY, z)
		end
	end
end

---------------------------------------------------------------------------
-- Cafe
---------------------------------------------------------------------------
function HeroInteriors.cafe(folder, cf, w, d, gh, glassZ, storeName, rng)
	local s = shell(folder, cf, w, d, gh, glassZ, Color3.fromRGB(214, 196, 170), Color3.fromRGB(120, 86, 58), M.WoodPlanks)
	local y = s.floorY
	local function at(x, h, z)
		return cf * CFrame.new(x, y + h, z)
	end
	local warm = Color3.fromRGB(255, 214, 160)

	-- Brick feature wall at the back with the counter in front of it.
	local feature = Util.deco(folder, V3(s.inner * 2, s.ceilingY - y, 0.2), at(0, (s.ceilingY - y) / 2, s.backZ - 0.1), Color3.fromRGB(150, 80, 60), M.Brick)
	Util.texture(feature, Front, "brick_red", 5, 5)
	local counterZ = s.backZ - 6
	local counter = Util.solid(folder, V3(s.inner * 1.3, 3.6, 2.6), at(-s.inner * 0.3, 1.8, counterZ), Color3.fromRGB(70, 50, 36), M.Wood)
	Util.deco(folder, V3(s.inner * 1.3 + 0.3, 0.2, 2.9), at(-s.inner * 0.3, 3.7, counterZ), Color3.fromRGB(230, 226, 220), M.Marble)
	Stores.attachPurchase(counter, "coffee", storeName)
	-- Pastry case, espresso machine, grinder, register, cups.
	local case = Util.deco(folder, V3(4.5, 2.2, 2.2), at(-s.inner * 0.3 + s.inner * 0.4, 4.9, counterZ), Color3.fromRGB(220, 235, 240), M.Glass)
	case.Transparency = 0.4
	for i = -1, 1 do
		Util.deco(folder, V3(0.9, 0.5, 0.9), at(-s.inner * 0.3 + s.inner * 0.4 + i * 1.3, 4.1, counterZ), Color3.fromRGB(200, 150, 80), M.SmoothPlastic, Enum.PartType.Ball)
	end
	Util.solid(folder, V3(3.4, 2.2, 1.8), at(-s.inner * 0.3 - s.inner * 0.35, 4.9, counterZ + 0.2), Color3.fromRGB(190, 190, 196), M.Metal)
	Util.deco(folder, V3(1, 1.8, 1), at(-s.inner * 0.3 - s.inner * 0.35 + 2.4, 4.7, counterZ), Color3.fromRGB(30, 30, 30), M.Metal)
	Util.deco(folder, V3(1.4, 1, 1.1), at(-s.inner * 0.3 + 0.5, 4.3, counterZ), Color3.fromRGB(30, 30, 32), M.Metal)
	for i = 0, 3 do
		Util.cylinder(folder, 0.9, 0.6, at(-s.inner * 0.3 - 1.5 + i * 0.7, 4.25, counterZ - 0.8), Color3.fromRGB(245, 245, 240), M.SmoothPlastic, false)
	end
	-- Menu board above the counter.
	local menu = Util.deco(folder, V3(10, 5, 0.2), at(-s.inner * 0.3, s.ceilingY - y - 3.2, s.backZ - 0.3), Color3.fromRGB(30, 30, 30), M.SmoothPlastic)
	if not Util.decal(menu, Front, "menu_board") then
		Util.sign(menu, Front, "ESPRESSO · LATTE · COLD BREW", Color3.fromRGB(240, 220, 170), Enum.Font.Merriweather)
	end
	-- Shelf of mugs and beans on the side wall.
	Util.deco(folder, V3(0.6, 0.3, 8), at(s.inner - 0.3, 6, counterZ - 2), Color3.fromRGB(70, 50, 36), M.Wood)
	for i = 0, 5 do
		Util.cylinder(folder, 0.8, 0.7, at(s.inner - 0.4, 6.55, counterZ - 5 + i * 1.2), Util.pick(rng, { Color3.fromRGB(240, 240, 235), Color3.fromRGB(60, 90, 80), Color3.fromRGB(180, 80, 50) }), M.SmoothPlastic, false)
	end

	-- Tables with chairs, and a bench along one wall.
	local rows = math.max(1, math.floor((counterZ - 4 - (s.frontZ + 4)) / 7))
	for r = 0, rows - 1 do
		for _, x in ipairs({ -s.inner * 0.45, s.inner * 0.35 }) do
			local z = s.frontZ + 5 + r * 7
			local base = at(x, 0, z)
			cafeTable(folder, base, Color3.fromRGB(236, 234, 228))
			chair(folder, base * CFrame.new(-2.4, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(90, 60, 40))
			chair(folder, base * CFrame.new(2.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(90, 60, 40))
			-- Pendant lamp over each table.
			local hang = s.ceilingY - y - 3
			Util.deco(folder, V3(0.1, 3, 0.1), at(x, hang + 1.5, z), Color3.fromRGB(20, 20, 20), M.Metal)
			local shade = Util.deco(folder, V3(1.6, 1, 1.6), at(x, hang, z), Color3.fromRGB(30, 30, 30), M.Metal)
			local light = Instance.new("PointLight")
			light.Range = 10
			light.Brightness = 0.9
			light.Color = warm
			light.Parent = shade
		end
	end
	Util.solid(folder, V3(2.4, 1.8, s.depth * 0.5), at(-s.inner + 1.2, 0.9, s.frontZ + s.depth * 0.3), Color3.fromRGB(70, 50, 36), M.Wood)
	Util.deco(folder, V3(2.4, 0.5, s.depth * 0.5), at(-s.inner + 1.2, 2.05, s.frontZ + s.depth * 0.3), Color3.fromRGB(40, 70, 60), M.Fabric)
	poster(folder, cf, -s.inner - 0.4, y + 6.5, s.frontZ + s.depth * 0.3, "poster_radio", math.rad(-90))
	plant(folder, at(s.inner - 1.6, 0, s.frontZ + 2))
	plant(folder, at(-s.inner + 1.6, 0, counterZ - 3))
	for z = s.frontZ + 4, s.backZ - 3, 9 do
		lightPanel(folder, cf, 0, s.ceilingY, z, warm)
	end

	-- Outdoor seating on the sidewalk in front.
	local outsideZ = -d / 2 - 5
	for _, x in ipairs({ -w * 0.3, w * 0.25 }) do
		local base = cf * CFrame.new(x, Util.WALK_TOP, outsideZ)
		cafeTable(folder, base, Color3.fromRGB(236, 234, 228))
		chair(folder, base * CFrame.new(-2.4, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(40, 40, 40))
		chair(folder, base * CFrame.new(2.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(40, 40, 40))
		Util.cylinder(folder, 7, 0.25, base * CFrame.new(0, 6.6, 0), Color3.fromRGB(60, 60, 60), M.Metal, false)
		Util.cylinder(folder, 0.4, 8, base * CFrame.new(0, 9.9, 0), Color3.fromRGB(40, 70, 60), M.Fabric, false)
	end
	plant(folder, cf * CFrame.new(-w / 2 + 2, Util.WALK_TOP, outsideZ + 1.5))
	plant(folder, cf * CFrame.new(w / 2 - 2, Util.WALK_TOP, outsideZ + 1.5))
	local aboard = Util.deco(folder, V3(2, 3, 0.2), cf * CFrame.new(0, Util.WALK_TOP + 1.5, outsideZ - 2) * CFrame.Angles(math.rad(10), 0, 0), Color3.fromRGB(30, 30, 30), M.Wood)
	Util.sign(aboard, Front, "COFFEE", Color3.fromRGB(240, 236, 220), Enum.Font.Merriweather)
end

return HeroInteriors
