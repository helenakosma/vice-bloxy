-- Driveable cars: builds the car model, handles getting in and out (door animation,
-- network ownership), and simulates parked cars on the server.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config).Car
local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local Remotes = require(script.Parent.Remotes)

local Cars = {}

local PAINTS = {
	Color3.fromRGB(22, 22, 25), -- black
	Color3.fromRGB(228, 228, 225), -- white
	Color3.fromRGB(160, 163, 168), -- silver
	Color3.fromRGB(68, 70, 74), -- graphite
	Color3.fromRGB(24, 36, 66), -- navy
	Color3.fromRGB(92, 20, 26), -- maroon
	Color3.fromRGB(28, 52, 40), -- dark green
	Color3.fromRGB(120, 105, 85), -- champagne
}
local TAXI_YELLOW = Color3.fromRGB(242, 186, 22)
local TRIM = Color3.fromRGB(32, 32, 34)
local GLASS = Color3.fromRGB(22, 28, 34)

-- Car-local layout (origin = chassis centre, forward = -Z, driver on the left).
local WHEEL_MOUNTS = {
	FL = Vector3.new(-2.95, -0.6, -4.7),
	FR = Vector3.new(2.95, -0.6, -4.7),
	RL = Vector3.new(-2.95, -0.6, 4.6),
	RR = Vector3.new(2.95, -0.6, 4.6),
}
local CHASSIS_SIZE = Vector3.new(6.6, 2, 14.6)
local DOOR_HINGE = Vector3.new(-3.6, -0.15, -2.1)
local DOOR_OPEN_ANGLE = math.rad(-65)

local cars = {} -- model -> car record
local carsBySeat = {} -- seat -> car record
local pendingEnter = {} -- player -> car record

local function newPart(model, name, size, localCF, chassis, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = chassis.CFrame * localCF
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Body panels shared by driveable and parked cars.
local function buildBody(model, chassis, paint, isTaxi)
	local function body(name, size, pos, color, material, rot)
		local cf = CFrame.new(pos)
		if rot then
			cf = cf * rot
		end
		local p = newPart(model, name, size, cf, chassis, color, material)
		weld(chassis, p)
		return p
	end

	local lower = body("BodyLower", Vector3.new(7, 2, 15.2), Vector3.new(0, -0.5, 0), paint)
	lower.Reflectance = 0.12
	body("Hood", Vector3.new(6.8, 0.5, 4.6), Vector3.new(0, 0.62, -5), paint).Reflectance = 0.12
	body("Trunk", Vector3.new(6.8, 0.5, 3), Vector3.new(0, 0.62, 5.9), paint).Reflectance = 0.12

	local cabin = body("Greenhouse", Vector3.new(6.4, 2, 5.2), Vector3.new(0, 1.7, 1.3), GLASS, Enum.Material.Glass)
	cabin.Transparency = 0.3
	cabin.Reflectance = 0.3
	body("Roof", Vector3.new(6.5, 0.3, 5), Vector3.new(0, 2.85, 1.1), paint).Reflectance = 0.12
	local windshield = body("Windshield", Vector3.new(6.3, 0.15, 3), Vector3.new(0, 1.75, -2.85), GLASS, Enum.Material.Glass, CFrame.Angles(math.rad(-40), 0, 0))
	windshield.Transparency = 0.35
	windshield.Reflectance = 0.35
	local rear = body("RearWindow", Vector3.new(6.3, 0.15, 2.4), Vector3.new(0, 1.75, 4.3), GLASS, Enum.Material.Glass, CFrame.Angles(math.rad(40), 0, 0))
	rear.Transparency = 0.35
	rear.Reflectance = 0.35

	body("BumperFront", Vector3.new(7.1, 0.8, 0.7), Vector3.new(0, -1.1, -7.75), TRIM)
	body("BumperRear", Vector3.new(7.1, 0.8, 0.7), Vector3.new(0, -1.1, 7.75), TRIM)
	body("Grille", Vector3.new(3.6, 0.7, 0.2), Vector3.new(0, -0.1, -7.65), Color3.fromRGB(12, 12, 12))
	for _, x in ipairs({ -2.5, 2.5 }) do
		body("Headlight", Vector3.new(1.4, 0.55, 0.2), Vector3.new(x, -0.05, -7.65), Color3.fromRGB(255, 246, 222), Enum.Material.Neon)
		body("Taillight", Vector3.new(1.4, 0.5, 0.2), Vector3.new(x, 0, 7.65), Color3.fromRGB(190, 18, 28), Enum.Material.Neon)
		body("Mirror", Vector3.new(0.35, 0.45, 0.7), Vector3.new(x * 1.5, 1.2, -1.6), paint)
	end
	if isTaxi then
		body("TaxiSign", Vector3.new(2.4, 0.9, 1), Vector3.new(0, 3.45, 1.1), Color3.fromRGB(255, 244, 200), Enum.Material.Neon)
		body("TaxiStripe", Vector3.new(7.05, 0.3, 9), Vector3.new(0, -0.2, 0.5), Color3.fromRGB(20, 20, 20))
	end
	return lower
end

local function buildWheel(model, chassis, name, mount, staticDrop, withMotor)
	local center = mount - Vector3.new(0, staticDrop, 0)
	local tire = newPart(model, "Wheel_" .. name, Vector3.new(1.1, Config.WheelRadius * 2, Config.WheelRadius * 2), CFrame.new(center), chassis, Color3.fromRGB(24, 24, 24), Enum.Material.Rubber, Enum.PartType.Cylinder)
	local rim = newPart(model, "Rim", Vector3.new(1.16, 1.6, 1.6), CFrame.new(center), chassis, Color3.fromRGB(175, 177, 182), Enum.Material.Metal, Enum.PartType.Cylinder)
	weld(tire, rim)
	if withMotor then
		local motor = Instance.new("Motor6D")
		motor.Name = "Motor"
		motor.Part0 = chassis
		motor.Part1 = tire
		motor.C0 = CFrame.new(center)
		motor.C1 = CFrame.new()
		motor.Parent = tire
	else
		weld(chassis, tire)
	end
	return tire
end

local function setDoor(car, open)
	local goal = car.doorClosedC0
	if open then
		goal = goal * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)
	end
	TweenService:Create(car.doorMotor, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = goal }):Play()
