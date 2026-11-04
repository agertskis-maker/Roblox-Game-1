--!strict
-- StuntPreRace: the card shown before a Stunt Circuit lap (Lane 3, big round M17-04; PREVIEW). Choose your car, see its three
-- stats (Speed, Jump and Grip, 1 to 5 pips) and the three medal targets, then START. CUSTOMIZE and TOP TIMES open the other
-- two Stunt screens through callbacks the lead wires.
--
--   local pre = StuntPreRace.new(ctx, { course = string?, state = CourseState?, cars = { PreRaceCar }?, targets = Targets?, ghost = string?, onStart = fn?,
--                                       onCustomize = fn?, onTopTimes = fn?, onClose = fn? })
--   pre:open(returnTo?)  pre:close()  pre:isOpen()
--   pre:setCars(list)  pre:selectCar(index)  pre:getSelected() -> PreRaceCar?  pre:setGhost(text?)  pre:setTargets(t)
--   pre:setState("Loading" | "Ready" | "Unavailable")   -- Loading and Unavailable switch START off and say why (N12-04a)
--   pre:pressStart() -> boolean  pre:pressCustomize()  pre:pressTopTimes()  pre:pressPrev()  pre:pressNext()   -- test hooks
--   pre:layout()  pre:setVisible(on)  pre:destroy()  pre:getDebugState()  pre:touchReport()
--   StuntPreRace.geometry(designSize) -> Geo
--
-- HONEST NUMBERS. The stats are PREVIEW fixtures (StuntFixtures.cars), never invented real values: a car with no stats shows
-- five empty pips and "--" and a note, not a guess. The medal targets are named PREVIEW values and say so. A PREVIEW chip
-- stays in the header at all times. START only calls options.onStart(car) once per activation; it starts no race, grants
-- nothing and opens no remote. Nothing here saves anything.
--
-- States: no cars (START off, a message), one car (no arrows), many cars (a "3 / 12" counter and wrapping arrows), a car with no art (the
-- plain Car glyph in a flat shape and "No art yet"), a car with no stats, and a long name (fitted, never clipped).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CardKit = require(script.Parent.CardKit)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)
local StuntKit = require(script.Parent.StuntKit)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local A = PreviewTokens.Arcade
local make = Arcade.make

local StuntPreRace = {}

export type CourseState = "Loading" | "Ready" | "Unavailable"

export type Options = {
	course: string?, -- the selected course's name (default "Stunt Circuit"); the course itself is Brian R's
	state: CourseState?, -- Loading and Unavailable switch START off with a message (default Ready)
	cars: { StuntFixtures.PreRaceCar }?,
	targets: StuntFixtures.Targets?,
	ghost: string?, -- e.g. "Your best 1:15.04"; nil = "No ghost yet"
	onStart: ((car: StuntFixtures.PreRaceCar) -> ())?,
	onCustomize: ((car: StuntFixtures.PreRaceCar?) -> ())?,
	onTopTimes: (() -> ())?,
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
	startSize: Vector2,
	sideSize: Vector2,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	cars: number,
	selected: number,
	carName: string,
	counter: string,
	stats: { string },
	statsKnown: boolean,
	targets: string,
	ghost: string,
	message: string,
	startEnabled: boolean,
	state: string,
	course: string,
	startPresses: number,
	startCalls: number,
	caption: string,
	instances: number,
}

