--!strict
-- LoadingScreen: the branded Car Hop loading screen's VIEW (big round M15-01). SELF-CONTAINED: it requires no module of the
-- game, uses no image or asset id and no new font (Fredoka One, the project's font, which ships with Roblox), and builds
-- itself only from local shapes, so it never waits for its own art. Everything it needs it creates here; everything it
-- creates it removes in destroy().
--
--   local view = LoadingScreen.new(playerGui, { reducedMotion = fn? })   -- mounts two ScreenGuis in PlayerGui
--   view.setStage("Loading assets")  view.setCount("2 / 5")  view.setProgress(0.4)   -- nil progress = indeterminate bar
--   view.setNote("1 item couldn't load")  view.setStatus("Still connecting... 14 s")
--   view.setAction("Rejoin", fn)  view.fadeOut(0.4, onGone)  view.destroy()  view.getDebugState()
--
-- LOOK. A warm sky with a sun and drifting clouds, mesas on the horizon, a road with a row of parked cars and three cars
-- hopping across their roofs; the CAR HOP wordmark; a progress track under a numeric status row (stage on the left, the
-- real count on the right); one icon-led tip below it, rotating about every five seconds. Tips live OUTSIDE the numeric row.
-- LAYOUT. It reflows live from the ScreenGui's actual size (and again whenever that changes): the approved short-side
-- scale (short side / 390, kept between 1.0 and 1.5) sizes the content, text is never below 16, buttons are at least 48
-- tall, and the content ScreenGui respects the device safe area (the sky itself is full bleed).
-- MOTION. Reduce Motion (GuiService.ReducedMotionEnabled, or the LocalPlayer attribute Lane3ReducedMotionOverride the HUD
-- uses) freezes the clouds, the hopping cars and the road, and swaps tips without a fade. The bar never fakes progress.
-- CLEANUP. One cleanup list owns every connection, tween delay and instance; destroy() runs it once. Calls after destroy()
-- do nothing (a late callback can never touch a destroyed screen).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LoadingScreen = {}

LoadingScreen.TipSeconds = 5
LoadingScreen.Tips = table.freeze({
	{ glyph = "!", colour = Color3.fromRGB(255, 140, 30), text = "Hop before it gets too hot!" },
	{ glyph = "$", colour = Color3.fromRGB(60, 190, 90), text = "Park cars to earn Lap Pay!" },
	{ glyph = ">", colour = Color3.fromRGB(60, 150, 235), text = "Try a new World!" },
})

export type Options = {
	reducedMotion: (() -> boolean)?,
	tips: { { glyph: string, colour: Color3, text: string } }?,
}

export type View = {
	setStage: (text: string) -> (),
	setCount: (text: string?) -> (),
	setProgress: (fraction: number?) -> (),
	setNote: (text: string?) -> (),
	setStatus: (text: string?) -> (),
	setAction: (label: string?, onPress: (() -> ())?) -> (),
	fadeOut: (seconds: number, onGone: (() -> ())?) -> (),
	destroy: () -> (),
	isAlive: () -> boolean,
	layout: () -> (),
	getDebugState: () -> { [string]: any },
}

local INK = Color3.fromRGB(14, 20, 38)
local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 214, 64)
local FONT = Font.fromName("FredokaOne")
local OVERRIDE = "Lane3ReducedMotionOverride"
local MIN_TEXT = 16
local TOUCH = 48

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function outline(parent: Instance, thickness: number, colour: Color3?)
	local isText = parent:IsA("TextLabel") or parent:IsA("TextButton")
	make("UIStroke", {
		Thickness = thickness,
		Color = colour or INK,
		ApplyStrokeMode = if isText then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

local function label(parent: Instance, name: string, text: string, size: number, align: Enum.TextXAlignment): TextLabel
	local l: TextLabel = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = text,
		TextSize = math.max(size, MIN_TEXT),
		TextColor3 = WHITE,
		TextXAlignment = align,
		TextWrapped = false,
		Parent = parent,
	})
	outline(l, 2)
	return l
end

