--!strict
-- The LUCK SHOP card (Lane 2 preview, Brian L 2026-11-08). The same layout as Adam's STAMINA SHOP card (StaminaPanel), for
-- the LUCK kiosk's circle on every Launch Pad (PadParts.kiosks). Waiting on Adam's review as the Lane 3 owner. It shows the
-- luck a run has now and after the next level, the ten levels, and one BUY with the PREVIEW price. It never decides
-- anything: BUY fires BuyLuckLevel with no arguments, the server checks the Cash and the level, and the card redraws from the
-- server's attributes (BetaLuckLevel, BetaCash) and shows the server's reply (BetaResult). Short of Cash it says
-- NEED $X MORE from the numbers.
--
--   Panel.open()   Panel.close()   Panel.isOpen()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BetaConfig = require(Shared:WaitForChild("Beta"):WaitForChild("BetaConfig"))
local Format = require(Shared:WaitForChild("UI"):WaitForChild("Format"))
local LuckTable = require(Shared:WaitForChild("Catalog"):WaitForChild("LuckTable"))
local Tokens = require(Shared.UI:WaitForChild("Tokens"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local UI = script.Parent.Parent
local Prototype = UI:WaitForChild("Prototype")
local CarKit = require(Prototype:WaitForChild("CarKit"))
local Motion = require(Prototype:WaitForChild("Motion"))

local make = CarKit.make
local player = Players.LocalPlayer

local Panel = {}

local SPENT = Color3.fromRGB(60, 68, 92)
local GREEN = Color3.fromRGB(70, 220, 110)
local GOLD = Color3.fromRGB(255, 205, 60)
local trove: any = nil

local function level(): number
	return LuckTable.clampLevel(player:GetAttribute(BetaConfig.LuckAttribute))
end

local function cash(): number?
	local v = player:GetAttribute(BetaConfig.CashAttribute)
	return if type(v) == "number" then v else nil
end

local function remote(name: string): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	local r = net and net:FindFirstChild(name)
	return if r and r:IsA("RemoteEvent") then r else nil
end

-- Pill colour for a level: green for the first half, gold for the top half.
local function levelColour(i: number): Color3
	return if i <= 5 then GREEN else GOLD
end

function Panel.isOpen(): boolean
	return trove ~= nil
end

function Panel.close()
	if trove then
		trove:Destroy()
		trove = nil
	end
end

function Panel.open()
	if trove then
		return
	end
	trove = Trove.new()
	local t = trove
	local viewport = (Workspace.CurrentCamera :: Camera).ViewportSize
	local scale = Tokens.uiScaleFor(viewport)
	CarKit.setStrokeScale(scale)
	local gui = t:Add(make("ScreenGui", {
		Name = "Lane2LuckShop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))) :: ScreenGui
	make("UIScale", { Scale = scale }, gui)
	local design = viewport / scale
	local dim = make("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, gui) :: TextButton
	t:Connect(dim.Activated, Panel.close)

	local h = math.min(design.Y - 20, 420)
	local w = math.min(design.X - 24, 560)
	local k = h / 420
	local card = CarKit.board(gui, {
		size = UDim2.fromOffset(w, h),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		radius = math.round(22 * k),
		top = Color3.fromRGB(30, 130, 70),
		bottom = Color3.fromRGB(10, 34, 26),
		bolts = true,
		z = 3,
		name = "Card",
	})
	CarKit.pattern(card, "chevron", { color = Color3.fromRGB(170, 255, 190), transparency = 0.9, z = 3 })
	CarKit.title(card, "LUCK SHOP", math.max(math.round(52 * k), 30), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, math.round(10 * k)),
		size = UDim2.new(1, 0, 0, math.round(58 * k)),
		top = CarKit.Yellow,
		bottom = CarKit.Orange,
		z = 6,
		name = "Title",
	})
	CarKit.text(card, "More Rare, Epic and Legendary cars in every run", math.max(math.round(20 * k), 14), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, math.round(66 * k)),
		size = UDim2.new(1, 0, 0, math.round(24 * k)),
		stroke = 1.5,
		z = 6,
		name = "Sub",
	})
	CarKit.button(card, {
		text = "X",
		tone = "Red",
		px = 26,
		size = UDim2.fromOffset(48, 48),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -10, 0, 10),
		z = 8,
		onPress = Panel.close,
		name = "Close",
	})

	-- the middle: NOW and NEXT, as the luck multiplier
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundColor3 = Color3.fromRGB(6, 22, 16),
		BackgroundTransparency = 0.35,
		Position = UDim2.fromOffset(math.round(18 * k), math.round(100 * k)),
		Size = UDim2.new(1, -math.round(36 * k), 0, math.round(150 * k)),
		ZIndex = 4,
	}, card) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, stage)
	local content = t:Extend()
	local levelsRow = make("Frame", {
		Name = "Levels",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, math.round(258 * k)),
		Size = UDim2.fromOffset(w - 40, math.round(26 * k)),
		ZIndex = 5,
	}, card) :: Frame
	local status = CarKit.text(card, "", math.max(math.round(18 * k), 14), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, math.round(292 * k)),
		size = UDim2.new(1, 0, 0, math.round(22 * k)),
		stroke = 1.5,
		z = 6,
		name = "Status",
	})
	local buy = CarKit.button(card, {
		text = "BUY",
		tone = "Green",
		px = math.max(math.round(30 * k), 20),
		size = UDim2.fromOffset(math.round(300 * k), math.max(math.round(60 * k), Tokens.Touch.Primary)),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -math.round(16 * k)),
		z = 8,
		name = "Buy",
	})
	-- centred between the status line and BUY, so a wide NEED $X MORE button never covers it (Brian L, 2026-11-08)
	CarKit.text(card, "PREVIEW prices: not final", 14, {
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 1, -(math.max(math.round(60 * k), Tokens.Touch.Primary) + math.round(16 * k) + 20)),
		size = UDim2.new(1, 0, 0, 18),
		color = Color3.fromRGB(190, 240, 200),
		stroke = 1,
		z = 7,
		name = "Preview",
	})

	local waiting = false
	local shownLevel = -1
	local note: string? = nil

	local function draw()
		content:Clean()
		local lvl = level()
		local top = lvl >= LuckTable.MaxLevel
		local half = (w - math.round(36 * k)) / 2
		local function column(x: number, heading: string, lv: number, colour: Color3)
			local col = content:Add(make("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(x, 0),
				Size = UDim2.new(0, half, 1, 0),
				ZIndex = 5,
			}, stage)) :: Frame
			CarKit.text(col, heading, math.max(math.round(16 * k), 14), {
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, math.round(10 * k)),
				size = UDim2.new(1, 0, 0, math.round(20 * k)),
				color = colour,
				stroke = 1.5,
				z = 6,
			})
			CarKit.title(col, string.format("x%.2f", LuckTable.multiplier(lv)), math.max(math.round(48 * k), 28), {
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, math.round(38 * k)),
				size = UDim2.new(1, 0, 0, math.round(56 * k)),
				top = if lv > 5 then CarKit.Yellow else Color3.fromRGB(150, 255, 170),
				bottom = if lv > 5 then CarKit.Orange else Color3.fromRGB(40, 180, 80),
				z = 6,
			})
			CarKit.text(col, string.format("LUCK  ·  LEVEL %d", lv), math.max(math.round(18 * k), 14), {
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -math.round(40 * k)),
				size = UDim2.new(1, 0, 0, math.round(26 * k)),
				stroke = 1.5,
				z = 6,
			})
		end
		column(0, "NOW", lvl, Color3.fromRGB(200, 230, 210))
		if top then
			CarKit.title(stage, "MAX!", math.max(math.round(40 * k), 24), {
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(half, 0),
				size = UDim2.new(0, half, 1, 0),
				top = CarKit.Yellow,
				bottom = CarKit.Orange,
				z = 6,
			})
		else
			column(half, "NEXT", lvl + 1, CarKit.Yellow)
		end

		-- the ten levels: a pill each, lit up to the player's level
		local pillW = (w - 40 - 9 * 6) / LuckTable.MaxLevel
		for i = 1, LuckTable.MaxLevel do
			local pill = content:Add(make("Frame", {
				Name = "Level" .. i,
				BackgroundColor3 = if i <= lvl then levelColour(i) else SPENT,
				Position = UDim2.fromOffset((i - 1) * (pillW + 6), 0),
				Size = UDim2.new(0, pillW, 1, 0),
				ZIndex = 5,
			}, levelsRow)) :: Frame
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
			make("UIStroke", { Color = CarKit.Ink, Thickness = 2 }, pill)
		end

		local price = LuckTable.price(lvl + 1)
		local have = cash()
		if top or not price then
			buy.setText("MAX LEVEL")
			buy.setTone("Grey")
			buy.setEnabled(false)
			status.Text = string.format("Level %d of %d: the luckiest runs there are", lvl, LuckTable.MaxLevel)
		elseif have and have < price then
			buy.setText("NEED " .. Format.cash(price - have) .. " MORE")
			buy.setTone("Grey")
			buy.setEnabled(false)
			status.Text =
				string.format("Level %d of %d  ·  next costs %s", lvl, LuckTable.MaxLevel, Format.cash(price))
		else
			buy.setText(if waiting then "..." else "BUY " .. Format.cash(price))
			buy.setTone("Green")
			buy.setEnabled(not waiting)
			status.Text = string.format("Level %d of %d", lvl, LuckTable.MaxLevel)
		end
		if note then
			status.Text = note
		end
		if shownLevel >= 0 and lvl > shownLevel and not Motion.reduced() then
			Motion.pop(card, 1.06)
		end
		shownLevel = lvl
	end

	t:Connect(buy.root.Activated, function()
		if waiting then
			return
		end
		local r = remote(BetaConfig.Remotes.BuyLuckLevel)
		if not r then
			status.Text = "The shop is closed in this place."
			return
		end
		waiting = true
		note = nil
		draw()
		r:FireServer()
		task.delay(4, function()
			if waiting and trove == t then
				waiting = false
				draw()
			end
		end)
	end)
	local result = remote(BetaConfig.Remotes.Result)
	if result then
		t:Connect(result.OnClientEvent, function(what: string, ok: boolean, reason: string?)
			if what ~= "BuyLuckLevel" then
				return
			end
			waiting = false
			note = if ok then string.format("Bought! Luck is now x%.2f", LuckTable.multiplier(level())) else reason
			draw()
		end)
	end
	t:Connect(player:GetAttributeChangedSignal(BetaConfig.LuckAttribute), draw)
	t:Connect(player:GetAttributeChangedSignal(BetaConfig.CashAttribute), draw)
	t:Connect(UserInputService.InputBegan, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			Panel.close()
		end
	end)
	draw()
	if not Motion.reduced() then
		Motion.pop(card, 1.04)
	end
end

return Panel