export type PreRace = {
	root: Frame,
	layout: (self: PreRace) -> (),
	setVisible: (self: PreRace, on: boolean) -> (),
	open: (self: PreRace, returnTo: GuiObject?) -> (),
	close: (self: PreRace) -> (),
	isOpen: (self: PreRace) -> boolean,
	setCars: (self: PreRace, cars: { StuntFixtures.PreRaceCar }) -> (),
	selectCar: (self: PreRace, index: number) -> (),
	getSelected: (self: PreRace) -> StuntFixtures.PreRaceCar?,
	setGhost: (self: PreRace, text: string?) -> (),
	setTargets: (self: PreRace, targets: StuntFixtures.Targets) -> (),
	setState: (self: PreRace, state: CourseState) -> (),
	pressStart: (self: PreRace) -> boolean,
	pressCustomize: (self: PreRace) -> (),
	pressTopTimes: (self: PreRace) -> (),
	pressPrev: (self: PreRace) -> (),
	pressNext: (self: PreRace) -> (),
	destroy: (self: PreRace) -> (),
	getDebugState: (self: PreRace) -> DebugState,
	touchReport: (self: PreRace) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY ---------------------------------------------------------------------------------------------------------------

function StuntPreRace.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH, leftW, footH, start, side
	if fit == "Compact" then
		pw, ph, headH, leftW, footH = math.min(ds.X - 12, 600), ds.Y - 8, 46, 200, 58
		start, side = Vector2.new(170, 54), Vector2.new(140, 48)
	elseif fit == "Regular" then
		pw, ph, headH, leftW, footH = math.min(ds.X - 24, 660), math.min(ds.Y - 16, 440), 54, 240, 72
		start, side = Vector2.new(200, 58), Vector2.new(160, 52)
	else
		pw, ph, headH, leftW, footH = math.min(ds.X - 32, 780), math.min(ds.Y - 24, 520), 60, 280, 80
		start, side = Vector2.new(220, 62), Vector2.new(172, 54)
	end
	local pad = 14
	local top = headH + 8
	local bodyH = ph - top - footH - 4
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		left = { x = pad, y = top, w = leftW, h = bodyH },
		right = { x = pad * 2 + leftW, y = top, w = pw - pad * 3 - leftW, h = bodyH },
		foot = { x = pad, y = ph - footH - 2, w = pw - pad * 2, h = footH },
		startSize = start,
		sideSize = side,
	}
end

-- BUILD ------------------------------------------------------------------------------------------------------------------

