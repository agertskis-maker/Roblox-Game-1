--!strict
-- CarCard: the signature reusable portrait car card (Lane 3 HUD prototype, PREVIEW only).
--
--   local card = CarCard.new(parent, car, { size = Vector2.new(200, 280), spinning = true })
--   card:setCar(car)          -- rebuilds the model ONCE (never per frame)
--   card:setSelected(true)    -- thicker white ring + a slight lift
--   card:setSpinning(true)    -- slow turn (20 deg/s) on the shared ticker; static 3/4 otherwise
--   card:setSize(Vector2)     -- re-lays out the card and refits the camera (model kept)
--   card:loadModel()          -- for lazy cards (CardGrid builds models only near the view)
--   card:setVisible(false)    -- hidden cards never spin
--   card:destroy()
--   card:getDebugState()      -- numbers for automated checks
--
-- Design (preview choices, see the handoff):
-- * Rarity reads without colour: a rarity LABEL plus 1-5 diamond PIPS (filled count out of 5).
-- * Variants (Gold / Chrome / Rainbow) are finishes, not rarities: an outer finish ring plus a
--   ribbon with the finish word. The rarity frame, label and pips stay as they are.
-- * Unowned: the model is shown as a near-black silhouette (recoloured once at build time); the
--   rarity frame, label, pips and the NAME stay visible (a child can still go and find "Rangy");
--   the quirk line becomes a lock + "Not owned yet".
-- * car.model == nil: a neutral placeholder; "Loading..." when options.loading is true or the
--   card is lazy and not built yet, otherwise "Unavailable".
-- * car.model == "Proxy": an original part-built scale proxy (ProxyCar) with a small PROXY tag.
--   Any other value is looked up under ReplicatedStorage.Cars (read-only clone, once per setCar).
-- * The name uses TextScaled with a UITextSizeConstraint (16..22). A name that does not fit on
--   one line at 16 is cut with an ellipsis, measured with TextService (so it never overflows).
--
-- Viewport stage: a back gradient (UI), a floor disc and a darker contact disc (parts inside the
-- viewport, so they line up with the wheels at every angle), a rim highlight (UI), explicit
-- Ambient / LightColor / LightDirection. The camera is fitted to GetBoundingBox: the distance
-- comes from the field of view so the car's turning footprint fills about 70% of the stage width
-- (7-stud motorcycle to 26-stud bus). The light turns with the camera, so it looks like a
-- turntable under a fixed studio light.
--
-- One shared ticker drives every spinning card: a RenderStepped connection exists only while at
-- least one visible card is spinning; a 0.25 s poll (only while some card wants to spin) checks
-- visibility (ancestors visible, ScreenGui enabled, inside clipping frames and the viewport).
-- Reduced motion stops all turning at once and snaps to the static 3/4 angle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Prototype = script.Parent.Parent
local Fixtures = require(Prototype.Fixtures)
local Gloss = require(Prototype.Gloss)
local Icons = require(Prototype.Icons)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local ProxyCar = require(Prototype.ProxyCar)
local Sounds = require(Prototype.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

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

export type CarRef = Fixtures.CarRef
export type Status = "Owned" | "Unowned" | "Loading" | "Unavailable"

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
}

export type DebugState = {
	id: string,
	name: string,
	shownName: string,
	truncated: boolean,
	rarity: string,
	rarityLabel: string,
	pips: number,
	variant: string,
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
	builds: number,
	yawDegrees: number,
	distance: number,
	modelSize: Vector3,
	size: Vector2,
	tickerConnected: boolean,
	tickerCards: number,
}

