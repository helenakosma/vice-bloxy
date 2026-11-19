-- The hero block: the stretch of downtown's central avenue around the player spawn,
-- built to the full detail standard. Buildings use the facade kit (real window
-- depth, storefronts, entrances), two shops are fully furnished walk-in interiors,
-- and the street gets crosswalks, stop lines, turn arrows, manholes, drains,
-- patches, meters, benches, signs, a loading zone and a rooftop billboard.
local Workspace = game:GetService("Workspace")

local Util = require(script.Parent.Util)
local Roads = require(script.Parent.Roads)
local Facade = require(script.Parent.Facade)
local HeroInteriors = require(script.Parent.HeroInteriors)
local Props = require(script.Parent.Props)
local Buildings = require(script.Parent.Buildings)

local HeroStreet = {}

local V3 = Vector3.new
local M = Enum.Material
local Top = Enum.NormalId.Top
local Front = Enum.NormalId.Front

local HALF_LENGTH = 190 -- along the avenue from the spawn point
local HALF_WIDTH = 150 -- across it (covers the building lots)
-- Decals on a part's Top face: set to false if road arrows appear reversed in Studio.
local ARROW_TOP_IS_FRONT = true

local BRICKS = {
	{ color = Color3.fromRGB(150, 76, 56), material = M.Brick, texture = "brick_red", tile = 5 },
	{ color = Color3.fromRGB(122, 86, 66), material = M.Brick, texture = "brick_brown", tile = 5 },
}
local LIMESTONE = { color = Color3.fromRGB(206, 196, 176), material = M.Limestone, texture = "limestone", tile = 12 }
local CAST_IRON = {
	{ color = Color3.fromRGB(196, 188, 172), material = M.Concrete, texture = "concrete_stained", tile = 14 },
	{ color = Color3.fromRGB(120, 124, 120), material = M.Concrete, texture = "concrete_stained", tile = 14 },
}
local TRIM_STONE = { color = Color3.fromRGB(214, 206, 188), material = M.Limestone }
local TRIM_DARK = { color = Color3.fromRGB(90, 86, 80), material = M.Concrete }
local AWNINGS = { Color3.fromRGB(28, 58, 40), Color3.fromRGB(96, 24, 28), Color3.fromRGB(24, 32, 60), Color3.fromRGB(26, 26, 28) }
local SHOP_NAMES = { "GREENWICH DELI", "MARIO'S SHOES", "PARK SLOPE OPTICS", "THE BAGEL HOLE", "CITY FLOWERS", "UNION HARDWARE", "BLUE NOTE RECORDS", "MIDTOWN TAILOR", "ATLAS BOOKS", "NOODLE BAR" }

---------------------------------------------------------------------------
-- Buildings
---------------------------------------------------------------------------
local function core(folder, cf, w, d, y0, y1, recess, wall)
	local p = Util.solid(folder, V3(w, y1 - y0, d - recess), cf * CFrame.new(0, (y0 + y1) / 2, recess / 2), wall.color, wall.material)
	if wall.texture then
		Util.texture(p, Enum.NormalId.Left, wall.texture, wall.tile, wall.tile)
		Util.texture(p, Enum.NormalId.Right, wall.texture, wall.tile, wall.tile)
	end
	return p
end

local function roofClutter(folder, cf, w, d, y, rng)
	for _ = 1, rng:NextInteger(1, 3) do
		local x = rng:NextNumber(-w / 3, w / 3)
		local z = rng:NextNumber(-d / 4, d / 3)
		Util.deco(folder, V3(4, 3, 3), cf * CFrame.new(x, y + 1.5, z), Color3.fromRGB(176, 176, 172), M.Metal)
		Util.deco(folder, V3(3.4, 0.2, 2.4), cf * CFrame.new(x, y + 3.1, z), Color3.fromRGB(90, 90, 90), M.DiamondPlate)
	end
	Util.deco(folder, V3(0.3, 8, 0.3), cf * CFrame.new(w / 3, y + 4, d / 4), Color3.fromRGB(60, 60, 60), M.Metal)
