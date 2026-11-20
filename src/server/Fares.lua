-- Transit fares: a stored-value card (bought and topped up at ticket machines),
-- tapped at subway fare gates and charged when you board a bus or streetcar.
-- Paying a fare gives a transfer: for Config.Fares.TransferSeconds, further
-- taps and boardings are free (like a real 2-hour transfer).
--
-- State lives in player attributes, so the HUD can show it:
--   HasTransitCard (bool), CardBalance (number), FareValidUntil (server time).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local Fares = {}
local settings = Config.Fares

local function cashOf(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function now()
	return Workspace:GetServerTimeNow()
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("HasTransitCard", false)
	player:SetAttribute("CardBalance", 0)
	player:SetAttribute("FareValidUntil", 0)
end)

-- Charges one fare (or uses a transfer). Returns ok, message.
function Fares.pay(player)
	if (player:GetAttribute("FareValidUntil") or 0) > now() then
		return true, "Transfer · no charge"
	end
	if not player:GetAttribute("HasTransitCard") then
		return false, "You need a Transit Card · get one at a ticket machine"
	end
	local balance = player:GetAttribute("CardBalance") or 0
	if balance < settings.Fare then
		return false, string.format("Card balance $%d · top up at a ticket machine", balance)
	end
	balance = balance - settings.Fare
	player:SetAttribute("CardBalance", balance)
	player:SetAttribute("FareValidUntil", now() + settings.TransferSeconds)
	return true, string.format("Fare $%d paid · balance $%d · transfer for %d min", settings.Fare, balance, math.floor(settings.TransferSeconds / 60))
end

local function prompt(part, action, object, key)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.HoldDuration = 0.2
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Parent = part
	return p
end

-- Ticket machine: buy a card, or top one up.
function Fares.attachMachine(part)
	local buy = prompt(part, string.format("Get Transit Card ($%d)", settings.CardPrice), "Ticket machine", Enum.KeyCode.E)
	buy.Triggered:Connect(function(player)
		if player:GetAttribute("HasTransitCard") then
			Remotes.notify(player, string.format("You already have a card · balance $%d", player:GetAttribute("CardBalance") or 0))
			return
		end
		local cash = cashOf(player)
		if not cash or cash.Value < settings.CardPrice then
			Remotes.notify(player, "Not enough cash")
			return
		end
		cash.Value = cash.Value - settings.CardPrice
		player:SetAttribute("HasTransitCard", true)
		player:SetAttribute("CardBalance", settings.StartBalance)
		Remotes.notify(player, string.format("Transit Card bought · $%d loaded · tap it at the fare gates", settings.StartBalance))
	end)
	local load = prompt(part, string.format("Top up card ($%d)", settings.LoadAmount), "Ticket machine", Enum.KeyCode.R)
	load.UIOffset = Vector2.new(0, 60)
	load.Triggered:Connect(function(player)
		if not player:GetAttribute("HasTransitCard") then
			Remotes.notify(player, "Get a Transit Card first")
			return
		end
		local cash = cashOf(player)
		if not cash or cash.Value < settings.LoadAmount then
			Remotes.notify(player, "Not enough cash")
			return
		end
		cash.Value = cash.Value - settings.LoadAmount
		local balance = (player:GetAttribute("CardBalance") or 0) + settings.LoadAmount
		player:SetAttribute("CardBalance", balance)
		Remotes.notify(player, string.format("Card topped up · balance $%d", balance))
	end)
end

-- Fare gate reader: tap to pay; the gate opens for you (on your screen).
function Fares.attachGate(reader, gateId)
	local tap = prompt(reader, "Tap card", "Fare gate", Enum.KeyCode.E)
	tap.HoldDuration = 0
	tap.MaxActivationDistance = 7
	tap.Triggered:Connect(function(player)
		local ok, message = Fares.pay(player)
		Remotes.notify(player, message)
		if ok then
			Remotes.FareGate:FireClient(player, gateId)
		end
	end)
end

-- Buses and streetcars: the client reports boarding; we charge or turn them away.
local lastBoard = {}
Remotes.BoardVehicle.OnServerEvent:Connect(function(player, vehicleName)
	if typeof(vehicleName) ~= "string" then
		return
	end
	local t = os.clock()
	if lastBoard[player] and t - lastBoard[player] < 1 then
		return
	end
	lastBoard[player] = t
	local ok, message = Fares.pay(player)
	Remotes.notify(player, message)
	Remotes.BoardResult:FireClient(player, vehicleName, ok)
end)
Players.PlayerRemoving:Connect(function(player)
	lastBoard[player] = nil
end)

return Fares
