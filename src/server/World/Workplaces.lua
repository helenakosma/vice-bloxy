-- Workplaces: the physical places jobs happen, built into the world and registered
-- by id so the Work service can put prompts on their stations.
--
--   Workplaces.cafe(folder, cf, w, id, employer)        an espresso bar on a wall
--   Workplaces.clothing(folder, y, xFront, inward, zA, zB, id, employer)
--                                                     a clothing store with stockroom
--   Workplaces.addPickup(name, position)              a counter couriers collect from
--   Workplaces.get(id), Workplaces.pickups
local CollectionService = game:GetService("CollectionService")

local Util = require(script.Parent.Util)

local Workplaces = {}
Workplaces.registry = {}
Workplaces.pickups = {}

local V3 = Vector3.new
local M = Enum.Material
local C = Color3.fromRGB
local Front = Enum.NormalId.Front

local function station(folder, size, cf, colour, material, name)
	local p = Util.solid(folder, size, cf, colour, material or M.SmoothPlastic)
	p.Name = name
	return p
end

local function sign(folder, size, cf, text, bg, fg)
	local p = Util.deco(folder, size, cf, bg, M.SmoothPlastic)
	p.CastShadow = false
	Util.sign(p, Front, text, fg, Enum.Font.GothamBlack).LightInfluence = 0
	return p
end

-- Time clock terminal (clock in / out).
local function clock(folder, cf)
	local body = station(folder, V3(1.6, 2.2, 0.6), cf, C(40, 42, 48), M.Metal, "TimeClock")
	local screen = Util.deco(folder, V3(1.2, 0.8, 0.1), cf * CFrame.new(0, 0.4, -0.32), C(60, 200, 120), M.Neon)
	screen.CastShadow = false
	return body
end

function Workplaces.get(id)
	return Workplaces.registry[id]
end

function Workplaces.addPickup(name, position)
	table.insert(Workplaces.pickups, { name = name, position = position })
end

