-- The only code allowed to change a player's money.
--
-- Every change is a transaction { id, time, amount, kind, memo, balance after }.
-- A transaction id is applied once only (retries are harmless), balances never go
-- below zero, and the last LedgerSize transactions are kept for the Bank app.
-- The leaderstats "Cash" value is a read-only mirror for the HUD and leaderboard.
--
--   Economy.balance(player)                          -> number?
--   Economy.pay(player, amount, kind, memo, txId?)   -> ok, balance   (money in)
--   Economy.charge(player, amount, kind, memo, txId?)-> ok, balance or "insufficient"
--   Economy.canAfford(player, amount)                -> bool
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Economy)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Parent.Remotes)

local Economy = {}

local function mirror(player, balance)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = stats
		stats.Parent = player
	end
	stats.Cash.Value = balance
end

local function apply(player, amount, kind, memo, txId)
	amount = math.floor(amount + 0.5)
	local data = PlayerData.get(player)
	if not data then
		return false, "not loaded"
	end
	local money = data.money
	txId = txId or HttpService:GenerateGUID(false)
	if table.find(money.seen, txId) then
		return true, money.balance -- already applied
	end
	if amount < 0 and money.balance + amount < 0 then
		return false, "insufficient"
	end
	money.balance += amount
	table.insert(money.seen, txId)
	while #money.seen > Settings.RememberTransactions do
		table.remove(money.seen, 1)
	end
	local entry = { id = txId, t = os.time(), a = amount, k = kind or "other", m = memo or "", b = money.balance }
	table.insert(money.ledger, 1, entry)
	while #money.ledger > Settings.LedgerSize do
		table.remove(money.ledger)
	end
	mirror(player, money.balance)
	Remotes.Push:FireClient(player, { type = "bank", balance = money.balance, entry = entry })
	return true, money.balance
end

function Economy.balance(player)
	local data = PlayerData.get(player)
	return data and data.money.balance
end

function Economy.canAfford(player, amount)
	local balance = Economy.balance(player)
	return balance ~= nil and balance >= amount
end

function Economy.pay(player, amount, kind, memo, txId)
	assert(amount >= 0, "pay takes a positive amount")
	return apply(player, amount, kind, memo, txId)
end

function Economy.charge(player, amount, kind, memo, txId)
	assert(amount >= 0, "charge takes a positive amount")
	return apply(player, -amount, kind, memo, txId)
end

function Economy.start()
	PlayerData.onLoaded(function(player, data)
		mirror(player, data.money.balance)
	end)
end

return Economy
