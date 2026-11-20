-- Creates the RemoteEvents shared between server and client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local Remotes = {}
for _, name in ipairs({ "EnterBegin", "EnterDone", "ExitRequest", "ExitBegin", "Notify", "FareGate", "BoardVehicle", "BoardResult" }) do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	Remotes[name] = event
end

-- The society: the phone asks with Request (a RemoteFunction routed and checked by
-- Services/Router) and the server tells the client about changes with Push.
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = folder
Remotes.Request = request
local push = Instance.new("RemoteEvent")
push.Name = "Push"
push.Parent = folder
Remotes.Push = push
folder.Parent = ReplicatedStorage

function Remotes.notify(player, text)
	Remotes.Notify:FireClient(player, text)
end

return Remotes
