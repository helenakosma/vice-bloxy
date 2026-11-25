-- Turns location ids (Shared/Catalog/Locations) into places in the world, so
-- gameplay never holds coordinates of its own. See the catalog for how a place is
-- found: an anchor the map team tagged "Location" (with a LocationId attribute)
-- wins; otherwise the catalog's source (a workplace, a TorontoLayout landmark, a
-- Line 1 station).
--
--   Locations.start()               after the world is built
--   Locations.resolve(id)           -> { id, name, kind, area, cframe, position, radius } or nil
--   Locations.arrival()             -> CFrame where new players arrive, or nil
--   Locations.nearestStation(pos)   -> station location id, distance
--   Router "locations.get"          -> { places = { { id, name, kind, area, x, y, z } } }
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog.Locations)
local Router = require(script.Parent.Router)
local World = script.Parent.Parent.World
local TorontoLayout = require(World.TorontoLayout)
local Workplaces = require(World.Workplaces)

local Locations = {}

local TAG = "Location"
local cache = {} -- id -> resolved place (cleared when tagged anchors change)

-- Every Line 1 station as "station.<name>", unless the catalog lists it already.
local entries = {}
for id, def in pairs(Catalog.list) do
	entries[id] = def
end
for _, s in ipairs(TorontoLayout.STATIONS) do
	local id = "station." .. string.lower(s.name)
	if not entries[id] then
		local name = s.name:sub(1, 1) .. s.name:sub(2):lower()
		entries[id] = { name = name .. " Station", kind = "station", area = "Line 1", source = { station = s.name } }
	end
end

-- The walking surface under (x, z): the highest solid thing below `fromY`,
-- ignoring characters and anything you can walk through.
local function surfaceY(x, z, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local origin = Vector3.new(x, fromY or 120, z)
	for _ = 1, 8 do
		local hit = Workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
		if not hit then
			return nil
		end
		if hit.Instance.CanCollide then
			return hit.Position.Y
		end
		table.insert(ignore, hit.Instance)
		params.FilterDescendantsInstances = ignore
	end
	return nil
end

local function fromAnchor(id)
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do
		if part:IsA("BasePart") and part:GetAttribute("LocationId") == id then
			return part.CFrame, part:GetAttribute("Radius") or 20
		end
	end
	return nil
end

local function fromSource(source)
	if source.workplace then
		local wp = Workplaces.get(source.workplace)
		if wp and wp.centre then
			return CFrame.new(wp.centre), wp.radius or 26
		end
	elseif source.landmark then
		local at = TorontoLayout[source.landmark]
		if typeof(at) == "Vector2" then
			local f = source.facing or { 0, -1 }
			local dir = Vector2.new(f[1], f[2]).Unit
			local p = at + dir * (source.forward or 0)
			local y = surfaceY(p.X, p.Y) or 0.75
			local pos = Vector3.new(p.X, y, p.Y)
			return CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Y)), 24
		end
	elseif source.rect then
		local r = TorontoLayout[source.rect]
		if type(r) == "table" and r.minX then
			local f = source.facing or { 0, -1 }
			local dir = Vector2.new(f[1], f[2]).Unit
			local cx, cz = (r.minX + r.maxX) / 2, (r.minZ + r.maxZ) / 2
			local half = math.abs(dir.X) * (r.maxX - r.minX) / 2 + math.abs(dir.Y) * (r.maxZ - r.minZ) / 2
			local reach = math.max(0, half - (source.inset or 0))
			local x, z = cx + dir.X * reach, cz + dir.Y * reach
			local y = surfaceY(x, z) or 0.75
			local pos = Vector3.new(x, y, z)
			return CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Y)), 30
		end
	elseif source.station then
		for _, s in ipairs(TorontoLayout.STATIONS) do
			if s.name == source.station then
				local x = TorontoLayout.YONGE_X
				local y = surfaceY(x, s.z) or 0.75
				return CFrame.new(x, y, s.z), 40
			end
		end
	end
	return nil
end

function Locations.resolve(id)
	if type(id) ~= "string" then
		return nil
	end
	local def = entries[id]
	if cache[id] then
		return cache[id]
	end
	local cframe, radius = fromAnchor(id)
	if not cframe and def and def.source then
		cframe, radius = fromSource(def.source)
	end
	if not cframe then
		return nil
	end
	local place = {
		id = id,
		name = def and def.name or id,
		kind = def and def.kind or "place",
		area = def and def.area or "",
		cframe = cframe,
		position = cframe.Position,
		radius = radius,
	}
	cache[id] = place
	return place
end

function Locations.arrival()
	local place = Locations.resolve(Catalog.ARRIVAL)
	return place and place.cframe
end

function Locations.nearestStation(position)
	local best, bestD = nil, math.huge
	for id, def in pairs(entries) do
		if def.kind == "station" then
			local place = Locations.resolve(id)
			if place then
				local d = (place.position - position).Magnitude
				if d < bestD then
					best, bestD = id, d
				end
			end
		end
	end
	return best, bestD
end

function Locations.start()
	-- A tagged anchor added or removed (the map moving a place) re-resolves.
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function()
		table.clear(cache)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function()
		table.clear(cache)
	end)
	local missing = {}
	for id in pairs(Catalog.list) do
		if not Locations.resolve(id) then
			table.insert(missing, id)
		end
	end
	if #missing > 0 then
		warn("[Locations] couldn't place: " .. table.concat(missing, ", "))
	end

	-- The phone (maps and navigation, later) asks for the places it can show.
	Router.on("locations.get", function()
		local places = {}
		for id in pairs(entries) do
			local place = Locations.resolve(id)
			if place then
				local p = place.position
				table.insert(places, { id = id, name = place.name, kind = place.kind, area = place.area, x = math.floor(p.X), y = math.floor(p.Y), z = math.floor(p.Z) })
			end
		end
		return { places = places }
	end)
end

return Locations
