-- Shifts: clocking in and out, the work itself, and pay.
--
--   Café (Grind Coffee): NPC customers queue at the counter. Take an order at the
--     register, make it at the stations in the right order (grinder, espresso,
--     steamer, hot water, oven, cups), hand it over at pick-up. Quick service tips.
--   Clothing store (Metro Threads): ring up customers at the till, carry stock from
--     the stockroom to the rack that needs it, fold the display table.
--   Delivery (Quickdrop): from the phone, any time. Go to a shop to collect an
--     order, then to the drop-off (a real building); paid per delivery by distance.
--
-- Pay for café and store shifts: wage x hours on shift x (FloorShare + rest x
-- performance) + tips, where performance compares tasks done with the tasks
-- expected for the time worked. Pay goes through Economy with the shift's id, so
-- it can only be paid once. Leaving the workplace too long ends the shift.
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Settings = require(ReplicatedStorage.Shared.Economy)
local E = Settings.Employment
local Jobs = require(ReplicatedStorage.Shared.Catalog.Jobs)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local Employment = require(script.Parent.Employment)
local Remotes = require(script.Parent.Parent.Remotes)
local Workplaces = require(script.Parent.Parent.World.Workplaces)
local Buildings = require(script.Parent.Parent.World.Buildings)

local Work = {}

local C = Color3.fromRGB
local shifts = {} -- player -> shift
local sites = {} -- workplace id -> { wp, staff = {player=true}, queue = {}, tasks = {}, lastSpawn }
local rng = Random.new()

local MENU = {
	{ name = "Latte", icon = "☕", steps = { "grind", "espresso", "milk", "cups" } },
	{ name = "Americano", icon = "☕", steps = { "grind", "espresso", "water", "cups" } },
	{ name = "Cappuccino", icon = "☕", steps = { "grind", "espresso", "milk", "cups" } },
	{ name = "Muffin", icon = "🧁", steps = { "oven" } },
	{ name = "Hot chocolate", icon = "🍫", steps = { "milk", "water", "cups" } },
}
local STEP_LABEL = { grind = "Grind beans", espresso = "Pull espresso", milk = "Steam milk", water = "Hot water", oven = "Warm in oven", cups = "Cup & lid" }

local function now()
	return os.clock()
end

