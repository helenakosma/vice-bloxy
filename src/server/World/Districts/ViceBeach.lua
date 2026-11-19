-- Vice Beach (Miami-inspired): an island across the river, reached by the
-- suspension bridge. Ocean Drive's Art Deco hotels face a palm-lined boardwalk and
-- beach, condo towers and clubs line the avenues, a marina sits on the bay side and
-- a Ferris wheel turns at the end of a pier.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)
local Buildings = require(World.Buildings)
local Props = require(World.Props)
local ViceStyles = require(World.ViceStyles)

local ViceBeach = {
	name = "ViceBeach",
	bounds = Layout.VICE_BEACH,
	budget = 16000,
}

local V3 = Vector3.new
local M = Enum.Material

local OCEAN_DRIVE_X = 2110
local COLLINS_X = 1880
local BAY_X = 1240
local SAND_FROM_X = 2148
local PIER_Z = 300
local SAND = Color3.fromRGB(230, 212, 168)
local WOOD = Color3.fromRGB(150, 116, 82)
local WHITE = Color3.fromRGB(245, 242, 235)
local CANOPY_COLORS = {
	Color3.fromRGB(240, 90, 110), Color3.fromRGB(60, 180, 200), Color3.fromRGB(250, 200, 70),
	Color3.fromRGB(245, 245, 240), Color3.fromRGB(120, 200, 140), Color3.fromRGB(240, 140, 60),
}

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
function ViceBeach.layout(ctx)
	local b = ViceBeach.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(150, 142, 128))
	Util.markRect(SAND_FROM_X, b.maxX, b.minZ, b.maxZ, Util.PARK) -- beach: no buildings

	local north, south = b.minZ + 40, b.maxZ - 40
	local roads = {
		Roads.add("boulevard", Roads.path(rng, Vector2.new(OCEAN_DRIVE_X, north), Vector2.new(OCEAN_DRIVE_X, south), 100, 3)),
		Roads.add("avenue", Roads.path(rng, Vector2.new(COLLINS_X, north), Vector2.new(COLLINS_X, south), 110, 5)),
		Roads.add("avenue", Roads.path(rng, Vector2.new(BAY_X, north), Vector2.new(BAY_X, south), 110, 4)),
	}
	-- Cross streets, including ones along the north and south ends.
	for _, z in ipairs({ north, 150, 500, 850, south }) do
		local offset = (z == north or z == south) and 0 or rng:NextNumber(-10, 10)
		table.insert(roads, Roads.add("street", Roads.path(rng, Vector2.new(BAY_X, z), Vector2.new(OCEAN_DRIVE_X, z + offset), 110, 3)))
	end
	-- The bridge lands at Bay Road and the road carries straight on to Ocean Drive.
	local landing = Layout.BRIDGE[#Layout.BRIDGE]
	table.insert(roads, Roads.add("avenue", {
		Vector2.new(landing.X, landing.Z),
		Vector2.new(COLLINS_X, landing.Z),
		Vector2.new(OCEAN_DRIVE_X, landing.Z),
	}))

	-- Vice Causeway: from downtown's waterfront drive across the river to Bay Road.
	local cz = Layout.CAUSEWAY_Z
	local waterfrontX = Util.RIVER_X - 36
	for _, road in ipairs(ctx.shared.downtownRoads) do
		if road.kind == "waterfront" then
			for i = 1, #road.points - 1 do
				local a, c = road.points[i], road.points[i + 1]
				if cz >= a.Y and cz <= c.Y then
					waterfrontX = a.X + (c.X - a.X) * (cz - a.Y) / (c.Y - a.Y)
				end
			end
		end
	end
	table.insert(roads, Roads.add("bridge", { Vector2.new(waterfrontX, cz), Vector2.new(b.minX + 4, cz) }))
	table.insert(roads, Roads.add("avenue", { Vector2.new(b.minX, cz), Vector2.new(BAY_X, cz) }))

	-- Marina docks on the bay side: keep the sea wall open where they meet land.
	for _, z in ipairs({ 0, 320 }) do
		Util.markRect(b.minX - 22, b.minX, z - 6, z + 6, Util.PARK)
	end

	Roads.rasterize(roads)
	ctx.roads = roads
end

---------------------------------------------------------------------------
-- Beach
---------------------------------------------------------------------------
local function lifeguardTower(folder, x, z, color)
	for _, dx in ipairs({ -2.5, 2.5 }) do
		for _, dz in ipairs({ -2.5, 2.5 }) do
			Util.deco(folder, V3(0.6, 8, 0.6), CFrame.new(x + dx, 4.2, z + dz), WHITE, M.Wood)
		end
	end
	Util.solid(folder, V3(7, 0.5, 7), CFrame.new(x, 8.2, z), WOOD, M.WoodPlanks)
	Util.solid(folder, V3(6, 5, 5), CFrame.new(x, 11, z + 0.5), color, M.Plaster)
	Util.deco(folder, V3(5.6, 1.6, 0.2), CFrame.new(x, 11.6, z - 2.05), Color3.fromRGB(40, 60, 70), M.Glass)
	Util.deco(folder, V3(7.5, 0.5, 7), CFrame.new(x, 13.8, z + 0.5), WHITE, M.SmoothPlastic)
	Util.beam(folder, V3(x - 6, 0.3, z), V3(x - 3.5, 8.2, z), 2.5, WOOD, M.WoodPlanks)
	local flag = Util.deco(folder, V3(0.2, 1.4, 2), CFrame.new(x + 3, 16, z), Color3.fromRGB(230, 40, 40), M.Fabric)
	flag.CastShadow = false
	Util.deco(folder, V3(0.2, 4, 0.2), CFrame.new(x + 3, 15, z + 1), WHITE, M.Metal)
end

local function umbrellaSpot(folder, x, z, rng)
	local color = Util.pick(rng, CANOPY_COLORS)
	Util.cylinder(folder, 7, 0.3, CFrame.new(x, 3.7, z), WHITE, M.Metal, false)
	local canopy = Util.cylinder(folder, 0.5, 8, CFrame.new(x, 7.2, z) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, 0), color, M.Fabric, false)
	canopy.CastShadow = true
	for _, dx in ipairs({ -2.2, 2.2 }) do
		Util.solid(folder, V3(2.2, 0.6, 6), CFrame.new(x + dx, 0.75, z + 0.5), Util.pick(rng, { WHITE, color }), M.Fabric)
	end
	if rng:NextNumber() < 0.5 then
		Util.deco(folder, V3(3, 0.05, 5.5), CFrame.new(x + rng:NextNumber(-4, 4), 0.43, z + 5), Util.pick(rng, CANOPY_COLORS), M.Fabric)
	end
