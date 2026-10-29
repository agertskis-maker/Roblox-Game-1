--!strict
-- Shared building blocks for the HUD prototype's glossy look (Lane 3 preview): one consistent
-- rounded shape, a dark outline, a short downward shadow and a restrained top-left highlight,
-- used only on major controls (buttons, Cash, cards, celebrations). Secondary text uses
-- Gloss.label (clean, no gradient).
--
--   Gloss.make(class, props)                        -- props may include Parent and Children
--   Gloss.panel(parent, { size, position, anchor, name, colour? }) -> Frame
--   Gloss.button(parent, spec) -> Button             -- see ButtonSpec; handles press / hover /
--                                                       gamepad selection / debounce
--   Gloss.title(parent, text, size, light, deep?)   -> TextLabel (outlined headline / number)
--   Gloss.label(parent, text, size, colour?)        -> TextLabel (plain readable text)
--   Gloss.badge(parent, count)                      -> Frame (hidden at 0; "9+" past 9)

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Motion = require(script.Parent.Motion)
local PreviewTokens = require(script.Parent.PreviewTokens)
local Sounds = require(script.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Gloss = {}

local C = PreviewTokens.Color
local S = PreviewTokens.Size

function Gloss.make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	local children = props.Children
	for key, value in props do
		if key ~= "Parent" and key ~= "Children" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = parent
	return instance
end
local make = Gloss.make

function Gloss.corner(parent: Instance, radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or S.Corner), Parent = parent })
end

function Gloss.stroke(parent: Instance, thickness: number?, colour: Color3?, mode: Enum.ApplyStrokeMode?): UIStroke
	return make("UIStroke", {
		Thickness = thickness or S.Outline,
		Color = colour or C.Ink,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Gloss.gradient(parent: Instance, light: Color3, deep: Color3, rotation: number?): UIGradient
	return make("UIGradient", {
		Color = ColorSequence.new(light, deep),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

-- A soft downward shadow: a same-shaped navy frame under `body`, offset down.
function Gloss.shadow(body: GuiObject, radius: number?, offset: number?): Frame
	local s = make("Frame", {
		Name = "Shadow",
		AnchorPoint = body.AnchorPoint,
		Position = body.Position + UDim2.fromOffset(0, offset or S.ShadowOffset),
		Size = body.Size,
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = math.max(body.ZIndex - 1, 0),
		Parent = body.Parent,
	})
	Gloss.corner(s, radius)
	return s
end

-- The restrained top-left highlight inside a glossy body.
function Gloss.highlight(body: GuiObject, radius: number?)
	local h = make("Frame", {
		Name = "Highlight",
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0.42, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = body.ZIndex + 1,
		Parent = body,
	})
	Gloss.corner(h, math.max((radius or S.Corner) - 4, 2))
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 60,
		Parent = h,
	})
end

export type PanelSpec = {
	name: string?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	colour: Color3?,
	radius: number?,
	z: number?,
	shadow: boolean?,
}

function Gloss.panel(parent: Instance, spec: PanelSpec): Frame
	local f = make("Frame", {
		Name = spec.name or "Panel",
		Size = spec.size,
		Position = spec.position or UDim2.new(),
		AnchorPoint = spec.anchor or Vector2.zero,
		BackgroundColor3 = spec.colour or C.Panel,
		BorderSizePixel = 0,
		ZIndex = spec.z or 2,
		Parent = parent,
	})
	Gloss.corner(f, spec.radius)
	Gloss.stroke(f)
	if spec.shadow ~= false then
		Gloss.shadow(f, spec.radius)
	end
	return f
end

function Gloss.title(parent: Instance, text: string, size: number, light: Color3?, deep: Color3?): TextLabel
	local t = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size + 8),
		FontFace = Tokens.font(),
		Text = text,
		TextSize = size,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	Gloss.stroke(t, math.clamp(math.floor(size / 12), 2, 4), C.Ink, Enum.ApplyStrokeMode.Contextual)
	if light then
		Gloss.gradient(t, light, deep or light)
	end
	return t
end

function Gloss.label(parent: Instance, text: string, size: number, colour: Color3?): TextLabel
	return make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size + 4),
		FontFace = Tokens.font(),
		Text = text,
		TextSize = math.max(size, Tokens.TextSize.Minimum),
		TextColor3 = colour or C.Ink,
		Parent = parent,
	})
end

function Gloss.badge(parent: GuiObject, count: number): Frame
	local b = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = C.Badge,
		ZIndex = parent.ZIndex + 5,
		Parent = parent,
	})
	Gloss.corner(b, 13)
	Gloss.stroke(b, 2.5)
	local t = make("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Tokens.font(),
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = b.ZIndex + 1,
		Parent = b,
	})
	Gloss.setBadge(b, count)
	local _ = t
	return b
