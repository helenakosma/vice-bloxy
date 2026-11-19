-- Shared helpers for world generation: part factories and an occupancy grid that
-- records what covers each 4x4-stud cell (road, sidewalk, building, park, water).
-- Coordinates: X runs west (-) to east (+); north is -Z.
local Util = {}

Util.CELL = 4

-- Downtown bounds (the original city). Other districts define their own.
Util.MIN_X, Util.MAX_X = -700, 620
Util.MIN_Z, Util.MAX_Z = -700, 700
Util.RIVER_X = 594 -- the east river starts here (downtown's east edge)

-- Whole-world grid covering every district. Cells start as water; districts
-- claim their land with Util.markRect(..., Util.FREE).
Util.GRID = { minX = -1900, maxX = 2400, minZ = -2100, maxZ = 1400 }

Util.FREE = 0
Util.ROAD = 1
Util.WALK = 2
Util.BUILT = 3
Util.PARK = 4
Util.WATER = 5
Util.RESERVED = 6 -- under elevated highways: keep clear of buildings

local CELL = Util.CELL
local G = Util.GRID
local NX = math.ceil((G.maxX - G.minX) / CELL)
local NZ = math.ceil((G.maxZ - G.minZ) / CELL)
local grid = buffer.create(NX * NZ) -- u8 per cell
local owner = buffer.create(NX * NZ * 2) -- u16 road id per cell (0 = none)
local junction = {} -- cell index -> true where two roads overlap
buffer.fill(grid, 0, Util.WATER)

local function index(ix, iz)
	return iz * NX + ix
end

local function cellOf(x, z)
	local ix = math.floor((x - G.minX) / CELL)
	local iz = math.floor((z - G.minZ) / CELL)
	if ix < 0 or iz < 0 or ix >= NX or iz >= NZ then
		return nil
	end
	return index(ix, iz)
end

function Util.get(x, z)
	local i = cellOf(x, z)
	if not i then
		return -1
	end
	return buffer.readu8(grid, i)
end

function Util.set(x, z, value)
	local i = cellOf(x, z)
	if i then
		buffer.writeu8(grid, i, value)
	end
end

function Util.isJunction(x, z)
	local i = cellOf(x, z)
	return i ~= nil and junction[i] == true
end

-- Calls fn(i, cx, cz) for every cell whose centre lies within the bounding box.
local function forCells(minX, maxX, minZ, maxZ, fn)
	local ix0 = math.max(0, math.floor((minX - G.minX) / CELL))
	local ix1 = math.min(NX - 1, math.floor((maxX - G.minX) / CELL))
	local iz0 = math.max(0, math.floor((minZ - G.minZ) / CELL))
	local iz1 = math.min(NZ - 1, math.floor((maxZ - G.minZ) / CELL))
	for iz = iz0, iz1 do
		local cz = G.minZ + (iz + 0.5) * CELL
		for ix = ix0, ix1 do
			fn(index(ix, iz), G.minX + (ix + 0.5) * CELL, cz)
		end
	end
end

local function distToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = 0
	if len2 > 0 then
		t = math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1)
	end
	local qx, qz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(qx * qx + qz * qz)
end

-- Marks cells within `radius` of segment a-b. With roadId set, records junctions.
-- With onlyFree, only claims cells that are still free.
function Util.markSegment(a, b, radius, value, roadId, onlyFree)
	forCells(math.min(a.X, b.X) - radius, math.max(a.X, b.X) + radius, math.min(a.Y, b.Y) - radius, math.max(a.Y, b.Y) + radius, function(i, cx, cz)
		if distToSegment(cx, cz, a.X, a.Y, b.X, b.Y) <= radius then
			if onlyFree then
				if buffer.readu8(grid, i) == Util.FREE then
					buffer.writeu8(grid, i, value)
				end
			else
				buffer.writeu8(grid, i, value)
				if roadId then
					local current = buffer.readu16(owner, i * 2)
					if current ~= 0 and current ~= roadId then
						junction[i] = true
					end
					buffer.writeu16(owner, i * 2, roadId)
				end
			end
		end
	end)
end

function Util.markRect(minX, maxX, minZ, maxZ, value)
	forCells(minX, maxX, minZ, maxZ, function(i)
		buffer.writeu8(grid, i, value)
	end)
end

