-- Advertising: rooftop billboards on mid-rise buildings and glowing LED screens on
-- the faces of taller ones, along the main roads. All brands are made up.
--
-- Called by Buildings.placeFrontage for each building it makes. Uses its own
-- random numbers (seeded from the lot position) so adding or changing ads never
-- changes the layout of the city itself.
local Workspace = game:GetService("Workspace")

local Util = require(script.Parent.Util)

local Billboards = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front
local C = Color3.fromRGB
local STEEL = C(48, 50, 54)

local MAX_ROOF, MAX_SCREENS = 70, 45
local roofCount, screenCount = 0, 0

-- { headline, tagline, background, text colour, accent }
local ADS = {
	{ "BLOXY COLA", "TASTE THE CITY", C(200, 24, 34), C(255, 255, 255), C(255, 214, 80) },
	{ "NOVA X", "THE PHONE THAT GETS YOU", C(18, 24, 48), C(120, 220, 255), C(255, 255, 255) },
	{ "CLUCK HOUSE", "24 PIECE BUCKET  $9.99", C(250, 196, 40), C(150, 30, 20), C(150, 30, 20) },
	{ "RADIO 6IX  99.1", "THE CITY'S HITS", C(110, 30, 160), C(255, 255, 255), C(255, 120, 220) },
	{ "MAPLE TRUST", "BANKING THAT GROWS", C(20, 110, 70), C(255, 255, 255), C(200, 240, 200) },
	{ "SUNSET TOWERS", "NOW LEASING · FROM $1,899", C(255, 140, 90), C(40, 20, 60), C(255, 255, 255) },
	{ "VELOCITY MOTORS", "0-60 IN 2.9", C(16, 16, 18), C(255, 70, 50), C(240, 240, 240) },
	{ "FROSTY'S", "SOFT SERVE · OPEN LATE", C(120, 210, 230), C(220, 30, 120), C(255, 255, 255) },
	{ "LIBERTY TAXI", "ONE TAP. ANYWHERE.", C(255, 210, 20), C(20, 20, 20), C(20, 20, 20) },
	{ "NEON NIGHTS", "LIVE  ·  FRI & SAT", C(30, 10, 40), C(255, 60, 200), C(80, 240, 255) },
	{ "GRIND COFFEE", "FUEL FOR THE COMMUTE", C(70, 44, 30), C(250, 230, 200), C(220, 160, 90) },
	{ "BLOX BET? NO.", "SAVE YOUR CASH · CITY CREDIT UNION", C(240, 240, 236), C(30, 60, 140), C(200, 30, 40) },
}

local function rngFor(center)
	return Random.new(math.floor(center.X * 7.31 + center.Y * 13.7) % 2147483647)
end

local function params(model)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { model }
	return p
end

-- Two lines of text that ignore lighting, so ads glow at night.
local function adFace(part, face, ad, emissive)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = emissive and 1.6 or 1.1
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = ad[3]
	bg.Parent = gui
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.fromScale(1, 0.06)
	stripe.Position = UDim2.fromScale(0, 0.86)
	stripe.BorderSizePixel = 0
	stripe.BackgroundColor3 = ad[5]
	stripe.Parent = bg
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.9, 0.5)
	title.Position = UDim2.fromScale(0.05, 0.1)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = ad[4]
	title.Text = ad[1]
	title.Parent = bg
	local tag = Instance.new("TextLabel")
	tag.BackgroundTransparency = 1
	tag.Size = UDim2.fromScale(0.9, 0.2)
	tag.Position = UDim2.fromScale(0.05, 0.62)
	tag.Font = Enum.Font.GothamBold
	tag.TextScaled = true
	tag.TextColor3 = ad[5]
	tag.Text = ad[2]
	tag.Parent = bg
	gui.Parent = part
	return gui
end

