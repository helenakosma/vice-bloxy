-- North York (Toronto-inspired): wide arterials north of the channel, joined to
-- downtown by bridges that continue three avenues. Landmarks: the Needle (a
-- CN Tower-style observation tower), the Dome stadium, a shopping centre and a
-- park, surrounded by glass condo towers, mid-rises and strip plazas.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)
local Buildings = require(World.Buildings)
local Props = require(World.Props)
local TorontoStyles = require(World.TorontoStyles)

local NorthYork = {
	name = "NorthYork",
	bounds = Layout.NORTH_YORK,
	budget = 20000,
}

local V3 = Vector3.new
local M = Enum.Material
local CONCRETE = Color3.fromRGB(206, 202, 194)
local CENTRE = Vector2.new(20, -1300) -- tallest towers cluster here

local NEEDLE_RADIUS = 42
local DOME_RADIUS = 60
local MALL_SIZE = Vector2.new(190, 140)

local function heightFactor(p)
	return 1 + 1.4 * math.max(0, 1 - (p - CENTRE).Magnitude / 650)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
function NorthYork.layout(ctx)
	local b = NorthYork.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(104, 102, 96))

	local roads = {}
	local north, south = Layout.NY_NORTH_Z, Layout.NY_SOUTH_Z
	local west, east = Layout.NY_WEST_X, Layout.NY_EAST_X

	-- Perimeter: north road, lakeshore road along the channel, west and east roads.
	table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(west, north), Vector2.new(east, north), 130, 4)))
	table.insert(roads, Roads.add("arterial", { Vector2.new(west, south), Vector2.new(east, south) }))
	table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(west, south), Vector2.new(west, north), 120, 4)))
	table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(east, south), Vector2.new(east, north), 120, 4)))

	-- Channel bridges continuing downtown avenues, then arterials up to the north road.
	for _, target in ipairs(Layout.NY_BRIDGE_AVENUES) do
		for _, ending in ipairs(Roads.avenueEnds(ctx.shared.downtownRoads, "north")) do
			local x = ending.point.X
			if ending.road.kind == "avenue" and math.abs(x - target) < 40 then
				table.insert(roads, Roads.add("bridge", { Vector2.new(x, Util.MIN_Z), Vector2.new(x, b.maxZ - 5) }))
				table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(x, b.maxZ - 5), Vector2.new(x, north), 115, 3)))
				break
			end
		end
	end

	-- Cross arterials and side streets between the west and east roads.
	for _, z in ipairs(Layout.NY_CROSS_Z) do
		table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(west, z), Vector2.new(east, z), 120, 4)))
	end
	for _, z in ipairs(Layout.NY_SIDE_STREETS_Z) do
		table.insert(roads, Roads.add("street", Roads.path(rng, Vector2.new(west, z), Vector2.new(east, z), 110, 4)))
	end
	for _, x in ipairs(Layout.NY_SIDE_STREETS_X) do
		table.insert(roads, Roads.add("street", Roads.path(rng, Vector2.new(x, south), Vector2.new(x, north), 110, 4)))
	end

	Roads.rasterize(roads)
	ctx.roads = roads

	-- Reserve the landmark sites so nothing else is built on them.
	local function reserveCircle(c, r)
		Util.markRect(c.X - r, c.X + r, c.Y - r, c.Y + r, Util.BUILT)
	end
	reserveCircle(Layout.NEEDLE, NEEDLE_RADIUS)
	reserveCircle(Layout.DOME, DOME_RADIUS + 6)
	local m = Layout.MALL
	Util.markRect(m.X - MALL_SIZE.X / 2, m.X + MALL_SIZE.X / 2, m.Y - MALL_SIZE.Y / 2, m.Y + MALL_SIZE.Y / 2, Util.BUILT)
	local p = Layout.NY_PARK
	Util.markRect(p.minX, p.maxX, p.minZ, p.maxZ, Util.PARK)
end

