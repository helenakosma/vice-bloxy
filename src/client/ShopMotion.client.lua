-- Small motions in the shops, played locally and only near the camera:
--   "Spin"  models turn on their pivot (window turntables). Attribute Speed
--           (degrees per second, default 20).
--   "Sway"  hanging garments swing gently on their hangers, more when someone
--           brushes past.
--   "Fold"  a cloth on a table is folded in half twice, lifted on to the pile
--           (attribute StackTo: local offset of the pile's top) and laid out
--           again, over and over.
-- The server builds everything anchored; these only move the client's copy.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SPIN_NEAR = 160
local SWAY_NEAR = 45
local SWAY_MAX = 60
local FOLD_NEAR = 90
local SWAY_HZ = 1 / 15

local base = {} -- instance -> original pivot / cframe
local size = {} -- fold part -> original size
local phase = {}

local function pivotOf(inst)
	if inst:IsA("Model") then
		return inst:GetPivot()
	end
	return inst.CFrame
end

local function remember(inst)
	if not base[inst] then
		base[inst] = pivotOf(inst)
		phase[inst] = math.random() * math.pi * 2
		if inst:IsA("BasePart") then
			size[inst] = inst.Size
		end
	end
	return base[inst]
end

for _, tagName in ipairs({ "Spin", "Sway", "Fold" }) do
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(inst)
		base[inst], size[inst], phase[inst] = nil, nil, nil
	end)
end

-- Which swaying garments are near (recomputed twice a second).
local near = {}
local function refresh(camPos, camLook)
	local list = {}
	for _, m in ipairs(CollectionService:GetTagged("Sway")) do
		if m:IsA("Model") and m.Parent then
			local p = remember(m).Position
			local off = p - camPos
			local d = off.Magnitude
			-- only garments in front of the camera (nothing behind you moves)
			if d < SWAY_NEAR and (d < 6 or off.Unit:Dot(camLook) > 0.35) then
				table.insert(list, { m = m, d = d })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	near = {}
	for i = 1, math.min(SWAY_MAX, #list) do
		near[i] = list[i].m
	end
end

local function rootPositions()
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if r then
			table.insert(out, r.Position)
		end
	end
	local npcs = Workspace:FindFirstChild("ShopNPCs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			local r = m:FindFirstChild("HumanoidRootPart")
			if r then
				table.insert(out, r.Position)
			end
		end
	end
	return out
end

local function foldAt(part, t)
	local cf0, s0 = base[part], size[part]
	local stack = part:GetAttribute("StackTo") or Vector3.new(1.7, 1, 0)
	local cycle = 7
	local x = ((t + phase[part]) % cycle) / cycle
	local cf, sz, hidden = cf0, s0, false
	if x < 0.25 then
		-- laid out flat
	elseif x < 0.45 then
		local k = (x - 0.25) / 0.2 -- fold the far half over
		sz = Vector3.new(s0.X, s0.Y, s0.Z * (1 - 0.5 * k))
		cf = cf0 * CFrame.new(0, 0.05 * k, -s0.Z * 0.25 * k)
	elseif x < 0.62 then
		local k = (x - 0.45) / 0.17 -- then in from the sides
		sz = Vector3.new(s0.X * (1 - 0.4 * k), s0.Y * (1 + k), s0.Z * 0.5)
		cf = cf0 * CFrame.new(0, 0.05 + 0.05 * k, -s0.Z * 0.25)
	elseif x < 0.85 then
		local k = (x - 0.62) / 0.23 -- lift on to the pile
		local from = cf0 * CFrame.new(0, 0.1, -s0.Z * 0.25)
		local to = cf0 * CFrame.new(stack)
		local p = from.Position:Lerp(to.Position, k) + Vector3.new(0, math.sin(k * math.pi) * 1.2, 0)
		sz = Vector3.new(s0.X * 0.6, s0.Y * 2, s0.Z * 0.5)
		cf = CFrame.new(p) * (cf0 - cf0.Position)
	else
		hidden = true
	end
	part.Size = sz
	part.CFrame = cf
	part.Transparency = hidden and 1 or 0
end

local acc, refreshAcc, t = 0, 1, 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position

	for _, inst in ipairs(CollectionService:GetTagged("Spin")) do
		if inst.Parent then
			local cf0 = remember(inst)
			if (cf0.Position - camPos).Magnitude < SPIN_NEAR then
				local speed = math.rad(inst:GetAttribute("Speed") or 20)
				local cf = cf0 * CFrame.Angles(0, (t * speed + phase[inst]) % (math.pi * 2), 0)
				if inst:IsA("Model") then
					inst:PivotTo(cf)
				else
					inst.CFrame = cf
				end
			end
		end
	end

	for _, part in ipairs(CollectionService:GetTagged("Fold")) do
		if part:IsA("BasePart") and part.Parent then
			local cf0 = remember(part)
			if (cf0.Position - camPos).Magnitude < FOLD_NEAR then
				foldAt(part, t)
			end
		end
	end

	refreshAcc += dt
	if refreshAcc > 0.5 then
		refreshAcc = 0
		refresh(camPos, cam.CFrame.LookVector)
	end
	acc += dt
	if acc < SWAY_HZ then
		return
	end
	acc = 0
	local people = rootPositions()
	for _, m in ipairs(near) do
		if m.Parent then
			local cf0 = base[m]
			local amp = 2.5
			for _, p in ipairs(people) do
				local d = (p - cf0.Position).Magnitude
				if d < 4.5 then
					amp = math.max(amp, 12 * (1 - d / 4.5) + 2.5) -- brushed past
				end
			end
			local a = math.sin(t * 1.7 + phase[m]) * math.rad(amp)
			m:PivotTo(cf0 * CFrame.Angles(a, 0, 0))
		end
	end
end)
