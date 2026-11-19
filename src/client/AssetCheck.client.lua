-- Preloads every imported texture once and warns in Output about any that fail,
-- which usually means a mistyped ID in src/shared/Assets.lua.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local names = {}
local decals = {}
for _, entry in ipairs(Assets.all()) do
	local decal = Instance.new("Decal")
	decal.Texture = entry[2]
	names[entry[2]] = entry[1]
	table.insert(decals, decal)
end

local failed = 0
ContentProvider:PreloadAsync(decals, function(contentId, status)
	if status ~= Enum.AssetFetchStatus.Success then
		failed = failed + 1
		warn(string.format("[Assets] %s (%s) failed to load: %s", names[contentId] or "?", contentId, status.Name))
	end
end)
print(string.format("[Assets] %d textures checked, %d failed", #decals, failed))