end

local function refreshPrompt(car)
	car.prompt.Enabled = not car.busy and car.seat.Occupant == nil
end

-- Spawns a driveable car. cframe = ground position and facing of the car.
function Cars.spawn(cframe, options)
	options = options or {}
	local isTaxi = options.taxi
	local paint = isTaxi and TAXI_YELLOW or (options.color or PAINTS[math.random(1, #PAINTS)])

	local model = Instance.new("Model")
	model.Name = isTaxi and "Taxi" or "Car"

	local mountHeight = VehiclePhysics.restMountHeight()
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = CHASSIS_SIZE
	chassis.CFrame = cframe * CFrame.new(0, mountHeight + 0.6 + 0.2, 0)
	chassis.Transparency = 1
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0, 1, 1)
	chassis.Parent = model
	model.PrimaryPart = chassis

	buildBody(model, chassis, paint, isTaxi)

	-- Headlight beams.
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 45
	beam.Angle = 55
	beam.Brightness = 2.5
	beam.Color = Color3.fromRGB(255, 240, 210)
	beam.Parent = chassis

	-- Driver door on a Motor6D hinge so it can swing open.
	local door = newPart(model, "DriverDoor", Vector3.new(0.25, 1.9, 3.8), CFrame.new(DOOR_HINGE + Vector3.new(0, 0, 1.9)), chassis, paint)
	door.Reflectance = 0.12
	local doorWindow = newPart(model, "DoorWindow", Vector3.new(0.15, 1.5, 3.4), CFrame.new(DOOR_HINGE + Vector3.new(0, 1.75, 1.9)), chassis, GLASS, Enum.Material.Glass)
	doorWindow.Transparency = 0.3
	weld(door, doorWindow)
	local doorMotor = Instance.new("Motor6D")
	doorMotor.Name = "DoorHinge"
	doorMotor.Part0 = chassis
	doorMotor.Part1 = door
	doorMotor.C0 = CFrame.new(DOOR_HINGE)
	doorMotor.C1 = CFrame.new(0, 0, -1.9)
	doorMotor.Parent = door

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.2, 0.8, 2.4)
	seat.CFrame = chassis.CFrame * CFrame.new(-1.5, -0.9, 0.6)
	seat.Transparency = 1
	seat.Massless = true
	seat.CanCollide = false
	seat.CanTouch = false -- only the enter prompt seats players
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Parent = model
	weld(chassis, seat)

	local staticDrop = VehiclePhysics.staticDrop()
	for name, mount in pairs(WHEEL_MOUNTS) do
		local att = Instance.new("Attachment")
		att.Name = "Mount_" .. name
		att.Position = mount
		att.Parent = chassis
		buildWheel(model, chassis, name, mount, staticDrop, true)
	end

	local doorOutside = Instance.new("Attachment")
	doorOutside.Name = "DoorOutside"
	doorOutside.Position = Vector3.new(-6, -0.5, -0.3)
	doorOutside.Parent = chassis

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = isTaxi and "Taxi" or "Car"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = doorOutside

	CollectionService:AddTag(model, "Car")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- stream the whole car at once
	model.Parent = options.parent or Workspace
	pcall(function()
		chassis:SetNetworkOwner(nil)
	end)

	local car = {
		model = model,
		chassis = chassis,
		seat = seat,
		prompt = prompt,
		doorMotor = doorMotor,
		doorClosedC0 = doorMotor.C0,
		busy = false,
		state = VehiclePhysics.new(model),
	}
	cars[model] = car
	carsBySeat[seat] = car

	prompt.Triggered:Connect(function(player)
		Cars.requestEnter(player, car)
	end)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if humanoid then
			local player = Players:GetPlayerFromCharacter(humanoid.Parent)
			if player then
				pcall(function()
					chassis:SetNetworkOwner(player)
				end)
				model:SetAttribute("DriverId", player.UserId)
			end
		else
			model:SetAttribute("DriverId", nil)
			car.state.steerAngle = 0
			pcall(function()
				chassis:SetNetworkOwner(nil)
			end)
		end
		refreshPrompt(car)
	end)

	model.Destroying:Connect(function()
		cars[model] = nil
		carsBySeat[seat] = nil
	end)

	return model
