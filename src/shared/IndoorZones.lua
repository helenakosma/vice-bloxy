-- Indoor areas (the Eaton Centre for now), published by the server as the
-- ReplicatedStorage "IndoorZones" value. Clients use it to hide map tags and
-- street guidance while you're inside a building.
--
--   IndoorZones.contains(position) -> bool
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IndoorZones = {}

local zones = {}

local function load(value)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, value.Value)
	zones = ok and type(list) == "table" and list or {}
end

task.spawn(function()
	local value = ReplicatedStorage:WaitForChild("IndoorZones", 120)
	if value then
		load(value)
		value.Changed:Connect(function()
			load(value)
		end)
	end
end)

function IndoorZones.contains(p)
	for _, z in ipairs(zones) do
		if p.X >= z.minX and p.X <= z.maxX and p.Z >= z.minZ and p.Z <= z.maxZ and p.Y >= z.minY and p.Y <= z.maxY then
			return true
		end
	end
	return false
end

return IndoorZones
