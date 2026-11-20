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
folder.Parent = ReplicatedStorage

function Remotes.notify(player, text)
	Remotes.Notify:FireClient(player, text)
end

return Remotes