local function root(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isOpen(employer)
	local h = Lighting.ClockTime
	local open, close = employer.hours[1], employer.hours[2]
	return h >= open and h < close
end

---------------------------------------------------------------------------
-- A free customer spot (index) at a site, given the things already standing there.
local function freeSpot(site, list)
	for i = 1, #site.wp.customerSpots do
		local used = false
		for _, item in ipairs(list) do
			if item.spot == i then
				used = true
			end
		end
		if not used then
			return i
		end
	end
	return nil
end

-- NPC customers: simple figures that wait at a spot with what they want.
---------------------------------------------------------------------------
local SHIRTS = { C(200, 60, 60), C(40, 90, 170), C(60, 140, 90), C(230, 180, 60), C(120, 80, 160), C(240, 240, 236) }
local SKIN = { C(255, 220, 190), C(230, 180, 140), C(190, 140, 100), C(140, 96, 64), C(100, 70, 50) }

local function npc(parent, cf, label)
	local model = Instance.new("Model")
	model.Name = "Customer"
	local shirt, skin = SHIRTS[rng:NextInteger(1, #SHIRTS)], SKIN[rng:NextInteger(1, #SKIN)]
	local function part(size, offset, colour, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = size
		p.CFrame = cf * offset
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	part(Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt)
	local head = part(Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.7, 0), skin, Enum.PartType.Ball)
	for _, x in ipairs({ -1.4, 1.4 }) do
		part(Vector3.new(0.8, 2, 0.8), CFrame.new(x, 3, 0), skin)
	end
	for _, x in ipairs({ -0.5, 0.5 }) do
		part(Vector3.new(0.9, 2, 0.9), CFrame.new(x, 1, 0), C(40, 44, 60))
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(120, 26)
	tag.StudsOffset = Vector3.new(0, 1.6, 0)
	tag.MaxDistance = 60
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = C(20, 20, 24)
	text.BackgroundTransparency = 0.2
	text.TextColor3 = C(255, 255, 255)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = label
	text.Parent = tag
	Instance.new("UICorner", text).CornerRadius = UDim.new(0, 6)
	tag.Parent = head
	model.PrimaryPart = head
	model.Parent = parent
	return model
end

---------------------------------------------------------------------------
-- Telling the client what's going on (the work panel and waypoints).
---------------------------------------------------------------------------
local function push(player)
	local s = shifts[player]
	if not s then
		Remotes.Push:FireClient(player, { type = "work", active = false })
		return
	end
	local msg = {
		type = "work",
		active = true,
		employerName = s.employer.name,
		title = s.title,
		started = Workspace:GetServerTimeNow() - (now() - s.started),
		length = s.length,
		tasks = s.tasks,
		tips = s.tips,
		earned = s.earned,
	}
	if s.kind == "cafe" then
		if s.order then
			local steps = {}
			for i, step in ipairs(s.order.steps) do
				table.insert(steps, { label = STEP_LABEL[step], done = i <= s.order.done })
			end
			table.insert(steps, { label = "Hand over at PICK UP", done = false })
			msg.task = s.order.icon .. " " .. s.order.name
			msg.steps = steps
		else
			local waiting = #sites[s.workplace.id].queue
			msg.task = waiting > 0 and string.format("%d customer%s waiting · take an order at the register", waiting, waiting == 1 and "" or "s") or "Waiting for customers"
		end
	elseif s.kind == "retail" then
		local site = sites[s.workplace.id]
		local lines = {}
		for _, t in ipairs(site.tasks) do
			table.insert(lines, { label = t.label, done = false })
		end
		msg.task = s.carrying and ("Carrying stock for " .. s.carrying) or (#lines > 0 and "Store tasks" or "Floor's quiet · tidy up")
		msg.steps = lines
	elseif s.kind == "delivery" and s.delivery then
		local d = s.delivery
		msg.task = d.stage == "pickup" and ("Collect the order at " .. d.pickupName) or ("Deliver to " .. d.destName)
		msg.waypoint = d.stage == "pickup" and d.pickup or d.dest
		msg.waypointLabel = d.stage == "pickup" and ("📦 PICK UP · " .. d.pickupName) or "🏠 DROP-OFF"
	end
	Remotes.Push:FireClient(player, msg)
end

local function pushSite(site)
	for player in pairs(site.staff) do
		push(player)
	end
end

---------------------------------------------------------------------------
-- Shifts
---------------------------------------------------------------------------
local function endShift(player, reason)
	local s = shifts[player]
	if not s then
		return
	end
	shifts[player] = nil
	local site = s.workplace and sites[s.workplace.id]
	if site then
		site.staff[player] = nil
		if s.order then
			s.order.takenBy = nil
		end
		if s.carryTask then
			s.carryTask.claimed = nil
		end
	end
	local elapsed = now() - s.started
	local hours = math.min(elapsed, s.length > 0 and s.length or elapsed) / 60
	local pay, performance = 0, 1
	if s.kind ~= "delivery" then
		local expected = math.max(0.5, (E.ExpectedPerHour[s.industry] or 1) * hours)
		performance = math.min(1, s.tasks / expected)
		pay = math.floor(s.wage * hours * (E.FloorShare + (1 - E.FloorShare) * performance) + 0.5)
		if pay > 0 then
			Economy.pay(player, pay, "salary", string.format("%s · %s shift", s.employer.name, s.title), s.id)
		end
	end
	local counts = s.length > 0 and elapsed >= s.length * 0.75 or (s.kind == "delivery" and s.tasks >= 3)
	Employment.recordShift(player, performance, s.tasks, counts)
	local data = PlayerData.get(player)
	if data then
		-- Short log of recent shifts for the Calendar app.
		local log = data.employment.shiftLog or {}
		data.employment.shiftLog = log
		table.insert(log, 1, { employer = s.employer.name, title = s.title, t = os.time(), minutes = math.floor(elapsed / 60 + 0.5), tasks = s.tasks, pay = pay + s.tips + s.earned, performance = s.kind ~= "delivery" and performance or nil })
		while #log > 10 do
			table.remove(log)
		end
	end
	if data and pay + s.tips + s.earned > 0 and not data.achievements.firstPaycheck then
		data.achievements.firstPaycheck = os.time()
	end
	if player.Parent then
		local total = pay + s.tips + s.earned
		Notify.send(player, {
			title = "Shift over · " .. s.employer.name,
			body = string.format("%s%s · %d task%s%s", reason and (reason .. " · ") or "", total > 0 and ("earned " .. ("$" .. total)) or "no pay", s.tasks, s.tasks == 1 and "" or "s",
				s.kind ~= "delivery" and string.format(" · performance %d%%", math.floor(performance * 100 + 0.5)) or ""),
			app = "bank",
			category = "jobs",
		})
		push(player)
	end
	if site then
		pushSite(site)
	end
end

local function startShift(player, workplace)
	local data = PlayerData.get(player)
	if not data or not data.activeCharacterId then
		return false, "Roll for your first character before working"
	end
	local c = data.employment.current
	if not c then
		return false, "You need a job first: open the Jobs app"
	end
	local employer = Jobs.EMPLOYERS[c.employer]
	if workplace and workplace.employer ~= c.employer then
		return false, "You don't work here"
	end
	if shifts[player] then
		return false, "You're already on a shift"
	end
	if not isOpen(employer) then
		return false, string.format("%s is closed. Open %d:00–%d:00", employer.name, employer.hours[1], employer.hours[2])
	end
	local kind = workplace and workplace.kind or "delivery"
	local s = {
		id = HttpService:GenerateGUID(false),
		kind = kind,
		employer = employer,
		employerId = c.employer,
		industry = employer.industry,
		title = c.title,
		level = c.level,
		wage = c.wage or 0,
		started = now(),
		length = kind == "delivery" and 0 or 60 * (c.type == "part" and Settings.ShiftHours.part or Settings.ShiftHours.full),
		tasks = 0,
		tips = 0,
		earned = 0,
		workplace = workplace,
	}
	shifts[player] = s
	if workplace then
		sites[workplace.id].staff[player] = true
	end
	return true
end

---------------------------------------------------------------------------
-- Café
---------------------------------------------------------------------------
local function cafeAction(player, site, station)
	local s = shifts[player]
	if not s or s.workplace ~= site.wp then
		Remotes.notify(player, "Staff only")
		return
	end
	if station == "register" then
		if s.order then
			Remotes.notify(player, "Finish your current order first")
			return
		end
		for _, order in ipairs(site.queue) do
			if not order.takenBy then
				order.takenBy = player
				s.order = order
				push(player)
				return
			end
		end
		Remotes.notify(player, "No customers waiting")
		return
	end
	local order = s.order
	if not order then
		Remotes.notify(player, "Take an order at the register first")
		return
	end
	if station == "pickup" then
		if order.done < #order.steps then
			Remotes.notify(player, "Not ready: " .. STEP_LABEL[order.steps[order.done + 1]])
			return
		end
		local waited = now() - order.created
		local tip = 2
		for _, band in ipairs(E.Tips) do
			if waited <= band[1] then
				tip = band[2]
				break
			end
		end
		s.tasks += 1
		s.tips += tip
		s.order = nil
		Economy.pay(player, tip, "salary", "Tip · " .. order.name, order.id)
		local i = table.find(site.queue, order)
		if i then
			table.remove(site.queue, i)
		end
		if order.npc then
			order.npc:Destroy()
		end
		Remotes.notify(player, string.format("%s served · +$%d tip", order.name, tip))
		pushSite(site)
		return
	end
	local nextStep = order.steps[order.done + 1]
	if station ~= nextStep then
		Remotes.notify(player, "Next: " .. (nextStep and STEP_LABEL[nextStep] or "hand it over at PICK UP"))
		return
	end
	order.done += 1
	push(player)
end

local function cafeTick(site)
	local staff = 0
	for _ in pairs(site.staff) do
		staff += 1
	end
	local t = now()
	-- Customers give up after 100 s.
	for i = #site.queue, 1, -1 do
		local order = site.queue[i]
		if t - order.created > 100 then
			if order.takenBy and shifts[order.takenBy] then
				shifts[order.takenBy].order = nil
				Remotes.notify(order.takenBy, "The customer gave up waiting")
			end
			if order.npc then
				order.npc:Destroy()
			end
			table.remove(site.queue, i)
			pushSite(site)
		end
	end
	if staff == 0 then
		return
	end
	if #site.queue < math.min(#site.wp.customerSpots, 1 + staff) and t - site.lastSpawn > rng:NextNumber(14, 24) then
		site.lastSpawn = t
		local item = MENU[rng:NextInteger(1, #MENU)]
		local spot = freeSpot(site, site.queue)
		if not spot then
			return
		end
		local order = { id = HttpService:GenerateGUID(false), name = item.name, icon = item.icon, steps = item.steps, done = 0, created = t, spot = spot }
		order.npc = npc(site.wp.folder, site.wp.customerSpots[spot], item.icon .. " " .. item.name)
		table.insert(site.queue, order)
		pushSite(site)
	end
end

---------------------------------------------------------------------------
-- Clothing store
---------------------------------------------------------------------------
local function retailAction(player, site, station)
	local s = shifts[player]
	if not s or s.workplace ~= site.wp then
		Remotes.notify(player, "Staff only")
		return
	end
	local function complete(job, message)
		local i = table.find(site.tasks, job)
		if i then
			table.remove(site.tasks, i)
		end
		if job.npc then
			job.npc:Destroy()
		end
		s.tasks += 1
		Remotes.notify(player, message)
		pushSite(site)
	end
	if station == "register" then
		for _, job in ipairs(site.tasks) do
			if job.kind == "checkout" then
				complete(job, "Customer rung up")
				return
			end
		end
		Remotes.notify(player, "Nobody at the till")
	elseif station == "stock" then
		if s.carrying then
			Remotes.notify(player, "You're already carrying stock for " .. s.carrying)
			return
		end
		for _, job in ipairs(site.tasks) do
			if job.kind == "restock" and not job.claimed then
				job.claimed = player
				s.carrying = "Rack " .. job.rack
				s.carryTask = job
				push(player)
				return
			end
		end
		Remotes.notify(player, "No racks need restocking")
	elseif station:sub(1, 4) == "rack" then
		if not s.carryTask then
			Remotes.notify(player, "Grab stock from the stockroom first")
			return
		end
		if "rack" .. s.carryTask.rack ~= station then
			Remotes.notify(player, "This stock goes on " .. s.carrying)
			return
		end
		local job = s.carryTask
		s.carrying, s.carryTask = nil, nil
		complete(job, "Rack restocked")
	elseif station == "table" then
		for _, job in ipairs(site.tasks) do
			if job.kind == "fold" then
				complete(job, "Display folded")
				return
			end
		end
		Remotes.notify(player, "The table looks great already")
	end
end

local function retailTick(site)
	local staff = 0
	for _ in pairs(site.staff) do
		staff += 1
	end
	if staff == 0 then
		return
	end
	local t = now()
	if #site.tasks < 2 + staff and t - site.lastSpawn > rng:NextNumber(10, 18) then
		site.lastSpawn = t
		local roll = rng:NextNumber()
		local job
		local spot = freeSpot(site, site.tasks)
		if roll < 0.45 and spot then
			job = { kind = "checkout", label = "Customer waiting at the till", spot = spot }
			job.npc = npc(site.wp.folder, site.wp.customerSpots[spot], "🛍 Checkout")
		elseif roll < 0.8 then
			local rack = rng:NextInteger(1, 3)
			job = { kind = "restock", rack = rack, label = "Restock Rack " .. rack .. " (stock in the stockroom)" }
		else
			job = { kind = "fold", label = "Fold the display table" }
		end
		table.insert(site.tasks, job)
		pushSite(site)
	end
end

---------------------------------------------------------------------------
-- Delivery
---------------------------------------------------------------------------
local destinations = nil -- sidewalk points in front of buildings
local function buildDestinations()
	destinations = {}
	for i, f in ipairs(Buildings.footprints) do
		if i % 3 == 0 then
			local a = math.rad(f[5])
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local p = Vector3.new(f[1], 1, f[2]) + dir * (f[4] / 2 + 4)
			table.insert(destinations, p)
		end
	end
end

local function nextDelivery(player)
	local s = shifts[player]
	local r = root(player)
	if not s or not r then
		return
	end
	if not destinations then
		buildDestinations()
	end
	local here = r.Position
	-- A pickup that's not too far, then a drop-off at a sensible distance from it.
	local candidates = {}
	for _, p in ipairs(Workplaces.pickups) do
		local d = (p.position - here).Magnitude
		if d > 60 and d < 900 then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		candidates = Workplaces.pickups
	end
	if #candidates == 0 then
		Remotes.notify(player, "No orders right now")
		return
	end
	local pickup = candidates[rng:NextInteger(1, #candidates)]
	local dest = nil
	for _ = 1, 40 do
		local p = destinations[rng:NextInteger(1, #destinations)]
		local d = (p - pickup.position).Magnitude
		if d >= E.DeliveryDistance[1] and d <= E.DeliveryDistance[2] then
			dest = p
			break
		end
	end
	dest = dest or destinations[rng:NextInteger(1, #destinations)]
	local distance = (dest - pickup.position).Magnitude
	local bonus = E.DeliveryLevelBonus[math.clamp(s.level, 1, #E.DeliveryLevelBonus)]
	s.delivery = {
		id = HttpService:GenerateGUID(false),
		stage = "pickup",
		pickup = pickup.position,
		pickupName = pickup.name,
		dest = dest,
		destName = "a customer's door",
		distance = distance,
		pay = math.floor((E.DeliveryBase + distance * E.DeliveryPerStud) * bonus + 0.5),
	}
	push(player)
end

local function deliveryTick(player, s)
	local d = s.delivery
	local r = root(player)
	if not d or not r then
		return
	end
	local p = r.Position
	local function near(target, radius)
		local flat = Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude
		return flat < radius and math.abs(p.Y - target.Y) < 14
	end
	if d.stage == "pickup" and near(d.pickup, 12) then
		d.stage = "dropoff"
		d.pickedAt = now()
		Remotes.notify(player, "Order collected · deliver it to the marked door ($" .. d.pay .. ")")
		push(player)
	elseif d.stage == "dropoff" and near(d.dest, 14) then
		-- Too fast for any car means something's wrong: no pay.
		if now() - d.pickedAt < d.distance / 170 then
			Remotes.notify(player, "That was impossibly fast · delivery not counted")
		else
			Economy.pay(player, d.pay, "delivery", "Quickdrop delivery", d.id)
			s.tasks += 1
			s.earned += d.pay
			Remotes.notify(player, string.format("Delivered · +$%d", d.pay))
			local data = PlayerData.get(player)
			if data then
				data.achievements.deliveries = (data.achievements.deliveries or 0) + 1
			end
		end
		s.delivery = nil
		push(player)
		task.delay(3, function()
			if shifts[player] == s then
				nextDelivery(player)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
local function prompt(part, action, object, hold, fn)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = part
	p.Triggered:Connect(fn)
	return p
end

function Work.start()
	-- A job change (new job, quit) ends any shift first, paid as normal.
	Employment.onJobChanged = function(player)
		endShift(player, "Changed jobs")
	end
	PlayerData.onLeaving(function(player)
		endShift(player, "Left the city")
	end)

	for id, wp in pairs(Workplaces.registry) do
		local site = { wp = wp, staff = {}, queue = {}, tasks = {}, lastSpawn = 0 }
		sites[id] = site
		local employer = Jobs.EMPLOYERS[wp.employer]
		prompt(wp.stations.clock, "Clock in / out", employer.name, 0.3, function(player)
			if shifts[player] then
				endShift(player, "Clocked out")
			else
				local ok, err = startShift(player, wp)
				if ok then
					Remotes.notify(player, "Clocked in at " .. employer.name)
					push(player)
					pushSite(site)
				else
					Remotes.notify(player, err)
				end
			end
		end)
		if wp.kind == "cafe" then
			prompt(wp.stations.register, "Take order", "Register", 0, function(player)
				cafeAction(player, site, "register")
			end)
			prompt(wp.stations.pickup, "Hand over", "Pick up", 0, function(player)
				cafeAction(player, site, "pickup")
			end)
			for _, station in ipairs({ "grind", "espresso", "milk", "water", "oven", "cups" }) do
				prompt(wp.stations[station], STEP_LABEL[station], "Bar", 0.6, function(player)
					cafeAction(player, site, station)
				end)
			end
		elseif wp.kind == "retail" then
			prompt(wp.stations.register, "Ring up", "Till", 1.5, function(player)
				retailAction(player, site, "register")
			end)
			prompt(wp.stations.stock, "Grab stock", "Stockroom", 0.8, function(player)
				retailAction(player, site, "stock")
			end)
			prompt(wp.stations.table, "Fold display", "Table", 1.2, function(player)
				retailAction(player, site, "table")
			end)
			for i = 1, 3 do
				prompt(wp.stations["rack" .. i], "Restock", "Rack " .. i, 1, function(player)
					retailAction(player, site, "rack" .. i)
				end)
			end
		end
	end

	-- Phone: start/stop deliveries, end a shift, current state.
	Router.on("work.startDelivery", function(player)
		local c = Employment.current(player)
		if not c or Jobs.EMPLOYERS[c.employer].industry ~= "delivery" then
			return nil, "You need a delivery job"
		end
		local ok, err = startShift(player, nil)
		if not ok then
			return nil, err
		end
		nextDelivery(player)
		return {}
	end)
	Router.on("work.end", function(player)
		if not shifts[player] then
			return nil, "You're not on a shift"
		end
		endShift(player, "Clocked out")
		return {}
	end)
	Router.on("work.state", function(player)
		push(player)
		return { active = shifts[player] ~= nil }
	end)

	-- One loop: customers and tasks, shift timers, leaving the workplace, deliveries.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, site in pairs(sites) do
				if site.wp.kind == "cafe" then
					cafeTick(site)
				else
					retailTick(site)
				end
			end
			for player, s in pairs(shifts) do
				if not player.Parent then
					shifts[player] = nil
				elseif s.length > 0 and now() - s.started >= s.length then
					endShift(player, "Shift complete")
				elseif s.workplace then
					local r = root(player)
					local away = not r or (r.Position - s.workplace.centre).Magnitude > s.workplace.radius
					if away then
						s.awaySince = s.awaySince or now()
						if now() - s.awaySince > E.AwaySeconds then
							endShift(player, "You left work")
						end
					else
						s.awaySince = nil
					end
				elseif s.kind == "delivery" then
					deliveryTick(player, s)
				end
			end
		end
	end)
end

return Work
