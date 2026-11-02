--!strict
-- WelcomeBackMock: the "WELCOME BACK!" card shown once when the player returns (Lane 3, Round 2 N9; PREVIEW). It follows the
-- N9 text and storyboard: a title plate with a moon sitting over the card's top edge, a red X, a night scene of the player's
-- cars asleep on a mini Raceway (Zzz bubbles, floating coins, twinkling stars), a big coin and a huge outlined amount, the line
-- "Your cars kept racing for 4h 42m!" and a big green CLAIM!, with soft light rays behind the card.
--
--   local welcome = WelcomeBackMock.new(ctx, { onCollect = fn?, cashTarget = fn?, data = Data?, onRetry = fn? })
--   welcome:open(returnTo?) -> boolean   -- false when the card is suppressed (a verified zero) or already open
--   welcome:request() -> boolean         -- the QUEUED entry: honours options.gate (WelcomeFixtures.newGate), then opens
--   welcome:close()  welcome:isOpen()  welcome:skip()  welcome:pressCollect()  welcome:pressClose()  welcome:pressRetry()
--   welcome:setData(data)  welcome:setPreset("Huge")  welcome:setEarnings(amount)   -- WelcomeFixtures presets
--   welcome:setCashTarget(fn?)           -- the Cash counter's SCREEN position for the coin flight (nil = no counter shown)
--   welcome:layout()  welcome:setVisible(on)  welcome:destroy()  welcome:getDebugState()  welcome:touchReport()
--   WelcomeBackMock.geometry(designSize, withNote?) -> Geo
--
-- THE CASH IS ALREADY IN THE BALANCE when this card appears (N9-03a). CLAIM only acknowledges the summary: it disables itself,
-- flies at most six pooled coins toward the Cash counter over about 0.45 s (purely visual), calls options.onCollect exactly
-- once and closes. If the HUD counter is not shown (cashTarget is nil or returns nil) the coins just fade where they are: a
-- coordinate is never guessed. The X acknowledges once as well (no coins), so a reward already credited can be neither lost nor
-- counted twice. Nothing on this card reads or writes a balance; Cash only changes when the server says so.
--
-- STATES (N9-04a). Ready (a verified amount above zero): the full card, showing the CREDITED time (a cap included) and a
-- PREVIEW stamp while the data is a fixture. A verified zero is SUPPRESSED (open returns false, never "$0 earned"). Checking
-- says "Checking your Raceway..." with CLAIM disabled. Error says "Earnings couldn't be checked" with CLOSE and, when the
-- caller gave onRetry, a TRY AGAIN that works at most three times. Data that arrives after the card was dismissed is kept and
-- never reopens it.
--
-- MOTION. ONE scoped animator (a single Heartbeat connection, 30 updates a second) exists only while the card is open and
-- shown, and rests when it is hidden or closed. Loop limits: 3 cars, 3 Zzz, 3 coins, 4 stars. The amount counts once from 0
-- to the total between 0.18 s and 0.60 s and never replays when the scene loops (3.6 s cycle, N9-02a). The timings are the
-- storyboard's PROPOSED values, not measured from the reference. Reduced motion shows the final amount, parked cars, still
-- bubbles and stars, no coins and no ray spin.
--
-- QUEUEING (N9-04) is the lead's: open this only after the loading screen has gone, outside the first tutorial steps, and with
-- no group or shop modal open (see WelcomeFixtures.newGate for the shared rule).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CardKit = require(script.Parent.CardKit)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local WelcomeFixtures = require(Prototype.SupportFixtures.WelcomeFixtures)

local make = Arcade.make

local WelcomeBackMock = {}

WelcomeBackMock.DefaultEarnings = 446070