---------------------------------------------------------------------------
-- Café: espresso bar against a wall. cf is on the floor at the wall face, Front
-- facing into the room; w is the width (about 16). Staff come in through a gap at
-- the right-hand end of the front counter.
---------------------------------------------------------------------------
function Workplaces.cafe(folder, cf, w, id, employer)
	local depth, h = 11, 9.5
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local brown, cream = C(70, 44, 30), C(232, 176, 100)
	-- Shell: floor, side walls, roof with the sign.
	Util.deco(folder, V3(w, 0.1, depth), at(0, 0.05, -depth / 2), C(150, 112, 76), M.Wood)
	for _, x in ipairs({ -w / 2 + 0.25, w / 2 - 0.25 }) do
		Util.solid(folder, V3(0.5, h, depth), at(x, h / 2, -depth / 2), brown, M.Wood)
	end
	Util.solid(folder, V3(w, 0.6, depth + 0.4), at(0, h + 0.3, -depth / 2 - 0.2), brown, M.Wood)
	sign(folder, V3(w, 1.9, 0.4), at(0, h - 0.95, -depth - 0.2), "GRIND COFFEE", brown, cream)
	local glow = Util.deco(folder, V3(w - 1, 0.15, 0.6), at(0, h - 2.05, -depth + 0.2), C(255, 246, 228), M.Neon)
	glow.CastShadow = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 14
	light.Brightness = 1.1
	light.Color = C(255, 238, 210)
	light.Parent = glow

	-- Back counter with the stations on it.
	Util.solid(folder, V3(w - 1.2, 3.6, 2.4), at(0, 1.8, -1.4), C(60, 60, 64), M.Metal)
	local stations = {}
	local x0 = -w / 2 + 2
	local stepX = (w - 4) / 4
	stations.grind = station(folder, V3(1.6, 2.6, 1.6), at(x0, 4.9, -1.4), C(30, 30, 32), M.Metal, "Grinder")
	stations.espresso = station(folder, V3(3.2, 2.4, 1.8), at(x0 + stepX, 4.8, -1.4), C(200, 200, 206), M.Metal, "Espresso")
	Util.deco(folder, V3(2.6, 0.3, 0.1), at(x0 + stepX, 5.4, -2.35), C(255, 160, 60), M.Neon).CastShadow = false
	stations.milk = station(folder, V3(1.4, 2, 1.4), at(x0 + stepX * 2, 4.6, -1.4), C(220, 220, 226), M.Metal, "Steamer")
	stations.water = station(folder, V3(1.4, 2.2, 1.4), at(x0 + stepX * 3, 4.7, -1.4), C(90, 140, 200), M.Metal, "HotWater")
	stations.oven = station(folder, V3(2.6, 2.2, 1.8), at(x0 + stepX * 4, 4.7, -1.4), C(40, 40, 44), M.Metal, "Oven")
	Util.deco(folder, V3(2, 1, 0.1), at(x0 + stepX * 4, 4.7, -2.35), C(255, 120, 40), M.Neon).CastShadow = false
	-- Menu board on the wall above.
	sign(folder, V3(w - 4, 2.4, 0.2), at(0, 7.4, -0.3), "LATTE $5  ·  AMERICANO $4  ·  MUFFIN $3", C(30, 26, 22), C(255, 230, 190))

	-- Front counter (gap at the right end for staff), register, pickup, cups.
	local counterW = w - 4.5
	local counterX = -w / 2 + counterW / 2
	Util.solid(folder, V3(counterW, 3.6, 1.8), at(counterX, 1.8, -depth + 1.6), brown, M.Wood)
	Util.solid(folder, V3(counterW + 0.2, 0.25, 2.1), at(counterX, 3.72, -depth + 1.6), C(220, 216, 208), M.Marble)
	stations.register = station(folder, V3(1.6, 1.1, 1.2), at(-w / 2 + 3, 4.4, -depth + 1.6), C(36, 36, 40), M.SmoothPlastic, "Register")
	stations.pickup = station(folder, V3(3, 0.3, 1.6), at(counterX + counterW / 2 - 2.2, 3.95, -depth + 1.6), C(250, 214, 120), M.SmoothPlastic, "Pickup")
	sign(folder, V3(3, 0.6, 0.1), at(counterX + counterW / 2 - 2.2, 4.6, -depth + 0.65), "PICK UP", C(30, 26, 22), C(255, 230, 190))
	stations.cups = station(folder, V3(1, 1.6, 1), at(-w / 2 + 1.2, 4.6, -depth + 1.6), C(250, 250, 246), M.SmoothPlastic, "Cups")
	-- Staff gate.
	local gate = Util.deco(folder, V3(3.6, 3, 0.2), at(w / 2 - 2.3, 1.5, -depth + 1.6), C(120, 84, 60), M.Wood)
	gate.Transparency = 0.2
	sign(folder, V3(3, 0.5, 0.1), at(w / 2 - 2.3, 2.6, -depth + 1.48), "STAFF", C(30, 26, 22), C(255, 230, 190))
	stations.clock = clock(folder, at(w / 2 - 0.9, 4, -4) * CFrame.Angles(0, math.rad(90), 0))

	local spots = {}
	for k = 0, 2 do
		table.insert(spots, at(-w / 2 + 3, 0, -depth - 2.5 - k * 3.2) * CFrame.Angles(0, math.pi, 0))
	end
	local wp = {
		id = id,
		employer = employer,
		kind = "cafe",
		stations = stations,
		customerSpots = spots,
		centre = at(0, 0, -depth / 2).Position,
		radius = 26,
		folder = folder,
	}
	Workplaces.registry[id] = wp
	Workplaces.addPickup("Grind Coffee", stations.pickup.Position)
	CollectionService:AddTag(stations.clock, "Workplace")
	return wp
end