end

-- Cheap anchored car for parking along the kerbs.
function Cars.spawnParked(cframe, parent, rng)
	local model = Instance.new("Model")
	model.Name = "ParkedCar"
	local isTaxi = rng:NextNumber() < 0.15
	local paint = isTaxi and TAXI_YELLOW or PAINTS[rng:NextInteger(1, #PAINTS)]

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = CHASSIS_SIZE
	chassis.CFrame = cframe * CFrame.new(0, VehiclePhysics.restMountHeight() + 0.6, 0)
	chassis.Transparency = 1
	chassis.Anchored = true
	chassis.Parent = model
	model.PrimaryPart = chassis

	local function simple(size, pos, color, material, shape)
		local p = newPart(model, "Part", size, CFrame.new(pos), chassis, color, material, shape)
		p.Anchored = true
		return p
	end
	simple(Vector3.new(7, 2, 15.2), Vector3.new(0, -0.5, 0), paint).Reflectance = 0.12
	simple(Vector3.new(6.8, 0.5, 13.2), Vector3.new(0, 0.62, 0), paint)
	local cabin = simple(Vector3.new(6.4, 2, 6.4), Vector3.new(0, 1.7, 0.9), GLASS, Enum.Material.Glass)
	cabin.Reflectance = 0.3
	simple(Vector3.new(6.5, 0.3, 5.8), Vector3.new(0, 2.85, 0.9), paint)
	simple(Vector3.new(7.1, 0.8, 16.2), Vector3.new(0, -1.1, 0), TRIM)
	if isTaxi then
		simple(Vector3.new(2.4, 0.9, 1), Vector3.new(0, 3.45, 0.9), Color3.fromRGB(255, 244, 200), Enum.Material.Neon)
	end
	local staticDrop = VehiclePhysics.staticDrop()
	for _, mount in pairs(WHEEL_MOUNTS) do
		simple(Vector3.new(1.1, Config.WheelRadius * 2, Config.WheelRadius * 2), mount - Vector3.new(0, staticDrop, 0), Color3.fromRGB(24, 24, 24), Enum.Material.Rubber, Enum.PartType.Cylinder)
	end
	chassis.CanCollide = true
	chassis.CanQuery = true
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = parent
	return model
end

function Cars.requestEnter(player, car)
	if car.busy or car.seat.Occupant or pendingEnter[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
		return
	end
	if (root.Position - car.chassis.Position).Magnitude > 18 then
		return
	end

	car.busy = true
	pendingEnter[player] = car
	refreshPrompt(car)
	setDoor(car, true)
	Remotes.EnterBegin:FireClient(player, car.model)

	-- If the client never confirms, release the car.
	task.delay(5, function()
		if pendingEnter[player] == car then
			pendingEnter[player] = nil
			car.busy = false
			setDoor(car, false)
			refreshPrompt(car)
		end
	end)
end

function Cars.init()
	Remotes.EnterDone.OnServerEvent:Connect(function(player, model, ok)
		local car = pendingEnter[player]
		if not car or car.model ~= model then
			return
		end
		pendingEnter[player] = nil
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if ok and humanoid and humanoid.Health > 0 and not car.seat.Occupant then
			car.seat:Sit(humanoid)
		end
		task.delay(0.25, function()
			setDoor(car, false)
		end)
		car.busy = false
		refreshPrompt(car)
	end)

	Remotes.ExitRequest.OnServerEvent:Connect(function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seatPart = humanoid and humanoid.SeatPart
		local car = seatPart and carsBySeat[seatPart]
		if not car or car.busy then
			return
		end
		car.busy = true
		setDoor(car, true)
		local seatWeld = seatPart:FindFirstChild("SeatWeld")
		if seatWeld then
			seatWeld:Destroy()
		end
		Remotes.ExitBegin:FireClient(player, car.model)
		task.delay(0.9, function()
			setDoor(car, false)
			car.busy = false
			refreshPrompt(car)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingEnter[player] = nil
	end)

	-- Parked (driverless) cars are simulated by the server with the handbrake on.
	local parkedInput = { throttle = 0, steer = 0, handbrake = true }
	RunService.PreSimulation:Connect(function(dt)
		for _, car in pairs(cars) do
			if car.model:GetAttribute("DriverId") == nil then
				VehiclePhysics.step(car.state, parkedInput, dt, false)
			end
		end
	end)
end

return Cars
