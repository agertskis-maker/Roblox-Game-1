--!strict
-- CarCard: the signature reusable portrait car card (Lane 3 HUD prototype, PREVIEW only).
-- HUD rebuild (2026-10-22): restyled into the arcade kit family (Prototype/Arcade.luau): a thick
-- near-black boundary, limited rounding, a hard dark lip instead of a soft shadow, a dark inner
-- panel with white outlined text (no cream).
--
--   local card = CarCard.new(parent, car, { size = Vector2.new(200, 280), spinning = true })
--   card:setCar(car)          -- rebuilds the model ONCE (never per frame)
--   card:setSelected(true)    -- thick white ring + a slight lift over the dark lip
--   card:setSpinning(true)    -- slow turn (20 deg/s) on the shared ticker; static 3/4 otherwise
--   card:setSize(Vector2)     -- re-lays out the card and refits the camera (model kept)
--   card:loadModel()          -- for lazy cards (CardGrid builds models only near the view)
--   card:setVisible(false)    -- hidden cards never spin
--   card:setStamp(text?)      -- a small tilted gold stamp inside the stage (e.g. "SECURED"); nil
--                                removes it
--   card:destroy()
--   card:getDebugState()      -- numbers for automated checks
--
-- Design (preview choices, see the handoff):
-- * Rarity reads without colour: a rarity frame (gradient) PLUS the rarity LABEL word PLUS 1-5
--   diamond PIPS (filled count out of 5).
-- * Variants (Gold / Chrome / Rainbow) are finishes, not rarities: a separate outer finish ring
--   plus a ribbon with the finish word. The rarity frame, label and pips stay as they are.
-- * Unowned: the model is a near-black silhouette (recoloured once at build time); the rarity
--   frame, label, pips and the NAME stay visible; the quirk line becomes a lock + "Not owned yet".
-- * car.model == nil: a neutral placeholder; "Loading..." when options.loading is true or the
--   card is lazy and not built yet, otherwise "Unavailable".
-- * car.model == "Proxy": an original part-built scale proxy (ProxyCar). Its "PROXY" tag is a
--   HARNESS CAPTION (attribute PreviewCaption = true): the card only shows or hides the tag's
--   holder; the tag's own Visible is left to the harness caption switch, so selecting or
--   rebuilding a card can never bring it back in a player-facing capture.
-- * Name rule: never truncated in a way that loses the model number. The name fits on one line
--   at 22..16, else wraps to two lines at 22..16 (no word is split); only a name that cannot fit
--   two lines at 16 is shortened, and then the LAST word is always kept ("Supercalifr… Deluxe").
--   Measured with TextService; until the measurement returns, TextScaled + TextWrapped (16..22)
--   keeps the name inside its box.
--
-- Viewport stage: a back gradient (UI), a floor disc and a darker contact disc (parts inside the
-- viewport, so they line up with the wheels at every angle), explicit Ambient / LightColor /
-- LightDirection. The camera is fitted to GetBoundingBox: the turning footprint fills about 70%
-- of the stage width (7-stud motorcycle to 26-stud bus). The light turns with the camera.
--
-- One shared ticker drives every spinning card: a RenderStepped connection exists only while at
-- least one visible card is spinning; a 0.25 s poll (only while some card wants to spin) checks
-- visibility (ancestors visible, ScreenGui enabled, inside clipping frames and the viewport).
-- Reduced motion stops all turning at once and snaps to the static 3/4 angle. CardGrid limits
-- how many cards spin (6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Fixtures = require(Prototype.Fixtures)
local Icons = require(Prototype.Icons)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local ProxyCar = require(Prototype.ProxyCar)
local Sounds = require(Prototype.Sounds)
local Style = require(Prototype.Screens.Style)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local CarCard = {}

CarCard.BaseSize = Vector2.new(200, 280)
CarCard.MinSize = Vector2.new(112, 150)
CarCard.CompactBelow = 180 -- narrower cards drop the family / quirk rows (pips move down)
CarCard.SpinDegreesPerSecond = 20
CarCard.StaticYawDegrees = 35 -- front three-quarter
CarCard.ElevationDegrees = 15
CarCard.FieldOfView = 30
CarCard.Fill = 0.7
CarCard.Ellipsis = "\u{2026}"
CarCard.NameMax = 22
CarCard.NameMin = 16 -- the approved minimum

-- TOKEN CANDIDATE: card corner radius (limited rounding).
local R = 8
-- TOKEN CANDIDATE: card lip depth (hard dark offset under the card).
local LIP = 4
-- TOKEN CANDIDATE: dark inner panel of the card.
local INNER = Color3.fromRGB(22, 32, 68)
-- TOKEN CANDIDATE: name area heights (two lines) for full / compact cards.
local NAME_H = 46
local NAME_H_COMPACT = 40
-- TOKEN CANDIDATE: three-line name area (narrow cards that must keep long names whole).
local NAME_H_3 = 60

export type CarRef = Fixtures.CarRef
export type Status = "Owned" | "Unowned" | "Loading" | "Unavailable"
export type NameFit = "Pending" | "OneLine" | "TwoLines" | "Shortened"

export type Options = {
	size: Vector2?,
	position: UDim2?,
	anchor: Vector2?,
	selected: boolean?,
	spinning: boolean?,
	onActivate: ((CarRef) -> ())?,
	lazy: boolean?, -- build the model only when :loadModel() is called
	loading: boolean?, -- car.model == nil shows "Loading..." instead of "Unavailable"
	name: string?,
	nameLines: number?, -- 2 (default) or 3: lines reserved for the name before it is shortened
}

export type DebugState = {
	id: string,
	name: string,
	shownName: string,
	truncated: boolean,
	nameFit: NameFit,
	nameSize: number,
	rarity: string,
	rarityLabel: string,
	pips: number,
	variant: string,
	variantLabel: string?,
	status: Status,
	owned: boolean,
	selected: boolean,
	spinning: boolean, -- the flag
	active: boolean, -- actually turning now (flag, visible, on screen, motion allowed)
	shown: boolean,
	reduced: boolean,
	compact: boolean,
	hasModel: boolean,
	proxy: boolean,
	proxyHolderVisible: boolean,
	stamp: string?,
	builds: number,
	yawDegrees: number,
	distance: number,
	modelSize: { number }, -- {x, y, z} studs (JSON-safe)
	size: { number }, -- {w, h} design px (JSON-safe)
	tickerConnected: boolean,
	tickerCards: number,
	instances: number,
}

export type Card = {
	root: Frame,
	body: TextButton,
	setCar: (self: Card, car: CarRef) -> (),
	setSelected: (self: Card, on: boolean) -> (),
	setSpinning: (self: Card, on: boolean) -> (),
	setSize: (self: Card, size: Vector2) -> (),
	setVisible: (self: Card, on: boolean) -> (),
	setStamp: (self: Card, text: string?) -> (),
	loadModel: (self: Card) -> (),
	car: (self: Card) -> CarRef,
	destroy: (self: Card) -> (),
	getDebugState: (self: Card) -> DebugState,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function kp(t: number, c: Color3): ColorSequenceKeypoint
	return ColorSequenceKeypoint.new(t, c)
end

-- Finish treatments (not rarities). At most 6 stops each (UIGradient guidance).
local VARIANT: { [string]: { label: string, sequence: ColorSequence } } = {
	Gold = {
		label = "GOLD",
		sequence = ColorSequence.new({
			kp(0, rgb(255, 240, 160)),
			kp(0.45, rgb(244, 196, 60)),
			kp(0.7, rgb(255, 226, 120)),
			kp(1, rgb(186, 124, 8)),
		}),
	},
	Chrome = {
		label = "CHROME",
		sequence = ColorSequence.new({
			kp(0, rgb(252, 253, 255)),
			kp(0.35, rgb(160, 172, 190)),
			kp(0.55, rgb(240, 244, 250)),
			kp(0.8, rgb(120, 132, 152)),
			kp(1, rgb(210, 218, 230)),
		}),
	},
	Rainbow = {
		label = "RAINBOW",
		sequence = ColorSequence.new({
			kp(0, rgb(255, 96, 96)),
			kp(0.2, rgb(255, 176, 60)),
			kp(0.4, rgb(255, 228, 80)),
			kp(0.6, rgb(96, 214, 120)),
			kp(0.8, rgb(80, 156, 255)),
			kp(1, rgb(186, 110, 255)),
		}),
	},
}

local SILHOUETTE = rgb(28, 32, 46)

---------------------------------------------------------------------------------------------
-- Shared ticker (one RenderStepped for all cards, connected only while needed)
---------------------------------------------------------------------------------------------

type Spinner = {
	wants: () -> boolean, -- spinning flag, card visible, model built, motion allowed
	isShown: () -> boolean,
	advance: (dt: number) -> (),
	onReduced: (reduced: boolean) -> (),
	shown: boolean,
}

local registry: { [Spinner]: boolean } = {}
local renderConnection: RBXScriptConnection? = nil
local polling = false
local reducedNow = Motion.reduced()

local function registryCount(): number
	local n = 0
	for _ in registry do
		n += 1
	end
	return n
end

local function updateRender()
	local need = false
	for s in registry do
		if s.shown and s.wants() then
			need = true
			break
		end
	end
	if need and not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(function(dt: number)
			for s in registry do
				if s.shown and s.wants() then
					s.advance(dt)
				end
			end
		end)
	elseif not need and renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function poll()
	while polling do
		local any = false
		for s in registry do
			if s.wants() then
				any = true
				s.shown = s.isShown()
			else
				s.shown = false
			end
		end
		updateRender()
		if not any then
			polling = false
			break
		end
		task.wait(0.25)
	end
end

local function wake()
	for s in registry do
		if s.wants() then
			s.shown = s.isShown()
		end
	end
	updateRender()
	if not polling then
		polling = true
		task.spawn(poll)
	end
end

Motion.onReducedChanged(function(reduced: boolean)
	reducedNow = reduced
	for s in registry do
		s.onReduced(reduced)
	end
	wake()
end)

-- Whether a GuiObject is really on screen: in the game, every ancestor visible, its ScreenGui
-- enabled, and some of it inside every clipping ancestor and the camera viewport.
local function isShown(g: GuiObject): boolean
	if not g:IsDescendantOf(game) then
		return false
	end
	local pos, size = g.AbsolutePosition, g.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return false
	end
	local x0, y0, x1, y1 = pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y
	local node: Instance? = g
	while node do
		if node:IsA("GuiObject") then
			local gui = node :: GuiObject
			if not gui.Visible then
				return false
			end
			if gui ~= g and gui.ClipsDescendants then
				local p, s = gui.AbsolutePosition, gui.AbsoluteSize
				x0, y0 = math.max(x0, p.X), math.max(y0, p.Y)
				x1, y1 = math.min(x1, p.X + s.X), math.min(y1, p.Y + s.Y)
			end
		elseif node:IsA("LayerCollector") then
			if not (node :: LayerCollector).Enabled then
				return false
			end
			break
		end
		node = node.Parent
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local v = camera.ViewportSize
		x0, y0 = math.max(x0, 0), math.max(y0, 0)
		x1, y1 = math.min(x1, v.X), math.min(y1, v.Y)
	end
	return x1 > x0 + 1 and y1 > y0 + 1
end

---------------------------------------------------------------------------------------------
-- Text fitting (the name rule)
---------------------------------------------------------------------------------------------

-- Bounds of `text` at `size`, wrapped inside `width` (single line when width is huge).
local function measure(text: string, size: number, width: number): Vector2?
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = Tokens.font()
	params.Size = size
	params.Width = width
	local ok, result = pcall(function()
		return TextService:GetTextBoundsAsync(params)
	end)
	params:Destroy()
	if ok and typeof(result) == "Vector2" then
		return result
	end
	return nil
end

local function words(text: string): { string }
	local out = {}
	for w in string.gmatch(text, "%S+") do
		table.insert(out, w)
	end
	return out
end

local function prefix(text: string, count: number): string
	local stop = utf8.offset(text, count + 1)
	if stop then
		return string.sub(text, 1, stop - 1)
	end
	return text
end

local function trimRight(text: string): string
	return (string.gsub(text, "%s+$", ""))
end

-- Fits within `width` x `height`: every word on one line by itself, the wrapped block within
-- the height. Returns nil when the measurement failed (yielding; call from a task).
local function fits(text: string, size: number, width: number, height: number): boolean?
	for _, w in words(text) do
		local b = measure(w, size, 100000)
		if b == nil then
			return nil
		end
		if b.X > width then
			return false
		end
	end
	local block = measure(text, size, width)
	if block == nil then
		return nil
	end
	return block.Y <= height + 0.5
end

---------------------------------------------------------------------------------------------
-- Card
---------------------------------------------------------------------------------------------

local function clampSize(v: Vector2): Vector2
	return Vector2.new(math.max(v.X, CarCard.MinSize.X), math.max(v.Y, CarCard.MinSize.Y))
end

-- A small outlined chip inside the stage (variant ribbon, NEW, PROXY).
local function chip(parent: Instance, name: string, text: string, z: number): (Frame, TextLabel)
	local f: Frame = make("Frame", {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Arcade.corner(f, 4)
	Arcade.outline(f, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = f })
	local t = Arcade.text(f, { text = text, role = "Badge", name = "Text", autoWidth = true, z = z + 1 })
	t.Size = UDim2.fromOffset(0, 22)
	return f, t
end

function CarCard.new(parent: Instance, initialCar: CarRef, options: Options?): Card
	local opts: Options = options or {}
	local trove = Trove.new()
	local modelTrove = trove:Extend()
	local stampTrove = trove:Extend()

	local car = initialCar
	local size = clampSize(opts.size or CarCard.BaseSize)
	local selected = opts.selected == true
	local spinning = opts.spinning == true
	local visible = true
	local lazy = opts.lazy == true
	local destroyed = false
	local yaw = math.rad(CarCard.StaticYawDegrees)
	local distance = 0
	local target = Vector3.zero
	local modelSize = Vector3.zero
	local hasModel = false
	local isProxy = false
	local builds = 0
	local status: Status = "Loading"
	local shownName = car.name
	local truncated = false
	local nameFit: NameFit = "Pending"
	local nameSize = CarCard.NameMax
	local nameToken = 0
	local compact = false
	local stageSize = Vector2.new(1, 1)
	local nameWidth = 100
	local nameHeight = NAME_H
	local stampText: string? = nil

	local root: Frame = trove:Add(make("Frame", {
		Name = opts.name or ("CarCard_" .. car.id),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
	}))
	-- hard dark lip (no soft shadow)
	local lip: Frame = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, LIP),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = root,
	})
	Arcade.corner(lip, R)
	local lift: Frame = make("Frame", {
		Name = "Lift",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	-- the finish ring (variants only) sits outside the rarity frame
	local variantRing: Frame = make("Frame", {
		Name = "VariantRing",
		Position = UDim2.fromOffset(-5, -5),
		Size = UDim2.new(1, 10, 1, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = lift,
	})
	Arcade.corner(variantRing, R + 4)
	Arcade.outline(variantRing, 2)
	local variantGradient: UIGradient = make("UIGradient", { Rotation = 45, Parent = variantRing })
	local selectRing: Frame = make("Frame", {
		Name = "SelectedRing",
		Position = UDim2.fromOffset(-9, -9),
		Size = UDim2.new(1, 18, 1, 18),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = lift,
	})
	Arcade.corner(selectRing, R + 8)
	Arcade.outline(selectRing, 4, Color3.new(1, 1, 1))
	local selectOuter: Frame = make("Frame", {
		Name = "Outer",
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = selectRing,
	})
	Arcade.corner(selectOuter, R + 12)
	Arcade.outline(selectOuter, 2, A.Ink)

	local body: TextButton = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 3,
		Parent = lift,
	})
	Arcade.corner(body, R)
	Arcade.outline(body, "Button")
	local frameGradient: UIGradient = make("UIGradient", { Rotation = 90, Parent = body })
	local focusRing: Frame = make("Frame", {
		Name = "FocusRing",
		Position = UDim2.fromOffset(-6, -6),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	Arcade.corner(focusRing, R + 6)
	Arcade.outline(focusRing, 3, Color3.new(1, 1, 1))
	body.SelectionImageObject = focusRing

	local inner: Frame = make("Frame", {
		Name = "Inner",
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		BackgroundColor3 = INNER,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = body,
	})
	Arcade.corner(inner, R - 3)
	Arcade.outline(inner, "Minor")

	-- rarity strip: the rarity word + pips (never colour alone)
	local strip: Frame = make("Frame", {
		Name = "RarityStrip",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = inner,
	})
	Arcade.corner(strip, 4)
	Arcade.outline(strip, "Minor")
	local stripGradient: UIGradient = make("UIGradient", { Rotation = 90, Parent = strip })
	local rarityLabel = Arcade.text(strip, {
		text = "",
		role = "Small",
		name = "RarityLabel",
		xAlign = Enum.TextXAlignment.Left,
		z = 7,
	})
	make("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = Tokens.TextSize.Minimum, Parent = rarityLabel })

	local pips: Frame = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(60, 16),
		ZIndex = 6,
		Parent = strip,
	})
	local pipFrames: { Frame } = {}
	for i = 1, 5 do
		local p: Frame = make("Frame", {
			Name = "Pip" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 6 + (i - 1) * 12, 0.5, 0),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = pips,
		})
		Arcade.outline(p, 1.5)
		Arcade.corner(p, 2)
		table.insert(pipFrames, p)
	end

	-- stage
	local stage: Frame = make("Frame", {
		Name = "Stage",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = inner,
	})
	Arcade.corner(stage, 5)
	Arcade.outline(stage, "Minor")
	local stageGradient: UIGradient = make("UIGradient", { Rotation = 90, Parent = stage })
	local glow: Frame = make("Frame", {
		Name = "BackGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.9, 0.7),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = stage,
	})
	Arcade.corner(glow, 999)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
		Parent = glow,
	})

	local viewport: ViewportFrame = make("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = rgb(168, 172, 188),
		LightColor = rgb(255, 246, 228),
		LightDirection = Vector3.new(-0.5, -1, -0.4),
		ZIndex = 6,
		Parent = stage,
	})
	local camera: Camera = make("Camera", {
		Name = "CardCamera",
		FieldOfView = CarCard.FieldOfView,
		Parent = viewport,
	})
	viewport.CurrentCamera = camera

	local placeholder: Frame = make("Frame", {
		Name = "Placeholder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 7,
		Parent = stage,
	})
	local placeholderIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = placeholder,
	})
	Arcade.icon(placeholderIcon, "Car")
	local placeholderText = Arcade.text(placeholder, {
		text = "Loading" .. CarCard.Ellipsis,
		role = "Small",
		name = "Status",
		z = 8,
	})
	placeholderText.AnchorPoint = Vector2.new(0.5, 0)
	placeholderText.Position = UDim2.new(0.5, 0, 0.4, 24)
	placeholderText.Size = UDim2.new(1, -8, 0, 22)

	-- PROXY harness caption: the card toggles the HOLDER only; the tag itself carries
	-- PreviewCaption and its Visible belongs to the harness caption switch.
	local proxyHolder: Frame = make("Frame", {
		Name = "ProxyHolder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = stage,
	})
	local proxyTag = chip(proxyHolder, "ProxyTag", "PROXY", 10)
	proxyTag:SetAttribute("PreviewCaption", true) -- harness caption (hidden in player-facing view)
	proxyTag.BackgroundColor3 = rgb(90, 100, 124)

	local ribbon, ribbonText = chip(stage, "VariantRibbon", "", 11)
	ribbon.AnchorPoint = Vector2.new(1, 0)
	ribbon.Position = UDim2.new(1, -4, 0, 4)
	ribbon.Visible = false
	local ribbonGradient: UIGradient = make("UIGradient", { Rotation = 0, Parent = ribbon })

	local newTag = chip(stage, "NewTag", "NEW", 11)
	newTag.Position = UDim2.fromOffset(4, 4)
	newTag.BackgroundColor3 = A.Badge

	-- name + rows
	local nameLabel: TextLabel = make("TextLabel", {
		Name = "CarName",
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = car.name,
		TextScaled = true,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		LineHeight = 0.95,
		ZIndex = 6,
		Parent = inner,
	})
	local nameConstraint: UITextSizeConstraint = make("UITextSizeConstraint", {
		MinTextSize = CarCard.NameMin,
		MaxTextSize = CarCard.NameMax,
		Parent = nameLabel,
	})
	local _ = nameConstraint
	Arcade.outline(nameLabel, "Minor")

	local familyRow: Frame =
		make("Frame", { Name = "FamilyRow", BackgroundTransparency = 1, ZIndex = 5, Parent = inner })
	local familyIcon: Frame = make("Frame", {
		Name = "FamilyIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = familyRow,
	})
	local familyLabel = Arcade.text(familyRow, {
		text = "",
		role = "Small",
		name = "Family",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Left,
		z = 6,
	})
	familyLabel.Position = UDim2.fromOffset(22, 0)
	familyLabel.Size = UDim2.new(1, -22, 1, 0)
	familyLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local quirkRow: Frame = make("Frame", { Name = "QuirkRow", BackgroundTransparency = 1, ZIndex = 5, Parent = inner })
	local quirkIcon: Frame = make("Frame", {
		Name = "QuirkIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = quirkRow,
	})
	local quirkLabel = Arcade.text(quirkRow, {
		text = "",
		role = "Small",
		name = "Quirk",
		xAlign = Enum.TextXAlignment.Left,
		z = 6,
	})
	quirkLabel.Position = UDim2.fromOffset(22, 0)
	quirkLabel.Size = UDim2.new(1, -22, 1, 0)
	quirkLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-------------------------------------------------------------------------------------------
	-- camera
	-------------------------------------------------------------------------------------------

	local function placeCamera()
		if not hasModel then
			return
		end
		local el = math.rad(CarCard.ElevationDegrees)
		local dir = Vector3.new(math.sin(yaw) * math.cos(el), math.sin(el), -math.cos(yaw) * math.cos(el))
		camera.CFrame = CFrame.lookAt(target + dir * distance, target)
		local cf = camera.CFrame
		-- light from the viewer's upper left, fixed relative to the camera (turntable look)
		viewport.LightDirection = (cf.LookVector * 0.55 + cf.RightVector * 0.55 - cf.UpVector * 0.9).Unit
	end

	local function fitCamera()
		if not hasModel then
			return
		end
		local aspect = math.max(stageSize.X, 1) / math.max(stageSize.Y, 1)
		local tanV = math.tan(math.rad(CarCard.FieldOfView) / 2)
		local tanH = tanV * aspect
		local el = math.rad(CarCard.ElevationDegrees)
		local rH = 0.5 * math.sqrt(modelSize.X ^ 2 + modelSize.Z ^ 2)
		local dH = rH / math.sin(math.atan(CarCard.Fill * tanH))
		local halfV = 0.5 * (modelSize.Y * math.cos(el) + 2 * rH * math.sin(el))
		local dV = halfV / (0.8 * tanV) + rH * 0.3
		distance = math.max(dH, dV)
		target = Vector3.new(0, modelSize.Y * 0.55, 0)
		placeCamera()
	end

	-------------------------------------------------------------------------------------------
	-- name rule
	-------------------------------------------------------------------------------------------

	local function fitName()
		nameToken += 1
		local token = nameToken
		local text = car.name
		local width, height = nameWidth, nameHeight
		-- provisional: the engine keeps it inside the box (wraps, 16..22) until measured
		nameLabel.Text = text
		nameLabel.TextScaled = true
		shownName = text
		truncated = false
		nameFit = "Pending"
		task.spawn(function()
			local function stale(): boolean
				return destroyed or token ~= nameToken
			end
			-- one line, largest size first
			for s = CarCard.NameMax, CarCard.NameMin, -1 do
				local one = measure(text, s, 100000)
				if stale() or one == nil then
					return
				end
				if one.X <= width then
					nameLabel.TextScaled = false
					nameLabel.TextSize = s
					nameSize, nameFit = s, "OneLine"
					return
				end
			end
			-- two lines, no word split
			for s = CarCard.NameMax, CarCard.NameMin, -1 do
				local ok = fits(text, s, width, height)
				if stale() or ok == nil then
					return
				end
				if ok then
					nameLabel.TextScaled = false
					nameLabel.TextSize = s
					nameSize, nameFit = s, "TwoLines"
					return
				end
			end
			-- shortened at 16, always keeping the last word (the model number / word)
			local list = words(text)
			local last = list[#list] or text
			local head = trimRight(string.sub(text, 1, #text - #last))
			local count = utf8.len(head) or #head
			local lo, hi, best = 1, math.max(count - 1, 1), 0
			while lo <= hi do
				local mid = (lo + hi) // 2
				local candidate = trimRight(prefix(head, mid)) .. CarCard.Ellipsis .. " " .. last
				local ok = fits(candidate, CarCard.NameMin, width, height)
				if stale() or ok == nil then
					return
				end
				if ok then
					best = mid
					lo = mid + 1
				else
					hi = mid - 1
				end
			end
			local cut = if best > 0
				then trimRight(prefix(head, best)) .. CarCard.Ellipsis .. " " .. last
				else CarCard.Ellipsis .. " " .. last
			nameLabel.TextScaled = false
			nameLabel.TextSize = CarCard.NameMin
			nameLabel.Text = cut
			shownName = cut
			truncated = true
			nameSize, nameFit = CarCard.NameMin, "Shortened"
		end)
	end

	-------------------------------------------------------------------------------------------
	-- layout
	-------------------------------------------------------------------------------------------

	local function placeTags()
		-- NEW top-left, finish ribbon top-right; on narrow stages with both, NEW drops below
		newTag.Position = UDim2.fromOffset(4, if compact and ribbon.Visible then 30 else 4)
	end

	local function applyLayout()
		local W, H = size.X, size.Y
		compact = W < CarCard.CompactBelow
		root.Size = UDim2.fromOffset(W, H)
		local iw, ih = W - 10, H - 10
		local x = 5
		local w = iw - 10
		local y = 5
		strip.Position = UDim2.fromOffset(x, y)
		strip.Size = UDim2.fromOffset(w, 24)
		y += 24 + 4
		nameHeight = if (opts.nameLines or 2) >= 3 then NAME_H_3 elseif compact then NAME_H_COMPACT else NAME_H
		local bottom = nameHeight + 2 + (if compact then 16 + 4 else 20 + 2 + 20 + 4)
		local stageH = math.max(ih - y - 4 - bottom, 40)
		stage.Position = UDim2.fromOffset(x, y)
		stage.Size = UDim2.fromOffset(w, stageH)
		stageSize = Vector2.new(w, stageH)
		y += stageH + 2
		nameLabel.Position = UDim2.fromOffset(x, y)
		nameLabel.Size = UDim2.fromOffset(w, nameHeight)
		nameWidth = w - 4
		y += nameHeight + 2
		if compact then
			rarityLabel.Position = UDim2.fromOffset(4, 0)
			rarityLabel.Size = UDim2.new(1, -8, 1, 0)
			rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
			rarityLabel.TextScaled = true
			pips.Parent = inner
			pips.AnchorPoint = Vector2.new(0.5, 0)
			pips.Position = UDim2.new(0.5, 0, 0, y)
			familyRow.Visible = false
			quirkRow.Visible = false
		else
			rarityLabel.Position = UDim2.fromOffset(4, 0)
			rarityLabel.Size = UDim2.new(1, -8 - 64, 1, 0)
			rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
			rarityLabel.TextScaled = true
			pips.Parent = strip
			pips.AnchorPoint = Vector2.new(1, 0.5)
			pips.Position = UDim2.new(1, -4, 0.5, 0)
			familyRow.Visible = true
			quirkRow.Visible = true
			familyRow.Position = UDim2.fromOffset(x + 2, y)
			familyRow.Size = UDim2.fromOffset(w - 4, 20)
			y += 22
			quirkRow.Position = UDim2.fromOffset(x + 2, y)
			quirkRow.Size = UDim2.fromOffset(w - 4, 20)
		end
		pips.ZIndex = 7
		placeTags()
		fitCamera()
		fitName()
	end

	-------------------------------------------------------------------------------------------
	-- content
	-------------------------------------------------------------------------------------------

	local function setStatusVisuals()
		placeholder.Visible = not hasModel
		viewport.Visible = hasModel
		-- only the holder: the PROXY tag's own Visible is the harness caption switch
		proxyHolder.Visible = hasModel and isProxy
		placeholderText.Text = if status == "Unavailable" then "Unavailable" else "Loading" .. CarCard.Ellipsis
	end

	local function buildModel()
		modelTrove:Clean()
		hasModel = false
		isProxy = false
		modelSize = Vector3.zero
		local model: Model? = nil
		if car.model == "Proxy" then
			model = ProxyCar.build(car)
			isProxy = true
		elseif car.model ~= nil then
			local folder = ReplicatedStorage:FindFirstChild("Cars")
			local source = folder and folder:FindFirstChild(car.model)
			if source and source:IsA("Model") then
				model = source:Clone()
			end
		end
		if not model then
			isProxy = false
			status = if car.model == nil and opts.loading == true then "Loading" else "Unavailable"
			setStatusVisuals()
			return
		end
		local m = model :: Model
		builds += 1
		modelTrove:Add(m)
		local cf, bounds = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() - Vector3.new(cf.X, cf.Y - bounds.Y / 2, cf.Z))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				if car.owned ~= true then
					d.Color = SILHOUETTE
					d.Material = Enum.Material.SmoothPlastic
					d.Reflectance = 0
					d.Transparency = 0
				end
			elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") then
				d:Destroy()
			end
		end
		modelSize = bounds
		local rarity = (PreviewTokens.Rarity :: any)[car.rarity] or PreviewTokens.Rarity.Common
		local footprint = math.sqrt(bounds.X ^ 2 + bounds.Z ^ 2)
		local upright = CFrame.Angles(0, 0, math.rad(90))
		local floor = Instance.new("Part")
		floor.Name = "FloorDisc"
		floor.Shape = Enum.PartType.Cylinder
		floor.Anchored = true
		floor.Size = Vector3.new(0.2, footprint * 1.2, footprint * 1.2)
		floor.CFrame = CFrame.new(0, -0.12, 0) * upright
		floor.Color = rarity.light:Lerp(Color3.new(1, 1, 1), 0.55)
		floor.Material = Enum.Material.SmoothPlastic
		floor.Parent = m
		local contact = Instance.new("Part")
		contact.Name = "ContactDisc"
		contact.Shape = Enum.PartType.Cylinder
		contact.Anchored = true
		contact.Size = Vector3.new(0.2, footprint * 0.82, math.max(bounds.X, bounds.Z) * 0.82)
		contact.CFrame = CFrame.new(0, -0.08, 0) * upright
		contact.Color = rarity.deep:Lerp(A.Ink, 0.5)
		contact.Transparency = 0.35
		contact.Material = Enum.Material.SmoothPlastic
		contact.Parent = m
		m.Parent = viewport
		hasModel = true
		status = if car.owned == true then "Owned" else "Unowned"
		setStatusVisuals()
		fitCamera()
	end

	local function applyCar()
		local rarity = (PreviewTokens.Rarity :: any)[car.rarity] or PreviewTokens.Rarity.Common
		root.Name = opts.name or ("CarCard_" .. car.id)
		frameGradient.Color = ColorSequence.new(rarity.light, rarity.deep)
		stripGradient.Color = ColorSequence.new(rarity.light:Lerp(rarity.deep, 0.35), rarity.deep)
		stageGradient.Color =
			ColorSequence.new(rarity.deep:Lerp(Color3.new(1, 1, 1), 0.4), rarity.light:Lerp(Color3.new(1, 1, 1), 0.78))
		rarityLabel.Text = rarity.label
		for i, p in pipFrames do
			local filled = i <= rarity.pips
			p.BackgroundColor3 = if filled then Color3.new(1, 1, 1) else A.Ink
			p.BackgroundTransparency = if filled then 0 else 0.55
		end
		local finish = VARIANT[car.variant]
		variantRing.Visible = finish ~= nil
		ribbon.Visible = finish ~= nil
		if finish then
			variantGradient.Color = finish.sequence
			ribbonGradient.Color = finish.sequence
			ribbonText.Text = finish.label
		end
		newTag.Visible = car.unseen == true and car.owned == true
		placeTags()
		familyIcon:ClearAllChildren()
		Icons.draw(familyIcon, "Car", Style.TextSoft)
		familyLabel.Text = car.family
		quirkIcon:ClearAllChildren()
		if car.owned == true then
			Icons.draw(quirkIcon, "Bolt", PreviewTokens.Color.KeysLight)
			quirkLabel.Text = car.quirk
			quirkLabel.TextColor3 = Color3.new(1, 1, 1)
		else
			Icons.draw(quirkIcon, "Lock", Style.TextSoft)
			quirkLabel.Text = "Not owned yet"
			quirkLabel.TextColor3 = Style.TextSoft
		end
		fitName()
		if lazy then
			modelTrove:Clean()
			hasModel = false
			isProxy = false
			status = "Loading"
			setStatusVisuals()
		else
			buildModel()
		end
	end

	-------------------------------------------------------------------------------------------
	-- spinning
	-------------------------------------------------------------------------------------------

	local function snapStatic()
		yaw = math.rad(CarCard.StaticYawDegrees)
		placeCamera()
	end

	local spinner: Spinner
	spinner = {
		wants = function(): boolean
			return spinning and visible and hasModel and not destroyed and not reducedNow
		end,
		isShown = function(): boolean
			return isShown(stage)
		end,
		advance = function(dt: number)
			yaw = (yaw + math.rad(CarCard.SpinDegreesPerSecond) * dt) % (2 * math.pi)
			placeCamera()
		end,
		onReduced = function(reduced: boolean)
			if reduced then
				snapStatic()
			end
		end,
		shown = false,
	}
	registry[spinner] = true
	trove:Add(function()
		registry[spinner] = nil
		updateRender()
	end)
	trove:Add(function()
		destroyed = true
		Motion.cancelAll(lift)
		Motion.cancelAll(body)
	end)

	-- activation (touch, mouse, gamepad A all fire Activated)
	local lastActivate = -math.huge
	trove:Connect(body.Activated, function()
		local now = os.clock()
		if now - lastActivate < 0.25 then
			return
		end
		lastActivate = now
		Sounds.play("Tap")
		if opts.onActivate then
			opts.onActivate(car)
		end
	end)
	trove:Connect(body.MouseButton1Down, function()
		Motion.press(body, true)
	end)
	trove:Connect(body.MouseButton1Up, function()
		Motion.press(body, false)
	end)
	trove:Connect(body.MouseLeave, function()
		Motion.press(body, false)
	end)

	local function applySelected(animate: boolean)
		selectRing.Visible = selected
		local goal = UDim2.fromOffset(0, if selected then -5 else 0)
		if animate and not Motion.reduced() then
			Motion.tween(lift, "lift", Motion.info(PreviewTokens.Motion.Release), { Position = goal })
		else
			Motion.cancelAll(lift)
			lift.Position = goal
		end
	end

	local function applyStamp()
		stampTrove:Clean()
		local text = stampText
		if not text then
			return
		end
		local s = Style.stamp(stage, text, "Gold", 12)
		s.frame.Name = "Stamp"
		s.frame.AnchorPoint = Vector2.new(0, 1)
		-- inside the stage (which clips): the tilt never reaches the edge
		s.frame.Position = UDim2.new(0, 7, 1, -8)
		stampTrove:Add(s.frame)
	end

	applyLayout()
	applyCar()
	applySelected(false)
	root.Parent = parent
	if spinning then
		wake()
	end

	local card: Card
	card = {
		root = root,
		body = body,
		setCar = function(_self: Card, newCar: CarRef)
			car = newCar
			snapStatic()
			applyCar()
			wake()
		end,
		setSelected = function(_self: Card, on: boolean)
			if selected == on then
				return
			end
			selected = on
			applySelected(true)
		end,
		setSpinning = function(_self: Card, on: boolean)
			if spinning == on then
				return
			end
			spinning = on
			if not on then
				snapStatic()
			end
			wake()
		end,
		setSize = function(_self: Card, newSize: Vector2)
			local s = clampSize(newSize)
			if s == size then
				return
			end
			size = s
			applyLayout()
		end,
		setVisible = function(_self: Card, on: boolean)
			visible = on
			root.Visible = on
			wake()
		end,
		setStamp = function(_self: Card, text: string?)
			if stampText == text then
				return
			end
			stampText = text
			applyStamp()
		end,
		loadModel = function(_self: Card)
			if lazy then
				lazy = false
				buildModel()
				wake()
			end
		end,
		car = function(_self: Card): CarRef
			return car
		end,
		destroy = function(_self: Card)
			if not destroyed then
				trove:Destroy()
			end
		end,
		getDebugState = function(_self: Card): DebugState
			local rarity = (PreviewTokens.Rarity :: any)[car.rarity] or PreviewTokens.Rarity.Common
			local shownNow = not destroyed and isShown(stage)
			local finish = VARIANT[car.variant]
			return {
				id = car.id,
				name = car.name,
				shownName = shownName,
				truncated = truncated,
				nameFit = nameFit,
				nameSize = nameSize,
				rarity = car.rarity,
				rarityLabel = rarityLabel.Text,
				pips = rarity.pips,
				variant = car.variant,
				variantLabel = if finish then finish.label else nil,
				status = status,
				owned = car.owned == true,
				selected = selected,
				spinning = spinning,
				active = spinner.wants() and shownNow and renderConnection ~= nil,
				shown = shownNow,
				reduced = reducedNow,
				compact = compact,
				hasModel = hasModel,
				proxy = isProxy,
				proxyHolderVisible = proxyHolder.Visible,
				stamp = stampText,
				builds = builds,
				yawDegrees = math.deg(yaw),
				distance = distance,
				modelSize = { modelSize.X, modelSize.Y, modelSize.Z },
				size = { size.X, size.Y },
				tickerConnected = renderConnection ~= nil,
				tickerCards = registryCount(),
				instances = if destroyed then 0 else #root:GetDescendants(),
			}
		end,
	}
	return card
end

-- The shared ticker's state (for the playground's performance checks).
function CarCard.tickerState(): { connected: boolean, cards: number, polling: boolean }
	return { connected = renderConnection ~= nil, cards = registryCount(), polling = polling }
end

return CarCard
