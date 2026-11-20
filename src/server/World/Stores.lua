-- Ground-floor shops. Most are facades (lit display window, awning, sign); some are
-- real interiors you can walk into and buy things at the counter.

local Util = require(script.Parent.Util)
local Remotes = require(script.Parent.Parent.Remotes)
local Economy = require(script.Parent.Parent.Services.Economy)

local Stores = {}
Stores.count = 0

local V3 = Vector3.new
local M = Enum.Material

local AWNINGS = {
	Color3.fromRGB(28, 58, 40),
	Color3.fromRGB(96, 24, 28),
	Color3.fromRGB(24, 32, 60),
	Color3.fromRGB(26, 26, 28),
	Color3.fromRGB(150, 40, 30),
	Color3.fromRGB(90, 70, 40),
}

local FACADE_NAMES = {
	"LAUNDROMAT", "NAIL SALON", "HARDWARE", "BARBER", "CHINESE TAKEOUT", "WINE & LIQUOR",
	"SHOE REPAIR", "CELL PHONES", "BAGELS", "FLOWERS", "DRY CLEANERS", "CHECK CASHING",
	"TATTOO", "DINER", "BOOKS", "OPTICIAN", "THAI KITCHEN", "PAWN SHOP", "HALAL GRILL",
	"DELI", "SUSHI", "TOYS", "VINTAGE", "LOCKSMITH", "DENTIST", "REAL ESTATE",
}

-- Enterable store types: what they sell and how the room is furnished.
local STORE_TYPES = {
	{ kind = "bodega", names = { "CORNER DELI & GROCERY", "24 HR DELI", "MINI MART" }, item = "Sandwich", price = 12, effect = "heal", light = Color3.fromRGB(235, 245, 255) },
	{ kind = "pizza", names = { "GINO'S SLICE", "FAMOUS ORIGINAL PIZZA", "BROOKLYN PIE" }, item = "Pizza slice", price = 4, effect = "heal", light = Color3.fromRGB(255, 220, 170) },
	{ kind = "coffee", names = { "BEAN STREET COFFEE", "MORNING CUP", "BREW & CO." }, item = "Coffee", price = 5, effect = "speed", light = Color3.fromRGB(255, 214, 160) },
	{ kind = "clothes", names = { "CANAL THREADS", "UPTOWN APPAREL", "METRO WEAR" }, item = "New outfit", price = 60, effect = "outfit", light = Color3.fromRGB(255, 240, 225) },
	{ kind = "electronics", names = { "VOLT ELECTRONICS", "BYTE SHOP", "TECH HUB" }, item = "Phone", price = 120, effect = "phone", light = Color3.fromRGB(225, 235, 255) },
	{ kind = "pharmacy", names = { "CITY PHARMACY", "RX PLUS", "NEIGHBORHOOD DRUGS" }, item = "First aid kit", price = 25, effect = "heal", light = Color3.fromRGB(240, 250, 255) },
	{ kind = "bank", names = { "FIRST METRO BANK", "LIBERTY SAVINGS" }, item = "Banking", price = 0, effect = "bank", light = Color3.fromRGB(255, 236, 205) },
	{ kind = "bar", names = { "THE BRASS RAIL", "NIGHT OWL TAVERN", "O'MALLEY'S" }, item = "Soda", price = 3, effect = "heal", light = Color3.fromRGB(255, 190, 120) },
}

