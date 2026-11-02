--!strict
-- StuntResults: the card at the end of a Stunt Circuit lap (Lane 3, big round M17-04a and M17-04b; PREVIEW). It shows, in this
-- order, the final TIME, the personal-best comparison, and the MEDAL; RETRY and HOME are equal in size and usable from the
-- first frame.
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
-- WORDS (M17-04a): no medal is "Lap complete!" / "Try again for Bronze."; a personal best is "NEW BEST!" and "0.84s faster", shown
-- only when the fixture supports it (a first lap says "First time on the board"; a slower lap says how much slower and never shows
-- the ribbon). An unfinished run shows "--:--.--" and "Run not finished", no medal and no ribbon. Bronze, Silver and Gold differ in
-- SILHOUETTE (a round disc, a diamond, a pointed seal) and in their word, not only colour.
--
-- TIMING (M17-04a): the time and the comparison are on screen at once; the medal reveal starts at 350 ms, settles over 250 ms, and a
-- small burst fires at 600 ms. REDUCED MOTION shows the whole result immediately with a short (0.15 s) fade and no burst.
--
-- NOTHING IS GRANTED. There is no reward here: the card shows no Cash and no item. The targets are named PREVIEW values (they stay
-- until Brian R measures them with the real car physics) and a PREVIEW chip stays in the header at all times.

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)
local StuntKit = require(script.Parent.StuntKit)
local SupportKit = require(script.Parent.SupportKit)

local A = PreviewTokens.Arcade
local make = Arcade.make

local StuntResults = {}

StuntResults.RevealStart = 0.35 -- seconds after the card opens
StuntResults.RevealSeconds = 0.25
StuntResults.SettleSeconds = 0.25
StuntResults.BurstAt = 0.6
StuntResults.ReducedFade = 0.15

export type Options = {
	targets: StuntFixtures.Targets?,
	onRetry: (() -> ())?,
	onHome: (() -> ())?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	left: Rect,
	right: Rect,
	foot: Rect,
	timeSize: number,
	badge: number,
	buttonSize: Vector2,
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
	medal: string,
	medalShape: string,
	medalPrimary: string,
	medalSecondary: string,
	phase: Phase,
	reduced: boolean,
	burstFired: number,
	retryPresses: number,
	homePresses: number,
	retryCalls: number,
	homeCalls: number,
	caption: string,
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

function StuntResults.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH, footH, timeSize, badge, button
	if fit == "Compact" then
		pw, ph, headH, footH, timeSize, badge = math.min(ds.X - 12, 580), ds.Y - 8, 46, 66, 40, 84
		button = Vector2.new(170, 54)
	elseif fit == "Regular" then
		pw, ph, headH, footH, timeSize, badge = math.min(ds.X - 24, 640), math.min(ds.Y - 16, 400), 54, 76, 48, 108
		button = Vector2.new(200, 58)
	else
		pw, ph, headH, footH, timeSize, badge = math.min(ds.X - 32, 740), math.min(ds.Y - 24, 460), 60, 84, 56, 128
		button = Vector2.new(220, 62)
	end
	local pad = 14
	local top = headH + 8
	local bodyH = ph - top - footH - 4
	local leftW = math.floor((pw - pad * 3) * 0.54)
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		left = { x = pad, y = top, w = leftW, h = bodyH },
		right = { x = pad * 2 + leftW, y = top, w = pw - pad * 3 - leftW, h = bodyH },
		foot = { x = pad, y = ph - footH - 2, w = pw - pad * 2, h = footH },
		timeSize = timeSize,
		badge = badge,
		buttonSize = button,
	}
end

-- BUILD ------------------------------------------------------------------------------------------------------------------

