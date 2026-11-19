-- Automatic sliding shop doors. The server builds the door panels and tags them
-- "AutoDoor" with a "SlideX" attribute (how far to slide, in the panel's own X).
-- Each client slides the panels open locally when its character is close, and
-- turns off their collision so the player walks straight in; nothing is teleported.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local OPEN_DISTANCE = 11
local TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local doors = {} -- panel -> { closed = CFrame, open = boolean }

local function track(panel)
	if not panel:IsA("BasePart") or doors[panel] then
		return
	end
	doors[panel] = { closed = panel.CFrame, open = false }
end

local function untrack(panel)
	doors[panel] = nil
end

for _, panel in ipairs(CollectionService:GetTagged("AutoDoor")) do
	track(panel)
end
CollectionService:GetInstanceAddedSignal("AutoDoor"):Connect(track)
CollectionService:GetInstanceRemovedSignal("AutoDoor"):Connect(untrack)

local function setOpen(panel, state, open)
	state.open = open
	local target = state.closed
	if open then
		target = state.closed * CFrame.new(panel:GetAttribute("SlideX") or 0, 0, 0)
	end
	panel.CanCollide = not open
	TweenService:Create(panel, TWEEN, { CFrame = target }):Play()
end

while true do
	task.wait(0.15)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for panel, state in pairs(doors) do
		if not panel.Parent then
			doors[panel] = nil
		else
			local near = root ~= nil and (root.Position - state.closed.Position).Magnitude < OPEN_DISTANCE
			if near ~= state.open then
				setOpen(panel, state, near)
			end
		end
	end
end
