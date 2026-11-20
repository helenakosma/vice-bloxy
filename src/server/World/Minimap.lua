-- Publishes what the minimap draws, once the world is built: land, parks, roads
-- (with names), highways, subway stations and landmarks, as JSON in
-- ReplicatedStorage.MinimapData (read by client/Minimap.client.lua).
-- Coordinates are world x, z rounded to whole studs to keep the data small.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Util)
local Roads = require(script.Parent.Roads)
local Highways = require(script.Parent.Highways)
local TorontoLayout = require(script.Parent.TorontoLayout)
local Buildings = require(script.Parent.Buildings)

local Minimap = {}

local function r(v)
	return math.floor(v + 0.5)
end

local function rect(b)
	return { r(b.minX), r(b.minZ), r(b.maxX), r(b.maxZ) }
end

function Minimap.publish(extraStations)
	local T = TorontoLayout
	local data = { land = {}, parks = {}, roads = {}, highways = {}, stations = {}, places = {} }
	local G = Util.GRID
	data.bounds = { G.minX, G.minZ, G.maxX, G.maxZ }

	for _, box in ipairs(Util.groundBoxes) do
		if not box.water then
			table.insert(data.land, { r(box.min.X), r(box.min.Z), r(box.max.X), r(box.max.Z) })
		end
	end
	for _, b in ipairs({ T.MOUNT_PLEASANT_CEMETERY, T.MEL_LASTMAN, T.UOFT_SOUTH, T.UOFT_NORTH, Roads.PARK }) do
		table.insert(data.parks, rect(b))
	end

	for _, road in ipairs(Roads.list) do
		local pts = {}
		for _, p in ipairs(road.points) do
			table.insert(pts, { r(p.X), r(p.Y) })
		end
		table.insert(data.roads, { p = pts, w = r(road.width + road.walk * 2), k = road.kind, n = road.name })
	end
	for _, hw in ipairs(Highways.list()) do
		local pts = {}
		for i, p in ipairs(hw.points) do
			if i % 3 == 1 or i == #hw.points then
				table.insert(pts, { r(p.X), r(p.Z) })
			end
		end
		table.insert(data.highways, { p = pts, w = r(hw.width), n = hw.name })
	end

	for _, s in ipairs(T.STATIONS) do
		table.insert(data.stations, { s.name, T.YONGE_X, r(s.z) })
	end
	for _, s in ipairs(extraStations or {}) do
		table.insert(data.stations, s)
	end

	local function place(name, b, kind)
		table.insert(data.places, { name, rect(b), kind })
	end
	place("EATON CENTRE", T.EATON, "mall")
	place("SANKOFA SQ", T.SANKOFA, "square")
	place("CITY HALL", T.CITY_HALL, "civic")
	place("TMU", T.TMU_SLC, "school")
	place("U OF T", T.UOFT_SOUTH, "school")
	local function point(name, v, size, kind)
		place(name, { minX = v.X - size, maxX = v.X + size, minZ = v.Y - size, maxZ = v.Y + size }, kind)
	end
	point("CN TOWER", T.NEEDLE, 30, "civic")
	point("DOME", T.DOME, 50, "civic")
	point("UNION STN", T.UNION, 40, "civic")
	point("ROM", T.ROM, 30, "civic")
	point("YONGE EGLINTON CTR", T.YONGE_EGLINTON_CENTRE, 70, "mall")

	-- Building footprints, flattened (x, z, w, d, facing) and split over several
	-- values (a StringValue can't hold an unlimited amount of text).
	local folder = Instance.new("Folder")
	folder.Name = "MinimapBuildings"
	local chunk, n, parts = {}, 0, 0
	local function flush()
		if #chunk > 0 then
			parts = parts + 1
			local v = Instance.new("StringValue")
			v.Name = "Part" .. parts
			v.Value = HttpService:JSONEncode(chunk)
			v.Parent = folder
			chunk = {}
		end
	end
	for _, f in ipairs(Buildings.footprints) do
		table.insert(chunk, r(f[1]))
		table.insert(chunk, r(f[2]))
		table.insert(chunk, r(f[3]))
		table.insert(chunk, r(f[4]))
		table.insert(chunk, r(f[5]))
		n = n + 1
		if #chunk >= 5 * 3000 then
			flush()
		end
	end
	flush()
	folder:SetAttribute("Parts", parts)
	folder.Parent = ReplicatedStorage
	print(string.format("[Minimap] %d building footprints in %d parts", n, parts))

	local value = Instance.new("StringValue")
	value.Name = "MinimapData"
	value.Value = HttpService:JSONEncode(data)
	value.Parent = ReplicatedStorage
	print(string.format("[Minimap] %d roads, %d highways, %d land boxes, %d bytes", #data.roads, #data.highways, #data.land, #value.Value))
end

return Minimap
