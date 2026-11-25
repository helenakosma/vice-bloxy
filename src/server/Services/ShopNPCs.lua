-- Cashiers and shoppers in the Eaton Centre's stores, only where players are.
--
--   Cashiers stand behind the tills ("ShopCashier" spots) of stores a player is
--   near, idling, and turn to face whoever is paying.
--   Shoppers wander between a store's browse spots ("ShopSpot"), stop at the
--   displays, and some leave carrying a bag in the store's colour.
--
-- Nothing runs for stores nobody is near: NPCs spawn when a player comes within
-- ACTIVE studs and are removed when everyone has gone (DESPAWN). Hard caps keep
-- the number of humanoids small.
--
-- Animations: the walk and idle animations are borrowed from a player's own
-- character (its Animate script's animation ids), so no asset ids are hard-coded.
-- Until a player with an R15 Animate script is in the game, NPCs move unanimated.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Stores = require(script.Parent.Parent.World.EatonCentre.Stores)

local ShopNPCs = {}

local ACTIVE = 110 -- a player this close to a store wakes it up
local DESPAWN = 170 -- nobody this close: its NPCs go
local MAX_CASHIERS = 24
local MAX_SHOPPERS = 28
local SHOPPERS_PER_STORE = 2
local TICK = 2

local C = Color3.fromRGB
local SKIN = { C(255, 220, 190), C(234, 190, 150), C(198, 140, 100), C(150, 100, 70), C(100, 66, 46), C(240, 206, 170) }
local CLOTHES = { C(30, 30, 34), C(240, 240, 236), C(40, 70, 130), C(160, 40, 40), C(120, 150, 90), C(200, 170, 140), C(90, 90, 100), C(220, 120, 150), C(60, 100, 160) }
local PANTS = { C(30, 30, 34), C(40, 60, 100), C(110, 100, 90), C(70, 70, 76), C(200, 190, 170) }

local rng = Random.new()
local folder
local anims = nil -- { walk = id, idle = id }
local cashiers = {} -- spot part -> model
local shoppers = {} -- model -> { store, alive }
local storeSpots = {} -- store key -> { spot parts }

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- Borrow walk/idle animation ids from a player's R15 Animate script.
local function findAnims()
	if anims then
		return anims
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local animate = character and character:FindFirstChild("Animate")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if animate and humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
			local function id(folderName)
				local f = animate:FindFirstChild(folderName)
				local a = f and f:FindFirstChildOfClass("Animation")
				return a and a.AnimationId ~= "" and a.AnimationId or nil
			end
			local walk, idle = id("walk"), id("idle")
			if walk and idle then
				anims = { walk = walk, idle = idle }
				return anims
			end
		end
	end
	return nil
end

local function newRig(name)
	local desc = Instance.new("HumanoidDescription")
	local skin = pick(SKIN)
	local top, legs = pick(CLOTHES), pick(PANTS)
	desc.HeadColor = skin
	desc.TorsoColor = top
	desc.LeftArmColor = top
	desc.RightArmColor = top
	desc.LeftLegColor = legs
	desc.RightLegColor = legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 6
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Default"
		end
	end
	return model, humanoid
end

-- Walk while moving, idle while still.
local function animate(humanoid)
	local a = findAnims()
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not a or not animator then
		return
	end
	local function load(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		return ok and track or nil
	end
	local walk, idle = load(a.walk), load(a.idle)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if not walk then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
				walk.Looped = true
			end
			walk:AdjustSpeed(speed / 10)
		elseif walk.IsPlaying then
			walk:Stop(0.25)
		end
	end)
end

local function anyPlayerWithin(pos, radius)
	for _, player in ipairs(Players:GetPlayers()) do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - pos).Magnitude <= radius then
			return true
		end
	end
	return false
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

---------------------------------------------------------------------------
-- Cashiers
---------------------------------------------------------------------------
local function spawnCashier(spotPart)
	local model, humanoid = newRig("Cashier")
	if not model then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	model:PivotTo(spotPart.CFrame * CFrame.new(0, 2.6, 0))
	model.Parent = folder
	animate(humanoid)
	cashiers[spotPart] = model
end