end

-- Ground floor: an enterable shop, a regular storefront, or a building entrance.
local function groundFloor(hero, folder, cf, w, d, gh, wall, trim, kind, rng)
	local front = -d / 2
	if kind == "entrance" then
		Facade.entrance(folder, cf, w, d, { groundH = gh, wall = wall, trim = trim, base = LIMESTONE, address = tostring(rng:NextInteger(10, 480)) }, rng)
		Util.solid(folder, V3(w, gh, d - 1.2), cf * CFrame.new(0, gh / 2, 0.6), wall.color, wall.material)
		return
	end
	local interior = nil
	if kind == "shop" and w >= 26 and d >= 34 then
		if not hero.madeStore then
			interior = "convenience"
		elseif not hero.madeCafe then
			interior = "cafe"
		end
	end
	local name
	if interior == "convenience" then
		name = "CORNER MART 24/7"
	elseif interior == "cafe" then
		name = "BEAN STREET COFFEE"
	else
		name = Util.pick(rng, SHOP_NAMES)
	end
	local glassZ = Facade.storefront(folder, cf, w, d, {
		groundH = gh,
		wall = wall,
		trim = trim,
		name = name,
		signColor = interior == "cafe" and Color3.fromRGB(40, 70, 60) or Util.pick(rng, { Color3.fromRGB(28, 30, 32), Color3.fromRGB(110, 24, 30), Color3.fromRGB(20, 40, 70) }),
		doorX = (interior and 0) or rng:NextNumber(-w / 4, w / 4),
		enterable = interior ~= nil,
		interior = rng:NextNumber() < 0.5 and "deli" or "boutique",
		awning = (rng:NextNumber() < 0.55) and Util.pick(rng, AWNINGS) or nil,
		gate = rng:NextNumber() < 0.4,
	}, rng)
	if interior == "convenience" then
		hero.madeStore = true
		HeroInteriors.convenience(folder, cf, w, d, gh, glassZ, name)
	elseif interior == "cafe" then
		hero.madeCafe = true
		HeroInteriors.cafe(folder, cf, w, d, gh, glassZ, name, rng)
	else
		-- Close off the rest of the ground floor behind the visible shop.
		local backFrom = glassZ + 6.2
		Util.solid(folder, V3(w, gh, d / 2 - backFrom), cf * CFrame.new(0, gh / 2, (backFrom + d / 2) / 2), wall.color, wall.material)
		for _, side in ipairs({ -1, 1 }) do
			Util.solid(folder, V3(1, gh, backFrom - front - 2.8), cf * CFrame.new(side * (w / 2 - 0.5), gh / 2, (front + 2.8 + backFrom) / 2), wall.color, wall.material)
		end
	end
	return front
end

local Variants = {}

function Variants.walkup(hero, folder, cf, w, d, rng)
	local wall = Util.pick(rng, BRICKS)
	local gh, floorH = 15, 10.5
	local floors = rng:NextInteger(4, 6)
	local spec = { floors = floors, floorH = floorH, y0 = gh, wall = wall, trim = TRIM_STONE, windowW = 4, windowH = 6, sillH = 2.4, lintels = true, ac = 0.22, lit = 0.15, recess = 0.9 }
	core(folder, cf, w, d, gh, gh + floors * floorH, spec.recess, wall)
	local top = Facade.upper(folder, cf, w, d, spec, rng)
	Facade.cornice(folder, cf, w, d, top, TRIM_STONE, wall)
	groundFloor(hero, folder, cf, w, d, gh, wall, TRIM_STONE, "shop", rng)
	if rng:NextNumber() < 0.6 then
		Facade.fireEscape(folder, cf, w, d, gh, floors, floorH)
	end
	if rng:NextNumber() < 0.4 then
		Buildings.waterTower(folder, cf * CFrame.new(0, 0, d / 6), top + 3)
	else
		roofClutter(folder, cf, w, d, top, rng)
	end
	Facade.grime(folder, cf, w, d, gh, top + 3)
	return top
