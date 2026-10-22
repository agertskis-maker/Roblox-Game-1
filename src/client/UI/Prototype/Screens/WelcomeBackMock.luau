--!strict
-- WelcomeBackMock: the short "Welcome back!" card drawn over gameplay (Lane 3 HUD prototype,
-- PREVIEW only). All values are synthetic; nothing is granted.
--
--   local welcome = WelcomeBackMock.new(ctx, { onCollect = fn? })
--   welcome:open(returnTo?)      -- plays the Lineup lap and the earnings count-up
--   welcome:close()  welcome:isOpen()
--   welcome:setEarnings(amount)  -- synthetic display amount (default 1,240)
--   welcome:skip()               -- jump to the final state
--   welcome:layout()  welcome:setVisible(on)  welcome:destroy()  welcome:getDebugState()
--
-- Presentation (outline v2.2 section 08: "the Lineup cars doing a quick lap with the total
-- rolling up; one tap closes it"): three small car cards slide along a mini track strip to
-- their bays, then "Preview earnings" counts up (0.4-0.8 s). Collect only closes the mock (and
-- calls options.onCollect if given); in the real game the Cash is already in the balance when
-- this card appears, so the card grants nothing. Reduced motion: the cards and total appear in
-- place with a short fade (no slide, no count). Tapping the dim or the card skips the reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = script.Parent.Parent
local CarCard = require(Prototype.Cards.CarCard)
local Fixtures = require(Prototype.Fixtures)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Gloss = require(Prototype.Gloss)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)

local C = PreviewTokens.Color
local M = PreviewTokens.Motion
local make = Gloss.make

local WelcomeBackMock = {}

WelcomeBackMock.DefaultEarnings = 1240

export type Options = {
	onCollect: (() -> ())?,
	cars: { CarCard.CarRef }?, -- default: the first three owned fixture cars
}

export type DebugState = {
	open: boolean,
	kind: string,
	revealing: boolean,
	shownEarnings: number,
	earnings: number,
	cards: number,
	collectCalls: number,
}

export type Welcome = {
	root: Frame,
	layout: (self: Welcome) -> (),
	setVisible: (self: Welcome, on: boolean) -> (),
	open: (self: Welcome, returnTo: GuiObject?) -> (),
	close: (self: Welcome) -> (),
	isOpen: (self: Welcome) -> boolean,
	setEarnings: (self: Welcome, amount: number) -> (),
	skip: (self: Welcome) -> (),
	destroy: (self: Welcome) -> (),
	getDebugState: (self: Welcome) -> DebugState,
}