---------------------------------------------------------------------------
-- Clothing store: a shop unit with racks, a folding table, a till and a stockroom
-- at the back. The front faces the galleria at xFront; the shop goes `inward`
-- (+1/-1 along x) 30 studs deep, from zA to zB.
---------------------------------------------------------------------------
function Workplaces.clothing(folder, y, xFront, inward, zA, zB, id, employer)
	local depth = 30
	local w = zB - zA
	local function P(dx, dy, dz)
		return V3(xFront + inward * dx, y + dy, zA + dz)
	end
	local function at(dx, dy, dz)
		return CFrame.new(P(dx, dy, dz))
	end
	local facing = CFrame.Angles(0, inward > 0 and math.rad(90) or math.rad(-90), 0) -- Front toward the galleria
	local ink, white = C(20, 20, 24), C(244, 244, 240)

	-- Floor, side partitions, storefront with a wide door and the name.
	Util.deco(folder, V3(depth, 0.08, w), CFrame.new(P(depth / 2, 0.04, w / 2)), C(176, 140, 104), M.WoodPlanks)
	for _, dz in ipairs({ 0, w }) do
		Util.solid(folder, V3(depth, 17, 0.6), at(depth / 2, 8.5, dz), C(236, 234, 228), M.SmoothPlastic)
	end
	local door = 9
	for _, s in ipairs({ -1, 1 }) do
		local len = (w - door) / 2
		local g = Util.solid(folder, V3(0.3, 11, len - 0.4), at(0, 5.5, w / 2 + s * (door / 2 + len / 2)), C(200, 220, 228), M.Glass)
		g.Transparency = 0.55
	end
	Util.solid(folder, V3(0.6, 6, w), at(0, 14, w / 2), ink, M.SmoothPlastic)
	local name = Util.deco(folder, V3(w - 4, 3, 0.2), CFrame.new(P(-0.4, 14, w / 2)) * facing, ink, M.SmoothPlastic)
	name.CastShadow = false
	Util.sign(name, Front, "METRO THREADS", white, Enum.Font.GothamBlack).LightInfluence = 0

	local stations = {}
	-- Racks (rack1..rack3): a rail on posts with garments hanging.
	local garment = { C(200, 60, 60), C(40, 70, 130), C(240, 240, 236), C(30, 30, 34), C(120, 150, 90), C(230, 180, 60) }
	for i = 1, 3 do
		local dz = w * i / 4
		local rail = station(folder, V3(10, 0.4, 0.4), at(15, 7, dz), C(170, 172, 178), M.Metal, "Rack" .. i)
		for _, dx in ipairs({ 10.2, 19.8 }) do
			Util.solid(folder, V3(0.4, 7, 0.4), at(dx, 3.5, dz), C(170, 172, 178), M.Metal)
		end
		for k = 0, 6 do
			Util.deco(folder, V3(1.2, 4.6, 2.6), at(11 + k * 1.4, 4.6, dz), garment[(i + k) % #garment + 1], M.Fabric)
		end
		local tag = Util.deco(folder, V3(2.4, 0.8, 0.1), CFrame.new(P(15, 8, dz)) * facing, ink, M.SmoothPlastic)
		Util.sign(tag, Front, "RACK " .. i, white, Enum.Font.GothamBold).LightInfluence = 0
		stations["rack" .. i] = rail
	end
	-- Folding table near the front with stacks of tees.
	stations.table = station(folder, V3(6, 3.4, 4), at(5, 1.7, w * 0.7), C(214, 200, 176), M.Wood, "FoldTable")
	for k = 0, 2 do
		Util.deco(folder, V3(1.6, 0.8 + k * 0.3, 1.6), at(4 + k * 1, 3.8, w * 0.7), garment[k + 1], M.Fabric)
	end
	-- Till: counter with the register; the customer queue is in front of it.
	Util.solid(folder, V3(3, 3.6, 8), at(9, 1.8, 4.5), ink, M.SmoothPlastic)
	stations.register = station(folder, V3(1.4, 1.2, 1.6), at(9, 4.2, 4.5), C(50, 52, 58), M.SmoothPlastic, "Register")
	local spots = {}
	for k = 0, 2 do
		local p = P(5.5 - k * 0.2, 0, 4.5 + k * 3.2)
		table.insert(spots, CFrame.lookAt(p, p + V3(inward, 0, 0)))
	end
	-- Stockroom at the back, behind a wall with a door.
	local wallDx = 23
	for _, seg in ipairs({ { 0, w / 2 - 3 }, { w / 2 + 3, w } }) do
		Util.solid(folder, V3(0.6, 17, seg[2] - seg[1]), at(wallDx, 8.5, (seg[1] + seg[2]) / 2), C(220, 218, 212), M.SmoothPlastic)
	end
	Util.solid(folder, V3(0.6, 7, 6), at(wallDx, 13.5, w / 2), C(220, 218, 212), M.SmoothPlastic)
	sign(folder, V3(4, 0.8, 0.1), CFrame.new(P(wallDx - 0.4, 10.6, w / 2)) * facing, "STOCKROOM · STAFF", ink, white)
	stations.stock = station(folder, V3(2.4, 8, w - 4), at(29, 4, w / 2), C(150, 140, 120), M.Wood, "StockShelf")
	for k = 0, 5 do
		Util.deco(folder, V3(2, 1.6, 2.4), at(28.6, 2 + (k % 3) * 2.4, w / 2 - 6 + math.floor(k / 3) * 9), C(184, 150, 106), M.WoodPlanks)
	end
	stations.clock = clock(folder, CFrame.new(P(wallDx - 0.6, 4, w / 2 + 5)) * facing)
	-- Mirror and a light.
	local mirror = Util.deco(folder, V3(4, 9, 0.2), at(20, 5.5, w - 0.4), C(200, 220, 230), M.Glass)
	mirror.Reflectance = 0.5
	local lamp = Util.deco(folder, V3(depth - 8, 0.15, 3), at(depth / 2 - 4, 16.6, w / 2), C(255, 250, 240), M.Neon)
	lamp.CastShadow = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = lamp

	local wp = {
		id = id,
		employer = employer,
		kind = "retail",
		stations = stations,
		customerSpots = spots,
		centre = P(depth / 2, 0, w / 2),
		radius = 26,
		folder = folder,
	}
	Workplaces.registry[id] = wp
	Workplaces.addPickup("Metro Threads", P(2, 0, w / 2))
	CollectionService:AddTag(stations.clock, "Workplace")
	return wp
end

return Workplaces