end

function Variants.loft(hero, folder, cf, w, d, rng)
	local wall = Util.pick(rng, CAST_IRON)
	local gh, floorH = 16, 13
	local floors = rng:NextInteger(5, 7)
	local spec = { floors = floors, floorH = floorH, y0 = gh, wall = wall, trim = TRIM_DARK, windowW = 5.5, windowH = 9, sillH = 2, beltEvery = 2, ac = 0.1, lit = 0.2, recess = 1.1 }
	core(folder, cf, w, d, gh, gh + floors * floorH, spec.recess, wall)
	local top = Facade.upper(folder, cf, w, d, spec, rng)
	Facade.cornice(folder, cf, w, d, top, TRIM_DARK, wall)
	groundFloor(hero, folder, cf, w, d, gh, wall, TRIM_DARK, "shop", rng)
	roofClutter(folder, cf, w, d, top, rng)
	Facade.grime(folder, cf, w, d, gh, top + 3)
	return top
end

function Variants.office(hero, folder, cf, w, d, rng)
	local wall = LIMESTONE
	local gh, floorH = 18, 11
	local floors = rng:NextInteger(11, 15)
	local spec = { floors = floors, floorH = floorH, y0 = gh, wall = wall, trim = TRIM_STONE, windowW = 4.5, windowH = 6.5, sillH = 2.4, lintels = true, beltEvery = 4, lit = 0.1, recess = 1 }
	core(folder, cf, w, d, gh, gh + floors * floorH, spec.recess, wall)
	local top = Facade.upper(folder, cf, w, d, spec, rng)
	Facade.cornice(folder, cf, w, d, top, TRIM_STONE, wall)
	groundFloor(hero, folder, cf, w, d, gh, wall, TRIM_STONE, "entrance", rng)
	roofClutter(folder, cf, w, d, top + 3, rng)
	Facade.grime(folder, cf, w, d, gh, top + 3)
	return top
end

-- Modern glass tower: curtain wall with a real mullion grid and a columned lobby.
function Variants.glass(hero, folder, cf, w, d, rng)
	local gh, floorH = 20, 12
	local floors = rng:NextInteger(16, 24)
	local h = gh + floors * floorH
	local front = -d / 2
	local tint = Util.pick(rng, { Color3.fromRGB(78, 96, 108), Color3.fromRGB(96, 104, 104), Color3.fromRGB(70, 84, 96) })
	local frame = Color3.fromRGB(84, 88, 92)
	local tower = Util.solid(folder, V3(w, h - gh, d), cf * CFrame.new(0, gh + (h - gh) / 2, 0), tint, M.Glass)
	tower.Reflectance = 0.42
	local cols = math.max(2, math.floor(w / 6))
	for j = 0, cols do
		local x = -w / 2 + w * j / cols
		Util.deco(folder, V3(0.5, h - gh, 0.6), cf * CFrame.new(x, gh + (h - gh) / 2, front - 0.25), frame, M.Metal)
	end
	for f = 1, floors do
		Util.deco(folder, V3(w + 0.3, 0.9, 0.6), cf * CFrame.new(0, gh + f * floorH - 0.45, front - 0.25), frame, M.Metal)
	end
	Util.deco(folder, V3(w * 0.85, 7, d * 0.8), cf * CFrame.new(0, h + 3.5, 0), Util.shade(tint, 0.6), M.Metal)
	-- Lobby: glass set 4 studs back behind round columns, under a canopy.
	Util.solid(folder, V3(w, gh, d - 4), cf * CFrame.new(0, gh / 2, 2), Color3.fromRGB(46, 46, 48), M.Granite)
	local lobby = Util.deco(folder, V3(w - 2, gh - 2, 0.3), cf * CFrame.new(0, (gh - 2) / 2 + 0.5, front + 3.9), Color3.fromRGB(150, 140, 120), M.Glass)
	lobby.Transparency = 0.3
	local glow = Instance.new("SurfaceLight")
	glow.Face = Front
	glow.Range = 12
	glow.Brightness = 0.8
	glow.Color = Color3.fromRGB(255, 230, 190)
	glow.Parent = lobby
	local n = math.max(2, math.floor(w / 10))
	for j = 0, n do
		Util.cylinder(folder, gh, 1.6, cf * CFrame.new(-w / 2 + 1 + (w - 2) * j / n, gh / 2, front + 1), Color3.fromRGB(200, 200, 204), M.Metal, true)
	end
	Util.deco(folder, V3(14, 0.6, 6), cf * CFrame.new(0, 12, front - 2.5), frame, M.Metal)
	local revolving = Util.cylinder(folder, 10, 7, cf * CFrame.new(0, Util.WALK_TOP + 5, front + 3.5), Color3.fromRGB(170, 190, 196), M.Glass, false)
	revolving.Transparency = 0.5
	return h
