-- Notifications: a toast on screen right now, and a saved entry in the phone's
-- inbox (the last InboxSize). Categories ("bank", "system", later "jobs", ...) can
-- be muted in the phone's settings; muted ones still go to the inbox.
--
--   Notify.send(player, { title, body, app?, category? })
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Economy)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Parent.Remotes)

local Notify = {}

function Notify.send(player, n)
	local data = PlayerData.get(player)
	local item = {
		id = HttpService:GenerateGUID(false),
		t = os.time(),
		title = n.title or "",
		body = n.body or "",
		app = n.app,
		category = n.category or "system",
		read = false,
	}
	if data then
		table.insert(data.inbox, 1, item)
		while #data.inbox > Settings.InboxSize do
			table.remove(data.inbox)
		end
	end
	local muted = data and data.phone.notify[item.category] == false
	Remotes.Push:FireClient(player, { type = "notify", item = item, silent = muted })
end

return Notify
