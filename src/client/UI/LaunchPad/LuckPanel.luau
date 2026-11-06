--!strict
-- The LUCKY CLOVER card (Round 7, L-01, U-07; decision 0042 item 10). It opens from the Lucky Clover kiosk's circle on every Launch
-- Pad. It shows the luck now and after the next level as big clovers (green for x1.25 and x1.5, gold for x2 and x3, purple for x4),
-- one kid-readable line ("Rare cars show up more often!"), the real odds now and after (R7-S09: "Rare or better: 37% -> 45%" and the
-- Rare, Epic and Legendary shares over a 2 km run), computed from the same shared rule the server uses (src/shared/Run/Luck), the
-- five levels, and one BUY with the PREVIEW price. It never decides anything: BUY fires BuyLuckLevel with no arguments; the server
-- checks the Cash, the level and the account (PolicyService), and the card redraws from the server's attributes. For an account
-- where paid random items are restricted, BUY is replaced by "Not available for your account" (the stand and numbers still show).
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
local Luck = require(Shared:WaitForChild("Run"):WaitForChild("Luck"))
local Tokens = require(Shared.UI:WaitForChild("Tokens"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local UI = script.Parent.Parent
local Prototype = UI:WaitForChild("Prototype")
local CarKit = require(Prototype:WaitForChild("CarKit"))
local Motion = require(Prototype:WaitForChild("Motion"))
local Sounds = require(Prototype:WaitForChild("Sounds")) :: any

local make = CarKit.make
local player = Players.LocalPlayer

local Panel = {}

Panel.RUN_METRES = 2000 -- the odds shown are averaged over a run this long
local GREEN = Color3.fromRGB(70, 200, 90)
local GOLD = Color3.fromRGB(255, 200, 50)
local PURPLE = Color3.fromRGB(176, 84, 255)
local SPENT = Color3.fromRGB(60, 68, 92)
local trove: any = nil

-- Clover colour by level: green (x1.25, x1.5), gold (x2, x3), purple (x4); grey for no luck.
function Panel.colourFor(level: number): Color3
	if level <= 0 then
		return SPENT
	elseif level <= 2 then
		return GREEN
	elseif level <= 4 then
		return GOLD
	end
	return PURPLE
end

local function level(): number
	local v = player:GetAttribute(BetaConfig.LuckAttribute)
	return if type(v) == "number" then v else 0
end

local function cash(): number?
	local v = player:GetAttribute(BetaConfig.CashAttribute)
	return if type(v) == "number" then v else nil
end

local function remote(name: string): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
		or ReplicatedStorage:WaitForChild(BetaConfig.NetName, 5)
	local r = net and (net:FindFirstChild(name) or net:WaitForChild(name, 3))
	return if r and r:IsA("RemoteEvent") then r else nil
end

-- A four-leaf clover drawn from four round leaves and a stem, `px` wide.
local function clover(parent: Instance, px: number, colour: Color3, name: string): Frame
	local holder = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(px, px),
		ZIndex = 6,
	}, parent) :: Frame
	local leaf = px * 0.46
	for i, offset in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		local l = make("Frame", {
			Name = "Leaf" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset.X * leaf * 0.48, 0.45, offset.Y * leaf * 0.48),
			Size = UDim2.fromOffset(leaf, leaf),
			BackgroundColor3 = colour,
			Rotation = 45,
			ZIndex = 6,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, l)
		make("UIStroke", { Color = CarKit.Ink, Thickness = 2 }, l)
		make("UIGradient", {
			Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.35), colour),
			Rotation = 90,
		}, l)
	end
	local stem = make("Frame", {
		Name = "Stem",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.55, 0.62),
		Size = UDim2.fromOffset(math.max(px * 0.07, 3), px * 0.36),
		BackgroundColor3 = colour:Lerp(Color3.new(0, 0, 0), 0.25),
		Rotation = -20,
		ZIndex = 5,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, stem)
	return holder
end

