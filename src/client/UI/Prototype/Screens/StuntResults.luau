--!strict
-- StuntResults: the card at the end of a Stunt Circuit lap (Lane 3, Round 2 N12-02 and N12-02a; PREVIEW). It follows the concept board:
-- a red "FINISH!" ribbon over the top edge, a big medal on the left (gold, silver, bronze or none, with a matching celebration and a
-- small car under it), the time in big outlined numbers on the right with NEW BEST! and the gap to your ghost, the three medal targets
-- with ticks, a PREVIEW reward row, and RETRY and HOME. No large empty area at any size: the card is sized from its content.
--
--   local results = StuntResults.new(ctx, { targets = Targets?, onRetry = fn?, onHome = fn?, onClose = fn? })
--   results:show(result)               -- a StuntFixtures.Result { finished, time?, best? }: opens the card and plays the reveal
--   results:setPreset("Gold")          -- a StuntFixtures.Results key: Gold, Silver, Bronze, NoMedal, NoMedalBest, Matched,
--                                         FirstNoMedal, Incomplete
--   results:close()  results:isOpen()  results:finishNow()    -- finishNow skips the reveal (for stills)
--   results:pressRetry() -> boolean  results:pressHome() -> boolean   -- the same path as a real tap; one fire per activation
--   results:layout()  results:setVisible(on)  results:destroy()  results:getDebugState()  results:touchReport()
--   StuntResults.geometry(designSize) -> Geo
--
-- WORDS (N12-02a): the time and the comparison are on screen at once. NEW BEST! shows only when the result supports it (a verified
-- earlier best that this time beats, or a first lap); the gap line reads "-0.84 vs your ghost" when faster, "+2.20 vs your ghost"
-- when slower and "No ghost comparison" when there is no earlier time. An unfinished run shows "--:--.--", "RUN NOT FINISHED", no
-- medal, no ribbon and no ticks. Bronze, Silver and Gold differ in SILHOUETTE (a round disc, a diamond, a pointed seal) and in their
-- word, not only colour; a tick (and an empty box for a missed target) says what this run reached.
--
-- TIMING: the time and the comparison are on screen at once; the medal reveal starts at 350 ms, settles over 250 ms, and a small
-- burst fires at 600 ms (more pieces for a better medal, none for no medal). REDUCED MOTION shows the whole result immediately with
-- a short (0.15 s) fade and no burst.
--
-- NOTHING IS GRANTED. The reward row is a PREVIEW (StuntFixtures.RewardPreview, made up) and says so on the card; the card changes no
-- Cash and no item. RETRY and HOME each fire once and then show a pending state (both buttons off) until the next show().

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CardKit = require(script.Parent.CardKit)
local Format = require(game:GetService("ReplicatedStorage").Shared.UI.Format)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local Style = require(script.Parent.Style)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)
local StuntKit = require(script.Parent.StuntKit)
local SupportKit = require(script.Parent.SupportKit)

local make = Arcade.make

local StuntResults = {}

StuntResults.RevealStart = 0.35 -- seconds after the card opens
StuntResults.RevealSeconds = 0.25
StuntResults.SettleSeconds = 0.25
StuntResults.BurstAt = 0.6
StuntResults.ReducedFade = 0.15

local PLATE_H = 52
local OVERHANG = PLATE_H / 2
local BORDER = 6
local GOOD = Color3.fromRGB(22, 140, 60)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Options = {
	targets: StuntFixtures.Targets?,
	onRetry: (() -> ())?,
	onHome: (() -> ())?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	cw: number,
	ch: number,
	stageH: number,
	bodyW: number,
	bodyH: number,
	topPad: number,
	left: Rect, -- the medal column, in body px
	right: Rect, -- the figures column, in body px
	timeSize: number,
	badge: number,
	rowH: number, -- one medal-target row (Compact uses one row of three chips instead)
	targetsH: number,
	rewardH: number,
	button: Vector2,
}

