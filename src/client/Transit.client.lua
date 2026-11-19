-- Moves the subway trains, streetcars and buses on every client from the shared
-- server clock, so they're smooth and in the same place for everyone.
--
-- Surface routes (streetcar, buses): one closed path; each vehicle goes round it,
-- accelerating out of a stop, cruising, braking into the next.
--
-- Subway: two paths (northbound, then southbound) run one after the other. Trains
-- always face north and keep their cars in the same order, so reversing at a
-- terminal is seamless. Each train is the same timetable shifted by the headway.
-- Lights switch to the leading end, car screens show the next stop. If your
-- character is inside a car it's carried along with it, so you can ride.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local routesValue = ReplicatedStorage:WaitForChild("TransitRoutes")
local vehicles = Workspace:WaitForChild("City"):WaitForChild("Transit"):WaitForChild("Vehicles")

local HEAD_ON = Color3.fromRGB(255, 248, 225)
local TAIL_ON = Color3.fromRGB(255, 40, 30)
local LAMP_OFF = Color3.fromRGB(60, 60, 64)

---------------------------------------------------------------------------
-- Motion profile
---------------------------------------------------------------------------
-- Time to cover distance d starting and ending at rest, and position at time t.
local function hop(d, v, a)
	if d <= v * v / a then
		local peak = math.sqrt(d * a)
		local total = 2 * peak / a
		return total, function(t)
			if t < total / 2 then
				return 0.5 * a * t * t
			end
			local r = total - t
			return d - 0.5 * a * r * r
		end
	end
	local ta = v / a
	local da = 0.5 * a * ta * ta
	local tc = (d - 2 * da) / v
	local total = 2 * ta + tc
	return total, function(t)
		if t < ta then
			return 0.5 * a * t * t
		elseif t < ta + tc then
			return da + v * (t - ta)
		end
		local r = total - t
		return d - 0.5 * a * r * r
	end
end

