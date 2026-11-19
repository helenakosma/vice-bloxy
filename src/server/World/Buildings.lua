-- Building styles and placement. Buildings line every road, facing the street.
-- Avenue buildings are detailed (and sometimes have enterable shops); side-street
-- buildings are simpler; cheap filler fills the gaps inside blocks.
local Util = require(script.Parent.Util)
local Stores = require(script.Parent.Stores)
local Billboards = require(script.Parent.Billboards)

local Buildings = {}

local V3 = Vector3.new
local M = Enum.Material

local BRICK = {
	Color3.fromRGB(122, 64, 48), Color3.fromRGB(140, 78, 58), Color3.fromRGB(105, 58, 44),
	Color3.fromRGB(150, 95, 70), Color3.fromRGB(92, 60, 50), Color3.fromRGB(128, 88, 66),
}
local BROWNSTONE = { Color3.fromRGB(110, 78, 60), Color3.fromRGB(96, 68, 54), Color3.fromRGB(125, 92, 72) }
local STONE = {
	Color3.fromRGB(196, 184, 160), Color3.fromRGB(176, 168, 152), Color3.fromRGB(160, 150, 135),
	Color3.fromRGB(140, 134, 126), Color3.fromRGB(205, 195, 175), Color3.fromRGB(118, 112, 104),
}
local CAST_IRON = { Color3.fromRGB(150, 146, 136), Color3.fromRGB(92, 94, 88), Color3.fromRGB(176, 166, 146) }
local GLASS = {
	Color3.fromRGB(78, 96, 108), Color3.fromRGB(92, 104, 110), Color3.fromRGB(70, 80, 78), Color3.fromRGB(105, 92, 78),
}
local WINDOW = Color3.fromRGB(40, 44, 50)
local METAL = Color3.fromRGB(38, 38, 40)

local MIDTOWN = Vector2.new(30, 120)
local decoCount = 0

-- Taller buildings toward midtown.
local function heightFactor(p)
	local dist = (p - MIDTOWN).Magnitude
	return 1 + 1.6 * math.max(0, 1 - dist / 650)
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------

-- Window rows: a glass band per floor, split into windows by piers on the front.
local function windows(folder, cf, w, d, y0, floors, floorH, wallColor, wallMat, opts)
	local bandH = floorH * (opts.ratio or 0.5)
	for f = 0, floors - 1 do
		local yc = y0 + f * floorH + floorH * 0.55
		if opts.wrap then
			local band = Util.deco(folder, V3(w + 0.3, bandH, d + 0.3), cf * CFrame.new(0, yc, 0), opts.glass or WINDOW, M.Glass)
			band.Reflectance = 0.18
			Util.nightWindow(band, 0.3)
		else
			local band = Util.deco(folder, V3(w - 1, bandH, 0.3), cf * CFrame.new(0, yc, -d / 2 - 0.1), opts.glass or WINDOW, M.Glass)
			band.Reflectance = 0.18
			Util.nightWindow(band, 0.3)
		end
	end
	if opts.pierSpacing and floors > 0 then
		local n = math.max(2, math.floor(w / opts.pierSpacing))
		local h = floors * floorH
		for j = 0, n do
			local x = -w / 2 + w * j / n
			Util.deco(folder, V3(1.1, h, 0.9), cf * CFrame.new(x, y0 + h / 2, -d / 2 - 0.25), wallColor, wallMat)
		end
	end
end

local function cornice(folder, cf, w, d, y, color)
	Util.deco(folder, V3(w + 1.4, 1.4, d + 1.4), cf * CFrame.new(0, y + 0.7, 0), color, M.Concrete)
end

