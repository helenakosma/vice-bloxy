-- Shopping on the client: animations and the basket panel. The server
-- (Services/Shopping) decides everything; this only shows it.
--
--   pickup   the item lifts off the display and arcs into your hand; the basket
--            panel opens or grows
--   paid     the receipt slides in (store, items, total); the panel closes
--   putback  a short note; the panel closes
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Products = require(ReplicatedStorage.Shared.Catalog.Products)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Push = Remotes:WaitForChild("Push")
local Request = Remotes:WaitForChild("Request")

local C = Color3.fromRGB

local gui = Instance.new("ScreenGui")
gui.Name = "Shopping"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = o
end
local function text(parent, size, colour, font, align)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, size + 6)
	t.TextSize = size
	t.TextColor3 = colour
	t.Font = font or Enum.Font.Gotham
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Parent = parent
	return t
end

---------------------------------------------------------------------------
-- The basket panel (bottom right)
---------------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -16, 1, -96)
panel.Size = UDim2.fromOffset(250, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = C(250, 250, 248)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 14)
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 12), UDim.new(0, 12)
pad.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel
local stripe = Instance.new("Frame")
stripe.Size = UDim2.new(1, 0, 0, 4)
stripe.BorderSizePixel = 0
stripe.BackgroundColor3 = C(30, 30, 32)
stripe.LayoutOrder = 0
stripe.Parent = panel
corner(stripe, 2)
local title = text(panel, 16, C(20, 20, 22), Enum.Font.GothamBold)
title.LayoutOrder = 1
local rows = Instance.new("Frame")
rows.BackgroundTransparency = 1
rows.Size = UDim2.new(1, 0, 0, 0)
rows.AutomaticSize = Enum.AutomaticSize.Y
rows.LayoutOrder = 2
rows.Parent = panel
local rowList = Instance.new("UIListLayout")
rowList.Padding = UDim.new(0, 2)
rowList.Parent = rows
local total = text(panel, 15, C(20, 20, 22), Enum.Font.GothamBold, Enum.TextXAlignment.Right)
total.LayoutOrder = 3
local hint = text(panel, 12, C(110, 110, 116))
hint.LayoutOrder = 4
hint.Text = "Pay at the till [F] · walk out and it's put back"
local putBack = Instance.new("TextButton")
putBack.Size = UDim2.new(1, 0, 0, 30)
putBack.BackgroundColor3 = C(236, 236, 234)
putBack.TextColor3 = C(40, 40, 44)
putBack.Font = Enum.Font.GothamMedium
putBack.TextSize = 13
putBack.Text = "Put everything back"
putBack.AutoButtonColor = true
putBack.LayoutOrder = 5
putBack.Parent = panel
corner(putBack, 8)
putBack.Activated:Connect(function()
	pcall(function()
		Request:InvokeServer("shop.putBack", {})
	end)
end)

local function showBasket(b)
	for _, c in ipairs(rows:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if not b or not b.items or #b.items == 0 then
		panel.Visible = false
		return
	end
	title.Text = "Basket · " .. (b.store or "")
	for _, item in ipairs(b.items) do
		local r = text(rows, 13, C(50, 50, 56))
		r.Text = string.format("%s   $%d", item.name, item.price)
	end
	total.Text = string.format("Total  $%d", b.total or 0)
	panel.Visible = true
end

---------------------------------------------------------------------------
-- Animations
---------------------------------------------------------------------------
local function handPart()
	local character = player.Character
	return character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("HumanoidRootPart"))
end

-- The item lifts off the display and arcs into your hand.
local function flyToHand(productId, from)
	local hand = handPart()
	if not hand or typeof(from) ~= "Vector3" then
		return
	end
	local p = Products.get(productId)
	local item = Instance.new("Part")
	item.Anchored = true
	item.CanCollide = false
	item.CanQuery = false
	item.CastShadow = false
	item.Size = Vector3.new(0.9, 0.9, 0.9)
	item.Material = Enum.Material.SmoothPlastic
	item.Color = (p and p.colour) or C(240, 240, 236)
	item.CFrame = CFrame.new(from)
	item.Parent = Workspace
	local glow = Instance.new("SelectionBox")
	glow.Adornee = item
	glow.LineThickness = 0.04
	glow.Color3 = C(255, 255, 255)
	glow.Parent = item
	local start = from
	local t0 = os.clock()
	local DURATION = 0.55
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / DURATION, 0, 1)
		local h = handPart()
		if not h then
			conn:Disconnect()
			item:Destroy()
			return
		end
		local target = h.Position
		local e = 1 - (1 - t) ^ 3
		local pos = start:Lerp(target, e) + Vector3.new(0, math.sin(t * math.pi) * 2.2, 0)
		item.CFrame = CFrame.new(pos) * CFrame.Angles(0, t * math.pi * 2, t * math.pi)
		item.Size = Vector3.new(0.9, 0.9, 0.9) * (1 - 0.6 * e)
		if t >= 1 then
			conn:Disconnect()
			item:Destroy()
		end
	end)
