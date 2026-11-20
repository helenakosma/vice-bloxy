-- Fare gate flaps on your screen. The server opens an entry lane for you after you
-- tap a card (FareGate event); exit lanes open by themselves when you walk up from
-- the paid side. Your character's collisions are worked out on your machine, so
-- opening the flaps here lets you through while they stay shut for everyone else.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local OPEN_FOR = 3.5

local function setOpen(flap, open)
	if flap:GetAttribute("Open") == open then
		return
	end
	flap:SetAttribute("Open", open)
	flap.CanCollide = not open
	flap.Transparency = open and 0.9 or 0.4
end

local openUntil = {} -- gateId -> os.clock() time

remotes:WaitForChild("FareGate").OnClientEvent:Connect(function(gateId)
	openUntil[gateId] = os.clock() + OPEN_FOR
end)

while true do
	task.wait(0.1)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local t = os.clock()
	for _, flap in ipairs(CollectionService:GetTagged("FareGate")) do
		local open = (openUntil[flap:GetAttribute("GateId")] or 0) > t
		if not open and not flap:GetAttribute("Entry") and root then
			-- Exit lanes: open when you're right there on the paid side.
			local rel = root.Position - flap.Position
			local paidDir = flap:GetAttribute("PaidDir") or 1
			local flat = Vector3.new(rel.X, 0, rel.Z).Magnitude
			open = flat < 6 and rel.Z * paidDir > -0.5 and math.abs(rel.Y) < 6
		end
		setOpen(flap, open)
	end
end