end

function Gloss.setBadge(b: Frame, count: number)
	local t = b:FindFirstChild("Count") :: TextLabel
	b.Visible = count > 0
	t.Text = if count > 9 then "9+" else tostring(count)
	b.Size = UDim2.fromOffset(if count > 9 then 34 else 26, 26)
end

export type ButtonSpec = {
	name: string,
	size: Vector2, -- body size in design px (the hit box is the whole body, at least TouchMin)
	position: UDim2?,
	anchor: Vector2?,
	light: Color3,
	deep: Color3,
	text: string?,
	textSize: number?,
	radius: number?,
	icon: ((parent: Frame) -> ())?, -- draws an original icon into the given holder
	iconSize: number?,
	sound: Sounds.Hook?,
	onActivate: (() -> ())?,
	cooldown: number?, -- seconds a repeat activation is ignored (default 0.35)
}

export type Button = {
	root: Frame, -- holds shadow + body
	body: TextButton,
	label: TextLabel?,
	iconHolder: Frame?,
	trove: Trove.Trove,
	setEnabled: (boolean) -> (),
}

function Gloss.button(parent: Instance, spec: ButtonSpec): Button
	local trove = Trove.new()
	local w = math.max(spec.size.X, S.TouchMin)
	local h = math.max(spec.size.Y, S.TouchMin)
	local root = trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(w, h + S.ShadowOffset),
		Position = spec.position or UDim2.new(),
		AnchorPoint = spec.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		Parent = parent,
	}))
	local body = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Selectable = true,
		Parent = root,
	})
	Gloss.corner(body, spec.radius)
	Gloss.stroke(body)
	local grad = Gloss.gradient(body, spec.light, spec.deep)
	Gloss.highlight(body, spec.radius)
	Gloss.shadow(body, spec.radius)
	-- gamepad / keyboard selection ring (same look as hover)
	local ring = make("Frame", {
		Name = "SelectionRing",
		Size = UDim2.new(1, 10, 1, 10),
		Position = UDim2.fromOffset(-5, -5),
		BackgroundTransparency = 1,
		Parent = body,
	})
	Gloss.corner(ring, (spec.radius or S.Corner) + 5)
	Gloss.stroke(ring, 3, Color3.new(1, 1, 1))
	body.SelectionImageObject = ring
	ring.Visible = false
	local iconHolder: Frame? = nil
	if spec.icon then
		local size = spec.iconSize or math.floor(math.min(w, h) * 0.62)
		local holder = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = if spec.text then UDim2.fromScale(0.5, 0.42) else UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = body,
		})
		spec.icon(holder)
		iconHolder = holder
	end
	local label: TextLabel? = nil
	if spec.text then
		local ts = spec.textSize or Tokens.TextSize.Minimum
		local l = make("TextLabel", {
			Name = "Text",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = if spec.icon then UDim2.new(0.5, 0, 1, -2) else UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 0, ts + 6),
			BackgroundTransparency = 1,
			FontFace = Tokens.font(),
			Text = spec.text,
			TextSize = ts,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = false,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 6,
			Parent = body,
		})
		if not spec.icon then
			l.AnchorPoint = Vector2.new(0.5, 0.5)
		end
		Gloss.stroke(l, 2.5, C.Ink, Enum.ApplyStrokeMode.Contextual)
		label = l
	end
	local enabled = true
	local last = -math.huge
	trove:Connect(body.Activated, function()
		local now = os.clock()
		if not enabled or now - last < (spec.cooldown or 0.35) then
			return
		end
		last = now
		Sounds.play(spec.sound or "Tap")
		Motion.pop(body, 1.06)
		if spec.onActivate then
			spec.onActivate()
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
		ring.Visible = false
	end)
	-- hover is a desktop-only enhancement: the same ring a gamepad selection shows
	trove:Connect(body.MouseEnter, function()
		ring.Visible = true
	end)
	trove:Connect(body.SelectionGained, function()
		ring.Visible = true
	end)
	trove:Connect(body.SelectionLost, function()
		ring.Visible = false
	end)
	trove:Add(function()
		Motion.cancelAll(body)
		if GuiService.SelectedObject == body then
			GuiService.SelectedObject = nil
		end
	end)
	local function setEnabled(on: boolean)
		enabled = on
		body.Active = on
		grad.Color = if on
			then ColorSequence.new(spec.light, spec.deep)
			else ColorSequence.new(Tokens.toGrey(spec.light), Tokens.toGrey(spec.deep))
	end
	return { root = root, body = body, label = label, iconHolder = iconHolder, trove = trove, setEnabled = setEnabled }
end

return Gloss