export type Phase = "Time" | "Reveal" | "Settle" | "Settled"

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	preset: string,
	timeText: string,
	ribbonVisible: boolean,
	ribbonText: string,
	pbText: string,
	bestText: string,
	ghostText: string,
	ghostTone: string,
	medal: string,
	medalShape: string,
	medalPrimary: string,
	medalSecondary: string,
	ticks: { boolean },
	rewardText: string,
	unlockText: string,
	rewardVisible: boolean,
	phase: Phase,
	reduced: boolean,
	burstFired: number,
	retryPresses: number,
	homePresses: number,
	retryCalls: number,
	homeCalls: number,
	pending: string,
	caption: string,
	title: string,
	instances: number,
}

export type Results = {
	root: Frame,
	layout: (self: Results) -> (),
	setVisible: (self: Results, on: boolean) -> (),
	show: (self: Results, result: StuntFixtures.Result) -> (),
	open: (self: Results, returnTo: GuiObject?) -> (),
	setPreset: (self: Results, name: string) -> boolean,
	close: (self: Results) -> (),
	isOpen: (self: Results) -> boolean,
	finishNow: (self: Results) -> (),
	pressRetry: (self: Results) -> boolean,
	pressHome: (self: Results) -> boolean,
	destroy: (self: Results) -> (),
	getDebugState: (self: Results) -> DebugState,
	touchReport: (self: Results) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY ---------------------------------------------------------------------------------------------------------------

-- The card is as tall as its content needs (title, ghost line, targets, reward, buttons), so there is never a big empty area; a short
-- phone keeps one row of three target chips, a taller screen shows three rows with their times.
function StuntResults.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local cw, timeSize, badge, rowH, rewardH, button
	if fit == "Compact" then
		cw, timeSize, badge, rowH, rewardH = math.min(ds.X - 16, 640), 40, 92, 0, 34
		button = Vector2.new(170, 56)
	elseif fit == "Regular" then
		cw, timeSize, badge, rowH, rewardH = math.min(ds.X - 24, 700), 46, 116, 28, 40
		button = Vector2.new(200, 58)
	else
		cw, timeSize, badge, rowH, rewardH = math.min(ds.X - 32, 780), 54, 144, 32, 46
		button = Vector2.new(220, 62)
	end
	local targetsH = if rowH == 0 then 36 else rowH * 3 + 6
	local topPad = OVERHANG - BORDER + 6
	local timeH = timeSize + 10
	local ghostH = 28
	local rightH = timeH + 4 + ghostH + 4 + targetsH + 4 + rewardH + 6 + button.Y + 4
	local bodyW = cw - BORDER * 2
	local bodyH = topPad + rightH + 10
	local leftW = math.floor(bodyW * 0.36)
	return {
		fit = fit,
		cw = cw,
		ch = bodyH + BORDER * 2,
		stageH = OVERHANG + bodyH + BORDER * 2,
		bodyW = bodyW,
		bodyH = bodyH,
		topPad = topPad,
		left = { x = 10, y = topPad, w = leftW, h = rightH },
		right = { x = 10 + leftW + 8, y = topPad, w = bodyW - leftW - 28, h = rightH },
		timeSize = timeSize,
		badge = badge,
		rowH = rowH,
		targetsH = targetsH,
		rewardH = rewardH,
		button = button,
	}
end

-- BUILD ------------------------------------------------------------------------------------------------------------------

function StuntResults.new(ctx: Overlay.Ctx, options: Options?): Results
	local opts: Options = options or {}
	local targets: StuntFixtures.Targets = opts.targets or table.clone(StuntFixtures.MedalTargets)
	local geo = StuntResults.geometry(Vector2.new(750, 325))
	local view: StuntFixtures.ResultView? = nil
	local current: StuntFixtures.Result? = nil
	local presetName = ""
	local phase: Phase = "Settled"
	local revealToken = 0
	local burstCancel: (() -> ())? = nil
	local burstFired = 0
	local retryPresses, homePresses, retryCalls, homeCalls = 0, 0, 0, 0
	local pending = ""
	local guard = SupportKit.guard()
	local builtKey = ""
	local ghostTone = "none"
	local rewardLine, unlockLine = "", ""
	local rewardTagWanted = false -- a finished run: the reward carries its PREVIEW tag when the plate has room for it
	local ticks: { boolean } = {}
	local results: Results

	local overlay = Overlay.new(ctx, { name = "StuntResults" })
	local trove = overlay.trove
	local revealTrove = trove:Extend()
	local buttonsTrove = trove:Extend()
	local targetsTrove = trove:Extend()
	local content = overlay.content

	local stage: Frame = make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 300),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = content,
	})
	local card = CardKit.card(stage, { name = "Card", z = 3 })
	local body = card.body
	local plate = CardKit.titlePlate(stage, {
		text = "FINISH!",
		size = 36,
		height = PLATE_H,
		face = "White",
		top = rgb(255, 96, 112),
		bottom = rgb(204, 30, 60),
		edge = rgb(255, 190, 196),
		z = 20,
	})
	local preview = StuntKit.previewChip(stage, nil, 24)
	preview.frame.AnchorPoint = Vector2.new(1, 0.5)

	-- left: the medal block (a CanvasGroup so rays, medal, words and car fade and pop as one piece)
	local medalGroup: CanvasGroup = make("CanvasGroup", {
		Name = "MedalBlock",
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = body,
	})
	local medalScale: UIScale = make("UIScale", { Name = "Reveal", Parent = medalGroup })
	local rays =
		CardKit.rays(medalGroup, { bars = 6, radius = 120, z = 6, transparency = 0.7, colour = rgb(255, 214, 90) })
	local badgeHolder: Frame = make("Frame", {
		Name = "BadgeHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = medalGroup,
	})
	local medalPrimary = CardKit.ink(medalGroup, "", 22, { name = "Primary", z = 8 })
	local medalSecondary = CardKit.ink(medalGroup, "", 16, { name = "Secondary", colour = CardKit.NavySoft, z = 8 })
	local car = CardKit.uiCar(medalGroup, { colour = rgb(226, 60, 64), family = "Sports", name = "result" }, 9)

	-- right: the time first, then NEW BEST! and the ghost gap, the targets, the reward, the buttons
	local timeRow: Frame = make("Frame", { Name = "TimeRow", BackgroundTransparency = 1, ZIndex = 6, Parent = body })
	local timeIcon = CardKit.icon(timeRow, { "Timer", "Flag" }, 40, 7)
	timeIcon.AnchorPoint = Vector2.new(0, 0.5)
	timeIcon.Position = UDim2.fromScale(0, 0.5)
	local timeText = Arcade.text(timeRow, {
		text = "0:00.00",
		role = "Value",
		name = "Time",
		face = "Keys",
		italic = true,
		size = 40,
		xAlign = Enum.TextXAlignment.Left,
		outline = "Major",
		z = 7,
	})
	timeText.AnchorPoint = Vector2.new(0, 0.5)
	local ribbon = Style.stamp(body, "NEW BEST!", "Gold", 9)
	ribbon.frame.Name = "NewBestRibbon"
	local ghostLabel = CardKit.ink(body, "", 20, { name = "Ghost", xAlign = Enum.TextXAlignment.Left, z = 6 })
	local targetsHolder: Frame =
		make("Frame", { Name = "Targets", BackgroundTransparency = 1, ZIndex = 6, Parent = body })

	-- the reward row: Cash and what the medal opens (PREVIEW)
	local rewardHolder: Frame =
		make("Frame", { Name = "Reward", BackgroundTransparency = 1, ZIndex = 6, Parent = body })
	local cashPlate: Frame = make("Frame", {
		Name = "CashPlate",
		BackgroundColor3 = rgb(214, 246, 208),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = rewardHolder,
	})
	Arcade.corner(cashPlate, 10)
	Arcade.outline(cashPlate, "Minor")
	local rewardCoin = CardKit.coin(cashPlate, 26, 8)
	rewardCoin.AnchorPoint = Vector2.new(0, 0.5)
	rewardCoin.Position = UDim2.new(0, 6, 0.5, 0)
	local rewardText =
		CardKit.ink(cashPlate, "", 22, { name = "Amount", xAlign = Enum.TextXAlignment.Left, colour = GOOD, z = 8 })
	local rewardTag = Style.stamp(cashPlate, "PREVIEW", "Gold", 10)
	rewardTag.frame.Rotation = 0
	rewardTag.frame.AnchorPoint = Vector2.new(1, 0.5)
	rewardTag.frame:SetAttribute("PersistentPreview", true)
	local unlockPlate: Frame = make("Frame", {
		Name = "UnlockPlate",
		BackgroundColor3 = rgb(214, 236, 255),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = rewardHolder,
	})
	Arcade.corner(unlockPlate, 10)
	Arcade.outline(unlockPlate, "Minor")
	local unlockIcon = CardKit.icon(unlockPlate, { "PaintBucket", "Medal" }, 26, 8)
	unlockIcon.AnchorPoint = Vector2.new(0, 0.5)
	unlockIcon.Position = UDim2.new(0, 6, 0.5, 0)
	local unlockText =
		CardKit.ink(unlockPlate, "", 16, { name = "Unlock", xAlign = Enum.TextXAlignment.Left, wrapped = true, z = 8 })

	-- RENDER ---------------------------------------------------------------------------------------------------------------

	local function medalShape(key: string?): string
		if key == "gold" then
			return "seal"
		elseif key == "silver" then
			return "diamond"
		elseif key == "bronze" then
			return "disc"
		end
		return "none"
	end

	local function renderMedal(v: StuntFixtures.ResultView)
		for _, child in badgeHolder:GetChildren() do
			child:Destroy()
		end
		if v.medal then
			StuntKit.medalBadge(badgeHolder, v.medal, geo.badge, 9)
		else
			-- no medal: a plain flag tile (a warning mark for an unfinished run), never a fake empty medal
			local tile = Style.well(badgeHolder, "NoMedal", 9)
			tile.Size = UDim2.fromScale(1, 1)
			Arcade.corner(tile, geo.badge / 2)
			local holder: Frame = make("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.6, 0.6),
				BackgroundTransparency = 1,
				ZIndex = 10,
				Parent = tile,
			})
			IconArt.draw(holder, if v.finished then { "Flag" } else { "Warning", "Flag" })
		end
	end

	-- the three medal targets, with a tick for each one THIS run reached (an empty box for a missed one)
	local function renderTargets()
		targetsTrove:Clean()
		for _, child in targetsHolder:GetChildren() do
			child:Destroy()
		end
		table.clear(ticks)
		local r = current
		if not r then
			return
		end
		local rows = StuntFixtures.medalRows(r, targets)
		local compact = geo.fit == "Compact"
		for i, row in rows do
			table.insert(ticks, row.reached)
			local info = (StuntFixtures.Medals :: { [string]: StuntFixtures.MedalInfo })[row.key]
			local plateRow: Frame = make("Frame", {
				Name = "Target_" .. info.word,
				BackgroundColor3 = CardKit.CreamShade,
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = targetsHolder,
			})
			Arcade.corner(plateRow, 8)
			Arcade.outline(plateRow, "Minor")
			plateRow:SetAttribute("Reached", row.reached)
			local rowHeight = if compact then 36 else geo.rowH
			local w = geo.right.w
			if compact then
				local chipW = math.floor((w - 8) / 3)
				plateRow.Position = UDim2.fromOffset((i - 1) * (chipW + 4), 0)
				plateRow.Size = UDim2.fromOffset(chipW, rowHeight)
			else
				plateRow.Position = UDim2.fromOffset(0, (i - 1) * (rowHeight + 3))
				plateRow.Size = UDim2.fromOffset(w, rowHeight)
			end
			local disc: Frame = make("Frame", {
				Name = "Disc",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 5, 0.5, 0),
				Size = UDim2.fromOffset(rowHeight - 10, rowHeight - 10),
				BackgroundColor3 = info.colour,
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = plateRow,
			})
			Arcade.corner(disc, 99)
			Arcade.outline(disc, 2)
			local letter = Arcade.text(
				disc,
				{ text = info.letter, role = "Badge", name = "Letter", colour = Style.Ink, z = 9, size = 16 }
			)
			letter.Size = UDim2.fromScale(1, 1)
			local letterStroke = letter:FindFirstChildOfClass("UIStroke")
			if letterStroke then
				letterStroke.Enabled = false
			end
			local left = rowHeight - 2
			local tickSize = math.min(rowHeight - 10, 22)
			if not compact then
				local word =
					CardKit.ink(plateRow, info.word, 18, { name = "Word", xAlign = Enum.TextXAlignment.Left, z = 8 })
				word.Position = UDim2.fromOffset(left, 0)
				word.Size = UDim2.fromScale(0.34, 1)
			end
			local timeLabel = CardKit.ink(plateRow, StuntFixtures.formatTime(row.target), if compact then 16 else 20, {
				name = "Time",
				xAlign = if compact then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				z = 8,
			})
			if compact then
				timeLabel.Position = UDim2.fromOffset(left, 0)
				timeLabel.Size = UDim2.new(1, -left - tickSize - 8, 1, 0)
			else
				timeLabel.Position = UDim2.new(0.34, left, 0, 0)
				timeLabel.Size = UDim2.new(0.66, -left - tickSize - 14, 1, 0)
			end
			-- tick or empty box: the shape says it, not only the colour
			local mark: Frame = make("Frame", {
				Name = if row.reached then "Tick" else "Missed",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -5, 0.5, 0),
				Size = UDim2.fromOffset(tickSize, tickSize),
				BackgroundColor3 = if row.reached then rgb(46, 190, 90) else CardKit.Cream,
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = plateRow,
			})
			Arcade.corner(mark, 5)
			Arcade.outline(mark, 2)
			if row.reached then
				local holder = CardKit.icon(mark, { "Check" }, tickSize - 4, 9)
				holder.AnchorPoint = Vector2.new(0.5, 0.5)
				holder.Position = UDim2.fromScale(0.5, 0.5)
			end
		end
	end

	local function render()
		local v, r = view, current
		if not v or not r then
			return
		end
		timeText.Text = v.timeText
		plate.label.Text = if v.finished then "FINISH!" else "NOT FINISHED"
		ribbon.frame.Visible = v.newBest
		local text, tone = StuntFixtures.ghostLine(r)
		ghostTone = tone
		ghostLabel.Text = text
		ghostLabel.TextColor3 = if tone == "faster"
			then GOOD
			else if tone == "none" then CardKit.NavySoft else CardKit.Navy
		medalPrimary.Text = v.medalPrimary
		medalSecondary.Text = v.medalSecondary
		-- the reward (PREVIEW): Cash by medal, and what the medal opens; an unfinished run earns and opens nothing
		local key = v.medal
		if v.finished then
			local cash = (StuntFixtures.RewardPreview :: { [string]: number })[key or "none"]
			rewardLine = "+" .. Format.cash(cash)
			unlockLine = if key then (StuntFixtures.UnlockPreview :: { [string]: string })[key] else ""
		else
			rewardLine = "No reward yet"
			unlockLine = "Cross the finish line to set a time."
		end
		rewardText.Text = rewardLine
		unlockText.Text = unlockLine
		rewardCoin.Visible = v.finished
		rewardTagWanted = v.finished
		rewardTag.frame.Visible = v.finished
		unlockPlate.Visible = unlockLine ~= ""
		renderMedal(v)
		renderTargets()
	end

	-- the buttons: equal size, rebuilt only when the size changes -------------------------------------------------------
	local retryButton: Arcade.Button? = nil
	local homeButton: Arcade.Button? = nil
	local function setPending(which: string)
		pending = which
		local retry, home = retryButton, homeButton
		if retry and home then
			local locked = which ~= ""
			retry.setEnabled(not locked)
			home.setEnabled(not locked)
			retry.setLabel(if which == "Retry" then "WAIT..." else "RETRY")
			home.setLabel(if which == "Home" then "WAIT..." else "HOME")
		end
	end
	local function buildButtons()
		local key = string.format("%dx%d", geo.button.X, geo.button.Y)
		if key == builtKey and retryButton then
			return
		end
		builtKey = key
		buttonsTrove:Clean()
		local retry = Arcade.button(body, {
			name = "Retry",
			label = "RETRY",
			fill = "Retry",
			size = "Custom",
			width = geo.button.X,
			height = geo.button.Y,
			icon = "Retry",
			pattern = true,
			cooldown = 0.6,
			onActivate = function()
				results:pressRetry()
			end,
		})
		buttonsTrove:Add(retry.trove)
		retry.root.ZIndex = 12
		local home = Arcade.button(body, {
			name = "Home",
			label = "HOME",
			fill = "Garage",
			size = "Custom",
			width = geo.button.X,
			height = geo.button.Y,
			icon = "Home",
			sound = "Close",
			cooldown = 0.6,
			onActivate = function()
				results:pressHome()
			end,
		})
		buttonsTrove:Add(home.trove)
		home.root.ZIndex = 12
		retryButton, homeButton = retry, home
		setPending(pending)
	end

	local function layoutNow()
		overlay:applyScale()
		geo = StuntResults.geometry(overlay:designSize())
		stage.Size = UDim2.fromOffset(geo.cw, geo.stageH)
		card.root.AnchorPoint = Vector2.zero
		card.root.Position = UDim2.fromOffset(0, OVERHANG)
		card.root.Size = UDim2.fromOffset(geo.cw, geo.ch)
		plate:fit(geo.cw - 220)
		plate.root.Position = UDim2.fromOffset(geo.cw / 2, OVERHANG)
		preview.frame.Position = UDim2.fromOffset(geo.cw - 8, OVERHANG)
		-- left: the medal block
		local l = geo.left
		medalGroup.Position = UDim2.fromOffset(l.x, l.y)
		medalGroup.Size = UDim2.fromOffset(l.w, l.h)
		-- the car takes what the medal and its two lines leave (never more than 150 wide), so its wheels and its shadow stay
		-- inside the block (the block is a CanvasGroup: whatever hangs past its foot is cut)
		local fixedH = geo.badge + 4 + 26 + 20 + 6
		local carH = math.min(math.min(l.w * 0.8, 150) * 0.56, math.max(l.h - fixedH - 10, 30))
		local carW = carH / 0.56
		local blockH = fixedH + carH
		local top = math.max((l.h - blockH - 6) / 2, 0)
		rays.root.Position = UDim2.fromOffset(l.w / 2, top + geo.badge / 2)
		rays:setRadius(geo.badge * 0.95)
		badgeHolder.Position = UDim2.fromOffset(l.w / 2, top)
		badgeHolder.Size = UDim2.fromOffset(geo.badge, geo.badge)
		medalPrimary.Position = UDim2.fromOffset(0, top + geo.badge + 4)
		medalPrimary.Size = UDim2.fromOffset(l.w, 26)
		medalSecondary.Position = UDim2.fromOffset(0, top + geo.badge + 30)
		medalSecondary.Size = UDim2.fromOffset(l.w, 20)
		car.root.Size = UDim2.fromOffset(carW, carH)
		car.root.AnchorPoint = Vector2.new(0.5, 1)
		car.root.Position = UDim2.fromOffset(l.w / 2, top + blockH)
		-- right: the figures
		local r = geo.right
		local y = r.y
		local timeH = geo.timeSize + 10
		timeRow.Position = UDim2.fromOffset(r.x, y)
		timeRow.Size = UDim2.fromOffset(r.w, timeH)
		local icon = geo.timeSize
		timeIcon.Size = UDim2.fromOffset(icon, icon)
		timeText.Position = UDim2.fromOffset(icon + 8, timeH / 2)
		timeText.Size = UDim2.fromOffset(r.w - icon - 8, geo.timeSize + 6)
		timeText.TextSize = geo.timeSize
		y += timeH + 4
		-- NEW BEST! then the ghost gap on one row
		ribbon.frame.AnchorPoint = Vector2.new(0, 0.5)
		ribbon.frame.Position = UDim2.fromOffset(r.x + 4, y + 14)
		local ribbonW = if ribbon.frame.Visible then math.ceil(SupportKit.measure("NEW BEST!", 16).X) + 30 else 0
		ghostLabel.Position = UDim2.fromOffset(r.x + (if ribbon.frame.Visible then ribbonW + 10 else 0), y)
		ghostLabel.Size = UDim2.fromOffset(r.w - (if ribbon.frame.Visible then ribbonW + 10 else 0), 28)
		y += 28 + 4
		targetsHolder.Position = UDim2.fromOffset(r.x, y)
		targetsHolder.Size = UDim2.fromOffset(r.w, geo.targetsH)
		y += geo.targetsH + 4
		rewardHolder.Position = UDim2.fromOffset(r.x, y)
		rewardHolder.Size = UDim2.fromOffset(r.w, geo.rewardH)
		local unlockShown = unlockPlate.Visible
		-- The Cash plate is as wide as its amount needs (coin, "+$1,500", and the PREVIEW tag when the unlock line keeps room
		-- enough to read beside it): a fixed share of the row left the amount 38 px wide, so it wrapped. The card's own PREVIEW
		-- chip stays on the stage whether or not the small tag fits here.
		local amountW = math.ceil(SupportKit.measure(rewardLine, 22).X * 1.12) + 10
		local tagW = math.ceil(SupportKit.measure("PREVIEW", 16).X * 1.12) + 34
		local plain = 36 + amountW + 8
		local tagFits = rewardTagWanted
		local cashW = r.w
		if unlockShown then
			-- never more than a little over half the row, so the unlock line keeps two readable rows
			local limit = math.floor(r.w * 0.56)
			tagFits = rewardTagWanted and plain + tagW + 6 <= limit and r.w - (plain + tagW + 6) - 4 >= 170
			cashW = math.min(if tagFits then plain + tagW + 6 else plain, limit)
		end
		rewardTag.frame.Visible = tagFits
		cashPlate.Size = UDim2.fromOffset(cashW, geo.rewardH)
		rewardText.Position = UDim2.fromOffset(36, 0)
		rewardText.Size = UDim2.new(1, -36 - (if tagFits then tagW + 6 else 4), 1, 0)
		rewardTag.frame.Position = UDim2.new(1, -5, 0.5, 0)
		local unlockW = r.w - cashW - 4
		unlockPlate.Position = UDim2.fromOffset(cashW + 4, 0)
		unlockPlate.Size = UDim2.fromOffset(unlockW, geo.rewardH)
		-- a narrow unlock plate gives up its icon, so the line keeps two readable rows
		local iconRoom = if unlockW >= 200 then 36 else 8
		unlockIcon.Visible = unlockW >= 200
		unlockText.Position = UDim2.fromOffset(iconRoom, 0)
		unlockText.Size = UDim2.new(1, -iconRoom - 6, 1, 0)
		SupportKit.fitLabel(unlockText, unlockText.Text, unlockW - iconRoom - 6, geo.rewardH - 4, 18)
		unlockText.TextColor3 = CardKit.Navy
		y += geo.rewardH + 6
		buildButtons()
		local retry, home = retryButton, homeButton
		if retry and home then
			local gap = 12
			local total = geo.button.X * 2 + gap
			local x0 = r.x + (r.w - total) / 2
			retry.root.AnchorPoint = Vector2.new(0, 0)
			home.root.AnchorPoint = Vector2.new(0, 0)
			retry.root.Position = UDim2.fromOffset(x0, y)
			home.root.Position = UDim2.fromOffset(x0 + geo.button.X + gap, y)
		end
		if view then
			renderMedal(view)
			renderTargets()
		end
	end

	-- THE REVEAL -----------------------------------------------------------------------------------------------------------

	local function cancelBurst()
		local cancel = burstCancel
		if cancel then
			burstCancel = nil
			cancel()
		end
	end

	local function showFinal()
		revealToken += 1
		revealTrove:Clean()
		cancelBurst()
		Motion.cancelAll(medalGroup)
		Motion.cancelAll(medalScale)
		medalGroup.GroupTransparency = 0
		medalScale.Scale = 1
		phase = "Settled"
	end

	local function startReveal()
		revealToken += 1
		local token = revealToken
		revealTrove:Clean()
		cancelBurst()
		Motion.cancelAll(medalGroup)
		Motion.cancelAll(medalScale)
		if Motion.reduced() then
			-- the whole result at once, with a short fade and no movement
			medalScale.Scale = 1
			medalGroup.GroupTransparency = 1
			Motion.tween(medalGroup, "fade", Motion.info(StuntResults.ReducedFade), { GroupTransparency = 0 })
			phase = "Settled"
			return
		end
		phase = "Time"
		medalScale.Scale = 0.6
		medalGroup.GroupTransparency = 1
		revealTrove:Add(task.delay(StuntResults.RevealStart, function()
			if token ~= revealToken then
				return
			end
			phase = "Reveal"
			Motion.tween(medalGroup, "fade", Motion.info(0.18), { GroupTransparency = 0 })
			Motion.tween(
				medalScale,
				"pop",
				Motion.info(StuntResults.RevealSeconds, Enum.EasingStyle.Back),
				{ Scale = 1.12 }
			)
		end))
		revealTrove:Add(task.delay(StuntResults.BurstAt, function()
			if token ~= revealToken then
				return
			end
			phase = "Settle"
			Motion.tween(medalScale, "pop", Motion.info(StuntResults.SettleSeconds), { Scale = 1 })
			local v = view
			if v and v.medal then
				-- a matching celebration: more pieces for a better medal
				local count = if v.medal == "gold" then 24 elseif v.medal == "silver" then 16 else 10
				local l = geo.left
				local centre =
					Vector2.new(l.x + l.w / 2, l.y + math.max((l.h - (geo.badge + 90)) / 2, 0) + geo.badge / 2)
				burstFired += 1
				burstCancel = SupportKit.burst(body, centre, count, 1700 + burstFired)
			end
		end))
		revealTrove:Add(task.delay(StuntResults.BurstAt + StuntResults.SettleSeconds, function()
			if token == revealToken then
				phase = "Settled"
			end
		end))
	end

	-- PUBLIC -----------------------------------------------------------------------------------------------------------

	overlay:setBack(function()
		results:pressHome()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)
	trove:Add(function()
		revealToken += 1
		cancelBurst()
		Motion.cancelAll(medalGroup)
		Motion.cancelAll(medalScale)
	end)

	results = {
		root = overlay.root,
		layout = function(_self: Results)
			layoutNow()
		end,
		setVisible = function(_self: Results, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(self: Results, _returnTo: GuiObject?)
			-- the harness opens every screen with :open(); the card opens on the last result shown (Gold the first time)
			self:setPreset(
				if presetName ~= "" and (StuntFixtures.Results :: any)[presetName] then presetName else "Gold"
			)
		end,
		show = function(_self: Results, r: StuntFixtures.Result)
			presetName = r.id
			current = r
			view = StuntFixtures.describe(r, targets)
			guard:reset()
			pending = ""
			render()
			layoutNow()
			-- the figures depend on what shows (NEW BEST!, the unlock plate): place them again now that it does
			layoutNow()
			if not overlay:isOpen() then
				local b = retryButton
				overlay:open(if b then b.body else nil, nil)
			end
			startReveal()
		end,
		setPreset = function(self: Results, name: string): boolean
			local r = (StuntFixtures.Results :: any)[name] :: StuntFixtures.Result?
			if not r then
				return false
			end
			self:show(r)
			return true
		end,
		close = function(_self: Results)
			if not overlay:isOpen() then
				return
			end
			showFinal()
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Results): boolean
			return overlay:isOpen()
		end,
		finishNow = function(_self: Results)
			showFinal()
		end,
		pressRetry = function(_self: Results): boolean
			retryPresses += 1
			if not guard:tryFire() then
				return false -- a second press for the same result does nothing
			end
			retryCalls += 1
			setPending("Retry")
			if opts.onRetry then
				opts.onRetry()
			end
			return true
		end,
		pressHome = function(_self: Results): boolean
			homePresses += 1
			if not guard:tryFire() then
				return false
			end
			homeCalls += 1
			setPending("Home")
			if opts.onHome then
				opts.onHome()
			end
			return true
		end,
		destroy = function(_self: Results)
			overlay:destroy()
		end,
		getDebugState = function(_self: Results): DebugState
			local v = view
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				preset = presetName,
				timeText = timeText.Text,
				ribbonVisible = ribbon.frame.Visible,
				ribbonText = ribbon.label.Text,
				pbText = if v then v.pbText else "",
				bestText = if v then v.bestText else "",
				ghostText = ghostLabel.Text,
				ghostTone = ghostTone,
				medal = if v and v.medal then v.medal else "none",
				medalShape = medalShape(if v then v.medal else nil),
				medalPrimary = medalPrimary.Text,
				medalSecondary = medalSecondary.Text,
				ticks = table.clone(ticks),
				rewardText = rewardLine,
				unlockText = unlockLine,
				rewardVisible = rewardHolder.Visible,
				phase = phase,
				reduced = Motion.reduced(),
				burstFired = burstFired,
				retryPresses = retryPresses,
				homePresses = homePresses,
				retryCalls = retryCalls,
				homeCalls = homeCalls,
				pending = pending,
				caption = preview.label.Text,
				title = plate.label.Text,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: Results): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	layoutNow()
	return results
end

return StuntResults
