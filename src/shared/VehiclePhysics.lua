-- Raycast vehicle physics shared by the server (parked cars) and the driving client.
-- Each wheel casts a ray down from its mount. A spring-damper holds the body up, and
-- tyre forces (grip, drive, brakes) are applied as impulses to the chassis. The wheel
-- parts are cosmetic and are only moved by the client that drives the car.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config).Car

local VehiclePhysics = {}

VehiclePhysics.WHEELS = { "FL", "FR", "RL", "RR" }

-- How far below its mount a wheel centre sits when the car is at rest.
function VehiclePhysics.staticDrop()
	local omega = 2 * math.pi * Config.SpringFrequency
	local compression = Workspace.Gravity / (omega * omega)
	return Config.SuspensionRest - compression
end

-- Height of a wheel mount above the ground when the car is at rest.
function VehiclePhysics.restMountHeight()
	return VehiclePhysics.staticDrop() + Config.WheelRadius
end

function VehiclePhysics.new(model)
	local chassis = model:WaitForChild("Chassis")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	local state = {
		model = model,
		chassis = chassis,
		steerAngle = 0,
		speed = 0,
		flipTimer = 0,
		nextFilter = 0,
		rayParams = params,
		wheels = {},
	}
	local staticDrop = VehiclePhysics.staticDrop()
	for _, name in ipairs(VehiclePhysics.WHEELS) do
		local wheelPart = model:WaitForChild("Wheel_" .. name)
		table.insert(state.wheels, {
			att = chassis:WaitForChild("Mount_" .. name),
			motor = wheelPart:WaitForChild("Motor"),
			front = string.sub(name, 1, 1) == "F",
			drop = staticDrop,
			spin = 0,
		})
	end
	return state
end

local function refreshFilter(state)
	local list = { state.model }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	state.rayParams.FilterDescendantsInstances = list
end

local function moveToward(current, target, maxDelta)
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

