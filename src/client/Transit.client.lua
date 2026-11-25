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
--
-- The subway runs on "service time" (server time minus delays the server has
-- announced in TransitClock), so a delay slows every train to a stop together.
-- Departure boards, signals and announcements all read the same timetable.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
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
-- Service clock (delays)
---------------------------------------------------------------------------
local clockValue = ReplicatedStorage:WaitForChild("TransitClock")
local clock = HttpService:JSONDecode(clockValue.Value)
clockValue.Changed:Connect(function()
	clock = HttpService:JSONDecode(clockValue.Value)
end)

-- Service seconds lost to one delay by wall time `wall`: the line slows to a stop
-- over `ramp`, holds, then speeds back up over `ramp`.
local function lostIn(e, wall)
	local u = wall - e.t0
	local R, hold = e.ramp, e.hold
	if u <= 0 then
		return 0
	elseif u < R then
		return u * u / (2 * R)
	elseif u < R + hold then
		return R / 2 + (u - R)
	elseif u < 2 * R + hold then
		local v = u - R - hold
		return R / 2 + hold + (v - v * v / (2 * R))
	end
	return R + hold
end

local function serviceTime(wall)
	local t = wall - clock.offset
	for _, e in ipairs(clock.events) do
		t = t - lostIn(e, wall)
	end
	return t
end