end

local ORDER = { "walkup", "loft", "office", "walkup", "glass", "loft", "walkup", "office" }

---------------------------------------------------------------------------
-- Street kit
---------------------------------------------------------------------------
local function flatPart(folder, size, pos2, dir, y, color, material)
	return Util.deco(folder, size, Util.groundCF(pos2, dir, y), color, material or M.SmoothPlastic)
end

local function roadDecal(folder, pos2, dir, size, name, y)
	local facing = ARROW_TOP_IS_FRONT and dir or -dir
	local p = flatPart(folder, V3(size.X, 0.05, size.Y), pos2, facing, y or (Util.ROAD_TOP + 0.04), Color3.new(1, 1, 1))
	p.Transparency = 1
	if not Util.decal(p, Top, name) then
		p:Destroy()
		return nil
	end
	return p
end

local function crosswalk(folder, centre, dir, roadWidth)
	local normal = Vector2.new(-dir.Y, dir.X)
	for off = -roadWidth / 2 + 2, roadWidth / 2 - 2, 3.4 do
		flatPart(folder, V3(1.9, 0.05, 9), centre + normal * off, dir, Util.ROAD_TOP + 0.04, Color3.fromRGB(236, 236, 230))
	end
end

local function parkingMeter(folder, p, facing)
	local base = Util.groundCF(p, facing, Util.WALK_TOP)
	Util.cylinder(folder, 3.6, 0.25, base * CFrame.new(0, 1.8, 0), Color3.fromRGB(70, 72, 74), M.Metal, true)
	Util.deco(folder, V3(0.7, 1.1, 0.5), base * CFrame.new(0, 4, 0), Color3.fromRGB(40, 42, 44), M.Metal)
	Util.deco(folder, V3(0.45, 0.35, 0.05), base * CFrame.new(0, 4.2, -0.26), Color3.fromRGB(120, 200, 140), M.Neon)
end

local function bench(folder, p, facing)
	local base = Util.groundCF(p, facing, Util.WALK_TOP)
	for _, x in ipairs({ -2.2, 2.2 }) do
		Util.deco(folder, V3(0.3, 2, 1.8), base * CFrame.new(x, 1, 0), Color3.fromRGB(30, 34, 32), M.Metal)
	end
	for k = 0, 2 do
		Util.solid(folder, V3(5.4, 0.2, 0.5), base * CFrame.new(0, 2.05, -0.6 + k * 0.6), Color3.fromRGB(120, 86, 56), M.Wood)
	end
	for k = 0, 1 do
		Util.deco(folder, V3(5.4, 0.45, 0.15), base * CFrame.new(0, 2.8 + k * 0.7, 0.85) * CFrame.Angles(math.rad(-10), 0, 0), Color3.fromRGB(120, 86, 56), M.Wood)
	end
end

