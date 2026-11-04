--!strict
-- PanelKit: the one panel look for Settings, Missions, the portal card, the group pop-up and the card detail (Lane 3,
-- Round 2 N7-02; PREVIEW). A white or light card with the kit's thick dark boundary and hard lip, a bold coloured header
-- with an icon and an outlined title (Style.header), rows with icons, green ON / OFF switches and a red square X.
-- Built on Style and the Arcade kit; it adds only what the dark Style panels do not have: the light card fill, light
-- rows, ink text (no outline, navy on light), a light tab and a green switch.
--
--   PanelKit.panel(parent, { name, z }) -> Style.Panel            -- the light card (root, body, lip)
--   PanelKit.row(parent, name, z?, tone?) -> Frame                -- a light inset row with a thin blue edge
--   PanelKit.ink(label, soft?) -> label                           -- navy text, outline removed (a label made for dark panels)
--   PanelKit.tab(parent, spec) -> Style.Tab                       -- selected = bright fill + white outlined word
--   PanelKit.toggle(parent, spec) -> Arcade.Toggle                -- the kit switch, green when ON, same children and API
--   PanelKit.closeX(parent, onActivate) -> SupportKit.CloseX      -- the square red X (48 px)
--   PanelKit.interact(button, trove, radius, ringColour?)         -- hover ring, press squash and gamepad ring for a custom button
--
-- Text on a light card is navy (the approved Ink role, 22/36/63) with no outline; text on a coloured fill (a header, a
-- button, a chosen tab) stays white with the dark outline. Touch targets are 48 design px or more after UIScale. Hover,
-- press and gamepad selection are on every control here; Reduced Motion (Motion.reduced) removes the press and slide tweens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local PanelKit = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TOKEN CANDIDATES (Round 2): the light card family.
PanelKit.CardTop = rgb(255, 255, 255)
PanelKit.CardBottom = rgb(222, 235, 255)
PanelKit.RowFill = rgb(231, 241, 255)
PanelKit.RowFillAlt = rgb(247, 251, 255)
PanelKit.RowEdge = rgb(132, 162, 214)
PanelKit.Ink = PreviewTokens.Color.Ink -- navy text on light
PanelKit.InkSoft = rgb(66, 84, 124)
PanelKit.Warm = rgb(176, 98, 0) -- a small accent word on light (NEXT, a harness caption)
PanelKit.Good = rgb(26, 138, 62) -- a good-news word on light (DONE, COMPLETE)
PanelKit.TabOff = rgb(214, 226, 247)
PanelKit.SwitchOff = rgb(150, 160, 182)

-- The light card: Style.panel with a white to pale-blue body.
function PanelKit.panel(parent: Instance, spec: { name: string?, z: number? }): Style.Panel
	return Style.panel(parent, {
		name = spec.name,
		z = spec.z,
		top = PanelKit.CardTop,
		bottom = PanelKit.CardBottom,
	})
end

-- A light inset row (a mission, a requirement, a setting). `tone` "Alt" is the paler stripe.
function PanelKit.row(parent: Instance, name: string, z: number?, tone: string?): Frame
	local f: Frame = make("Frame", {
		Name = name,
		BackgroundColor3 = if tone == "Alt" then PanelKit.RowFillAlt else PanelKit.RowFill,
		BorderSizePixel = 0,
		ZIndex = z or 5,
		Parent = parent,
	})
	Arcade.corner(f, 8)
	Arcade.outline(f, "Minor", PanelKit.RowEdge)
	return f
end

-- Turns a label made for a dark panel (white, outlined) into navy text with no outline.
function PanelKit.ink(label: TextLabel, soft: boolean?): TextLabel
	label.TextColor3 = if soft then PanelKit.InkSoft else PanelKit.Ink
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	return label
end

function PanelKit.closeX(parent: Instance, onActivate: () -> ()): SupportKit.CloseX
	local x = SupportKit.closeX(parent, onActivate)
	-- the kit's outline sits on a TextButton, where the default stroke mode draws round the (empty) text: draw it round the edge
	local stroke = x.root:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	return x
end

-- Hover ring, press squash and gamepad ring for a custom button. The squash goes on a UIScale named "Press" and rests in
-- Reduced Motion; the ring is drawn outside the button (navy on a light surface, or pass a white `ringColour` on a dark one).
local function interact(button: TextButton, trove: Trove.Trove, radius: number, ringColour: Color3?)
	local ring: Frame = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = button,
	})
	Arcade.corner(ring, radius + 5)
	Arcade.outline(ring, 3, ringColour or PanelKit.Ink)
	button.SelectionImageObject = ring
	local press: UIScale = make("UIScale", { Name = "Press", Parent = button })
	local function squash(down: boolean)
		if Motion.reduced() then
			press.Scale = 1
			return
		end
		Motion.tween(press, "press", Motion.info(if down then A.Motion.Press else A.Motion.Release), {
			Scale = if down then 0.95 else 1,
		})
	end
	trove:Connect(button.MouseButton1Down, function()
		squash(true)
	end)
	trove:Connect(button.MouseButton1Up, function()
		squash(false)
	end)
	trove:Connect(button.MouseLeave, function()
		squash(false)
		ring.Visible = false
	end)
	trove:Connect(button.MouseEnter, function()
		ring.Visible = true
	end)
	trove:Connect(button.SelectionGained, function()
		ring.Visible = true
	end)
	trove:Connect(button.SelectionLost, function()
		ring.Visible = false
	end)
	trove:Add(function()
		Motion.cancelAll(press)
	end)
