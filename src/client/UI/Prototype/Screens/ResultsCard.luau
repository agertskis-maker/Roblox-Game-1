--!strict
-- ResultsCard: the run Results screen drawn over the run view (Lane 3 HUD rebuild, PREVIEW only;
-- the values come from the caller's fixtures and nothing is granted). Ledger: H-15 family, E-06,
-- the Results part of E-04 / E-05, K-04 step 6 (delayed confirmation), V-06.
--
--   local results = ResultsCard.new(ctx, { onRetry = fn, onHome = fn })
--   results:show(r: Store.Results, cars: { CarRef }?)  -- asks Priority for the Center slot
--                                                        (Safety), then plays the reveal
--   results:addLateClaim(claim: Store.Claim)  -- a KeysConfirmed that arrived after the run
--                                                ended: shown exactly once (by claim.id and
--                                                car id) with a small SECURED stamp
--   results:skip()      -- jump to the final state (nothing is lost)
--   results:hide()      -- close without choosing (releases the Center slot)
--   results:open() / results:close()   -- open re-shows the last results; close = hide
--   results:layout()  results:setVisible(on)  results:destroy()  results:getDebugState()
--   results:pressRetry() / results:pressHome()   -- test hooks: the same path as a real press
--   results:scrollTo(alpha)   -- test hook: scroll the content region (0 top .. 1 bottom)
--
-- Layout: a fixed REASON HEADING at the top, a constrained, scrollable CONTENT region, and a
-- FIXED FOOTER that only holds RETRY (kit "Retry" orange, the larger primary, right) and
-- GO HOME (kit "Home" teal, smaller, left). The content region ends above the footer, so cards
-- can never scroll behind the buttons.
--
-- Reason heading: results.endReason through ResultsCard.Reasons ("Overheated" -> OVERHEATED! /
-- "Heat full"); anything else (or nil) -> RUN OVER with no cause line (never an invented cause).
-- Rows: Distance, Coins, Best (NEW BEST! stamp and "was ..." on their own line, so nothing
-- overlaps), Joyride Bonus only when results.joyride > 0, Milestones only when > 0, then the
-- Cash tally (the existing count-up timing: 0.4-0.8 s by size), then the claimed cars as
-- kit car cards in a wrapping grid (none: a friendly line; one; many). Claimed cars are always
-- shown owned (a confirmed car is never shown as lost).
-- Buttons: enabled after the reveal; the first press of either disables both and calls its
-- callback exactly once; later presses do nothing until the next show() (the caller's
-- store:setMode is the second guard). Back after the reveal = GO HOME.
-- Late confirmation: KeysConfirmed events (captureId) received while the mode is Results, or
-- after a RunEnded event and before the next run starts, are added through addLateClaim.
-- Priority (E-05): the Results wait (max 3 s) for the Center slot at Safety, so they never stack
-- on a run-end banner, then hold it and suppress Side and Upper below Safety while open (no
-- ribbon or banner on top of them); everything is released on hide.
-- Reduced motion: no slide, no pops, no count (the final value is shown at once).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(Prototype.Cards.CarCard)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Priority = require(Prototype.Priority)
local Sounds = require(Prototype.Sounds)
local Store = require(Prototype.Store)
local Style = require(script.Parent.Style)

local A = PreviewTokens.Arcade
local M = PreviewTokens.Motion
local make = Arcade.make

-- TOKEN CANDIDATES (design px / seconds) -----------------------------------------------------
local RETRY_W_MAX = 232 -- primary: wider than Wide (156)
local HOME_W_MAX = 196
local BUTTON_GAP = 16
local FOOTER_PAD = 12
local FOOTER_PAD_SHORT = 8
local RETRY_H = A.Button.WideH -- 66 (>= 56 primary)
local RETRY_H_SHORT = 58
local HOME_H = 58
local HOME_H_SHORT = 52
local ROW_H = 52
local ROW_GAP = 8
local CASH_H = 92
local SIDE = 10
local CELL_WIDE = Vector2.new(176, 236) -- two name lines
local CELL_NARROW = Vector2.new(148, 206) -- three name lines
local GRID_GAP = Vector2.new(14, 16)
local GRID_PAD = 9 -- room for the variant ring (5) and the card lip (4): never clipped
local SLOT_WAIT = 3 -- seconds the Results may wait for the Center slot before showing anyway
local HEADING_SIZE = 40

local ResultsCard = {}

export type CarRef = CarCard.CarRef

export type Reason = {
	heading: string,
	line: string?,
	face: Arcade.FaceName,
	icon: string,
}

-- Run-end reasons with a display mapping. Only reasons another lane really supplies belong here.
ResultsCard.Reasons = {
	Overheated = { heading = "OVERHEATED!", line = "Heat full", face = "Heat", icon = "Flame" },
} :: { [string]: Reason }

-- The truthful fallback: no cause is invented.
ResultsCard.Fallback = { heading = "RUN OVER", line = nil, face = "White", icon = "Flag" } :: Reason

function ResultsCard.reasonFor(endReason: string?): Reason
	if endReason then
		local r = ResultsCard.Reasons[endReason]
		if r then
			return r
		end
	end
	return ResultsCard.Fallback
end

export type Options = {
	onRetry: (() -> ())?,
	onHome: (() -> ())?,
}

export type CardDebug = { id: string, shownName: string, nameFit: string, late: boolean }

export type DebugState = {
	open: boolean,
	waitingForSlot: boolean,
	slotHeld: boolean,
	kind: string,
	revealing: boolean,
	chosen: string?,
	retryCalls: number,
	homeCalls: number,
	buttonsEnabled: boolean,
	shownEarnings: number,
	earnings: number,
	claimed: number,
	lateClaims: number,
	lateQueued: number,
	claimKeys: number,
	reasonHeading: string,
	reasonLine: string?,
	rows: { string },
	newBest: boolean,
	scrollable: boolean,
	canvasHeight: number,
	windowHeight: number,
	contentBottom: number,
	footerTop: number,
	separated: boolean,
	cards: { CardDebug },
	instances: number,
}

export type Results = {
	root: Frame,
	layout: (self: Results) -> (),
	setVisible: (self: Results, on: boolean) -> (),
	show: (self: Results, results: Store.Results, cars: { CarRef }?) -> (),
	addLateClaim: (self: Results, claim: Store.Claim) -> boolean,
	skip: (self: Results) -> (),
	hide: (self: Results) -> (),
	open: (self: Results, returnTo: GuiObject?) -> (),
	close: (self: Results) -> (),
	isOpen: (self: Results) -> boolean,
	destroy: (self: Results) -> (),
	getDebugState: (self: Results) -> DebugState,
	pressRetry: (self: Results) -> (),
	pressHome: (self: Results) -> (),
	scrollTo: (self: Results, alpha: number) -> (),
}

type Entry = { key: string, car: CarRef, late: boolean }
type Row = { frame: Frame, value: TextLabel, label: TextLabel }

function ResultsCard.new(ctx: Overlay.Ctx, options: Options?): Results
	local opts: Options = options or {}
	local last: Store.Results? = nil
	local revealing = false
	local chosen: string? = nil
	local retryCalls, homeCalls = 0, 0
	local shownEarnings = 0
	local earnings = 0
	local buttonsEnabled = false
	local destroyed = false
	local results: Results

	-- claims shown on this Results (dedupe keys: "claim:<id>" and "car:<car id>")
	local entries: { Entry } = {}
	local keys: { [string]: boolean } = {}
	local early: { Store.Claim } = {} -- late claims that arrived before show()
	local runEnded = false

	-- Center slot
	local slot: Priority.Handle? = nil
	local waitingForSlot = false
	local suppressing = false
	local showToken = 0

	local overlay = Overlay.new(ctx, {
		name = "ResultsCard",
		onDim = function()
			results:skip()
		end,
	})
	local trove = overlay.trove
	local revealTrove = trove:Extend()
	local cardsTrove = trove:Extend()
	local buttonsTrove = trove:Extend()
	local slotTrove = trove:Extend()
	local content = overlay.content

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body

	-- REASON HEADING (fixed) --------------------------------------------------------------
	local heading: Frame = make("Frame", {
		Name = "Heading",
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = panel,
	})
	local headingIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = heading,
	})
	local headingText = Style.text(heading, "", "Display", { name = "Reason", size = HEADING_SIZE, z = 8 })
	local headingGradient: UIGradient = make("UIGradient", { Rotation = 90, Parent = headingText })
	local reasonLine = Style.text(heading, "", "Label", { name = "ReasonLine", colour = Style.TextSoft, z = 8 })
	local rule: Frame = make("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = heading,
	})
	local _ = rule

	-- CONTENT REGION (scrolls; ends above the footer) -------------------------------------
	local body = Style.scroll(panel, "Body", 5)
	make("UIListLayout", {
		Padding = UDim.new(0, ROW_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = body,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = body,
	})

	local function statRow(order: number, name: string, icon: string, label: string, face: Arcade.FaceName): Row
		local f = Style.well(body, "Row_" .. name, 6)
		f.Size = UDim2.new(1, 0, 0, ROW_H)
		f.LayoutOrder = order
		local holder: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(8, ROW_H / 2),
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Parent = f,
		})
		Arcade.icon(holder, icon)
		local l = Style.text(f, label, "Label", { name = "Label", z = 8 })
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.fromOffset(50, ROW_H / 2)
		l.Size = UDim2.new(0.45, -50, 0, 28)
		-- the value shrinks (never below 16) before it could reach the label
		local v = Style.text(f, "", "Value", {
			name = "Value",
			italic = true,
			face = face,
			size = 32,
			xAlign = Enum.TextXAlignment.Right,
			z = 8,
		})
		v.AnchorPoint = Vector2.new(1, 0.5)
		v.Position = UDim2.new(1, -10, 0, ROW_H / 2)
		v.Size = UDim2.new(0.55, -14, 0, 40)
		return { frame = f, value = v, label = l }
	end

	local distanceRow = statRow(1, "Distance", "Flag", "Distance", "White")
	local coinsRow = statRow(2, "Coins", "Coin", "Coins", "Keys")
	local bestRow = statRow(3, "Best", "Medal", "Best", "White")
	local joyrideRow = statRow(4, "Joyride", "Key", "Joyride Bonus", "Cash")
	local milestonesRow = statRow(5, "Milestones", "Flag", "Milestones", "White")

	-- NEW BEST! and the previous best sit on their own line inside the Best row (no overlap)
	local bestStamp = Style.stamp(bestRow.frame, "NEW BEST!", "Retry", 9)
	bestStamp.frame.AnchorPoint = Vector2.new(0, 1)
	bestStamp.frame.Position = UDim2.new(0, 50, 1, -8)
	bestStamp.frame.Visible = false
	local bestWas = Style.text(bestRow.frame, "", "Small", {
		name = "Was",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Right,
		z = 8,
	})
	bestWas.AnchorPoint = Vector2.new(1, 1)
	bestWas.Position = UDim2.new(1, -12, 1, -8)
	bestWas.Size = UDim2.new(0.5, -12, 0, 22)

	-- Cash tally
	local cashFrame = Style.well(body, "Cash", 6)
	cashFrame.Size = UDim2.new(1, 0, 0, CASH_H)
	cashFrame.LayoutOrder = 6
	local cashLabel = Style.text(cashFrame, "Cash earned", "Label", {
		name = "Label",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Center,
		z = 8,
	})
	cashLabel.Position = UDim2.fromOffset(0, 6)
	cashLabel.Size = UDim2.new(1, 0, 0, 24)
	local cashValue = Style.text(cashFrame, "$0", "Value", {
		name = "Value",
		italic = true,
		face = "Cash",
		size = 44,
		xAlign = Enum.TextXAlignment.Center,
		z = 8,
	})
	cashValue.Position = UDim2.fromOffset(8, 32)
	cashValue.Size = UDim2.new(1, -16, 0, 52)

	-- claimed cars
	local claimsFrame: Frame = make("Frame", {
		Name = "Claimed",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 7,
		ZIndex = 6,
		Parent = body,
	})
	local claimsTitle = Style.text(claimsFrame, "Cars claimed", "Label", { name = "Title", z = 8 })
	claimsTitle.Position = UDim2.fromOffset(2, 2)
	claimsTitle.Size = UDim2.new(1, -4, 0, 26)
	local noClaims = Style.text(
		claimsFrame,
		"No new cars this run. Keep hopping!",
		"Label",
		{ name = "Empty", colour = Style.TextSoft, z = 8 }
	)
	noClaims.Position = UDim2.fromOffset(2, 32)
	noClaims.Size = UDim2.new(1, -4, 0, 26)
	local grid: Frame = make("Frame", {
		Name = "ClaimGrid",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = claimsFrame,
	})
	local gridLayout: UIGridLayout = make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL_WIDE.X, CELL_WIDE.Y),
		CellPadding = UDim2.fromOffset(GRID_GAP.X, GRID_GAP.Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, GRID_PAD),
		PaddingBottom = UDim.new(0, GRID_PAD),
		PaddingLeft = UDim.new(0, GRID_PAD),
		PaddingRight = UDim.new(0, GRID_PAD),
		Parent = grid,
	})

	local footnote = Overlay.text(body, "Preview values", 16, Style.TextSoft, Enum.TextXAlignment.Center, 6)
	footnote:SetAttribute("PreviewCaption", true) -- harness caption, hidden for player-facing captures
	footnote.LayoutOrder = 8

	-- FIXED FOOTER --------------------------------------------------------------------------
	local footer: Frame = make("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Style.Well,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = panel,
	})
	Arcade.corner(footer, 8)
	local footerRule: Frame = make("Frame", {
		Name = "Rule",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = footer,
	})
	local _ = footerRule

	local retry: Arcade.Button? = nil
	local home: Arcade.Button? = nil
	local buttonDims = Vector2.zero -- (retryW, retryH) the buttons were built with
	local homeDims = Vector2.zero

	local function setButtons(on: boolean)
		buttonsEnabled = on
		if retry then
			retry.setEnabled(on)
		end
		if home then
			home.setEnabled(on)
		end
	end

	local function choose(which: string)
		if chosen or revealing or not buttonsEnabled or destroyed then
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
		results:hide()
	end

	local function buildButtons(retrySize: Vector2, homeSize: Vector2)
		if retrySize == buttonDims and homeSize == homeDims and retry and home then
			return
		end
		buttonsTrove:Clean()
		buttonDims, homeDims = retrySize, homeSize
		local r = Arcade.button(footer, {
			name = "Retry",
			label = "RETRY",
			fill = "Retry",
			size = "Custom",
			width = retrySize.X,
			height = retrySize.Y,
			pattern = true,
			cooldown = 0.6,
			onActivate = function()
				choose("Retry")
			end,
		})
		buttonsTrove:Add(r.trove)
		r.root.ZIndex = 11
		local h = Arcade.button(footer, {
			name = "GoHome",
			label = "GO HOME",
			fill = "Home",
			size = "Custom",
			width = homeSize.X,
			height = homeSize.Y,
			sound = "Close",
			cooldown = 0.6,
			onActivate = function()
				choose("Home")
			end,
		})
		buttonsTrove:Add(h.trove)
		h.root.ZIndex = 11
		retry, home = r, h
		setButtons(buttonsEnabled)
	end

	-- tap-anywhere catcher during the reveal (above everything on the card)
	local catcher: TextButton = make("TextButton", {
		Name = "SkipCatcher",
		Size = UDim2.fromScale(1, 1),
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

	-- STATE -> VIEW -------------------------------------------------------------------------
	local reveal: { GuiObject } = {} -- the rows of this show, in reveal order
	local reason: Reason = ResultsCard.Fallback
	local kindNow: Overlay.Kind = "Wide"
	local cell = CELL_WIDE
	local contentW = 560

	local function setEarningsText(n: number)
		shownEarnings = n
		cashValue.Text = Format.cash(n)
	end

	local function lateCount(): number
		local n = 0
		for _, e in entries do
			if e.late then
				n += 1
			end
		end
		return n
	end

	local function claimsHeight(): number
		local n = #entries
		if n == 0 then
			return 64
		end
		local cols = math.max(1, math.floor((contentW - 2 * GRID_PAD + GRID_GAP.X) / (cell.X + GRID_GAP.X)))
		local rows = math.ceil(n / cols)
		return 30 + 2 * GRID_PAD + rows * cell.Y + (rows - 1) * GRID_GAP.Y
	end

	local function updateClaimsFrame()
		local n = #entries
		claimsTitle.Text = if n > 0 then string.format("Cars claimed: %d", n) else "Cars claimed"
		noClaims.Visible = n == 0
		grid.Visible = n > 0
		local h = claimsHeight()
		grid.Size = UDim2.new(1, 0, 0, h - 30)
		claimsFrame.Size = UDim2.new(1, 0, 0, h)
	end

	local cardList: { { card: CarCard.Card, late: boolean } } = {}

	local function addCard(entry: Entry, index: number)
		-- a claimed car is owned now: never a silhouette here
		local car = table.clone(entry.car)
		car.owned = true
		local card = CarCard.new(grid, car, {
			size = cell,
			spinning = false,
			nameLines = if cell.X < CELL_WIDE.X then 3 else 2,
		})
		card.root.LayoutOrder = index
		if entry.late then
			card:setStamp("SECURED")
		end
		table.insert(cardList, { card = card, late = entry.late })
		cardsTrove:Add(function()
			card:destroy()
		end)
		return card
	end

	local function buildCards()
		cardsTrove:Clean()
		table.clear(cardList)
		gridLayout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
		for i, e in entries do
			addCard(e, i)
		end
		updateClaimsFrame()
	end

	local function addEntry(claimId: string?, car: CarRef, late: boolean): Entry?
		if claimId and keys["claim:" .. claimId] then
			return nil
		end
		if claimId then
			keys["claim:" .. claimId] = true
		end
		if keys["car:" .. car.id] then
			return nil
		end
		keys["car:" .. car.id] = true
		local e: Entry = { key = claimId or ("car:" .. car.id), car = car, late = late }
		table.insert(entries, e)
		return e
	end

	local function resetEntries(cars: { CarRef })
		table.clear(entries)
		table.clear(keys)
		for _, c in cars do
			addEntry(nil, c, false)
		end
		for _, claim in early do
			addEntry(claim.id, claim.car :: any, true)
		end
		table.clear(early)
	end

	local function applyReason(r: Store.Results)
		reason = ResultsCard.reasonFor(r.endReason)
		headingText.Text = reason.heading
		headingGradient.Color = A.Face[reason.face]
		reasonLine.Text = reason.line or ""
		reasonLine.Visible = reason.line ~= nil
		headingIcon:ClearAllChildren()
		Arcade.icon(headingIcon, reason.icon)
	end

	local function fillContent(r: Store.Results)
		applyReason(r)
		distanceRow.value.Text = Format.distance(r.distance)
		coinsRow.value.Text = Format.group(r.coins)
		local newBestValue = if r.newBest then math.max(r.best, r.distance) else r.best
		bestRow.value.Text = Format.distance(newBestValue)
		local showPrevious = r.newBest and r.distance > r.best
		bestWas.Text = if showPrevious then "was " .. Format.distance(r.best) else ""
		bestWas.Visible = showPrevious
		bestRow.frame.Size = UDim2.new(1, 0, 0, if r.newBest then ROW_H + 34 else ROW_H)
		local joy = r.joyride
		local hasJoy = type(joy) == "number" and joy > 0
		joyrideRow.value.Text = if hasJoy then "+" .. Format.cash(joy :: number) else ""
		local mil = r.milestones
		local hasMil = type(mil) == "number" and mil > 0
		milestonesRow.value.Text = if hasMil then tostring(mil) else ""
		earnings = math.max(0, math.floor(r.earnings))
		table.clear(reveal)
		table.insert(reveal, distanceRow.frame)
		table.insert(reveal, coinsRow.frame)
		table.insert(reveal, bestRow.frame)
		if hasJoy then
			table.insert(reveal, joyrideRow.frame)
		end
		if hasMil then
			table.insert(reveal, milestonesRow.frame)
		end
		table.insert(reveal, cashFrame)
		table.insert(reveal, claimsFrame)
		joyrideRow.frame.Visible = hasJoy
		milestonesRow.frame.Visible = hasMil
		buildCards()
	end

	local function finishReveal()
		revealTrove:Clean() -- also stops the tally loop
		revealing = false
		catcher.Visible = false
		for _, row in reveal do
			row.Visible = true
			Motion.cancelAll(row)
			local pop = row:FindFirstChild("Pop") :: UIScale?
			if pop then
				pop.Scale = 1
			end
		end
		local r = last
		bestStamp.frame.Visible = r ~= nil and r.newBest
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
		-- the approved tally vocabulary and timing (0.4-0.8 s by size, ease-out cubic)
		local duration = math.clamp(M.CountUpMin + 0.1 * math.log10(earnings), M.CountUpMin, M.CountUpMax)
		local t0 = os.clock()
		revealTrove:Add(Sounds.loop("ResultsCount"))
		revealTrove:Connect(RunService.Heartbeat, function()
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			setEarningsText(math.floor(earnings * (1 - (1 - a) ^ 3) + 0.5))
			if a >= 1 then
				finishReveal()
			end
		end)
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
		bestStamp.frame.Visible = false
		for _, row in reveal do
			row.Visible = false
		end
		for i, row in reveal do
			revealTrove:Add(task.delay(0.22 + (i - 1) * 0.12, function()
				row.Visible = true
				Motion.pop(row, 1.03)
				if row == bestRow.frame and last and last.newBest then
					bestStamp.frame.Visible = true
					Motion.pop(bestStamp.frame, 1.15)
					Sounds.play("NewBest")
				end
				if row == cashFrame then
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

	-- LAYOUT ------------------------------------------------------------------------------------
	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		kindNow = kind
		local pw, ph
		if kind == "Wide" then
			pw, ph = math.min(ds.X - 48, 660), math.min(ds.Y - 32, 700)
		elseif kind == "Short" then
			pw, ph = math.min(ds.X - 32, 680), ds.Y - 20
		else
			pw, ph = ds.X - 20, math.min(ds.Y - 40, 700)
		end
		shell.root.Size = UDim2.fromOffset(pw, ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2) -- the lip stays inside the safe area
		local short = kind == "Short"
		-- heading
		local headH = if short then 60 else 84
		heading.Position = UDim2.fromOffset(SIDE, 4)
		heading.Size = UDim2.new(1, -2 * SIDE, 0, headH)
		local iconS = if short then 38 else 52
		headingIcon.Size = UDim2.fromOffset(iconS, iconS)
		headingIcon.Position = UDim2.new(0, 2, 0.5, -1)
		local textLeft = iconS + 10
		local hasLine = reason.line ~= nil
		headingText.AnchorPoint = Vector2.new(0, 0.5)
		headingText.Position = UDim2.new(0, textLeft, 0.5, if hasLine then (if short then -9 else -12) else 0)
		headingText.Size = UDim2.new(1, -textLeft, 0, if short then 34 else 46)
		reasonLine.AnchorPoint = Vector2.new(0, 0.5)
		reasonLine.Position = UDim2.new(0, textLeft + 2, 0.5, if short then 15 else 22)
		reasonLine.Size = UDim2.new(1, -textLeft - 2, 0, 24)
		-- footer (fixed)
		local pad = if short then FOOTER_PAD_SHORT else FOOTER_PAD
		local retryH = if short then RETRY_H_SHORT else RETRY_H
		local homeH = if short then HOME_H_SHORT else HOME_H
		local footerH = retryH + A.Button.DepthOffset + 2 * pad
		footer.Position = UDim2.new(0, 4, 1, -4)
		footer.Size = UDim2.new(1, -8, 0, footerH)
		local avail = pw - 8 - 2 * pad - BUTTON_GAP
		local retryW = math.min(RETRY_W_MAX, math.floor(avail * 0.54))
		local homeW = math.min(HOME_W_MAX, avail - retryW)
		buildButtons(Vector2.new(retryW, retryH), Vector2.new(homeW, homeH))
		local total = homeW + BUTTON_GAP + retryW
		local x0 = math.floor((pw - 8 - total) / 2)
		local h, r = home :: Arcade.Button, retry :: Arcade.Button
		h.root.AnchorPoint = Vector2.new(0, 0)
		h.root.Position = UDim2.fromOffset(x0, pad + math.floor((retryH - homeH) / 2))
		r.root.AnchorPoint = Vector2.new(0, 0)
		r.root.Position = UDim2.fromOffset(x0 + homeW + BUTTON_GAP, pad)
		-- content region: between the heading and the footer, never under the buttons
		local top = 4 + headH + 4
		body.Position = UDim2.fromOffset(SIDE, top)
		body.Size = UDim2.new(1, -2 * SIDE, 1, -(top + footerH + 4 + 4))
		contentW = pw - 2 * SIDE - 12 - 8 -- list padding and the scroll bar
		-- wide cells (two name lines) where at least two fit; narrow cells keep three name lines
		local twoWide = 2 * CELL_WIDE.X + GRID_GAP.X + 2 * GRID_PAD
		local newCell = if kind == "Wide" and contentW >= twoWide then CELL_WIDE else CELL_NARROW
		if newCell ~= cell then
			cell = newCell
			if last then
				buildCards()
			end
		end
		updateClaimsFrame()
	end

	-- OPEN / SLOT -------------------------------------------------------------------------------
	local function releaseSlot()
		local arb = ctx.priority
		if arb and slot then
			arb:release(slot)
		end
		if arb and suppressing then
			-- note: Priority keeps one floor per slot, so this also clears a floor set by others
			arb:unsuppress("Side", "results")
			arb:unsuppress("Upper", "results")
		end
		suppressing = false
		slot = nil
		waitingForSlot = false
	end

	local function openNow()
		waitingForSlot = false
		if destroyed or not last then
			return
		end
		if not overlay:isOpen() then
			overlay:open(if retry then retry.body else nil)
		end
		-- nothing below Safety stacks on the Results (side ribbons, upper banners)
		local arb = ctx.priority
		if arb and not suppressing then
			suppressing = true
			arb:suppress("Side", "Safety", "results")
			arb:suppress("Upper", "Safety", "results")
		end
		playReveal()
	end

	local function requestAndOpen()
		slotTrove:Clean()
		showToken += 1
		local token = showToken
		if overlay:isOpen() then
			openNow() -- already holding the Center slot
			return
		end
		local arb = ctx.priority
		if not arb then
			openNow()
			return
		end
		waitingForSlot = true
		slot = arb:request("Center", "Safety", "results", {
			grant = function()
				if token == showToken and not overlay:isOpen() then
					openNow()
				end
			end,
			revoke = function() end, -- nothing outranks Safety; Results stays
			wait = SLOT_WAIT,
		})
		-- the Results never fail to appear: after SLOT_WAIT they show regardless
		slotTrove:Add(task.delay(SLOT_WAIT + 0.1, function()
			if token == showToken and waitingForSlot and not overlay:isOpen() then
				openNow()
			end
		end))
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
	end)
	trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Results" and overlay:isOpen() then
			results:hide()
		end
		if mode ~= "Results" then
			showToken += 1
			if waitingForSlot then
				releaseSlot()
			end
		end
		if mode == "Run" or mode == "Home" then
			runEnded = false
			table.clear(early)
		end
		if mode == "Run" then
			-- a new run: the previous Results are finished (late claims now wait for the next show)
			last = nil
		end
	end)
	-- late confirmation: a KeysConfirmed after the run ended reaches the Results exactly once
	trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "RunEnded" then
			runEnded = true
		elseif event.kind == "KeysConfirmed" and event.car then
			local mode = ctx.store:get().mode
			if mode == "Results" or runEnded then
				results:addLateClaim({ id = event.captureId or event.id, car = event.car :: Store.CarRef })
			end
		end
	end)
	trove:Add(function()
		destroyed = true
		showToken += 1
		releaseSlot()
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
			resetEntries(cars or (r.claimed :: any))
			layoutNow()
			fillContent(r)
			layoutNow()
			requestAndOpen()
		end,
		addLateClaim = function(_self: Results, claim: Store.Claim): boolean
			if destroyed or not claim or not claim.car then
				return false
			end
			if not last then
				-- the Results are not built yet: keep it for show() (deduplicated there)
				for _, c in early do
					if c.id == claim.id then
						return false
					end
				end
				table.insert(early, claim)
				return true
			end
			local e = addEntry(claim.id, claim.car :: any, true)
			if not e then
				return false
			end
			local card = addCard(e, #entries)
			updateClaimsFrame()
			Sounds.play("Unlock")
			if overlay:isOpen() and not Motion.reduced() then
				Motion.pop(card.root, 1.06)
			end
			return true
		end,
		skip = function(_self: Results)
			if revealing then
				finishReveal()
			end
		end,
		hide = function(_self: Results)
			showToken += 1
			releaseSlot()
			if not overlay:isOpen() then
				return
			end
			revealTrove:Clean()
			revealing = false
			catcher.Visible = false
			overlay:close()
		end,
		open = function(_self: Results, _returnTo: GuiObject?)
			local r = last
			if r and not overlay:isOpen() then
				layoutNow()
				fillContent(r)
				requestAndOpen()
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
		scrollTo = function(_self: Results, alpha: number)
			local maxY = math.max(body.AbsoluteCanvasSize.Y - body.AbsoluteWindowSize.Y, 0)
			-- AbsoluteCanvasSize is in screen px; CanvasPosition is in the frame's own px
			local scale = ctx.screen:uiScale()
			body.CanvasPosition = Vector2.new(0, math.clamp(alpha, 0, 1) * maxY / math.max(scale, 0.01))
		end,
		getDebugState = function(_self: Results): DebugState
			local r = last
			local rows = {}
			for _, row in reveal do
				if row.Visible then
					table.insert(rows, row.Name)
				end
			end
			local cardsOut: { CardDebug } = {}
			for _, c in cardList do
				local d = c.card:getDebugState()
				table.insert(cardsOut, { id = d.id, shownName = d.shownName, nameFit = d.nameFit, late = c.late })
			end
			local keyCount = 0
			for _ in keys do
				keyCount += 1
			end
			local contentBottom = body.AbsolutePosition.Y + body.AbsoluteSize.Y
			local footerTop = footer.AbsolutePosition.Y
			return {
				open = overlay:isOpen(),
				waitingForSlot = waitingForSlot,
				slotHeld = slot ~= nil and not waitingForSlot,
				kind = kindNow,
				revealing = revealing,
				chosen = chosen,
				retryCalls = retryCalls,
				homeCalls = homeCalls,
				buttonsEnabled = buttonsEnabled,
				shownEarnings = shownEarnings,
				earnings = earnings,
				claimed = #entries,
				lateClaims = lateCount(),
				lateQueued = #early,
				claimKeys = keyCount,
				reasonHeading = headingText.Text,
				reasonLine = if reasonLine.Visible then reasonLine.Text else nil,
				rows = rows,
				newBest = r ~= nil and r.newBest,
				scrollable = body.AbsoluteCanvasSize.Y > body.AbsoluteWindowSize.Y + 1,
				canvasHeight = body.AbsoluteCanvasSize.Y,
				windowHeight = body.AbsoluteWindowSize.Y,
				contentBottom = contentBottom,
				footerTop = footerTop,
				separated = contentBottom <= footerTop + 0.5,
				cards = cardsOut,
				instances = if destroyed then 0 else #overlay.root:GetDescendants(),
			}
		end,
	}

	layoutNow()
	setButtons(false)
	return results
end

return ResultsCard
