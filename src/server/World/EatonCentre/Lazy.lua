-- Store contents built only where players are. A full fit-out of every store
-- in the Eaton Centre is ~500,000 parts; instead each store's contents (its
-- fixtures, stock, mannequins, ceiling and lights) are registered here as
-- builder functions and built into a "Contents" folder when a player comes
-- within NEAR studs of the store, and destroyed when nobody is within FAR.
-- The mall's structure, storefronts and signs stay built all the time.
--
--   Lazy.add(shop, centre, radius, build)   build(contents) builds into a folder
--   Lazy.start()                            after the world is built
local Players = game:GetService("Players")
local Util = require(script.Parent.Parent.Util)

local Lazy = {}

local NEAR = 140 -- build when a player is this far beyond the store's radius
local FAR = 230 -- destroy when nobody is this far beyond it
local PER_TICK = 1 -- stores started per tick at most (nearest first)
local TICK = 0.2

local entries = {} -- shop folder -> { shop, centre, radius, builders = {}, contents }
local list = {}

function Lazy.add(shop, centre, radius, build)
	local e = entries[shop]
	if not e then
		e = { shop = shop, centre = centre, radius = radius or 20, builders = {} }
		entries[shop] = e
		table.insert(list, e)
	end
	e.radius = math.max(e.radius, radius or 0)
	table.insert(e.builders, build)
end

local function nearest(pos, roots)
	local best = math.huge
	for _, r in ipairs(roots) do
		local d = (r - pos).Magnitude
		if d < best then
			best = d
		end
	end
	return best
end

-- Builds a store's contents straight into the world a little at a time: the
-- builder gives up the frame every Util.yieldEvery parts (see Util), so the
-- server and the clients take a big store in small pieces instead of one burst
-- (one burst of thousands of parts was a hitch of up to a second).
local building = 0
local function activate(e)
	e.building = true
	building += 1
	task.spawn(function()
		local contents = Instance.new("Folder")
		contents.Name = "Contents"
		contents.Parent = e.shop
		Util.yieldThread = coroutine.running()
		for _, build in ipairs(e.builders) do
			local ok, err = pcall(build, contents)
			if not ok then
				warn("[Lazy] " .. e.shop:GetFullName() .. ": " .. tostring(err))
			end
			task.wait()
		end
		if Util.yieldThread == coroutine.running() then
			Util.yieldThread = nil
		end
		e.building = false
		building -= 1
		if e.shop.Parent and not e.cancel then
			e.contents = contents
		else
			contents:Destroy()
		end
		e.cancel = false
	end)
end

local function tick()
	local roots = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r then
			table.insert(roots, r.Position)
		end
	end
	local want = {}
	for _, e in ipairs(list) do
		if e.shop.Parent then
			local d = nearest(e.centre, roots) - e.radius
			if e.building then
				e.cancel = d > FAR
			elseif e.contents then
				if d > FAR then
					e.contents:Destroy()
					e.contents = nil
				end
			elseif d < NEAR then
				table.insert(want, { e = e, d = d })
			end
		end
	end
	table.sort(want, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(PER_TICK - math.min(building, PER_TICK), #want) do
		activate(want[i].e)
	end
end

function Lazy.start()
	print(string.format("[Lazy] %d stores fitted out on demand", #list))
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then
				warn("[Lazy] " .. tostring(err))
			end
			task.wait(TICK)
		end
	end)
end

function Lazy.count()
	local n = 0
	for _, e in ipairs(list) do
		if e.contents then
			n += 1
		end
	end
	return n, #list
end

return Lazy
