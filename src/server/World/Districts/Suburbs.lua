-- Suburbs (west of downtown): three curving north-south collectors, with downtown's
-- cross streets carrying on west under the expressway. Phase 1: roads only.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)

local Suburbs = {
	name = "Suburbs",
	bounds = Layout.SUBURBS,
	budget = 14000,
}

local COLLECTORS = { -1050, -1400, -1700 }

local function collectorX(i, z)
	return COLLECTORS[i] + 40 * math.sin(z / 260 + i * 1.7)
end

function Suburbs.layout(ctx)
	local b = Suburbs.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(98, 104, 84), Enum.Material.Grass)

	local roads = {}
	for i = 1, #COLLECTORS do
		local points = {}
		for z = b.minZ + 15, b.maxZ - 20, 60 do
			table.insert(points, Vector2.new(collectorX(i, z), z))
		end
		table.insert(roads, Roads.add("street", points))
	end

	-- Downtown cross streets that reach the west edge continue to the last collector.
	for _, road in ipairs(ctx.shared.downtownRoads) do
		local first = road.points[1]
		if road.kind == "street" and math.abs(first.X - Util.MIN_X) < 1 then
			local z = first.Y
			local points = { Vector2.new(Util.MIN_X, z) }
			local prevX = Util.MIN_X
			for i = 1, #COLLECTORS do
				local zz = z + rng:NextNumber(-12, 12)
				local cx = collectorX(i, zz)
				table.insert(points, Vector2.new((prevX + cx) / 2, z + rng:NextNumber(-12, 12)))
				table.insert(points, Vector2.new(cx, zz))
				prevX = cx
			end
			table.insert(roads, Roads.add("residential", points))
		end
	end

	Roads.rasterize(roads)
	ctx.roads = roads
end

function Suburbs.build(ctx)
	Roads.render(ctx.makeFolder(ctx.folder, "Roads"), ctx.roads)
	return {}
end

return Suburbs
