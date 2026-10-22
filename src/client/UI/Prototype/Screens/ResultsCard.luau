--!strict
-- ResultsCard: the run Results card drawn over the run view (Lane 3 HUD prototype, PREVIEW
-- only; the values come from the caller's fixtures and nothing is granted).
--
--   local results = ResultsCard.new(ctx, { onRetry = fn, onHome = fn })
--   results:show(r: Store.Results, cars: { CarRef }?)  -- plays the reveal
--   results:skip()      -- jump to the final state (nothing is lost)
--   results:hide()      -- close without choosing
--   results:open() / results:close()   -- open re-shows the last results; close = hide
--   results:layout()  results:setVisible(on)  results:destroy()  results:getDebugState()
--   results:pressRetry() / results:pressHome()   -- test hooks: the same path as a real press
-- After a choice the card hides itself; it also hides when the store leaves the Results mode.
--
-- Rows: Distance, Coins, Best (with a NEW BEST stamp when r.newBest). Claimed cars: none (a
-- calm line), one, or many (a horizontal scrolling row of cards; long names are cut by the
-- card). Earnings count up in 0.4-0.8 s. RETRY (primary, orange, larger) and GO HOME
-- (secondary, navy, smaller). The first press of either disables both and fires its callback
-- exactly once; later presses do nothing until the next show().
-- The reveal is skippable: a tap anywhere on the card or the dim, any key or gamepad button,
-- or Back skips to the final state. Buttons work only after the reveal ends or is skipped.
-- Back after the reveal = GO HOME (single fire). The body scrolls when it does not fit (phone
-- landscape); the buttons stay pinned at the bottom.
-- Best: shows max(best, distance) when newBest is set, with the previous best underneath.
-- Reduced motion: no slide, stamp tilt stays but does not pop, no count (final value shown).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local CarCard = require(Prototype.Cards.CarCard)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Gloss = require(Prototype.Gloss)
local Icons = require(Prototype.Icons)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Store = require(Prototype.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local C = PreviewTokens.Color
local M = PreviewTokens.Motion
local make = Gloss.make

local ResultsCard = {}

export type CarRef = CarCard.CarRef

export type Options = {
	onRetry: (() -> ())?,
	onHome: (() -> ())?,
}

export type DebugState = {
	open: boolean,
	kind: string,
	revealing: boolean,
	chosen: string?,
	retryCalls: number,
	homeCalls: number,
	buttonsEnabled: boolean,
	shownEarnings: number,
	earnings: number,
	claimed: number,
	newBest: boolean,
	rowsVisible: number,
	scrollable: boolean,
	canvasHeight: number,
	windowHeight: number,
}

export type Results = {
	root: Frame,
	layout: (self: Results) -> (),
	setVisible: (self: Results, on: boolean) -> (),
	show: (self: Results, results: Store.Results, cars: { CarRef }?) -> (),
	skip: (self: Results) -> (),
	hide: (self: Results) -> (),
	open: (self: Results, returnTo: GuiObject?) -> (),
	close: (self: Results) -> (),
	isOpen: (self: Results) -> boolean,
	destroy: (self: Results) -> (),
	getDebugState: (self: Results) -> DebugState,
	-- test hooks: the same path as a real press (skips during the reveal, single fire)
	pressRetry: (self: Results) -> (),
	pressHome: (self: Results) -> (),
}

function ResultsCard.new(ctx: Overlay.Ctx, options: Options?): Results
	local opts: Options = options or {}
	local last: Store.Results? = nil
	local lastCars: { CarRef }? = nil
	local revealing = false
	local chosen: string? = nil
	local retryCalls, homeCalls = 0, 0
	local shownEarnings = 0
	local earnings = 0
	local buttonsEnabled = false
	local results: Results

	local overlay = Overlay.new(ctx, {
		name = "ResultsCard",
		onDim = function()
			results:skip()
		end,
	})
	local trove = overlay.trove
	local revealTrove = trove:Extend()
	local cardsTrove = trove:Extend()
	local content = overlay.content

	local panel = Gloss.panel(content, {
		name = "Panel",
		size = UDim2.fromOffset(600, 500),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		radius = 22,
		z = 3,
	})
	local panelShadow = content:FindFirstChild("Shadow") :: Frame?

	-- ribbon across the top (gold, the run's celebration colour; not a rarity)
	local ribbon = make("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(1, 24, 0, 52),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = panel,
	})
	Gloss.corner(ribbon, 14)
	Gloss.stroke(ribbon, 3)
	Gloss.gradient(ribbon, C.KeysLight, C.KeysDeep)
	Gloss.highlight(ribbon, 14)
	local ribbonTitle = Gloss.title(ribbon, "RUN COMPLETE", 30)
	ribbonTitle.Size = UDim2.fromScale(1, 1)
	ribbonTitle.ZIndex = 10

	-- scrolling body
	local body: ScrollingFrame = make("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 0.3,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Selectable = false,
		ZIndex = 5,
		Parent = panel,
	})
	make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = body,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = body,
	})

	type Row = { frame: Frame, value: TextLabel, sub: TextLabel? }
	local function statRow(order: number, icon: Icons.Name, label: string): Row
		local f = make("Frame", {
			Name = "Row_" .. label,
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 6,
			Parent = body,
		})
		Gloss.corner(f, 12)
		Gloss.stroke(f, 2).Transparency = 0.35
		local holder = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			ZIndex = 7,
			Parent = f,
		})
		Icons.draw(holder, icon, C.Ink)
		local l = Overlay.text(f, label, 18, C.InkSoft, nil, 7)
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.new(0, 44, 0.5, 0)
		l.Size = UDim2.new(0.45, -44, 0, 24)
		local v = make("TextLabel", {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0.55, -12, 0, 30),
			BackgroundTransparency = 1,
			FontFace = Tokens.font(),
			Text = "",
			TextSize = Tokens.TextSize.Value,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
			Parent = f,
		})
		return { frame = f, value = v }
	end

	local distanceRow = statRow(1, "Flag", "Distance")
	local coinsRow = statRow(2, "Coin", "Coins")
	local bestRow = statRow(3, "Medal", "Best")
	-- Joyride bonuses and milestones (outline v2: Results lists both); optional in the payload
	local joyrideRow = statRow(3, "Key", "Joyride bonuses")
	joyrideRow.frame.Name = "Row_Joyride"
	local milestonesRow = statRow(3, "Flag", "Milestones")
	milestonesRow.frame.Name = "Row_Milestones"
	local bestSub = Overlay.text(bestRow.frame, "", 16, C.InkSoft, Enum.TextXAlignment.Right, 7)
	bestSub.AnchorPoint = Vector2.new(1, 1)
	bestSub.Position = UDim2.new(1, -12, 1, -1) -- inside the row, under the value
	bestSub.Size = UDim2.new(0.4, 0, 0, 16)
	local stamp = make("Frame", {
		Name = "NewBest",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(132, 34),
		Rotation = -8,
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 9,
		Parent = bestRow.frame,
	})
	Gloss.corner(stamp, 10)
	Gloss.stroke(stamp, 3)
	Gloss.gradient(stamp, C.PrimaryLight, C.PrimaryDeep)
	local stampText = Gloss.title(stamp, "NEW BEST!", 20)
	stampText.Size = UDim2.fromScale(1, 1)
	stampText.ZIndex = 10

	-- earnings block
	local earnFrame = make("Frame", {
		Name = "Earnings",
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		LayoutOrder = 4,
		ZIndex = 6,
		Parent = body,
	})
	Gloss.corner(earnFrame, 14)
	Gloss.stroke(earnFrame, 2)
	local earnLabel = Overlay.text(earnFrame, "Earnings", 18, C.InkSoft, Enum.TextXAlignment.Center, 7)
	earnLabel.Position = UDim2.fromOffset(0, 2)
	local earnValue = Gloss.title(earnFrame, "$0", 40, C.CashLight, C.CashDeep)
	earnValue.Position = UDim2.fromOffset(0, 24)
	earnValue.Size = UDim2.new(1, 0, 0, 46)
	earnValue.ZIndex = 7

	-- claimed cars
	local carsFrame = make("Frame", {
		Name = "Claimed",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		ZIndex = 6,
		Parent = body,
	})
	local carsTitle = Overlay.text(carsFrame, "Cars claimed", 18, C.Ink, nil, 7)
	carsTitle.Position = UDim2.fromOffset(4, 0)
	local noCars = Overlay.text(carsFrame, "No new cars this run. Keep hopping!", 16, C.InkSoft, nil, 7)
	noCars.Position = UDim2.fromOffset(4, 28)
	local carRow: ScrollingFrame = make("ScrollingFrame", {
		Name = "CarRow",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Ink,
		Selectable = false,
		ZIndex = 7,
		Parent = carsFrame,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = carRow,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = carRow,
	})
	local footnote = Overlay.text(body, "Preview values", 16, C.InkSoft, Enum.TextXAlignment.Center, 6)
	footnote:SetAttribute("PreviewCaption", true) -- harness caption, hidden for player-facing captures
	footnote.LayoutOrder = 6

	-- footer buttons (pinned)
	local retry: Gloss.Button
	local home: Gloss.Button
	local function setButtons(on: boolean)
		buttonsEnabled = on
		retry.setEnabled(on)
		home.setEnabled(on)
	end
	local function choose(which: string)
		if chosen or revealing or not buttonsEnabled then
			return
		end
		chosen = which
		setButtons(false)
		if which == "Retry" then
			retryCalls += 1
			if opts.onRetry then
				opts.onRetry()
			end
		else
			homeCalls += 1
			if opts.onHome then
				opts.onHome()
			end
		end
		-- the card leaves after a choice (the buttons stay disabled until the next show)
		results:hide()
	end
	retry = Gloss.button(panel, {
		name = "Retry",
		size = Vector2.new(196, 60),
		light = C.PrimaryLight,
		deep = C.PrimaryDeep,
		text = "RETRY",
		textSize = 28,
		radius = 18,
		cooldown = 0.6,
		onActivate = function()
			choose("Retry")
		end,
	})
	trove:Add(retry.trove)
	home = Gloss.button(panel, {
		name = "GoHome",
		size = Vector2.new(156, 52),
		light = C.SettingsLight,
		deep = C.SettingsDeep,
		text = "GO HOME",
		textSize = 20,
		radius = 16,
		cooldown = 0.6,
		onActivate = function()
			choose("Home")
		end,
	})
	trove:Add(home.trove)

	-- tap-anywhere catcher during the reveal (above everything on the card)
	local catcher: TextButton = make("TextButton", {
		Name = "SkipCatcher",
		Size = UDim2.new(1, 0, 1, 30),
		Position = UDim2.fromOffset(0, -30),
		BackgroundTransparency = 1,
		Text = "",
		Selectable = false,
		Visible = false,
		ZIndex = 30,
		Parent = panel,
	})
	trove:Connect(catcher.Activated, function()
		results:skip()
	end)

	-- ordered by name within LayoutOrder 3 ("Row_Best" < "Row_Joyride" < "Row_Milestones")
	local rowsInOrder: { GuiObject } = {
		distanceRow.frame,
		coinsRow.frame,
		bestRow.frame,
		joyrideRow.frame,
		milestonesRow.frame,
		earnFrame,
		carsFrame,
	}
	local rowsVisible = #rowsInOrder

	local function setEarningsText(n: number)
		shownEarnings = n
		earnValue.Text = Format.cash(n)
	end

	local function finishReveal()
		revealTrove:Clean()
		revealing = false
		catcher.Visible = false
		for _, r in rowsInOrder do
			r.Visible = true
			Motion.cancelAll(r)
		end
		rowsVisible = #rowsInOrder
		local r = last
		stamp.Visible = r ~= nil and r.newBest
		setEarningsText(earnings)
		if not chosen then
			setButtons(true)
		end
	end

	local function startCount()
		if earnings <= 0 then
			finishReveal()
			return
		end
		local duration = math.clamp(M.CountUpMin + 0.1 * math.log10(earnings), M.CountUpMin, M.CountUpMax)
		local t0 = os.clock()
		Sounds.play("ResultsCount")
		revealTrove:Connect(RunService.Heartbeat, function()
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			setEarningsText(math.floor(earnings * (1 - (1 - a) ^ 3) + 0.5))
			if a >= 1 then
				finishReveal()
			end
		end)
	end

	local function fillContent(r: Store.Results, cars: { CarRef })
		distanceRow.value.Text = Format.distance(r.distance)
		coinsRow.value.Text = Format.group(r.coins)
		local newBestValue = if r.newBest then math.max(r.best, r.distance) else r.best
		bestRow.value.Text = Format.distance(newBestValue)
		local showPrevious = r.newBest and r.distance > r.best
		bestSub.Text = if showPrevious then "was " .. Format.distance(r.best) else ""
		bestSub.Visible = showPrevious
		bestRow.frame.Size = UDim2.new(1, 0, 0, if showPrevious then 58 else 42)
		bestRow.value.Position = UDim2.new(1, -12, 0, if showPrevious then 20 else 21)
		local extra = r :: any
		joyrideRow.value.Text = if type(extra.joyride) == "number" then Format.cash(extra.joyride) else "$0"
		milestonesRow.value.Text = if type(extra.milestones) == "number" then tostring(extra.milestones) else "0"
		earnings = math.max(0, math.floor(r.earnings))
		cardsTrove:Clean()
		noCars.Visible = #cars == 0
		carRow.Visible = #cars > 0
		carsTitle.Text = if #cars > 0 then string.format("Cars claimed: %d", #cars) else "Cars claimed"
		local kind = overlay:kind()
		local cardSize = if kind == "Short" then Vector2.new(112, 150) else Vector2.new(132, 176)
		carRow.Size = UDim2.new(1, 0, 0, cardSize.Y + 24)
		carsFrame.Size = UDim2.new(1, 0, 0, if #cars > 0 then 28 + cardSize.Y + 24 else 56)
		for i, claimedCar in cars do
			-- a claimed car is owned now: never shown as a silhouette here
			local car = table.clone(claimedCar)
			car.owned = true
			local card = CarCard.new(carRow, car, { size = cardSize, spinning = false })
			card.root.LayoutOrder = i
			cardsTrove:Add(function()
				card:destroy()
			end)
		end
		carRow.CanvasPosition = Vector2.zero
	end

	local function playReveal()
		revealTrove:Clean()
		chosen = nil
		setButtons(false)
		body.CanvasPosition = Vector2.zero
		if Motion.reduced() then
			finishReveal()
			return
		end
		revealing = true
		catcher.Visible = true
		setEarningsText(0)
		stamp.Visible = false
		for _, r in rowsInOrder do
			r.Visible = false
		end
		rowsVisible = 0
		for i, r in rowsInOrder do
			revealTrove:Add(task.delay(0.22 + (i - 1) * 0.12, function()
				r.Visible = true
				rowsVisible = math.max(rowsVisible, i)
				Motion.pop(r, 1.04)
				if r == bestRow.frame and last and last.newBest then
					stamp.Visible = true
					Motion.pop(stamp, 1.15)
					Sounds.play("NewBest")
				end
				if r == earnFrame then
					startCount()
				end
			end))
		end
		-- any key or gamepad button skips (mouse and touch go through the catcher)
		revealTrove:Connect(UserInputService.InputBegan, function(input: InputObject)
			local t = input.UserInputType
			if t == Enum.UserInputType.Keyboard or t.Name:sub(1, 7) == "Gamepad" then
				if input.KeyCode ~= Enum.KeyCode.Thumbstick1 and input.KeyCode ~= Enum.KeyCode.Thumbstick2 then
					results:skip()
				end
			end
		end)
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
		if kind == "Wide" then
			pw, ph = math.min(ds.X - 48, 620), math.min(ds.Y - 24, 660)
		elseif kind == "Short" then
			pw, ph = math.min(ds.X - 48, 620), ds.Y - 24
		else
			pw, ph = ds.X - 24, math.min(ds.Y - 40, 640)
		end
		panel.Size = UDim2.fromOffset(pw, ph)
		panel.Position = UDim2.new(0.5, 0, 0.5, if kind == "Short" then 8 else 10)
		if panelShadow then
			panelShadow.Size = panel.Size
			panelShadow.Position = panel.Position + UDim2.fromOffset(0, PreviewTokens.Size.ShadowOffset)
		end
		ribbon.Size = UDim2.new(1, 24, 0, if kind == "Short" then 44 else 52)
		ribbonTitle.TextSize = if kind == "Short" then 26 else 30
		local top = if kind == "Short" then 30 else 36
		local footer = 76
		body.Position = UDim2.fromOffset(8, top)
		body.Size = UDim2.new(1, -16, 1, -(top + footer))
		-- RETRY on the right (primary), GO HOME on the left (secondary)
		retry.root.AnchorPoint = Vector2.new(1, 1)
		retry.root.Position = UDim2.new(1, -16, 1, -10)
		home.root.AnchorPoint = Vector2.new(0, 1)
		home.root.Position = UDim2.new(0, 16, 1, -14)
	end

	overlay:setBack(function()
		if revealing then
			results:skip()
		else
			choose("Home")
		end
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
		if last then
			fillContent(last, lastCars or {})
		end
	end)
	-- Results is superseded cleanly when the flow leaves the Results mode
	trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Results" and overlay:isOpen() then
			results:hide()
		end
	end)

	results = {
		root = overlay.root,
		layout = function(_self: Results)
			layoutNow()
		end,
		setVisible = function(_self: Results, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		show = function(_self: Results, r: Store.Results, cars: { CarRef }?)
			last = r
			lastCars = cars or (r.claimed :: any)
			layoutNow()
			fillContent(r, lastCars or {})
			if not overlay:isOpen() then
				overlay:open(retry.body)
			end
			playReveal()
		end,
		skip = function(_self: Results)
			if revealing then
				finishReveal()
			end
		end,
		hide = function(_self: Results)
			if not overlay:isOpen() then
				return
			end
			revealTrove:Clean()
			revealing = false
			catcher.Visible = false
			overlay:close()
		end,
		open = function(_self: Results, returnTo: GuiObject?)
			local r = last
			if r and not overlay:isOpen() then
				layoutNow()
				fillContent(r, lastCars or {})
				overlay:open(retry.body, returnTo)
				playReveal()
			end
		end,
		close = function(self: Results)
			self:hide()
		end,
		isOpen = function(_self: Results): boolean
			return overlay:isOpen()
		end,
		destroy = function(_self: Results)
			overlay:destroy()
		end,
		pressRetry = function(self: Results)
			if revealing then
				self:skip()
			else
				choose("Retry")
			end
		end,
		pressHome = function(self: Results)
			if revealing then
				self:skip()
			else
				choose("Home")
			end
		end,
		getDebugState = function(_self: Results): DebugState
			local r = last
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				revealing = revealing,
				chosen = chosen,
				retryCalls = retryCalls,
				homeCalls = homeCalls,
				buttonsEnabled = buttonsEnabled,
				shownEarnings = shownEarnings,
				earnings = earnings,
				claimed = if lastCars then #lastCars else 0,
				newBest = r ~= nil and r.newBest,
				rowsVisible = rowsVisible,
				scrollable = body.AbsoluteCanvasSize.Y > body.AbsoluteWindowSize.Y + 1,
				canvasHeight = body.AbsoluteCanvasSize.Y,
				windowHeight = body.AbsoluteWindowSize.Y,
			}
		end,
	}

	layoutNow()
	setButtons(false)
	return results
end

return ResultsCard
