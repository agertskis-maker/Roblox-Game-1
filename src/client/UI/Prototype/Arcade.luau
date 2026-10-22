--!strict
-- The ARCADE kit for the rebuilt HUD (Lane 3 preview, 2026-10-22). One visual system for every
-- rebuilt component, measured from Adam's two new HUD references
-- (vault/design/research/hud-ref-arcade-translation.md; spec vault/design/ui/hud-arcade-rebuild.md):
-- wide compact rectangles with limited rounding, a thick near-black boundary, a strong fill with
-- a controlled gradient, a narrow gloss band and a shallow dark lip; big white labels with a
-- dark outline; large coloured numbers floating on the world with no backing card.
--
--   Arcade.text(parent, spec) -> TextLabel          -- outlined text in a role (see TextSpec)
--   Arcade.button(parent, spec) -> Button          -- see ButtonSpec / Button
--   Arcade.badge(anchor, value) -> Badge           -- red earned badge pinned outside a corner
--   Arcade.toggle(parent, spec) -> Toggle          -- a real local on/off setting with a label
--   Arcade.icon(holder, name) -> boolean           -- Icons2 art, falling back to Icons, then a
--                                                     neutral "missing icon" glyph (never blank)
--   Arcade.motorPattern(body)                      -- faint original bolt/tread motif (large
--                                                     buttons only)
--   Arcade.outline(gui, role?) -> UIStroke         -- the dark outline at a role's thickness
--
-- Outline thickness: UIStroke thickness is set in design px and multiplied by the root's
-- HudScale here (setStrokeScale), because UIScale does not reliably scale UIStroke on text
-- (to be confirmed in Studio; the kit is correct either way as long as only one of the two
-- paths applies — see Arcade.STROKE_FOLLOWS_UISCALE).
--
-- No component may add a backing panel behind a number. Colour is never the only signal: labels,
-- icons and segment counts carry meaning too.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local PreviewTokens = require(script.Parent.PreviewTokens)
local Sounds = require(script.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local B = A.Button

local Arcade = {}

-- Set to true if Studio shows that UIScale already scales UIStroke thickness (then the kit
-- leaves thickness in design px). Checked on the specimen sheet; recorded in the UI spec.
Arcade.STROKE_FOLLOWS_UISCALE = true

-- Every stroke the kit creates, with its design thickness, so a layout change can rescale them.
local strokes: { [UIStroke]: number } = setmetatable({}, { __mode = "k" }) :: any
local strokeScale = 1

function Arcade.setStrokeScale(scale: number)
	if Arcade.STROKE_FOLLOWS_UISCALE then
		return
	end
	strokeScale = scale
	for stroke, design in strokes do
		if stroke.Parent then
			stroke.Thickness = design * strokeScale
		end
	end
end

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
Arcade.make = make

function Arcade.corner(parent: Instance, radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or B.Radius), Parent = parent })
end

export type StrokeRole = "Major" | "Minor" | "Button" | number

function Arcade.outline(gui: GuiObject, role: StrokeRole?, colour: Color3?): UIStroke
	local design = if type(role) == "number"
		then role
		elseif role == "Minor" then A.OutlineMinor
		elseif role == "Button" then A.OutlineButton
		else A.OutlineMajor
	local isText = gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")
	local s = make("UIStroke", {
		Thickness = if Arcade.STROKE_FOLLOWS_UISCALE then design else design * strokeScale,
		Color = colour or A.Ink,
		ApplyStrokeMode = if isText then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = gui,
	})
	strokes[s] = design
	return s
end

-- TEXT -------------------------------------------------------------------------------------

export type TextRole =
	"Display"
	| "Button"
	| "ButtonSmall"
	| "Value"
	| "ValueRun"
	| "Earning"
	| "Label"
	| "Small"
	| "Badge"
	| "Timer"

export type FaceName = "Cash" | "Cars" | "Keys" | "White" | "Heat" | "Danger"