-- Rooftop billboard on two legs with a catwalk and lamps shining up onto it.
local function rooftop(model, cf, w, rng)
	local hit = Workspace:Raycast((cf * CFrame.new(0, 2000, 0)).Position, V3(0, -2100, 0), params(model))
	if not hit then
		return false
	end
	local roof = hit.Position.Y
	if roof > 110 then
		return false -- nobody would see it up there
	end
	local panelW = math.min(30, w - 4)
	local panelH = math.clamp(panelW * 0.42, 9, 13)
	for _, x in ipairs({ -panelW / 3, panelW / 3 }) do
		Util.deco(model, V3(0.8, 8, 0.8), cf * CFrame.new(x, roof + 4, 0), STEEL, M.Metal)
		Util.deco(model, V3(0.4, 8.4, 0.4), cf * CFrame.new(x, roof + 4, 2.4) * CFrame.Angles(math.rad(-16), 0, 0), STEEL, M.Metal)
	end
	local panelCF = cf * CFrame.new(0, roof + 8 + panelH / 2, 0)
	local panel = Util.solid(model, V3(panelW, panelH, 0.6), panelCF, C(240, 240, 240), M.SmoothPlastic)
	local roll = rng:NextNumber()
	if roll < 0.15 and Util.hasAsset("billboard_phone") then
		Util.decal(panel, Front, "billboard_phone")
	elseif roll < 0.3 and Util.hasAsset("billboard_burger") then
		Util.decal(panel, Front, "billboard_burger")
	else
		adFace(panel, Front, ADS[rng:NextInteger(1, #ADS)], false)
	end
	-- Back of the board: plain steel frame.
	Util.deco(model, V3(panelW + 0.4, panelH + 0.4, 0.3), panelCF * CFrame.new(0, 0, 0.45), STEEL, M.DiamondPlate)
	Util.deco(model, V3(panelW, 0.3, 2), panelCF * CFrame.new(0, -panelH / 2 - 0.2, -1), STEEL, M.DiamondPlate)
	for _, x in ipairs({ -panelW / 3, 0, panelW / 3 }) do
		local lamp = Util.deco(model, V3(0.8, 0.5, 0.8), panelCF * CFrame.new(x, -panelH / 2 - 0.1, -1.8), C(255, 240, 210), M.Neon)
		lamp.CastShadow = false
		if x == 0 then
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Top
			light.Range = 18
			light.Angle = 90
			light.Brightness = 1.4
			light.Parent = lamp
		end
	end
	return true
end

-- LED screen fixed to the facade facing the road, with a neon frame and a glow
-- that spills onto the street.
local function screen(model, cf, w, depth, rng)
	local hit = Workspace:Raycast((cf * CFrame.new(0, 2000, 0)).Position, V3(0, -2100, 0), params(model))
	if not hit then
		return false
	end
	local top = hit.Position.Y
	if top < 34 then
		return false
	end
	local sw = math.min(w - 6, rng:NextNumber(16, 26))
	local sh = sw * rng:NextNumber(0.55, 0.8)
	local y = math.clamp(top * 0.45, 14 + sh / 2, top - sh / 2 - 4)
	-- Find the actual facade at that height (it may be set back or have bays).
	local origin = (cf * CFrame.new(0, y, -depth / 2 - 30)).Position
	local face = Workspace:Raycast(origin, cf.LookVector * -(depth + 30), params(model))
	if not face or math.abs(face.Normal.Y) > 0.2 then
		return false
	end
	local pos = face.Position + face.Normal * 0.6
	local panelCF = CFrame.lookAt(pos, pos + face.Normal)
	local frameColour = Util.pick(rng, { C(255, 60, 180), C(60, 220, 255), C(255, 200, 60), C(255, 255, 255) })
	Util.deco(model, V3(sw + 1.2, sh + 1.2, 0.5), panelCF * CFrame.new(0, 0, 0.3), C(20, 20, 22), M.Metal)
	local panel = Util.deco(model, V3(sw, sh, 0.4), panelCF, C(10, 10, 12), M.SmoothPlastic)
	panel.CastShadow = false
	adFace(panel, Front, ADS[rng:NextInteger(1, #ADS)], true)
	for _, s in ipairs({ -1, 1 }) do
		local edge = Util.deco(model, V3(0.3, sh + 1, 0.3), panelCF * CFrame.new(s * (sw / 2 + 0.5), 0, -0.1), frameColour, M.Neon)
		edge.CastShadow = false
	end
	local glow = Instance.new("SurfaceLight")
	glow.Face = Front
	glow.Range = 26
	glow.Angle = 100
	glow.Brightness = 1.2
	glow.Color = frameColour
	glow.Parent = panel
	return true
end

-- Maybe add an ad to a building just built on a main road.
-- cf: ground level at the lot centre, facing the road; w: frontage; depth: lot depth.
function Billboards.maybe(model, cf, w, depth, center)
	local rng = rngFor(center)
	local roll = rng:NextNumber()
	if roll < 0.1 and screenCount < MAX_SCREENS and w >= 22 then
		if screen(model, cf, w, depth, rng) then
			screenCount = screenCount + 1
			return
		end
	end
	if roll > 0.88 and roofCount < MAX_ROOF and w >= 18 then
		if rooftop(model, cf, w, rng) then
			roofCount = roofCount + 1
		end
	end
end

return Billboards
