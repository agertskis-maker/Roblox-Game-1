--!strict
-- SupportKit: the small shared helpers behind the supporting screens (big round M12 to M16: portal card, Missions,
-- Welcome back, group reward). Lane 3 PREVIEW. Built on the Arcade kit and Style; it adds only what several of those
-- screens need and the kit does not have. Nothing here knows a game rule, an amount or a price.
--
--   SupportKit.fitFor(designSize) -> "Compact" | "Regular" | "Roomy"        -- the layout class of a design-px viewport
--   SupportKit.guard() -> Guard                                             -- "at most one" per activation
--   SupportKit.fraction(have, need, key) -> (number?, boolean)              -- a bar fill that is clamped and logs bad input
--   SupportKit.measure(text, size, width?) -> Vector2
--   SupportKit.fitLabel(label, text, w, h, maxSize)                         -- wrap, then step the size down to fit (>= 16)
--   SupportKit.localizer(frame) -> (absolute: Vector2) -> Vector2           -- a screen position -> that frame's design px
--   SupportKit.closeX(parent, onActivate) -> CloseX                         -- the square red X (48 px touch target)
--   SupportKit.pill(parent, spec) -> Pill                                   -- a small icon + word state pill
--   SupportKit.pips(parent, rarity, size) -> Frame                          -- 1..5 diamonds (rarity without colour)
--   SupportKit.carIcon(holder, car) -> boolean                              -- the family icon tinted with the paint
--   SupportKit.silhouette(holder)                                           -- darken a drawn icon to a flat shape
--   SupportKit.scene(parent, worldId, z) -> Scene                           -- a World preview built from local shapes
--   SupportKit.burst(parent, centre, count, seed) -> () -> ()               -- a bounded confetti burst (none when reduced)
--   SupportKit.touchReport(root, ratio) -> { { name, w, h } }               -- the visible interactive sizes in design px

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local SupportKit = {}

-- LAYOUT CLASS -------------------------------------------------------------------------------

export type Fit = "Compact" | "Regular" | "Roomy"

-- Design px = the safe area divided by the approved UI scale (Overlay.designSizeFor). Phone landscape
-- (844 x 390 and 667 x 375) lands in Compact (about 750 x 325 and 573 x 310), a 1024 x 768 tablet in Regular
-- (683 x 460) and 1920 x 1080 in Roomy (1280 x 681).
function SupportKit.fitFor(ds: Vector2): Fit
	if ds.Y < 420 or ds.X < 560 then
		return "Compact"
	elseif ds.X >= 1000 and ds.Y >= 600 then
		return "Roomy"
	end
	return "Regular"
end

-- GUARD --------------------------------------------------------------------------------------

export type Guard = {
	tryFire: (self: Guard) -> boolean,
	reset: (self: Guard) -> (),
	hasFired: (self: Guard) -> boolean,
	fires: (self: Guard) -> number,
}

-- "At most one per activation": tryFire is true once, then false until reset. A screen resets its own guard when it
-- opens; a guard shared with another start path (a walk-through) is reset by whoever owns it.
function SupportKit.guard(): Guard
	local fired = false
	local total = 0
	local g: Guard = {
		tryFire = function(_self: Guard): boolean
			if fired then
				return false
			end
			fired = true
			total += 1
			return true
		end,
		reset = function(_self: Guard)
			fired = false
		end,
		hasFired = function(_self: Guard): boolean
			return fired
		end,
		fires = function(_self: Guard): number
			return total
		end,
	}
	return g
end

-- PROGRESS -----------------------------------------------------------------------------------

local warned: { [string]: boolean } = {}

