-- TMU uses side platforms. Existing entrance passages arrive at concourse Y.
-- Distances below are gameplay clearances in studs, relative to the track
-- centreline and the north end of the station. Keep this layout local to TMU.
local Util = require(script.Parent.Util)
local Kit = require(script.Parent.StationKit)
local TMU = {}
local V = Vector3.new
local floorColour = Color3.fromRGB(179, 177, 169)
local railColour = Color3.fromRGB(236, 198, 68)
local wallColour = Color3.fromRGB(185, 179, 156)

function TMU.reserve(hole, x, z, length, platform, upper)
	hole(V(x - 46, platform - 1, z), V(x + 46, upper, z + length))
	for _, side in ipairs({-1, 1}) do
		local cx = x + side * 54
		hole(V(cx - 19, platform - 1, z + 30), V(cx + 19, -1.5, z + 106))
		local sx = x + side * 66
		hole(V(sx - 7, platform - 20, z + 36), V(sx + 7, platform + 10, z + 82))
		hole(V(sx - 8, platform - 20, z + 20), V(sx + 8, -1.5, z + 44))
		local aisle = x + side * 75
		hole(V(aisle - 5, platform - 2, z + 31), V(aisle + 5, platform + 11, z + 80))
	end
	hole(V(x - 73, platform - 20, z + 33), V(x + 73, platform - 7, z + 46))
end

