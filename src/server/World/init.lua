-- Builds the city: roads, buildings, shops, props, park and river.
-- Returns spawn points for players and cars.
local Workspace = game:GetService("Workspace")

local Util = require(script.Util)
local Roads = require(script.Roads)
local Buildings = require(script.Buildings)
local Props = require(script.Props)
local Atmosphere = require(script.Atmosphere)

local World = {}

local SEED = 1986

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function World.build(Cars)
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	Atmosphere.apply()

	local root = folder(Workspace, "City")
	local rng = Random.new(SEED)

	-- Ground first, so early joiners have something to stand on.
	local width = Util.RIVER_X - Util.MIN_X + 40
	Util.solid(root, Vector3.new(width, 2, Util.MAX_Z - Util.MIN_Z + 40), CFrame.new(Util.MIN_X - 20 + width / 2, -1, 0), Color3.fromRGB(96, 93, 88), Enum.Material.Concrete)
	local outer = Util.deco(root, Vector3.new(2000, 2, 2000), CFrame.new(0, -1.2, 0), Color3.fromRGB(80, 78, 74), Enum.Material.Concrete)
	outer.CastShadow = false

	-- Roads and the occupancy grid.
	Roads.generate(rng)
	local park = Roads.PARK
	Util.markRect(park.minX, park.maxX, park.minZ, park.maxZ, Util.PARK)
	Util.markRect(Util.RIVER_X - 10, Util.MAX_X, Util.MIN_Z, Util.MAX_Z, Util.WATER)
	Roads.rasterize()

	-- Player spawn: sidewalk of the central avenue.
	local spawnCF = CFrame.new(40, 1, 0)
	for _, road in ipairs(Roads.list) do
		if road.kind == "avenue" and math.abs(road.points[1].X - 20) < 40 then
			for i = 1, #road.points - 1 do
				local a, b = road.points[i], road.points[i + 1]
				if a.Y <= 0 and b.Y >= 0 then
					local dir = (b - a).Unit
					local normal = Vector2.new(-dir.Y, dir.X)
					local mid = a:Lerp(b, (0 - a.Y) / (b.Y - a.Y))
					local p = mid + normal * (road.width / 2 + road.walk / 2)
					spawnCF = Util.groundCF(p, dir, 1)
					World.spawnRoad = { point = mid, dir = dir, normal = normal, width = road.width }
				end
			end
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = spawnCF
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = Workspace

	Roads.render(folder(root, "Roads"))
	Props.buildPark(folder(root, "Park"), rng)
	Props.buildRiver(folder(root, "River"))

	local buildings = folder(root, "Buildings")
	local placed = Buildings.placeFrontage(buildings, Roads.list, rng)
	local filled = Buildings.fillGaps(buildings, rng)
	Buildings.background(folder(root, "Skyline"), rng)

	Props.placeStreetFurniture(folder(root, "Street"), rng)
	Props.startSignals()
	local parked = Props.placeParkedCars(folder(root, "ParkedCars"), rng, Cars)

	-- Invisible boundary walls.
	local function wall(size, pos)
		local p = Util.solid(root, size, CFrame.new(pos), Color3.new(), Enum.Material.SmoothPlastic)
		p.Transparency = 1
	end
	local h = 120
	local spanZ = Util.MAX_Z - Util.MIN_Z
	local spanX = Util.RIVER_X - Util.MIN_X
	wall(Vector3.new(2, h, spanZ), Vector3.new(Util.MIN_X - 4, h / 2, 0))
	wall(Vector3.new(spanX, h, 2), Vector3.new(Util.MIN_X + spanX / 2, h / 2, Util.MAX_Z + 4))
	wall(Vector3.new(spanX, h, 2), Vector3.new(Util.MIN_X + spanX / 2, h / 2, Util.MIN_Z - 4))

	print(string.format("[World] %d frontage buildings, %d filler, %d parked cars", placed, filled, parked))

	-- Driveable car spawns: a few by the player spawn plus some around the city.
	local carSpawns = {}
	local s = World.spawnRoad
	if s then
		for i = 0, 2 do
			local p = s.point + s.dir * (20 + i * 18) + s.normal * (s.width / 2 - 5)
			table.insert(carSpawns, { cframe = Util.groundCF(p, s.dir, 0.3), taxi = i == 1 })
		end
	end
	Roads.eachSegment(function(road, a, _, dir, normal, length)
		if #carSpawns < 16 and road.kind == "avenue" and length > 60 and rng:NextNumber() < 0.08 then
			local p = a + dir * (length / 2) + normal * (road.width / 2 - 5)
			if not Util.isJunction(p.X, p.Y) then
				table.insert(carSpawns, { cframe = Util.groundCF(p, dir, 0.3), taxi = rng:NextNumber() < 0.3 })
			end
		end
	end)

	return {
		spawnCFrame = spawnCF,
		carSpawns = carSpawns,
		jobCFrame = spawnCF * CFrame.new(0, -0.75, 14),
	}
end

return World