local function applyEffect(player, storeType)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, nil
	end
	local effect = storeType.effect
	if effect == "heal" then
		humanoid.Health = humanoid.MaxHealth
		return true, "Health restored"
	elseif effect == "speed" then
		humanoid.WalkSpeed = 24
		task.delay(30, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = 16
			end
		end)
		return true, "Caffeine rush: faster for 30s"
	elseif effect == "outfit" then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
				item:Destroy()
			end
		end
		local colors = character:FindFirstChildOfClass("BodyColors")
		if colors then
			local top = Color3.fromHSV(math.random(), 0.45, 0.55)
			local bottom = Color3.fromHSV(math.random(), 0.3, 0.3)
			colors.TorsoColor3 = top
			colors.LeftArmColor3 = top
			colors.RightArmColor3 = top
			colors.LeftLegColor3 = bottom
			colors.RightLegColor3 = bottom
		end
		return true, "New outfit"
	elseif effect == "phone" then
		if player.Backpack:FindFirstChild("Phone") or character:FindFirstChild("Phone") then
			return false, "You already have a phone"
		end
		local tool = Instance.new("Tool")
		tool.Name = "Phone"
		tool.CanBeDropped = false
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = V3(0.4, 0.8, 0.1)
		handle.Color = Color3.fromRGB(20, 20, 22)
		handle.Material = M.Glass
		handle.Parent = tool
		tool.Parent = player.Backpack
		return true, "Bought a phone"
	elseif effect == "bank" then
		-- Bank branches open the Bank app on the phone.
		Remotes.Push:FireClient(player, { type = "open", app = "bank" })
		return true, "Opened your bank on your phone"
	end
	return false, nil
end

local function onPurchase(player, storeType, storeName)
	if storeType.price > 0 and not Economy.canAfford(player, storeType.price) then
		Remotes.notify(player, "Not enough money")
		return
	end
	local ok, message = applyEffect(player, storeType)
	if ok then
		if storeType.price > 0 then
			Economy.charge(player, storeType.price, "shopping", storeName .. " · " .. storeType.item)
		end
		local cost = storeType.price > 0 and (" (-$" .. storeType.price .. ")") or ""
		Remotes.notify(player, storeName .. ": " .. (message or storeType.item) .. cost)
	elseif message then
		Remotes.notify(player, message)
	end
end

-- Puts a purchase prompt for a store type ("bodega", "coffee", ...) on a part,
-- using the same prices and effects as every other shop.
function Stores.attachPurchase(part, kind, storeName)
	for _, storeType in ipairs(STORE_TYPES) do
		if storeType.kind == kind then
			local prompt = Instance.new("ProximityPrompt")
			if storeType.price > 0 then
				prompt.ActionText = string.format("Buy %s ($%d)", storeType.item, storeType.price)
			else
				prompt.ActionText = "Collect " .. storeType.item
			end
			prompt.ObjectText = storeName
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(player)
				onPurchase(player, storeType, storeName)
			end)
			Stores.count = Stores.count + 1
			return prompt
		end
	end
	return nil
end

-- Sign board above the shop with the store name.
local function signBoard(folder, cf, width, name, rng)
	local board = Util.deco(folder, V3(width, 2.6, 0.4), cf, Util.pick(rng, AWNINGS), M.SmoothPlastic)
	Util.sign(board, Enum.NormalId.Front, name, Color3.fromRGB(245, 236, 210), Util.pick(rng, { Enum.Font.GothamBold, Enum.Font.Oswald, Enum.Font.Merriweather }))
	return board
end

local function awning(folder, cf, width, rng)
	-- Tilted so its outer edge hangs lower.
	Util.deco(folder, V3(width, 0.3, 4), cf * CFrame.Angles(math.rad(-18), 0, 0), Util.pick(rng, AWNINGS), M.Fabric)
end

-- Non-enterable shopfront on a building whose front face is at local z = -d/2.
function Stores.facade(folder, base, w, d, groundH, rng)
	local fz = -d / 2
	local glassH = groundH - 5.5
	-- Warm interior glow seen through the window.
	local glow = Util.deco(folder, V3(w - 5, glassH, 0.2), base * CFrame.new(0, 1 + glassH / 2, fz - 0.12), Color3.fromRGB(196, 160, 112), M.SmoothPlastic)
	if rng:NextNumber() < 0.45 then
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Range = 10
		light.Brightness = 0.8
		light.Color = Color3.fromRGB(255, 214, 160)
		light.Parent = glow
	end
	local glass = Util.deco(folder, V3(w - 4, glassH, 0.3), base * CFrame.new(0, 1 + glassH / 2, fz - 0.4), Color3.fromRGB(150, 165, 170), M.Glass)
	glass.Transparency = 0.45
	glass.Reflectance = 0.2
	Util.deco(folder, V3(w - 2, 1, 0.6), base * CFrame.new(0, 0.5, fz - 0.3), Color3.fromRGB(40, 38, 36), M.Metal) -- base rail
	Util.deco(folder, V3(3.6, 8, 0.4), base * CFrame.new(w / 2 - 4, 4, fz - 0.55), Color3.fromRGB(30, 30, 32), M.Metal) -- door
	awning(folder, base * CFrame.new(0, groundH - 4.4, fz - 2), w - 2, rng)
	signBoard(folder, base * CFrame.new(0, groundH - 1.6, fz - 0.45), w - 5, Util.pick(rng, FACADE_NAMES), rng)