end

local function volleyball(folder, x, z)
	for _, dz in ipairs({ -12, 12 }) do
		Util.cylinder(folder, 9, 0.4, CFrame.new(x, 4.7, z + dz), WHITE, M.Metal, true)
	end
	local net = Util.deco(folder, V3(0.1, 3, 24), CFrame.new(x, 7, z), Color3.fromRGB(240, 240, 240), M.Fabric)
	net.Transparency = 0.5
end

local function buildBeach(folder, rng)
	local b = ViceBeach.bounds
	local length = b.maxZ - b.minZ
	local midZ = (b.minZ + b.maxZ) / 2

	-- Sand, and a gentle slope down into the sea.
	Util.solid(folder, V3(b.maxX - SAND_FROM_X, 0.4, length), CFrame.new((SAND_FROM_X + b.maxX) / 2, 0.2, midZ), SAND, M.Sand)
	local slope = 120
	local drop = 5.2
	local angle = math.atan(drop / slope)
	local run = math.sqrt(slope * slope + drop * drop)
	Util.solid(folder, V3(run, 1, length), CFrame.new(b.maxX + slope / 2, 0.2 - drop / 2 - 0.5, midZ) * CFrame.Angles(0, 0, -angle), SAND, M.Sand)
	-- Wet sand and foam where the water meets the beach.
	local foam = Util.deco(folder, V3(4, 0.1, length), CFrame.new(b.maxX + 52, -1.95, midZ), Color3.fromRGB(240, 245, 245), M.SmoothPlastic)
	foam.Transparency = 0.3

	-- Boardwalk along the top of the beach with lamps and benches.
	local walkX = SAND_FROM_X + 9
	Util.solid(folder, V3(16, 0.8, length - 40), CFrame.new(walkX, 0.3, midZ), WOOD, M.WoodPlanks)
	for z = b.minZ + 40, b.maxZ - 40, 70 do
		Props.streetlight(folder, Vector2.new(walkX + 7.5, z), Vector2.new(-1, 0))
		Util.solid(folder, V3(2, 1.6, 6), CFrame.new(walkX - 6, 1.5, z + 20), WOOD, M.Wood)
	end
	-- Palms between the boardwalk and the sand.
	for z = b.minZ + 25, b.maxZ - 25, 34 do
		Props.palm(folder, Vector2.new(walkX + 14 + rng:NextNumber(-3, 3), z + rng:NextNumber(-6, 6)), rng)
	end

	-- Lifeguard towers, umbrellas, loungers and volleyball courts.
	local towerColors = { Color3.fromRGB(240, 140, 120), Color3.fromRGB(128, 208, 214), Color3.fromRGB(248, 228, 168), Color3.fromRGB(200, 176, 228) }
	local i = 0
	for z = b.minZ + 90, b.maxZ - 90, 260 do
		i = i + 1
		if math.abs(z - PIER_Z) > 40 then
			lifeguardTower(folder, b.maxX - 30, z, towerColors[(i - 1) % #towerColors + 1])
		end
	end
	for _ = 1, 70 do
		local x = rng:NextNumber(walkX + 22, b.maxX - 45)
		local z = rng:NextNumber(b.minZ + 30, b.maxZ - 30)
		if math.abs(z - PIER_Z) > 30 then
			umbrellaSpot(folder, x, z, rng)
		end
	end
	for _, z in ipairs({ 80, 640 }) do
		volleyball(folder, walkX + 60, z)
	end
end

---------------------------------------------------------------------------
-- Ferris wheel pier
---------------------------------------------------------------------------
local function buildFerrisWheel(folder)
	local b = ViceBeach.bounds
	local pierFrom, pierTo = b.maxX - 10, b.maxX + 230
	local pierLength = pierTo - pierFrom
	Util.solid(folder, V3(pierLength, 1, 36), CFrame.new((pierFrom + pierTo) / 2, 1.5, PIER_Z), WOOD, M.WoodPlanks)
	for x = pierFrom + 10, pierTo, 24 do
		for _, dz in ipairs({ -16, 16 }) do
			Util.cylinder(folder, 18, 1.4, CFrame.new(x, -7, PIER_Z + dz), Color3.fromRGB(96, 80, 64), M.Wood, false)
		end
	end
	for _, dz in ipairs({ -17.5, 17.5 }) do
		Util.solid(folder, V3(pierLength, 3, 0.4), CFrame.new((pierFrom + pierTo) / 2, 3.5, PIER_Z + dz), WHITE, M.Metal)
	end
	-- Pastel arch at the start of the pier.
	for _, dz in ipairs({ -15, 15 }) do
		Util.solid(folder, V3(3, 18, 3), CFrame.new(pierFrom + 8, 11, PIER_Z + dz), Color3.fromRGB(244, 170, 194), M.Plaster)
	end
	local arch = Util.deco(folder, V3(3, 5, 33), CFrame.new(pierFrom + 8, 22, PIER_Z), Color3.fromRGB(26, 30, 46), M.SmoothPlastic)
	Util.sign(arch, Enum.NormalId.Left, "VICE PIER", Color3.fromRGB(60, 230, 255), Enum.Font.GothamBlack).LightInfluence = 0

	-- The wheel: an unanchored, welded assembly on a motorised hinge.
	local cx, cy = pierTo - 60, 56
	local radius = 44
	local center = V3(cx, cy, PIER_Z)
	for _, dz in ipairs({ -9, 9 }) do
		for _, dx in ipairs({ -26, 26 }) do
			Util.beam(folder, V3(cx + dx, 2, PIER_Z + dz * 1.6), V3(cx, cy, PIER_Z + dz), 2.4, WHITE, M.Metal)
		end
	end
	local axle = Util.solid(folder, V3(3, 3, 22), CFrame.new(center), Color3.fromRGB(180, 180, 185), M.Metal)
	axle.CanCollide = false

	local wheel = Instance.new("Model")
	wheel.Name = "FerrisWheel"
	wheel.Parent = folder
	local hub = Util.deco(wheel, V3(7, 7, 14), CFrame.new(center), WHITE, M.Metal)
	local moving = { hub }
	local rimColor = Color3.fromRGB(255, 70, 170)
	local spokes = 16
	for _, dz in ipairs({ -5, 5 }) do
		for k = 0, spokes - 1 do
			local a1 = k / spokes * math.pi * 2
			local a2 = (k + 1) / spokes * math.pi * 2
			local p1 = center + V3(math.cos(a1) * radius, math.sin(a1) * radius, dz)
			local p2 = center + V3(math.cos(a2) * radius, math.sin(a2) * radius, dz)
			table.insert(moving, Util.beam(wheel, p1, p2, 1.2, rimColor, M.Neon))
			table.insert(moving, Util.beam(wheel, center + V3(0, 0, dz), p1, 0.6, WHITE, M.Metal))
		end
	end
	local gondolaColors = { Color3.fromRGB(60, 200, 220), Color3.fromRGB(250, 200, 70), Color3.fromRGB(240, 120, 150), Color3.fromRGB(150, 110, 230) }
	for k = 0, spokes - 1 do
		local a = k / spokes * math.pi * 2
		local p = center + V3(math.cos(a) * radius, math.sin(a) * radius, 0)
		table.insert(moving, Util.deco(wheel, V3(5, 5, 5), CFrame.new(p), gondolaColors[k % #gondolaColors + 1], M.SmoothPlastic, Enum.PartType.Ball))
	end
	for i = 2, #moving do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hub
		weld.Part1 = moving[i]
		weld.Parent = moving[i]
	end
	for _, part in ipairs(moving) do
		part.Anchored = false
	end

	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.Angles(0, math.rad(90), 0) -- hinge axis along Z
	a0.Parent = axle
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.Angles(0, math.rad(90), 0)
	a1.Parent = hub
	local hinge = Instance.new("HingeConstraint")
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = 0.12
	hinge.MotorMaxTorque = 1e10
	hinge.MotorMaxAcceleration = 0.5
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.Parent = hub
	pcall(function()
		hub:SetNetworkOwner(nil)
	end)
end

---------------------------------------------------------------------------
-- Marina
---------------------------------------------------------------------------
local function yacht(folder, x, z, rng)
	local hullColor = Util.pick(rng, { WHITE, Color3.fromRGB(230, 230, 232), Color3.fromRGB(28, 40, 70) })
	local length = rng:NextNumber(22, 34)
	local cf = CFrame.new(x, -0.6, z) * CFrame.Angles(0, math.rad(90), 0) -- bow points west
	Util.solid(folder, V3(8, 3, length), cf, hullColor, M.SmoothPlastic)
	Util.deco(folder, V3(5.6, 3, 5.6), cf * CFrame.new(0, 0, -length / 2 - 1.2) * CFrame.Angles(0, math.rad(45), 0), hullColor, M.SmoothPlastic)
	Util.deco(folder, V3(8.1, 0.4, length), cf * CFrame.new(0, -0.9, 0), Color3.fromRGB(30, 80, 140), M.SmoothPlastic)
	Util.deco(folder, V3(6, 3, length * 0.45), cf * CFrame.new(0, 3, length * 0.1), WHITE, M.SmoothPlastic)
	local windows = Util.deco(folder, V3(6.1, 1.2, length * 0.4), cf * CFrame.new(0, 3.2, length * 0.1), Color3.fromRGB(30, 40, 50), M.Glass)
	windows.Reflectance = 0.3
	Util.deco(folder, V3(5, 0.4, length * 0.3), cf * CFrame.new(0, 4.7, length * 0.12), WHITE, M.SmoothPlastic)
end

local function buildMarina(folder, rng)
	local b = ViceBeach.bounds
	local x = b.minX - 16
	Util.solid(folder, V3(8, 1, 520), CFrame.new(x, 0.7, 160), WOOD, M.WoodPlanks)
	for _, z in ipairs({ 0, 320 }) do
		Util.solid(folder, V3(18, 1, 10), CFrame.new(b.minX - 9, 0.7, z), WOOD, M.WoodPlanks)
	end
	for z = -80, 400, 60 do
		Util.solid(folder, V3(44, 1, 5), CFrame.new(x - 26, 0.7, z), WOOD, M.WoodPlanks)
		for px = x - 46, x, 15 do
			Util.cylinder(folder, 8, 1, CFrame.new(px, -1.5, z + 3), Color3.fromRGB(96, 80, 64), M.Wood, false)
		end
		if z < 400 then
			yacht(folder, x - 28, z + 30, rng)
		end
	end
	local sign = Util.deco(folder, V3(0.4, 4, 16), CFrame.new(b.minX + 4, 4, 0), Color3.fromRGB(26, 30, 46), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Left, "VICE MARINA", Color3.fromRGB(248, 228, 168), Enum.Font.GothamBold)
	for _, dz in ipairs({ -7, 7 }) do
		Util.deco(folder, V3(0.5, 6, 0.5), CFrame.new(b.minX + 4, 3, dz), WHITE, M.Metal)
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function ViceBeach.build(ctx)
	local rng = ctx.rng
	local folder = ctx.folder
	local roads = ctx.roads

	Roads.render(ctx.makeFolder(folder, "Roads"), roads)
	Util.seawall(ctx.makeFolder(folder, "Seawall"), ViceBeach.bounds, { east = true })

	local buildings = ctx.makeFolder(folder, "Buildings")
	local placed = Buildings.placeFrontage(buildings, roads, rng, {
		chooseStyle = ViceStyles.choose,
		interiorChance = 0.25,
		facadeChance = 0.8,
		heightFactor = function()
			return 1
		end,
	})
	local filled = Buildings.fillGaps(buildings, rng, ViceBeach.bounds)

	buildBeach(ctx.makeFolder(folder, "Beach"), rng)
	buildFerrisWheel(ctx.makeFolder(folder, "Pier"))
	buildMarina(ctx.makeFolder(folder, "Marina"), rng)

	Props.placeStreetFurniture(ctx.makeFolder(folder, "Street"), rng, roads, { tropical = true })
	local parked = Props.placeParkedCars(ctx.makeFolder(folder, "ParkedCars"), rng, ctx.Cars, roads)
	print(string.format("[ViceBeach] %d buildings, %d filler, %d parked cars", placed, filled, parked))

	-- A few cars to drive on Ocean Drive.
	local carSpawns = {}
	local ocean = roads[1]
	for i, z in ipairs({ 40, 420, 760 }) do
		local p = Vector2.new(OCEAN_DRIVE_X, z)
		local dir = Vector2.new(0, 1)
		for k = 1, #ocean.points - 1 do
			local a, c = ocean.points[k], ocean.points[k + 1]
			if z >= a.Y and z <= c.Y then
				dir = (c - a).Unit
				p = a:Lerp(c, (z - a.Y) / (c.Y - a.Y))
			end
		end
		local normal = Vector2.new(-dir.Y, dir.X)
		table.insert(carSpawns, { cframe = Util.groundCF(p + normal * (ocean.width / 2 - 5), dir, 0.3), taxi = i == 2 })
	end
	return { carSpawns = carSpawns }
end

return ViceBeach
