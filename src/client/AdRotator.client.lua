-- Rotates every ad in the city (billboards, station screens, train ads) to the
-- next one in the shared library every Config.Ads.RotateEvery seconds. The choice
-- comes from the server clock, so everyone sees the same ad on the same panel.
-- Only text faces rotate; image billboards (decals) stay as they are.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ads = require(Shared:WaitForChild("Ads"))
local Config = require(Shared:WaitForChild("Config"))

local interval = Config.Ads.RotateEvery

local function show(part, t)
	local gui = part:FindFirstChild("AdFace")
	local bg = gui and gui:FindFirstChild("Bg")
	if not bg then
		return
	end
	local ad = Ads.at(part:GetAttribute("AdSeed") or 0, t, interval)
	if part:GetAttribute("AdShowing") == ad[1] then
		return
	end
	part:SetAttribute("AdShowing", ad[1])
	bg.BackgroundColor3 = ad[3]
	local stripe, title, tag = bg:FindFirstChild("Stripe"), bg:FindFirstChild("Title"), bg:FindFirstChild("Tag")
	if stripe then
		stripe.BackgroundColor3 = ad[5]
	end
	if title then
		title.Text = ad[1]
		title.TextColor3 = ad[4]
	end
	if tag then
		tag.Text = ad[2]
		tag.TextColor3 = ad[5]
	end
end

-- Panels that stream in get the current ad straight away.
CollectionService:GetInstanceAddedSignal("AdPanel"):Connect(function(part)
	show(part, Workspace:GetServerTimeNow())
end)

while true do
	local now = Workspace:GetServerTimeNow()
	for _, part in ipairs(CollectionService:GetTagged("AdPanel")) do
		show(part, now)
	end
	-- Wake just after the next change.
	task.wait(interval - (now % interval) + 0.05)
end