local function utilityBox(folder, p, facing)
	local base = Util.groundCF(p, facing, Util.WALK_TOP)
	Util.solid(folder, V3(2.6, 4, 1.6), base * CFrame.new(0, 2, 0), Color3.fromRGB(76, 96, 80), M.Metal)
	Util.deco(folder, V3(0.08, 3.4, 0.05), base * CFrame.new(0, 2, -0.82), Color3.fromRGB(40, 50, 44), M.Metal)
	Util.deco(folder, V3(0.9, 0.5, 0.05), base * CFrame.new(0.6, 3.2, -0.82), Color3.fromRGB(240, 200, 40), M.SmoothPlastic)
end

local function mailbox(folder, p, facing)
	local base = Util.groundCF(p, facing, Util.WALK_TOP)
	Util.solid(folder, V3(1.8, 2.6, 1.8), base * CFrame.new(0, 2.4, 0), Color3.fromRGB(30, 60, 140), M.Metal)
	Util.cylinder(folder, 1.8, 1.8, base * CFrame.new(0, 3.7, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)), Color3.fromRGB(30, 60, 140), M.Metal, false)
	for _, x in ipairs({ -0.7, 0.7 }) do
		Util.deco(folder, V3(0.25, 1.1, 1.6), base * CFrame.new(x, 0.55, 0), Color3.fromRGB(30, 30, 30), M.Metal)
	end
end

local function bikeRack(folder, p, dir)
	local base = Util.groundCF(p, dir, Util.WALK_TOP)
	for k = -1, 1 do
		for _, z in ipairs({ -1, 1 }) do
			Util.deco(folder, V3(0.18, 2.6, 0.18), base * CFrame.new(k * 1.6, 1.3, z), Color3.fromRGB(150, 150, 150), M.Metal)
		end
		Util.deco(folder, V3(0.18, 0.18, 2.2), base * CFrame.new(k * 1.6, 2.6, 0), Color3.fromRGB(150, 150, 150), M.Metal)
	end
end

local function treePit(folder, lifted, p, rng)
	Util.deco(folder, V3(5, 0.1, 5), CFrame.new(p.X, Util.WALK_TOP + 0.03, p.Y), Color3.fromRGB(70, 56, 44), M.Ground)
	for _, e in ipairs({ { 0, -2.5, 5, 0.2 }, { 0, 2.5, 5, 0.2 }, { -2.5, 0, 0.2, 5 }, { 2.5, 0, 0.2, 5 } }) do
		Util.deco(folder, V3(e[3], 1.2, e[4]), CFrame.new(p.X + e[1], Util.WALK_TOP + 0.6, p.Y + e[2]), Color3.fromRGB(30, 30, 30), M.Metal)
	end
	Props.tree(lifted, p, rng)
end