function StuntResults.new(ctx: Overlay.Ctx, options: Options?): Results
	local opts: Options = options or {}
	local targets: StuntFixtures.Targets = opts.targets or table.clone(StuntFixtures.MedalTargets)
	local geo = StuntResults.geometry(Vector2.new(750, 325))
	local view: StuntFixtures.ResultView? = nil
	local presetName = ""
	local phase: Phase = "Settled"
	local revealToken = 0
	local burstCancel: (() -> ())? = nil
	local burstFired = 0
	local retryPresses, homePresses, retryCalls, homeCalls = 0, 0, 0, 0
	local guard = SupportKit.guard()
	local builtDims = ""
	local results: Results

	local overlay = Overlay.new(ctx, { name = "StuntResults" })
	local trove = overlay.trove
	local revealTrove = trove:Extend()
	local buttonsTrove = trove:Extend()
	local content = overlay.content
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Gold", title = "STUNT CIRCUIT", icon = "Flag", rightInset = 130 })
	local preview = StuntKit.previewChip(header.band, nil, 12)
	preview.frame.AnchorPoint = Vector2.new(1, 0.5)

	-- left: the time first, then the personal-best comparison
	local timeLabel = Style.text(panel, "TIME", "Small", { name = "TimeLabel", z = 6 })
	timeLabel.TextColor3 = Style.TextSoft
	local timeText = Style.text(panel, "0:00.00", "Value", { name = "Time", italic = true, face = "White", z = 6 })
	local ribbon = Style.stamp(panel, "NEW BEST!", "Retry", 9)
	ribbon.frame.Name = "NewBestRibbon"
	local pbLabel = SupportKit.label(panel, "Comparison", 22, 6)
	local bestLabel = SupportKit.label(panel, "Best", 18, 6)
	bestLabel.TextColor3 = Style.TextSoft

	-- right: the medal block (a CanvasGroup so it can fade as one piece)
	local medalGroup: CanvasGroup = make("CanvasGroup", {
		Name = "MedalBlock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = panel,
	})
	local medalScale: UIScale = make("UIScale", { Name = "Reveal", Parent = medalGroup })
	local badgeHolder: Frame = make("Frame", {
		Name = "BadgeHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = medalGroup,
	})
	local medalPrimary = SupportKit.label(medalGroup, "Primary", 24, 7)
	medalPrimary.TextXAlignment = Enum.TextXAlignment.Center
	local medalSecondary = SupportKit.label(medalGroup, "Secondary", 18, 7)
	medalSecondary.TextXAlignment = Enum.TextXAlignment.Center
	medalSecondary.TextColor3 = Style.TextSoft

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
			StuntKit.medalBadge(badgeHolder, v.medal, geo.badge, 8)
		else
			-- no medal: a plain flag tile (a warning mark for an unfinished run), never a fake empty medal
			local tile = Style.well(badgeHolder, "NoMedal", 8)
			tile.Size = UDim2.fromScale(1, 1)
			Arcade.corner(tile, geo.badge / 2)
			local holder: Frame = make("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.6, 0.6),
				BackgroundTransparency = 1,
				ZIndex = 9,
				Parent = tile,
			})
			IconArt.draw(holder, if v.finished then { "Flag" } else { "Warning", "Flag" })
		end
	end

	local function render()
		local v = view
		if not v then
			return
		end
		timeText.Text = v.timeText
		ribbon.frame.Visible = v.newBest
		pbLabel.Text = v.pbText
		bestLabel.Text = v.bestText
		medalPrimary.Text = v.medalPrimary
		medalSecondary.Text = v.medalSecondary
		renderMedal(v)
	end

	-- the buttons: equal size, rebuilt only when the size changes --------------------------------------------------------

	local retryButton: Arcade.Button? = nil
	local function buildButtons()
		local key = string.format("%dx%d", geo.buttonSize.X, geo.buttonSize.Y)
		if key == builtDims and retryButton then
			return
		end
		builtDims = key
		buttonsTrove:Clean()
		local retry = Arcade.button(panel, {
			name = "Retry",
			label = "RETRY",
			fill = "Retry",
			size = "Custom",
			width = geo.buttonSize.X,
			height = geo.buttonSize.Y,
			pattern = true,
			cooldown = 0.6,
			onActivate = function()
				results:pressRetry()
			end,
		})
		buttonsTrove:Add(retry.trove)
		retry.root.ZIndex = 12
		local home = Arcade.button(panel, {
			name = "Home",
			label = "HOME",
			fill = "Home",
			size = "Custom",
			width = geo.buttonSize.X,
			height = geo.buttonSize.Y,
			sound = "Close",
			cooldown = 0.6,
			onActivate = function()
				results:pressHome()
			end,
		})
		buttonsTrove:Add(home.trove)
		home.root.ZIndex = 12
		retryButton = retry
		local f = geo.foot
		local gap = 18
		local y = f.y + f.h / 2
		local totalW = geo.buttonSize.X * 2 + gap
		local x0 = f.x + (f.w - totalW) / 2
		retry.root.AnchorPoint = Vector2.new(0, 0.5)
		home.root.AnchorPoint = Vector2.new(0, 0.5)
		retry.root.Position = UDim2.fromOffset(x0, y)
		home.root.Position = UDim2.fromOffset(x0 + geo.buttonSize.X + gap, y)
	end

	local function layoutNow()
		overlay:applyScale()
		geo = StuntResults.geometry(overlay:designSize())
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		header.title.Size =
			UDim2.new(1, -header.title.Position.X.Offset - 130, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		preview.frame.Position = UDim2.new(1, -12, 0.5, 0)
		-- left column: TIME label, the time, the ribbon beside the comparison, the best line
		local l = geo.left
		timeLabel.Position = UDim2.fromOffset(l.x, l.y)
		timeLabel.Size = UDim2.fromOffset(l.w, 22)
		timeText.Position = UDim2.fromOffset(l.x, l.y + 22)
		timeText.Size = UDim2.fromOffset(l.w, geo.timeSize + 10)
		local y = l.y + 22 + geo.timeSize + 14
		ribbon.frame.Position = UDim2.fromOffset(l.x + 6, y)
		pbLabel.Position = UDim2.fromOffset(l.x, y + 32)
		pbLabel.Size = UDim2.fromOffset(l.w, 30)
		bestLabel.Position = UDim2.fromOffset(l.x, y + 64)
		bestLabel.Size = UDim2.fromOffset(l.w, 26)
		-- right column: the medal block
		local r = geo.right
		local blockH = geo.badge + 8 + 30 + 26
		medalGroup.Size = UDim2.fromOffset(r.w, blockH)
		medalGroup.Position = UDim2.fromOffset(r.x + r.w / 2, r.y + math.max(blockH / 2, r.h / 2))
		badgeHolder.Position = UDim2.fromScale(0.5, 0)
		badgeHolder.Size = UDim2.fromOffset(geo.badge, geo.badge)
		medalPrimary.Position = UDim2.fromOffset(0, geo.badge + 6)
		medalPrimary.Size = UDim2.fromOffset(r.w, 30)
		medalSecondary.Position = UDim2.fromOffset(0, geo.badge + 36)
		medalSecondary.Size = UDim2.fromOffset(r.w, 26)
		local v = view
		if v then
			local sizeCap = timeText:FindFirstChildOfClass("UITextSizeConstraint")
			if sizeCap then
				sizeCap.MaxTextSize = geo.timeSize
			end
			SupportKit.fitLabel(pbLabel, pbLabel.Text, l.w, 30, 22)
			SupportKit.fitLabel(bestLabel, bestLabel.Text, l.w, 26, 18)
			SupportKit.fitLabel(medalPrimary, medalPrimary.Text, r.w, 30, 24)
			SupportKit.fitLabel(medalSecondary, medalSecondary.Text, r.w, 26, 18)
			renderMedal(v)
		end
		buildButtons()
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
				local r = geo.right
				local blockH = geo.badge + 64
				local groupY = r.y + math.max(blockH / 2, r.h / 2)
				local centre = Vector2.new(r.x + r.w / 2, groupY - blockH / 2 + geo.badge / 2)
				burstFired += 1
				burstCancel = SupportKit.burst(panel, centre, 18, 1700 + burstFired)
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
			view = StuntFixtures.describe(r, targets)
			guard:reset()
			render()
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
				pbText = pbLabel.Text,
				bestText = bestLabel.Text,
				medal = if v and v.medal then v.medal else "none",
				medalShape = medalShape(if v then v.medal else nil),
				medalPrimary = medalPrimary.Text,
				medalSecondary = medalSecondary.Text,
				phase = phase,
				reduced = Motion.reduced(),
				burstFired = burstFired,
				retryPresses = retryPresses,
				homePresses = homePresses,
				retryCalls = retryCalls,
				homeCalls = homeCalls,
				caption = preview.label.Text,
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
