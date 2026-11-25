-- Shopping in the Eaton Centre's stores.
--
--   Pick up: every featured item on a fixture (tagged "ShopProduct" by
--     World/EatonCentre/Stores) has a prompt. Picking one up puts it in your
--     basket for that store (BasketMax items; picking up in another store puts
--     the first basket back).
--   Pay: the store's till (tagged "ShopTill") charges the basket through Economy
--     with the basket's id, so a basket is only ever paid once. Paid items go into
--     your inventory; you walk out with a bag in the store's colour (or holding
--     your drink or snack).
--   Walk out without paying: the basket is put back (LeaveStuds from the store).
--
-- Prices come from Catalog/Products tiers and Economy.Shopping.Prices, on the
-- server only. The client is told what happened (Push { type = "shop" }) so it can
-- animate it; it never decides anything.
--
--   Router: shop.basket, shop.putBack, inventory.get
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Economy).Shopping
local Products = require(ReplicatedStorage.Shared.Catalog.Products)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local Remotes = require(script.Parent.Parent.Remotes)
local Stores = require(script.Parent.Parent.World.EatonCentre.Stores)

local Shopping = {}

local baskets = {} -- player -> { id, store, items = { productId, ... } }

local function price(productId)
	local p = Products.get(productId)
	return p and Settings.Prices[p.tier] or nil
end