local function waterTower(folder, cf, y)
	local wood = Color3.fromRGB(112, 84, 58)
	Util.deco(folder, V3(8, 0.5, 8), cf * CFrame.new(0, y + 4.25, 0), METAL, M.Metal)
	for _, x in ipairs({ -3, 3 }) do
		for _, z in ipairs({ -3, 3 }) do
			Util.deco(folder, V3(0.5, 4, 0.5), cf * CFrame.new(x, y + 2, z), METAL, M.Metal)
		end
	end
	Util.cylinder(folder, 8, 7, cf * CFrame.new(0, y + 8.5, 0), wood, M.WoodPlanks, false)
	Util.cylinder(folder, 1, 7.4, cf * CFrame.new(0, y + 13, 0), Util.shade(wood, 0.7), M.Wood, false)
	Util.cylinder(folder, 1.2, 4, cf * CFrame.new(0, y + 14, 0), Util.shade(wood, 0.7), M.Wood, false)
end

local function fireEscape(folder, cf, w, d, y0, floors, floorH)
	local width = math.min(12, w * 0.5)
	local fz = -d / 2 - 1.8
	for f = 1, floors - 1 do
		local y = y0 + f * floorH
		Util.deco(folder, V3(width, 0.25, 3), cf * CFrame.new(0, y, fz), METAL, M.DiamondPlate)
		Util.deco(folder, V3(width, 2.6, 0.15), cf * CFrame.new(0, y + 1.3, fz - 1.4), METAL, M.Metal)
		local ladder = Util.deco(folder, V3(0.9, floorH * 1.15, 0.2), cf * CFrame.new(width * 0.2, y - floorH / 2, fz + 0.4), METAL, M.Metal)
		ladder.CFrame = ladder.CFrame * CFrame.Angles(0, 0, math.rad(32))
	end
end

local function rooftopBox(folder, cf, w, d, y, rng)
	local bw, bd = w * rng:NextNumber(0.2, 0.4), d * rng:NextNumber(0.2, 0.4)
	Util.deco(folder, V3(bw, 4, bd), cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), y + 2, rng:NextNumber(-d / 4, d / 4)), Color3.fromRGB(120, 120, 118), M.Metal)
end

local function entranceDoor(folder, cf, w, d)
	Util.deco(folder, V3(4, 8.5, 0.5), cf * CFrame.new(0, 4.25, -d / 2 - 0.2), Color3.fromRGB(44, 32, 24), M.Wood)
	Util.deco(folder, V3(5.4, 0.6, 1), cf * CFrame.new(0, 8.8, -d / 2 - 0.4), Color3.fromRGB(70, 66, 60), M.Concrete)
end

-- Ground floor: an enterable shop, a shopfront, or a plain entrance.
local function groundFloor(folder, cf, w, d, groundH, ctx)
	if ctx.shop == "interior" then
		Stores.interior(folder, cf, w, d, groundH, ctx.rng)
	elseif ctx.shop == "facade" then
		Stores.facade(folder, cf, w, d, groundH, ctx.rng)
	else
		entranceDoor(folder, cf, w, d)
	end
end

-- Main box of a building. With an interior shop the box starts above the shop.
local function core(folder, cf, w, d, h, color, material, ctx, groundH)
	local bottom = 0
	if ctx.shop == "interior" then
		bottom = groundH
	end
	if h - bottom < 0.5 then
		return
	end
	Util.solid(folder, V3(w, h - bottom, d), cf * CFrame.new(0, bottom + (h - bottom) / 2, 0), color, material)
end

---------------------------------------------------------------------------
-- Styles
---------------------------------------------------------------------------
local Styles = {}
Buildings.Styles = Styles -- other modules (e.g. ViceStyles) add their own styles here

