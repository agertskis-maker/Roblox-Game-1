--!strict
-- The LUCKY CLOVER card (Round 7, L-01, U-07; decision 0042 item 10). It opens from the Lucky Clover kiosk's circle on every Launch
-- Pad. It shows the luck now and after the next level as big clovers (green for x1.25 and x1.5, gold for x2 and x3, purple for x4),
-- one kid-readable line ("Rare cars show up more often!"), the real odds now and after (R7-S09: "Rare or better: 37% -> 45%" and the
-- Rare, Epic and Legendary shares over a 2 km run), computed from the same shared rule the server uses (src/shared/Run/Luck), the
-- five levels, and one BUY with the PREVIEW price. It never decides anything: BUY fires BuyLuckLevel with no arguments; the server
-- checks the Cash, the level and the account (PolicyService), and the card redraws from the server's attributes. For an account
-- where paid random items are restricted, BUY is replaced by "Not available for your account" (the stand and numbers still show).
-- Round 8 (O-09): the odds are two short lines ("Rare or better: 37% -> 45%" and what the run length is) and a small ODDS button
-- that opens the full table (every kind, now and next, unchanged ones marked "same"); the numbers are the same R7-S09 numbers from
-- the same shared rule, nothing is hidden. BUY is the shared GlossButton, the one cannot-afford treatment.
--
--   Panel.open()   Panel.close()   Panel.isOpen()
--   Panel.oddsRows(level) -> { OddsRow }   the odds table's numbers at a luck level (pure; the run's own Luck rule)
--   Panel.onShopCash: (() -> ())?          what the green "+" on the cannot-afford button does (open the Shop's Cash page); set by
--                                          the Launch Pad shell. Unset, the "+" says where the Cash shop is.

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
local GlossButton = require(Prototype:WaitForChild("R8Kit"):WaitForChild("GlossButton"))

local make = CarKit.make
local player = Players.LocalPlayer

local Panel = {}

Panel.onShopCash = nil :: (() -> ())?

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

-- Round 8 (O-09): the odds table's numbers at a luck level, from the same rule the server spawns with (R7-S09). `next` is nil at
-- the top level. Common here is everything that is not Rare or better (Uncommon cars are drawn from it).
export type OddsRow = { name: string, colour: Color3, now: number, next: number?, total: boolean? }

function Panel.oddsRows(lvl: number): { OddsRow }
	local top = lvl >= EconomyPreview.LuckMaxLevel
	local a = Luck.averageShares(EconomyPreview.luckFor(lvl), Panel.RUN_METRES)
	local b = Luck.averageShares(EconomyPreview.luckFor(if top then lvl else lvl + 1), Panel.RUN_METRES)
	local function row(name: string, colour: Color3, now: number, nxt: number): OddsRow
		return { name = name, colour = colour, now = now, next = if top then nil else nxt }
	end
	local rows: { OddsRow } = {
		row("Common & Uncommon", CarKit.Rarity.Common, a.Common, b.Common),
		row("Rare", CarKit.Rarity.Rare, a.Rare, b.Rare),
		row("Epic", CarKit.Rarity.Epic, a.Epic, b.Epic),
		row("Legendary", CarKit.Rarity.Legendary, a.Legendary, b.Legendary),
	}
	local total = row("Rare or better", CarKit.White, a.Rare + a.Epic + a.Legendary, b.Rare + b.Epic + b.Legendary)
	total.total = true
	table.insert(rows, total)
	return rows
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
	-- Round 8 (O-09): two short lines and a small ODDS button (the full table). The lines sit between two equal margins so the
	-- button never crowds them.
	local oddsMargin = math.round(18 * k) + 100
	local odds = CarKit.text(card, "", math.max(math.round(20 * k), 16), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(oddsMargin, math.round(232 * k)),
		size = UDim2.new(1, -2 * oddsMargin, 0, math.round(26 * k)),
		stroke = 1.5,
		z = 6,
		name = "Odds",
	})
	local oddsNote = CarKit.text(card, "", math.max(math.round(15 * k), 14), {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(oddsMargin, math.round(258 * k)),
		size = UDim2.new(1, -2 * oddsMargin, 0, math.round(20 * k)),
		color = CarKit.Soft,
		stroke = 1.5,
		z = 6,
		name = "OddsNote",
	})
	local oddsButton = CarKit.button(card, {
		text = "ODDS",
		tone = "Blue",
		px = math.max(math.round(22 * k), 18),
		size = UDim2.fromOffset(92, math.max(math.round(44 * k), 44)),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -math.round(18 * k), 0, math.round(234 * k)),
		z = 8,
		name = "OddsButton",
	})
	local content = t:Extend()
	local sheetTrove = t:Extend()
	local sheetLevel: number? = nil -- the luck level the open table was drawn for (nil: closed)
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
	-- Round 8 (O-09): the shared GlossButton (buy / need / max / busy / disabled); its "+" opens the Shop's Cash page
	local buy = GlossButton.new(card, {
		size = UDim2.fromOffset(math.round(320 * k), math.max(math.round(60 * k), Tokens.Touch.Primary)),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -math.round(16 * k)),
		zIndex = 8,
		label = "BUY",
		icon = "cash",
	})
	buy.frame.Name = "Buy"
	t:Add(buy, "destroy")
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

	-- Round 8 (O-09): the full odds table, a panel over the card. Every kind, now and next; a value that does not move says "same".
	local function closeOdds()
		sheetTrove:Clean()
		sheetLevel = nil
	end

	local function openOdds()
		if sheetLevel ~= nil then
			return
		end
		local lvl = level()
		sheetLevel = lvl
		local top = lvl >= EconomyPreview.LuckMaxLevel
		local rows = Panel.oddsRows(lvl)
		local sheetTop = math.round(56 * k)
		local sheetH = h - sheetTop - math.round(10 * k)
		local sheet = sheetTrove:Add(make("Frame", {
			Name = "OddsSheet",
			Active = true, -- it sits over BUY and the clovers: presses stop here
			BackgroundColor3 = Color3.fromRGB(6, 34, 24),
			Position = UDim2.fromOffset(math.round(12 * k), sheetTop),
			Size = UDim2.new(1, -math.round(24 * k), 0, sheetH),
			ZIndex = 20,
		}, card)) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, 14) }, sheet)
		make("UIStroke", { Color = CarKit.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, sheet)
		local titleH = math.max(math.round(38 * k), 30)
		local y = math.round(6 * k)
		CarKit.title(sheet, "ODDS", math.max(math.round(34 * k), 26), {
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, y),
			size = UDim2.new(1, 0, 0, titleH),
			top = CarKit.Yellow,
			bottom = CarKit.Orange,
			z = 21,
			name = "Title",
		})
		y += titleH
		CarKit.text(
			sheet,
			string.format("How often a car is each kind, averaged over a %g km run", Panel.RUN_METRES / 1000),
			15,
			{
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(8, y),
				size = UDim2.new(1, -16, 0, 20),
				color = CarKit.Soft,
				stroke = 1.5,
				z = 21,
				name = "Sub",
			}
		)
		y += 26
		local inner = w - math.round(24 * k) - 20 -- the rows' width
		local nameW = math.round(inner * 0.44)
		local colW = (inner - nameW) / 2
		local function cell(parent: Instance, text: string, x: number, width: number, colour: Color3, px: number)
			return CarKit.text(parent, text, px, {
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(x, 0),
				size = UDim2.new(0, width, 1, 0),
				color = colour,
				stroke = 1.5,
				z = 22,
			})
		end
		local head = make("Frame", {
			Name = "Head",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.new(1, -20, 0, 22),
			ZIndex = 21,
		}, sheet) :: Frame
		cell(head, string.format("NOW  (LUCK x%g)", EconomyPreview.luckFor(lvl)), nameW, colW, CarKit.Soft, 16)
		if not top then
			cell(
				head,
				string.format("NEXT  (x%g)", EconomyPreview.luckFor(lvl + 1)),
				nameW + colW,
				colW,
				CarKit.Yellow,
				16
			)
		end
		y += 24
		local rowH = math.max(math.round(30 * k), 24)
		for i, r in rows do
			local line = make("Frame", {
				Name = "Row" .. i,
				BackgroundColor3 = Color3.fromRGB(4, 22, 15),
				BackgroundTransparency = if r.total then 0 else 0.35,
				Position = UDim2.fromOffset(10, y),
				Size = UDim2.new(1, -20, 0, rowH),
				ZIndex = 21,
			}, sheet) :: Frame
			make("UICorner", { CornerRadius = UDim.new(0, 8) }, line)
			if r.total then
				make(
					"UIStroke",
					{ Color = CarKit.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
					line
				)
			end
			local dot = make("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = r.colour,
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(12, 12),
				ZIndex = 22,
			}, line)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
			make("UIStroke", { Color = CarKit.Ink, Thickness = 1.5 }, dot)
			local name = CarKit.text(line, r.name, 16, {
				align = Enum.TextXAlignment.Left,
				position = UDim2.fromOffset(28, 0),
				size = UDim2.new(0, nameW - 28, 1, 0),
				stroke = 1.5,
				z = 22,
				name = "Name",
			})
			name.TextTruncate = Enum.TextTruncate.AtEnd
			cell(line, pct(r.now), nameW, colW, CarKit.White, 18).Name = "Now"
			local nxt = r.next
			if nxt ~= nil then
				local same = pct(nxt) == pct(r.now)
				cell(
					line,
					if same then pct(nxt) .. "  same" else pct(nxt),
					nameW + colW,
					colW,
					if same then CarKit.Soft else CarKit.Yellow,
					18
				).Name =
					"Next"
			end
			y += rowH + 4
		end
		if y + 24 <= sheetH - math.round(10 * k) - 48 - 4 then -- only when there is room above the OK button
			CarKit.text(sheet, "These are chances, not promises.", 15, {
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(8, y + 2),
				size = UDim2.new(1, -16, 0, 20),
				color = CarKit.Soft,
				stroke = 1.5,
				z = 21,
				name = "Note",
			})
		end
		CarKit.button(sheet, {
			text = "OK",
			tone = "Blue",
			px = 26,
			size = UDim2.fromOffset(140, 48),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -math.round(10 * k)),
			z = 24,
			onPress = closeOdds,
			name = "Close",
		})
	end
	t:Connect(oddsButton.root.Activated, function()
		if sheetLevel ~= nil then
			closeOdds()
		else
			openOdds()
		end
	end)

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
		-- R7-S09: the real numbers before purchase, from the same rule the server spawns with. Round 8 (O-09): two short lines here,
		-- every kind in the table behind the ODDS button.
		local rows = Panel.oddsRows(lvl)
		local total = rows[#rows]
		local nextTotal = total.next
		odds.Text = if nextTotal == nil
			then string.format("Rare or better: %s", pct(total.now))
			else string.format("Rare or better: %s -> %s", pct(total.now), pct(nextTotal))
		oddsNote.Text = string.format("Averaged over a %g km run", Panel.RUN_METRES / 1000)
		-- a table left open while the level changes would show old numbers: close it
		if sheetLevel ~= nil and sheetLevel ~= lvl then
			closeOdds()
		end
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
			buy:setState("disabled", { label = "Not available for your account" })
			status.Text = "Luck can't be bought on this account."
		elseif top or not price then
			buy:setState("max", { maxText = "MAX LEVEL" })
			status.Text = string.format("Level %d of %d: luck x%g on every run", lvl, EconomyPreview.LuckMaxLevel, nowL)
		elseif have and have < price then
			-- the shortfall is the server's Cash attribute against the PREVIEW price; the client sends no amount
			buy:setState("need", {
				label = "BUY",
				price = Format.cash(price),
				need = Format.cash(price - have),
				icon = "cash",
			})
			status.Text =
				string.format("Level %d of %d  ·  next costs %s", lvl, EconomyPreview.LuckMaxLevel, Format.cash(price))
		else
			-- still checking the account's policy (restricted == nil): the button waits, as before
			local state: GlossButton.State = if waiting then "busy" elseif restricted == nil then "disabled" else "buy"
			buy:setState(state, {
				label = if restricted == nil then "CHECKING..." else "BUY",
				price = Format.cash(price),
				icon = "cash",
			})
			status.Text = string.format(
				"Level %d of %d  ·  next costs %s  ·  counts from your next run",
				lvl,
				EconomyPreview.LuckMaxLevel,
				Format.cash(price)
			)
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

	t:Connect(buy.PlusPressed, function()
		-- the "+" on the cannot-afford button: the Shop's Cash page (the Launch Pad shell sets Panel.onShopCash)
		local toShop = Panel.onShopCash
		if toShop then
			Panel.close()
			toShop()
		else
			status.Text = "Get Cash in the Shop (the green + by your Cash)."
		end
	end)
	t:Connect(buy.Pressed, function()
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
			if sheetLevel ~= nil then
				closeOdds() -- the odds table first, then the card
			else
				Panel.close()
			end
		end
	end)
	draw()
	if not Motion.reduced() then
		Motion.pop(card, 1.04)
	end
end

return Panel