function StuntPreRace.new(ctx: Overlay.Ctx, options: Options?): PreRace
	local opts: Options = options or {}
	local cars: { StuntFixtures.PreRaceCar } = opts.cars or StuntFixtures.cars()
	local targets: StuntFixtures.Targets = opts.targets or table.clone(StuntFixtures.MedalTargets)
	local ghostText: string? = opts.ghost
	local courseState: CourseState = opts.state or "Ready"
	local selected = 1
	local geo = StuntPreRace.geometry(Vector2.new(750, 325))
	local startPresses, startCalls = 0, 0
	local guard = SupportKit.guard()
	local builtDims = ""
	local statFit = ""
	local pre: PreRace

	local overlay = Overlay.new(ctx, {
		name = "StuntPreRace",
		onDim = function()
			pre:close()
		end,
	})
	local trove = overlay.trove
	local buttonsTrove = trove:Extend()
	local content = overlay.content
	-- the Round 2 garage-night family shared with Customize and the leaderboard
	local shell = Style.panel(content, {
		name = "Panel",
		z = 3,
		top = Color3.fromRGB(58, 52, 140),
		bottom = Color3.fromRGB(26, 24, 78),
	})
	local panel = shell.body
	local header = Style.header(panel, {
		fill = "Gold",
		title = string.upper(opts.course or "Stunt Circuit"),
		icon = "StuntCircuit",
	})
	local closeX = SupportKit.closeX(panel, function()
		pre:close()
	end)
	trove:Add(closeX.trove)
	local preview = StuntKit.previewChip(header.band, nil, 12)
	preview.frame.AnchorPoint = Vector2.new(1, 0.5)

	-- the car carousel (left)
	local carBox = Style.well(panel, "CarBox", 5)
	StuntKit.garageBackdrop(carBox)
	local carArt: Frame = make("Frame", {
		Name = "CarArt",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = carBox,
	})
	local carName = SupportKit.label(carBox, "CarName", 22, 7)
	carName.TextXAlignment = Enum.TextXAlignment.Center
	local carCounter = SupportKit.label(carBox, "Counter", 16, 7)
	carCounter.TextXAlignment = Enum.TextXAlignment.Center
	carCounter.TextColor3 = Style.TextSoft
	local artNote = SupportKit.label(carBox, "ArtNote", 16, 8)
	artNote.TextXAlignment = Enum.TextXAlignment.Center
	artNote.TextColor3 = PreviewTokens.Color.KeysLight
	local ghostLabel = SupportKit.label(carBox, "Ghost", 16, 7)
	ghostLabel.TextXAlignment = Enum.TextXAlignment.Center
	ghostLabel.TextColor3 = Style.TextSoft

	local prevButton = Arcade.button(carBox, {
		name = "Prev",
		label = "<",
		fill = "Garage",
		size = "Custom",
		width = 48,
		height = 48,
		cooldown = 0.15,
		onActivate = function()
			pre:pressPrev()
		end,
	})
	trove:Add(prevButton.trove)
	prevButton.root.ZIndex = 12
	local nextButton = Arcade.button(carBox, {
		name = "Next",
		label = ">",
		fill = "Garage",
		size = "Custom",
		width = 48,
		height = 48,
		cooldown = 0.15,
		onActivate = function()
			pre:pressNext()
		end,
	})
	trove:Add(nextButton.trove)
	nextButton.root.ZIndex = 12

	-- stats and targets (right)
	local statsBox = Style.well(panel, "StatsBox", 5)
	local statsHolder: Frame = make("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = statsBox,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = statsHolder,
	})
	local statsNote = SupportKit.label(statsBox, "StatsNote", 16, 7)
	statsNote.TextColor3 = PreviewTokens.Color.KeysLight

	local targetsBox = Style.well(panel, "TargetsBox", 5)
	local targetRow: Frame =
		make("Frame", { Name = "Row", BackgroundTransparency = 1, ZIndex = 6, Parent = targetsBox })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = targetRow,
	})
	local targetTimes: { [string]: TextLabel } = {}
	-- Each target is built in BOTH forms and the screen shows one: a small chip (disc + time) on a cramped phone, a medal CARD
	-- (the real medal badge, its word, the time) when there is room, so the lower half of a roomy card is filled with the three
	-- targets and not left as empty navy.
	type TargetChip = {
		key: string,
		chip: Frame,
		bg: Frame,
		disc: Frame,
		badge: Frame?,
		badgeSize: number,
		word: TextLabel,
		time: TextLabel,
	}
	local targetChips: { TargetChip } = {}
	for i, key in StuntFixtures.MedalOrder do
		local info = StuntFixtures.Medals[key]
		local chip: Frame = make("Frame", {
			Name = "Target_" .. info.word,
			LayoutOrder = i,
			Size = UDim2.fromOffset(100, 34),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = targetRow,
		})
		local bg: Frame = make("Frame", {
			Name = "CardBg",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 6,
			Parent = chip,
		})
		Arcade.corner(bg, 10)
		local disc: Frame = make("Frame", {
			Name = "Disc",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = info.colour,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = chip,
		})
		Arcade.corner(disc, 13)
		Arcade.outline(disc, 2.5)
		local letter = Overlay.text(disc, info.letter, 16, A.Ink, Enum.TextXAlignment.Center, 8)
		letter.Size = UDim2.fromScale(1, 1)
		local stroke = letter:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = false
		end
		local word = Style.text(chip, info.word, "Small", {
			name = "Word",
			colour = Style.TextSoft,
			xAlign = Enum.TextXAlignment.Center,
			z = 7,
		})
		word.Visible = false
		local time = Style.text(chip, "", "Small", { name = "Time", italic = true, z = 7 })
		time.AnchorPoint = Vector2.new(0, 0.5)
		time.Position = UDim2.new(0, 30, 0.5, 0)
		time.Size = UDim2.new(1, -30, 0, 24)
		targetTimes[key] = time
		table.insert(targetChips, {
			key = key,
			chip = chip,
			bg = bg,
			disc = disc,
			badge = nil,
			badgeSize = 0,
			word = word,
			time = time,
		})
	end
	local targetsCaption = SupportKit.label(targetsBox, "Caption", 16, 7)
	targetsCaption.TextColor3 = Style.TextSoft
	targetsCaption.Text = "PREVIEW targets, not measured"
	targetsCaption:SetAttribute("PersistentPreview", true)

	local message = SupportKit.label(panel, "Message", 22, 9)
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.Visible = false

	-- the car shown ----------------------------------------------------------------------------------------------------

	local function currentCar(): StuntFixtures.PreRaceCar?
		return cars[selected]
	end

	local sideCar: Frame? = nil -- the side-on car drawn for the selected car (nil: none, or a flat no-art glyph)

	-- the stat rows are 26 tall on a cramped phone (pips 20), 38 on a tablet and 46 on a desktop (plate, pips 26): a roomy card
	-- fills its right column with the table instead of leaving it empty
	local function statRowHeight(): number
		return if geo.fit == "Compact" then 26 elseif geo.fit == "Regular" then 38 else 46
	end

	local function renderCar()
		for _, child in carArt:GetChildren() do
			child:Destroy()
		end
		sideCar = nil
		statsHolder:ClearAllChildren()
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = statsHolder,
		})
		local car = currentCar()
		local many = #cars > 1
		prevButton.root.Visible = many
		nextButton.root.Visible = many
		if not car then
			carName.Text = "No cars yet"
			carCounter.Text = ""
			artNote.Text = ""
			message.Visible = true
			message.Text = "Get a car in the Garage first."
			statsNote.Text = ""
			for _, label in { "Speed", "Jump", "Grip" } do
				local row = StuntKit.statRow(statsHolder, label, nil, 7, statRowHeight(), geo.fit ~= "Compact")
				row.LayoutOrder = #statsHolder:GetChildren()
			end
			return
		end
		message.Visible = false
		carName.Text = car.name
		carCounter.Text = if many then string.format("%d / %d", selected, #cars) else ""
		-- the car's art: the family icon tinted with its paint; with no art, a flat silhouette and a note
		local holder: Frame = make("Frame", {
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 7,
			Parent = carArt,
		})
		if car.missingArt then
			-- no art: the plain Car glyph as one flat shape, and a note
			SupportKit.carIcon(holder, { family = car.family, paint = car.paint })
			SupportKit.silhouette(holder)
			sideCar = nil
		else
			-- a SIDE-ON car (wheels, cabin, window, lamps, a ground shadow), tinted with the paint: the family icon is a front
			-- view that read as a blue blob, not a car. layoutNow sizes it to the art box.
			local art = CardKit.uiCar(holder, {
				colour = car.paint or Color3.fromRGB(40, 120, 232),
				family = car.family,
				name = car.id,
			}, 8)
			art.root.AnchorPoint = Vector2.new(0.5, 0.5)
			art.root.Position = UDim2.fromScale(0.5, 0.5)
			sideCar = art.root
		end
		artNote.Text = if car.missingArt then "No art yet" else ""
		local stats = car.stats
		local order = 0
		for _, spec in { { "Speed", "speed" }, { "Jump", "jump" }, { "Grip", "grip" } } do
			local value: number? = if stats then (stats :: any)[spec[2]] else nil
			local row = StuntKit.statRow(statsHolder, spec[1], value, 7, statRowHeight(), geo.fit ~= "Compact")
			order += 1
			row.LayoutOrder = order
		end
		statsNote.Text = if stats then "PREVIEW stats" else "Stats not set yet"
	end

	local function renderTargets()
		for _, key in StuntFixtures.MedalOrder do
			targetTimes[key].Text = StuntFixtures.formatTime((targets :: any)[key])
		end
	end

	local function renderGhost()
		ghostLabel.Text = if ghostText then "Ghost: " .. ghostText else "No ghost yet"
	end

	-- the buttons: rebuilt only when their size changes (Arcade buttons are fixed size) --------------------------------

	local startButton: Arcade.Button? = nil
	local function buildButtons()
		local key = string.format("%dx%d/%dx%d", geo.startSize.X, geo.startSize.Y, geo.sideSize.X, geo.sideSize.Y)
		if key == builtDims and startButton then
			return
		end
		builtDims = key
		buttonsTrove:Clean()
		local start = Arcade.button(panel, {
			name = "Start",
			label = "START",
			fill = "Green",
			size = "Custom",
			width = geo.startSize.X,
			height = geo.startSize.Y,
			icon = "StuntCircuit",
			pattern = true,
			cooldown = 0.6,
			onActivate = function()
				pre:pressStart()
			end,
		})
		buttonsTrove:Add(start.trove)
		start.root.ZIndex = 12
		local customize = Arcade.button(panel, {
			name = "Customize",
			label = "CUSTOMIZE",
			fill = "Missions",
			size = "Custom",
			width = geo.sideSize.X,
			height = geo.sideSize.Y,
			icon = "PaintBucket",
			cooldown = 0.4,
			onActivate = function()
				pre:pressCustomize()
			end,
		})
		buttonsTrove:Add(customize.trove)
		customize.root.ZIndex = 12
		local top = Arcade.button(panel, {
			name = "TopTimes",
			label = "TOP TIMES",
			fill = "Garage",
			size = "Custom",
			width = geo.sideSize.X,
			height = geo.sideSize.Y,
			icon = "Leaderboard",
			cooldown = 0.4,
			onActivate = function()
				pre:pressTopTimes()
			end,
		})
		buttonsTrove:Add(top.trove)
		top.root.ZIndex = 12
		startButton = start
		-- the three sit in one row on the foot: TOP TIMES, PAINT, START
		local f = geo.foot
		local gap = 12
		local y = f.y + f.h / 2
		local totalW = geo.sideSize.X * 2 + geo.startSize.X + gap * 2
		local x0 = f.x + (f.w - totalW) / 2
		for _, b in { top, customize, start } do
			b.root.AnchorPoint = Vector2.new(0, 0.5)
		end
		top.root.Position = UDim2.fromOffset(x0, y)
		customize.root.Position = UDim2.fromOffset(x0 + geo.sideSize.X + gap, y)
		start.root.Position = UDim2.fromOffset(x0 + geo.sideSize.X * 2 + gap * 2, y)
	end

	local function applyStartEnabled()
		local b = startButton
		if b then
			b.setEnabled(currentCar() ~= nil and courseState == "Ready")
		end
		-- loading and unavailable say so in words, and START stays off (a ready course keeps the car messages)
		if courseState == "Loading" then
			message.Visible = true
			message.Text = "Getting the course ready..."
		elseif courseState == "Unavailable" then
			message.Visible = true
			message.Text = "This course isn't available right now."
		end
	end

	-- the three medal targets in the targets box (`box` = its size): medal CARDS (badge, word, time, the caption under them) when
	-- there is room, small chips (disc and time on one line) on a cramped phone
	local function layoutTargets(box: Vector2, cards: boolean, badgeSize: number)
		if cards then
			local gap = 8
			local cardH = box.Y - 8 - 30
			local cardW = math.floor((box.X - 20 - 2 * gap) / 3)
			targetRow.Position = UDim2.fromOffset(0, 8)
			targetRow.Size = UDim2.new(1, 0, 0, cardH)
			targetsCaption.Position = UDim2.fromOffset(6, box.Y - 26)
			targetsCaption.Size = UDim2.new(1, -12, 0, 20)
			targetsCaption.TextXAlignment = Enum.TextXAlignment.Center
			for _, t in targetChips do
				t.chip.Size = UDim2.fromOffset(cardW, cardH)
				t.bg.Visible = true
				t.disc.Visible = false
				if t.badgeSize ~= badgeSize then
					local old = t.badge
					if old then
						old:Destroy()
					end
					local badge = StuntKit.medalBadge(t.chip, t.key, badgeSize, 7)
					badge.AnchorPoint = Vector2.new(0.5, 0)
					badge.Position = UDim2.new(0.5, 0, 0, 8)
					t.badge = badge
					t.badgeSize = badgeSize
				end
				local badge = t.badge
				if badge then
					badge.Visible = true
				end
				t.word.Visible = true
				t.word.AnchorPoint = Vector2.new(0.5, 0)
				t.word.Position = UDim2.new(0.5, 0, 0, 8 + badgeSize + 2)
				t.word.Size = UDim2.new(1, -8, 0, 20)
				t.time.AnchorPoint = Vector2.new(0.5, 0)
				t.time.Position = UDim2.new(0.5, 0, 0, 8 + badgeSize + 24)
				t.time.Size = UDim2.new(1, -8, 0, 26)
				t.time.TextXAlignment = Enum.TextXAlignment.Center
				local limit = t.time:FindFirstChildOfClass("UITextSizeConstraint")
				if limit then
					limit.MaxTextSize = 24
				end
			end
		else
			targetRow.Position = UDim2.fromOffset(0, 4)
			targetRow.Size = UDim2.new(1, 0, 0, 34)
			targetsCaption.Position = UDim2.fromOffset(6, 40)
			targetsCaption.Size = UDim2.new(1, -12, 0, 20)
			targetsCaption.TextXAlignment = Enum.TextXAlignment.Left
			for _, t in targetChips do
				t.chip.Size = UDim2.fromOffset(100, 34)
				t.bg.Visible = false
				t.disc.Visible = true
				local badge = t.badge
				if badge then
					badge.Visible = false
				end
				t.word.Visible = false
				t.time.AnchorPoint = Vector2.new(0, 0.5)
				t.time.Position = UDim2.new(0, 30, 0.5, 0)
				t.time.Size = UDim2.new(1, -30, 0, 24)
				t.time.TextXAlignment = Enum.TextXAlignment.Left
				local limit = t.time:FindFirstChildOfClass("UITextSizeConstraint")
				if limit then
					limit.MaxTextSize = 16
				end
			end
		end
	end

	local function layoutNow()
		overlay:applyScale()
		geo = StuntPreRace.geometry(overlay:designSize())
		if geo.fit ~= statFit then
			statFit = geo.fit
			renderCar() -- the stat rows are a different height at a different size
		end
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		preview.frame.Position = UDim2.new(1, -8 - Tokens.Touch.Minimum - 8, 0.5, 0)
		header.title.Size =
			UDim2.new(1, -header.title.Position.X.Offset - 190, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		-- the carousel box: art, name, counter, and the ghost line at the foot
		local l = geo.left
		carBox.Position = UDim2.fromOffset(l.x, l.y)
		carBox.Size = UDim2.fromOffset(l.w, l.h)
		local roomy = geo.fit ~= "Compact"
		local artH = math.max(l.h - 92, 60)
		-- roomy: the car takes the whole width of the box (the arrows stand beside its name below it); a cramped phone keeps the
		-- arrows at the car's sides
		local artW = if roomy then l.w - 16 else math.min(l.w - 112, artH * 1.7)
		carArt.Position = UDim2.new(0.5, 0, 0, 6)
		carArt.Size = UDim2.fromOffset(artW, artH)
		local sc = sideCar
		if sc then
			local cw = math.floor(math.min(artW, artH / 0.56 * 0.9)) -- the side car is a 100 : 56 box
			sc.Size = UDim2.fromOffset(cw, math.floor(cw * 0.56))
		end
		local nameX = if roomy then 56 else 4
		carName.Position = UDim2.fromOffset(nameX, 6 + artH + 2)
		carName.Size = UDim2.new(1, -2 * nameX, 0, 28)
		carCounter.Position = UDim2.fromOffset(nameX, 6 + artH + 30)
		carCounter.Size = UDim2.new(1, -2 * nameX, 0, 22)
		artNote.AnchorPoint = Vector2.new(0.5, 0)
		artNote.Position = UDim2.new(0.5, 0, 0, 6 + artH - 22)
		artNote.Size = UDim2.fromOffset(140, 22)
		ghostLabel.AnchorPoint = Vector2.new(0, 1)
		ghostLabel.Position = UDim2.new(0, 4, 1, -3)
		ghostLabel.Size = UDim2.new(1, -8, 0, 24)
		if roomy then
			prevButton.root.Position = UDim2.fromOffset(6, 6 + artH + 4)
			nextButton.root.Position = UDim2.new(1, -54, 0, 6 + artH + 4)
		else
			prevButton.root.Position = UDim2.fromOffset(6, 6 + artH / 2 - 24)
			nextButton.root.Position = UDim2.new(1, -54, 0, 6 + artH / 2 - 24)
		end
		SupportKit.fitLabel(carName, carName.Text, l.w - 2 * nameX, 28, 22)
		-- stats (three rows and a one-line note) over the medal targets (three medal cards, or chips, and a one-line caption)
		local r = geo.right
		local rowH = statRowHeight()
		local listPad = if roomy then 4 else 0 -- the rows' own 2 px gaps
		local statsH = 4 + rowH * 3 + listPad + 4 + 20 + 4
		statsBox.Position = UDim2.fromOffset(r.x, r.y)
		statsBox.Size = UDim2.fromOffset(r.w, statsH)
		statsHolder.Position = UDim2.fromOffset(10, 4)
		statsHolder.Size = UDim2.new(1, -20, 0, rowH * 3 + listPad)
		statsNote.Position = UDim2.fromOffset(10, 4 + rowH * 3 + listPad + 4)
		statsNote.Size = UDim2.new(1, -20, 0, 20)
		local targetsH = math.max(r.h - statsH - 6, 62)
		targetsBox.Position = UDim2.fromOffset(r.x, r.y + statsH + 6)
		targetsBox.Size = UDim2.fromOffset(r.w, targetsH)
		layoutTargets(Vector2.new(r.w, targetsH), roomy, if geo.fit == "Roomy" then 72 else 46)
		message.AnchorPoint = Vector2.new(0.5, 0.5)
		message.Position = UDim2.fromOffset(l.x + l.w / 2, l.y + l.h - 40)
		message.Size = UDim2.fromOffset(l.w, 30)
		buildButtons()
		applyStartEnabled()
	end

	overlay:setBack(function()
		pre:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	-- PUBLIC -----------------------------------------------------------------------------------------------------------

	pre = {
		root = overlay.root,
		layout = function(_self: PreRace)
			layoutNow()
		end,
		setVisible = function(_self: PreRace, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(_self: PreRace, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			guard:reset()
			layoutNow()
			renderCar()
			layoutNow()
			local b = startButton
			overlay:open(if b and currentCar() then b.body else nil, returnTo)
		end,
		close = function(_self: PreRace)
			if not overlay:isOpen() then
				return
			end
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: PreRace): boolean
			return overlay:isOpen()
		end,
		setCars = function(_self: PreRace, list: { StuntFixtures.PreRaceCar })
			cars = list
			selected = 1
			renderCar()
			applyStartEnabled()
			layoutNow()
		end,
		selectCar = function(_self: PreRace, index: number)
			if #cars == 0 then
				return
			end
			selected = (math.floor(index) - 1) % #cars + 1
			renderCar()
			layoutNow()
		end,
		getSelected = function(_self: PreRace): StuntFixtures.PreRaceCar?
			return currentCar()
		end,
		setGhost = function(_self: PreRace, text: string?)
			ghostText = text
			renderGhost()
		end,
		setTargets = function(_self: PreRace, t: StuntFixtures.Targets)
			targets = table.clone(t)
			renderTargets()
		end,
		setState = function(_self: PreRace, state: CourseState)
			courseState = state
			renderCar() -- put the car's own messages back before the course state is applied over them
			applyStartEnabled()
			layoutNow()
		end,
		pressStart = function(_self: PreRace): boolean
			startPresses += 1
			local car = currentCar()
			if not car or courseState ~= "Ready" or not guard:tryFire() then
				return false -- no car, or a second press for the same activation: nothing happens
			end
			startCalls += 1
			if opts.onStart then
				opts.onStart(car)
			end
			return true
		end,
		pressCustomize = function(_self: PreRace)
			if opts.onCustomize then
				opts.onCustomize(currentCar())
			end
		end,
		pressTopTimes = function(_self: PreRace)
			if opts.onTopTimes then
				opts.onTopTimes()
			end
		end,
		pressPrev = function(self: PreRace)
			self:selectCar(selected - 1)
		end,
		pressNext = function(self: PreRace)
			self:selectCar(selected + 1)
		end,
		destroy = function(_self: PreRace)
			overlay:destroy()
		end,
		getDebugState = function(_self: PreRace): DebugState
			local car = currentCar()
			local stats: { string } = {}
			for _, row in statsHolder:GetChildren() do
				if row:IsA("Frame") then
					local pips = row:FindFirstChild("Pips")
					local filled = if pips then pips:GetAttribute("Filled") else nil
					table.insert(stats, string.format("%s=%s", row.Name:gsub("^Stat_", ""), tostring(filled)))
				end
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				cars = #cars,
				selected = selected,
				carName = carName.Text,
				counter = carCounter.Text,
				stats = stats,
				statsKnown = car ~= nil and car.stats ~= nil,
				targets = string.format(
					"%s / %s / %s",
					StuntFixtures.formatTime(targets.gold),
					StuntFixtures.formatTime(targets.silver),
					StuntFixtures.formatTime(targets.bronze)
				),
				ghost = ghostLabel.Text,
				message = message.Text,
				startEnabled = startButton ~= nil and car ~= nil and courseState == "Ready",
				state = courseState,
				course = header.title.Text,
				startPresses = startPresses,
				startCalls = startCalls,
				caption = preview.label.Text,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: PreRace): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	renderTargets()
	renderGhost()
	layoutNow()
	renderCar()
	layoutNow()
	return pre
end

return StuntPreRace