export type TextSpec = {
	text: string,
	role: TextRole,
	name: string?,
	size: number?, -- override TextSize (design px), never below the 16 minimum
	face: FaceName?, -- glyph gradient; default plain white
	colour: Color3?, -- plain fill when no face
	italic: boolean?, -- Nunito Black Italic (numbers, timers, the earning line)
	outline: StrokeRole?, -- default by role (subordinate roles get the minor outline)
	xAlign: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	autoWidth: boolean?, -- AutomaticSize X (numbers that grow rightward)
	z: number?,
}

local ROLE_SIZE: { [string]: number } = {
	Display = A.Text.Display,
	Button = A.Text.Button,
	ButtonSmall = A.Text.ButtonSmall,
	Value = A.Text.Value,
	ValueRun = A.Text.ValueRun,
	Earning = A.Text.Earning,
	Label = A.Text.Label,
	Small = A.Text.Small,
	Badge = A.Text.Badge,
	Timer = A.Text.Label + 4,
}

local ROLE_OUTLINE: { [string]: StrokeRole } = {
	Display = "Major",
	Button = "Major",
	ButtonSmall = "Minor",
	Value = "Major",
	ValueRun = "Major",
	Earning = "Minor",
	Label = "Minor",
	Small = "Minor",
	Badge = "Minor",
	Timer = "Minor",
}

function Arcade.textSize(role: TextRole): number
	return ROLE_SIZE[role]
end

function Arcade.text(parent: Instance, spec: TextSpec): TextLabel
	local size = math.max(spec.size or ROLE_SIZE[spec.role], Tokens.TextSize.Minimum)
	local label = make("TextLabel", {
		Name = spec.name or spec.role,
		BackgroundTransparency = 1,
		Size = if spec.autoWidth then UDim2.fromOffset(0, size + 6) else UDim2.new(1, 0, 0, size + 6),
		AutomaticSize = if spec.autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		FontFace = if spec.italic then PreviewTokens.FontItalicNumber() else Tokens.font(),
		Text = spec.text,
		TextSize = size,
		TextColor3 = if spec.face then Color3.new(1, 1, 1) else (spec.colour or Color3.new(1, 1, 1)),
		TextXAlignment = spec.xAlign or Enum.TextXAlignment.Center,
		TextYAlignment = spec.yAlign or Enum.TextYAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = spec.z or 5,
		Parent = parent,
	})
	-- a little padding so the outline and italic overhang are never clipped by the label box
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, if spec.italic then 6 else 3),
		Parent = label,
	})
	Arcade.outline(label, spec.outline or ROLE_OUTLINE[spec.role])
	if spec.face then
		make("UIGradient", { Color = A.Face[spec.face], Rotation = 90, Parent = label })
	end
	return label
end

-- ICONS ------------------------------------------------------------------------------------

local Icons2: any = nil
do
	local module = script.Parent:FindFirstChild("Icons2")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			Icons2 = result
		else
			warn("[Arcade] Icons2 failed to load: " .. tostring(result))
		end
	end
end

-- Draws icon `name` into `holder` (a square Frame). Returns false when only the neutral
-- missing-icon glyph could be drawn (so a review can count missing art).
function Arcade.icon(holder: Frame, name: string): boolean
	if Icons2 and Icons2.draw then
		local ok, drawn = pcall(Icons2.draw, holder, name)
		if ok and drawn then
			return true
		end
	end
	local ok = pcall(function()
		Icons.draw(holder, name :: any)
	end)
	local art = holder:FindFirstChild("Art")
	if ok and art and #art:GetChildren() > 0 then
		return true
	end
	-- Icons.draw leaves an empty "Art" frame for a name it does not know: replace it
	if art then
		art:Destroy()
	end
	-- neutral missing-icon glyph: a rounded square with a "?" (never an empty hole)
	local box = make("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundColor3 = Color3.fromRGB(230, 236, 246),
		Parent = holder,
	})
	box:SetAttribute("Icon", "Missing")
	Arcade.corner(box, 6)
	Arcade.outline(box, "Minor")
	local q = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Tokens.font(),
		Text = "?",
		TextScaled = true,
		TextColor3 = A.Ink,
		Parent = box,
	})
	local _ = q
	return false
