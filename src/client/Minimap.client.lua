-- GTA-style minimap in the bottom-left corner: zoomed in, centred on you, north
-- up. Shows land, water, parks, every building's footprint, roads (Yonge in gold,
-- highways in orange), street names along the roads, landmark icons, subway
-- stations and other players. Your arrow turns with your character; the street
-- you're on is shown underneath. Press M (or tap MAP) for a big zoomed-out map.
--
-- Drawn once from the data the server publishes (MinimapData + MinimapBuildings).
-- Detail is split into square chunks and only the chunks round you are shown, so
-- moving the map each frame stays cheap.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local data = HttpService:JSONDecode(ReplicatedStorage:WaitForChild("MinimapData").Value)
local buildingFolder = ReplicatedStorage:WaitForChild("MinimapBuildings")

local K = 0.34 -- pixels per stud on the minimap
local BIG_SCALE = 0.19 -- the big map is this much further out
local SMALL_SIZE = 240
local CHUNK = 400 -- studs per detail chunk
local PIECE = 160 -- long road segments are cut into pieces this long

local C = Color3.fromRGB
local WATER = C(38, 66, 92)
local LAND = C(62, 64, 66)
local PARK = C(64, 102, 60)
local BUILDING = C(98, 100, 104)
local MAIN_ROAD = C(206, 206, 200)
local MINOR_ROAD = C(150, 150, 146)
local YONGE = C(232, 200, 110)
local HIGHWAY = C(232, 166, 60)
local MAIN_KINDS = { arterial = true, avenue = true, boulevard = true, broadway = true, waterfront = true, bridge = true }
local PLACE = { mall = C(196, 150, 100), square = C(214, 192, 110), civic = C(150, 150, 184), school = C(120, 146, 196) }
local ICON = { mall = "🛍", square = "🎪", civic = "🏛", school = "🎓" }

---------------------------------------------------------------------------
-- Frame and layers
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Minimap"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0, 1)
holder.Position = UDim2.new(0, 20, 1, -44)
holder.Size = UDim2.fromOffset(SMALL_SIZE, SMALL_SIZE)
holder.BackgroundColor3 = WATER
holder.ClipsDescendants = true
holder.Parent = gui
Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 12)
local border = Instance.new("UIStroke")
border.Thickness = 3
border.Color = C(16, 16, 18)
border.Parent = holder

