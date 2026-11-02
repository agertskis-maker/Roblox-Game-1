--!strict
-- StuntPreRace: the card shown before a Stunt Circuit lap (Lane 3, big round M17-04; PREVIEW). Choose your car, see its three
-- stats (Speed, Jump and Grip, 1 to 5 pips) and the three medal targets, then START. CUSTOMIZE and TOP TIMES open the other
-- two Stunt screens through callbacks the lead wires.
--
--   local pre = StuntPreRace.new(ctx, { cars = { PreRaceCar }?, targets = Targets?, ghost = string?, onStart = fn?,
--                                       onCustomize = fn?, onTopTimes = fn?, onClose = fn? })
--   pre:open(returnTo?)  pre:close()  pre:isOpen()
--   pre:setCars(list)  pre:selectCar(index)  pre:getSelected() -> PreRaceCar?  pre:setGhost(text?)  pre:setTargets(t)
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

export type Options = {
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
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Garage", title = "STUNT CIRCUIT", icon = "Flag" })
	local closeX = SupportKit.closeX(panel, function()
		pre:close()
	end)
	trove:Add(closeX.trove)
	local preview = StuntKit.previewChip(header.band, nil, 12)
	preview.frame.AnchorPoint = Vector2.new(1, 0.5)

	-- the car carousel (left)
	local carBox = Style.well(panel, "CarBox", 5)
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
		local time = Style.text(chip, "", "Small", { name = "Time", italic = true, z = 7 })
		time.AnchorPoint = Vector2.new(0, 0.5)
		time.Position = UDim2.new(0, 30, 0.5, 0)
		time.Size = UDim2.new(1, -30, 0, 24)
		targetTimes[key] = time
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

	-- the stat rows are 26 tall on a cramped phone and 30 elsewhere (the pips stay 20)
	local function statRowHeight(): number
		return if geo.fit == "Compact" then 26 else 30
	end

	local function renderCar()
		for _, child in carArt:GetChildren() do
			child:Destroy()
		end
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
				local row = StuntKit.statRow(statsHolder, label, nil, 7, statRowHeight())
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
		SupportKit.carIcon(holder, { family = car.family, paint = car.paint })
		if car.missingArt then
			SupportKit.silhouette(holder)
		end
		artNote.Text = if car.missingArt then "No art yet" else ""
		local stats = car.stats
		local order = 0
		for _, spec in { { "Speed", "speed" }, { "Jump", "jump" }, { "Grip", "grip" } } do
			local value: number? = if stats then (stats :: any)[spec[2]] else nil
			local row = StuntKit.statRow(statsHolder, spec[1], value, 7, statRowHeight())
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
			label = "PAINT",
			fill = "Missions",
			size = "Custom",
			width = geo.sideSize.X,
			height = geo.sideSize.Y,
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
			b.setEnabled(currentCar() ~= nil)
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
		local artH = math.max(l.h - 92, 60)
		carArt.Position = UDim2.new(0.5, 0, 0, 6)
		carArt.Size = UDim2.fromOffset(math.min(l.w - 112, artH * 1.7), artH)
		carName.Position = UDim2.fromOffset(4, 6 + artH + 2)
		carName.Size = UDim2.new(1, -8, 0, 28)
		carCounter.Position = UDim2.fromOffset(4, 6 + artH + 30)
		carCounter.Size = UDim2.new(1, -8, 0, 22)
		artNote.AnchorPoint = Vector2.new(0.5, 0)
		artNote.Position = UDim2.new(0.5, 0, 0, 6 + artH - 22)
		artNote.Size = UDim2.fromOffset(140, 22)
		ghostLabel.AnchorPoint = Vector2.new(0, 1)
		ghostLabel.Position = UDim2.new(0, 4, 1, -3)
		ghostLabel.Size = UDim2.new(1, -8, 0, 24)
		prevButton.root.Position = UDim2.fromOffset(6, 6 + artH / 2 - 24)
		nextButton.root.Position = UDim2.new(1, -54, 0, 6 + artH / 2 - 24)
		SupportKit.fitLabel(carName, carName.Text, l.w - 8, 28, 22)
		-- stats (three rows and a one-line note) over the medal targets (three chips and a one-line caption)
		local r = geo.right
		local rowH = statRowHeight()
		local statsH = 4 + rowH * 3 + 4 + 20 + 4
		statsBox.Position = UDim2.fromOffset(r.x, r.y)
		statsBox.Size = UDim2.fromOffset(r.w, statsH)
		statsHolder.Position = UDim2.fromOffset(10, 4)
		statsHolder.Size = UDim2.new(1, -20, 0, rowH * 3)
		statsNote.Position = UDim2.fromOffset(10, 4 + rowH * 3 + 4)
		statsNote.Size = UDim2.new(1, -20, 0, 20)
		targetsBox.Position = UDim2.fromOffset(r.x, r.y + statsH + 6)
		targetsBox.Size = UDim2.fromOffset(r.w, math.max(r.h - statsH - 6, 62))
		targetRow.Position = UDim2.fromOffset(0, 4)
		targetRow.Size = UDim2.new(1, 0, 0, 34)
		targetsCaption.Position = UDim2.fromOffset(6, 40)
		targetsCaption.Size = UDim2.new(1, -12, 0, 20)
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
		pressStart = function(_self: PreRace): boolean
			startPresses += 1
			local car = currentCar()
			if not car or not guard:tryFire() then
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
				startEnabled = startButton ~= nil and car ~= nil,
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
