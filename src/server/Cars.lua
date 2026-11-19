-- Builds simple driveable cars out of a VehicleSeat chassis, hinge-driven wheels
-- and servo-steered front wheels. Seat input (W/S/A/D, arrows) drives the car.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config).Car

local Cars = {}

local function attachment(parent, name, cframe)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cframe
	a.Parent = parent
	return a
end

local function makeWheel(model, seat, offset, steered)
	local r = Config.WheelRadius
	local wheel = Instance.new("Part")
	wheel.Name = "Wheel"
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(1, r * 2, r * 2) -- cylinder axis is X
	wheel.Color = Color3.fromRGB(25, 25, 25)
	wheel.Material = Enum.Material.Rubber
	wheel.CustomPhysicalProperties = PhysicalProperties.new(1, 2, 0, 1, 1)
	wheel.CFrame = seat.CFrame * CFrame.new(offset)
	wheel.TopSurface = Enum.SurfaceType.Smooth
	wheel.BottomSurface = Enum.SurfaceType.Smooth
	wheel.Parent = model

	local mount = seat
	if steered then
		-- Invisible knuckle the wheel spins on; a servo hinge turns it left/right.
		local knuckle = Instance.new("Part")
		knuckle.Name = "Knuckle"
		knuckle.Size = Vector3.new(0.5, 0.5, 0.5)
		knuckle.Transparency = 1
		knuckle.CanCollide = false
		knuckle.CFrame = wheel.CFrame
		knuckle.Parent = model

		-- Rotating the attachment 90 degrees about Z points its X axis up, so the hinge turns about Y.
		local up = CFrame.Angles(0, 0, math.rad(90))
		local steer = Instance.new("HingeConstraint")
		steer.Name = "Steer"
		steer.ActuatorType = Enum.ActuatorType.Servo
		steer.ServoMaxTorque = 1e6
		steer.AngularSpeed = Config.SteerSpeed
		steer.LimitsEnabled = false
		steer.Attachment0 = attachment(seat, "SteerA", CFrame.new(offset) * up)
		steer.Attachment1 = attachment(knuckle, "SteerB", up)
		steer.Parent = knuckle
		mount = knuckle
	end

	local spin = Instance.new("HingeConstraint")
	spin.Name = "Drive"
	spin.ActuatorType = Enum.ActuatorType.Motor
	spin.MotorMaxTorque = Config.Torque
	spin.Attachment0 = attachment(mount, "WheelA", mount == seat and CFrame.new(offset) or CFrame.new())
	spin.Attachment1 = attachment(wheel, "WheelB", CFrame.new())
	spin.Parent = wheel

	return spin, mount ~= seat and mount.Steer or nil
end

function Cars.spawn(position)
	local model = Instance.new("Model")
	model.Name = "Car"

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(6, 1, 12)
	seat.Color = Config.Color
	seat.Material = Enum.Material.SmoothPlastic
	seat.MaxSpeed = 0 -- we drive the wheels ourselves, not the seat's built-in motor
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.CFrame = CFrame.new(position + Vector3.new(0, Config.WheelRadius + 1, 0))
	seat.Parent = model
	model.PrimaryPart = seat

	-- Cabin so it looks like a car.
	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(5, 2, 5)
	cabin.Color = Color3.fromRGB(38, 224, 255)
	cabin.Material = Enum.Material.Glass
	cabin.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0.5)
	cabin.Massless = true
	cabin.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = seat, cabin
	weld.Parent = cabin

	local driven, steers = {}, {}
	local x, front, back = 3.5, -4, 4 -- forward is -Z for a VehicleSeat
	for _, spec in ipairs({
		{ Vector3.new(-x, -0.5, front), true },
		{ Vector3.new(x, -0.5, front), true },
		{ Vector3.new(-x, -0.5, back), false },
		{ Vector3.new(x, -0.5, back), false },
	}) do
		local drive, steer = makeWheel(model, seat, spec[1], spec[2])
		table.insert(driven, drive)
		if steer then
			table.insert(steers, steer)
		end
	end

	model.Parent = Workspace

	-- Apply seat input to the wheels every physics step.
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		-- If the car drives the wrong way, flip the sign on the next line.
		local speed = -seat.ThrottleFloat * Config.MaxSpeed / Config.WheelRadius
		for _, motor in ipairs(driven) do
			motor.AngularVelocity = speed
		end
		-- Steering right (SteerFloat > 0) turns clockwise seen from above, i.e. negative about +Y.
		local angle = -seat.SteerFloat * Config.MaxSteerAngle
		for _, servo in ipairs(steers) do
			servo.TargetAngle = angle
		end
	end)

	return model
end

return Cars
