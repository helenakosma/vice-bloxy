-- Floating map labels (stations, stops) show through walls so you can find them
-- from the street. Underground they'd just clutter the view, so they're hidden
-- while your character is below street level.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local hidden = false

local function apply(gui)
	if gui:IsA("BillboardGui") then
		gui.Enabled = not hidden
	end
end

CollectionService:GetInstanceAddedSignal("MapMarker"):Connect(apply)

while true do
	task.wait(0.5)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local under = root ~= nil and root.Position.Y < -3
	if under ~= hidden then
		hidden = under
		for _, gui in ipairs(CollectionService:GetTagged("MapMarker")) do
			apply(gui)
		end
	end
end
