-- Client side of driving: the get-in / get-out animation, reading controls,
-- running the car physics for the car you drive, and the speedometer.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")).Car
local VehiclePhysics = require(ReplicatedStorage.Shared:WaitForChild("VehiclePhysics"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local EnterBegin = remotes:WaitForChild("EnterBegin")
local EnterDone = remotes:WaitForChild("EnterDone")
local ExitRequest = remotes:WaitForChild("ExitRequest")
local ExitBegin = remotes:WaitForChild("ExitBegin")

local player = Players.LocalPlayer

local current = nil -- { model, seat, state }
local handbrake = false
local animating = false

---------------------------------------------------------------------------
-- Speedometer
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "VehicleHud"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local speedLabel = Instance.new("TextLabel")
speedLabel.AnchorPoint = Vector2.new(1, 1)
speedLabel.Position = UDim2.new(1, -24, 1, -64)
speedLabel.Size = UDim2.fromOffset(200, 60)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.GothamBlack
speedLabel.TextSize = 52
speedLabel.TextXAlignment = Enum.TextXAlignment.Right
speedLabel.TextColor3 = Color3.fromRGB(240, 236, 228)
speedLabel.TextStrokeTransparency = 0.4
speedLabel.Text = "0"
speedLabel.Parent = gui

local unitLabel = Instance.new("TextLabel")
unitLabel.AnchorPoint = Vector2.new(1, 1)
unitLabel.Position = UDim2.new(1, -26, 1, -40)
unitLabel.Size = UDim2.fromOffset(200, 22)
unitLabel.BackgroundTransparency = 1
unitLabel.Font = Enum.Font.GothamBold
unitLabel.TextSize = 16
unitLabel.TextXAlignment = Enum.TextXAlignment.Right
unitLabel.TextColor3 = Color3.fromRGB(200, 195, 185)
unitLabel.TextStrokeTransparency = 0.6
unitLabel.Text = "MPH"
unitLabel.Parent = gui

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(1, 1)
hint.Position = UDim2.new(1, -26, 1, -16)
hint.Size = UDim2.fromOffset(400, 20)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.TextColor3 = Color3.fromRGB(200, 195, 185)
hint.TextStrokeTransparency = 0.7
hint.Text = "W/S drive · A/D steer · Space handbrake · F exit"
hint.Parent = gui

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function getCharacter()
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root then
		return character, humanoid, root
	end
	return nil
end

-- Plays one of the character's default animations (from its Animate script).
local function playDefaultAnimation(character, humanoid, name)
	local animate = character:FindFirstChild("Animate")
	local folder = animate and animate:FindFirstChild(name)
	local animation = folder and folder:FindFirstChildOfClass("Animation")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animation or not animator then
		return nil
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track:Play(0.1)
		return track
	end
	return nil
end

local function easeInOut(a)
	if a < 0.5 then
		return 2 * a * a
	end
	return 1 - ((-2 * a + 2) ^ 2) / 2
end

-- Moves the (anchored) root along an arc. `getTarget` is re-read each frame so the
-- motion follows a car that is still settling.
local function moveArc(root, fromCF, getTarget, height, duration)
	local start = os.clock()
	while true do
		local a = math.clamp((os.clock() - start) / duration, 0, 1)
		local cf = fromCF:Lerp(getTarget(), easeInOut(a))
		root.CFrame = cf + Vector3.new(0, math.sin(a * math.pi) * height, 0)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

---------------------------------------------------------------------------
-- Getting in: walk to the door, face it while it opens, hop into the seat.
---------------------------------------------------------------------------
EnterBegin.OnClientEvent:Connect(function(model)
	if animating then
		EnterDone:FireServer(model, false)
		return
	end
	local character, humanoid, root = getCharacter()
	local chassis = model and model:FindFirstChild("Chassis")
	local seat = model and model:FindFirstChild("DriverSeat")
	local doorOutside = chassis and chassis:FindFirstChild("DoorOutside")
	if not character or not chassis or not seat or not doorOutside then
		EnterDone:FireServer(model, false)
		return
	end
	animating = true

	-- 1. Walk to the driver door.
	local doorPos = doorOutside.WorldPosition
	humanoid:MoveTo(Vector3.new(doorPos.X, root.Position.Y, doorPos.Z))
	local arrived = false
	local conn = humanoid.MoveToFinished:Connect(function()
		arrived = true
	end)
	local t0 = os.clock()
	while not arrived and os.clock() - t0 < 2.5 do
		task.wait()
	end
	conn:Disconnect()

	-- 2. Turn to face the car while the door swings open.
	root.Anchored = true
	local function standCF()
		local p = doorOutside.WorldPosition
		local base = Vector3.new(p.X, root.Position.Y, p.Z)
		local toward = flat(seat.Position - base)
		if toward.Magnitude < 0.1 then
			toward = flat(chassis.CFrame.RightVector)
		end
		return CFrame.lookAt(base, base + toward.Unit)
	end
	moveArc(root, root.CFrame, standCF, 0, 0.25)
	task.wait(0.25)

	-- 3. Duck in: a small hop from the door into the seat.
	local track = playDefaultAnimation(character, humanoid, "jump")
	local function seatCF()
		return seat.CFrame * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.3, 0)
	end
	moveArc(root, root.CFrame, seatCF, 1.6, 0.5)
	if track then
		track:Stop(0.15)
	end
	root.Anchored = false
	animating = false
	EnterDone:FireServer(model, true)
end)

---------------------------------------------------------------------------
-- Getting out: the server unseats us, then we step out beside the door.
---------------------------------------------------------------------------
ExitBegin.OnClientEvent:Connect(function(model)
	local character, humanoid, root = getCharacter()
	local chassis = model and model:FindFirstChild("Chassis")
	local doorOutside = chassis and chassis:FindFirstChild("DoorOutside")
	if not character or not doorOutside then
		return
	end
	animating = true
	root.Anchored = true
	task.wait(0.2) -- let the door start opening
	local track = playDefaultAnimation(character, humanoid, "jump")
	local function outsideCF()
		local p = doorOutside.WorldPosition + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.6, 0)
		local away = flat(-chassis.CFrame.RightVector)
		return CFrame.lookAt(p, p + away)
	end
	moveArc(root, root.CFrame, outsideCF, 1.4, 0.45)
	if track then
		track:Stop(0.15)
	end
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	animating = false
end)