---------------------------------------------------------------------------
-- Landmarks
---------------------------------------------------------------------------
-- The Needle: tapering concrete shaft with three fins, a wide observation pod,
-- a small sky pod and a red-and-white antenna mast.
local function needle(folder, c)
	local x, z = c.X, c.Y
	local base = CFrame.new(x, 0.3, z)

	-- Plaza.
	Util.cylinder(folder, 0.4, NEEDLE_RADIUS * 2, base * CFrame.new(0, 0.2, 0), Color3.fromRGB(170, 166, 158), M.Pavement, true)

	-- Shaft: stacked, tapering hexagonal sections (cylinders read well from afar).
	local shaftTop = 330
	local sections = 8
	for i = 0, sections - 1 do
		local y0 = shaftTop * i / sections
		local y1 = shaftTop * (i + 1) / sections
		local dia = 24 - 11 * (i / sections)
		Util.cylinder(folder, y1 - y0 + 0.2, dia, base * CFrame.new(0, (y0 + y1) / 2, 0), CONCRETE, M.Concrete, true)
	end
	-- Three fins forming the Y-shaped base, tapering as they rise.
	for k = 0, 2 do
		local yaw = CFrame.Angles(0, k * math.pi * 2 / 3, 0)
		for i = 0, 3 do
			local y0 = 220 * i / 4
			local y1 = 220 * (i + 1) / 4
			local reach = 30 - 22 * (i / 4)
			Util.solid(folder, V3(6, y1 - y0 + 0.2, reach), base * yaw * CFrame.new(0, (y0 + y1) / 2, -reach / 2), CONCRETE, M.Concrete)
		end
	end
	-- Main observation pod.
	local pod = shaftTop
	Util.cylinder(folder, 6, 40, base * CFrame.new(0, pod, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 5, 52, base * CFrame.new(0, pod + 5.5, 0), Color3.fromRGB(190, 188, 182), M.Concrete, true)
	local windows = Util.cylinder(folder, 7, 54, base * CFrame.new(0, pod + 11.5, 0), Color3.fromRGB(40, 50, 60), M.Glass, true)
	windows.Reflectance = 0.35
	Util.cylinder(folder, 4, 50, base * CFrame.new(0, pod + 17, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 4, 36, base * CFrame.new(0, pod + 21, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 0.5, 54.4, base * CFrame.new(0, pod + 8.2, 0), Color3.fromRGB(255, 220, 160), M.Neon, false)
	-- Upper shaft and sky pod.
	Util.cylinder(folder, 70, 10, base * CFrame.new(0, pod + 58, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 9, 18, base * CFrame.new(0, pod + 96, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 3, 18.4, base * CFrame.new(0, pod + 96, 0), Color3.fromRGB(40, 50, 60), M.Glass, true)
	-- Antenna mast, banded red and white.
	local mastBase = pod + 100
	for i = 0, 7 do
		local color = (i % 2 == 0) and Color3.fromRGB(196, 40, 36) or Color3.fromRGB(236, 236, 232)
		Util.cylinder(folder, 13, 5 - i * 0.45, base * CFrame.new(0, mastBase + 6.5 + i * 13, 0), color, M.Metal, false)
	end
	Util.deco(folder, V3(2, 2, 2), base * CFrame.new(0, mastBase + 106, 0), Color3.fromRGB(255, 40, 40), M.Neon, Enum.PartType.Ball)

	local sign = Util.deco(folder, V3(16, 3, 0.4), base * CFrame.new(0, 6, -NEEDLE_RADIUS + 6), Color3.fromRGB(30, 34, 40), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Front, "THE NEEDLE", Color3.fromRGB(240, 236, 228), Enum.Font.GothamBold)
end

-- The Dome: round stadium with panelled walls and a stepped domed roof.
local function dome(folder, c)
	local x, z = c.X, c.Y
	local r = DOME_RADIUS
	local wallH = 36
	local panels = 40
	local white = Color3.fromRGB(226, 226, 222)
	local panelW = 2 * math.pi * r / panels + 0.6
	for k = 0, panels - 1 do
		local a = k / panels * math.pi * 2
		local pos = V3(x + math.cos(a) * r, wallH / 2, z + math.sin(a) * r)
		local cf = CFrame.lookAt(pos, V3(x, wallH / 2, z))
		local isGate = k % 10 == 0
		Util.solid(folder, V3(panelW, wallH, 3), cf, isGate and Color3.fromRGB(40, 44, 52) or white, isGate and M.Glass or M.Concrete)
		if k % 2 == 0 and not isGate then
			Util.deco(folder, V3(1.2, wallH + 2, 4), cf * CFrame.new(-panelW / 2, 1, 0), Color3.fromRGB(150, 150, 150), M.Metal)
		end
	end
	-- Stepped dome: concentric rings rising toward the middle.
	local rings = { { r + 2, wallH }, { r * 0.86, wallH + 7 }, { r * 0.68, wallH + 12.5 }, { r * 0.47, wallH + 16 }, { r * 0.24, wallH + 18 } }
	for i, ring in ipairs(rings) do
		local color = (i % 2 == 1) and Color3.fromRGB(200, 204, 210) or Color3.fromRGB(176, 180, 186)
		Util.cylinder(folder, 3, ring[1] * 2, CFrame.new(x, ring[2] + 1.5, z), color, M.Metal, true)
	end
	Util.cylinder(folder, 1.2, r * 2 + 4.4, CFrame.new(x, wallH - 2, z), Color3.fromRGB(30, 90, 170), M.Neon, false)
	local sign = Util.deco(folder, V3(40, 6, 0.4), CFrame.lookAt(V3(x, wallH - 9, z + r + 1.8), V3(x, wallH - 9, z + r + 10)), Color3.fromRGB(20, 40, 90), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Front, "THE DOME", Color3.fromRGB(240, 240, 240), Enum.Font.GothamBlack)
end

-- Shopping centre: big low box with glass entrances and skylights in a parking lot.
local function mall(folder, c, rng, Cars)
	local x, z = c.X, c.Y
	local w, d = MALL_SIZE.X, MALL_SIZE.Y
	Util.deco(folder, V3(w, 0.06, d), CFrame.new(x, 0.32, z), Color3.fromRGB(56, 56, 58), M.Asphalt)
	local bw, bd, h = w * 0.7, d * 0.5, 26
	local bz = z + d * 0.18
	Util.solid(folder, V3(bw, h, bd), CFrame.new(x, h / 2, bz), Color3.fromRGB(196, 190, 180), M.Concrete)
	Util.deco(folder, V3(bw + 1, 3, bd + 1), CFrame.new(x, h + 1.5, bz), Color3.fromRGB(120, 116, 110), M.Concrete)
	for i = -1, 1 do
		local sky = Util.deco(folder, V3(bw * 0.2, 5, bd * 0.6), CFrame.new(x + i * bw * 0.3, h + 2.5, bz), Color3.fromRGB(150, 180, 190), M.Glass)
		sky.Transparency = 0.2
	end
	for _, ex in ipairs({ -bw * 0.3, 0, bw * 0.3 }) do
		local entrance = Util.deco(folder, V3(16, 16, 6), CFrame.new(x + ex, 8, bz - bd / 2 - 3), Color3.fromRGB(110, 140, 150), M.Glass)
		entrance.Reflectance = 0.3
	end
	local sign = Util.deco(folder, V3(46, 6, 0.6), CFrame.new(x, h - 5, bz - bd / 2 - 0.4), Color3.fromRGB(240, 238, 232), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Front, "YORKGATE CENTRE", Color3.fromRGB(150, 30, 40), Enum.Font.GothamBlack)
	-- Parked cars in rows in front.
	local rowZ = z - d / 2 + 18
	for row = 0, 1 do
		for px = x - w / 2 + 12, x + w / 2 - 12, 13 do
			if rng:NextNumber() < 0.55 then
				local car = Cars.spawnParked(CFrame.new(px, 0.3, rowZ + row * 26) * CFrame.Angles(0, math.rad(row == 0 and 0 or 180), 0), folder, rng)
				Util.tick(#car:GetChildren())
			end
		end
	end
end

local function park(folder, rect, rng)
	local w, d = rect.maxX - rect.minX, rect.maxZ - rect.minZ
	local cx, cz = (rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2
	Util.solid(folder, V3(w, 1, d), CFrame.new(cx, -0.15, cz), Color3.fromRGB(86, 110, 64), M.Grass)
	Util.deco(folder, V3(w, 0.2, 9), CFrame.new(cx, 0.4, cz), Color3.fromRGB(160, 150, 136), M.Pavement)
	local pond = Util.cylinder(folder, 0.3, 46, CFrame.new(cx + w * 0.25, 0.3, cz - d * 0.18), Color3.fromRGB(60, 84, 90), M.Glass, false)
	pond.Reflectance = 0.35
	for _ = 1, 28 do
		local p = Vector2.new(rng:NextNumber(rect.minX + 8, rect.maxX - 8), rng:NextNumber(rect.minZ + 8, rect.maxZ - 8))
		if math.abs(p.Y - cz) > 9 and (p - Vector2.new(cx + w * 0.25, cz - d * 0.18)).Magnitude > 28 then
			local h = rng:NextNumber(9, 13)
			Util.cylinder(folder, h, 1, CFrame.new(p.X, h / 2, p.Y), Color3.fromRGB(70, 56, 44), M.Wood, true)
			local s = rng:NextNumber(8, 11)
			Util.deco(folder, V3(s, s, s), CFrame.new(p.X, h + s * 0.25, p.Y), Color3.fromRGB(rng:NextInteger(60, 90), rng:NextInteger(96, 120), 52), M.LeafyGrass, Enum.PartType.Ball)
		end
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function NorthYork.build(ctx)
	local rng = ctx.rng
	local folder = ctx.folder
	local roads = ctx.roads

	Roads.render(ctx.makeFolder(folder, "Roads"), roads)
	Util.seawall(ctx.makeFolder(folder, "Seawall"), NorthYork.bounds)

	local landmarks = ctx.makeFolder(folder, "Landmarks")
	needle(landmarks, Layout.NEEDLE)
	dome(landmarks, Layout.DOME)
	mall(landmarks, Layout.MALL, rng, ctx.Cars)
	park(ctx.makeFolder(folder, "Park"), Layout.NY_PARK, rng)

	local buildings = ctx.makeFolder(folder, "Buildings")
	local placed = Buildings.placeFrontage(buildings, roads, rng, {
		chooseStyle = function(r, road, center)
			return TorontoStyles.choose(r, road, center, heightFactor)
		end,
		heightFactor = heightFactor,
		interiorChance = 0.12,
		facadeChance = 0.75,
	})
	local filled = Buildings.fillGaps(buildings, rng, NorthYork.bounds)

	Props.placeStreetFurniture(ctx.makeFolder(folder, "Street"), rng, roads)
	local parked = Props.placeParkedCars(ctx.makeFolder(folder, "ParkedCars"), rng, ctx.Cars, roads)
	print(string.format("[NorthYork] %d buildings, %d filler, %d parked cars", placed, filled, parked))

	-- Two cars to drive near the bridges.
	local carSpawns = {}
	for _, road in ipairs(roads) do
		if road.kind == "arterial" and #carSpawns < 2 and math.abs(road.points[1].Y - (NorthYork.bounds.maxZ - 5)) < 1 then
			local a, c = road.points[1], road.points[2]
			local dir = (c - a).Unit
			local normal = Vector2.new(-dir.Y, dir.X)
			table.insert(carSpawns, { cframe = Util.groundCF(a + dir * 120 + normal * (road.width / 2 - 6), dir, 0.3) })
		end
	end
	return { carSpawns = carSpawns }
end

return NorthYork