-- The fill of a progress bar: nil while the value is unknown (never zero), clamped to 0..1 for rendering. A value that
-- is not a sane number (NaN, infinite, negative, or a target that is not above zero) is logged once per key and drawn
-- as empty. The second result is false for such a value.
function SupportKit.fraction(have: number?, need: number, key: string): (number?, boolean)
	if have == nil then
		return nil, true
	end
	local h = have :: number
	local bad = h ~= h or h == math.huge or h == -math.huge or h < 0 or need ~= need or need <= 0 or need == math.huge
	if bad then
		if not warned[key] then
			warned[key] = true
			warn(string.format("[Lane3 support] invalid progress %s: %s of %s", key, tostring(h), tostring(need)))
		end
		return 0, false
	end
	return math.clamp(h / need, 0, 1), true
end

-- TEXT ---------------------------------------------------------------------------------------

function SupportKit.measure(text: string, size: number, width: number?): Vector2
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(width or 4096, 4096))
end

-- Wrap `text` inside w x h and use the largest size (maxSize down to the approved 16) whose wrapped height fits. Nothing
-- is cut with an ellipsis; below 16 the text keeps 16 and may grow past h (the caller scrolls).
function SupportKit.fitLabel(label: TextLabel, text: string, w: number, h: number, maxSize: number)
	label.TextWrapped = true
	label.TextScaled = false
	label.Text = text
	local size = math.max(maxSize, Tokens.TextSize.Minimum)
	while size > Tokens.TextSize.Minimum do
		if SupportKit.measure(text, size, math.max(w - 10, 20)).Y <= h then
			break
		end
		size -= 1
	end
	label.TextSize = size
end

-- A wrapped, outlined, vertically centred white label. Use fitLabel to set its text and size inside a known box.
function SupportKit.label(parent: Instance, name: string, size: number, z: number?): TextLabel
	local label: TextLabel = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "",
		TextSize = math.max(size, Tokens.TextSize.Minimum),
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = z or 6,
		Parent = parent,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), Parent = label })
	Arcade.outline(label, "Minor")
	return label
end

-- COORDINATES --------------------------------------------------------------------------------

-- A function turning an absolute screen position into design px of `frame`'s own coordinate space (any UIScale between
-- the frame and the screen is handled by measuring a hidden 100 px probe).
function SupportKit.localizer(frame: GuiObject): (Vector2) -> Vector2
	local probe = make("Frame", {
		Name = "Probe",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(100, 100),
		Visible = true,
		Parent = frame,
	})
	pcall(function()
		(probe :: any).Interactable = false
	end)
	return function(absolute: Vector2): Vector2
		local ratio = probe.AbsoluteSize.X / 100
		if ratio <= 0 then
			ratio = 1
		end
		return (absolute - frame.AbsolutePosition) / ratio
	end
end

-- CLOSE X ------------------------------------------------------------------------------------

export type CloseX = { root: TextButton, trove: Trove.Trove }

-- The square red X of the concept boards: the kit's red fill, the dark button boundary, a gloss band and the Close icon;
-- 48 design px (the approved touch minimum). Anchored top-right; the caller positions it.
function SupportKit.closeX(parent: Instance, onActivate: () -> ()): CloseX
	local trove = Trove.new()
	local side = Tokens.Touch.Minimum
	local button: TextButton = trove:Add(make("TextButton", {
		Name = "CloseX",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 14,
		Parent = parent,
	}))
	Arcade.corner(button, A.Button.Radius + 2)
	Arcade.outline(button, "Button")
	make("UIGradient", { Color = A.Fill.Settings, Rotation = 90, Parent = button })
	Arcade.gloss(button)
	local holder: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		ZIndex = 16,
		Parent = button,
	})
	IconArt.draw(holder, { "Close" })
	local ring: Frame = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = button,
	})
	Arcade.corner(ring, A.Button.Radius + 7)
	Arcade.outline(ring, 3, Color3.new(1, 1, 1))
	button.SelectionImageObject = ring
	local press: UIScale = make("UIScale", { Name = "Press", Parent = button })
	local last = -math.huge
	trove:Connect(button.Activated, function()
		local now = os.clock()
		if now - last < 0.25 then
			return
		end
		last = now
		onActivate()
	end)
	trove:Connect(button.MouseButton1Down, function()
		Motion.tween(press, "press", Motion.info(A.Motion.Press), { Scale = 0.94 })
	end)
	trove:Connect(button.MouseButton1Up, function()
		Motion.tween(press, "press", Motion.info(A.Motion.Release), { Scale = 1 })
	end)
	trove:Connect(button.MouseLeave, function()
		Motion.tween(press, "press", Motion.info(A.Motion.Release), { Scale = 1 })
	end)
	trove:Add(function()
		Motion.cancelAll(press)
	end)
	return { root = button, trove = trove }