export type Card = {
	root: Frame,
	body: TextButton,
	setCar: (self: Card, car: CarRef) -> (),
	setSelected: (self: Card, on: boolean) -> (),
	setSpinning: (self: Card, on: boolean) -> (),
	setSize: (self: Card, size: Vector2) -> (),
	setVisible: (self: Card, on: boolean) -> (),
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
-- Text fitting
---------------------------------------------------------------------------------------------

local function measure(text: string, size: number): number?
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = Tokens.font()
	params.Size = size
	params.Width = 100000
	local ok, result = pcall(function()
		return TextService:GetTextBoundsAsync(params)
	end)
	params:Destroy()
	if ok and typeof(result) == "Vector2" then
		return result.X
	end
	return nil
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

---------------------------------------------------------------------------------------------
-- Card
---------------------------------------------------------------------------------------------

local function clampSize(v: Vector2): Vector2
	return Vector2.new(math.max(v.X, CarCard.MinSize.X), math.max(v.Y, CarCard.MinSize.Y))
end

local function textLabel(parent: Instance, name: string, size: number, z: number): TextLabel
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = math.max(size, Tokens.TextSize.Minimum),
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = z,
		Parent = parent,
	})
end

local function pill(parent: Instance, name: string, text: string, z: number): (Frame, TextLabel)
	local f = make("Frame", {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Gloss.corner(f, 8)
	Gloss.stroke(f, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = f })
	local t = make("TextLabel", {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = text,
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = C.Ink,
		ZIndex = z + 1,
		Parent = f,
	})
	return f, t
end

function CarCard.new(parent: Instance, initialCar: CarRef, options: Options?): Card
	local opts: Options = options or {}
	local trove = Trove.new()
	local modelTrove = trove:Extend()

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
	local nameToken = 0
	local compact = false
	local stageSize = Vector2.new(1, 1)
	local nameWidth = 100

	local R = 16 -- corner radius

	local root: Frame = trove:Add(make("Frame", {
		Name = opts.name or ("CarCard_" .. car.id),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
	}))
	local shadow = make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, PreviewTokens.Size.ShadowOffset + 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = root,
	})
	Gloss.corner(shadow, R)
	local lift = make("Frame", {
		Name = "Lift",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	local variantRing = make("Frame", {
		Name = "VariantRing",
		Position = UDim2.fromOffset(-5, -5),
		Size = UDim2.new(1, 10, 1, 10),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = lift,
	})
	Gloss.corner(variantRing, R + 5)
	Gloss.stroke(variantRing, 2)
	local variantGradient = Gloss.gradient(variantRing, C.White, C.White, 45)
	local selectRing = make("Frame", {
		Name = "SelectedRing",
		Position = UDim2.fromOffset(-10, -10),
		Size = UDim2.new(1, 20, 1, 20),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = lift,
	})
	Gloss.corner(selectRing, R + 10)
	Gloss.stroke(selectRing, 5, C.White)
	local selectOuter = make("Frame", {
		Name = "Outer",
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = selectRing,
	})
	Gloss.corner(selectOuter, R + 14)
	Gloss.stroke(selectOuter, 2, C.Ink)

	local body: TextButton = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 3,
		Parent = lift,
	})
	Gloss.corner(body, R)
	Gloss.stroke(body, 3)
	local frameGradient = Gloss.gradient(body, C.White, C.White, 90)
	local focusRing = make("Frame", {
		Name = "FocusRing",
		Position = UDim2.fromOffset(-6, -6),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	Gloss.corner(focusRing, R + 6)
	Gloss.stroke(focusRing, 3, C.White)
	body.SelectionImageObject = focusRing

	local inner = make("Frame", {
		Name = "Inner",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = body,
	})
	Gloss.corner(inner, R - 5)

	-- rarity strip: label + pips
	local strip = make("Frame", {
		Name = "RarityStrip",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = inner,
	})
	Gloss.corner(strip, 8)
	Gloss.stroke(strip, 2)
	local stripGradient = Gloss.gradient(strip, C.White, C.White, 0)
	local rarityLabel = textLabel(strip, "RarityLabel", 16, 6)
	rarityLabel.TextColor3 = C.White
	Gloss.stroke(rarityLabel, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)

	local pips = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(60, 16),
		ZIndex = 6,
		Parent = strip,
	})
	local pipFrames: { Frame } = {}
	for i = 1, 5 do
		local p = make("Frame", {
			Name = "Pip" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 6 + (i - 1) * 12, 0.5, 0),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = pips,
		})
		Gloss.stroke(p, 1.5)
		Gloss.corner(p, 2)
		table.insert(pipFrames, p)
	end

	-- stage
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = inner,
	})
	Gloss.corner(stage, 10)
	local stageStroke = Gloss.stroke(stage, 2)
	stageStroke.Transparency = 0.45
	local stageGradient = Gloss.gradient(stage, C.White, C.White, 90)
	local rim = make("Frame", {
		Name = "Rim",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = stage,
	})
	Gloss.corner(rim, 8)
	local rimStroke = Gloss.stroke(rim, 2, C.White)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.45, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 45,
		Parent = rimStroke,
	})
	local glow = make("Frame", {
		Name = "BackGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.9, 0.7),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = stage,
	})
	Gloss.corner(glow, 999)
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

	local placeholder = make("Frame", {
		Name = "Placeholder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 7,
		Parent = stage,
	})
	local placeholderIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = placeholder,
	})
	Icons.draw(placeholderIcon, "Car", rgb(176, 182, 196))
	local placeholderText = make("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.4, 28),
		Size = UDim2.new(1, -8, 0, 20),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "Loading" .. CarCard.Ellipsis,
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = C.InkSoft,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 8,
		Parent = placeholder,
	})

	local proxyTag, _ = pill(stage, "ProxyTag", "PROXY", 10)
	proxyTag:SetAttribute("PreviewCaption", true) -- harness caption
	proxyTag.AnchorPoint = Vector2.new(1, 1)
	proxyTag.Position = UDim2.new(1, -4, 1, -4)
	proxyTag.BackgroundTransparency = 0.2

	local ribbon = make("Frame", {
		Name = "VariantRibbon",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = stage,
	})
	Gloss.corner(ribbon, 8)
	Gloss.stroke(ribbon, 2)
	local ribbonGradient = Gloss.gradient(ribbon, C.White, C.White, 0)
	make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = ribbon })
	local ribbonText = make("TextLabel", {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "",
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = C.White,
		ZIndex = 11,
		Parent = ribbon,
	})
	Gloss.stroke(ribbonText, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)

	local newTag, newText = pill(stage, "NewTag", "NEW", 10)
	newTag.Position = UDim2.fromOffset(4, 4)
	newTag.BackgroundColor3 = C.Badge
	newText.TextColor3 = C.White

	-- name + rows
	local nameLabel = make("TextLabel", {
		Name = "CarName",
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = car.name,
		TextScaled = true,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = C.Ink,
		ZIndex = 6,
		Parent = inner,
	})
	make("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 22, Parent = nameLabel })

	local familyRow = make("Frame", { Name = "FamilyRow", BackgroundTransparency = 1, ZIndex = 5, Parent = inner })
	local familyIcon = make("Frame", {
		Name = "FamilyIcon",
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = familyRow,
	})
	local familyLabel = textLabel(familyRow, "Family", 16, 6)
	familyLabel.TextColor3 = C.InkSoft
	familyLabel.Position = UDim2.fromOffset(26, 0)
	familyLabel.Size = UDim2.new(1, -26, 1, 0)

	local quirkRow = make("Frame", { Name = "QuirkRow", BackgroundTransparency = 1, ZIndex = 5, Parent = inner })
	local quirkIcon = make("Frame", {
		Name = "QuirkIcon",
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = quirkRow,
	})
	local quirkLabel = textLabel(quirkRow, "Quirk", 16, 6)
	quirkLabel.Position = UDim2.fromOffset(26, 0)
	quirkLabel.Size = UDim2.new(1, -26, 1, 0)

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
		-- horizontal: the turning footprint (a circle) fills Fill of the stage width
		local rH = 0.5 * math.sqrt(modelSize.X ^ 2 + modelSize.Z ^ 2)
		local dH = rH / math.sin(math.atan(CarCard.Fill * tanH))
		-- vertical: projected height (body height plus the footprint seen from above) in 80%
		local halfV = 0.5 * (modelSize.Y * math.cos(el) + 2 * rH * math.sin(el))
		local dV = halfV / (0.8 * tanV) + rH * 0.3
		distance = math.max(dH, dV)
		-- look a little above the centre so the car sits low on its floor disc
		target = Vector3.new(0, modelSize.Y * 0.55, 0)
		placeCamera()
	end

	-------------------------------------------------------------------------------------------
	-- layout
	-------------------------------------------------------------------------------------------

	local function fitName()
		nameToken += 1
		local token = nameToken
		local text = car.name
		nameLabel.Text = text
		shownName = text
		truncated = false
		local width = nameWidth
		task.spawn(function()
			local full = measure(text, 16)
			if destroyed or token ~= nameToken or full == nil or full <= width then
				return
			end
			local count = utf8.len(text) or #text
			local lo, hi, best = 1, count - 1, 1
			while lo <= hi do
				local mid = (lo + hi) // 2
				local w = measure(trimRight(prefix(text, mid)) .. CarCard.Ellipsis, 16)
				if destroyed or token ~= nameToken or w == nil then
					return
				end
				if w <= width then
					best = mid
					lo = mid + 1
				else
					hi = mid - 1
				end
			end
			local cut = trimRight(prefix(text, best)) .. CarCard.Ellipsis
			nameLabel.Text = cut
			shownName = cut
			truncated = true
		end)
	end

	local function applyLayout()
		local W, H = size.X, size.Y
		compact = W < CarCard.CompactBelow
		root.Size = UDim2.fromOffset(W, H)
		local iw, ih = W - 12, H - 12
		local x = 6
		local w = iw - 12
		local y = 6
		strip.Position = UDim2.fromOffset(x, y)
		strip.Size = UDim2.fromOffset(w, 24)
		y += 24 + 4
		local bottom = if compact then 24 + 2 + 16 + 6 else 26 + 2 + 20 + 2 + 20 + 6
		local stageH = math.max(ih - y - 4 - bottom, 40)
		stage.Position = UDim2.fromOffset(x, y)
		stage.Size = UDim2.fromOffset(w, stageH)
		stageSize = Vector2.new(w, stageH)
		y += stageH + 4
		local nameH = if compact then 24 else 26
		nameLabel.Position = UDim2.fromOffset(x + 4, y)
		nameLabel.Size = UDim2.fromOffset(w - 8, nameH)
		nameWidth = w - 8
		y += nameH + 2
		if compact then
			rarityLabel.Position = UDim2.fromOffset(6, 0)
			rarityLabel.Size = UDim2.new(1, -12, 1, 0)
			rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
			pips.Parent = inner
			pips.AnchorPoint = Vector2.new(0.5, 0)
			pips.Position = UDim2.new(0.5, 0, 0, y)
			familyRow.Visible = false
			quirkRow.Visible = false
		else
			rarityLabel.Position = UDim2.fromOffset(8, 0)
			rarityLabel.Size = UDim2.new(1, -16 - 64, 1, 0)
			rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
			pips.Parent = strip
			pips.AnchorPoint = Vector2.new(1, 0.5)
			pips.Position = UDim2.new(1, -6, 0.5, 0)
			familyRow.Visible = true
			quirkRow.Visible = true
			familyRow.Position = UDim2.fromOffset(x + 4, y)
			familyRow.Size = UDim2.fromOffset(w - 8, 20)
			y += 22
			quirkRow.Position = UDim2.fromOffset(x + 4, y)
			quirkRow.Size = UDim2.fromOffset(w - 8, 20)
		end
		pips.ZIndex = 7
		fitCamera()
		fitName()
	end

	-------------------------------------------------------------------------------------------
	-- content
	-------------------------------------------------------------------------------------------

	local function setStatusVisuals()
		local showPlaceholder = not hasModel
		placeholder.Visible = showPlaceholder
		viewport.Visible = hasModel
		proxyTag.Visible = hasModel and isProxy
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
			status = if car.model == nil and opts.loading == true then "Loading" else "Unavailable"
			setStatusVisuals()
			return
		end
		local m = model :: Model
		builds += 1
		modelTrove:Add(m)
		-- sit the model on y = 0, centred on the origin
		local cf, bounds = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() - Vector3.new(cf.X, cf.Y - bounds.Y / 2, cf.Z))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				if not car.owned then
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
		-- floor disc and a darker contact disc (cylinders: axis along X, so turn them upright)
		local rarity = (PreviewTokens.Rarity :: any)[car.rarity] or PreviewTokens.Rarity.Common
		local footprint = math.sqrt(bounds.X ^ 2 + bounds.Z ^ 2)
		local upright = CFrame.Angles(0, 0, math.rad(90))
		local floor = Instance.new("Part")
		floor.Name = "FloorDisc"
		floor.Shape = Enum.PartType.Cylinder
		floor.Anchored = true
		floor.Size = Vector3.new(0.2, footprint * 1.2, footprint * 1.2)
		floor.CFrame = CFrame.new(0, -0.12, 0) * upright
		floor.Color = rarity.light:Lerp(C.White, 0.55)
		floor.Material = Enum.Material.SmoothPlastic
		floor.Parent = m
		local contact = Instance.new("Part")
		contact.Name = "ContactDisc"
		contact.Shape = Enum.PartType.Cylinder
		contact.Anchored = true
		contact.Size = Vector3.new(0.2, footprint * 0.82, math.max(bounds.X, bounds.Z) * 0.82)
		contact.CFrame = CFrame.new(0, -0.08, 0) * upright
		contact.Color = rarity.deep:Lerp(C.Ink, 0.5)
		contact.Transparency = 0.35
		contact.Material = Enum.Material.SmoothPlastic
		contact.Parent = m
		m.Parent = viewport
		hasModel = true
		status = if car.owned then "Owned" else "Unowned"
		setStatusVisuals()
		fitCamera()
	end

	local function applyCar()
		local rarity = (PreviewTokens.Rarity :: any)[car.rarity] or PreviewTokens.Rarity.Common
		root.Name = opts.name or ("CarCard_" .. car.id)
		frameGradient.Color = ColorSequence.new(rarity.light, rarity.deep)
		stripGradient.Color = ColorSequence.new(rarity.light:Lerp(rarity.deep, 0.25), rarity.deep)
		stageGradient.Color = ColorSequence.new(rarity.deep:Lerp(C.White, 0.45), rarity.light:Lerp(C.White, 0.82))
		rarityLabel.Text = rarity.label
		for i, p in pipFrames do
			local filled = i <= rarity.pips
			p.BackgroundColor3 = if filled then C.White else C.Ink
			p.BackgroundTransparency = if filled then 0 else 0.75
		end
		local finish = VARIANT[car.variant]
		variantRing.Visible = finish ~= nil
		ribbon.Visible = finish ~= nil
		if finish then
			variantGradient.Color = finish.sequence
			ribbonGradient.Color = finish.sequence
			ribbonText.Text = finish.label
		end
		newTag.Visible = car.unseen == true
		familyIcon:ClearAllChildren()
		Icons.draw(familyIcon, "Car", C.InkSoft)
		familyLabel.Text = car.family
		quirkIcon:ClearAllChildren()
		if car.owned then
			Icons.draw(quirkIcon, "Bolt", C.PrimaryDeep)
			quirkLabel.Text = car.quirk
			quirkLabel.TextColor3 = C.Ink
		else
			Icons.draw(quirkIcon, "Lock", C.InkSoft)
			quirkLabel.Text = "Not owned yet"
			quirkLabel.TextColor3 = C.InkSoft
		end
		fitName()
		if lazy then
			modelTrove:Clean()
			hasModel = false
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
		local goal = UDim2.fromOffset(0, if selected then -6 else 0)
		if animate and not Motion.reduced() then
			Motion.tween(lift, "lift", Motion.info(PreviewTokens.Motion.Release), { Position = goal })
		else
			Motion.cancelAll(lift)
			lift.Position = goal
		end
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
			return {
				id = car.id,
				name = car.name,
				shownName = shownName,
				truncated = truncated,
				rarity = car.rarity,
				rarityLabel = rarityLabel.Text,
				pips = rarity.pips,
				variant = car.variant,
				status = status,
				owned = car.owned,
				selected = selected,
				spinning = spinning,
				active = spinner.wants() and shownNow and renderConnection ~= nil,
				shown = shownNow,
				reduced = reducedNow,
				compact = compact,
				hasModel = hasModel,
				proxy = isProxy,
				builds = builds,
				yawDegrees = math.deg(yaw),
				distance = distance,
				modelSize = modelSize,
				size = size,
				tickerConnected = renderConnection ~= nil,
				tickerCards = registryCount(),
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