end

-- SURFACE DETAILS --------------------------------------------------------------------------

-- The narrow gloss band at the top of a body: a soft white strip, never over the label's
-- centre line.
function Arcade.gloss(body: GuiObject)
	local g = make("Frame", {
		Name = "Gloss",
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, B.GlossHeight, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = body.ZIndex + 1,
		Parent = body,
	})
	Arcade.corner(g, math.max(B.Radius - 3, 2))
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 0.85),
		}),
		Rotation = 90,
		Parent = g,
	})
end

-- A faint original motif: sparse bolt heads and short tread bars at low contrast (replaces the
-- references' stud tiles; never copied). Large buttons only.
function Arcade.motorPattern(body: GuiObject)
	local holder = make("Frame", {
		Name = "MotorPattern",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = body.ZIndex + 1,
		Parent = body,
	})
	Arcade.corner(holder)
	-- deterministic sparse layout in fractions of the body
	local bolts = { { 0.36, 0.2 }, { 0.62, 0.78 }, { 0.88, 0.24 }, { 0.12, 0.82 } }
	for i, p in bolts do
		local bolt = make("Frame", {
			Name = "Bolt" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(p[1], p[2]),
			Size = UDim2.fromOffset(9, 9),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.86,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
		Arcade.corner(bolt, 5)
		local slot = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.7, 0, 0, 2),
			Rotation = 35 * i,
			BackgroundColor3 = A.Ink,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
			Parent = bolt,
		})
		local _ = slot
	end
	local treads = { { 0.5, 0.12 }, { 0.75, 0.5 }, { 0.24, 0.56 } }
	for i, p in treads do
		for k = 0, 2 do
			local bar = make("Frame", {
				Name = "Tread" .. i .. "_" .. k,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(p[1], k * 7 - 7, p[2], 0),
				Size = UDim2.fromOffset(4, 11),
				Rotation = 20,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.9,
				BorderSizePixel = 0,
				ZIndex = holder.ZIndex,
				Parent = holder,
			})
			Arcade.corner(bar, 2)
		end
	end
end

-- BADGE ------------------------------------------------------------------------------------

export type Badge = {
	frame: Frame,
	set: (value: number | string | nil) -> (),
}

