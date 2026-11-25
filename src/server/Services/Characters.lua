local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Characters
local PlayerData = require(script.Parent.PlayerData)
local Router = require(script.Parent.Router)

local Characters = {}
local rng = Random.new()

local function spawnPlayer(player, data)
	if not player.Parent then
		return
	end

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local root = character:WaitForChild("HumanoidRootPart")
		local pending = data.activeCharacterId == nil
		-- Hold the native Roblox avatar at the city spawn until the starter roll.
		if pending then
			root.Anchored = true
		else
			character:SetAttribute("CharacterId", data.activeCharacterId)
		end
		player:SetAttribute("StarterRollPending", pending)

		humanoid.Died:Once(function()
			task.wait(Players.RespawnTime)
			if player.Parent then
				player:LoadCharacterAsync()
			end
		end)
	end)

	player:LoadCharacterAsync()
end

function Characters.start()
	Router.on("characters.get", function(player)
		local data = PlayerData.get(player)
		return {
			balance = data.money.balance,
			level = data.level,
			activeCharacterId = data.activeCharacterId,
			characters = data.characters,
		}
	end)

	Router.on("characters.rollStarter", function(player)
		local data = PlayerData.get(player)
		-- A repeated request returns the existing roll from this player's profile.
		if data.activeCharacterId then
			return { character = data.characters[data.activeCharacterId] }
		end
		local avatar = player.Character
		local root = avatar and avatar:FindFirstChild("HumanoidRootPart")
		if not root or not player:GetAttribute("StarterRollPending") then
			return nil, "Your avatar is still loading. Try again in a moment."
		end

		local id = HttpService:GenerateGUID(false)
		local character = {
			id = id,
			level = Config.StartingLevel,
			baseStats = {
				strength = rng:NextInteger(Config.StarterStatMin, Config.StarterStatMax),
				stamina = rng:NextInteger(Config.StarterStatMin, Config.StarterStatMax),
			},
		}
		data.characters[id] = character
		data.activeCharacterId = id
		avatar:SetAttribute("CharacterId", id)
		root.Anchored = false
		player:SetAttribute("StarterRollPending", false)
		return { character = character }
	end)

	PlayerData.onLoaded(spawnPlayer)
end

return Characters