local function layer(name, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(0, 0)
	f.ZIndex = z
	f.Parent = holder
	return f
end
-- The map itself (scaled down for the big map), and two text layers that are not
-- scaled so text stays readable: one for the minimap, one for the big map.
local world = layer("World", 1)
local scale = Instance.new("UIScale")
scale.Parent = world
local smallText = layer("SmallText", 10)
local bigText = layer("BigText", 11)
bigText.Visible = false

-- Detail chunks: a zero-size frame per chunk per layer; only nearby ones are shown.
local chunks = {} -- key -> { frames }
local function chunkOf(parent, x, z, tag)
	local cx, cz = math.floor(x / CHUNK), math.floor(z / CHUNK)
	local key = tag .. cx .. "," .. cz
	local entry = chunks[key]
	if not entry then
		local f = Instance.new("Frame")
		f.Name = key
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(0, 0)
		f.Visible = false
		f.ZIndex = tag == "b" and 2 or 3 -- buildings under roads
		f.Parent = parent
		entry = { frame = f, cx = cx, cz = cz, tag = tag }
		chunks[key] = entry
	end
	return entry.frame
end

local function rect(parent, x0, z0, x1, z1, colour, k)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Position = UDim2.fromOffset(x0 * k, z0 * k)
	f.Size = UDim2.fromOffset((x1 - x0) * k, (z1 - z0) * k)
	f.Parent = parent
	return f
end

local function bar(parent, ax, az, bx, bz, w, colour)
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.5 then
		return
	end
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((ax + bx) / 2 * K, (az + bz) / 2 * K)
	f.Size = UDim2.fromOffset(len * K + w * K * 0.9, math.max(2, w * K))
	f.Rotation = math.deg(math.atan2(dz, dx))
	f.Parent = parent
end

-- Text that reads left to right (never upside down), rotated to `angle` degrees.
local function text(parent, str, x, z, k, size, colour, angle, font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromOffset(x * k, z * k)
	t.Size = UDim2.fromOffset(220, size + 4)
	t.Font = font or Enum.Font.GothamBold
	t.TextSize = size
	t.TextColor3 = colour or C(255, 255, 255)
	t.TextStrokeTransparency = 0.25
	t.TextStrokeColor3 = C(10, 10, 12)
	angle = angle or 0
	if angle > 90 then
		angle = angle - 180
	elseif angle < -90 then
		angle = angle + 180
	end
	t.Rotation = angle
	t.Text = str
	t.Parent = parent
	return t
end

---------------------------------------------------------------------------
-- Draw the city once
---------------------------------------------------------------------------
for _, b in ipairs(data.land) do
	rect(world, b[1], b[2], b[3], b[4], LAND, K)
end
for _, b in ipairs(data.parks) do
	rect(world, b[1], b[2], b[3], b[4], PARK, K)
end

-- Buildings (minimap only).
for i = 1, buildingFolder:GetAttribute("Parts") or 0 do
	local list = HttpService:JSONDecode(buildingFolder:WaitForChild("Part" .. i).Value)
	for j = 1, #list, 5 do
		local x, z, w, d, a = list[j], list[j + 1], list[j + 2], list[j + 3], list[j + 4]
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = BUILDING
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x * K, z * K)
		f.Size = UDim2.fromOffset(math.max(2, (w - 3) * K), math.max(2, (d - 3) * K))
		f.Rotation = a - 90
		f.Parent = chunkOf(world, x, z, "b")
	end
end

-- Roads and highways, cut into pieces so each lands in the chunk it's in. Street
-- names repeat along each named road: often on the minimap, rarely on the big map.
local function drawLine(points, w, colour, name, isMain)
	local sinceSmall, sinceBig = 120, 700
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local n = math.max(1, math.ceil(len / PIECE))
		local angle = math.deg(math.atan2(dz, dx))
		for k = 0, n - 1 do
			local t0, t1 = k / n, (k + 1) / n
			local ax, az = a[1] + dx * t0, a[2] + dz * t0
			local bx, bz = a[1] + dx * t1, a[2] + dz * t1
			local mx, mz = (ax + bx) / 2, (az + bz) / 2
			-- Big-map roads stay visible everywhere; they go in the "r" chunks.
			bar(chunkOf(world, mx, mz, "r"), ax, az, bx, bz, w, colour)
			if name then
				local step = len / n
				sinceSmall = sinceSmall + step
				sinceBig = sinceBig + step
				if sinceSmall >= 240 then
					sinceSmall = 0
					text(chunkOf(smallText, mx, mz, "s"), name, mx, mz, K, isMain and 12 or 11, C(255, 255, 255), angle)
				end
				if isMain and sinceBig >= 1300 then
					sinceBig = 0
					text(bigText, name, mx, mz, K * BIG_SCALE, 12, C(240, 240, 236), angle)
				end
			end
		end
	end
end
for _, road in ipairs(data.roads) do
	local named = nil
	if road.n and not road.n:find("^Side St") and not road.n:find("Bridge") then
		named = road.n
	end
	local isYonge = road.k == "yonge" or road.k == "yongeNorth"
	local colour = isYonge and YONGE or (MAIN_KINDS[road.k] and MAIN_ROAD or MINOR_ROAD)
	drawLine(road.p, road.w, colour, named, isYonge or MAIN_KINDS[road.k] or false)
end
local HIGHWAY_NAMES = { Highway401 = "HIGHWAY 401", Expressway = "ALLEN RD · EXPRESSWAY", HarborFreeway = "HARBOR FWY", SuspensionBridge = "VICE BRIDGE" }
for _, hw in ipairs(data.highways) do
	drawLine(hw.p, hw.w * 0.8, HIGHWAY, HIGHWAY_NAMES[hw.n], true)
end

-- Landmarks: footprint, icon and name.
for _, p in ipairs(data.places) do
	local r = p[2]
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local f = rect(chunkOf(world, cx, cz, "r"), r[1], r[2], r[3], r[4], PLACE[p[3]] or PLACE.civic, K)
	f.ZIndex = 2
	text(chunkOf(smallText, cx, cz, "s"), (ICON[p[3]] or "★") .. " " .. p[1], cx, cz, K, 13, C(255, 236, 190), 0, Enum.Font.GothamBlack)
	text(bigText, (ICON[p[3]] or "★") .. " " .. p[1], cx, cz, K * BIG_SCALE, 12, C(255, 236, 190), 0, Enum.Font.GothamBlack)
end

-- Subway stations: a red dot on both maps, the name beside it.
for _, s in ipairs(data.stations) do
	for _, info in ipairs({ { world, K, 13 }, { bigText, K * BIG_SCALE, 10 } }) do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(s[2] * info[2], s[3] * info[2])
		dot.Size = UDim2.fromOffset(info[3], info[3])
		dot.BackgroundColor3 = C(206, 30, 40)
		dot.ZIndex = 8
		dot.Parent = info[1]
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		local ring = Instance.new("UIStroke")
		ring.Color = C(255, 255, 255)
		ring.Thickness = 2
		ring.Parent = dot
	end
	local small = text(chunkOf(smallText, s[2], s[3], "s"), "🚇 " .. s[1], s[2], s[3], K, 12, C(255, 210, 210), 0, Enum.Font.GothamBlack)
	small.AnchorPoint = Vector2.new(0, 0.5)
	small.TextXAlignment = Enum.TextXAlignment.Left
	small.Position = UDim2.fromOffset(s[2] * K + 10, s[3] * K)
	local big = text(bigText, s[1], s[2], s[3], K * BIG_SCALE, 11, C(255, 210, 210), 0, Enum.Font.GothamBlack)
	big.AnchorPoint = Vector2.new(0, 0.5)
	big.TextXAlignment = Enum.TextXAlignment.Left
	big.Position = UDim2.fromOffset(s[2] * K * BIG_SCALE + 8, s[3] * K * BIG_SCALE)
end

---------------------------------------------------------------------------
-- You, north, the street name, the MAP button
---------------------------------------------------------------------------
local arrow = Instance.new("TextLabel")
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.fromScale(0.5, 0.5)
arrow.Size = UDim2.fromOffset(24, 24)
arrow.BackgroundTransparency = 1
arrow.Font = Enum.Font.GothamBlack
arrow.TextSize = 24
arrow.TextColor3 = C(255, 255, 255)
arrow.TextStrokeTransparency = 0
arrow.Text = "▲"
arrow.ZIndex = 30
arrow.Parent = holder

local north = Instance.new("TextLabel")
north.AnchorPoint = Vector2.new(0.5, 0)
north.Position = UDim2.new(0.5, 0, 0, 4)
north.Size = UDim2.fromOffset(20, 20)
north.BackgroundColor3 = C(16, 16, 18)
north.Font = Enum.Font.GothamBlack
north.TextSize = 13
north.TextColor3 = C(255, 255, 255)
north.Text = "N"
north.ZIndex = 30
north.Parent = holder
Instance.new("UICorner", north).CornerRadius = UDim.new(1, 0)

local street = Instance.new("TextLabel")
street.Position = UDim2.new(0, 20, 1, -40)
street.Size = UDim2.fromOffset(SMALL_SIZE + 60, 24)
street.BackgroundTransparency = 1
street.Font = Enum.Font.GothamBold
street.TextSize = 16
street.TextColor3 = C(255, 255, 255)
street.TextStrokeTransparency = 0.2
street.TextXAlignment = Enum.TextXAlignment.Left
street.Text = ""
street.Parent = gui

local toggle = Instance.new("TextButton")
toggle.AnchorPoint = Vector2.new(0, 1)
toggle.Position = UDim2.new(0, 20 + SMALL_SIZE + 8, 1, -44)
toggle.Size = UDim2.fromOffset(44, 28)
toggle.BackgroundColor3 = C(16, 16, 18)
toggle.Font = Enum.Font.GothamBlack
toggle.TextSize = 13
toggle.TextColor3 = C(255, 255, 255)
toggle.Text = "MAP"
toggle.Parent = gui
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

gui.Parent = player:WaitForChild("PlayerGui")

-- Other players.
local dots = {}
local function dotFor(other)
	local d = dots[other]
	if not d then
		d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromOffset(9, 9)
		d.BackgroundColor3 = C(90, 200, 255)
		d.ZIndex = 25
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
		d.Parent = holder
		dots[other] = d
	end
	return d
end
Players.PlayerRemoving:Connect(function(other)
	if dots[other] then
		dots[other]:Destroy()
		dots[other] = nil
	end
end)

---------------------------------------------------------------------------
-- Which chunks to show
---------------------------------------------------------------------------
local big = false
local function refreshChunks(p)
	local pcx, pcz = math.floor(p.X / CHUNK), math.floor(p.Z / CHUNK)
	for _, entry in pairs(chunks) do
		local near = math.abs(entry.cx - pcx) <= 1 and math.abs(entry.cz - pcz) <= 1
		if entry.tag == "r" then
			entry.frame.Visible = big or near
		elseif entry.tag == "b" or entry.tag == "s" then
			entry.frame.Visible = (not big) and near
		end
	end
end

local function setBig(on)
	big = on
	bigText.Visible = on
	smallText.Visible = not on
	scale.Scale = on and BIG_SCALE or 1
	if on then
		local screen = Workspace.CurrentCamera.ViewportSize
		local s = math.floor(math.min(screen.X, screen.Y) * 0.82)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromOffset(s, s)
	else
		holder.AnchorPoint = Vector2.new(0, 1)
		holder.Position = UDim2.new(0, 20, 1, -44)
		holder.Size = UDim2.fromOffset(SMALL_SIZE, SMALL_SIZE)
	end
	street.Visible = not on
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		refreshChunks(root.Position)
	end
end
toggle.Activated:Connect(function()
	setBig(not big)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		setBig(not big)
	end
end)

---------------------------------------------------------------------------
-- Street name: the nearest named road, a few times a second.
---------------------------------------------------------------------------
local segments = {}
for _, road in ipairs(data.roads) do
	if road.n and not road.n:find("^Side St") and not road.n:find("Bridge") then
		for i = 1, #road.p - 1 do
			table.insert(segments, { road.p[i], road.p[i + 1], road.w / 2 + 6, road.n })
		end
	end
end
for _, hw in ipairs(data.highways) do
	local name = HIGHWAY_NAMES[hw.n]
	if name then
		for i = 1, #hw.p - 1 do
			table.insert(segments, { hw.p[i], hw.p[i + 1], hw.w / 2 + 4, name })
		end
	end
end
local function streetAt(x, z)
	local best, bestD = nil, math.huge
	for _, s in ipairs(segments) do
		local ax, az, bx, bz = s[1][1], s[1][2], s[2][1], s[2][2]
		local dx, dz = bx - ax, bz - az
		local t = math.clamp(((x - ax) * dx + (z - az) * dz) / math.max(dx * dx + dz * dz, 1), 0, 1)
		local px, pz = ax + dx * t - x, az + dz * t - z
		local d = math.sqrt(px * px + pz * pz)
		if d < s[3] and d < bestD then
			best, bestD = s[4], d
		end
	end
	return best
end
task.spawn(function()
	while true do
		task.wait(0.4)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local p = root.Position
			refreshChunks(p)
			local name = streetAt(p.X, p.Z)
			if not name then
				if p.Z < -800 then
					name = "Toronto"
				elseif p.Z > 700 then
					name = "Port Lands"
				else
					name = "Downtown"
				end
			end
			street.Text = p.Y < -4 and "Underground · Line 1" or name
		end
	end
end)

---------------------------------------------------------------------------
-- Every frame: slide the map under you, turn your arrow, move other players.
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local p = root.Position
	local s = scale.Scale
	local pos = UDim2.new(0.5, -p.X * K * s, 0.5, -p.Z * K * s)
	world.Position = pos
	smallText.Position = pos
	bigText.Position = pos
	local look = root.CFrame.LookVector
	arrow.Rotation = math.deg(math.atan2(look.Z, look.X)) + 90
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local c = other.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r then
				local d = dotFor(other)
				d.Position = UDim2.new(0.5, (r.Position.X - p.X) * K * s, 0.5, (r.Position.Z - p.Z) * K * s)
				d.Visible = true
			elseif dots[other] then
				dots[other].Visible = false
			end
		end
	end
end)