-- Samples a rotated rectangle (centre c, unit vectors fwd/right, as Vector2s).
local function sampleRect(c, fwd, right, w, d, fn)
	local nu = math.max(1, math.ceil(w / 3))
	local nv = math.max(1, math.ceil(d / 3))
	for a = 0, nu do
		local u = -w / 2 + w * a / nu
		for b = 0, nv do
			local v = -d / 2 + d * b / nv
			local p = c + right * u + fwd * v
			if fn(p) == false then
				return false
			end
		end
	end
	return true
end

-- True when the rectangle (shrunk slightly so neighbours can touch) is all free.
function Util.rectFree(c, fwd, right, w, d)
	if w < 6 or d < 6 then
		return false
	end
	return sampleRect(c, fwd, right, w - 3, d - 3, function(p)
		if Util.get(p.X, p.Y) ~= Util.FREE then
			return false
		end
		return true
	end)
end

function Util.rectMark(c, fwd, right, w, d, value)
	sampleRect(c, fwd, right, w, d, function(p)
		Util.set(p.X, p.Y, value)
		return true
	end)
end

---------------------------------------------------------------------------
-- Part factories. Parts are fully configured before parenting (much faster).
---------------------------------------------------------------------------
local created = 0
local currentDistrict = "Shared"
Util.partCounts = {} -- district name -> parts created
Util.districtOrder = {}

-- Parts created after this call are counted toward `name`.
function Util.beginDistrict(name)
	currentDistrict = name
	if not Util.partCounts[name] then
		Util.partCounts[name] = 0
		table.insert(Util.districtOrder, name)
	end
end
Util.beginDistrict("Shared")

-- Counts a created part (or model piece built elsewhere, e.g. parked cars) and
-- yields now and then so building thousands of parts never trips the script timeout.
function Util.tick(amount)
	amount = amount or 1
	created = created + amount
	Util.partCounts[currentDistrict] = Util.partCounts[currentDistrict] + amount
	if created % 600 < amount then
		task.wait()
	end
end

function Util.totalParts()
	return created
end

local function makePart(parent, size, cf, color, material, collide, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	if not collide then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	Util.tick()
	return p
end

-- Collidable part (ground, walls, building cores).
function Util.solid(parent, size, cf, color, material, shape)
	return makePart(parent, size, cf, color, material, true, shape)
end

-- Cosmetic part: no collisions, raycasts or touch events.
function Util.deco(parent, size, cf, color, material, shape)
	return makePart(parent, size, cf, color, material, false, shape)
end

-- Upright cylinder (Roblox cylinders run along X, so rotate onto Y).
function Util.cylinder(parent, height, diameter, cf, color, material, collide)
	return makePart(parent, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, collide, Enum.PartType.Cylinder)
end

function Util.pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

function Util.shade(color, factor)
	return Color3.new(math.clamp(color.R * factor, 0, 1), math.clamp(color.G * factor, 0, 1), math.clamp(color.B * factor, 0, 1))
end

-- Flat CFrame at ground point p (Vector2) facing direction dir (Vector2).
function Util.groundCF(p, dir, y)
	local pos = Vector3.new(p.X, y or 0, p.Y)
	return CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Y))
end

-- Land: a thick slab with its top at y = 0. Water cells under it become free
-- (cells already claimed by roads from another district are left alone).
function Util.land(parent, minX, maxX, minZ, maxZ, color, material)
	forCells(minX, maxX, minZ, maxZ, function(i)
		if buffer.readu8(grid, i) == Util.WATER then
			buffer.writeu8(grid, i, Util.FREE)
		end
	end)
	local size = Vector3.new(maxX - minX, 20, maxZ - minZ)
	local cf = CFrame.new((minX + maxX) / 2, -10, (minZ + maxZ) / 2)
	return Util.solid(parent, size, cf, color or Color3.fromRGB(96, 93, 88), material or Enum.Material.Concrete)
end

-- Thin straight piece between two 3D points (cables, rails, ladders).
function Util.beam(parent, a, b, thickness, color, material)
	local length = (b - a).Magnitude
	return Util.deco(parent, Vector3.new(thickness, thickness, length), CFrame.lookAt((a + b) / 2, b), color, material)
end

-- Adds a SurfaceGui sign with text to one face of a part.
function Util.sign(part, face, text, textColor, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBold
	label.TextColor3 = textColor
	label.Parent = gui
	gui.Parent = part
	return gui
end

return Util