local function streetSign(folder, p, dirA, nameA, dirB, nameB)
	local base = CFrame.new(p.X, Util.WALK_TOP, p.Y)
	Util.cylinder(folder, 14, 0.45, base * CFrame.new(0, 7, 0), Color3.fromRGB(60, 64, 60), M.Metal, true)
	for i, info in ipairs({ { dirA, nameA }, { dirB, nameB } }) do
		local blade = Util.deco(folder, V3(0.12, 1.2, 7), Util.groundCF(p, info[1], Util.WALK_TOP + 12 + i * 1.4), Color3.fromRGB(0, 110, 70), M.SmoothPlastic)
		for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
			Util.sign(blade, face, info[2], Color3.fromRGB(245, 245, 240), Enum.Font.GothamBold).LightInfluence = 0.3
		end
	end
	local oneWay = Util.deco(folder, V3(0.1, 1.2, 3.6), Util.groundCF(p, dirB, Util.WALK_TOP + 10), Color3.fromRGB(20, 20, 20), M.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		Util.sign(oneWay, face, "ONE WAY →", Color3.fromRGB(250, 250, 250), Enum.Font.GothamBlack)
	end
end

local function boxTruck(folder, p, dir)
	local base = Util.groundCF(p, dir, Util.ROAD_TOP)
	local white = Color3.fromRGB(236, 236, 232)
	Util.solid(folder, V3(8, 1.2, 30), base * CFrame.new(0, 2.6, 0), Color3.fromRGB(30, 30, 32), M.Metal)
	Util.solid(folder, V3(8, 6.5, 7), base * CFrame.new(0, 6.2, -11), white, M.SmoothPlastic)
	local glass = Util.deco(folder, V3(7.6, 2.6, 0.2), base * CFrame.new(0, 7.6, -14.55), Color3.fromRGB(30, 40, 50), M.Glass)
	glass.Reflectance = 0.3
	local box = Util.solid(folder, V3(8.4, 10, 21), base * CFrame.new(0, 8.2, 3.5), white, M.SmoothPlastic)
	Util.decal(box, Enum.NormalId.Left, "billboard_burger")
	Util.decal(box, Enum.NormalId.Right, "billboard_burger")
	for _, z in ipairs({ -10.5, 6, 10 }) do
		for _, x in ipairs({ -3.8, 3.8 }) do
			Util.cylinder(folder, 1.4, 3.4, base * CFrame.new(x, 1.7, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(24, 24, 24), M.Rubber, false)
		end
	end
	Util.deco(folder, V3(8.2, 1.2, 0.2), base * CFrame.new(0, 3.4, 15), Color3.fromRGB(200, 30, 30), M.Neon)
end

local function billboard(folder, model, cf, w)
	-- Find the roof under the building's centre.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local origin = (cf * CFrame.new(0, 2000, 0)).Position
	local hit = Workspace:Raycast(origin, V3(0, -2100, 0), params)
	if not hit then
		return
	end
	local roof = hit.Position.Y
	local panelW, panelH = math.min(30, w - 4), 13
	-- cf sits at ground level, so offsets in its space are heights above the ground.
	for _, x in ipairs({ -panelW / 3, panelW / 3 }) do
		Util.deco(folder, V3(0.8, 8, 0.8), cf * CFrame.new(x, roof + 4, 0), Color3.fromRGB(50, 52, 54), M.Metal)
	end
	local panelCF = cf * CFrame.new(0, roof + 8 + panelH / 2, 0)
	local panel = Util.solid(folder, V3(panelW, panelH, 0.6), panelCF, Color3.fromRGB(240, 240, 240), M.SmoothPlastic)
	if not Util.decal(panel, Front, "billboard_phone") then
		Util.sign(panel, Front, "NOVA X · THE PHONE THAT GETS YOU", Color3.fromRGB(20, 30, 60), Enum.Font.GothamBlack)
	end
	Util.deco(folder, V3(panelW, 0.3, 2), panelCF * CFrame.new(0, -panelH / 2 - 0.2, -1), Color3.fromRGB(50, 52, 54), M.DiamondPlate)
	for _, x in ipairs({ -panelW / 3, 0, panelW / 3 }) do
		local lamp = Util.deco(folder, V3(0.8, 0.5, 0.8), panelCF * CFrame.new(x, -panelH / 2 - 0.1, -1.8), Color3.fromRGB(255, 240, 210), M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Top
		light.Range = 16
		light.Angle = 70
		light.Brightness = 1.2
		light.Parent = lamp
	end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
-- spawnRoad = { point, dir, normal, width } (the avenue at the player spawn).
function HeroStreet.new(spawnRoad, rng)
	local hero = { rng = rng, zone = spawnRoad, count = 0, billboard = false }

	function hero.contains(p)
		local rel = p - spawnRoad.point
		return math.abs(rel:Dot(spawnRoad.dir)) < HALF_LENGTH and math.abs(rel:Dot(spawnRoad.normal)) < HALF_WIDTH
	end

	-- Called by Buildings.placeFrontage for each lot inside the zone.
	function hero.build(model, cf, w, d, road, center, side)
		hero.count = hero.count + 1
		local name = ORDER[(hero.count - 1) % #ORDER + 1]
		-- Side-street lots and narrow lots get walk-ups.
		if road.kind ~= "avenue" or w < 22 then
			name = "walkup"
		end
		local top = Variants[name](hero, model, cf, w, d, rng)
		if not hero.billboard and (name == "walkup" or name == "loft") and top < 90 and side ~= nil then
			hero.billboard = true
			billboard(model, model, cf, w)
		end
	end

	-- Street-level detail inside the zone (after buildings and furniture exist).
	function hero.streetscape(folder)
		-- Props shared with the rest of the city were made for the old sidewalk
		-- height; they go in here and get raised onto the kerb at the end.
		local lifted = Instance.new("Folder")
		lifted.Name = "SharedProps"
		lifted.Parent = folder
		local avenueWidth = spawnRoad.width
		local dir, normal = spawnRoad.dir, spawnRoad.normal
		local half = avenueWidth / 2
		local walk = 10

		-- Intersections at the ends of the block.
		for _, x in ipairs(Roads.intersections) do
			if hero.contains(x.position) or (x.position - spawnRoad.point).Magnitude < HALF_LENGTH + 40 then
				local mainDir = x.mainDir
				local crossDir = Vector2.new(-mainDir.Y, mainDir.X)
				for _, sgn in ipairs({ -1, 1 }) do
					-- Across the avenue, on each side of the cross street.
					local outward = mainDir * sgn
					local cw = x.position + outward * (x.crossWidth / 2 + 5.5)
					crosswalk(folder, cw, mainDir, x.mainWidth)
					local approach = -outward
					local right = Vector2.new(-approach.Y, approach.X)
					flatPart(folder, V3(x.mainWidth / 2 - 1.5, 0.05, 1.2), cw + outward * 6.5 + right * (x.mainWidth / 4), mainDir, Util.ROAD_TOP + 0.04, Color3.fromRGB(236, 236, 230))
					roadDecal(folder, cw + outward * 20 + right * (x.mainWidth / 8), approach, Vector2.new(3, 6), "arrow_left")
					roadDecal(folder, cw + outward * 20 + right * (x.mainWidth * 3 / 8), approach, Vector2.new(3, 6), "arrow_straight")
					-- Across the cross street, on each side of the avenue.
					local outB = crossDir * sgn
					local cwB = x.position + outB * (x.mainWidth / 2 + 5.5)
					if Util.get(cwB.X, cwB.Y) == Util.ROAD then
						crosswalk(folder, cwB, crossDir, x.crossWidth)
						local approachB = -outB
						local rightB = Vector2.new(-approachB.Y, approachB.X)
						flatPart(folder, V3(x.crossWidth / 2 - 1.5, 0.05, 1.2), cwB + outB * 6.5 + rightB * (x.crossWidth / 4), crossDir, Util.ROAD_TOP + 0.04, Color3.fromRGB(236, 236, 230))
					end
				end
				-- Street-name sign on one corner.
				local corner = x.position + crossDir * (x.mainWidth / 2 + 3) + mainDir * (x.crossWidth / 2 + 3)
				if Util.get(corner.X, corner.Y) == Util.WALK then
					streetSign(folder, corner, mainDir, "CENTRAL AV", crossDir, "W " .. tostring(20 + math.floor((x.position.Y + 700) / 140)) .. " ST")
				end
			end
		end

		-- Manholes, asphalt patches and kerbside drains along the avenue.
		for k = -2, 2 do
			roadDecal(folder, spawnRoad.point + dir * (k * 60 + 15) + normal * (k % 2 == 0 and 7 or -9), dir, Vector2.new(4, 4), "manhole")
		end
		for _ = 1, 4 do
			local p = spawnRoad.point + dir * rng:NextNumber(-HALF_LENGTH + 30, HALF_LENGTH - 30) + normal * rng:NextNumber(-half + 4, half - 4)
			local patch = flatPart(folder, V3(rng:NextNumber(4, 9), 0.04, rng:NextNumber(6, 14)), p, dir, Util.ROAD_TOP + 0.03, Color3.fromRGB(48, 48, 50), M.Asphalt)
			patch.CFrame = patch.CFrame * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0)
		end
		for t = -HALF_LENGTH + 20, HALF_LENGTH - 20, 45 do
			for _, sgn in ipairs({ -1, 1 }) do
				roadDecal(folder, spawnRoad.point + dir * t + normal * sgn * (half - 0.9), dir, Vector2.new(1.4, 3), "drain_grate")
			end
		end

		-- Sidewalk kit on both sides of the avenue, skipping occupied spots.
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		local function clear(p, radius)
			local parts = Workspace:GetPartBoundsInRadius(V3(p.X, Util.WALK_TOP + 2, p.Y), radius, overlap)
			for _, part in ipairs(parts) do
				if part.Size.Y > 1.3 and part.Size.Magnitude < 60 then
					return false
				end
			end
			return true
		end
		for _, sgn in ipairs({ -1, 1 }) do
			local kerb = normal * sgn * (half + 1.3)
			local inner = normal * sgn * (half + walk - 1.6)
			local mid = normal * sgn * (half + walk * 0.45)
			local towardRoad = normal * -sgn
			local t = -HALF_LENGTH + 10
			local slot = 0
			while t < HALF_LENGTH - 10 do
				local base = spawnRoad.point + dir * t
				if Util.get((base + kerb).X, (base + kerb).Y) == Util.WALK and clear(base + kerb, 1.5) then
					slot = slot + 1
					if slot % 4 == 0 then
						treePit(folder, lifted, base + mid, rng)
					elseif slot % 7 == 3 then
						Props.hydrant(lifted, base + kerb)
					else
						parkingMeter(folder, base + kerb, towardRoad)
					end
				end
				t = t + 14
			end
			-- Larger items near the building line.
			local items = { "bench", "trash", "news", "mail", "utility", "bike", "trash", "bench" }
			t = -HALF_LENGTH + 25
			local i = 0
			while t < HALF_LENGTH - 25 do
				local p = spawnRoad.point + dir * t + inner * 0.82 + kerb * 0.18
				if Util.get(p.X, p.Y) == Util.WALK and clear(p, 2.5) then
					i = i + 1
					local item = items[(i - 1) % #items + 1]
					if item == "bench" then
						bench(folder, p, towardRoad)
					elseif item == "trash" then
						Props.trashCan(lifted, p)
					elseif item == "news" then
						Props.newsBox(lifted, p, towardRoad, rng)
					elseif item == "mail" then
						mailbox(folder, p, towardRoad)
					elseif item == "utility" then
						utilityBox(folder, p, dir)
					else
						bikeRack(folder, p, dir)
					end
				end
				t = t + rng:NextNumber(22, 34)
			end
		end

		-- Loading zone with a box truck on the far side of the avenue.
		local truckAt = spawnRoad.point + dir * -70 + normal * -(half - 6)
		boxTruck(folder, truckAt, -dir)
		local signPos = truckAt + normal * -7.5
		Util.cylinder(folder, 9, 0.3, CFrame.new(signPos.X, Util.WALK_TOP + 4.5, signPos.Y), Color3.fromRGB(70, 72, 74), M.Metal, true)
		local loading = Util.deco(folder, V3(0.1, 2.4, 2), Util.groundCF(signPos, dir, Util.WALK_TOP + 8), Color3.fromRGB(245, 245, 240), M.SmoothPlastic)
		for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
			Util.sign(loading, face, "LOADING ZONE", Color3.fromRGB(200, 30, 30), Enum.Font.GothamBlack)
		end
		local curb = Util.deco(folder, V3(0.3, 0.05, 34), Util.groundCF(truckAt + normal * -(5.6), dir, Util.ROAD_TOP + 0.04), Color3.fromRGB(240, 200, 40), M.SmoothPlastic)
		curb.CastShadow = false

		local lift = V3(0, Util.WALK_TOP - 0.25, 0)
		for _, item in ipairs(lifted:GetDescendants()) do
			if item:IsA("BasePart") then
				item.CFrame = item.CFrame + lift
			end
		end
	end

	return hero
end

return HeroStreet