-- A red earned badge pinned outside the top-right corner of `anchor` (a Frame that does NOT
-- scale on press, so the badge never clips or shrinks with the button). Hidden for nil/0.
function Arcade.badge(anchor: GuiObject, value: number | string | nil): Badge
	local d = B.Badge
	local frame = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = A.Badge,
		ZIndex = anchor.ZIndex + 20,
		Parent = anchor,
	})
	Arcade.corner(frame, d)
	Arcade.outline(frame, 2.5)
	local text = Arcade.text(frame, {
		text = "",
		role = "Badge",
		name = "Count",
		z = frame.ZIndex + 1,
	})
	text.Size = UDim2.fromScale(1, 1)
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	local function set(v: number | string | nil)
		if v == nil or v == 0 or v == "" then
			frame.Visible = false
			return
		end
		frame.Visible = true
		local s = if type(v) == "number" then (if v > 9 then "9+" else tostring(math.floor(v))) else v
		text.Text = s
		frame.Size = UDim2.fromOffset(if #s > 1 then d + 10 else d, d)
	end
	set(value)
	return { frame = frame, set = set }
end

-- BUTTON -----------------------------------------------------------------------------------

export type FillName = "Rainbow" | "Garage" | "Missions" | "Settings" | "Retry" | "Home" | "Gold" | "Green"
export type ButtonSize = "Wide" | "Compact" | "Small" | "Custom"

export type ButtonSpec = {
	name: string,
	label: string,
	fill: FillName,
	size: ButtonSize,
	width: number?, -- Custom only (design px)
	height: number?,
	icon: string?, -- Icons2 / Icons name; left of the label, overhanging the edge a little
	pattern: boolean?, -- the faint motor pattern (large buttons only)
	drift: boolean?, -- slow sideways colour drift (Rainbow); stopped in reduced motion
	badge: (number | string)?,
	sound: Sounds.Hook?,
	onActivate: (() -> ())?,
	cooldown: number?, -- seconds a repeat activation is ignored (default 0.35)
	position: UDim2?,
	anchor: Vector2?,
}

export type Button = {
	root: Frame, -- fixed-size holder (never scales; the badge lives here)
	body: TextButton, -- the pressable body (scales on press inside root)
	label: TextLabel,
	iconHolder: Frame?,
	badge: Badge,
	trove: Trove.Trove,
	setEnabled: (boolean) -> (),
	setLabel: (string) -> (),
	setBadge: (number | string | nil) -> (),
	size: Vector2, -- body size in design px
	destroy: () -> (),
}

local function dims(spec: ButtonSpec): Vector2
	if spec.size == "Wide" then
		return Vector2.new(B.WideW, B.WideH)
	elseif spec.size == "Compact" then
		return Vector2.new(B.CompactW, B.CompactH)
	elseif spec.size == "Small" then
		return Vector2.new(B.SmallW, B.SmallH)
	end
	return Vector2.new(spec.width or B.WideW, spec.height or B.WideH)
end

function Arcade.button(parent: Instance, spec: ButtonSpec): Button
	local trove = Trove.new()
	local size = dims(spec)
	local w, h = size.X, size.Y
	local small = spec.size == "Small"
	-- hit box: at least the approved 48 design px tall, even when the visual body is smaller
	local hitH = math.max(h, Tokens.Touch.Minimum)
	local root = trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(w, hitH + B.DepthOffset),
		Position = spec.position or UDim2.new(),
		AnchorPoint = spec.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = parent,
	}))
	-- the pressable surface fills the hit box; the visual body is centred inside it
	local body = make("TextButton", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, hitH / 2),
		Size = UDim2.fromOffset(w, hitH),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Selectable = true,
		Parent = root,
	})
	-- dark lip (shallow depth) under the face
	local lip = make("Frame", {
		Name = "Lip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, B.DepthOffset),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = A.Ink,
		ZIndex = 3,
		Parent = body,
	})
	Arcade.corner(lip)
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		ClipsDescendants = false,
		Parent = body,
	})
	Arcade.corner(face)
	Arcade.outline(face, "Button")
	local grad = make("UIGradient", {
		Color = PreviewTokens.Arcade.Fill[spec.fill],
		Rotation = if spec.fill == "Rainbow" then 0 else 90,
		Parent = face,
	})
	-- rainbow: a soft top-to-bottom shade over the sideways bands so labels keep contrast
	if spec.fill == "Rainbow" then
		local shade = make("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.82,
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
		Arcade.corner(shade)
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.55, 0.55),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
			Rotation = 90,
			Parent = shade,
		})
	end
	if spec.pattern and not small then
		Arcade.motorPattern(face)
	end
	Arcade.gloss(face)

	-- icon (left, slightly overhanging) and label (right, dominant)
	local iconHolder: Frame? = nil
	local labelLeft = 8
	if spec.icon then
		local iconSize = math.floor(h * B.IconScale)
		local holder = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6 - B.IconOverhang, 0.5, -1),
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			ZIndex = face.ZIndex + 4,
			Parent = face,
		})
		Arcade.icon(holder, spec.icon)
		iconHolder = holder
		labelLeft = iconSize + 8 - B.IconOverhang
	end
	local label = Arcade.text(face, {
		text = spec.label,
		role = if small then "ButtonSmall" else "Button",
		name = "Label",
		xAlign = if spec.icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		z = face.ZIndex + 5,
	})
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, labelLeft, 0.5, 0)
	label.Size = UDim2.new(1, -labelLeft - 4, 1, 0)
	-- long labels shrink to fit rather than clip (never below the 16 minimum)
	local maxSize = label.TextSize
	make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = Tokens.TextSize.Minimum, Parent = label })
	label.TextScaled = true

	-- gamepad / keyboard selection ring and desktop hover: a white ring outside the boundary
	local ring = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w + 10, h + 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	Arcade.corner(ring, B.Radius + 5)
	Arcade.outline(ring, 3, Color3.new(1, 1, 1))
	body.SelectionImageObject = ring

	local badge = Arcade.badge(root, spec.badge)
	-- align the badge with the visual body's top-right corner (inside the fixed root)
	badge.frame.Position = UDim2.new(1, -2, 0, (hitH - h) / 2 + 2)

	-- press feedback on the body only (root and badge stay put)
	local press = make("UIScale", { Name = "Press", Parent = body })
	local enabled = true
	local last = -math.huge
	trove:Connect(body.Activated, function()
		local now = os.clock()
		if not enabled or now - last < (spec.cooldown or 0.35) then
			return
		end
		last = now
		Sounds.play(spec.sound or "Tap")
		if spec.onActivate then
			spec.onActivate()
		end
	end)
	local function pressTo(down: boolean)
		if not enabled then
			return
		end
		Motion.tween(press, "press", Motion.info(if down then A.Motion.Press else A.Motion.Release), {
			Scale = if down then 0.95 else 1,
		})
	end
	trove:Connect(body.MouseButton1Down, function()
		pressTo(true)
	end)
	trove:Connect(body.MouseButton1Up, function()
		pressTo(false)
	end)
	trove:Connect(body.MouseLeave, function()
		pressTo(false)
		if GuiService.SelectedObject ~= body then
			ring.Visible = false
		end
	end)
	trove:Connect(body.MouseEnter, function()
		ring.Visible = true
	end)
	trove:Connect(body.SelectionGained, function()
		ring.Visible = true
	end)
	trove:Connect(body.SelectionLost, function()
		ring.Visible = false
	end)

	-- rainbow drift: shifts the gradient offset slowly; paused when hidden or reduced motion
	if spec.drift and spec.fill == "Rainbow" then
		local t = 0
		-- shown only when the root and every GuiObject/ScreenGui above it is visible
		local function onScreen(): boolean
			local node: Instance? = root
			while node do
				if node:IsA("GuiObject") and not node.Visible then
					return false
				elseif node:IsA("LayerCollector") then
					return node.Enabled
				end
				node = node.Parent
			end
			return false
		end
		local check = 0
		local shown = true
		trove:Connect(RunService.Heartbeat, function(dt)
			check -= dt
			if check <= 0 then
				check = 0.25
				shown = onScreen()
			end
			if Motion.reduced() or not shown then
				if grad.Offset ~= Vector2.zero and Motion.reduced() then
					grad.Offset = Vector2.zero
				end
				return
			end
			t = (t + dt / A.Motion.RainbowDriftSeconds) % 1
			-- a gentle back-and-forth (never a flash): offset within ±0.12
			grad.Offset = Vector2.new(math.sin(t * math.pi * 2) * 0.12, 0)
		end)
	end

	trove:Add(function()
		Motion.cancelAll(press)
		if GuiService.SelectedObject == body then
			GuiService.SelectedObject = nil
		end
	end)

	local function setEnabled(on: boolean)
		enabled = on
		body.Active = on
		body.Selectable = on
		grad.Color = if on then PreviewTokens.Arcade.Fill[spec.fill] else PreviewTokens.Arcade.Fill.Disabled
		label.TextTransparency = if on then 0 else 0.25
		if not on then
			press.Scale = 1
		end
	end

	return {
		root = root,
		body = body,
		label = label,
		iconHolder = iconHolder,
		badge = badge,
		trove = trove,
		setEnabled = setEnabled,
		setLabel = function(text: string)
			label.Text = text
		end,
		setBadge = badge.set,
		size = size,
		destroy = function()
			trove:Destroy()
		end,
	}