end

-- The receipt card.
local receipt = Instance.new("Frame")
receipt.AnchorPoint = Vector2.new(0.5, 0)
receipt.Position = UDim2.new(0.5, 0, 1, 10)
receipt.Size = UDim2.fromOffset(260, 0)
receipt.AutomaticSize = Enum.AutomaticSize.Y
receipt.BackgroundColor3 = C(252, 252, 250)
receipt.BorderSizePixel = 0
receipt.Visible = false
receipt.Parent = gui
corner(receipt, 6)
local rpad = Instance.new("UIPadding")
rpad.PaddingLeft, rpad.PaddingRight, rpad.PaddingTop, rpad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16), UDim.new(0, 14), UDim.new(0, 14)
rpad.Parent = receipt
local rlist = Instance.new("UIListLayout")
rlist.Padding = UDim.new(0, 3)
rlist.SortOrder = Enum.SortOrder.LayoutOrder
rlist.Parent = receipt

local function showReceipt(msg)
	for _, c in ipairs(receipt:GetChildren()) do
		if c:IsA("TextLabel") or c:IsA("Frame") then
			c:Destroy()
		end
	end
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0, 6)
	band.BorderSizePixel = 0
	band.BackgroundColor3 = typeof(msg.colour) == "Color3" and msg.colour or C(30, 30, 32)
	band.Parent = receipt
	local head = text(receipt, 17, C(20, 20, 22), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	head.Text = msg.store or "Receipt"
	local sub = text(receipt, 11, C(120, 120, 126), Enum.Font.Code, Enum.TextXAlignment.Center)
	sub.Text = "PAID BY CARD · " .. os.date("%H:%M")
	for _, item in ipairs(msg.items or {}) do
		local r = text(receipt, 13, C(40, 40, 44), Enum.Font.Code)
		r.Text = string.format("%-22s $%d", item.name, item.price)
	end
	local tot = text(receipt, 15, C(20, 20, 22), Enum.Font.Code, Enum.TextXAlignment.Right)
	tot.Text = string.format("TOTAL  $%d", msg.total or 0)
	local thanks = text(receipt, 12, C(110, 110, 116), Enum.Font.Gotham, Enum.TextXAlignment.Center)
	thanks.Text = "Thanks for shopping with us"
	receipt.Position = UDim2.new(0.5, 0, 1, 10)
	receipt.Visible = true
	TweenService:Create(receipt, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -260) }):Play()
	task.delay(4, function()
		local out = TweenService:Create(receipt, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1, 10) })
		out:Play()
		out.Completed:Wait()
		receipt.Visible = false
	end)
end

-- A short note at the top of the basket area.
local note = Instance.new("TextLabel")
note.AnchorPoint = Vector2.new(1, 1)
note.Position = UDim2.new(1, -16, 1, -60)
note.Size = UDim2.fromOffset(250, 30)
note.BackgroundColor3 = C(30, 30, 34)
note.BackgroundTransparency = 0.1
note.TextColor3 = C(240, 240, 240)
note.Font = Enum.Font.GothamMedium
note.TextSize = 12
note.TextWrapped = true
note.Visible = false
note.Parent = gui
corner(note, 8)
local function showNote(t)
	note.Text = t
	note.Visible = true
	task.delay(3, function()
		if note.Text == t then
			note.Visible = false
		end
	end)
end

Push.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" or msg.type ~= "shop" then
		return
	end
	if msg.event == "pickup" then
		flyToHand(msg.product, msg.from)
		showBasket(msg.basket)
		local b = msg.basket
		stripe.BackgroundColor3 = (b and typeof(b.colour) == "Color3") and b.colour or C(30, 30, 32)
	elseif msg.event == "paid" then
		showBasket(nil)
		-- the cashier scans each item (a red scanner flash at the till), then the receipt
		if typeof(msg.at) == "Vector3" then
			task.spawn(function()
				for _ = 1, #(msg.items or {}) do
					local beam = Instance.new("Part")
					beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CastShadow = true, false, false, false
					beam.Material = Enum.Material.Neon
					beam.Color = C(255, 40, 40)
					beam.Size = Vector3.new(1.6, 0.05, 0.05)
					beam.CFrame = CFrame.new(msg.at + Vector3.new(0, 2, 0))
					beam.Parent = Workspace
					TweenService:Create(beam, TweenInfo.new(0.22), { Transparency = 1, Size = Vector3.new(2.4, 0.05, 0.05) }):Play()
					task.delay(0.25, function()
						beam:Destroy()
					end)
					task.wait(0.3)
				end
				showReceipt(msg)
			end)
		else
			showReceipt(msg)
		end
	elseif msg.event == "putback" then
		showBasket(nil)
		if msg.reason then
			showNote(msg.reason)
		end
	end
end)