end

-- STATE PILL ---------------------------------------------------------------------------------

export type PillSpec = {
	text: string,
	icons: { string },
	fill: Arcade.FillName,
	z: number?,
}

export type Pill = {
	root: Frame,
	set: (text: string, icons: { string }, fill: Arcade.FillName) -> (),
	width: () -> number,
}

local PILL_H = 30

-- A small word + icon chip. State is never colour alone: the word and the icon both change.
function SupportKit.pill(parent: Instance, spec: PillSpec): Pill
	local z = spec.z or 10
	local root: Frame = make("Frame", {
		Name = "StatePill",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(110, PILL_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = z,
		Parent = parent,
	})
	Arcade.corner(root, 7)
	Arcade.outline(root, "Button")
	local gradient: UIGradient = make("UIGradient", { Color = A.Fill[spec.fill], Rotation = 90, Parent = root })
	local holder: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	local label =
		Arcade.text(root, { text = "", role = "Small", name = "Text", z = z + 2, xAlign = Enum.TextXAlignment.Left })
	label.AnchorPoint = Vector2.new(0, 0.5)
	local width = 110
	local function set(text: string, icons: { string }, fill: Arcade.FillName)
		holder:ClearAllChildren()
		IconArt.draw(holder, icons)
		label.Text = text
		gradient.Color = A.Fill[fill]
		local textW = math.ceil(SupportKit.measure(text, 16).X) + 8
		width = 6 + 20 + 4 + textW + 8
		root.Size = UDim2.fromOffset(width, PILL_H)
		label.Position = UDim2.new(0, 30, 0.5, 0)
		label.Size = UDim2.fromOffset(textW + 4, 24)
	end
	set(spec.text, spec.icons, spec.fill)
	return {
		root = root,
		set = set,
		width = function(): number
			return width
		end,
	}
end

-- RARITY PIPS --------------------------------------------------------------------------------

-- Five small diamonds, the first N filled (N from the rarity ladder): the rarity reads without colour.
function SupportKit.pips(parent: Instance, rarity: string, size: number): Frame
	local info = (PreviewTokens.Rarity :: any)[rarity] or PreviewTokens.Rarity.Common
	local holder: Frame = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size * 5 + 4 * 2, size),
		ZIndex = parent:IsA("GuiObject") and (parent :: GuiObject).ZIndex + 1 or 6,
		Parent = parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	for i = 1, 5 do
		local d: Frame = make("Frame", {
			Name = "Pip" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(size * 0.8, size * 0.8),
			Rotation = 45,
			BackgroundColor3 = if i <= info.pips then info.light else Color3.fromRGB(20, 30, 62),
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
		Arcade.outline(d, 1.5)
	end
	return holder
end

-- CAR ART ------------------------------------------------------------------------------------

local Icons2: any = nil
do
	local module = Prototype:FindFirstChild("Icons2")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			Icons2 = result
		end
	end
end

-- The family icon (Icons2 Family_*) tinted with the car's paint, falling back to the plain Car icon and then to the
-- kit's neutral glyph (a car with no art is never a blank hole). Returns false when only the neutral glyph was drawn.
function SupportKit.carIcon(holder: Frame, car: { family: string, paint: Color3? }): boolean
	if Icons2 and Icons2.draw then
		local tint = car.paint
		local options = if tint then { tint = tint } else nil
		for _, name in { "Family_" .. car.family, "Car" } do
			local ok, drawn = pcall(Icons2.draw, holder, name, options)
			if ok and drawn then
				return true
			end
		end
	end
	return Arcade.icon(holder, "Car")
end

local SILHOUETTE = Color3.fromRGB(14, 22, 48)

-- Turns a drawn icon into one flat dark shape (an unowned car in Peek): every fill becomes the same ink-navy.
function SupportKit.silhouette(holder: Instance)
	for _, d in holder:GetDescendants() do
		if d:IsA("UIGradient") then
			d:Destroy()
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			d.BackgroundColor3 = SILHOUETTE
		elseif d:IsA("UIStroke") then
			d.Color = SILHOUETTE
		end
	end
end

-- WORLD SCENES -------------------------------------------------------------------------------

export type Scene = {
	root: Frame,
	setWorld: (self: Scene, worldId: string) -> (),
	layout: (self: Scene, size: Vector2) -> (),
	destroy: (self: Scene) -> (),
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- A preview of one World built only from local shapes (no image, no asset id, no mesh). Triangles are clipped squares
-- turned 45 degrees, so a peak stays a peak at any aspect ratio; everything else is a plain frame in scale units.
function SupportKit.scene(parent: Instance, worldId: string, z: number?): Scene
	local zi = z or 4
	local root: Frame = make("Frame", {
		Name = "Scene",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zi,
		Parent = parent,
	})
	Arcade.corner(root, 8)
	Arcade.outline(root, "Button")
	local sky: Frame = make("Frame", {
		Name = "Sky",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = zi,
		Parent = root,
	})
	local skyGradient: UIGradient = make("UIGradient", { Rotation = 90, Parent = sky })
	local shapes: { (w: number, h: number) -> () } = {}
	local current = ""
	local size = Vector2.new(200, 120)

	local function rect(
		name: string,
		x: number,
		base: number,
		w: number,
		h: number,
		colour: Color3,
		radius: number?,
		layer: number?
	): Frame
		local f: Frame = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(x, base),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = zi + (layer or 1),
			Parent = root,
		})
		if radius and radius > 0 then
			Arcade.corner(f, radius)
		end
		return f
	end
	local function disc(name: string, cx: number, cy: number, diameter: number, colour: Color3, layer: number?)
		local f: Frame = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx, cy),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = zi + (layer or 1),
			Parent = root,
		})
		Arcade.corner(f, 999)
		table.insert(shapes, function(_w: number, h: number)
			f.Size = UDim2.fromOffset(diameter * h, diameter * h)
		end)
	end
	local function triangle(name: string, cx: number, base: number, height: number, colour: Color3, layer: number?)
		local clip: Frame = make("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = zi + (layer or 1),
			Parent = root,
		})
		local square: Frame = make("Frame", {
			Name = "Shape",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = zi + (layer or 1),
			Parent = clip,
		})
		table.insert(shapes, function(w: number, h: number)
			local th = height * h
			clip.Position = UDim2.fromOffset(cx * w - th, base * h - th)
			clip.Size = UDim2.fromOffset(2 * th, th)
			square.Position = UDim2.fromOffset(th, th)
			square.Size = UDim2.fromOffset(th * 1.41421, th * 1.41421)
		end)
	end
	local function road(base: number, thickness: number, colour: Color3)
		rect("Road", 0, base, 1, thickness, colour, 0, 6)
		for i = 0, 4 do
			rect("Dash", 0.06 + i * 0.2, base - thickness * 0.4, 0.1, thickness * 0.1, rgb(255, 246, 214), 0, 7)
		end
	end
	local function cactus(x: number, base: number)
		local green = rgb(58, 138, 70)
		rect("Cactus", x, base, 0.022, 0.2, green, 6, 4)
		rect("CactusArmL", x - 0.016, base - 0.07, 0.016, 0.07, green, 4, 4)
		rect("CactusArmR", x + 0.022, base - 0.1, 0.016, 0.08, green, 4, 4)
	end

	local function build(id: string)
		for _, child in root:GetChildren() do
			if child ~= sky and not child:IsA("UICorner") and not child:IsA("UIStroke") then
				child:Destroy()
			end
		end
		table.clear(shapes)
		if id == "DustyHighway" then
			skyGradient.Color = ColorSequence.new(rgb(255, 214, 150), rgb(255, 150, 84))
			disc("Sun", 0.78, 0.26, 0.3, rgb(255, 244, 196), 1)
			rect("MesaA", 0.04, 0.78, 0.22, 0.4, rgb(204, 102, 62), 5, 2)
			rect("MesaB", 0.3, 0.78, 0.3, 0.52, rgb(182, 84, 52), 5, 2)
			rect("MesaBand", 0.3, 0.5, 0.3, 0.06, rgb(224, 138, 84), 0, 3)
			rect("MesaC", 0.66, 0.78, 0.18, 0.3, rgb(214, 112, 66), 5, 2)
			rect("Sand", 0, 1, 1, 0.3, rgb(240, 190, 120), 0, 4)
			cactus(0.12, 0.84)
			cactus(0.9, 0.82)
			road(0.97, 0.16, rgb(72, 70, 84))
		elseif id == "SummitPass" then
			skyGradient.Color = ColorSequence.new(rgb(150, 206, 255), rgb(226, 242, 255))
			disc("Sun", 0.82, 0.22, 0.2, rgb(255, 252, 232), 1)
			triangle("PeakA", 0.2, 0.8, 0.5, rgb(96, 128, 190), 2)
			triangle("PeakB", 0.55, 0.8, 0.72, rgb(78, 108, 176), 2)
			triangle("PeakC", 0.86, 0.8, 0.42, rgb(110, 140, 198), 2)
			triangle("CapA", 0.2, 0.8 - 0.5 * 0.7, 0.15, rgb(250, 252, 255), 3)
			triangle("CapB", 0.55, 0.8 - 0.72 * 0.78, 0.16, rgb(250, 252, 255), 3)
			triangle("CapC", 0.86, 0.8 - 0.42 * 0.7, 0.13, rgb(250, 252, 255), 3)
			rect("Snow", 0, 1, 1, 0.3, rgb(246, 250, 255), 0, 4)
			triangle("PineA", 0.08, 0.86, 0.2, rgb(46, 112, 84), 5)
			triangle("PineB", 0.95, 0.84, 0.18, rgb(46, 112, 84), 5)
			road(0.97, 0.16, rgb(86, 92, 112))
		else
			skyGradient.Color = ColorSequence.new(rgb(126, 200, 255), rgb(232, 244, 255))
			disc("Sun", 0.8, 0.24, 0.24, rgb(255, 246, 204), 1)
			for i, spec in
				{
					{ 0.03, 0.22, 0.36 },
					{ 0.14, 0.18, 0.5 },
					{ 0.3, 0.2, 0.3 },
					{ 0.48, 0.16, 0.56 },
					{ 0.62, 0.2, 0.34 },
					{ 0.78, 0.18, 0.46 },
				} :: { { number } }
			do
				rect("Far" .. i, spec[1], 0.8, spec[2] * 0.7, spec[3], rgb(158, 190, 226), 0, 2)
			end
			for i, spec in
				{
					{ 0.0, 0.14, 0.42 },
					{ 0.17, 0.12, 0.3 },
					{ 0.34, 0.16, 0.5 },
					{ 0.55, 0.13, 0.36 },
					{ 0.72, 0.15, 0.46 },
					{ 0.9, 0.1, 0.28 },
				} :: { { number } }
			do
				rect("Near" .. i, spec[1], 0.84, spec[2], spec[3], rgb(52, 84, 160), 0, 3)
				rect("Roof" .. i, spec[1], 0.84 - spec[3], spec[2], 0.04, rgb(96, 136, 214), 0, 4)
			end
			rect("Street", 0, 1, 1, 0.2, rgb(150, 160, 178), 0, 4)
			road(0.97, 0.16, rgb(66, 72, 94))
		end
		-- the dark footing under the road, so the scene never ends on a bright edge
		rect("Footing", 0, 1, 1, 0.03, A.Ink, 0, 8)
		size = Vector2.new(math.max(size.X, 1), math.max(size.Y, 1))
		for _, fn in shapes do
			fn(size.X, size.Y)
		end
		current = id
	end
	build(worldId)

	return {
		root = root,
		setWorld = function(_self: Scene, id: string)
			if id ~= current then
				build(id)
			end
		end,
		layout = function(_self: Scene, newSize: Vector2)
			size = newSize
			for _, fn in shapes do
				fn(newSize.X, newSize.Y)
			end
		end,
		destroy = function(_self: Scene)
			root:Destroy()
		end,
	}