---------------------------------------------------------------------------
-- Shoppers
---------------------------------------------------------------------------
-- A garment held up against the body (on its hanger), as if trying it on.
local function holdUp(model)
	local torso = model:FindFirstChild("UpperTorso")
	if not torso then
		return nil
	end
	local colour = pick(CLOTHES):Lerp(pick(CLOTHES), 0.3)
	local g = Instance.new("Model")
	g.Name = "HeldGarment"
	local function piece(size, offset, c, mat)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = c
		p.Material = mat or Enum.Material.Fabric
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = torso.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = torso, p
		w.Parent = p
		p.Parent = g
		return p
	end
	piece(Vector3.new(1.9, 2.6, 0.12), CFrame.new(0, -0.4, -0.75), colour)
	for _, s in ipairs({ -1, 1 }) do
		piece(Vector3.new(0.45, 1.6, 0.1), CFrame.new(s * 1.15, -0.3, -0.72) * CFrame.Angles(0, 0, math.rad(s * 8)), colour)
	end
	piece(Vector3.new(1.6, 0.1, 0.1), CFrame.new(0, 0.95, -0.8), Color3.fromRGB(200, 180, 150), Enum.Material.Wood)
	piece(Vector3.new(0.08, 0.4, 0.08), CFrame.new(0, 1.2, -0.8), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	g.Parent = model
	return g
end

local function shopperLoop(model, humanoid, storeKey)
	local spots = storeSpots[storeKey] or {}
	local state = shoppers[model]
	local visits = rng:NextInteger(3, 6)
	for _ = 1, visits do
		if not state.alive or not model.Parent or #spots == 0 then
			break
		end
		local target = pick(spots)
		humanoid:MoveTo(target.Position + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5)))
		local done = false
		local conn = humanoid.MoveToFinished:Connect(function()
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 12 and state.alive do
			task.wait(0.3)
		end
		conn:Disconnect()
		-- browse: stand and look at the display a while; in clothing stores, often
		-- hold a garment up against themselves first
		local held = nil
		local store = Stores.registry[storeKey]
		local arch = store and store.arch
		if (arch == "fashion" or arch == "dept" or arch == "sports" or arch == "premium" or arch == "intimates" or arch == "outdoor") and rng:NextNumber() < 0.45 then
			held = holdUp(model)
		end
		task.wait(rng:NextNumber(3, 8))
		if held then
			held:Destroy()
		end
	end
	-- leave: some with a bag, then fade out by the door
	if state.alive and model.Parent and rng:NextNumber() < 0.5 then
		local store = Stores.registry[storeKey]
		local hand = model:FindFirstChild("RightHand")
		if hand and store then
			local bag = Instance.new("Part")
			bag.Size = Vector3.new(0.4, 1.3, 1.1)
			bag.Color = store.colour
			bag.Material = Enum.Material.Fabric
			bag.CanCollide = false
			bag.Massless = true
			bag.CFrame = hand.CFrame * CFrame.new(0, -0.6, 0)
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = hand, bag
			w.Parent = bag
			bag.Parent = model
		end
		task.wait(rng:NextNumber(2, 4))
	end
	if model.Parent then
		model:Destroy()
	end
	shoppers[model] = nil
end

local function spawnShopper(storeKey)
	local spots = storeSpots[storeKey]
	if not spots or #spots == 0 then
		return
	end
	local model, humanoid = newRig("Shopper")
	if not model then
		return
	end
	local start = pick(spots)
	model:PivotTo(start.CFrame * CFrame.new(rng:NextNumber(-1, 1), 2.6, rng:NextNumber(-1, 1)))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	animate(humanoid)
	shoppers[model] = { store = storeKey, alive = true }
	task.spawn(shopperLoop, model, humanoid, storeKey)
end

---------------------------------------------------------------------------
-- The manager: wake stores near players, put the rest to sleep
---------------------------------------------------------------------------
local function tick()
	-- cashiers
	for _, spotPart in ipairs(CollectionService:GetTagged("ShopCashier")) do
		local have = cashiers[spotPart]
		if have and not have.Parent then
			cashiers[spotPart] = nil
			have = nil
		end
		if not have and count(cashiers) < MAX_CASHIERS and anyPlayerWithin(spotPart.Position, ACTIVE) then
			spawnCashier(spotPart)
		elseif have and not anyPlayerWithin(spotPart.Position, DESPAWN) then
			have:Destroy()
			cashiers[spotPart] = nil
		end
	end
	-- shoppers
	local perStore = {}
	for model, s in pairs(shoppers) do
		if not model.Parent then
			shoppers[model] = nil
		else
			local store = Stores.registry[s.store]
			if store and not anyPlayerWithin(store.centre, DESPAWN) then
				s.alive = false
				model:Destroy()
				shoppers[model] = nil
			else
				perStore[s.store] = (perStore[s.store] or 0) + 1
			end
		end
	end
	for key, store in pairs(Stores.registry) do
		if count(shoppers) >= MAX_SHOPPERS then
			break
		end
		if (perStore[key] or 0) < SHOPPERS_PER_STORE and storeSpots[key] and anyPlayerWithin(store.centre, ACTIVE) then
			spawnShopper(key)
		end
	end
end

function ShopNPCs.start()
	folder = Instance.new("Folder")
	folder.Name = "ShopNPCs"
	folder.Parent = Workspace
	for _, p in ipairs(CollectionService:GetTagged("ShopSpot")) do
		local key = p:GetAttribute("Store")
		if key then
			storeSpots[key] = storeSpots[key] or {}
			table.insert(storeSpots[key], p)
		end
	end
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ShopNPCs] " .. tostring(err))
			end
		end
	end)
end

return ShopNPCs
