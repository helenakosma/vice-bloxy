-- Industrial waterfront (south of downtown): avenues continue south as truck
-- routes between three east-west roads. A ramp links it to the expressway.
-- Roads only so far.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)

local Industrial = {
	name = "Industrial",
	bounds = Layout.INDUSTRIAL,
	budget = 9000,
}

function Industrial.layout(ctx)
	local b = Industrial.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(92, 88, 82))

	local roads = {}
	local northZ, mainZ, southZ = Layout.INDUSTRIAL_NORTH_Z, Layout.INDUSTRIAL_MAIN_Z, Layout.INDUSTRIAL_SOUTH_Z
	local eastX = Layout.INDUSTRIAL_EAST_X

	-- Avenues continue south to the south road. Between x = 300 and 500 they stop
	-- at the north road, clear of the expressway ramp; the waterfront drive goes on
	-- to the main road.
	for _, ending in ipairs(Roads.avenueEnds(ctx.shared.downtownRoads, "south")) do
		local x = ending.point.X
		local stopZ = southZ
		if x > 500 then
			stopZ = mainZ
		elseif x > 300 then
			stopZ = northZ
		end
		local finish = Vector2.new(x + rng:NextNumber(-10, 10), stopZ)
		table.insert(roads, Roads.add("industrial", Roads.path(rng, Vector2.new(x, Util.MAX_Z), finish, 110, 4)))
	end

	-- East-west roads. The northern one carries on west to the first suburb collector.
	local westStart = Vector2.new(Layout.suburbCollectorX(1, northZ), northZ)
	table.insert(roads, Roads.add("industrial", Roads.path(rng, westStart, Vector2.new(eastX, northZ), 130, 5)))
	table.insert(roads, Roads.add("industrial", Roads.path(rng, Vector2.new(b.minX, mainZ), Vector2.new(eastX, mainZ), 130, 4)))
	table.insert(roads, Roads.add("industrial", Roads.path(rng, Vector2.new(b.minX, southZ), Vector2.new(300, southZ), 130, 3)))

	Roads.rasterize(roads)
	ctx.roads = roads
end

function Industrial.build(ctx)
	Roads.render(ctx.makeFolder(ctx.folder, "Roads"), ctx.roads)
	Util.seawall(ctx.makeFolder(ctx.folder, "Seawall"), Industrial.bounds)
	return {}
end

return Industrial