-- one little car from local shapes; the container is twice as wide as it is tall and anchored bottom centre
local function buildCar(parent: Instance, colour: Color3, z: number): Frame
	local car: Frame = make("Frame", {
		Name = "Car",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local function part(
		name: string,
		x: number,
		y: number,
		w: number,
		h: number,
		c: Color3,
		r: number,
		zi: number
	): Frame
		local f: Frame = make("Frame", {
			Name = name,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			ZIndex = z + zi,
			Parent = car,
		})
		make("UICorner", { CornerRadius = UDim.new(r, 0), Parent = f })
		outline(f, 2)
		return f
	end
	part("Cabin", 0.22, 0.06, 0.5, 0.42, colour, 0.28, 1)
	part("Glass", 0.28, 0.14, 0.38, 0.26, Color3.fromRGB(176, 226, 255), 0.2, 2)
	part("Body", 0, 0.38, 1, 0.34, colour, 0.22, 3)
	part("Lamp", 0.88, 0.46, 0.09, 0.12, Color3.fromRGB(255, 244, 190), 0.3, 4)
	for _, x in { 0.14, 0.7 } do
		part("Wheel", x, 0.58, 0.17, 0.34, Color3.fromRGB(40, 44, 58), 0.5, 5)
	end
	return car
end

function LoadingScreen.new(playerGui: Instance, options: Options?): View
	local opts: Options = options or {}
	local tips = opts.tips or LoadingScreen.Tips
	local cleanups: { () -> () } = {}
	local alive = true
	local function onClean(fn: () -> ())
		table.insert(cleanups, fn)
	end
	local function reduced(): boolean
		if opts.reducedMotion then
			return opts.reducedMotion()
		end
		local player = Players.LocalPlayer
		local override = player and player:GetAttribute(OVERRIDE)
		if type(override) == "boolean" then
			return override
		end
		return GuiService.ReducedMotionEnabled
	end

	-- two ScreenGuis: the full-bleed sky behind, the safe-area content in front. ResetOnSpawn is OFF so the character
	-- spawning does not delete the screen before the controller dismisses it.
	local backdropGui: ScreenGui = make("ScreenGui", {
		Name = "CarHopLoadingBackdrop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.None,
		Parent = playerGui,
	})
	local gui: ScreenGui = make("ScreenGui", {
		Name = "CarHopLoading",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1001,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		Parent = playerGui,
	})
	onClean(function()
		backdropGui:Destroy()
		gui:Destroy()
	end)

	-- BACKDROP -------------------------------------------------------------------------------

	local sky: Frame = make("Frame", {
		Name = "Sky",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = backdropGui,
	})
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(104, 190, 255)),
			ColorSequenceKeypoint.new(0.62, Color3.fromRGB(190, 228, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 226, 168)),
		}),
		Rotation = 90,
		Parent = sky,
	})
	local sun: Frame = make("Frame", {
		Name = "Sun",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 244, 196),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = backdropGui,
	})
	corner(sun, 999)
	local clouds: { Frame } = {}
	for i = 1, 3 do
		local cloud: Frame = make("Frame", {
			Name = "Cloud" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = backdropGui,
		})
		corner(cloud, 999)
		table.insert(clouds, cloud)
	end
	local mesas: { Frame } = {}
	for i = 1, 4 do
		local mesa: Frame = make("Frame", {
			Name = "Mesa" .. i,
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(214, 112, 66) else Color3.fromRGB(190, 92, 56),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = backdropGui,
		})
		corner(mesa, 10)
		table.insert(mesas, mesa)
	end
	local ground: Frame = make("Frame", {
		Name = "Ground",
		BackgroundColor3 = Color3.fromRGB(240, 196, 128),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = backdropGui,
	})
	local road: Frame = make("Frame", {
		Name = "Road",
		BackgroundColor3 = Color3.fromRGB(70, 74, 92),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = backdropGui,
	})
	outline(road, 3)
	local dashes: { Frame } = {}
	for i = 1, 9 do
		local dash: Frame = make("Frame", {
			Name = "Dash" .. i,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 246, 214),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = backdropGui,
		})
		table.insert(dashes, dash)
	end
	local parked: { Frame } = {}
	local parkedColours = {
		Color3.fromRGB(120, 140, 190),
		Color3.fromRGB(200, 120, 110),
		Color3.fromRGB(110, 170, 150),
		Color3.fromRGB(190, 170, 110),
		Color3.fromRGB(150, 120, 180),
	}
	for i, c in parkedColours do
		local car = buildCar(backdropGui, c, 8)
		car.Name = "Parked" .. i
		table.insert(parked, car)
	end
	local hoppers: { Frame } = {}
	for _, c in { Color3.fromRGB(46, 120, 235), Color3.fromRGB(232, 64, 60), Color3.fromRGB(250, 200, 40) } do
		table.insert(hoppers, buildCar(backdropGui, c, 20))
	end

	-- CONTENT --------------------------------------------------------------------------------

	local stage: Frame = make("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale: UIScale = make("UIScale", { Parent = stage })
	local wordmark: Frame = make("Frame", {
		Name = "Wordmark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = -3,
		ZIndex = 10,
		Parent = stage,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		Parent = wordmark,
	})
	local words: { TextLabel } = {}
	for i, spec in { { "CAR", WHITE }, { "HOP", YELLOW } } :: { { any } } do
		local w: TextLabel = make("TextLabel", {
			Name = spec[1],
			LayoutOrder = i,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			FontFace = FONT,
			Text = spec[1],
			TextSize = 90,
			TextColor3 = spec[2],
			ZIndex = 11,
			Parent = wordmark,
		})
		outline(w, 7)
		table.insert(words, w)
	end

	local block: Frame = make("Frame", {
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = stage,
	})
	local stageLabel = label(block, "Stage", "Starting up...", 20, Enum.TextXAlignment.Left)
	stageLabel.ZIndex = 11
	local countLabel = label(block, "Count", "", 20, Enum.TextXAlignment.Right)
	countLabel.ZIndex = 11
	local track: Frame = make("Frame", {
		Name = "Track",
		BackgroundColor3 = Color3.fromRGB(20, 38, 96),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 11,
		Parent = block,
	})
	corner(track, 12)
	outline(track, 3)
	local fill: Frame = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = track,
	})
	corner(fill, 12)
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 210, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 160, 58)),
		}),
		Rotation = 90,
		Parent = fill,
	})
	local shimmer: Frame = make("Frame", {
		Name = "Shimmer",
		Size = UDim2.fromScale(0.28, 1),
		BackgroundColor3 = Color3.fromRGB(140, 220, 255),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
		Parent = track,
	})
	corner(shimmer, 12)
	local noteLabel = label(block, "Note", "", 16, Enum.TextXAlignment.Center)
	noteLabel.ZIndex = 11
	local statusLabel = label(block, "Status", "", 20, Enum.TextXAlignment.Center)
	statusLabel.ZIndex = 11
	statusLabel.TextColor3 = YELLOW
	local actionButton: TextButton = make("TextButton", {
		Name = "Action",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		FontFace = FONT,
		Text = "",
		TextSize = 22,
		TextColor3 = WHITE,
		Visible = false,
		ZIndex = 13,
		Parent = block,
	})
	corner(actionButton, 8)
	outline(actionButton, 3)
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 70)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 96, 16)),
		}),
		Rotation = 90,
		Parent = actionButton,
	})
	local actionText = label(actionButton, "Text", "", 22, Enum.TextXAlignment.Center)
	actionText.Size = UDim2.fromScale(1, 1)
	actionText.ZIndex = 14
	local actionLabel = ""
	local onAction: (() -> ())? = nil
	local spent: { [string]: boolean } = {} -- an action already pressed does not come back
	local actionConn = actionButton.Activated:Connect(function()
		local fn = onAction
		if fn then
			onAction = nil -- one press: a second tap while it works does nothing
			spent[actionLabel] = true
			actionButton.Visible = false
			fn()
		end
	end)
	onClean(function()
		actionConn:Disconnect()
	end)

	-- the tip: an icon disc and one line, in its own pill
	local tipPill: Frame = make("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = stage,
	})
	corner(tipPill, 14)
	outline(tipPill, 2.5, WHITE)
	local tipDisc: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = YELLOW,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = tipPill,
	})
	corner(tipDisc, 32)
	outline(tipDisc, 2)
	local tipGlyph = label(tipDisc, "Glyph", "!", 22, Enum.TextXAlignment.Center)
	tipGlyph.Size = UDim2.fromScale(1, 1)
	tipGlyph.ZIndex = 12
	local tipText = label(tipPill, "Text", "", 20, Enum.TextXAlignment.Left)
	tipText.ZIndex = 11
	tipText.Position = UDim2.fromOffset(50, 0)

	-- STATE ----------------------------------------------------------------------------------

	local vp = Vector2.new(844, 390)
	local uiScale = 1
	local design = Vector2.new(844, 390)
	local tipIndex = 1
	local tipClock = 0
	local progress: number? = nil
	local stageText = "Starting up..."
	local countText = ""
	local noteText = ""
	local statusText = ""
	local time = 0
	local fading = false
	local geometry = { horizon = 0, roadTop = 0, roadBottom = 0, baseline = 0, carW = 80, slots = {} :: { number } }

	local function applyTip(index: number)
		local tip = tips[((index - 1) % #tips) + 1]
		tipText.Text = tip.text
		tipGlyph.Text = tip.glyph
		tipDisc.BackgroundColor3 = tip.colour
	end
	applyTip(1)

	local function layoutNow()
		if not alive then
			return
		end
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			local camera = workspace.CurrentCamera
			size = if camera then camera.ViewportSize else Vector2.new(844, 390)
		end
		vp = size
		local bsize = backdropGui.AbsoluteSize
		local full = if bsize.X > 0 and bsize.Y > 0 then bsize else size
		-- the approved short-side rule: short side / 390, between 1.0 and 1.5
		uiScale = math.clamp(math.min(size.X, size.Y) / 390, 1, 1.5)
		scale.Scale = uiScale
		design = size / uiScale
		stage.Size = UDim2.fromOffset(design.X, design.Y)
		local W, H = design.X, design.Y
		-- wordmark
		local wordSize = math.clamp(math.floor(H * 0.2), 56, 110)
		for _, w in words do
			w.TextSize = wordSize
		end
		wordmark.Size = UDim2.fromOffset(math.min(W - 24, wordSize * 6), wordSize + 10)
		wordmark.Position = UDim2.fromOffset(W / 2, H * 0.24)
		-- progress block
		local blockW = math.min(560, W * 0.82)
		local blockTop = H * 0.43
		block.Position = UDim2.fromOffset(W / 2, blockTop)
		block.Size = UDim2.fromOffset(blockW, 130)
		stageLabel.Position = UDim2.fromOffset(0, 0)
		stageLabel.Size = UDim2.fromOffset(blockW * 0.62, 26)
		countLabel.Position = UDim2.fromOffset(blockW * 0.62, 0)
		countLabel.Size = UDim2.fromOffset(blockW * 0.38, 26)
		track.Position = UDim2.fromOffset(0, 30)
		track.Size = UDim2.fromOffset(blockW, 26)
		noteLabel.Position = UDim2.fromOffset(0, 60)
		noteLabel.Size = UDim2.fromOffset(blockW, 22)
		statusLabel.Position = UDim2.fromOffset(0, 84)
		statusLabel.Size = UDim2.fromOffset(blockW, 24)
		actionButton.Position = UDim2.new(0.5, 0, 0, 110)
		actionButton.Size = UDim2.fromOffset(180, TOUCH)
		-- the tip
		local tipW = math.min(blockW + 40, W - 24)
		tipPill.Position = UDim2.fromOffset(W / 2, H * 0.43 + 148)
		tipPill.Size = UDim2.fromOffset(tipW, 44)
		tipText.Size = UDim2.fromOffset(tipW - 60, 44)
		-- backdrop (full bleed): pixel geometry from the sky's own size
		local fw, fh = full.X, full.Y
		geometry.horizon = fh * 0.74
		geometry.roadTop = fh * 0.82
		geometry.roadBottom = fh * 0.96
		geometry.carW = math.clamp(fw * 0.085, 64, 150)
		geometry.baseline = geometry.roadTop + (geometry.roadBottom - geometry.roadTop) * 0.66
		sun.Position = UDim2.fromOffset(fw * 0.84, fh * 0.2)
		sun.Size = UDim2.fromOffset(fh * 0.16, fh * 0.16)
		for i, cloud in clouds do
			cloud.Size = UDim2.fromOffset(fw * (0.1 + 0.03 * i), fh * 0.05)
		end
		for i, mesa in mesas do
			mesa.Position = UDim2.fromOffset(fw * (0.1 + 0.27 * (i - 1)), geometry.horizon)
			mesa.Size = UDim2.fromOffset(fw * (0.2 + 0.03 * (i % 2)), fh * (0.1 + 0.03 * (i % 3)))
		end
		ground.Position = UDim2.fromOffset(0, geometry.horizon)
		ground.Size = UDim2.fromOffset(fw, fh - geometry.horizon)
		road.Position = UDim2.fromOffset(0, geometry.roadTop)
		road.Size = UDim2.fromOffset(fw, geometry.roadBottom - geometry.roadTop)
		for _, dash in dashes do
			dash.Size = UDim2.fromOffset(fw * 0.06, math.max(4, fh * 0.008))
		end
		local slots: { number } = {}
		for i, car in parked do
			local x = fw * (0.18 + 0.16 * (i - 1))
			car.Size = UDim2.fromOffset(geometry.carW, geometry.carW * 0.5)
			car.Position = UDim2.fromOffset(x, geometry.baseline)
			table.insert(slots, x)
		end
		geometry.slots = slots
		for _, car in hoppers do
			car.Size = UDim2.fromOffset(geometry.carW, geometry.carW * 0.5)
		end
	end

	-- the bar, honestly: a fraction only when one is known, otherwise a moving highlight
	local function applyProgress()
		if progress == nil then
			fill.Visible = false
			shimmer.Visible = true
		else
			shimmer.Visible = false
			fill.Visible = progress > 0
			fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		end
	end
	applyProgress()

	local HOP_SECONDS = 0.62
	local PAUSE_SECONDS = 0.12

	local function animate(dt: number)
		time += dt
		local still = reduced()
		local fw = backdropGui.AbsoluteSize.X
		local fh = backdropGui.AbsoluteSize.Y
		if fw <= 0 then
			fw, fh = vp.X, vp.Y
		end
		-- clouds
		for i, cloud in clouds do
			local drift = if still then 0 else time * (4 + i * 3)
			local x = (fw * (0.15 + 0.32 * (i - 1)) + drift) % (fw * 1.3) - fw * 0.15
			cloud.Position = UDim2.fromOffset(x, fh * (0.1 + 0.07 * ((i * 5) % 3)))
		end
		-- the road's dashes
		local period = fw * 0.12
		for i, dash in dashes do
			local x = ((i - 1) * period - (if still then 0 else time * fw * 0.04)) % (period * #dashes)
			dash.Position = UDim2.fromOffset(
				x - period,
				(geometry.roadTop + geometry.roadBottom) / 2 + (geometry.roadBottom - geometry.roadTop) * 0.2
			)
		end
		-- the three hoppers: each hops from the left edge, over every parked car's roof, to the right edge, then again
		local slots = geometry.slots
		local points: { Vector2 } = {}
		local carH = geometry.carW * 0.5
		table.insert(points, Vector2.new(-geometry.carW, geometry.baseline))
		for _, x in slots do
			table.insert(points, Vector2.new(x, geometry.baseline - carH * 0.8))
		end
		table.insert(points, Vector2.new(fw + geometry.carW, geometry.baseline))
		local hops = #points - 1
		local cycle = HOP_SECONDS + PAUSE_SECONDS
		for i, car in hoppers do
			if hops < 1 then
				break
			end
			-- staggered so the three are never on the same roof
			local t = (if still then 0 else time) / cycle + (i - 1) * 2.4
			local index = math.floor(t) % hops + 1
			local u = math.clamp((t % 1) * cycle / HOP_SECONDS, 0, 1)
			if still then
				-- a calm still pose: one car per roof, resting
				local rest = points[2 + ((i * 2 - 2) % math.max(hops - 1, 1))] or points[2]
				car.Position = UDim2.fromOffset(rest.X, rest.Y)
				car.Rotation = 0
			else
				local a, b = points[index], points[index + 1]
				local arc = math.sin(u * math.pi) * carH * 1.5
				car.Position = UDim2.fromOffset(a.X + (b.X - a.X) * u, a.Y + (b.Y - a.Y) * u - arc)
				car.Rotation = (u - 0.5) * 12
			end
		end
		-- the indeterminate highlight
		if shimmer.Visible then
			local s = if still then 0.36 else (time * 0.7) % 1
			shimmer.Position = UDim2.fromScale(-0.3 + s * 1.3, 0)
		end
	end

	local function rotateTip(dt: number)
		tipClock += dt
		if tipClock < LoadingScreen.TipSeconds then
			return
		end
		tipClock = 0
		tipIndex += 1
		if reduced() then
			applyTip(tipIndex)
			return
		end
		local out = TweenService:Create(tipPill, TweenInfo.new(0.15), { BackgroundTransparency = 0.8 })
		out:Play()
		task.delay(0.15, function()
			if alive then
				applyTip(tipIndex)
				TweenService:Create(tipPill, TweenInfo.new(0.2), { BackgroundTransparency = 0.2 }):Play()
			end
		end)
	end

	local frameConn = RunService.Heartbeat:Connect(function(dt: number)
		if not alive then
			return
		end
		animate(dt)
		rotateTip(dt)
	end)
	onClean(function()
		frameConn:Disconnect()
	end)
	local sizeConn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutNow)
	local sizeConn2 = backdropGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutNow)
	onClean(function()
		sizeConn:Disconnect()
		sizeConn2:Disconnect()
	end)
	layoutNow()

	-- API ------------------------------------------------------------------------------------

	local view: View
	view = {
		setStage = function(text: string)
			if alive and text ~= stageText then
				stageText = text
				stageLabel.Text = text
			end
		end,
		setCount = function(text: string?)
			if alive and (text or "") ~= countText then
				countText = text or ""
				countLabel.Text = countText
			end
		end,
		setProgress = function(fraction: number?)
			if not alive then
				return
			end
			local p = if fraction == nil or fraction ~= fraction then nil else math.clamp(fraction, 0, 1)
			if p ~= progress then
				progress = p
				applyProgress()
			end
		end,
		setNote = function(text: string?)
			if alive and (text or "") ~= noteText then
				noteText = text or ""
				noteLabel.Text = noteText
			end
		end,
		setStatus = function(text: string?)
			if alive and (text or "") ~= statusText then
				statusText = text or ""
				statusLabel.Text = statusText
			end
		end,
		setAction = function(text: string?, onPress: (() -> ())?)
			if not alive then
				return
			end
			if text == nil or onPress == nil then
				onAction = nil
				actionLabel = ""
				actionButton.Visible = false
				return
			end
			if spent[text] then
				return
			end
			if text ~= actionLabel then
				actionLabel = text
				actionText.Text = text
			end
			if onAction == nil then
				onAction = onPress
				actionButton.Visible = true
			end
		end,
		fadeOut = function(seconds: number, onGone: (() -> ())?)
			if not alive or fading then
				return
			end
			fading = true
			local duration = if reduced() then math.min(seconds, 0.15) else seconds
			-- everything dissolves: the sky and every piece of content fade together, then the screens are removed
			for _, host in { backdropGui, gui } do
				for _, d in host:GetDescendants() do
					local goal: { [string]: any } = {}
					if d:IsA("TextLabel") or d:IsA("TextButton") then
						goal.TextTransparency = 1
						goal.TextStrokeTransparency = 1
						goal.BackgroundTransparency = 1
					elseif d:IsA("Frame") then
						goal.BackgroundTransparency = 1
					elseif d:IsA("UIStroke") then
						goal.Transparency = 1
					end
					if next(goal) then
						TweenService:Create(d, TweenInfo.new(duration, Enum.EasingStyle.Quad), goal):Play()
					end
				end
			end
			task.delay(duration + 0.05, function()
				if alive then
					view.destroy()
				end
				if onGone then
					onGone()
				end
			end)
		end,
		destroy = function()
			if not alive then
				return
			end
			alive = false
			for i = #cleanups, 1, -1 do
				pcall(cleanups[i])
			end
			table.clear(cleanups)
		end,
		isAlive = function(): boolean
			return alive
		end,
		layout = layoutNow,
		getDebugState = function(): { [string]: any }
			return {
				alive = alive,
				viewport = vp,
				uiScale = uiScale,
				designSize = design,
				stage = stageText,
				count = countText,
				progress = progress,
				indeterminate = progress == nil,
				note = noteText,
				status = statusText,
				action = actionLabel,
				actionVisible = actionButton.Visible,
				tip = tipText.Text,
				tipIndex = ((tipIndex - 1) % #tips) + 1,
				tipInStatusRow = false, -- the tip never shares the numeric row
				reduced = reduced(),
				fading = fading,
				minTextSize = MIN_TEXT,
				actionHeight = TOUCH,
			}
		end,
	}
	return view
end

-- The sink a LoadingController feeds (structurally the same table type, so this file needs no require of the controller):
-- the view shows what it is told, and finish() fades the screen out and then calls onGone once.
function LoadingScreen.sinkFor(view: View, fadeSeconds: number, onGone: (() -> ())?)
	return {
		stage = view.setStage,
		count = view.setCount,
		progress = view.setProgress,
		note = view.setNote,
		status = view.setStatus,
		action = view.setAction,
		finish = function(_reason: string, _summary: any)
			view.setStatus(nil)
			view.setAction(nil, nil)
			view.fadeOut(fadeSeconds, onGone)
		end,
	}
end

return LoadingScreen