end
PanelKit.interact = interact

-- A light tab: not selected = a pale blue chip with a navy word; selected = the Garage fill, a thicker boundary, a gloss band
-- and a white outlined word (state is never colour alone: the boundary and the gloss change too). 48 px tall by default.
function PanelKit.tab(parent: Instance, spec: Style.TabSpec): Style.Tab
	local trove = Trove.new()
	local z = spec.z or 6
	local root: TextButton = trove:Add(make("TextButton", {
		Name = spec.name,
		Size = UDim2.fromOffset(160, Tokens.Touch.Minimum),
		BackgroundColor3 = PanelKit.TabOff,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = z,
		Parent = parent,
	}))
	Arcade.corner(root, A.Button.Radius + 2)
	local stroke = Arcade.outline(root, "Minor")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- round the tab's edge, not round its (empty) text
	local grad: UIGradient = make("UIGradient", {
		Color = A.Fill.Garage,
		Rotation = 90,
		Enabled = false,
		Parent = root,
	})
	local gloss: Frame = make("Frame", {
		Name = "Gloss",
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, A.Button.GlossHeight, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = z + 1,
		Parent = root,
	})
	Arcade.corner(gloss, 4)
	local label =
		Style.text(root, spec.label, "Label", { name = "Label", xAlign = Enum.TextXAlignment.Center, z = z + 2 })
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -12, 0, A.Text.Label + 6)
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
	interact(root, trove, A.Button.Radius + 2)
	local last = -math.huge
	trove:Connect(root.Activated, function()
		local now = os.clock()
		if now - last < 0.2 then
			return
		end
		last = now
		Sounds.play("Tap")
		spec.onActivate()
	end)
	local function set(on: boolean)
		grad.Enabled = on
		gloss.Visible = on
		root.BackgroundColor3 = if on then Color3.new(1, 1, 1) else PanelKit.TabOff
		stroke.Thickness = if on then A.OutlineButton else A.OutlineMinor
		label.TextColor3 = if on then Color3.new(1, 1, 1) else PanelKit.Ink
		if labelStroke then
			labelStroke.Enabled = on
		end
	end
	set(false)
	return {
		root = root,
		label = label,
		set = set,
		setText = function(text: string)
			label.Text = text
		end,
		trove = trove,
	}
end

-- The kit switch in the light family. Same children as Arcade.toggle (Hit, Track > State + Knob, Label) and the same knob
-- positions (ON: scale 1, offset -40; OFF: scale 0, offset 4), so a harness reads it the same way; the track is green when
-- ON and grey when OFF, the knob is white, the word ON / OFF is inside the track and the line beside it is navy text.
function PanelKit.toggle(parent: Instance, spec: Arcade.ToggleSpec): Arcade.Toggle
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
	local hit: TextButton = make("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		Parent = root,
	})
	local track: Frame = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(trackW, trackH),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = root,
	})
	Arcade.corner(track, 10)
	Arcade.outline(track, "Button")
	local fill: UIGradient = make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = track })
	local state: TextLabel = make("TextLabel", {
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
	local knob: Frame = make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(36, trackH - 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = track,
	})
	Arcade.corner(knob, 7)
	Arcade.outline(knob, "Minor")
	local label = Arcade.text(root, {
		text = spec.label,
		role = "Label",
		name = "Label",
		size = 18,
		xAlign = Enum.TextXAlignment.Left,
	})
	PanelKit.ink(label)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, trackW + 10, 0.5, 0)
	label.Size = UDim2.new(1, -trackW - 10, 0, 30)

	local value = spec.value
	local function render(animate: boolean)
		local goal = if value then UDim2.new(1, -40, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
		if animate and not Motion.reduced() then
			Motion.tween(knob, "slide", Motion.info(0.14), { Position = goal })
		else
			Motion.cancelAll(knob)
			knob.Position = goal
		end
		track.BackgroundColor3 = if value then Color3.new(1, 1, 1) else PanelKit.SwitchOff
		fill.Enabled = value
		state.Text = if value then "ON" else "OFF"
		state.Position = if value then UDim2.fromScale(0.04, 0) else UDim2.fromScale(0.42, 0)
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

return PanelKit