-- Timings (seconds). PROPOSED storyboard values (N9-02a), tuned in Studio.
local CYCLE = 3.6
local COUNT_START = 0.18
local COUNT_END = 0.6
local BOUNCE_START = { 0.2, 0.55, 0.9 }
local BOUNCE_LENGTH = 0.9
local BOUNCE_LIFT = { 0.05, 0.035, 0.045 } -- of the scene height (the storyboard's 2% is hard to see; tune)
local ZZZ_START = { 0.45, 0.65, 0.85 }
local ZZZ_LENGTH = 1.4
local COIN_START = { 1.1, 1.32, 1.54 }
local COIN_LENGTH = 1.0
local RAY_DEGREES_PER_SECOND = 6
local TICK = 1 / 30
local COIN_POOL = 6 -- the claim flight: never more than this many coins
local COIN_FLIGHT = 0.42
local COIN_STAGGER = 0.025
local MAX_RETRIES = 3
local BORDER = 6
local PLATE_H = 56
local OVERHANG = PLATE_H / 2

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Options = {
	onCollect: (() -> ())?,
	cashTarget: (() -> Vector2?)?, -- absolute screen position of the Cash counter, for the coin flight; nil = not shown
	data: WelcomeFixtures.Data?,
	gate: WelcomeFixtures.Gate?, -- the queue rule for welcome:request()
	cars: { WelcomeFixtures.LineupCar }?, -- overrides data.lineup
	onRetry: (() -> ())?, -- the existing "check again" action; TRY AGAIN shows only when this is given
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	cw: number, -- card width
	ch: number, -- card height
	stageH: number, -- card plus the title plate's overhang
	bodyW: number,
	bodyH: number,
	scene: Rect, -- in card-body px
	amountY: number,
	amountH: number,
	lineY: number,
	lineH: number,
	noteY: number,
	noteH: number, -- 0 when there is no room or nothing to say
	amountSize: number,
	lineSize: number,
	button: Vector2,
	sideButton: Vector2,
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
	zzz: number,
	coins: number,
	stars: number,
	animating: boolean, -- the one scoped animator is connected
	collectCalls: number, -- how many times options.onCollect was called (never more than once per opening)
	closeCalls: number,
	retryCalls: number,
	coinsLaunched: number,
	balanceTouched: boolean, -- always false: this card never reads or writes a balance
	timeLine: string,
	note: string,
	amountText: string,
	lineText: string,
	preview: boolean, -- the PREVIEW stamp is showing
	claimEnabled: boolean,
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
	setCashTarget: (self: Welcome, fn: (() -> Vector2?)?) -> (),
	skip: (self: Welcome) -> (),
	pressCollect: (self: Welcome) -> (),
	pressClose: (self: Welcome) -> (),
	pressRetry: (self: Welcome) -> boolean,
	destroy: (self: Welcome) -> (),
	getDebugState: (self: Welcome) -> DebugState,
	touchReport: (self: Welcome) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY -----------------------------------------------------------------------------------------------------------

-- One column at every size: the scene on top, the amount, the line, then CLAIM!. A pure function of the design-px viewport
-- (844 x 390, 667 x 375, 1024 x 768, 1920 x 1080 ...). The scene takes whatever height is left, between its minimum and
-- maximum, so a short phone gets a short scene and never a clipped button.
function WelcomeBackMock.geometry(ds: Vector2, withNote: boolean?): Geo
	local fit = SupportKit.fitFor(ds)
	local cw, amountSize, lineSize, button, sceneMin, sceneMax
	if fit == "Compact" then
		cw, amountSize, lineSize = math.min(ds.X - 16, 540), 36, 18
		button, sceneMin, sceneMax = Vector2.new(210, 56), 76, 120
	elseif fit == "Regular" then
		cw, amountSize, lineSize = math.min(ds.X - 32, 540), 50, 20
		button, sceneMin, sceneMax = Vector2.new(240, 62), 110, 200
	else
		cw, amountSize, lineSize = math.min(ds.X - 48, 620), 62, 22
		button, sceneMin, sceneMax = Vector2.new(270, 68), 150, 260
	end
	local sceneY = PLATE_H / 2 - BORDER + 4
	local amountH = amountSize + 8
	local lineH = lineSize + 8
	local noteWanted = if withNote then 22 else 0
	local buttonBox = button.Y + 4 -- the kit button's lip
	local rest = OVERHANG + BORDER * 2 + sceneY + 4 + amountH + lineH + 4 + buttonBox + 6
	local avail = ds.Y - 10
	local noteH = if noteWanted > 0 and avail - rest - noteWanted >= sceneMin then noteWanted else 0
	local sceneH = math.clamp(avail - rest - noteH, sceneMin, sceneMax)
	local bodyW = cw - BORDER * 2
	local amountY = sceneY + sceneH + 4
	local lineY = amountY + amountH
	local noteY = lineY + lineH
	local bodyH = noteY + noteH + 4 + buttonBox + 6
	local ch = bodyH + BORDER * 2
	return {
		fit = fit,
		cw = cw,
		ch = ch,
		stageH = OVERHANG + ch,
		bodyW = bodyW,
		bodyH = bodyH,
		scene = { x = 8, y = sceneY, w = bodyW - 16, h = sceneH },
		amountY = amountY,
		amountH = amountH,
		lineY = lineY,
		lineH = lineH,
		noteY = noteY,
		noteH = noteH,
		amountSize = amountSize,
		lineSize = lineSize,
		button = button,
		sideButton = Vector2.new(if fit == "Compact" then 150 else 170, 56),
	}
end

-- SCENE SHAPES -------------------------------------------------------------------------------------------------------

-- a frame placed and sized in fractions of its parent; `round` is a corner as a fraction of the shorter side
local function box(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3,
	z: number,
	round: number?
): Frame
	local f: Frame = make("Frame", {
		Name = name,
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	if round then
		make("UICorner", { CornerRadius = UDim.new(round, 0), Parent = f })
	end
	return f
end

type Rig = {
	cx: number, -- centre x as a fraction of the scene width
	car: GuiObject,
	shadow: Frame,
	bubble: CanvasGroup,
	index: number,
}

type CoinSprite = { frame: Frame, scale: UIScale, x: number, y: number }
type StarSprite = { frame: Frame, scale: UIScale, x: number, y: number, phase: number }

-- BUILD --------------------------------------------------------------------------------------------------------------

function WelcomeBackMock.new(ctx: Overlay.Ctx, options: Options?): Welcome
	local opts: Options = options or {}
	local data: WelcomeFixtures.Data = opts.data or (WelcomeFixtures.preset("Typical") :: WelcomeFixtures.Data)
	local cashTarget: (() -> Vector2?)? = opts.cashTarget
	local geo = WelcomeBackMock.geometry(Vector2.new(750, 325), false)
	local shownEarnings = 0
	local revealing = false
	local revealClock = 0
	local acknowledged = false
	local collectCalls, closeCalls, retryCalls = 0, 0, 0
	local coinsLaunched = 0
	local suppressed = false
	local lastGate = ""
	local pendingRetry = false -- a retry was asked for and the new data has not arrived yet
	local destroyed = false
	local animating = false
	local elapsed = 0
	local accumulator = 0
	local visibleCheck = 0
	local shown = true
	local builtButtons = ""
	local sceneW, sceneH = 500, 100
	local welcome: Welcome

	local overlay = Overlay.new(ctx, {
		name = "WelcomeBackMock",
		onDim = function()
			if revealing then
				welcome:skip()
			else
				welcome:pressClose()
			end
		end,
	})
	local trove = overlay.trove
	local revealTrove = trove:Extend()
	local animTrove = trove:Extend()
	local flightTrove = trove:Extend()
	local buttonsTrove = trove:Extend()
	local content = overlay.content

	-- soft light rays behind the card; the whole bundle turns slowly while the card is shown
	local rays = CardKit.rays(content, { bars = 6, radius = 300, z = 2, transparency = 0.82 })

	-- the stage: the card plus the title plate that rises above its top edge
	local stage: Frame = make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(540, 320),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = content,
	})
	local card = CardKit.card(stage, { name = "Card", z = 3 })
	local body = card.body
	-- a catcher under every control: tapping the card body during the reveal finishes it
	local catcher: TextButton = make("TextButton", {
		Name = "SkipCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Selectable = false,
		Active = false,
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = body,
	})
	trove:Connect(catcher.Activated, function()
		if revealing then
			welcome:skip()
		end
	end)

	local plate = CardKit.titlePlate(stage, {
		text = "WELCOME BACK!",
		icon = "Moon",
		iconFallback = { "Star" },
		size = 34,
		height = PLATE_H,
		z = 20,
	})
	local closeX = SupportKit.closeX(stage, function()
		welcome:pressClose()
	end)
	trove:Add(closeX.trove)
	closeX.root.ZIndex = 24

	-- the night scene: a CanvasGroup, so everything in it is cut to the rounded corners; the dark boundary is a separate frame
	-- laid over it (a stroke on the group itself would be cut away with the rest)
	local sceneHolder: Frame = make("Frame", {
		Name = "SceneHolder",
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = body,
	})
	local scene: CanvasGroup = make("CanvasGroup", {
		Name = "Scene",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = sceneHolder,
	})
	Arcade.corner(scene, 12)
	local sceneBorder: Frame = make("Frame", {
		Name = "SceneBorder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = sceneHolder,
	})
	Arcade.corner(sceneBorder, 12)
	Arcade.outline(sceneBorder, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(rgb(12, 20, 74), rgb(62, 66, 156)),
		Rotation = 90,
		Parent = scene,
	})
	local glow = box(scene, "HorizonGlow", 0, 0.42, 1, 0.3, rgb(150, 110, 220), 7)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.6),
		}),
		Rotation = 90,
		Parent = glow,
	})
	box(scene, "HillA", -0.06, 0.5, 0.5, 0.6, rgb(26, 40, 112), 7, 0.5)
	box(scene, "HillB", 0.42, 0.56, 0.66, 0.6, rgb(20, 32, 94), 7, 0.5)
	local stand = box(scene, "Grandstand", 0.78, 0.24, 0.15, 0.46, rgb(38, 48, 118), 8, 0.06)
	for i = 0, 2 do
		box(stand, "Window" .. i, 0.18 + i * 0.26, 0.14, 0.18, 0.12, rgb(255, 224, 120), 9)
	end
	for _, x in { 0.05, 0.93 } do
		box(scene, "LightPole", x + 0.018, 0.3, 0.012, 0.42, rgb(20, 28, 80), 8)
		local head = box(scene, "LightHead", x - 0.004, 0.2, 0.06, 0.12, rgb(255, 244, 190), 9, 0.2)
		Arcade.outline(head, "Minor")
	end
	local trackBand = box(scene, "Track", 0, 0.66, 1, 0.34, rgb(60, 66, 100), 10)
	make("UIGradient", {
		Color = ColorSequence.new(rgb(84, 92, 134), rgb(40, 44, 76)),
		Rotation = 90,
		Parent = trackBand,
	})
	for i = 0, 9 do
		box(
			scene,
			"Kerb" .. i,
			i * 0.1,
			0.63,
			0.1,
			0.05,
			if i % 2 == 0 then Color3.new(1, 1, 1) else rgb(232, 52, 62),
			11
		)
	end
	for _, x in { 0.012, 0.935 } do
		box(scene, "TyreLow", x, 0.72, 0.05, 0.1, rgb(20, 24, 40), 11, 0.4)
		box(scene, "TyreHigh", x, 0.6, 0.05, 0.1, rgb(30, 34, 54), 11, 0.4)
	end

	-- one rig per car: a UI car (or the owned car's art), its ground shadow and its Zzz bubble
	local rigs: { Rig } = {}
	local coins: { CoinSprite } = {}
	local stars: { StarSprite } = {}

	local function buildRigs()
		for _, rig in rigs do
			rig.car:Destroy()
			rig.shadow:Destroy()
			rig.bubble:Destroy()
		end
		table.clear(rigs)
		local list = opts.cars or data.lineup
		for i, c in list do
			if i > 3 then
				break
			end
			local shadow: Frame = make("Frame", {
				Name = "Shadow" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				ZIndex = 12,
				Parent = scene,
			})
			Arcade.corner(shadow, 99)
			local car: GuiObject
			if c.image then
				local image: ImageLabel = make("ImageLabel", {
					Name = "Car_" .. c.id,
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Image = c.image,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 13,
					Parent = scene,
				})
				car = image
			else
				local art = CardKit.uiCar(scene, { colour = c.paint, family = c.family, name = c.id }, 13)
				art.shadow.Visible = false -- the rig keeps its own shadow on the ground
				car = art.root
			end
			local bubble: CanvasGroup = make("CanvasGroup", {
				Name = "Zzz" .. i,
				AnchorPoint = Vector2.new(0.5, 1),
				Size = UDim2.fromOffset(48, 36),
				BackgroundTransparency = 1,
				ZIndex = 20,
				Parent = scene,
			})
			local bubbleBody: Frame = make("Frame", {
				Name = "Bubble",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 20,
				Parent = bubble,
			})
			Arcade.corner(bubbleBody, 12)
			Arcade.outline(bubbleBody, "Minor")
			local tail: Frame = make("Frame", {
				Name = "Tail",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.3, 0, 0, 29),
				Size = UDim2.fromOffset(8, 8),
				Rotation = 45,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 20,
				Parent = bubble,
			})
			Arcade.outline(tail, "Minor")
			bubbleBody.ZIndex = 21 -- over the tail's outline, so no seam shows
			local word = Style.text(bubbleBody, "Zzz", "Small", {
				name = "Word",
				colour = rgb(48, 100, 230),
				xAlign = Enum.TextXAlignment.Center,
				z = 22,
			})
			word.Size = UDim2.fromScale(1, 1)
			local wordStroke = word:FindFirstChildOfClass("UIStroke")
			if wordStroke then
				wordStroke.Enabled = false
			end
			table.insert(rigs, {
				cx = ({ 0.2, 0.5, 0.8 })[i],
				car = car,
				shadow = shadow,
				bubble = bubble,
				index = i,
			})
		end
	end

	local function buildSprites()
		-- three decorative coins and four stars: built once, only posed afterwards
		for i = 1, 3 do
			local holder: Frame = make("Frame", {
				Name = "FloatCoin" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(26, 26),
				BackgroundTransparency = 1,
				ZIndex = 16,
				Visible = false,
				Parent = scene,
			})
			local coin = CardKit.coin(holder, 26, 16)
			coin.Position = UDim2.fromScale(0.5, 0.5)
			local scale: UIScale = make("UIScale", { Parent = holder })
			table.insert(coins, { frame = holder, scale = scale, x = ({ 0.34, 0.64, 0.88 })[i], y = 0.5 })
		end
		local spots = { { 0.1, 0.16 }, { 0.34, 0.3 }, { 0.58, 0.14 }, { 0.9, 0.2 } }
		for i, spot in spots do
			local holder: Frame = make("Frame", {
				Name = "TwinkleStar" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(if i % 2 == 0 then 12 else 16, if i % 2 == 0 then 12 else 16),
				BackgroundTransparency = 1,
				ZIndex = 8,
				Parent = scene,
			})
			local star = CardKit.star(holder, if i % 2 == 0 then 12 else 16, 8)
			star.Position = UDim2.fromScale(0.5, 0.5)
			local scale: UIScale = make("UIScale", { Parent = holder })
			table.insert(stars, { frame = holder, scale = scale, x = spot[1], y = spot[2], phase = i * 0.27 })
		end
		local caption = Style.stamp(scene, "PREVIEW", "Gold", 24)
		caption.frame.Name = "PreviewStamp"
		caption.frame.AnchorPoint = Vector2.new(0, 0)
		caption.frame.Position = UDim2.fromOffset(8, 6)
		caption.frame:SetAttribute("PersistentPreview", true)
		return caption
	end
	local stamp = buildSprites()

	-- the figures -----------------------------------------------------------------------------------------------------
	local amountRow: Frame = make("Frame", {
		Name = "AmountRow",
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = body,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = amountRow,
	})
	local coinSlot: Frame = make("Frame", {
		Name = "CoinSlot",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = amountRow,
	})
	local bigCoin = CardKit.coin(coinSlot, 40, 7)
	bigCoin.Position = UDim2.fromScale(0.5, 0.5)
	local amount = Arcade.text(amountRow, {
		text = "$0",
		role = "Value",
		name = "Amount",
		face = "Keys",
		size = 40,
		autoWidth = true,
		outline = "Major",
		z = 7,
	})
	amount.LayoutOrder = 2
	local lineLabel = CardKit.ink(body, "", 20, { name = "Line", z = 6 })
	local noteLabel = CardKit.ink(body, "", 16, { name = "Note", colour = CardKit.NavySoft, z = 6 })
	local statusLabel = CardKit.ink(body, "", 22, { name = "Status", z = 6 })
	statusLabel.Visible = false

	-- the buttons: rebuilt only when their size changes (kit buttons are fixed size) -----------------------------------
	local claimButton: Arcade.Button? = nil
	local closeButton: Arcade.Button? = nil
	local retryButton: Arcade.Button? = nil

	-- a pool of six coins for the claim flight, in a layer of the playground's own so the flight can cross the whole screen
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
	local toLocal = SupportKit.localizer(coinLayer)
	local pool: { Frame } = {}
	for i = 1, COIN_POOL do
		local c = CardKit.coin(coinLayer, 26, 81)
		c.Name = "FlightCoin" .. i
		c.Visible = false
		table.insert(pool, c)
	end

	-- LOGIC -------------------------------------------------------------------------------------------------------------

	local function setValue(n: number)
		shownEarnings = n
		amount.Text = Format.cash(n)
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
		if pendingRetry then
			return "Checking"
		end
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

	-- the capped line ("Away 18h · Earned for 12h"), only when a cap shortened the paid time
	local function noteText(): string?
		local credited = WelcomeFixtures.creditedSeconds(data)
		local away = data.awaySeconds
		if credited ~= nil and away ~= nil and credited < away then
			return WelcomeFixtures.timeLine(data)
		end
		return nil
	end

	-- POSES ---------------------------------------------------------------------------------------------------------------

	local function carWidth(): number
		return math.clamp(sceneH * 0.95, 54, 160)
	end

	-- one pose of the whole scene at cycle time t (seconds). Cars bounce one after another, Zzz rise and fade, coins rise and
	-- pop, stars breathe. Nothing here is a loop of its own: the one animator calls it.
	local function pose(t: number, still: boolean)
		local groundY = sceneH * 0.9
		local cw = carWidth()
		local bubbleLift = sceneH * 0.07
		for _, rig in rigs do
			local i = rig.index
			local lift = 0
			local squash = 0
			local a = 0
			if not still then
				a = math.clamp((t - BOUNCE_START[i]) / BOUNCE_LENGTH, 0, 1)
				local s = math.sin(a * math.pi)
				lift = s * BOUNCE_LIFT[i] * sceneH
				squash = s * 0.16
			end
			local cx = sceneW * rig.cx
			rig.car.Position = UDim2.fromOffset(cx, groundY - lift)
			rig.shadow.Position = UDim2.fromOffset(cx, groundY + 2)
			rig.shadow.Size = UDim2.fromOffset(cw * 0.86 * (1 - squash), math.max(cw * 0.1, 5))
			-- the Zzz bubble: still, it rests part way up; moving, it rises 7% of the scene height and fades
			local za = if still then 0.3 else math.clamp((t - ZZZ_START[i]) / ZZZ_LENGTH, 0, 1)
			local carTop = groundY - cw * 0.56
			rig.bubble.Position = UDim2.fromOffset(cx + cw * 0.2, carTop - 2 - za * bubbleLift)
			if still then
				rig.bubble.GroupTransparency = 0
			elseif za <= 0 or za >= 1 then
				rig.bubble.GroupTransparency = 1
			else
				rig.bubble.GroupTransparency = 1 - math.min(1, math.sin(za * math.pi) * 2.2)
			end
		end
		for i, c in coins do
			if still then
				c.frame.Visible = false
			else
				local a = (t - COIN_START[i]) / COIN_LENGTH
				if a <= 0 or a >= 1 then
					c.frame.Visible = false
				else
					c.frame.Visible = true
					c.frame.Position = UDim2.fromOffset(sceneW * c.x, sceneH * 0.58 - a * sceneH * 0.16)
					-- pop in, hold, swell and vanish
					local s = if a < 0.2 then a / 0.2 elseif a < 0.75 then 1 else 1 + (a - 0.75) * 1.2
					c.scale.Scale = math.max(s, 0.01)
				end
			end
		end
		for _, s in stars do
			s.frame.Position = UDim2.fromOffset(sceneW * s.x, sceneH * s.y)
			if still then
				s.scale.Scale = 1
			else
				s.scale.Scale = 0.8 + 0.2 * math.sin(((t / CYCLE) + s.phase) * math.pi * 2)
			end
		end
	end

	local function layoutScene()
		local cw = carWidth()
		for _, rig in rigs do
			rig.car.Size = UDim2.fromOffset(cw, cw * 0.56)
		end
		local coinPx = math.clamp(math.floor(sceneH * 0.2), 18, 34)
		for _, c in coins do
			c.frame.Size = UDim2.fromOffset(coinPx, coinPx)
			local coin = c.frame:FindFirstChild("Coin")
			if coin and coin:IsA("Frame") then
				coin.Size = UDim2.fromOffset(coinPx, coinPx)
			end
		end
	end

	-- THE REVEAL AND THE ANIMATOR ----------------------------------------------------------------------------------------

	local function finishReveal()
		revealTrove:Clean()
		revealing = false
		catcher.Active = false
		setValue(earnedFinal())
	end

	local function tickReveal(dt: number)
		if not revealing then
			return
		end
		revealClock += dt
		local a = math.clamp((revealClock - COUNT_START) / (COUNT_END - COUNT_START), 0, 1)
		setValue(math.floor(earnedFinal() * (1 - (1 - a) ^ 3) + 0.5))
		if revealClock >= COUNT_END then
			finishReveal()
		end
	end

	local function stopAnimator()
		animTrove:Clean()
		animating = false
	end

	local function startAnimator()
		if animating then
			return
		end
		animating = true
		accumulator = 0
		animTrove:Connect(RunService.Heartbeat, function(dt: number)
			visibleCheck -= dt
			if visibleCheck <= 0 then
				visibleCheck = 0.25
				shown = CardKit.visible(overlay.root)
			end
			if not shown then
				return -- a hidden card does no animation work
			end
			accumulator += dt
			if accumulator < TICK then
				return
			end
			local step = accumulator
			accumulator = 0
			elapsed += step
			tickReveal(step)
			pose(elapsed % CYCLE, false)
			rays.root.Rotation = (elapsed * RAY_DEGREES_PER_SECOND) % 360
		end)
	end

	-- the animator exists only while the card is open, shown and motion is allowed; otherwise a still pose is held
	local function refreshAnimator()
		if destroyed then
			return
		end
		if overlay:isOpen() and overlay.root.Visible and not Motion.reduced() then
			startAnimator()
		else
			stopAnimator()
			pose(0, true)
			rays.root.Rotation = 0
			if revealing then
				finishReveal()
			end
		end
	end

	local function startReveal()
		revealTrove:Clean()
		if stateName() ~= "Ready" or Motion.reduced() then
			finishReveal()
			return
		end
		revealing = true
		revealClock = 0
		catcher.Active = true
		setValue(0)
		revealTrove:Add(Sounds.loop("ResultsCount"))
	end

	trove:Add(Motion.onReducedChanged(function(_reduced: boolean)
		refreshAnimator()
	end))
	trove:Add(function()
		destroyed = true
		stopAnimator()
	end)

	-- STATES AND LAYOUT ----------------------------------------------------------------------------------------------------

	local function applyData()
		local name = stateName()
		local ready = name == "Ready"
		local waiting = name == "Checking"
		local failed = name == "Error"
		suppressed = name == "Suppressed"
		buildRigs()
		layoutScene()
		pose(0, true)
		setValue(earnedFinal())
		amountRow.Visible = ready
		lineLabel.Visible = ready
		lineLabel.Text = if ready then WelcomeFixtures.racingLine(data) else ""
		local note = if ready then noteText() else nil
		noteLabel.Visible = note ~= nil and geo.noteH > 0
		noteLabel.Text = note or ""
		statusLabel.Visible = waiting or failed
		statusLabel.Text = if waiting
			then "Checking your Raceway..."
			elseif failed then "Earnings couldn't be checked"
			else ""
		stamp.frame.Visible = WelcomeFixtures.isPreview(data)
		local claim = claimButton
		local close = closeButton
		local retry = retryButton
		if claim then
			claim.root.Visible = ready or waiting
			claim.setEnabled(ready and not acknowledged)
		end
		if close then
			close.root.Visible = failed
		end
		if retry then
			retry.root.Visible = failed and opts.onRetry ~= nil and retryCalls < MAX_RETRIES
		end
	end

	local function buildButtons()
		local key = string.format("%dx%d/%dx%d", geo.button.X, geo.button.Y, geo.sideButton.X, geo.sideButton.Y)
		if key == builtButtons and claimButton then
			return
		end
		builtButtons = key
		buttonsTrove:Clean()
		local claim = Arcade.button(body, {
			name = "Claim",
			label = "CLAIM!",
			fill = "Green",
			size = "Custom",
			width = geo.button.X,
			height = geo.button.Y,
			pattern = true,
			cooldown = 0.5,
			onActivate = function()
				welcome:pressCollect()
			end,
		})
		buttonsTrove:Add(claim.trove)
		claim.root.ZIndex = 12
		local close = Arcade.button(body, {
			name = "Dismiss",
			label = "CLOSE",
			fill = "Garage",
			size = "Custom",
			width = geo.sideButton.X,
			height = geo.sideButton.Y,
			sound = "Close",
			cooldown = 0.4,
			onActivate = function()
				welcome:pressClose()
			end,
		})
		buttonsTrove:Add(close.trove)
		close.root.ZIndex = 12
		local retry = Arcade.button(body, {
			name = "Retry",
			label = "TRY AGAIN",
			fill = "Green",
			size = "Custom",
			width = geo.sideButton.X + 30,
			height = geo.sideButton.Y,
			cooldown = 0.6,
			onActivate = function()
				welcome:pressRetry()
			end,
		})
		buttonsTrove:Add(retry.trove)
		retry.root.ZIndex = 12
		claimButton, closeButton, retryButton = claim, close, retry
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		geo = WelcomeBackMock.geometry(ds, stateName() == "Ready" and noteText() ~= nil)
		stage.Size = UDim2.fromOffset(geo.cw, geo.stageH)
		card.root.AnchorPoint = Vector2.zero
		card.root.Position = UDim2.fromOffset(0, OVERHANG)
		card.root.Size = UDim2.fromOffset(geo.cw, geo.ch)
		plate.root.Position = UDim2.fromOffset((geo.cw - 56) / 2 + 4, OVERHANG)
		plate:fit(geo.cw - 56 - 24)
		closeX.root.AnchorPoint = Vector2.new(1, 0.5)
		closeX.root.Position = UDim2.fromOffset(geo.cw + 4, OVERHANG + 6)
		rays.root.Position = UDim2.fromOffset(geo.cw / 2, geo.stageH / 2)
		rays:setRadius(math.max(geo.cw, geo.stageH) * 0.85)
		local s = geo.scene
		sceneHolder.Position = UDim2.fromOffset(s.x, s.y)
		sceneHolder.Size = UDim2.fromOffset(s.w, s.h)
		sceneW, sceneH = s.w, s.h
		layoutScene()
		-- the figures
		amountRow.Position = UDim2.fromOffset(0, geo.amountY)
		amountRow.Size = UDim2.fromOffset(geo.bodyW, geo.amountH)
		coinSlot.Size = UDim2.fromOffset(geo.amountSize, geo.amountSize)
		bigCoin.Size = UDim2.fromOffset(geo.amountSize, geo.amountSize)
		amount.TextSize = geo.amountSize
		amount.Size = UDim2.fromOffset(0, geo.amountSize + 6)
		lineLabel.Position = UDim2.fromOffset(8, geo.lineY)
		lineLabel.Size = UDim2.fromOffset(geo.bodyW - 16, geo.lineH)
		local lineConstraint = lineLabel:FindFirstChildOfClass("UITextSizeConstraint")
		if lineConstraint then
			lineConstraint.MaxTextSize = geo.lineSize
		end
		noteLabel.Position = UDim2.fromOffset(8, geo.noteY)
		noteLabel.Size = UDim2.fromOffset(geo.bodyW - 16, math.max(geo.noteH, 20))
		statusLabel.Position = UDim2.fromOffset(8, geo.amountY)
		statusLabel.Size = UDim2.fromOffset(geo.bodyW - 16, geo.amountH + geo.lineH)
		buildButtons()
		-- the data decides which buttons show, so apply it BEFORE the buttons are placed
		applyData()
		local claim, close, retry = claimButton, closeButton, retryButton
		local bottom = geo.bodyH - 6
		if claim then
			claim.root.AnchorPoint = Vector2.new(0.5, 1)
			claim.root.Position = UDim2.fromOffset(geo.bodyW / 2, bottom)
		end
		if close and retry then
			local retryShown = retry.root.Visible
			local gap = 12
			local total = if retryShown then geo.sideButton.X * 2 + 30 + gap else geo.sideButton.X
			close.root.AnchorPoint = Vector2.new(0, 1)
			retry.root.AnchorPoint = Vector2.new(0, 1)
			close.root.Position = UDim2.fromOffset((geo.bodyW - total) / 2, bottom)
			retry.root.Position = UDim2.fromOffset((geo.bodyW - total) / 2 + geo.sideButton.X + gap, bottom)
		end
	end

	-- the acknowledgement: at most six pooled coins fly to the Cash counter; this changes no number anywhere
	local function flyCoins()
		local target: Vector2? = if cashTarget then cashTarget() else nil
		if Motion.reduced() then
			return
		end
		local claim = claimButton
		if not claim then
			return
		end
		local from = toLocal(claim.body.AbsolutePosition + claim.body.AbsoluteSize / 2)
		local to: Vector2? = if target then toLocal(target) else nil
		for i, coin in pool do
			coinsLaunched += 1
			coin.Visible = false
			coin.Position = UDim2.fromOffset(from.X, from.Y)
			coin.Size = UDim2.fromOffset(26, 26)
			flightTrove:Add(task.delay((i - 1) * COIN_STAGGER, function()
				if destroyed then
					return
				end
				coin.Visible = true
				if to then
					-- a short arc: the coin lifts before it drops toward the counter
					local mid = from:Lerp(to, 0.45) + Vector2.new(0, -34 - (i % 3) * 12)
					local up = Motion.tween(coin, "up", Motion.info(COIN_FLIGHT * 0.4, Enum.EasingStyle.Quad), {
						Position = UDim2.fromOffset(mid.X, mid.Y),
					})
					up.Completed:Once(function(state)
						if state ~= Enum.PlaybackState.Completed or destroyed then
							return
						end
						local down = Motion.tween(
							coin,
							"down",
							Motion.info(COIN_FLIGHT * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
							{
								Position = UDim2.fromOffset(to.X, to.Y),
								Size = UDim2.fromOffset(14, 14),
							}
						)
						down.Completed:Once(function()
							coin.Visible = false
							if i == #pool then
								Sounds.play("CashGain")
							end
						end)
					end)
				else
					-- no counter on screen: fade locally, never fly to a guessed spot
					local rise = Motion.tween(coin, "rise", Motion.info(COIN_FLIGHT * 0.8), {
						Position = UDim2.fromOffset(from.X + (i - 3.5) * 14, from.Y - 36),
						Size = UDim2.fromOffset(10, 10),
					})
					rise.Completed:Once(function()
						coin.Visible = false
					end)
				end
			end))
		end
		flightTrove:Add(function()
			for _, coin in pool do
				Motion.cancelAll(coin)
				coin.Visible = false
			end
		end)
	end

	-- the one acknowledgement: at most once per opening, from CLAIM! or from the X
	local function acknowledge(fly: boolean)
		if acknowledged or stateName() ~= "Ready" then
			return
		end
		acknowledged = true
		collectCalls += 1
		finishReveal()
		local claim = claimButton
		if claim then
			claim.setEnabled(false)
		end
		if fly then
			flyCoins()
		end
		if opts.onCollect then
			opts.onCollect()
		end
	end

	overlay:setBack(function()
		if revealing then
			welcome:skip()
		else
			welcome:pressClose()
		end
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	-- PUBLIC --------------------------------------------------------------------------------------------------------------

	welcome = {
		root = overlay.root,
		layout = function(_self: Welcome)
			layoutNow()
		end,
		setVisible = function(_self: Welcome, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
			refreshAnimator()
		end,
		open = function(_self: Welcome, returnTo: GuiObject?): boolean
			if destroyed or overlay:isOpen() then
				return false
			end
			if stateName() == "Suppressed" then
				suppressed = true
				return false -- a verified zero is not shown as "$0 earned"
			end
			acknowledged = false
			flightTrove:Clean()
			elapsed = 0
			layoutNow()
			local claim = claimButton
			overlay:open(if stateName() == "Ready" and claim then claim.body else closeX.root, returnTo)
			startReveal()
			refreshAnimator()
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
			local shownNow = self:open(nil)
			if shownNow and gate then
				gate:recordShown()
			end
			return shownNow
		end,
		close = function(_self: Welcome)
			if not overlay:isOpen() then
				return
			end
			closeCalls += 1
			finishReveal()
			overlay:close()
			refreshAnimator()
		end,
		isOpen = function(_self: Welcome): boolean
			return overlay:isOpen()
		end,
		setData = function(_self: Welcome, incoming: WelcomeFixtures.Data)
			data = incoming
			pendingRetry = false
			-- the data may arrive after the card was dismissed: it is kept, and it never reopens the card
			if overlay:isOpen() then
				finishReveal()
				layoutNow()
				if stateName() == "Ready" then
					startReveal()
				end
				refreshAnimator()
			else
				applyData()
			end
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
		setCashTarget = function(_self: Welcome, fn: (() -> Vector2?)?)
			cashTarget = fn
		end,
		skip = function(_self: Welcome)
			if revealing then
				finishReveal()
			end
		end,
		pressCollect = function(_self: Welcome)
			if destroyed or not overlay:isOpen() or acknowledged or stateName() ~= "Ready" then
				return
			end
			-- one action: finish the reveal if it is still running, acknowledge once, fly the coins, close
			acknowledge(true)
			welcome:close()
		end,
		pressClose = function(_self: Welcome)
			if destroyed or not overlay:isOpen() then
				return
			end
			acknowledge(false) -- a Ready card is acknowledged once; Checking and Error just close
			welcome:close()
		end,
		pressRetry = function(_self: Welcome): boolean
			if destroyed or stateName() ~= "Error" or opts.onRetry == nil or retryCalls >= MAX_RETRIES then
				return false
			end
			retryCalls += 1
			pendingRetry = true
			applyData()
			layoutNow()
			if opts.onRetry then
				opts.onRetry()
			end
			return true
		end,
		destroy = function(_self: Welcome)
			if destroyed then
				return
			end
			overlay:destroy()
		end,
		getDebugState = function(_self: Welcome): DebugState
			local claim = claimButton
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				state = stateName(),
				suppressed = suppressed,
				revealing = revealing,
				shownEarnings = shownEarnings,
				earnings = earnedFinal(),
				cars = #rigs,
				zzz = #rigs,
				coins = #coins,
				stars = #stars,
				animating = animating,
				collectCalls = collectCalls,
				closeCalls = closeCalls,
				retryCalls = retryCalls,
				coinsLaunched = coinsLaunched,
				balanceTouched = false,
				timeLine = noteText() or "",
				note = noteLabel.Text,
				amountText = amount.Text,
				lineText = lineLabel.Text,
				preview = stamp.frame.Visible,
				claimEnabled = claim ~= nil and claim.body.Active,
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

	layoutNow()
	pose(0, true)
	return welcome
end

return WelcomeBackMock
