-- Routes phone requests (Remotes.Request, a RemoteFunction) to handlers, with a
-- per-player rate limit. Handlers get (player, args) and must validate args
-- themselves: nothing from the client is trusted. They return a table (sent back
-- to the client) or nil, message.
--
--   Router.on("bank.get", function(player, args) ... end)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Settings = require(ReplicatedStorage.Shared.Economy)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Parent.Remotes)

local Router = {}

local handlers = {}
local buckets = {} -- player -> { count, windowStart }

function Router.on(action, fn)
	assert(not handlers[action], "duplicate handler " .. action)
	handlers[action] = fn
end

local function allowed(player)
	local now = os.clock()
	local b = buckets[player]
	if not b or now - b.start > Settings.RequestWindowSeconds then
		b = { count = 0, start = now }
		buckets[player] = b
	end
	b.count += 1
	return b.count <= Settings.RequestBurst
end

function Router.start()
	Remotes.Request.OnServerInvoke = function(player, action, args)
		if type(action) ~= "string" or not handlers[action] then
			return { ok = false, error = "Unknown request" }
		end
		if not allowed(player) then
			return { ok = false, error = "Slow down a little" }
		end
		if not PlayerData.get(player) then
			return { ok = false, error = "Your profile is still loading" }
		end
		if args ~= nil and type(args) ~= "table" then
			return { ok = false, error = "Bad request" }
		end
		local ok, result, message = pcall(handlers[action], player, args or {})
		if not ok then
			warn("[Router] " .. action .. " failed: " .. tostring(result))
			return { ok = false, error = "Something went wrong" }
		end
		if result == nil then
			return { ok = false, error = message or "Not allowed" }
		end
		result.ok = true
		return result
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Router
