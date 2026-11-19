-- Suburbs (west of downtown): a north shore road where the Harbor Freeway comes
-- down, three winding collectors, and downtown's cross streets carrying on west
-- under the expressway. Roads only so far.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)

local Suburbs = {
	name = "Suburbs",
	bounds = Layout.SUBURBS,
	budget = 14000,
}

function Suburbs.layout(ctx)
	local b = Suburbs.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(98, 104, 84), Enum.Material.Grass)

	local roads = {}
	local shoreZ = Layout.SUBURB_SHORE_Z
	local harborStart = Layout.HARBOR[1]

	-- North shore road, from where the Harbor Freeway lands out to the west edge.
	table.insert(roads, Roads.add("street", Roads.path(rng, Vector2.new(harborStart.X, harborStart.Z), Vector2.new(b.minX + 30, shoreZ), 110, 3)))

	-- Collectors run from the shore road to the south edge, then join up along it.
	local southZ = b.maxZ - 30
	for i = 1, #Layout.SUBURB_COLLECTORS do
		local points = {}
		for z = shoreZ, southZ, 60 do
			table.insert(points, Vector2.new(Layout.suburbCollectorX(i, z), z))
		end
		table.insert(points, Vector2.new(Layout.suburbCollectorX(i, southZ), southZ))
		table.insert(roads, Roads.add("street", points))
	end
	local southRoad = {}
	for i = #Layout.SUBURB_COLLECTORS, 1, -1 do
		table.insert(southRoad, Vector2.new(Layout.suburbCollectorX(i, southZ), southZ))
	end
	table.insert(southRoad, Vector2.new(b.maxX, southZ))
	table.insert(roads, Roads.add("residential", southRoad))

	-- Downtown cross streets that reach the west edge continue to the last collector.
	for _, road in ipairs(ctx.shared.downtownRoads) do
		local first = road.points[1]
		if road.kind == "street" and math.abs(first.X - Util.MIN_X) < 1 then
			local z = first.Y
			local points = { Vector2.new(Util.MIN_X, z) }
			local prevX = Util.MIN_X
			for i = 1, #Layout.SUBURB_COLLECTORS do
				local zz = z + rng:NextNumber(-12, 12)
				local cx = Layout.suburbCollectorX(i, zz)
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
	Util.seawall(ctx.makeFolder(ctx.folder, "Seawall"), Suburbs.bounds)
	return {}
end

return Suburbs
