--!strict
-- The STAMINA SHOP card (Lane 3, beta; Adam 2026-11-05, built straight in Studio with his OK to skip the Figma step). It opens from
-- the STAMINA kiosk's circle on every Launch Pad (PadParts.kiosks), the hubs a player stands on just before a run. It shows the
-- Stamina a run starts with now and after the next upgrade, drawn as the run's own bolts (yellow holds 1, red 2, purple 3), the ten
-- levels, and one BUY button with the PREVIEW price. It never decides anything: BUY fires BuyStaminaLevel with no arguments, the
-- server checks the Cash and the level, and the card redraws from the server's attributes (BetaStaminaLevel, BetaCash) and shows
-- the server's reply (BetaResult) when it is refused. Short of Cash it says NEED $X MORE from the numbers, never from text.
--
--   Panel.open()   Panel.close()   Panel.isOpen()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BetaConfig = require(Shared:WaitForChild("Beta"):WaitForChild("BetaConfig"))
local EconomyPreview = require(Shared:WaitForChild("UI"):WaitForChild("EconomyPreview"))
local Format = require(Shared.UI:WaitForChild("Format"))
local Tokens = require(Shared.UI:WaitForChild("Tokens"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local UI = script.Parent.Parent
local Prototype = UI:WaitForChild("Prototype")
local CarKit = require(Prototype:WaitForChild("CarKit"))
local Motion = require(Prototype:WaitForChild("Motion"))
local Sounds = require(Prototype:WaitForChild("Sounds"))
local StaminaBolt = require(Prototype:WaitForChild("Run"):WaitForChild("StaminaBolt")) :: any
local RunStamina = require(script.Parent.RunStamina)

local make = CarKit.make
local player = Players.LocalPlayer

local Panel = {}

local SPENT = Color3.fromRGB(60, 68, 92)
local trove: any = nil

local function level(): number
	local v = player:GetAttribute(BetaConfig.StaminaAttribute)
	return if type(v) == "number" then v else 0
end

local function cash(): number?
	local v = player:GetAttribute(BetaConfig.CashAttribute)
	return if type(v) == "number" then v else nil
end

-- Round 7 (P-03): waits a moment for the remote (a slow join) instead of giving up at once
local function remote(name: string): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
		or ReplicatedStorage:WaitForChild(BetaConfig.NetName, 5)
	local r = net and (net:FindFirstChild(name) or net:WaitForChild(name, 3))
	return if r and r:IsA("RemoteEvent") then r else nil
end

-- A row of up to five bolts for a Stamina amount, all full, in the tier's colour.
local function boltRow(parent: Instance, stamina: number, px: number, name: string): Frame
	local tier, count = RunStamina.layout(stamina)
	local row = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset((px * 0.8 + 6) * 5, px),
		ZIndex = 5,
	}, parent) :: Frame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, row)
	for i = 1, count do
		-- the last bolt is only part full when the amount is not a whole number of bolts
		local part = math.clamp(stamina - (i - 1) * tier.per, 0, tier.per) / tier.per
		local holder = make("Frame", {
			Name = "Bolt" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(StaminaBolt.metrics(px, nil, 0.9), px),
			LayoutOrder = i,
			ZIndex = 5,
		}, row)
		StaminaBolt.new(holder, { height = px, colour = SPENT, slim = 0.9, z = 5 })
		local clip = make("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, part),
			ZIndex = 6,
		}, holder)
		local lit = StaminaBolt.new(clip, { height = px, colour = tier.colour, slim = 0.9, z = 6, shine = true })
		lit.root.AnchorPoint = Vector2.new(0, 1)
		lit.root.Position = UDim2.fromScale(0, 1)
	end
	return row
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
		Name = "Lane3StaminaShop",
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
		top = Color3.fromRGB(70, 40, 150),
		bottom = Color3.fromRGB(14, 16, 50),
		bolts = true,
		z = 3,
		name = "Card",
	})
	CarKit.pattern(card, "chevron", { color = Color3.fromRGB(200, 170, 255), transparency = 0.9, z = 3 })
	-- Round 7 (H-03): the panel says the kiosk's name
	CarKit.title(card, "PIT STOP", math.max(math.round(52 * k), 30), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, math.round(10 * k)),
		size = UDim2.new(1, 0, 0, math.round(58 * k)),
		top = CarKit.Yellow,
		bottom = CarKit.Orange,
		z = 6,
		name = "Title",
	})
	CarKit.text(card, "More hops in every run", math.max(math.round(20 * k), 14), {
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

	-- the middle: NOW and NEXT, as bolts
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundColor3 = Color3.fromRGB(8, 10, 32),
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
	CarKit.text(card, "PREVIEW price", 14, {
		align = Enum.TextXAlignment.Right,
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -16, 1, -math.round(22 * k)),
		size = UDim2.fromOffset(120, 18),
		color = Color3.fromRGB(200, 190, 240),
		stroke = 1,
		z = 7,
		name = "Preview",
	})

	local waiting = false
	local shownLevel = -1

	local function draw()
		content:Clean()
		local lvl = level()
		local now = EconomyPreview.staminaFor(lvl)
		local top = lvl >= EconomyPreview.StaminaMaxLevel
		local nextStamina = EconomyPreview.staminaFor(lvl + 1)
		local boltPx = math.max(math.round(34 * k), 22)
		local half = (w - math.round(36 * k)) / 2
		local function column(x: number, heading: string, stamina: number, colour: Color3)
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
			local row = boltRow(col, stamina, boltPx, "Row")
			row.AnchorPoint = Vector2.new(0.5, 0)
			row.Position = UDim2.new(0.5, 0, 0, math.round(42 * k))
			CarKit.title(col, string.format("%d HOPS", stamina), math.max(math.round(26 * k), 18), {
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -math.round(46 * k)),
				size = UDim2.new(1, 0, 0, math.round(34 * k)),
				z = 6,
			})
		end
		column(0, "NOW", now, Color3.fromRGB(200, 210, 240))
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
			column(half, "NEXT  (+1 hop)", nextStamina, CarKit.Yellow)
		end

		-- the ten levels: a pill each, coloured by the bolt tier that level gives
		local pillW = (w - 40 - 9 * 6) / EconomyPreview.StaminaMaxLevel
		for i = 1, EconomyPreview.StaminaMaxLevel do
			local tier = RunStamina.layout(EconomyPreview.staminaFor(i))
			local pill = content:Add(make("Frame", {
				Name = "Level" .. i,
				BackgroundColor3 = if i <= lvl then tier.colour else SPENT,
				Position = UDim2.fromOffset((i - 1) * (pillW + 6), 0),
				Size = UDim2.new(0, pillW, 1, 0),
				ZIndex = 5,
			}, levelsRow)) :: Frame
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
			make("UIStroke", { Color = CarKit.Ink, Thickness = 2 }, pill)
		end

		local price = EconomyPreview.staminaPrice(lvl + 1)
		local have = cash()
		if top or not price then
			buy.setText("MAX LEVEL")
			buy.setTone("Grey")
			buy.setEnabled(false)
			status.Text =
				string.format("Level %d of %d: every run starts with %d hops", lvl, EconomyPreview.StaminaMaxLevel, now)
		elseif have and have < price then
			buy.setText("NEED " .. Format.cash(price - have) .. " MORE")
			buy.setTone("Grey")
			buy.setEnabled(false)
			status.Text = string.format(
				"Level %d of %d  ·  next costs %s",
				lvl,
				EconomyPreview.StaminaMaxLevel,
				Format.cash(price)
			)
		else
			buy.setText(if waiting then "..." else "BUY " .. Format.cash(price))
			buy.setTone("Green")
			buy.setEnabled(not waiting)
			status.Text = string.format("Level %d of %d", lvl, EconomyPreview.StaminaMaxLevel)
		end
		if shownLevel >= 0 and lvl > shownLevel then
			-- Round 7 (U-07): the buy moment: the bolts charge up and sparks fly (Reduce Motion: the sound only)
			pcall(Sounds.play, "Unlock")
			if not Motion.reduced() then
				Motion.pop(card, 1.06)
				local flash = make("Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 240, 120),
					BackgroundTransparency = 0.35,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 8,
				}, card)
				make("UICorner", { CornerRadius = UDim.new(0, 18) }, flash)
				Motion.tween(flash, "flash", Motion.info(0.45), { BackgroundTransparency = 1 })
				for i = 1, 14 do
					local spark = make("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.4),
						Size = UDim2.fromOffset(30, 30),
						Text = "⚡",
						TextScaled = true,
						TextColor3 = if i % 2 == 0 then Color3.fromRGB(255, 226, 60) else Color3.fromRGB(110, 230, 255),
						Rotation = i * 25,
						ZIndex = 9,
					}, card)
					local angle = i / 14 * math.pi * 2
					Motion.tween(spark, "spark", Motion.info(0.6), {
						Position = UDim2.new(0.5, math.cos(angle) * 170, 0.4, math.sin(angle) * 120),
						TextTransparency = 1,
						Rotation = i * 25 + 90,
					})
					task.delay(0.65, function()
						spark:Destroy()
					end)
				end
				task.delay(0.5, function()
					flash:Destroy()
				end)
			end
		end
		shownLevel = lvl
	end

	t:Connect(buy.root.Activated, function()
		if waiting then
			return
		end
		local r = remote(BetaConfig.Remotes.BuyStaminaLevel)
		if not r then
			status.Text = "The shop is not ready yet. Try again in a moment."
			warn("[CarHopBeta] Stamina BUY: CarHopBetaNet." .. BetaConfig.Remotes.BuyStaminaLevel .. " not found")
			return
		end
		waiting = true
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
			if what ~= "BuyStaminaLevel" then
				return
			end
			waiting = false
			draw()
			if not ok and reason then
				status.Text = reason
			end
		end)
	end
	t:Connect(player:GetAttributeChangedSignal(BetaConfig.StaminaAttribute), draw)
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
