-- Saves and loads each player's profile (DataStore "Profiles_v1", key = UserId).
--
--   * Session lock: a profile is marked with this server's id while the player is
--     here, so two servers can never overwrite each other's copy. A lock that
--     hasn't been refreshed for SessionLockSeconds is treated as abandoned.
--   * Saves every SaveEverySeconds, when the player leaves, and when the server
--     shuts down (BindToClose), with retries on failure.
--   * Versioned: missing fields are filled from the template, and `version` lets
--     later milestones migrate old saves.
--   * If DataStores aren't available (Studio without API access), the player plays
--     with a fresh, unsaved profile and is told saving is off.
--
-- Other services: PlayerData.get(player), PlayerData.waitFor(player),
-- PlayerData.onLoaded(fn(player, data)), PlayerData.isGuest(player).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Economy)

local PlayerData = {}

local VERSION = 1
local SESSION = HttpService:GenerateGUID(false)

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Profiles_v1")
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStores unavailable, profiles won't save: " .. tostring(result))
	end
end

-- Everything a new player starts with. Later milestones add their sections here.
local function template(player)
	return {
		version = VERSION,
		identity = {
			joined = os.time(),
			bio = "",
			privacy = { profile = "public", job = true, home = true, education = true },
		},
		money = { balance = Economy.StartingBalance, ledger = {}, seen = {} },
		transit = { card = false, balance = 0 },
		phone = { wallpaper = 1, theme = "dark", notify = { bank = true, jobs = true, system = true } },
		inbox = {},
		employment = { history = {}, applications = {}, saved = {}, experience = {}, skills = {}, totalShifts = 0 },
		education = { applications = {}, enrolment = nil, degrees = {} },
		housing = { lease = nil, owned = {}, layouts = {} },
		inventory = { furniture = {}, items = {} },
		social = { connections = {}, requestsIn = {}, requestsOut = {}, referrals = { given = {}, received = {} } },
		achievements = {},
		stats = { playSeconds = 0 },
		_name = player.Name,
	}
end

-- Fills in anything the saved profile is missing (new fields from later versions).
local function reconcile(data, base)
	for k, v in pairs(base) do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v)
		end
	end
	return data
end

local function migrate(data)
	-- Future: if data.version < 2 then ... end
	data.version = VERSION
	return data
end

local profiles = {} -- player -> { data, guest, loadedAt }
local loadedEvent = Instance.new("BindableEvent")
local listeners = {}
local leavingHooks = {} -- run before the final save (e.g. pay out a shift in progress)

local function key(player)
	return "u" .. player.UserId
end

-- One load attempt. Returns data, or nil plus "locked" / an error message.
local function tryLoad(player)
	local lockedElsewhere = false
	local ok, result = pcall(function()
		return store:UpdateAsync(key(player), function(old)
			old = old or template(player)
			local lock = old.__lock
			if lock and lock.id ~= SESSION and os.time() - (lock.t or 0) < Economy.SessionLockSeconds then
				lockedElsewhere = true
				return nil -- leave it alone; the other server still has it
			end
			old.__lock = { id = SESSION, t = os.time() }
			return old
		end)
	end)
	if not ok then
		return nil, tostring(result)
	end
	if lockedElsewhere then
		return nil, "locked"
	end
	return result, nil
end

local function load(player)
	if not store then
		return template(player), true
	end
	for attempt = 1, 6 do
		local data, err = tryLoad(player)
		if data then
			return reconcile(migrate(data), template(player)), false
		end
		if err ~= "locked" and (err:find("403") or err:find("API") or err:find("publish")) then
			warn("[PlayerData] " .. err)
			return template(player), true -- no access in this place: play unsaved
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(err == "locked" and 6 or math.min(2 ^ attempt, 16))
	end
	return nil, false
end

-- Writes the profile. release = true drops the session lock (player left).
local function save(player, entry, release)
	if entry.guest or not store then
		return true
	end
	local data = entry.data
	data.stats.lastSaved = os.time()
	for attempt = 1, 4 do
		local lost = false
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				if old and old.__lock and old.__lock.id ~= SESSION then
					lost = true -- another server took over: never overwrite its copy
					return nil
				end
				data.__lock = (not release) and { id = SESSION, t = os.time() } or nil
				return data
			end)
		end)
		if ok then
			if lost then
				warn("[PlayerData] lost the session lock for " .. player.Name .. "; not saving over it")
			end
			return not lost
		end
		warn(string.format("[PlayerData] save failed for %s (try %d): %s", player.Name, attempt, tostring(err)))
		task.wait(math.min(2 ^ attempt, 8))
	end
	return false
end

local function onPlayerAdded(player)
	local data, guest = load(player)
	if not data then
		if player.Parent then
			player:Kick("Your profile is still being saved by another server. Please rejoin in a moment.")
		end
		return
	end
	if not player.Parent then
		-- Left while loading: hand the lock straight back.
		save(player, { data = data, guest = guest }, true)
		return
	end
	local entry = { data = data, guest = guest, loadedAt = os.clock() }
	profiles[player] = entry
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("SavingOff", guest)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, player, data)
	end
	loadedEvent:Fire(player)
end

local function onPlayerRemoving(player)
	local entry = profiles[player]
	if not entry then
		return
	end
	for _, fn in ipairs(leavingHooks) do
		local ok, err = pcall(fn, player, entry.data)
		if not ok then
			warn("[PlayerData] leaving hook failed: " .. tostring(err))
		end
	end
	entry.data.stats.playSeconds += os.clock() - entry.loadedAt
	save(player, entry, true)
	profiles[player] = nil
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
function PlayerData.get(player)
	local entry = profiles[player]
	return entry and entry.data
end

function PlayerData.isGuest(player)
	local entry = profiles[player]
	return entry ~= nil and entry.guest
end

function PlayerData.waitFor(player, timeout)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and os.clock() < deadline do
		task.wait(0.2)
	end
	return PlayerData.get(player)
end

-- fn(player, data) runs once each player's profile is ready (and for anyone
-- already loaded when this is called).
function PlayerData.onLoaded(fn)
	table.insert(listeners, fn)
	for player, entry in pairs(profiles) do
		task.spawn(fn, player, entry.data)
	end
end

-- fn(player, data) runs when a player leaves, just before their final save.
function PlayerData.onLeaving(fn)
	table.insert(leavingHooks, fn)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	-- Autosave, spread out so every save doesn't hit at once.
	task.spawn(function()
		while true do
			task.wait(Economy.SaveEverySeconds)
			for player, entry in pairs(profiles) do
				if player.Parent then
					task.spawn(save, player, entry, false)
					task.wait(0.5)
				end
			end
		end
	end)
	-- Server shutting down: save everyone (in parallel) before it closes.
	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player, entry in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(player, entry, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
