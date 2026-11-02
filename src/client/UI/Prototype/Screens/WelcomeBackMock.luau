--!strict
-- WelcomeBackMock: the "Welcome back!" card shown once when the player returns (Lane 3, big round M14; PREVIEW).
-- One focused card: a miniature of the Raceway with the Lineup cars doing a quick lap, a large "+$amount", "Earned while
-- you were away", "Already added to your Cash", the time away, a small honest cap note and a big COLLECT!.
--
--   local welcome = WelcomeBackMock.new(ctx, { onCollect = fn?, cashTarget = fn?, data = Data? })
--   welcome:open(returnTo?) -> boolean   -- false when the card is suppressed (a verified zero) or already open
--   welcome:request() -> boolean         -- the QUEUED entry: honours options.gate (WelcomeFixtures.newGate), then opens
--   welcome:close()  welcome:isOpen()  welcome:skip()  welcome:pressCollect()
--   welcome:setData(data)  welcome:setPreset("Huge")  welcome:setEarnings(amount)   -- WelcomeFixtures presets
--   welcome:layout()  welcome:setVisible(on)  welcome:destroy()  welcome:getDebugState()  welcome:touchReport()
--   WelcomeBackMock.geometry(designSize) -> Geo
--
-- THE CASH IS ALREADY IN THE BALANCE when this card appears. COLLECT only acknowledges the summary: it flies a few coins
-- toward the Cash counter (purely visual; `options.cashTarget()` returns the counter's absolute screen position, nil =
-- the top-left corner), calls options.onCollect once, and closes. Nothing on this card reads or writes a balance.
--
-- STATES. Ready (amount above zero): the full card. A verified zero is SUPPRESSED (open returns false). Checking and Error
-- are neutral ("Checking your earnings...", "Could not load this right now.") with a CLOSE, never "$0 earned".
-- TIMING. The lap starts at once, the number starts counting at 600 ms and COLLECT is active from the first frame; tapping
-- COLLECT during the reveal finishes it and collects in that one action. Reduced motion: the final value, parked cars,
-- and no coin flight (the card just closes with the overlay's short fade).
-- QUEUEING (M14-02) is the lead's: open this only after the loading screen has gone, outside the first tutorial steps,
-- and with no group or shop modal open (see GroupFixtures.Gate for the shared rule).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local WelcomeFixtures = require(Prototype.SupportFixtures.WelcomeFixtures)

local A = PreviewTokens.Arcade
local make = Arcade.make

local WelcomeBackMock = {}

WelcomeBackMock.DefaultEarnings = 1240

-- Timings (seconds). The number starts at 600 ms as the brief asks; the lap is the "quick lap".
local LAP_SECONDS = 1.5
local COUNT_DELAY = 0.6
local COUNT_MIN = 0.45
local COUNT_MAX = 0.9
local COIN_COUNT = 9
local COIN_FLIGHT = 0.55
local COIN_STAGGER = 0.045
local RING = 24 -- width of the asphalt ring on the miniature track

export type Options = {
	onCollect: (() -> ())?,
	cashTarget: (() -> Vector2?)?, -- absolute screen position of the Cash counter, for the coin flight
	data: WelcomeFixtures.Data?,
	gate: WelcomeFixtures.Gate?, -- the queue rule for welcome:request()
	cars: { WelcomeFixtures.LineupCar }?, -- overrides data.lineup
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	track: Rect, -- the miniature, in panel px
	lineup: Rect, -- the "Your Lineup" caption
	right: Rect, -- the text column
	amountSize: number,
	labelSize: number,
	button: Vector2,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	state: string, -- Ready | Checking | Error | Suppressed
	suppressed: boolean, -- the last open() declined to show a verified zero
	revealing: boolean,
	shownEarnings: number,
	earnings: number,
	cars: number,
	collectCalls: number,
	coinsLaunched: number,
	balanceTouched: boolean, -- always false: this card never reads or writes a balance
	timeLine: string,
	note: string,
	amountText: string,
	reduced: boolean,
	gate: string, -- the last reason welcome:request() was declined
}

export type Welcome = {
	root: Frame,
	layout: (self: Welcome) -> (),
	setVisible: (self: Welcome, on: boolean) -> (),
	open: (self: Welcome, returnTo: GuiObject?) -> boolean,
	request: (self: Welcome) -> boolean,
	close: (self: Welcome) -> (),
	isOpen: (self: Welcome) -> boolean,
	setData: (self: Welcome, data: WelcomeFixtures.Data) -> (),
	setPreset: (self: Welcome, name: string) -> boolean,
	setEarnings: (self: Welcome, amount: number) -> (),
	skip: (self: Welcome) -> (),
	pressCollect: (self: Welcome) -> (),
	destroy: (self: Welcome) -> (),
	getDebugState: (self: Welcome) -> DebugState,
	touchReport: (self: Welcome) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY -----------------------------------------------------------------------------------

-- Two columns at every size: the miniature track on the left, the figures on the right with COLLECT! pinned at the
-- bottom of that column. A pure function of the design-px viewport (844 x 390, 667 x 375, 1024 x 768, 1920 x 1080 ...).
function WelcomeBackMock.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH
	if fit == "Compact" then
		pw, ph, headH = math.min(ds.X - 12, 720), ds.Y - 8, 46
	elseif fit == "Regular" then
		pw, ph, headH = math.min(ds.X - 24, 760), math.min(ds.Y - 16, 460), 58
	else
		pw, ph, headH = math.min(ds.X - 32, 880), math.min(ds.Y - 24, 540), 66
	end
	local leftW = math.floor(pw * (if fit == "Compact" then 0.46 elseif fit == "Regular" then 0.46 else 0.45))
	local trackH = math.min(math.floor(leftW * 0.6), ph - headH - 24 - 30)
	local areaH = ph - headH - 12
	local trackY = headH + math.floor((areaH - trackH - 30) / 2) + 6
	local rightX = 12 + leftW + 12
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		track = { x = 12, y = trackY, w = leftW, h = trackH },
		lineup = { x = 12, y = trackY + trackH + 4, w = leftW, h = 26 },
		right = {
			x = rightX,
			y = headH + (if fit == "Compact" then 8 else 14),
			w = pw - rightX - 12,
			h = ph - headH - 20,
		},
		amountSize = if fit == "Compact" then 40 elseif fit == "Regular" then 48 else 56,
		labelSize = if fit == "Compact" then 16 else 18,
		button = if fit == "Compact" then Vector2.new(210, 56) else Vector2.new(230, 62),
	}
end

-- A point on the centre line of a stadium (two straights and two half circles) after distance `s`, with the heading in
-- degrees (a sprite pointing right has Rotation = heading). Starts at the left end of the bottom straight, heading right.
local function stadium(s: number, wc: number, hc: number): (number, number, number)
	local r = hc / 2
	local straight = math.max(wc - 2 * r, 0)
	local arc = math.pi * r
	local total = 2 * straight + 2 * arc
	local d = s % total
	if d < straight then
		return r + d, hc, 0
	end
	d -= straight
	if d < arc then
		local theta = math.pi / 2 - d / r -- bottom -> right -> top
		return r + straight + r * math.cos(theta), r + r * math.sin(theta), math.deg(theta) - 90
	end
	d -= arc
	if d < straight then
		return r + straight - d, 0, 180
	end
	d -= straight
	local theta = -math.pi / 2 - d / r -- top -> left -> bottom
	return r + r * math.cos(theta), r + r * math.sin(theta), math.deg(theta) - 90
end

local function lapEase(t: number): number
	if t < 0.5 then
		return 2 * t * t
	end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end

-- BUILD --------------------------------------------------------------------------------------

type Sprite = { frame: Frame, offset: number }

function WelcomeBackMock.new(ctx: Overlay.Ctx, options: Options?): Welcome
	local opts: Options = options or {}
	local data: WelcomeFixtures.Data = opts.data or (WelcomeFixtures.preset("Typical") :: WelcomeFixtures.Data)
	local geo = WelcomeBackMock.geometry(Vector2.new(750, 325))
	local shownEarnings = 0
	local revealing = false
	local collected = false
	local collectCalls = 0
	local coinsLaunched = 0
	local suppressed = false
	local lastGate = ""
	local trackW, trackH = 200, 120
	local welcome: Welcome

	local overlay = Overlay.new(ctx, {
		name = "WelcomeBackMock",
		onDim = function()
			if revealing then
				welcome:skip()
			elseif collected == false then
				welcome:close()
			end
		end,
	})
	local trove = overlay.trove
	local revealTrove = trove:Extend()
	local flightTrove = trove:Extend()
	local content = overlay.content

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	-- a catcher under every control: tapping the card body during the reveal finishes it
	local catcher: TextButton = make("TextButton", {
		Name = "SkipCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Selectable = false,
		Active = false,
		AutoButtonColor = false,
		ZIndex = 4,
		Parent = panel,
	})
	trove:Connect(catcher.Activated, function()
		if revealing then
			welcome:skip()
		end
	end)

	local header = Style.header(panel, { fill = "Green", title = "WELCOME BACK!", icon = "Track" })
	-- nothing here is real money yet, so the card says so at all times
	local previewStamp = Style.stamp(header.band, "PREVIEW", "Gold", 9)
	previewStamp.frame.AnchorPoint = Vector2.new(1, 0.5)
	previewStamp.frame.Position = UDim2.new(1, -66, 0.5, 0)
	local closeX = SupportKit.closeX(panel, function()
		welcome:close()
	end)
	trove:Add(closeX.trove)

	-- the miniature Raceway: an asphalt ring around a grass infield, a checkered start line and the Lineup cars
	local trackBox: Frame = make("Frame", {
		Name = "Track",
		BackgroundColor3 = Color3.fromRGB(70, 78, 98),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = panel,
	})
	Arcade.corner(trackBox, 60)
	Arcade.outline(trackBox, "Button")
	local infield: Frame = make("Frame", {
		Name = "Infield",
		Position = UDim2.fromOffset(RING, RING),
		BackgroundColor3 = Color3.fromRGB(96, 184, 100),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = trackBox,
	})
	Arcade.corner(infield, 40)
	Arcade.outline(infield, "Minor")
	for i, spot in { { 0.3, 0.45 }, { 0.5, 0.58 }, { 0.7, 0.4 } } :: { { number } } do
		local tree: Frame = make("Frame", {
			Name = "Tree" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot[1], spot[2]),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.fromRGB(46, 128, 74),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = infield,
		})
		Arcade.corner(tree, 16)
	end
	-- the start line: a short checkered strip across the bottom straight
	local startLine: Frame = make("Frame", {
		Name = "StartLine",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = trackBox,
	})
	for row = 0, 3 do
		for col = 0, 1 do
			if (row + col) % 2 == 0 then
				make("Frame", {
					Name = "Check",
					Position = UDim2.fromScale(col / 2, row / 4),
					Size = UDim2.fromScale(1 / 2, 1 / 4),
					BackgroundColor3 = A.Ink,
					BorderSizePixel = 0,
					ZIndex = 8,
					Parent = startLine,
				})
			end
		end
	end
	local carLayer: Frame = make("Frame", {
		Name = "Lineup",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = trackBox,
	})
	local lineupLabel = SupportKit.label(panel, "LineupLabel", 16, 6)
	lineupLabel.Text = "Your Lineup"
	lineupLabel.TextXAlignment = Enum.TextXAlignment.Center
	lineupLabel.TextColor3 = Style.TextSoft

	local sprites: { Sprite } = {}
	local function buildSprites()
		for _, s in sprites do
			s.frame:Destroy()
		end
		table.clear(sprites)
		local list = opts.cars or data.lineup
		local length = math.clamp(math.floor(trackH * 0.22), 26, 44)
		for i, c in list do
			if i > 3 then
				break
			end
			local car: Frame = make("Frame", {
				Name = "Car_" .. c.id,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(length, math.floor(length * 0.56)),
				BackgroundColor3 = c.paint,
				BorderSizePixel = 0,
				ZIndex = 10,
				Parent = carLayer,
			})
			Arcade.corner(car, 6)
			Arcade.outline(car, "Minor")
			local glass: Frame = make("Frame", {
				Name = "Glass",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.28, 0.64),
				BackgroundColor3 = Color3.fromRGB(28, 44, 86),
				BorderSizePixel = 0,
				ZIndex = 11,
				Parent = car,
			})
			Arcade.corner(glass, 3)
			for _, y in { 0.2, 0.8 } do
				local lamp: Frame = make("Frame", {
					Name = "Lamp",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(0.98, y),
					Size = UDim2.fromScale(0.1, 0.2),
					BackgroundColor3 = Color3.fromRGB(255, 244, 196),
					BorderSizePixel = 0,
					ZIndex = 11,
					Parent = car,
				})
				Arcade.corner(lamp, 2)
			end
			table.insert(sprites, { frame = car, offset = 8 + (i - 1) * (length + 14) })
		end
	end

	local function wcHc(): (number, number)
		return trackW - RING, trackH - RING
	end

	local function placeCars(progress: number)
		local wc, hc = wcHc()
		local r = hc / 2
		local total = 2 * math.max(wc - 2 * r, 0) + 2 * math.pi * r
		for _, s in sprites do
			local x, y, deg = stadium(s.offset + total * progress, wc, hc)
			s.frame.Position = UDim2.fromOffset(RING / 2 + x, RING / 2 + y)
			s.frame.Rotation = deg
		end
	end

	-- the figures
	local earnLabel = SupportKit.label(panel, "EarnLabel", 18, 6)
	earnLabel.Text = "Earned while you were away"
	earnLabel.TextXAlignment = Enum.TextXAlignment.Center
	earnLabel.TextColor3 = Style.TextSoft
	local amount = Style.text(panel, "+$0", "Value", {
		name = "Amount",
		italic = true,
		face = "Cash",
		size = 48,
		xAlign = Enum.TextXAlignment.Center,
		z = 6,
	})
	local addedChip: Frame = make("Frame", {
		Name = "AlreadyAdded",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
		Parent = panel,
	})
	Arcade.corner(addedChip, 7)
	Arcade.outline(addedChip, "Button")
	make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = addedChip })
	local addedIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = addedChip,
	})
	IconArt.draw(addedIcon, { "Check" })
	local addedText = SupportKit.label(addedChip, "Text", 16, 7)
	addedText.Text = "Already added to your Cash"
	addedText.Position = UDim2.fromOffset(32, 0)
	addedText.Size = UDim2.new(1, -36, 1, 0)
	local timeIcon: Frame = make("Frame", {
		Name = "ClockIcon",
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = panel,
	})
	IconArt.draw(timeIcon, { "Timer" })
	local timeLabel = SupportKit.label(panel, "TimeAway", 18, 6)
	local noteLabel = SupportKit.label(panel, "CapNote", 16, 6)
	noteLabel.TextColor3 = Style.TextSoft
	local statusLabel = SupportKit.label(panel, "Status", 20, 6)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center

	local collectButton = Arcade.button(panel, {
		name = "Collect",
		label = "COLLECT!",
		fill = "Green",
		size = "Custom",
		width = 230,
		height = 62,
		pattern = true,
		cooldown = 0.5,
		onActivate = function()
			welcome:pressCollect()
		end,
	})
	trove:Add(collectButton.trove)
	collectButton.root.ZIndex = 12
	local closeButton = Arcade.button(panel, {
		name = "Dismiss",
		label = "CLOSE",
		fill = "Garage",
		size = "Custom",
		width = 190,
		height = 56,
		onActivate = function()
			welcome:close()
		end,
	})
	trove:Add(closeButton.trove)
	closeButton.root.ZIndex = 12

	local coinLayer: Frame = make("Frame", {
		Name = "WelcomeCoins",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 80,
		Parent = ctx.layer,
	})
	trove:Add(coinLayer)
	pcall(function()
		(coinLayer :: any).Interactable = false
	end)

	-- LOGIC ----------------------------------------------------------------------------------

	local function amountText(n: number): string
		return "+" .. Format.cash(n)
	end

	local function setValue(n: number)
		shownEarnings = n
		amount.Text = amountText(n)
	end

	-- the verified amount, or nil when the data does not hold a usable one (the card then shows the neutral state)
	local function verifiedAmount(): number?
		if data.status ~= "Ready" then
			return nil
		end
		local e = data.earned
		if e == nil or e ~= e or e == math.huge or e < 0 then
			return nil
		end
		return math.floor(e)
	end

	local function stateName(): string
		if data.status == "Ready" then
			local v = verifiedAmount()
			if v == nil then
				return "Error"
			elseif v == 0 then
				return "Suppressed"
			end
			return "Ready"
		end
		return data.status
	end

	local function earnedFinal(): number
		return verifiedAmount() or 0
	end

	local function finishReveal()
		revealTrove:Clean()
		revealing = false
		catcher.Active = false
		placeCars(0)
		setValue(earnedFinal())
	end

	local function startReveal()
		revealTrove:Clean()
		if stateName() ~= "Ready" or Motion.reduced() then
			finishReveal()
			return
		end
		revealing = true
		catcher.Active = true
		setValue(0)
		local final = earnedFinal()
		local countSeconds = math.clamp(COUNT_MIN + 0.1 * math.log10(math.max(final, 1)), COUNT_MIN, COUNT_MAX)
		local t0 = os.clock()
		local counting = false
		revealTrove:Connect(RunService.Heartbeat, function()
			local t = os.clock() - t0
			placeCars(lapEase(math.clamp(t / LAP_SECONDS, 0, 1)))
			if t >= COUNT_DELAY then
				if not counting then
					counting = true
					revealTrove:Add(Sounds.loop("ResultsCount"))
				end
				local a = math.clamp((t - COUNT_DELAY) / countSeconds, 0, 1)
				setValue(math.floor(final * (1 - (1 - a) ^ 3) + 0.5))
			end
			if t >= COUNT_DELAY + countSeconds and t >= LAP_SECONDS then
				finishReveal()
			end
		end)
	end

	trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced and revealing then
			finishReveal()
		end
	end))

	local function applyData()
		local name = stateName()
		local ready = name == "Ready"
		local waiting = not ready
		suppressed = name == "Suppressed"
		buildSprites()
		placeCars(0)
		setValue(earnedFinal())
		earnLabel.Visible = ready
		amount.Visible = ready
		addedChip.Visible = ready
		local line = if ready then WelcomeFixtures.timeLine(data) else nil
		timeLabel.Visible = line ~= nil
		timeIcon.Visible = line ~= nil
		timeLabel.Text = line or ""
		local note = if ready then WelcomeFixtures.capNote(data) else nil
		noteLabel.Visible = note ~= nil
		noteLabel.Text = note or ""
		statusLabel.Visible = waiting
		statusLabel.Text = if data.status == "Checking"
			then "Checking your earnings..."
			elseif data.status == "Error" or name == "Error" then "Could not load this right now."
			else ""
		collectButton.root.Visible = ready
		closeButton.root.Visible = waiting
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		geo = WelcomeBackMock.geometry(ds)
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		local left = header.title.Position.X.Offset
		header.title.AnchorPoint = Vector2.new(0, 0.5)
		header.title.Position = UDim2.new(0, left, 0.5, 0)
		header.title.Size = UDim2.new(1, -left - 70, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		-- the miniature track
		trackW, trackH = geo.track.w, geo.track.h
		trackBox.Position = UDim2.fromOffset(geo.track.x, geo.track.y)
		trackBox.Size = UDim2.fromOffset(trackW, trackH)
		local trackCorner = trackBox:FindFirstChildOfClass("UICorner")
		if trackCorner then
			trackCorner.CornerRadius = UDim.new(0, math.floor(trackH / 2))
		end
		infield.Size = UDim2.fromOffset(trackW - 2 * RING, trackH - 2 * RING)
		local infieldCorner = infield:FindFirstChildOfClass("UICorner")
		if infieldCorner then
			infieldCorner.CornerRadius = UDim.new(0, math.floor((trackH - 2 * RING) / 2))
		end
		startLine.Position = UDim2.new(0, math.floor(trackW * 0.34), 1, -2)
		startLine.Size = UDim2.fromOffset(10, RING + 2)
		lineupLabel.Position = UDim2.fromOffset(geo.lineup.x, geo.lineup.y)
		lineupLabel.Size = UDim2.fromOffset(geo.lineup.w, geo.lineup.h)
		-- the figures, top to bottom in the right column; COLLECT! pinned to its foot
		local r = geo.right
		local y = r.y
		local compact = geo.fit == "Compact"
		local function place(obj: GuiObject, height: number, gap: number)
			obj.Position = UDim2.fromOffset(r.x, y)
			obj.Size = UDim2.fromOffset(r.w, height)
			y += height + gap
		end
		place(earnLabel, if compact then 22 else 26, 0)
		local amountConstraint = amount:FindFirstChildOfClass("UITextSizeConstraint")
		if amountConstraint then
			amountConstraint.MaxTextSize = geo.amountSize
		end
		place(amount, geo.amountSize + 8, 2)
		local chipW = math.min(r.w, math.ceil(SupportKit.measure("Already added to your Cash", 16).X) + 56)
		addedChip.AnchorPoint = Vector2.new(0.5, 0)
		addedChip.Position = UDim2.fromOffset(r.x + r.w / 2, y)
		addedChip.Size = UDim2.fromOffset(chipW, 32)
		y += 32 + (if compact then 4 else 10)
		timeIcon.Position = UDim2.fromOffset(r.x, y + 1)
		timeLabel.Position = UDim2.fromOffset(r.x + 26, y)
		timeLabel.Size = UDim2.fromOffset(r.w - 26, 26)
		SupportKit.fitLabel(timeLabel, timeLabel.Text, r.w - 26, 26, 18)
		y += 26 + (if compact then 2 else 6)
		noteLabel.Position = UDim2.fromOffset(r.x, y)
		local noteH = if compact then 38 else 46
		noteLabel.Size = UDim2.fromOffset(r.w, noteH)
		SupportKit.fitLabel(noteLabel, noteLabel.Text, r.w, noteH, 16)
		statusLabel.Position = UDim2.fromOffset(r.x, r.y + 30)
		statusLabel.Size = UDim2.fromOffset(r.w, 60)
		SupportKit.fitLabel(statusLabel, statusLabel.Text, r.w, 60, 22)
		for _, b in { collectButton, closeButton } do
			b.root.AnchorPoint = Vector2.new(0.5, 1)
			b.root.Position = UDim2.fromOffset(r.x + r.w / 2, geo.ph - 10)
		end
		buildSprites()
		if not revealing then
			placeCars(0)
		end
	end

	-- the acknowledgement: a few coins fly to the Cash counter; this changes no number anywhere
	local function flyCoins()
		if Motion.reduced() then
			return
		end
		local toLocal = SupportKit.localizer(coinLayer)
		local buttonCentre = collectButton.body.AbsolutePosition + collectButton.body.AbsoluteSize / 2
		local from = toLocal(buttonCentre)
		local target: Vector2? = if opts.cashTarget then opts.cashTarget() else nil
		local to = if target then toLocal(target) else Vector2.new(64, 44)
		for i = 1, COIN_COUNT do
			local coin: Frame = make("Frame", {
				Name = "Coin",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(from.X, from.Y),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = Color3.fromRGB(255, 208, 64),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 81,
				Parent = coinLayer,
			})
			Arcade.corner(coin, 24)
			Arcade.outline(coin, "Minor")
			local shine: Frame = make("Frame", {
				Name = "Shine",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.42, 0.4),
				Size = UDim2.fromScale(0.34, 0.34),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				ZIndex = 82,
				Parent = coin,
			})
			Arcade.corner(shine, 12)
			coin.Visible = false
			coinsLaunched += 1
			flightTrove:Add(task.delay((i - 1) * COIN_STAGGER, function()
				if not coin.Parent then
					return
				end
				coin.Visible = true
				coin.BackgroundTransparency = 0
				-- a little arc: the coin rises before it drops toward the counter
				local mid = from:Lerp(to, 0.5) + Vector2.new(0, -40 - (i % 3) * 14)
				local up = Motion.tween(coin, "up", Motion.info(COIN_FLIGHT * 0.45, Enum.EasingStyle.Quad), {
					Position = UDim2.fromOffset(mid.X, mid.Y),
				})
				up.Completed:Once(function(state)
					if state ~= Enum.PlaybackState.Completed or not coin.Parent then
						return
					end
					local down = Motion.tween(
						coin,
						"down",
						Motion.info(COIN_FLIGHT * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{
							Position = UDim2.fromOffset(to.X, to.Y),
							Size = UDim2.fromOffset(12, 12),
							BackgroundTransparency = 0.4,
						}
					)
					down.Completed:Once(function()
						if i == COIN_COUNT then
							Sounds.play("CashGain")
						end
						if coin.Parent then
							coin:Destroy()
						end
					end)
				end)
			end))
		end
		flightTrove:Add(function()
			for _, coin in coinLayer:GetChildren() do
				if coin.Name == "Coin" then
					Motion.cancelAll(coin)
					coin:Destroy()
				end
			end
		end)
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
		end,
		open = function(_self: Welcome, returnTo: GuiObject?): boolean
			if overlay:isOpen() then
				return false
			end
			if stateName() == "Suppressed" then
				suppressed = true
				return false -- a verified zero is not shown as "$0 earned"
			end
			collected = false
			flightTrove:Clean()
			layoutNow()
			applyData()
			overlay:open(if stateName() == "Ready" then collectButton.body else closeButton.body, returnTo)
			startReveal()
			return true
		end,
		request = function(self: Welcome): boolean
			local gate = opts.gate
			if gate then
				local ok, reason = gate:check()
				lastGate = reason
				if not ok then
					return false
				end
			end
			local shown = self:open(nil)
			if shown and gate then
				gate:recordShown()
			end
			return shown
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
		setData = function(_self: Welcome, incoming: WelcomeFixtures.Data)
			data = incoming
			if overlay:isOpen() then
				finishReveal()
			end
			applyData()
			layoutNow()
		end,
		setPreset = function(self: Welcome, name: string): boolean
			local incoming = WelcomeFixtures.preset(name)
			if not incoming then
				return false
			end
			self:setData(incoming)
			return true
		end,
		setEarnings = function(self: Welcome, value: number)
			local d = table.clone(data)
			d.status = "Ready"
			d.earned = math.max(0, math.floor(value))
			self:setData(d)
		end,
		skip = function(_self: Welcome)
			if revealing then
				finishReveal()
			end
		end,
		pressCollect = function(_self: Welcome)
			if not overlay:isOpen() or collected or stateName() ~= "Ready" then
				return
			end
			-- one action: finish the reveal if it is still running, acknowledge, close
			collected = true
			collectCalls += 1
			finishReveal()
			flyCoins()
			if opts.onCollect then
				opts.onCollect()
			end
			overlay:close()
		end,
		destroy = function(_self: Welcome)
			overlay:destroy()
		end,
		getDebugState = function(_self: Welcome): DebugState
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				state = stateName(),
				suppressed = suppressed,
				revealing = revealing,
				shownEarnings = shownEarnings,
				earnings = earnedFinal(),
				cars = #sprites,
				collectCalls = collectCalls,
				coinsLaunched = coinsLaunched,
				balanceTouched = false,
				timeLine = timeLabel.Text,
				note = noteLabel.Text,
				amountText = amount.Text,
				reduced = Motion.reduced(),
				gate = lastGate,
			}
		end,
		touchReport = function(_self: Welcome): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	applyData()
	layoutNow()
	return welcome
end

return WelcomeBackMock