local function pct(n: number): string
	return string.format("%d%%", math.round(n * 100))
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
		Name = "Lane3LuckyClover",
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

	local h = math.min(design.Y - 20, 450)
	local w = math.min(design.X - 24, 600)
	local k = h / 450
	local card = CarKit.board(gui, {
		size = UDim2.fromOffset(w, h),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		radius = math.round(22 * k),
		top = Color3.fromRGB(40, 150, 80),
		bottom = Color3.fromRGB(10, 50, 34),
		bolts = true,
		z = 3,
		name = "Card",
	})
	CarKit.pattern(card, "chevron", { color = Color3.fromRGB(190, 255, 200), transparency = 0.9, z = 3 })
	CarKit.title(card, "LUCKY CLOVER", math.max(math.round(50 * k), 30), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, math.round(8 * k)),
		size = UDim2.new(1, 0, 0, math.round(56 * k)),
		top = CarKit.Yellow,
		bottom = CarKit.Orange,
		z = 6,
		name = "Title",
	})
	CarKit.text(card, "Rare cars show up more often!", math.max(math.round(20 * k), 14), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, math.round(62 * k)),
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

	local stage = make("Frame", {
		Name = "Stage",
		BackgroundColor3 = Color3.fromRGB(4, 24, 16),
		BackgroundTransparency = 0.35,
		Position = UDim2.fromOffset(math.round(18 * k), math.round(94 * k)),
		Size = UDim2.new(1, -math.round(36 * k), 0, math.round(132 * k)),
		ZIndex = 4,
	}, card) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, stage)
	local odds = CarKit.text(card, "", math.max(math.round(17 * k), 14), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(math.round(18 * k), math.round(232 * k)),
		size = UDim2.new(1, -math.round(36 * k), 0, math.round(44 * k)),
		wrap = true,
		stroke = 1.5,
		z = 6,
		name = "Odds",
	})
	local content = t:Extend()
	local levelsRow = make("Frame", {
		Name = "Levels",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, math.round(284 * k)),
		Size = UDim2.fromOffset(w - 40, math.round(24 * k)),
		ZIndex = 5,
	}, card) :: Frame
	local status = CarKit.text(card, "", math.max(math.round(17 * k), 14), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, math.round(314 * k)),
		size = UDim2.new(1, 0, 0, math.round(22 * k)),
		stroke = 1.5,
		z = 6,
		name = "Status",
	})
	local buy = CarKit.button(card, {
		text = "BUY",
		tone = "Green",
		px = math.max(math.round(30 * k), 20),
		size = UDim2.fromOffset(math.round(320 * k), math.max(math.round(60 * k), Tokens.Touch.Primary)),
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
		color = Color3.fromRGB(200, 240, 210),
		stroke = 1,
		z = 7,
		name = "Preview",
	})

	local waiting = false
	local shownLevel = -1

	local function draw()
		content:Clean()
		local lvl = level()
		local top = lvl >= EconomyPreview.LuckMaxLevel
		local nowL = EconomyPreview.luckFor(lvl)
		local nextL = EconomyPreview.luckFor(lvl + 1)
		local px = math.max(math.round(70 * k), 44)
		local half = (w - math.round(36 * k)) / 2
		local function column(x: number, heading: string, lv: number, mult: number, colour: Color3)
			local col = content:Add(make("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(x, 0),
				Size = UDim2.new(0, half, 1, 0),
				ZIndex = 5,
			}, stage)) :: Frame
			CarKit.text(col, heading, math.max(math.round(16 * k), 14), {
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, math.round(6 * k)),
				size = UDim2.new(1, 0, 0, math.round(20 * k)),
				color = colour,
				stroke = 1.5,
				z = 6,
			})
			local c = clover(col, px, Panel.colourFor(lv), "Clover")
			c.AnchorPoint = Vector2.new(0.5, 0)
			c.Position = UDim2.new(0.5, 0, 0, math.round(28 * k))
			CarKit.title(col, string.format("LUCK x%g", mult), math.max(math.round(24 * k), 16), {
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -math.round(32 * k)),
				size = UDim2.new(1, 0, 0, math.round(30 * k)),
				z = 6,
			})
		end
		column(0, "NOW", lvl, nowL, Color3.fromRGB(200, 240, 210))
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
			column(half, "NEXT", lvl + 1, nextL, CarKit.Yellow)
		end
		-- R7-S09: the real numbers before purchase, from the same rule the server spawns with
		local a = Luck.averageShares(nowL, Panel.RUN_METRES)
		local b = Luck.averageShares(if top then nowL else nextL, Panel.RUN_METRES)
		local ra, rb = a.Rare + a.Epic + a.Legendary, b.Rare + b.Epic + b.Legendary
		odds.Text = if top
			then string.format(
				"Rare or better: %s   (Rare %s · Epic %s · Legendary %s, over a 2 km run)",
				pct(ra),
				pct(a.Rare),
				pct(a.Epic),
				pct(a.Legendary)
			)
			else string.format(
				"Rare or better: %s -> %s   (Rare %s · Epic %s -> %s · Legendary %s -> %s, over a 2 km run)",
				pct(ra),
				pct(rb),
				pct(b.Rare),
				pct(a.Epic),
				pct(b.Epic),
				pct(a.Legendary),
				pct(b.Legendary)
			)
		-- the five levels, a small clover pill each
		local pillW = (w - 40 - 4 * 8) / EconomyPreview.LuckMaxLevel
		for i = 1, EconomyPreview.LuckMaxLevel do
			local pill = content:Add(make("TextLabel", {
				Name = "Level" .. i,
				BackgroundColor3 = if i <= lvl then Panel.colourFor(i) else SPENT,
				Position = UDim2.fromOffset((i - 1) * (pillW + 8), 0),
				Size = UDim2.new(0, pillW, 1, 0),
				FontFace = CarKit.display(),
				Text = string.format("x%g", EconomyPreview.luckFor(i)),
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
			}, levelsRow)) :: TextLabel
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
			make("UIStroke", {
				Color = if i == lvl + 1 then CarKit.Yellow else CarKit.Ink,
				Thickness = if i == lvl + 1 then 3 else 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, pill)
		end

		local restricted = player:GetAttribute(BetaConfig.LuckRestrictedAttribute)
		local price = EconomyPreview.luckPrice(lvl + 1)
		local have = cash()
		if restricted == true then
			buy.setText("Not available for your account")
			buy.setTone("Grey")
			buy.setEnabled(false)
			status.Text = "Luck can't be bought on this account."
		elseif top or not price then
			buy.setText("MAX LEVEL")
			buy.setTone("Grey")
			buy.setEnabled(false)
			status.Text = string.format("Level %d of %d: luck x%g on every run", lvl, EconomyPreview.LuckMaxLevel, nowL)
		elseif have and have < price then
			buy.setText("NEED " .. Format.cash(price - have) .. " MORE")
			buy.setTone("Grey")
			buy.setEnabled(false)
			status.Text =
				string.format("Level %d of %d  ·  next costs %s", lvl, EconomyPreview.LuckMaxLevel, Format.cash(price))
		else
			buy.setText(
				if waiting then "..." elseif restricted == nil then "CHECKING..." else "BUY " .. Format.cash(price)
			)
			buy.setTone("Green")
			buy.setEnabled(not waiting and restricted == false)
			status.Text =
				string.format("Level %d of %d  ·  counts from your next run", lvl, EconomyPreview.LuckMaxLevel)
		end
		if shownLevel >= 0 and lvl > shownLevel then
			-- the buy moment: the clover bursts into leaves
			pcall(Sounds.play, "Unlock")
			if not Motion.reduced() then
				Motion.pop(card, 1.06)
				for i = 1, 12 do
					local leaf = make("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.75, 0.35),
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = Panel.colourFor(lvl),
						Rotation = i * 30,
						ZIndex = 9,
					}, card)
					make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, leaf)
					local angle = i / 12 * math.pi * 2
					Motion.tween(leaf, "leaf", Motion.info(0.7), {
						Position = UDim2.new(0.75, math.cos(angle) * 140, 0.35, math.sin(angle) * 110),
						BackgroundTransparency = 1,
						Rotation = i * 30 + 180,
					})
					task.delay(0.75, function()
						leaf:Destroy()
					end)
				end
			end
		end
		shownLevel = lvl
	end

	t:Connect(buy.root.Activated, function()
		if waiting then
			return
		end
		local r = remote(BetaConfig.Remotes.BuyLuckLevel)
		if not r then
			status.Text = "The shop is not ready yet. Try again in a moment."
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
			if what ~= "BuyLuckLevel" then
				return
			end
			waiting = false
			draw()
			if not ok and reason then
				status.Text = reason
			end
		end)
	end
	t:Connect(player:GetAttributeChangedSignal(BetaConfig.LuckAttribute), draw)
	t:Connect(player:GetAttributeChangedSignal(BetaConfig.LuckRestrictedAttribute), draw)
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
