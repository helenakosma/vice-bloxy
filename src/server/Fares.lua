-- Transit fares: a stored-value card (bought and topped up at ticket machines),
-- tapped at subway fare gates and charged when you board a bus or streetcar.
-- Paying a fare gives a transfer: for Config.Fares.TransferSeconds, further
-- taps and boardings are free (like a real 2-hour transfer).
--
-- The card and its balance are saved in the player's profile (transit section);
-- attributes mirror them for the HUD: HasTransitCard, CardBalance, and
-- FareValidUntil (server time, not saved).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.Services.PlayerData)
local Economy = require(script.Parent.Services.Economy)

local Fares = {}
local settings = Config.Fares

local function now()
	return Workspace:GetServerTimeNow()
end

-- The card is saved in the profile; attributes mirror it for the HUD.
local function mirror(player, transit)
	player:SetAttribute("HasTransitCard", transit.card)
	player:SetAttribute("CardBalance", transit.balance)
end
PlayerData.onLoaded(function(player, data)
	mirror(player, data.transit)
	player:SetAttribute("FareValidUntil", 0)
end)

local function transitOf(player)
	local data = PlayerData.get(player)
	return data and data.transit
end

-- Charges one fare (or uses a transfer). Returns ok, message.
function Fares.pay(player)
	if (player:GetAttribute("FareValidUntil") or 0) > now() then
		return true, "Transfer · no charge"
	end
	local transit = transitOf(player)
	if not transit or not transit.card then
		return false, "You need a Transit Card · get one at a ticket machine"
	end
	local balance = transit.balance
	if balance < settings.Fare then
		return false, string.format("Card balance $%d · top up at a ticket machine", balance)
	end
	balance = balance - settings.Fare
	transit.balance = balance
	mirror(player, transit)
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
		local transit = transitOf(player)
		if not transit then
			return
		end
		if transit.card then
			Remotes.notify(player, string.format("You already have a card · balance $%d", transit.balance))
			return
		end
		if not Economy.charge(player, settings.CardPrice, "transit", "Transit Card") then
			Remotes.notify(player, "Not enough money")
			return
		end
		transit.card = true
		transit.balance = settings.StartBalance
		mirror(player, transit)
		Remotes.notify(player, string.format("Transit Card bought · $%d loaded · tap it at the fare gates", settings.StartBalance))
	end)
	local load = prompt(part, string.format("Top up card ($%d)", settings.LoadAmount), "Ticket machine", Enum.KeyCode.R)
	load.UIOffset = Vector2.new(0, 60)
	load.Triggered:Connect(function(player)
		local transit = transitOf(player)
		if not transit or not transit.card then
			Remotes.notify(player, "Get a Transit Card first")
			return
		end
		if not Economy.charge(player, settings.LoadAmount, "transit", "Transit Card top-up") then
			Remotes.notify(player, "Not enough money")
			return
		end
		transit.balance += settings.LoadAmount
		local balance = transit.balance
		mirror(player, transit)
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