function Styles.walkup(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 10, 13
	local floors = rng:NextInteger(4, 6)
	local h = groundH + floors * floorH
	local color = Util.pick(rng, BRICK)
	core(folder, cf, w, d, h, color, M.Brick, ctx, groundH)
	windows(folder, cf, w, d, groundH, floors, floorH, color, M.Brick, { pierSpacing = ctx.detailed and 5.5 or nil, wrap = not ctx.detailed })
	cornice(folder, cf, w, d, h, Util.shade(color, 0.7))
	groundFloor(folder, cf, w, d, groundH, ctx)
	if rng:NextNumber() < 0.45 then
		fireEscape(folder, cf, w, d, groundH, floors, floorH)
	end
	if rng:NextNumber() < 0.25 then
		waterTower(folder, cf, h + 1.4)
	end
end

function Styles.brownstone(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH = 10
	local floors = rng:NextInteger(4, 5)
	local h = 2 + floors * floorH
	local color = Util.pick(rng, BROWNSTONE)
	ctx.shop = nil -- residential
	Util.solid(folder, V3(w, h, d), cf * CFrame.new(0, h / 2, 0), color, M.Sandstone)
	windows(folder, cf, w, d, 2, floors, floorH, color, M.Sandstone, { pierSpacing = 5, wrap = false, ratio = 0.55 })
	cornice(folder, cf, w, d, h, Util.shade(color, 0.6))
	-- Stoop up to a raised front door.
	local x = w / 2 - 4
	Util.solid(folder, V3(5, 3, 6), cf * CFrame.new(x, 1.5, -d / 2 - 3), Util.shade(color, 0.9), M.Sandstone)
	Util.deco(folder, V3(3.6, 7, 0.4), cf * CFrame.new(x, 6.5, -d / 2 - 0.2), Color3.fromRGB(40, 28, 20), M.Wood)
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(0.2, 2.5, 6), cf * CFrame.new(x + side * 2.5, 4.25, -d / 2 - 3), METAL, M.Metal)
	end
	if rng:NextNumber() < 0.15 then
		waterTower(folder, cf, h + 1.4)
	end
end

function Styles.loft(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 13, 15
	local floors = math.floor(rng:NextInteger(5, 9) * math.min(1.4, ctx.heightFactor))
	local h = groundH + floors * floorH
	local color = Util.pick(rng, CAST_IRON)
	core(folder, cf, w, d, h, color, M.Concrete, ctx, groundH)
	windows(folder, cf, w, d, groundH, floors, floorH, color, M.Metal, { pierSpacing = 7, wrap = false, ratio = 0.62 })
	cornice(folder, cf, w, d, h, Util.shade(color, 0.75))
	Util.deco(folder, V3(w + 2.4, 2.2, d + 2.4), cf * CFrame.new(0, h + 2.2, 0), Util.shade(color, 0.85), M.Concrete)
	groundFloor(folder, cf, w, d, groundH, ctx)
	if rng:NextNumber() < 0.3 then
		waterTower(folder, cf, h + 3.3)
	end
end

function Styles.office(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 11, 15
	local floors = math.floor(rng:NextInteger(9, 16) * ctx.heightFactor)
	local color = Util.pick(rng, STONE)
	local lowerFloors = floors
	if floors > 16 then
		lowerFloors = math.floor(floors * 0.6)
	end
	local h1 = groundH + lowerFloors * floorH
	core(folder, cf, w, d, h1, color, M.Limestone, ctx, groundH)
	windows(folder, cf, w, d, groundH, lowerFloors, floorH, color, M.Limestone, { pierSpacing = 6, wrap = true })
	cornice(folder, cf, w, d, h1, Util.shade(color, 0.8))
	groundFloor(folder, cf, w, d, groundH, ctx)
	local top = h1 + 1.4
	if floors > lowerFloors then
		-- Setback tower on top.
		local w2, d2 = w * 0.72, d * 0.72
		local upper = floors - lowerFloors
		local cf2 = cf * CFrame.new(0, top, 0)
		Util.solid(folder, V3(w2, upper * floorH, d2), cf2 * CFrame.new(0, upper * floorH / 2, 0), color, M.Limestone)
		windows(folder, cf2, w2, d2, 0, upper, floorH, color, M.Limestone, { pierSpacing = 6, wrap = true })
		top = top + upper * floorH
		cornice(folder, cf, w2, d2, top, Util.shade(color, 0.8))
		top = top + 1.4
	end
	rooftopBox(folder, cf, w * 0.7, d * 0.7, top, rng)
end

function Styles.glass(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 12, 18
	local floors = math.floor(rng:NextInteger(12, 22) * ctx.heightFactor)
	local h = groundH + floors * floorH
	local glass = Util.pick(rng, GLASS)
	local frame = Color3.fromRGB(88, 92, 96)

	-- Stone lobby with a glass curtain wall above.
	if ctx.shop == "interior" then
		Stores.interior(folder, cf, w, d, groundH, rng)
	else
		Util.solid(folder, V3(w, groundH, d), cf * CFrame.new(0, groundH / 2, 0), Color3.fromRGB(46, 46, 48), M.Granite)
		local lobby = Util.deco(folder, V3(w - 6, groundH - 4, 0.4), cf * CFrame.new(0, (groundH - 4) / 2 + 0.5, -d / 2 - 0.15), Color3.fromRGB(150, 140, 120), M.Glass)
		lobby.Transparency = 0.2
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Range = 12
		light.Brightness = 0.7
		light.Color = Color3.fromRGB(255, 230, 190)
		light.Parent = lobby
	end
	local tower = Util.solid(folder, V3(w, h - groundH, d), cf * CFrame.new(0, groundH + (h - groundH) / 2, 0), glass, M.Glass)
	tower.Reflectance = 0.38

	-- Spandrel lines every two floors and vertical mullions on every face.
	for f = 2, floors, 2 do
		Util.deco(folder, V3(w + 0.3, 0.7, d + 0.3), cf * CFrame.new(0, groundH + f * floorH, 0), frame, M.Metal)
	end
	local shaftH = h - groundH
	local function mullions(length, across, isFront)
		local n = math.max(2, math.floor(length / 8))
		for j = 0, n do
			local u = -length / 2 + length * j / n
			for _, side in ipairs({ -1, 1 }) do
				local pos
				if isFront then
					pos = V3(u, groundH + shaftH / 2, side * (across / 2 + 0.15))
				else
					pos = V3(side * (across / 2 + 0.15), groundH + shaftH / 2, u)
				end
				Util.deco(folder, V3(0.35, shaftH, 0.35), cf * CFrame.new(pos), frame, M.Metal)
			end
		end
	end
	mullions(w, d, true)
	mullions(d, w, false)
	Util.deco(folder, V3(w * 0.8, 6, d * 0.8), cf * CFrame.new(0, h + 3, 0), Util.shade(glass, 0.6), M.Metal)
end

-- Rare art deco landmark: stacked setbacks, a metal crown and a spire.
function Styles.deco(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 11, 18
	local color = Util.pick(rng, { Color3.fromRGB(190, 180, 160), Color3.fromRGB(150, 140, 125) })
	ctx.shop = ctx.shop == "interior" and "interior" or "facade"
	core(folder, cf, w, d, groundH, color, M.Limestone, ctx, groundH)
	groundFloor(folder, cf, w, d, groundH, ctx)
	local y = groundH
	local tiers = { { 1, 14 }, { 0.8, 12 }, { 0.62, 10 }, { 0.45, 8 } }
	for _, tier in ipairs(tiers) do
		local tw, td = w * tier[1], d * tier[1]
		local floors = math.floor(tier[2] * math.min(1.5, ctx.heightFactor))
		local th = floors * floorH
		Util.solid(folder, V3(tw, th, td), cf * CFrame.new(0, y + th / 2, 0), color, M.Limestone)
		windows(folder, cf * CFrame.new(0, y, 0), tw, td, 0, math.floor(floors / 2), floorH * 2, color, M.Limestone, { pierSpacing = 5, wrap = true, ratio = 0.7 })
		y = y + th
		cornice(folder, cf, tw, td, y - 1.4, Util.shade(color, 0.8))
	end
	local crown = Color3.fromRGB(196, 198, 204)
	for i = 1, 4 do
		local s = w * (0.4 - i * 0.07)
		local part = Util.deco(folder, V3(s, 6, s), cf * CFrame.new(0, y + 3, 0), crown, M.Foil)
		part.Reflectance = 0.4
		y = y + 6
	end
	Util.cylinder(folder, 40, 1.2, cf * CFrame.new(0, y + 20, 0), crown, M.Metal, false)
	decoCount = decoCount + 1
end

-- Cheap box for gaps inside blocks and for background skyline.
function Buildings.filler(folder, cf, w, d, h, rng, collide)
	local color = Util.pick(rng, rng:NextNumber() < 0.5 and BRICK or STONE)
	if collide then
		Util.solid(folder, V3(w, h, d), cf * CFrame.new(0, h / 2, 0), color, M.Concrete)
	else
		local p = Util.deco(folder, V3(w, h, d), cf * CFrame.new(0, h / 2, 0), color, M.Concrete)
		p.CastShadow = false
	end
	local floorH = 10
	local bands = math.min(6, math.floor(h / floorH) - 1)
	local step = math.max(1, math.floor((h / floorH) / math.max(1, bands)))
	for b = 1, bands do
		local band = Util.deco(folder, V3(w + 0.3, floorH * 0.45, d + 0.3), cf * CFrame.new(0, b * step * floorH - floorH * 0.4, 0), WINDOW, M.Glass)
		band.CastShadow = false
		Util.nightWindow(band, 0.25)
	end
	local top = Util.deco(folder, V3(w + 1, 1.2, d + 1), cf * CFrame.new(0, h + 0.6, 0), Util.shade(color, 0.7), M.Concrete)
	top.CastShadow = false
end

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------
local function chooseStyle(rng, road, center)
	if road.main then
		local hf = heightFactor(center)
		local r = rng:NextNumber()
		if decoCount < 3 and hf > 2 and r < 0.04 then
			return "deco"
		end
		if r < 0.18 + 0.12 * (hf - 1) then
			return "glass"
		elseif r < 0.55 then
			return "office"
		elseif r < 0.75 then
			return "loft"
		end
		return "walkup"
	end
	local r = rng:NextNumber()
	if r < 0.45 then
		return "walkup"
	elseif r < 0.8 then
		return "brownstone"
	end
	return "loft"
end

local maxInteriors = 60

-- Walks both sides of every road placing buildings that face it.
-- opts (all optional):
--   chooseStyle(rng, road, center) -> style name in Buildings.Styles
--   interiorChance / facadeChance  -> per-road chances for walk-in shops / shopfronts
--   heightFactor(center)           -> multiplier for building height
function Buildings.placeFrontage(folder, roads, rng, opts)
	opts = opts or {}
	local choose = opts.chooseStyle or chooseStyle
	local getHeight = opts.heightFactor or heightFactor
	-- Main roads first so they claim the corners.
	local ordered = {}
	for _, road in ipairs(roads) do
		if road.main then
			table.insert(ordered, road)
		end
	end
	for _, road in ipairs(roads) do
		if not road.main and road.kind ~= "alley" then
			table.insert(ordered, road)
		end
	end

	local placed = 0
	for _, road in ipairs(ordered) do
		local setback = road.width / 2 + road.walk + 0.4
		for i = 1, #road.points - 1 do
			local a, b = road.points[i], road.points[i + 1]
			local delta = b - a
			local length = delta.Magnitude
			if length > 10 then
				local dir = delta.Unit
				local normal = Vector2.new(-dir.Y, dir.X)
				for _, side in ipairs({ -1, 1 }) do
					local front = normal * -side -- buildings face the road
					local t = 0
					while t < length - 8 do
						local w
						if road.main then
							w = rng:NextNumber(24, 44)
						else
							w = rng:NextNumber(18, 30)
						end
						w = math.min(w, length - t)
						local done = false
						local depths = road.main and { rng:NextNumber(44, 60), 34, 24 } or { rng:NextNumber(30, 42), 24, 16 }
						for _, depth in ipairs(depths) do
							local center = a + dir * (t + w / 2) + normal * side * (setback + depth / 2)
							local right = Vector2.new(-front.Y, front.X) * -1
							if Util.rectFree(center, front, right, w, depth) then
								Util.rectMark(center, front, right, w, depth, Util.BUILT)
								local cf = Util.groundCF(center, front, 0)
								local style = choose(rng, road, center)
								local ctx = {
									rng = rng,
									detailed = road.main,
									heightFactor = getHeight(center),
								}
								local shopRoll = rng:NextNumber()
								local interiorChance = opts.interiorChance or (road.main and 0.22 or 0)
								local facadeChance = opts.facadeChance or (road.main and 0.85 or 0.4)
								if road.main and w >= 20 and depth >= 24 and Stores.count < maxInteriors and shopRoll < interiorChance then
									ctx.shop = "interior"
								elseif shopRoll < facadeChance then
									ctx.shop = "facade"
								end
								-- Each building is its own Model so streaming can swap in a
								-- low-detail version far away. The hero block gets hand-built kits.
								local model = Util.buildingModel(folder, style)
								if opts.hero and opts.hero.contains(center) then
									model.Name = "Hero"
									opts.hero.build(model, cf, w, depth, road, center, side)
								else
									Styles[style](model, cf, w, depth, ctx)
									if road.main and opts.ads ~= false then
										Billboards.maybe(model, cf, w, depth, center)
									end
								end
								placed = placed + 1
								done = true
								t = t + w
								break
							end
						end
						if not done then
							t = t + 4
						end
					end
				end
			end
		end
	end
	return placed
end

-- Fills any open ground left inside blocks with simple buildings.
-- bounds defaults to downtown.
function Buildings.fillGaps(folder, rng, bounds)
	local b = bounds or { minX = Util.MIN_X, maxX = Util.RIVER_X, minZ = Util.MIN_Z, maxZ = Util.MAX_Z }
	local count = 0
	for x = b.minX + 10, b.maxX - 20, 10 do
		for z = b.minZ + 10, b.maxZ - 10, 10 do
			if Util.get(x, z) == Util.FREE then
				for _, size in ipairs({ 30, 20, 13 }) do
					local c = Vector2.new(x + size / 2 - 5, z + size / 2 - 5)
					local fwd, right = Vector2.new(0, -1), Vector2.new(1, 0)
					if Util.rectFree(c, fwd, right, size, size) then
						Util.rectMark(c, fwd, right, size, size, Util.BUILT)
						local h = rng:NextNumber(30, 70) * heightFactor(c)
						Buildings.filler(Util.buildingModel(folder, "Filler"), Util.groundCF(c, fwd, 0), size, size, h, rng, true)
						count = count + 1
						break
					end
				end
			end
		end
	end
	return count
end

-- Distant skyline beyond the edge of the world, standing on its own land.
function Buildings.background(folder, rng)
	local G = Util.GRID
	local function ring(minX, maxX, minZ, maxZ, count, hMin, hMax)
		local land = Util.deco(folder, Vector3.new(maxX - minX + 80, 2, maxZ - minZ + 80), CFrame.new((minX + maxX) / 2, -1, (minZ + maxZ) / 2), Color3.fromRGB(78, 76, 72), Enum.Material.Concrete)
		land.CastShadow = false
		for _ = 1, count do
			local c = Vector2.new(rng:NextNumber(minX, maxX), rng:NextNumber(minZ, maxZ))
			local w = rng:NextNumber(30, 80)
			local d = rng:NextNumber(30, 80)
			Buildings.filler(Util.buildingModel(folder, "Skyline"), Util.groundCF(c, Vector2.new(0, -1), 0), w, d, rng:NextNumber(hMin, hMax), rng, false)
		end
	end
	-- Each ring is kept under 2048 studs across (the Roblox part size limit).
	ring(G.minX - 900, G.minX - 500, -1800, -250, 40, 40, 220) -- far west
	ring(G.minX - 900, G.minX - 500, -250, 1200, 40, 40, 220)
	ring(-1400, -250, G.minZ - 800, G.minZ - 450, 40, 60, 260) -- far north
	ring(-250, 900, G.minZ - 800, G.minZ - 450, 40, 60, 260)
	ring(-1600, 300, G.maxZ + 450, G.maxZ + 800, 60, 30, 140) -- far south
end

Buildings.waterTower = waterTower

return Buildings