-- The delay announced or running now, and the service seconds it still has to cost.
local function activeDelay(wall)
	for _, e in ipairs(clock.events) do
		if wall >= e.t0 - 4 and wall < e.t0 + 2 * e.ramp + e.hold then
			return e, (e.ramp + e.hold) - lostIn(e, wall)
		end
	end
	return nil, 0
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
		-- When (in the timetable) a train reaches each platform: dwell starts.
		r.arrivals = {}
		for _, leg in ipairs(r.legs) do
			if leg.dwell then
				r.arrivals[leg.station] = r.arrivals[leg.station] or {}
				r.arrivals[leg.station][leg.path == 1 and "N" or "S"] = { o = leg.t0, dwell = leg.dur }
			end
		end
		r.trainObjs = {}
		for _, names in ipairs(r.trains) do
			local train = { cars = {}, dir = nil, screenText = nil, destText = nil }
			for _, name in ipairs(names) do
				table.insert(train.cars, setupCar(name))
			end
			-- Optional sounds (Config.Transit.Sounds): a rumble that follows the train
			-- and a door chime; both fade with distance.
			local sounds = Config.Transit.Sounds
			local holder = train.cars[math.ceil(#train.cars / 2)].parts[1]
			if sounds.TrainRumble and sounds.TrainRumble ~= 0 and holder then
				local rumble = Instance.new("Sound")
				rumble.SoundId = "rbxassetid://" .. sounds.TrainRumble
				rumble.Looped = true
				rumble.Volume = 0.6
				rumble.RollOffMaxDistance = 260
				rumble.Parent = holder
				rumble:Play()
			end
			if sounds.DoorChime and sounds.DoorChime ~= 0 and holder then
				train.doorChime = Instance.new("Sound")
				train.doorChime.SoundId = "rbxassetid://" .. sounds.DoorChime
				train.doorChime.Volume = 0.7
				train.doorChime.RollOffMaxDistance = 160
				train.doorChime.Parent = holder
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
-- Placing vehicles, lights and screens
---------------------------------------------------------------------------
local function insideCar(cf, carLength, halfW, height, position)
	local p = cf:PointToObjectSpace(position)
	return math.abs(p.X) < halfW and math.abs(p.Z) < carLength / 2 and p.Y > -1 and p.Y < height
end

local carried = false
local function place(car, cf, doorsOpen, platformX, root, carLength, halfW, height)
	-- Carry the local player along if they're inside this car.
	local mine = false
	if root and car.last and not carried and insideCar(car.last, carLength, halfW, height, root.Position) then
		root.CFrame = cf * car.last:ToObjectSpace(root.CFrame)
		carried = true
		mine = true
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
	return mine
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

---------------------------------------------------------------------------
-- Announcements (captions, optional chime)
---------------------------------------------------------------------------
local announceSettings = Config.Transit.Announcements
local soundSettings = Config.Transit.Sounds

local captionGui = Instance.new("ScreenGui")
captionGui.Name = "TransitAnnouncements"
captionGui.ResetOnSpawn = false
local captionFrame = Instance.new("Frame")
captionFrame.AnchorPoint = Vector2.new(0.5, 1)
captionFrame.Position = UDim2.new(0.5, 0, 1, -96)
captionFrame.Size = UDim2.fromOffset(640, 62)
captionFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
captionFrame.BackgroundTransparency = 0.15
captionFrame.Visible = false
captionFrame.Parent = captionGui
Instance.new("UICorner", captionFrame).CornerRadius = UDim.new(0, 10)
local captionTag = Instance.new("TextLabel")
captionTag.BackgroundColor3 = Color3.fromRGB(206, 30, 40)
captionTag.Position = UDim2.fromOffset(10, 10)
captionTag.Size = UDim2.fromOffset(64, 42)
captionTag.Font = Enum.Font.GothamBlack
captionTag.TextColor3 = Color3.new(1, 1, 1)
captionTag.TextScaled = true
captionTag.Text = "🔊 TTC"
captionTag.Parent = captionFrame
Instance.new("UICorner", captionTag).CornerRadius = UDim.new(0, 6)
local captionText = Instance.new("TextLabel")
captionText.BackgroundTransparency = 1
captionText.Position = UDim2.fromOffset(84, 6)
captionText.Size = UDim2.new(1, -94, 1, -12)
captionText.Font = Enum.Font.GothamMedium
captionText.TextColor3 = Color3.new(1, 1, 1)
captionText.TextSize = 19
captionText.TextWrapped = true
captionText.TextXAlignment = Enum.TextXAlignment.Left
captionText.Parent = captionFrame
captionGui.Parent = player:WaitForChild("PlayerGui")

local chime = nil
if soundSettings.Chime and soundSettings.Chime ~= 0 then
	chime = Instance.new("Sound")
	chime.SoundId = "rbxassetid://" .. soundSettings.Chime
	chime.Volume = 0.5
	chime.Parent = SoundService
end
local ambience = nil
if soundSettings.StationAmbience and soundSettings.StationAmbience ~= 0 then
	ambience = Instance.new("Sound")
	ambience.SoundId = "rbxassetid://" .. soundSettings.StationAmbience
	ambience.Volume = 0.25
	ambience.Looped = true
	ambience.Parent = SoundService
end

local queue = {}
local lastSaid = 0
local function say(text)
	for _, queued in ipairs(queue) do
		if queued == text then
			return
		end
	end
	if #queue < 3 then
		table.insert(queue, text)
	end
end
task.spawn(function()
	while true do
		task.wait(0.2)
		local text = table.remove(queue, 1)
		if text then
			if chime then
				chime:Play()
			end
			captionText.Text = text
			captionFrame.Visible = true
			lastSaid = os.clock()
			task.wait(announceSettings.ShowFor)
			captionFrame.Visible = false
			task.wait(announceSettings.MinGap)
		end
	end
end)

local function nice(name)
	return name:sub(1, 1) .. name:sub(2):lower()
end

local DELAY_MESSAGES = {
	["MINOR DELAY"] = {
		"Attention passengers. This train is experiencing a minor delay.",
		"Service is currently delayed due to operational conditions. Please allow additional time for your journey.",
	},
	["MODERATE DELAY"] = {
		"Attention passengers. Service on Line 1 is delayed. Please allow additional time for your journey.",
	},
	["MAJOR DELAY"] = {
		"Attention passengers. Service on this line is temporarily delayed. We apologize for the inconvenience. Please listen for further announcements.",
	},
}

-- Where the player is: the station they're in (underground, or up on the
-- Portlands platform), if any.
local function stationAround(line, root)
	if not root then
		return nil
	end
	local p = root.Position
	if math.abs(p.X - line.platformX) > 140 then
		return nil
	end
	for _, st in ipairs(line.stations) do
		if st.elevated then
			if p.Y > 12 and math.abs(p.X - line.platformX) < 40 and math.abs(p.Z - st.z) < 115 then
				return st.name
			end
		elseif p.Y < -3 and math.abs(p.Z - st.z) < 170 then
			return st.name
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Departure boards and signals (twice a second)
---------------------------------------------------------------------------
local function fmt(sec)
	sec = math.max(0, math.floor(sec + 0.5))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local ON_TIME = Color3.fromRGB(120, 230, 120)
local MINOR = Color3.fromRGB(255, 190, 60)
local MAJOR = Color3.fromRGB(255, 80, 70)

local function setBoard(board, rows, statusColour)
	for _, gui in ipairs(board:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			for name, text in pairs(rows) do
				local label = gui:FindFirstChild(name)
				if label then
					label.Text = text
					if name == "Status" then
						label.TextColor3 = statusColour
					end
				end
			end
		end
	end
end

local function updateInfo(line)
	local now = Workspace:GetServerTimeNow()
	local svc = serviceTime(now)
	local event, remaining = activeDelay(now)
	local H = line.headway
	for _, board in ipairs(CollectionService:GetTagged("DepartureBoard")) do
		local station, bound = board:GetAttribute("Station"), board:GetAttribute("Bound")
		local info = line.arrivals[station] and line.arrivals[station][bound]
		if not info then
			setBoard(board, {
				Next = "NO SERVICE ON THIS PLATFORM",
				Following = "TRAINS LEAVE FROM PLATFORM " .. (bound == "N" and "1" or "2"),
				Status = "STATUS  —",
			}, MINOR)
		else
			local since = (svc - info.o) % H
			local untilNext = (info.o - svc) % H
			local rows = {}
			if since < info.dwell then
				rows.Next = "NOW BOARDING"
				rows.Following = "FOLLOWING       " .. fmt(untilNext + remaining)
			elseif event then
				rows.Next = "NEXT TRAIN      DELAYED"
				rows.Following = "NEW ARRIVAL     " .. fmt(untilNext + remaining)
			elseif untilNext < 10 then
				rows.Next = "NEXT TRAIN      ARRIVING"
				rows.Following = "FOLLOWING       " .. fmt(untilNext + H)
			else
				rows.Next = "NEXT TRAIN      " .. fmt(untilNext)
				rows.Following = "FOLLOWING       " .. fmt(untilNext + H)
			end
			local colour = ON_TIME
			if event then
				rows.Status = "STATUS  " .. event.kind
				colour = event.kind == "MINOR DELAY" and MINOR or MAJOR
			else
				rows.Status = "STATUS  ON TIME"
			end
			setBoard(board, rows, colour)
		end
	end
	-- Signals: green while a train is about to leave or leaving that platform.
	for _, head in ipairs(CollectionService:GetTagged("RailSignal")) do
		local info = line.arrivals[head:GetAttribute("Station")] and line.arrivals[head:GetAttribute("Station")][head:GetAttribute("Bound")]
		local green = false
		if info then
			local since = (svc - info.o) % H
			green = since > info.dwell - 3 and since < info.dwell + 8
		end
		local red, grn = head:FindFirstChild("Red"), head:FindFirstChild("Green")
		if red and grn then
			red.Material = green and Enum.Material.SmoothPlastic or Enum.Material.Neon
			red.Color = green and Color3.fromRGB(90, 20, 18) or Color3.fromRGB(255, 40, 30)
			grn.Material = green and Enum.Material.Neon or Enum.Material.SmoothPlastic
			grn.Color = green and Color3.fromRGB(60, 255, 120) or Color3.fromRGB(20, 70, 36)
		end
	end
end

if subway[1] then
	task.spawn(function()
		while true do
			updateInfo(subway[1])
			task.wait(0.5)
		end
	end)
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local lastEvent = nil
local wasRiding = false

-- Buses and streetcars charge a fare when you get on (server decides); without a
-- card or a transfer you're put back off at the door.
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local boardVehicle, boardResult = remotes:WaitForChild("BoardVehicle"), remotes:WaitForChild("BoardResult")
local boardedCar = nil
boardResult.OnClientEvent:Connect(function(name, ok)
	if ok or not boardedCar or boardedCar.model.Name ~= name or not boardedCar.last then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = boardedCar.last * CFrame.new(4.5 + 4, 3, 0)
	end
end)

RunService.PreSimulation:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local svc = serviceTime(now)
	local event = activeDelay(now)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	carried = false
	local ridingAny = false

	for _, r in ipairs(subway) do
		local spacing = r.carLength + r.carGap
		local halfW, height = r.carWidth / 2 - 0.3, r.carHeight + 2
		local here = stationAround(r, root)
		for k, train in ipairs(r.trainObjs) do
			local tl = svc - (k - 1) * r.headway
			local leg, s = legAt(r, tl)
			local path = r.pathObjs[leg.path]
			local sign = r.signs[leg.path]
			local n = #train.cars
			local riding = false
			local outer = r.sidePlatformX and r.sidePlatformX[leg.station]
			local platformX = outer and outer[leg.path] or r.platformX
			for c, car in ipairs(train.cars) do
				local centre = s + sign * (c - (n + 1) / 2) * spacing
				if place(car, carCFrame(path, centre, r.carLength, sign), leg.dwell == true, platformX, root, r.carLength, halfW, height) then
					riding = true
				end
			end
			ridingAny = ridingAny or riding
			local dir = leg.path == 1 and "N" or "S"
			if train.dir ~= dir then
				train.dir = dir
				setLights(train, dir)
			end
			local dest = r.dests[leg.path]
			local names = r.stopNames[leg.path]
			local lastStop = leg.station == names[#names]

			-- Screens and destination signs.
			local screen
			if leg.dwell then
				screen = leg.terminal and (leg.station .. " · TO " .. dest) or ("NOW AT " .. leg.station)
			elseif event then
				screen = "DELAYED · NEXT: " .. leg.station
			else
				screen = "NEXT: " .. leg.station
			end
			setText(train, screen, "1  " .. dest)

			-- Announcements when this train starts a new leg, and before its doors close.
			if train.leg ~= leg then
				local first = train.leg == nil
				train.leg = leg
				train.closingSaid = false
				if not first then
					if leg.dwell then
						if riding then
							if leg.terminal then
								say(string.format("This is %s. This train now returns to %s.", nice(leg.station), nice(dest)))
							else
								say(string.format("This is %s station.", nice(leg.station)))
							end
						elseif here == leg.station then
							say(string.format("The train to %s is now boarding. Please allow passengers to exit before boarding.", nice(dest)))
						end
					else
						if riding then
							if lastStop then
								say(string.format("Next station: %s. This is the last stop.", nice(leg.station)))
							else
								say(string.format("Next station: %s.", nice(leg.station)))
							end
						elseif here == leg.station then
							local goingTo = lastStop and r.dests[3 - leg.path] or dest
							say(string.format("The next train to %s is now approaching. Please stand behind the yellow line.", nice(goingTo)))
						end
					end
				end
			end
			if leg.dwell and not train.closingSaid and (leg.t0 + leg.dur - (tl % r.cycle)) < 3 then
				train.closingSaid = true
				if train.doorChime then
					train.doorChime:Play()
				end
				if riding or here == leg.station then
					say(string.format("Please stand clear of the doors. This train is going to %s.", nice(dest)))
				end
			end
		end

		-- Delay announcements for anyone in a station or on a train.
		if event ~= lastEvent then
			if (here or wasRiding) then
				if event then
					local options = DELAY_MESSAGES[event.kind] or DELAY_MESSAGES["MINOR DELAY"]
					say(options[math.random(1, #options)])
				else
					say("Service on Line 1 is now resuming. Thank you for your patience.")
				end
			end
			lastEvent = event
		end
		-- A quiet reminder now and then.
		if here and os.clock() - lastSaid > announceSettings.ReminderEvery and #queue == 0 then
			lastSaid = os.clock()
			say("For your safety, please stand behind the yellow line.")
		end
		if ambience then
			if here and not ambience.Playing then
				ambience:Play()
			elseif not here and ambience.Playing then
				ambience:Stop()
			end
		end
	end
	wasRiding = ridingAny

	local onSurface = nil
	for _, r in ipairs(surface) do
		local cars = r.carModels
		for k, car in ipairs(cars) do
			local leg, s = legAt(r, now + r.cycle * (k - 1) / #cars)
			if place(car, carCFrame(r.pathObj, s, r.carLength, 1), leg.dwell == true, r.platformX, root, r.carLength, 4.6, 11) then
				onSurface = car
			end
		end
	end
	if onSurface ~= boardedCar then
		boardedCar = onSurface
		if onSurface then
			boardVehicle:FireServer(onSurface.model.Name)
		end
	end
end)