end

-- Furniture helpers (local coordinates inside the shop; floor top at y = 0.4).
local function furnish(folder, base, w, d, storeType, rng)
	local function put(size, x, y, z, color, material)
		return Util.solid(folder, size, base * CFrame.new(x, y, z), color, material)
	end
	local function decor(size, x, y, z, color, material)
		return Util.deco(folder, size, base * CFrame.new(x, y, z), color, material)
	end
	local backZ = d / 2 - 1
	local wood = Color3.fromRGB(96, 64, 40)
	local counterZ = backZ - 4
	local counterW = math.min(w - 8, 14)

	-- Counter with register, where you buy things.
	local counter = put(V3(counterW, 3.6, 2.6), 0, 0.4 + 1.8, counterZ, storeType.kind == "bank" and Color3.fromRGB(70, 52, 40) or wood, M.Wood)
	decor(V3(counterW + 0.4, 0.2, 2.9), 0, 4.3, counterZ, Color3.fromRGB(40, 38, 36), M.Granite)
	decor(V3(1.6, 1.2, 1.3), counterW / 2 - 1.5, 5, counterZ, Color3.fromRGB(30, 30, 32), M.Metal)

	local kind = storeType.kind
	local productColors = {
		Color3.fromRGB(196, 52, 40), Color3.fromRGB(230, 190, 60), Color3.fromRGB(40, 110, 170),
		Color3.fromRGB(60, 150, 70), Color3.fromRGB(230, 230, 220), Color3.fromRGB(210, 110, 40),
	}

	if kind == "bodega" or kind == "pharmacy" then
		for _, side in ipairs({ -1, 1 }) do
			local x = side * (w / 2 - 2.2)
			local len = d * 0.55
			put(V3(2.2, 7, len), x, 0.4 + 3.5, -1, Color3.fromRGB(200, 200, 196), M.Metal)
			for level = 0, 2 do
				decor(V3(0.8, 1.3, len - 1), x - side * 1.3, 1.6 + level * 2.2, -1, Util.pick(rng, productColors), M.SmoothPlastic)
			end
		end
		local fridge = put(V3(math.min(8, w * 0.3), 8, 2), -w / 2 + 6, 0.4 + 4, backZ - 1, Color3.fromRGB(210, 210, 210), M.Metal)
		local inner = decor(V3(fridge.Size.X - 1, 6.5, 0.2), -w / 2 + 6, 4.6, backZ - 2.1, Color3.fromRGB(220, 240, 255), M.Neon)
		inner.Transparency = 0.4
		if kind == "pharmacy" then
			local cross = decor(V3(3, 3, 0.3), 0, 9.5, backZ - 0.4, Color3.fromRGB(40, 180, 90), M.Neon)
			Util.sign(cross, Enum.NormalId.Front, "+", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
		end
	elseif kind == "pizza" or kind == "coffee" then
		if kind == "pizza" then
			put(V3(7, 5.5, 4), w / 2 - 5, 0.4 + 2.75, backZ - 2, Color3.fromRGB(120, 60, 45), M.Brick)
			decor(V3(3.5, 1.6, 0.3), w / 2 - 5, 3, backZ - 4.1, Color3.fromRGB(255, 120, 30), M.Neon)
		else
			decor(V3(2, 2.2, 1.6), -counterW / 2 + 2, 5.4, counterZ, Color3.fromRGB(170, 170, 175), M.Metal)
		end
		for i = 1, 3 do
			local x = -w / 2 + 4 + (i - 1) * ((w - 8) / 2)
			local z = -d / 2 + 6 + (i % 2) * 3
			Util.cylinder(folder, 0.3, 4, base * CFrame.new(x, 3.2, z), Color3.fromRGB(230, 225, 215), M.Marble, true)
			Util.cylinder(folder, 2.8, 0.4, base * CFrame.new(x, 1.8, z), Color3.fromRGB(30, 30, 30), M.Metal, false)
			for _, off in ipairs({ -2.6, 2.6 }) do
				put(V3(1.6, 2.2, 1.6), x + off, 0.4 + 1.1, z, Color3.fromRGB(60, 40, 30), M.Wood)
			end
		end
	elseif kind == "clothes" then
		for i = -1, 1, 2 do
			local x = i * (w / 4)
			decor(V3(0.3, 0.3, d * 0.45), x, 6, -2, Color3.fromRGB(180, 180, 185), M.Metal)
			put(V3(0.3, 6, 0.3), x, 3.4, -2 - d * 0.22, Color3.fromRGB(180, 180, 185), M.Metal)
			put(V3(0.3, 6, 0.3), x, 3.4, -2 + d * 0.22, Color3.fromRGB(180, 180, 185), M.Metal)
			decor(V3(1.4, 3.2, d * 0.4), x, 4.2, -2, Util.pick(rng, productColors), M.Fabric)
		end
		local mirror = decor(V3(4, 8, 0.2), -w / 2 + 1.2, 4.4, backZ - 6, Color3.fromRGB(200, 205, 210), M.Glass)
		mirror.Reflectance = 0.85
		mirror.CFrame = mirror.CFrame * CFrame.Angles(0, math.rad(90), 0)
	elseif kind == "electronics" then
		for i = -1, 1 do
			decor(V3(5, 3, 0.3), i * 6, 8, backZ - 0.3, Color3.fromRGB(30, 60, 120), M.Neon)
		end
		put(V3(w * 0.4, 3, 5), 0, 0.4 + 1.5, -d / 2 + 8, Color3.fromRGB(230, 230, 230), M.SmoothPlastic)
		for i = -1, 1 do
			decor(V3(1.6, 1, 0.2), i * 2.5, 3.6, -d / 2 + 8, Color3.fromRGB(20, 20, 25), M.Glass)
		end
	elseif kind == "bank" then
		local partition = decor(V3(counterW, 4, 0.2), 0, 6.6, counterZ - 1, Color3.fromRGB(200, 220, 230), M.Glass)
		partition.Transparency = 0.6
		Util.cylinder(folder, 1, 7, base * CFrame.new(w / 2 - 6, 4.5, backZ - 0.4) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(150, 150, 155), M.DiamondPlate, false)
		put(V3(1.4, 3.5, 1.4), -w / 2 + 3, 0.4 + 1.75, -d / 2 + 4, Color3.fromRGB(150, 120, 60), M.Metal)
	elseif kind == "bar" then
		decor(V3(counterW, 6, 0.6), 0, 5.2, backZ - 0.3, Color3.fromRGB(70, 46, 30), M.Wood)
		for i = 1, 8 do
			local bottle = decor(V3(0.4, 1.1, 0.4), -counterW / 2 + i * counterW / 9, 6.2 + (i % 2) * 1.6, backZ - 0.8, Util.pick(rng, productColors), M.Glass)
			bottle.Transparency = 0.2
		end
		for i = -2, 2 do
			Util.cylinder(folder, 3, 1.4, base * CFrame.new(i * 2.6, 1.9, counterZ - 2.4), Color3.fromRGB(110, 30, 30), M.Leather, true)
		end
	end

	return counter
end

-- Enterable shop: hollow ground floor with walls, glass front, door gap and furniture.
-- kinds (optional): list of store kinds to choose from, e.g. { "bar", "coffee" }.
function Stores.interior(folder, base, w, d, groundH, rng, kinds)
	local choices = STORE_TYPES
	if kinds then
		choices = {}
		for _, storeType in ipairs(STORE_TYPES) do
			if table.find(kinds, storeType.kind) then
				table.insert(choices, storeType)
			end
		end
		if #choices == 0 then
			choices = STORE_TYPES
		end
	end
	local storeType = Util.pick(rng, choices)
	local storeName = Util.pick(rng, storeType.names)
	local fz = -d / 2
	local wallColor = Util.pick(rng, { Color3.fromRGB(226, 220, 205), Color3.fromRGB(205, 196, 180), Color3.fromRGB(180, 170, 155) })
	local floorMaterial = Util.pick(rng, { M.CeramicTiles, M.WoodPlanks, M.Marble })
	local floorColor = floorMaterial == M.WoodPlanks and Color3.fromRGB(120, 86, 56) or Color3.fromRGB(205, 200, 192)

	Util.solid(folder, V3(w, 0.4, d), base * CFrame.new(0, 0.2, 0), floorColor, floorMaterial)
	Util.solid(folder, V3(w, groundH, 1), base * CFrame.new(0, groundH / 2, d / 2 - 0.5), wallColor, M.Plaster)
	Util.solid(folder, V3(1, groundH, d), base * CFrame.new(-w / 2 + 0.5, groundH / 2, 0), wallColor, M.Plaster)
	Util.solid(folder, V3(1, groundH, d), base * CFrame.new(w / 2 - 0.5, groundH / 2, 0), wallColor, M.Plaster)

	-- Front: header beam over a glass shopfront with a doorway in the middle.
	local doorW, doorH = 7, 10
	Util.solid(folder, V3(w, groundH - doorH, 1), base * CFrame.new(0, doorH + (groundH - doorH) / 2, fz + 0.5), Color3.fromRGB(36, 34, 32), M.Metal)
	local paneW = (w - doorW) / 2
	for _, side in ipairs({ -1, 1 }) do
		local pane = Util.solid(folder, V3(paneW, doorH, 0.4), base * CFrame.new(side * (doorW / 2 + paneW / 2), doorH / 2, fz + 0.5), Color3.fromRGB(170, 185, 190), M.Glass)
		pane.Transparency = 0.6
		pane.Reflectance = 0.15
		Util.deco(folder, V3(0.5, doorH, 0.6), base * CFrame.new(side * doorW / 2, doorH / 2, fz + 0.5), Color3.fromRGB(36, 34, 32), M.Metal)
	end
	local open = Util.deco(folder, V3(3, 1.1, 0.15), base * CFrame.new(-doorW / 2 - 2.5, 7, fz + 0.85), Color3.fromRGB(255, 60, 60), M.Neon)
	Util.sign(open, Enum.NormalId.Front, "OPEN", Color3.fromRGB(255, 240, 240), Enum.Font.GothamBold)

	-- Ceiling and light.
	local ceiling = Util.deco(folder, V3(w - 2, 0.4, d - 2), base * CFrame.new(0, groundH - 0.25, 0), Color3.fromRGB(235, 232, 225), M.SmoothPlastic)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 18
	light.Angle = 120
	light.Brightness = 1.6
	light.Color = storeType.light
	light.Parent = ceiling
	local fill = Instance.new("PointLight")
	fill.Range = 16
	fill.Brightness = 0.8
	fill.Color = storeType.light
	fill.Parent = ceiling

	local counter = furnish(folder, base, w, d, storeType, rng)
	local prompt = Instance.new("ProximityPrompt")
	if storeType.price > 0 then
		prompt.ActionText = string.format("Buy %s ($%d)", storeType.item, storeType.price)
	else
		prompt.ActionText = "Collect " .. storeType.item
	end
	prompt.ObjectText = storeName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(function(player)
		onPurchase(player, storeType, storeName)
	end)

	-- Outside: sign and a short awning over the door.
	signBoard(folder, base * CFrame.new(0, groundH - 2, fz - 0.3), w - 4, storeName, rng)
	awning(folder, base * CFrame.new(0, doorH + 0.6, fz - 2), doorW + 4, rng)

	Stores.count = Stores.count + 1
end

return Stores
