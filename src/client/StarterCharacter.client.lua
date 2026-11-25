local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.Phone.PhoneUI)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request")
local theme = UI.THEMES.dark

local shown = false
local function showRoll()
	if shown or not player:GetAttribute("StarterRollPending") then
		return
	end
	shown = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "StarterCharacter"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30

	local backdrop = UI.frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.bg,
		BackgroundTransparency = 0.25,
		Active = true,
	})
	local card = UI.frame(backdrop, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.88, 0, 0, 204),
		BackgroundColor3 = theme.card,
	})
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(380, 204)
	size.Parent = card
	UI.corner(card, 16)
	UI.pad(card, 20)

	local title = UI.text(card, "Your first character", 24, theme.text, {
		Font = Enum.Font.GothamBold,
	})
	local detail = UI.text(card, "Roll to get your first character and their base stats.", 16, theme.muted, {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 64),
	})
	local button = UI.button(card, "Roll", theme.accent, theme.bg, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		Modal = true,
	})

	local rolling = false
	local rolled = false
	button.Activated:Connect(function()
		if rolled then
			gui:Destroy()
			return
		end
		if rolling then
			return
		end

		rolling = true
		button.Text = "Rolling..."
		local ok, result = pcall(request.InvokeServer, request, "characters.rollStarter")
		rolling = false
		if not ok or not result.ok then
			detail.Text = ok and result.error or "Couldn't roll right now. Try again."
			button.Text = "Roll"
			return
		end

		local character = result.character
		rolled = true
		title.Text = "Character ready"
		detail.Text = string.format("Level %d   •   Strength %d   •   Stamina %d\nOpen the Jobs app to find work.",
			character.level, character.baseStats.strength, character.baseStats.stamina)
		button.Text = "Play"
	end)

	gui.Parent = playerGui
end

player:GetAttributeChangedSignal("StarterRollPending"):Connect(showRoll)
showRoll()
