-- Level of detail for things that cost frame time but can't be seen from far
-- away, on this client only (nothing is removed from the world):
--   * Lights: a light is switched off while the camera is well beyond its
--     reach (its range plus a margin), and back on as you come near. With the
--     mall's lights, street lights and shop lights that's ~1,700 lights, of
--     which only the nearby ones can light anything you see.
--   * Signs: small SurfaceGuis (store names, menus, labels) stop drawing past
--     SIGN_DISTANCE studs, where their text is too small to read anyway. Big
--     billboards keep their full distance.
-- Lights that start switched off (the trains' headlights) are left alone:
-- their own scripts switch those.
local Workspace = game:GetService("Workspace")

local LIGHT_MARGIN = 70 -- studs beyond a light's range before it's switched off
local SIGN_DISTANCE = 160
local BIG_SIGN = 30 -- a sign on a part this big (studs) is a billboard
local CHECK = 0.35 -- seconds between passes
local PER_PASS = 900 -- lights looked at per pass (the rest next time)

local lights = {} -- light -> true (managed)
local list = {}
local dirty = false

local function considerLight(l)
	if lights[l] or not l.Enabled then
		return
	end
	-- (lights that start switched off, such as the trains' headlights, are
	-- switched by their own scripts and left alone)
	local part = l.Parent
	if not (part and part:IsA("BasePart")) then
		return
	end
	lights[l] = true
	table.insert(list, l)
end

local function considerGui(g)
	local part = g.Parent
	if part and part:IsA("BasePart") then
		local s = part.Size
		-- (MaxDistance 0 means "no limit", the default)
		if math.max(s.X, s.Y, s.Z) < BIG_SIGN and (g.MaxDistance == 0 or g.MaxDistance > SIGN_DISTANCE) then
			g.MaxDistance = SIGN_DISTANCE
		end
	end
end

local function consider(d)
	if d:IsA("Light") then
		considerLight(d)
	elseif d:IsA("SurfaceGui") then
		considerGui(d)
	end
end

for _, d in ipairs(Workspace:GetDescendants()) do
	consider(d)
end
Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Light") or d:IsA("SurfaceGui") then
		-- set up after its properties are in (replicated objects arrive whole,
		-- but locally made ones are filled in right after)
		task.defer(consider, d)
	end
end)
Workspace.DescendantRemoving:Connect(function(d)
	if lights[d] then
		lights[d] = nil
		dirty = true
	end
end)

local cursor = 1
task.spawn(function()
	while true do
		task.wait(CHECK)
		if dirty then
			dirty = false
			local keep = {}
			for _, l in ipairs(list) do
				if lights[l] then
					table.insert(keep, l)
				end
			end
			list = keep
			cursor = 1
		end
		local cam = Workspace.CurrentCamera
		if cam and #list > 0 then
			local pos = cam.CFrame.Position
			local n = math.min(PER_PASS, #list)
			for _ = 1, n do
				if cursor > #list then
					cursor = 1
				end
				local l = list[cursor]
				cursor += 1
				local part = l.Parent
				if part and part:IsA("BasePart") then
					local far = (part.Position - pos).Magnitude > l.Range + LIGHT_MARGIN
					if l.Enabled == far then
						l.Enabled = not far
					end
				end
			end
		end
	end
end)