local function root(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function near(player, part, reach)
	local r = root(player)
	return r ~= nil and part ~= nil and (r.Position - part.Position).Magnitude <= (reach or Settings.ReachStuds)
end

local function summary(player)
	local b = baskets[player]
	if not b or #b.items == 0 then
		return { items = {}, total = 0 }
	end
	local items, total = {}, 0
	for _, id in ipairs(b.items) do
		local p = Products.get(id)
		local cost = price(id) or 0
		total += cost
		table.insert(items, { id = id, name = p and p.name or id, price = cost })
	end
	local store = Stores.registry[b.store]
	return { items = items, total = total, store = store and store.name or "", storeKey = b.store, colour = store and store.colour }
end

local function push(player, event, extra)
	local msg = { type = "shop", event = event, basket = summary(player) }
	for k, v in pairs(extra or {}) do
		msg[k] = v
	end
	Remotes.Push:FireClient(player, msg)
end

local function putBack(player, why)
	local b = baskets[player]
	if b and #b.items > 0 then
		baskets[player] = nil
		push(player, "putback", { reason = why })
	else
		baskets[player] = nil
	end
end

---------------------------------------------------------------------------
-- What you carry out: a bag in the store's colour, or your drink/snack
---------------------------------------------------------------------------
local function hand(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function hold(player, model, seconds)
	local character = player.Character
	local h = character and hand(character)
	if not h then
		model:Destroy()
		return
	end
	local old = character:FindFirstChild("HeldShopItem")
	if old then
		old:Destroy()
	end
	model.Name = "HeldShopItem"
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
		end
	end
	local main = model.PrimaryPart
	model:PivotTo(h.CFrame * CFrame.new(0, -0.6, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = h, main
	weld.Parent = main
	model.Parent = character
	task.delay(seconds, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function bagModel(colour, label)
	local m = Instance.new("Model")
	local bag = Instance.new("Part")
	bag.Size = Vector3.new(0.4, 1.4, 1.2)
	bag.Color = colour
	bag.Material = Enum.Material.Fabric
	bag.Parent = m
	local handle = Instance.new("Part")
	handle.Size = Vector3.new(0.1, 0.5, 0.6)
	handle.Color = colour:Lerp(Color3.new(0, 0, 0), 0.3)
	handle.CFrame = bag.CFrame * CFrame.new(0, 0.9, 0)
	handle.Parent = m
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = bag, handle
	w.Parent = bag
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = label or ""
	text.Parent = gui
	gui.Parent = bag
	m.PrimaryPart = bag
	return m
end

local function treatModel(colour)
	local m = Instance.new("Model")
	local cup = Instance.new("Part")
	cup.Shape = Enum.PartType.Cylinder
	cup.Size = Vector3.new(0.9, 0.5, 0.5)
	cup.Color = Color3.fromRGB(245, 245, 242)
	cup.Parent = m
	cup.CFrame = CFrame.Angles(0, 0, math.rad(90))
	local fill = Instance.new("Part")
	fill.Shape = Enum.PartType.Cylinder
	fill.Size = Vector3.new(0.6, 0.52, 0.52)
	fill.Color = colour or Color3.fromRGB(160, 110, 70)
	fill.CFrame = cup.CFrame * CFrame.new(-0.1, 0, 0)
	fill.Parent = m
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = cup, fill
	w.Parent = cup
	m.PrimaryPart = cup
	return m
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function pickUp(player, part)
	local productId = part:GetAttribute("Product")
	local storeKey = part:GetAttribute("Store")
	local cost = price(productId)
	local store = storeKey and Stores.registry[storeKey]
	if not cost or not store or not PlayerData.get(player) then
		return
	end
	if not near(player, part, Settings.ReachStuds) then
		return
	end
	local b = baskets[player]
	if b and b.store ~= storeKey then
		putBack(player, "You put back what you had in " .. (Stores.registry[b.store] and Stores.registry[b.store].name or "the other store"))
		b = nil
	end
	if not b then
		b = { id = HttpService:GenerateGUID(false), store = storeKey, items = {} }
		baskets[player] = b
	end
	if #b.items >= Settings.BasketMax then
		Notify.send(player, { title = "Your hands are full", body = "Pay at the till before picking up more.", category = "system" })
		return
	end
	table.insert(b.items, productId)
	push(player, "pickup", { product = productId, from = part.Position })
end

local function checkout(player, till)
	local storeKey = till:GetAttribute("Store")
	local b = baskets[player]
	if not b or #b.items == 0 then
		Notify.send(player, { title = "Nothing to pay for", body = "Pick something up first.", category = "system" })
		return
	end
	if b.store ~= storeKey then
		Notify.send(player, { title = "Wrong till", body = "Pay at the store you picked these up in.", category = "system" })
		return
	end
	if not near(player, till, Settings.ReachStuds + 4) then
		return
	end
	local store = Stores.registry[storeKey]
	local s = summary(player)
	local ok, result = Economy.charge(player, s.total, "shopping", string.format("%s · %d item%s", store.name, #b.items, #b.items == 1 and "" or "s"), b.id)
	if not ok then
		if result == "insufficient" then
			Notify.send(player, { title = "Card declined", body = string.format("That's $%d; you don't have enough.", s.total), category = "bank" })
		end
		return
	end
	-- Into the inventory (a count per product, the last InventoryMax kept).
	local data = PlayerData.get(player)
	local inv = data.inventory.items
	local onlyTreats = true
	for _, id in ipairs(b.items) do
		local p = Products.get(id)
		if p.kind ~= "treat" then
			onlyTreats = false
			local entry = inv[id]
			if type(entry) ~= "table" then
				entry = { n = 0 }
				inv[id] = entry
			end
			entry.n += 1
			entry.t = os.time()
			entry.from = store.name
		end
	end
	local count = 0
	for _ in pairs(inv) do
		count += 1
	end
	while count > Settings.InventoryMax do
		local oldest, oldestT = nil, math.huge
		for id, e in pairs(inv) do
			if type(e) == "table" and (e.t or 0) < oldestT then
				oldest, oldestT = id, e.t or 0
			end
		end
		if not oldest then
			break
		end
		inv[oldest] = nil
		count -= 1
	end
	baskets[player] = nil
	push(player, "paid", { total = s.total, items = s.items, store = store.name, colour = store.colour, at = till.Position })
	-- What you walk out with.
	if onlyTreats then
		local p = Products.get(s.items[1].id)
		hold(player, treatModel(p and p.colour), Settings.TreatSeconds)
	else
		hold(player, bagModel(store.colour, store.name), Settings.BagSeconds)
	end
end

---------------------------------------------------------------------------
-- Prompts on the tagged parts
---------------------------------------------------------------------------
local function addProductPrompt(part)
	if not part:IsA("BasePart") or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local p = Products.get(part:GetAttribute("Product"))
	local cost = price(part:GetAttribute("Product"))
	if not p or not cost then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = string.format("%s · $%d", p.name, cost)
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		pickUp(player, part)
	end)
end

local function addTillPrompt(part)
	if not part:IsA("BasePart") or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local store = Stores.registry[part:GetAttribute("Store")]
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pay"
	prompt.ObjectText = store and store.name or "Till"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		checkout(player, part)
	end)
end

function Shopping.start()
	for _, part in ipairs(CollectionService:GetTagged("ShopProduct")) do
		addProductPrompt(part)
	end
	for _, part in ipairs(CollectionService:GetTagged("ShopTill")) do
		addTillPrompt(part)
	end
	CollectionService:GetInstanceAddedSignal("ShopProduct"):Connect(addProductPrompt)
	CollectionService:GetInstanceAddedSignal("ShopTill"):Connect(addTillPrompt)
	print(string.format("[Shopping] %d items on display, %d tills", #CollectionService:GetTagged("ShopProduct"), #CollectionService:GetTagged("ShopTill")))

	-- Walk out without paying and the basket is put back.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, b in pairs(baskets) do
				local store = Stores.registry[b.store]
				local r = root(player)
				if not player.Parent then
					baskets[player] = nil
				elseif store and r and (r.Position - store.centre).Magnitude > store.radius + Settings.LeaveStuds then
					putBack(player, "You left " .. store.name .. " without paying, so your basket was put back.")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		baskets[player] = nil
	end)

	Router.on("shop.basket", function(player)
		return summary(player)
	end)
	Router.on("shop.putBack", function(player)
		putBack(player, "You put everything back.")
		return { done = true }
	end)
	Router.on("inventory.get", function(player)
		local data = PlayerData.get(player)
		local list = {}
		for id, e in pairs(data.inventory.items) do
			local p = Products.get(id)
			if p and type(e) == "table" then
				table.insert(list, { id = id, name = p.name, n = e.n, from = e.from, t = e.t })
			end
		end
		table.sort(list, function(a, b)
			return (a.t or 0) > (b.t or 0)
		end)
		return { items = list }
	end)
end

return Shopping