-- A server-owned servo carries standing characters using the physics floor.
-- Landing doors stay closed whenever the car is away or travelling.
local function buildLift(folder, x, z, stops)
	local base = stops[1].y
	local anchor = Util.solid(folder, V(1,1,1), CFrame.new(x,base-0.5,z), wallColour, Enum.Material.Metal)
	anchor.CanCollide = false
	anchor.Transparency = 1
	local car = Util.solid(folder,V(9,1,10),anchor.CFrame,floorColour,Enum.Material.Metal)
	car.Name = "PassengerLift"
	local guide = Instance.new("Attachment")
	guide.Axis = Vector3.yAxis
	guide.SecondaryAxis = Vector3.zAxis
	guide.Parent = anchor
	local carriage = guide:Clone()
	carriage.Parent = car
	local drive = Instance.new("PrismaticConstraint")
	drive.Attachment0 = guide
	drive.Attachment1 = carriage
	drive.ActuatorType = Enum.ActuatorType.Servo
	drive.Speed = 7
	drive.ServoMaxForce = 1000000
	drive.Parent = car
	car.Anchored = false
	car:SetNetworkOwner(nil)
	local active, moving = 1, false
	local gates = {}
	local function travel(i)
		if moving or active == i then return end
		moving = true
		gates[active].CanCollide = true
		gates[active].Transparency = 0.25
		drive.TargetPosition = stops[i].y - base
		repeat task.wait(0.1) until not car.Parent or math.abs(car.Position.Y + 0.5 - stops[i].y) < 0.12
		if not car.Parent then return end
		active, moving = i, false
		gates[i].CanCollide = false
		gates[i].Transparency = 1
	end
	local height = stops[#stops].y + 9 - base
	for _, dx in ipairs({-4.8,4.8}) do
		Util.solid(folder,V(0.4,height,10),CFrame.new(x+dx,base+height/2,z),wallColour,Enum.Material.Concrete)
	end
	Util.solid(folder,V(10,height,0.4),CFrame.new(x,base+height/2,z-5.2),wallColour,Enum.Material.Concrete)
	for i, stop in ipairs(stops) do
		local gate = Util.solid(folder,V(9.2,8,0.35),CFrame.new(x,stop.y+4,z+5.2),wallColour,Enum.Material.Glass)
		gates[i] = gate
		gate.CanCollide = i ~= active
		gate.Transparency = i == active and 1 or 0.25
		local call = Instance.new("ProximityPrompt")
		call.ActionText = "Call elevator"
		call.ObjectText = stop.name
		call.MaxActivationDistance = 7
		call.RequiresLineOfSight = false
		call.Parent = gate
		call.Triggered:Connect(function() travel(i) end)
		local button = Instance.new("Attachment")
		button.Position = V(-3.5,3.5+i,0)
		button.Parent = car
		local selectFloor = call:Clone()
		selectFloor.ActionText = stop.name
		selectFloor.ObjectText = "Elevator"
		selectFloor.KeyboardKeyCode = ({Enum.KeyCode.R,Enum.KeyCode.T,Enum.KeyCode.Y})[i]
		selectFloor.UIOffset = Vector2.new(0,45*(i-2))
		selectFloor.Parent = button
		selectFloor.Triggered:Connect(function() travel(i) end)
	end
end

function TMU.build(folder, station, x, z, length, track, platform, upper, hallHalf, gaps, north, northSide)
	local function floor(x0, x1, z0, z1, y, name)
		local part = Util.solid(folder, V(math.abs(x1-x0), 1, z1-z0),
			CFrame.new(x+(x0+x1)/2, y-0.5, z+(z0+z1)/2), floorColour, Enum.Material.Granite)
		part.Name = name
	end
	-- The two entry mezzanines keep the existing street passages on their
	-- original sides. A centred northern passage belongs to its source side.
	local divider = northSide == 1 and -11 or 11
	floor(-hallHalf, hallHalf, 0, 43, upper, "EntryMezzanine")
	Kit.wall(folder, true, x-hallHalf, x+hallHalf, z, upper, -1.5, north, station.tile)
	Kit.wall(folder, false, z, z+43, x+divider, upper, -1.5, {}, station.tile)
	Kit.wall(folder, true, x-hallHalf, x+hallHalf, z+43, upper, -1.5, {}, station.tile)
	local under = platform - 18
	floor(-72, 72, 34, 46, under, "UnpaidUnderpass")
	for _, endZ in ipairs({34,46}) do
		local openings = {{x-72,x-60},{x+60,x+72}}
		Kit.wall(folder,true,x-72,x+72,z+endZ,under,under+10,openings,wallColour)
	end
	Kit.ceiling(folder,x-72,x+72,z+34,z+46,under+10,nil)
	for _, side in ipairs({-1,1}) do
		local function pos(offset, dz, y)
			return V(x+side*offset,y,z+dz)
		end
		local function deck(a,b,c,d,y,name)
			floor(side*a,side*b,c,d,y,name)
		end
		local bound = side < 0 and "S" or "N"
		local destination = side < 0 and "Southbound" or "Northbound"
		local edge = track + 6.5
		deck(edge,45,0,length,platform,destination.."Platform")
		local stripe = Util.deco(folder,V(1,0.08,length),CFrame.new(pos(edge+0.65,length/2,platform+0.04)),railColour,Enum.Material.Concrete)
		stripe.Name = "TactileEdge"
		Kit.wall(folder,false,z,z+length,x+side*45,platform,upper-1,{{z+87,z+103}},station.tile)
		local dir = V(-side,0,0)
		for _, dz in ipairs({18,105,183}) do
			local p = pos(44.3,dz,platform+7)
			Kit.nameSign(folder,CFrame.lookAt(p,p+dir),V(14,3,0.2),"TMU",station.tile,Color3.new(0,0,0))
		end
		local p = pos(43,124,platform+9)
		Kit.departureBoard(folder,CFrame.lookAt(p,p+dir),station.name,bound,upper-1)
		Kit.ceiling(folder,math.min(x+side*edge,x+side*45),math.max(x+side*edge,x+side*45),z,z+length,upper-1,nil)
		local sideGaps = table.clone(gaps[side])
		table.insert(sideGaps,{z+30,z+43})
		Kit.wall(folder,false,z,z+43,x+side*hallHalf,upper,-1.5,sideGaps,station.tile)
		deck(hallHalf,60,30,43,upper,"StairLanding")
		Kit.stairs(folder,pos(53,43,upper),pos(53,70,platform),12,floorColour)
		deck(45,72,70,82,platform,"UnpaidLanding")
		deck(60,72,31,43,upper,"LiftLanding")
		deck(60,79,31,36,platform,"LiftLanding")
		deck(72,79,36,80,platform,"AccessibleAisle")
		deck(60,72,31,34,under,"LiftLanding")
		buildLift(folder,x+side*66,z+26,{
			{y=under,name="Unpaid underpass"},
			{y=platform,name=destination.." fare gates"},
			{y=upper,name="Entrance passage"},
		})
		Kit.ticketMachine(folder,CFrame.new(pos(70,78,platform)))
		Kit.stairs(folder,pos(66,70,platform),pos(66,46,under),12,floorColour)
		deck(45,60,82,104,platform,"PaidLanding")
		-- Two lanes and three cabinets span the 15-stud opening.
		Kit.fareGates(folder,math.min(x+side*45,x+side*60),z+82,platform,1,station.name,
			{{w=6,entry=true},{w=5.7,entry=false}})
		Kit.wall(folder,true,math.min(x+side*60,x+side*72),math.max(x+side*60,x+side*72),z+82,platform,upper-1,{},wallColour)
		local sign = pos(53,79,platform+10)
		Kit.hangingSign(folder,CFrame.lookAt(sign,sign+V(0,0,-1)),14,destination.." / Line 1",upper-1,nil)
		local cross = pos(66,68,platform+9)
		Kit.hangingSign(folder,CFrame.lookAt(cross,cross+V(0,0,1)),12,"Unpaid underpass",upper-1,nil)
	end
end

return TMU