end

-- CONFETTI -----------------------------------------------------------------------------------

local BURST_COLOURS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(90, 190, 255),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 190, 70),
	Color3.fromRGB(170, 130, 255),
}

-- A small bounded burst of confetti around `centre` (design px of `parent`). Nothing at all when Reduce Motion is on.
-- Returns a cancel function (call it on close; the pieces also destroy themselves when done).
function SupportKit.burst(parent: GuiObject, centre: Vector2, count: number, seed: number): () -> ()
	if Motion.reduced() then
		return function() end
	end
	local rng = Random.new(seed)
	local pieces: { Frame } = {}
	for i = 1, math.min(count, 24) do
		local piece: Frame = make("Frame", {
			Name = "Confetti",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(centre.X, centre.Y),
			Size = UDim2.fromOffset(if i % 2 == 0 then 8 else 6, if i % 2 == 0 then 5 else 9),
			Rotation = rng:NextInteger(0, 90),
			BackgroundColor3 = BURST_COLOURS[(i - 1) % #BURST_COLOURS + 1],
			BorderSizePixel = 0,
			ZIndex = 60,
			Parent = parent,
		})
		Arcade.corner(piece, 2)
		table.insert(pieces, piece)
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(36, 96)
		local goal = UDim2.fromOffset(centre.X + math.cos(angle) * distance, centre.Y + math.sin(angle) * distance + 18)
		local move = Motion.tween(piece, "move", Motion.info(0.8, Enum.EasingStyle.Quad), {
			Position = goal,
			Rotation = piece.Rotation + rng:NextNumber(-220, 220),
		})
		Motion.tween(piece, "fade", TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), {
			BackgroundTransparency = 1,
		})
		move.Completed:Once(function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
	return function()
		for _, piece in pieces do
			Motion.cancelAll(piece)
			if piece.Parent then
				piece:Destroy()
			end
		end
		table.clear(pieces)
	end
end

-- TOUCH REPORT -------------------------------------------------------------------------------

-- The visible interactive objects under `root` with their size in design px (`ratio` = screen px per design px). For the
-- harness: every row must be at least 44 on both sides.
function SupportKit.touchReport(root: Instance, ratio: number): { { name: string, w: number, h: number } }
	local out: { { name: string, w: number, h: number } } = {}
	local r = if ratio > 0 then ratio else 1
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			local visible = true
			local node: Instance? = d
			while node and node ~= root do
				if node:IsA("GuiObject") and not node.Visible then
					visible = false
					break
				end
				node = node.Parent
			end
			if visible and d.AbsoluteSize.X > 0 and d.Name ~= "Dim" and d.Name ~= "SkipCatcher" then
				table.insert(out, { name = d:GetFullName(), w = d.AbsoluteSize.X / r, h = d.AbsoluteSize.Y / r })
			end
		end
	end
	return out
end

return SupportKit