---------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------
local function makePath(encoded, loop)
	local path = { points = {}, cum = { 0 }, loop = loop }
	for _, p in ipairs(encoded) do
		table.insert(path.points, Vector3.new(p[1], p[2], p[3]))
	end
	for i = 2, #path.points do
		path.cum[i] = path.cum[i - 1] + (path.points[i] - path.points[i - 1]).Magnitude
	end
	path.total = path.cum[#path.cum]
	return path
end

local function pointAt(path, s)
	if path.loop then
		s = s % path.total
	else
		s = math.clamp(s, 0, path.total)
	end
	local pts, cum = path.points, path.cum
	local lo, hi = 1, #pts - 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if cum[mid] <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local a, b = pts[lo], pts[lo + 1]
	local seg = cum[lo + 1] - cum[lo]
	if seg <= 0 then
		return a
	end
	return a:Lerp(b, (s - cum[lo]) / seg)
end

-- sign: which way along the path the car faces.
local function carCFrame(path, centre, carLength, sign)
	local reach = carLength * 0.35
	local front = pointAt(path, centre + sign * reach)
	local back = pointAt(path, centre - sign * reach)
	local mid = (front + back) / 2
	if (front - back).Magnitude < 0.01 then
		return CFrame.new(mid)
	end
	return CFrame.lookAt(mid, front)
end

---------------------------------------------------------------------------
-- Timelines
---------------------------------------------------------------------------
-- Surface loop: dwell, move, dwell, move ... round the closed path.
local function loopTimeline(route, total)
	local legs = {}
	local t = 0
	for i, s in ipairs(route.stops) do
		table.insert(legs, { t0 = t, dur = route.dwell, from = s, to = s, dwell = true, path = 1 })
		t = t + route.dwell
		local nextStop = route.stops[i + 1] or (route.stops[1] + total)
		local dur, fn = hop(math.abs(nextStop - s), route.speed, route.accel)
		table.insert(legs, { t0 = t, dur = dur, from = s, to = nextStop, fn = fn, path = 1 })
		t = t + dur
	end
	return legs, t
end

-- Subway: for each path, a terminal dwell at its first stop, then hop from stop
-- to stop with a dwell at each one in between (the last stop is the next path's
-- first). Legs carry the name of the station (dwell) or the next one (moving).
local function subwayTimeline(route)
	local legs = {}
	local t = 0
	for p, stops in ipairs(route.stops) do
		local names = route.stopNames[p]
		table.insert(legs, { t0 = t, dur = route.terminalDwell, from = stops[1], to = stops[1], dwell = true, path = p, station = names[1], terminal = true })
		t = t + route.terminalDwell
		for i = 1, #stops - 1 do
			local dur, fn = hop(math.abs(stops[i + 1] - stops[i]), route.speed, route.accel)
			table.insert(legs, { t0 = t, dur = dur, from = stops[i], to = stops[i + 1], fn = fn, path = p, station = names[i + 1] })
			t = t + dur
			if i + 1 < #stops then
				table.insert(legs, { t0 = t, dur = route.dwell, from = stops[i + 1], to = stops[i + 1], dwell = true, path = p, station = names[i + 1] })
				t = t + route.dwell
			end
		end
	end
	return legs, t
end

-- The leg running at time t, and the distance along its path.
local function legAt(r, time)
	local t = time % r.cycle
	local legs = r.legs
	local lo, hi = 1, #legs
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if legs[mid].t0 <= t then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local leg = legs[lo]
	if leg.dwell then
		return leg, leg.from
	end
	local d = leg.fn(math.clamp(t - leg.t0, 0, leg.dur))
	local sign = leg.to >= leg.from and 1 or -1
	return leg, leg.from + sign * d
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local function labelOf(part)
	local gui = part:FindFirstChildWhichIsA("SurfaceGui")
	return gui and gui:FindFirstChildWhichIsA("TextLabel")
end

local function setupCar(name)
	local model = vehicles:WaitForChild(name)
	local pivot = model:GetPivot()
	local car = { model = model, parts = {}, offsets = {}, doors = {}, heads = {}, beams = {}, screens = {}, dests = {}, last = nil }
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(car.parts, part)
			table.insert(car.offsets, pivot:ToObjectSpace(part.CFrame))
			if part.Name == "Door" then
				car.doors[#car.parts] = { side = part:GetAttribute("Side") or 1, slide = part:GetAttribute("Slide") or 0 }
			elseif part.Name == "Head" then
				table.insert(car.heads, part)
			elseif part.Name == "Beam" then
				table.insert(car.beams, part)
			elseif part.Name == "Screen" or part.Name == "Dest" then
				local label = labelOf(part)
				if label then
					table.insert(part.Name == "Screen" and car.screens or car.dests, label)
				end
			end
		end
	end
	return car
end

local surface, subway = {}, {}
for _, data in ipairs(HttpService:JSONDecode(routesValue.Value)) do
	local r = data
	if r.kind == "subway" then
		r.pathObjs = { makePath(r.paths[1], false), makePath(r.paths[2], false) }
		r.legs, r.cycle = subwayTimeline(r)
		r.trainObjs = {}
		for _, names in ipairs(r.trains) do
			local train = { cars = {}, dir = nil, screenText = nil, destText = nil }
			for _, name in ipairs(names) do
				table.insert(train.cars, setupCar(name))
			end
			table.insert(r.trainObjs, train)
		end
		table.insert(subway, r)
	else
		r.pathObj = makePath(r.points, true)
		r.legs, r.cycle = loopTimeline(r, r.pathObj.total)
		r.carModels = {}
		for _, name in ipairs(r.cars) do
			table.insert(r.carModels, setupCar(name))
		end
		table.insert(surface, r)
	end
end
do
	local count = 0
	for _, r in ipairs(subway) do
		for _, t in ipairs(r.trainObjs) do
			count = count + #t.cars
		end
	end
	for _, r in ipairs(surface) do
		count = count + #r.carModels
	end
	print(string.format("[Transit] client running %d subway lines, %d surface routes, %d vehicles", #subway, #surface, count))
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function insideCar(cf, carLength, halfW, height, position)
	local p = cf:PointToObjectSpace(position)
	return math.abs(p.X) < halfW and math.abs(p.Z) < carLength / 2 and p.Y > -1 and p.Y < height
end

local carried = false
local function place(car, cf, doorsOpen, platformX, root, carLength, halfW, height)
	-- Carry the local player along if they're inside this car.
	if root and car.last and not carried and insideCar(car.last, carLength, halfW, height, root.Position) then
		root.CFrame = cf * car.last:ToObjectSpace(root.CFrame)
		carried = true
	end
	car.last = cf
	local platformSide = 0
	if doorsOpen and platformX then
		platformSide = (platformX - cf.Position.X) > 0 and 1 or -1
	end
	local cframes = table.create(#car.parts)
	for i, offset in ipairs(car.offsets) do
		local target = cf * offset
		local door = car.doors[i]
		if door and platformSide ~= 0 then
			local worldSide = (cf:VectorToWorldSpace(Vector3.new(door.side, 0, 0))).X > 0 and 1 or -1
			if worldSide == platformSide then
				target = target * CFrame.new(0, 0, door.slide)
			end
		end
		cframes[i] = target
	end
	Workspace:BulkMoveTo(car.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Headlights on the leading end, tail lights on the trailing end, the rest off.
-- Cars face north (local -Z), so End = -1 is a car's north end.
local function setLights(train, dir)
	local n = #train.cars
	for k, car in ipairs(train.cars) do
		for _, head in ipairs(car.heads) do
			local e = head:GetAttribute("End")
			local colour, neon = LAMP_OFF, false
			if (k == n and e == -1) or (k == 1 and e == 1) then
				local leading = (e == -1) == (dir == "N")
				colour, neon = leading and HEAD_ON or TAIL_ON, true
			end
			head.Color = colour
			head.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
		for _, beam in ipairs(car.beams) do
			local e = beam:GetAttribute("End")
			local on = (k == n and e == -1 and dir == "N") or (k == 1 and e == 1 and dir == "S")
			local light = beam:FindFirstChildWhichIsA("SpotLight")
			if light then
				light.Enabled = on
			end
		end
	end
end

local function setText(train, screen, dest)
	if train.screenText ~= screen then
		train.screenText = screen
		for _, car in ipairs(train.cars) do
			for _, label in ipairs(car.screens) do
				label.Text = screen
			end
		end
	end
	if train.destText ~= dest then
		train.destText = dest
		for _, car in ipairs(train.cars) do
			for _, label in ipairs(car.dests) do
				label.Text = dest
			end
		end
	end
end

RunService.PreSimulation:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	carried = false

	for _, r in ipairs(subway) do
		local spacing = r.carLength + r.carGap
		local halfW, height = r.carWidth / 2 - 0.3, r.carHeight + 2
		for k, train in ipairs(r.trainObjs) do
			local leg, s = legAt(r, now - (k - 1) * r.headway)
			local path = r.pathObjs[leg.path]
			local sign = r.signs[leg.path]
			local n = #train.cars
			for c, car in ipairs(train.cars) do
				local centre = s + sign * (c - (n + 1) / 2) * spacing
				place(car, carCFrame(path, centre, r.carLength, sign), leg.dwell == true, r.platformX, root, r.carLength, halfW, height)
			end
			local dir = leg.path == 1 and "N" or "S"
			if train.dir ~= dir then
				train.dir = dir
				setLights(train, dir)
			end
			local dest = r.dests[leg.path]
			local screen
			if leg.dwell then
				screen = leg.terminal and (leg.station .. " · TO " .. dest) or leg.station
			else
				screen = "NEXT: " .. leg.station
			end
			setText(train, screen, "1  " .. dest)
		end
	end

	for _, r in ipairs(surface) do
		local cars = r.carModels
		for k, car in ipairs(cars) do
			local leg, s = legAt(r, now + r.cycle * (k - 1) / #cars)
			place(car, carCFrame(r.pathObj, s, r.carLength, 1), leg.dwell == true, r.platformX, root, r.carLength, 4.6, 11)
		end
	end
end)