---------------------------------------------------------------------------
-- Driving
---------------------------------------------------------------------------
local function onExitAction(_, inputState)
	if inputState == Enum.UserInputState.Begin and current and not animating then
		ExitRequest:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function onHandbrake(_, inputState)
	handbrake = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	return Enum.ContextActionResult.Sink -- also stops Space from jumping out of the seat
end

local function startDriving(seat)
	local model = seat.Parent
	current = { model = model, seat = seat, state = VehiclePhysics.new(model) }
	handbrake = false
	gui.Enabled = true
	ContextActionService:BindActionAtPriority("ExitVehicle", onExitAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:BindActionAtPriority("Handbrake", onHandbrake, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Handbrake", "Brake")
end

local function stopDriving()
	if current then
		-- Put the cosmetic wheels back to their rest pose.
		for _, wheel in ipairs(current.state.wheels) do
			wheel.motor.Transform = CFrame.new()
		end
	end
	current = nil
	handbrake = false
	gui.Enabled = false
	ContextActionService:UnbindAction("ExitVehicle")
	ContextActionService:UnbindAction("Handbrake")
end

local function readInput(seat)
	local throttle, steer = 0, 0
	local function down(...)
		for _, key in ipairs({ ... }) do
			if UserInputService:IsKeyDown(key) then
				return true
			end
		end
		return false
	end
	if down(Enum.KeyCode.W, Enum.KeyCode.Up) then
		throttle = throttle + 1
	end
	if down(Enum.KeyCode.S, Enum.KeyCode.Down) then
		throttle = throttle - 1
	end
	if down(Enum.KeyCode.D, Enum.KeyCode.Right) then
		steer = steer + 1
	end
	if down(Enum.KeyCode.A, Enum.KeyCode.Left) then
		steer = steer - 1
	end

	if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		for _, inputObject in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
				throttle = throttle + inputObject.Position.Z
			elseif inputObject.KeyCode == Enum.KeyCode.ButtonL2 then
				throttle = throttle - inputObject.Position.Z
			elseif inputObject.KeyCode == Enum.KeyCode.Thumbstick1 and math.abs(inputObject.Position.X) > 0.15 then
				steer = steer + inputObject.Position.X
			end
		end
	end

	-- Touch controls (and anything else) go through the seat's own inputs.
	if throttle == 0 then
		throttle = seat.ThrottleFloat
	end
	if steer == 0 then
		steer = seat.SteerFloat
	end
	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
end

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") and seatPart.Name == "DriverSeat" then
			startDriving(seatPart)
		else
			stopDriving()
		end
	end)
	humanoid.Died:Connect(stopDriving)
end

if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(function(character)
	stopDriving()
	watchCharacter(character)
end)

RunService.PreSimulation:Connect(function(dt)
	if not current then
		return
	end
	if not current.model.Parent then
		stopDriving()
		return
	end
	local throttle, steer = readInput(current.seat)
	VehiclePhysics.step(current.state, { throttle = throttle, steer = steer, handbrake = handbrake }, dt, true)
	speedLabel.Text = tostring(math.floor(math.abs(current.state.speed) * Config.MphPerStud + 0.5))
end)
