-- Moves the subway trains and streetcars on every client from the shared server
-- clock, so they're smooth and in the same place for everyone.
--
-- Each route (published by the server as JSON) is a path, a list of stops and
-- timing settings. A vehicle accelerates out of a stop, cruises, brakes into the
-- next, waits with its doors open, and so on (back and forth for the subway, round
-- the loop for the streetcar). If your character is inside a car it is carried
-- along with it, so you can ride.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local routesValue = ReplicatedStorage:WaitForChild("TransitRoutes")
local vehicles = Workspace:WaitForChild("City"):WaitForChild("Transit"):WaitForChild("Vehicles")

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

local function buildTimeline(route, total)
	local legs = {}
	local t = 0
	local function dwell(s, extra)
		local dur = route.dwell * (extra or 1)
		table.insert(legs, { t0 = t, dur = dur, from = s, to = s, dwell = true })
		t = t + dur
	end
	local function move(a, b)
		local dist = math.abs(b - a)
		local dur, fn = hop(dist, route.speed, route.accel)
		table.insert(legs, { t0 = t, dur = dur, from = a, to = b, fn = fn, dist = dist })
		t = t + dur
	end
	local stops = route.stops
	if route.loop then
		for i = 1, #stops do
			dwell(stops[i])
			local nextStop = stops[i + 1] or (stops[1] + total)
			move(stops[i], nextStop)
		end
	else
		for i = 1, #stops do
			dwell(stops[i], (i == 1 or i == #stops) and 1.5 or 1)
			if i < #stops then
				move(stops[i], stops[i + 1])
			end
		end
		for i = #stops, 2, -1 do
			move(stops[i], stops[i - 1])
			if i - 1 > 1 then
				dwell(stops[i - 1])
			end
		end
	end
	return legs, t
end

-- Centre position (distance along the path) and whether the doors are open.
local function positionAt(r, time)
	local t = time % r.cycle
	for _, leg in ipairs(r.legs) do
		if t >= leg.t0 and t < leg.t0 + leg.dur then
			local local_t = t - leg.t0
			if leg.dwell then
				return leg.from, true
			end
			local d = leg.fn(local_t)
			local sign = leg.to >= leg.from and 1 or -1
			return leg.from + sign * d, false
		end
	end
	return r.legs[1].from, true
end

---------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------
local function pointAt(r, s)
	if r.loop then
		s = s % r.total
	else
		s = math.clamp(s, 0, r.total)
	end
	local pts, cum = r.points, r.cum
	-- Binary search for the segment.
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

local function carCFrame(r, centre)
	local reach = r.carLength * 0.35
	local front = pointAt(r, centre + reach)
	local back = pointAt(r, centre - reach)
	local mid = (front + back) / 2
	if (front - back).Magnitude < 0.01 then
		return CFrame.new(mid)
	end
	return CFrame.lookAt(mid, front)
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local routes = {}
for _, data in ipairs(HttpService:JSONDecode(routesValue.Value)) do
	local r = data
	r.points = {}
	for _, p in ipairs(data.points) do
		table.insert(r.points, Vector3.new(p[1], p[2], p[3]))
	end
	r.cum = { 0 }
	for i = 2, #r.points do
		r.cum[i] = r.cum[i - 1] + (r.points[i] - r.points[i - 1]).Magnitude
	end
	r.total = r.cum[#r.cum]
	r.legs, r.cycle = buildTimeline(r, r.total)
	r.carModels = {}
	for _, name in ipairs(r.cars) do
		local model = vehicles:WaitForChild(name)
		local pivot = model:GetPivot()
		local car = { model = model, parts = {}, offsets = {}, doors = {}, last = nil }
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(car.parts, part)
				table.insert(car.offsets, pivot:ToObjectSpace(part.CFrame))
				if part.Name == "Door" then
					car.doors[#car.parts] = { side = part:GetAttribute("Side") or 1, slide = part:GetAttribute("Slide") or 0 }
				end
			end
		end
		table.insert(r.carModels, car)
	end
	table.insert(routes, r)
end

local carCount = 0
for _, r in ipairs(routes) do
	carCount = carCount + #r.carModels
end
print(string.format("[Transit] client running %d routes, %d vehicles", #routes, carCount))

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local HALF_W, HEIGHT = 4.6, 11

local function insideCar(cf, carLength, position)
	local p = cf:PointToObjectSpace(position)
	return math.abs(p.X) < HALF_W and math.abs(p.Z) < carLength / 2 and p.Y > -1 and p.Y < HEIGHT
end

RunService.PreSimulation:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local carried = false

	for _, r in ipairs(routes) do
		local cars = r.carModels
		for k, car in ipairs(cars) do
			local centre, doorsOpen
			if r.singleCars then
				centre, doorsOpen = positionAt(r, now + r.cycle * (k - 1) / #cars)
			else
				local c, open = positionAt(r, now + r.cycle * (r.offset or 0))
				local spacing = r.carLength + r.carGap
				centre = c + (k - (#cars + 1) / 2) * spacing
				doorsOpen = open
			end
			local cf = carCFrame(r, centre)

			-- Carry the local player along if they're inside this car.
			if root and car.last and not carried and insideCar(car.last, r.carLength, root.Position) then
				root.CFrame = cf * car.last:ToObjectSpace(root.CFrame)
				carried = true
			end
			car.last = cf

			local platformSide = 0
			if doorsOpen and r.platformX then
				platformSide = (r.platformX - cf.Position.X) > 0 and 1 or -1
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
	end
end)
