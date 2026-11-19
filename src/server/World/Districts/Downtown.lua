-- Downtown (Manhattan-style): the original city. Wandering avenues, a diagonal
-- boulevard, alleys, the park, the east river and walk-in shops.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Buildings = require(World.Buildings)
local Props = require(World.Props)
local Layout = require(World.Layout)

local Downtown = {
	name = "Downtown",
	bounds = { minX = Util.MIN_X, maxX = Util.RIVER_X, minZ = Util.MIN_Z - 30, maxZ = Util.MAX_Z },
	budget = 28000, -- parts; a warning prints if the district goes over
}

-- Finds the sidewalk point on the central avenue at z = 0 for the player spawn.
local function findSpawn(roads)
	for _, road in ipairs(roads) do
		if road.kind == "avenue" and math.abs(road.points[1].X - 20) < 40 then
			for i = 1, #road.points - 1 do
				local a, b = road.points[i], road.points[i + 1]
				if a.Y <= 0 and b.Y >= 0 then
					local dir = (b - a).Unit
					local normal = Vector2.new(-dir.Y, dir.X)
					local mid = a:Lerp(b, (0 - a.Y) / (b.Y - a.Y))
					local p = mid + normal * (road.width / 2 + road.walk / 2)
					return Util.groundCF(p, dir, 1), { point = mid, dir = dir, normal = normal, width = road.width }
				end
			end
		end
	end
	return CFrame.new(40, 1, 0), nil
end

-- Land, roads and the occupancy grid. Runs before any district builds.
function Downtown.layout(ctx)
	local b = Downtown.bounds
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ)

	local roads = Roads.generate(ctx.rng)
	-- North-shore road along the channel, underneath the Harbor Freeway.
	local shoreZ = Layout.DOWNTOWN_SHORE_Z
	table.insert(roads, Roads.add("industrial", { Vector2.new(Util.MIN_X, shoreZ), Vector2.new(Util.RIVER_X - 30, shoreZ) }))
	local park = Roads.PARK
	Util.markRect(park.minX, park.maxX, park.minZ, park.maxZ, Util.PARK)
	Util.markRect(Util.RIVER_X - 10, Util.MAX_X, Util.MIN_Z, Util.MAX_Z, Util.WATER)
	Roads.rasterize(roads)
	ctx.roads = roads
	ctx.shared.downtownRoads = roads

	local spawnCF, spawnRoad = findSpawn(roads)
	ctx.spawnCF = spawnCF
	ctx.spawnRoad = spawnRoad
	ctx.setSpawn(spawnCF)
end

function Downtown.build(ctx)
	local rng = ctx.rng
	local folder = ctx.folder
	local roads = ctx.roads

	Roads.render(ctx.makeFolder(folder, "Roads"), roads)
	Props.buildPark(ctx.makeFolder(folder, "Park"), rng)
	local cz = Layout.CAUSEWAY_Z
	Props.buildRiver(ctx.makeFolder(folder, "River"), { { minZ = cz - 45, maxZ = cz + 45 } })
	Util.seawall(ctx.makeFolder(folder, "Seawall"), Downtown.bounds, { east = true })

	local buildings = ctx.makeFolder(folder, "Buildings")
	local placed = Buildings.placeFrontage(buildings, roads, rng)
	local filled = Buildings.fillGaps(buildings, rng)

	Props.placeStreetFurniture(ctx.makeFolder(folder, "Street"), rng, roads, { signals = true })
	Props.startSignals()
	local parked = Props.placeParkedCars(ctx.makeFolder(folder, "ParkedCars"), rng, ctx.Cars, roads)
	print(string.format("[Downtown] %d frontage buildings, %d filler, %d parked cars", placed, filled, parked))

	-- Driveable cars: a few by the player spawn plus some along the avenues.
	local carSpawns = {}
	local spawnRoad = ctx.spawnRoad
	if spawnRoad then
		for i = 0, 2 do
			local p = spawnRoad.point + spawnRoad.dir * (20 + i * 18) + spawnRoad.normal * (spawnRoad.width / 2 - 5)
			table.insert(carSpawns, { cframe = Util.groundCF(p, spawnRoad.dir, 0.3), taxi = i == 1 })
		end
	end
	Roads.eachSegment(function(road, a, _, dir, normal, length)
		if #carSpawns < 16 and road.kind == "avenue" and length > 60 and rng:NextNumber() < 0.08 then
			local p = a + dir * (length / 2) + normal * (road.width / 2 - 5)
			if not Util.isJunction(p.X, p.Y) then
				table.insert(carSpawns, { cframe = Util.groundCF(p, dir, 0.3), taxi = rng:NextNumber() < 0.3 })
			end
		end
	end, roads)

	return {
		carSpawns = carSpawns,
		jobCFrame = ctx.spawnCF * CFrame.new(0, -0.75, 14),
	}
end

return Downtown