local function sign(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	end
	return 0
end

-- input = { throttle = -1..1, steer = -1..1, handbrake = bool }
function VehiclePhysics.step(state, input, dt, updateVisuals)
	local chassis = state.chassis
	if not chassis.Parent or chassis.Anchored then
		return
	end
	local now = os.clock()
	if now >= state.nextFilter then
		refreshFilter(state)
		state.nextFilter = now + 0.5
	end

	local P = Config
	local cf = chassis.CFrame
	local up = cf.UpVector
	local forward = cf.LookVector
	local mass = chassis.AssemblyMass
	local com = chassis.AssemblyCenterOfMass
	local vel = chassis.AssemblyLinearVelocity
	local angVel = chassis.AssemblyAngularVelocity
	local speed = vel:Dot(forward)
	state.speed = speed

	-- Steering: smooth the wheel angle, and allow less lock at high speed.
	local speedRatio = math.clamp(math.abs(speed) / P.MaxSpeed, 0, 1)
	local maxAngle = P.MaxSteerAngle + (P.HighSpeedSteerAngle - P.MaxSteerAngle) * speedRatio
	local steerInput = input.steer
	local rate = P.SteerRate
	if math.abs(steerInput) < 0.01 then
		rate = P.SteerReturnRate
	end
	state.steerAngle = moveToward(state.steerAngle, steerInput * maxAngle, rate * dt)
	local steerRad = math.rad(state.steerAngle)

	-- Engine and brake demand (accelerations).
	local throttle = input.throttle
	local driveAccel, brakeAccel = 0, 0
	if throttle > 0.01 then
		if speed < -2 then
			brakeAccel = P.BrakeDecel * throttle
		else
			local r = math.clamp(speed / P.MaxSpeed, 0, 1)
			driveAccel = P.Acceleration * throttle * (1 - r * r)
		end
	elseif throttle < -0.01 then
		if speed > 2 then
			brakeAccel = P.BrakeDecel * -throttle
		else
			local r = math.clamp(-speed / P.ReverseMaxSpeed, 0, 1)
			driveAccel = -P.ReverseAcceleration * -throttle * (1 - r)
		end
	end

	local quarterMass = mass / 4
	local omega = 2 * math.pi * P.SpringFrequency
	local k = quarterMass * omega * omega
	local c = 2 * P.DampingRatio * math.sqrt(k * quarterMass)
	local rayLength = P.SuspensionRest + P.WheelRadius
	local steerRotation = CFrame.fromAxisAngle(up, -steerRad)
	local grounded = 0

	for _, wheel in ipairs(state.wheels) do
		local mountPos = wheel.att.WorldPosition
		local result = Workspace:Raycast(mountPos, -up * rayLength, state.rayParams)
		if result then
			grounded = grounded + 1
			local compression = rayLength - result.Distance
			wheel.drop = result.Distance - P.WheelRadius
			local contact = result.Position
			local pointVel = vel + angVel:Cross(contact - com)

			-- Suspension spring and damper.
			local load = math.max(0, k * compression - c * pointVel:Dot(up))
			chassis:ApplyImpulseAtPosition(up * load * dt, mountPos)

			-- Tyre frame.
			local wheelForward = forward
			if wheel.front then
				wheelForward = steerRotation:VectorToWorldSpace(forward)
			end
			local wheelRight = wheelForward:Cross(up)
			local lateralSpeed = pointVel:Dot(wheelRight)
			local longSpeed = pointVel:Dot(wheelForward)

			-- Sideways grip cancels sliding; the handbrake loosens the rear.
			local grip = P.FrontGrip
			if not wheel.front then
				grip = input.handbrake and P.HandbrakeGrip or P.RearGrip
			end
			local lateralImpulse = -lateralSpeed * quarterMass * grip

			-- Drive (rear wheels), brakes and rolling resistance.
			local longImpulse = 0
			if not wheel.front and driveAccel ~= 0 then
				longImpulse = driveAccel * (mass / 2) * dt
			end
			local stopping = brakeAccel
			if input.handbrake and not wheel.front then
				stopping = math.max(stopping, P.HandbrakeDecel)
			end
			if stopping == 0 and math.abs(throttle) < 0.01 then
				stopping = P.CoastDecel
			end
			if stopping > 0 then
				local maxStop = math.abs(longSpeed) * quarterMass
				longImpulse = longImpulse - sign(longSpeed) * math.min(stopping * quarterMass * dt, maxStop)
			end

			-- Friction circle: a tyre can only push so hard for the load on it.
			local maxImpulse = load * dt * P.TireFriction
			local total = math.sqrt(lateralImpulse * lateralImpulse + longImpulse * longImpulse)
			if total > maxImpulse and total > 0 then
				local s = maxImpulse / total
				lateralImpulse = lateralImpulse * s
				longImpulse = longImpulse * s
			end

			-- Apply partway up toward the centre of mass to limit body roll.
			local height = (com - contact):Dot(up)
			local applyAt = contact + up * (height * (1 - P.RollInfluence))
			chassis:ApplyImpulseAtPosition(wheelRight * lateralImpulse + wheelForward * longImpulse, applyAt)

			wheel.spin = (wheel.spin - longSpeed / P.WheelRadius * dt) % (2 * math.pi)
		else
			wheel.drop = P.SuspensionRest
			wheel.spin = (wheel.spin - speed / P.WheelRadius * dt) % (2 * math.pi)
		end
	end

	if grounded > 0 then
		chassis:ApplyImpulse(-vel * vel.Magnitude * P.AirDrag * mass * dt)
	end

	-- Flip recovery: if the car is on its side or roof and nearly still, set it upright.
	if up.Y < 0.3 and vel.Magnitude < 8 then
		state.flipTimer = state.flipTimer + dt
		if state.flipTimer > 2 then
			state.flipTimer = 0
			local look = Vector3.new(forward.X, 0, forward.Z)
			if look.Magnitude < 0.1 then
				look = Vector3.new(0, 0, -1)
			end
			local pos = chassis.Position + Vector3.new(0, 4, 0)
			chassis.CFrame = CFrame.lookAt(pos, pos + look.Unit)
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
		end
	else
		state.flipTimer = 0
	end

	if updateVisuals then
		local staticDrop = VehiclePhysics.staticDrop()
		for _, wheel in ipairs(state.wheels) do
			local steer = 0
			if wheel.front then
				steer = -steerRad
			end
			wheel.motor.Transform = CFrame.new(0, -(wheel.drop - staticDrop), 0)
				* CFrame.Angles(0, steer, 0)
				* CFrame.Angles(wheel.spin, 0, 0)
		end
	end
end

return VehiclePhysics