end

-- TOGGLE -----------------------------------------------------------------------------------

export type ToggleSpec = {
	name: string,
	label: string,
	value: boolean,
	onChanged: (boolean) -> (),
	position: UDim2?,
	anchor: Vector2?,
}

export type Toggle = {
	root: Frame,
	set: (boolean) -> (),
	get: () -> boolean,
	trove: Trove.Trove,
	destroy: () -> (),
}

-- A wide switch with a sliding knob, the label outside to the right, and ON/OFF text inside
-- the track (state is never colour alone).
function Arcade.toggle(parent: Instance, spec: ToggleSpec): Toggle
	local trove = Trove.new()
	local trackW, trackH = 92, 40
	local root = trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(trackW + 150, math.max(trackH, Tokens.Touch.Minimum)),
		Position = spec.position or UDim2.new(),
		AnchorPoint = spec.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		Parent = parent,
	}))
	local hit = make("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		Parent = root,
	})
	local track = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(trackW, trackH),
		BackgroundColor3 = Color3.fromRGB(120, 86, 60),
		ZIndex = 3,
		Parent = root,
	})
	Arcade.corner(track, 8)
	Arcade.outline(track, "Button")
	local state = make("TextLabel", {
		Name = "State",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.55, 1),
		FontFace = Tokens.font(),
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = track,
	})
	Arcade.outline(state, "Minor")
	local knob = make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(36, trackH - 8),
		BackgroundColor3 = Color3.fromRGB(70, 230, 70),
		ZIndex = 5,
		Parent = track,
	})
	Arcade.corner(knob, 6)
	Arcade.outline(knob, "Minor")
	make("UIGradient", {
		Color = PreviewTokens.Arcade.Fill.Green,
		Rotation = 90,
		Parent = knob,
	})
	local label = Arcade.text(root, {
		text = spec.label,
		role = "Label",
		name = "Label",
		size = 22,
		xAlign = Enum.TextXAlignment.Left,
	})
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, trackW + 10, 0.5, 0)
	label.Size = UDim2.new(1, -trackW - 10, 0, 30)

	local value = spec.value
	local function render(animate: boolean)
		local goal = if value then UDim2.new(1, -40, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
		if animate and not Motion.reduced() then
			Motion.tween(knob, "slide", Motion.info(0.14), { Position = goal })
		else
			knob.Position = goal
		end
		track.BackgroundColor3 = if value then Color3.fromRGB(46, 120, 60) else Color3.fromRGB(110, 92, 80)
		state.Text = if value then "ON" else "OFF"
		state.Position = if value then UDim2.fromScale(0.04, 0) else UDim2.fromScale(0.42, 0)
		knob.BackgroundColor3 = if value then Color3.fromRGB(70, 230, 70) else Color3.fromRGB(200, 205, 215)
		local g = knob:FindFirstChildOfClass("UIGradient")
		if g then
			g.Enabled = value
		end
	end
	render(false)
	trove:Connect(hit.Activated, function()
		value = not value
		Sounds.play("Tap")
		render(true)
		spec.onChanged(value)
	end)
	trove:Add(function()
		Motion.cancelAll(knob)
	end)
	return {
		root = root,
		set = function(v: boolean)
			value = v
			render(false)
		end,
		get = function()
			return value
		end,
		trove = trove,
		destroy = function()
			trove:Destroy()
		end,
	}
end

return Arcade