function WelcomeBackMock.new(ctx: Overlay.Ctx, options: Options?): Welcome
	local opts: Options = options or {}
	local earnings = WelcomeBackMock.DefaultEarnings
	local shownEarnings = 0
	local revealing = false
	local collectCalls = 0
	local welcome: Welcome

	local overlay = Overlay.new(ctx, {
		name = "WelcomeBackMock",
		onDim = function()
			welcome:skip()
		end,
	})
	local trove = overlay.trove
	local revealTrove = trove:Extend()
	local content = overlay.content

	local panel = Gloss.panel(content, {
		name = "Panel",
		size = UDim2.fromOffset(700, 400),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		radius = 22,
		z = 3,
	})
	local panelShadow = content:FindFirstChild("Shadow") :: Frame?
	-- a full-panel catcher: tapping the card during the reveal skips it
	local catcher: TextButton = make("TextButton", {
		Name = "SkipCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Selectable = false,
		Visible = false,
		ZIndex = 20,
		Parent = panel,
	})
	trove:Connect(catcher.Activated, function()
		welcome:skip()
	end)

	local title = Overlay.title(panel, "Welcome back!", 34, C.PrimaryLight, C.PrimaryDeep, 6)
	local subtitle =
		Overlay.text(panel, "Your Lineup kept racing while you were away.", 16, C.InkSoft, Enum.TextXAlignment.Left, 6)

	-- mini track strip
	local track = make("Frame", {
		Name = "Track",
		BackgroundColor3 = Color3.fromRGB(70, 78, 98),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = panel,
	})
	Gloss.corner(track, 16)
	Gloss.stroke(track, 3)
	local lane = make("Frame", {
		Name = "Lane",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = track,
	})
	for i = 0, 15 do
		make("Frame", {
			Name = "Dash",
			Position = UDim2.new(i / 16, 6, 0, 0),
			Size = UDim2.fromScale(1 / 32, 1),
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = lane,
		})
	end
	-- checkered finish (original simple pattern)
	local finish = make("Frame", {
		Name = "Finish",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 0),
		Size = UDim2.new(0, 16, 1, 0),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	})
	for row = 0, 11 do
		for col = 0, 1 do
			if (row + col) % 2 == 0 then
				make("Frame", {
					Name = "Check",
					Position = UDim2.fromScale(col / 2, row / 12),
					Size = UDim2.fromScale(1 / 2, 1 / 12),
					BackgroundColor3 = C.Ink,
					BorderSizePixel = 0,
					ZIndex = 6,
					Parent = finish,
				})
			end
		end
	end
	local cardsHolder = make("Frame", {
		Name = "Cars",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = track,
	})

	local carList: { CarCard.CarRef } = opts.cars or {}
	if #carList == 0 then
		for _, c in Fixtures.Cars do
			if c.owned and #carList < 3 then
				table.insert(carList, c)
			end
		end
	end
	local cards: { CarCard.Card } = {}
	for i, c in carList do
		local card = CarCard.new(cardsHolder, c, { size = Vector2.new(132, 176), spinning = false })
		card.root.LayoutOrder = i
		table.insert(cards, card)
		trove:Add(function()
			card:destroy()
		end)
	end
	local slotPositions: { UDim2 } = {}

	-- earnings
	local earnBlock = make("Frame", { Name = "Earnings", BackgroundTransparency = 1, ZIndex = 5, Parent = panel })
	local earnLabel = Overlay.text(earnBlock, "Preview earnings", 18, C.InkSoft, Enum.TextXAlignment.Center, 6)
	earnLabel.Position = UDim2.fromOffset(0, 0)
	local earnValue = Gloss.title(earnBlock, "$0", 48, C.CashLight, C.CashDeep)
	earnValue.Position = UDim2.fromOffset(0, 26)
	earnValue.ZIndex = 6
	earnValue.TextXAlignment = Enum.TextXAlignment.Center
	local collect = Gloss.button(panel, {
		name = "Collect",
		size = Vector2.new(200, 60),
		light = C.CashLight,
		deep = C.CashDeep,
		text = "COLLECT",
		textSize = 26,
		radius = 18,
		cooldown = 0.6,
		onActivate = function()
			if revealing then
				welcome:skip()
				return
			end
			collectCalls += 1
			welcome:close()
			if opts.onCollect then
				opts.onCollect()
			end
		end,
	})
	trove:Add(collect.trove)
	collect.root.ZIndex = 8

	local function setValue(n: number)
		shownEarnings = n
		earnValue.Text = Format.cash(n)
	end

	local function finishReveal()
		revealTrove:Clean()
		revealing = false
		catcher.Visible = false
		for i, card in cards do
			Motion.cancelAll(card.root)
			card.root.Position = slotPositions[i] or card.root.Position
		end
		setValue(earnings)
	end

	local function startCount()
		local duration = math.clamp(M.CountUpMin + 0.1 * math.log10(math.max(earnings, 1)), M.CountUpMin, M.CountUpMax)
		local t0 = os.clock()
		Sounds.play("ResultsCount")
		revealTrove:Connect(RunService.Heartbeat, function()
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			local eased = 1 - (1 - a) ^ 3
			setValue(math.floor(earnings * eased + 0.5))
			if a >= 1 then
				finishReveal()
			end
		end)
	end

	local function playReveal()
		revealTrove:Clean()
		if Motion.reduced() then
			finishReveal()
			return
		end
		revealing = true
		catcher.Visible = true
		setValue(0)
		-- the Lineup lap: each card enters from the left and slides to its bay
		for i, card in cards do
			local goal = slotPositions[i]
			if goal then
				card.root.Position = UDim2.new(goal.X.Scale, goal.X.Offset - 640, goal.Y.Scale, goal.Y.Offset)
				revealTrove:Add(task.delay(0.12 + (#cards - i) * 0.12, function()
					Motion.tween(card.root, "lap", Motion.info(0.6, Enum.EasingStyle.Quart), { Position = goal })
				end))
			end
		end
		revealTrove:Add(task.delay(0.12 + #cards * 0.12 + 0.55, startCount))
	end

	trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced and revealing then
			finishReveal()
		end
	end))

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local pw, ph
		local cardSize
		local gap = 10
		if kind == "Wide" then
			-- tall enough for 150 x 200 cards (desktop); otherwise smaller cards (tablet)
			local roomy = ds.Y - 24 >= 520
			pw, ph = math.min(ds.X - 32, 760), if roomy then 520 else ds.Y - 24
			cardSize = if roomy then Vector2.new(150, 200) else Vector2.new(120, 160)
		elseif kind == "Short" then
			pw, ph = ds.X - 24, ds.Y - 16
			cardSize = Vector2.new(120, 160)
		else
			-- phone portrait: the three cards overlap a little, like a convoy
			pw, ph = ds.X - 16, math.min(ds.Y - 16, 560)
			cardSize = Vector2.new(112, 150)
			gap = -16
		end
		subtitle.Text = if kind == "Tall"
			then "Your cars kept racing!"
			else "Your Lineup kept racing while you were away."
		panel.Size = UDim2.fromOffset(pw, ph)
		if panelShadow then
			panelShadow.Size = panel.Size
		end
		title.Position = UDim2.fromOffset(20, 14)
		title.Size = UDim2.new(1, -40, 0, 42)
		title.TextSize = if kind == "Short" then 30 else 34
		subtitle.Position = UDim2.fromOffset(22, 56)
		subtitle.Size = UDim2.new(1, -44, 0, 22)
		local rowW = #cards * cardSize.X + math.max(#cards - 1, 0) * gap
		local trackH = cardSize.Y + 36
		local trackW
		if kind == "Short" then
			trackW = rowW + 60
			track.Position = UDim2.fromOffset(16, 86)
			earnBlock.Position = UDim2.fromOffset(16 + trackW + 12, 96)
			earnBlock.Size = UDim2.fromOffset(pw - trackW - 44, 90)
			collect.root.AnchorPoint = Vector2.new(0.5, 1)
			collect.root.Position = UDim2.new(0, 16 + trackW + 12 + (pw - trackW - 44) / 2, 1, -14)
		else
			trackW = math.min(pw - 32, rowW + 80)
			track.Position = UDim2.new(0.5, -trackW / 2, 0, 88)
			earnBlock.Position = UDim2.fromOffset(16, 88 + trackH + 10)
			earnBlock.Size = UDim2.new(1, -32, 0, 90)
			collect.root.AnchorPoint = Vector2.new(0.5, 1)
			collect.root.Position = UDim2.new(0.5, 0, 1, -14)
		end
		track.Size = UDim2.fromOffset(trackW, trackH)
		earnValue.Size = UDim2.new(1, 0, 0, 56)
		earnValue.TextSize = if kind == "Short" then 40 else 48
		-- bays: the cards sit on the strip, finish line on the right
		local x0 = math.max(math.floor((trackW - 34 - rowW) / 2), 6)
		table.clear(slotPositions)
		for i, card in cards do
			card:setSize(cardSize)
			local pos = UDim2.fromOffset(x0 + (i - 1) * (cardSize.X + gap), 8)
			slotPositions[i] = pos
			if not revealing then
				card.root.Position = pos
			end
		end
	end

	overlay:setBack(function()
		if revealing then
			welcome:skip()
		else
			welcome:close()
		end
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	welcome = {
		root = overlay.root,
		layout = function(_self: Welcome)
			layoutNow()
		end,
		setVisible = function(_self: Welcome, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
			for _, card in cards do
				card:setVisible(on)
			end
		end,
		open = function(_self: Welcome, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			layoutNow()
			overlay:open(collect.body, returnTo)
			playReveal()
		end,
		close = function(_self: Welcome)
			if not overlay:isOpen() then
				return
			end
			finishReveal()
			overlay:close()
		end,
		isOpen = function(_self: Welcome): boolean
			return overlay:isOpen()
		end,
		setEarnings = function(_self: Welcome, amount: number)
			earnings = math.max(0, math.floor(amount))
			if not revealing then
				setValue(earnings)
			end
		end,
		skip = function(_self: Welcome)
			if revealing then
				finishReveal()
			end
		end,
		destroy = function(_self: Welcome)
			overlay:destroy()
		end,
		getDebugState = function(_self: Welcome): DebugState
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				revealing = revealing,
				shownEarnings = shownEarnings,
				earnings = earnings,
				cards = #cards,
				collectCalls = collectCalls,
			}
		end,
	}

	layoutNow()
	setValue(earnings)
	return welcome
end

return WelcomeBackMock
