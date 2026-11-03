--!strict
-- Home/HomeButton: the two button shapes of the Round 2 Home HUD (Lane 3, N7-01 and N7-03a, 2026-11-02), built from the
-- Arcade kit's own pieces (Arcade.corner / outline / gloss / text / badge, the kit fills, the kit press feel) so they read
-- as one family with the rest of the HUD.
--
--   HomeButton.square(parent, spec) -> Button
--     A labelled tile like IMG-09's Shop / Garage / Missions: a thick dark boundary, a strong gradient fill, a narrow gloss
--     band, a shallow lip. style "Stack" draws the icon over the label; "Row" draws the icon beside the label (the phone
--     rows, 48 px tall = the touch minimum). Fill "Rainbow" with drift = true keeps the Shop's slow sideways colour cycle
--     (the same seamless two-period field as Arcade.button: it stops in reduced motion and pauses while hidden).
--   HomeButton.round(parent, spec) -> Button
--     A round icon button for the right-hand column: a coloured disc, the icon, an optional label under it. The hit box is
--     the disc plus its label, never smaller than the 48 px touch minimum.
--
-- Both: the badge is a red "!" or count pinned outside the top-right corner of a FIXED root (a press never shrinks or clips
-- it) and appears only for a state the caller says is real; a press scales the body 0.95 over 0.08 s (the kit's feel) and
-- plays the "Tap" sound through the UI SoundGroup; a repeat activation within 0.35 s is ignored; gamepad and keyboard focus
-- show the kit's white selection ring. Nothing here decides anything: it calls onActivate and nothing else.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local IconArt = require(script.Parent.IconArt)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local B = A.Button
local make = Arcade.make

local HomeButton = {}

local LABEL_H = 22 -- the label strip of a stacked tile
local ROUND_LABEL_H = 22

export type SquareSpec = {
	name: string,
	label: string,
	fill: Arcade.FillName,
	icons: { string }, -- painter names to try in order (GameIcons art first, then the older painters)
	style: "Stack" | "Row",
	w: number,
	h: number,
	drift: boolean?, -- Rainbow only
	badge: (number | string)?,
	onActivate: (() -> ())?,
	sound: Sounds.Hook?,
}

export type RoundSpec = {
	name: string,
	label: string?,
	fill: Arcade.FillName,
	icons: { string },
	glyph: string?, -- text drawn in place of the icon (the overflow "...")
	d: number, -- the disc's diameter
	colW: number, -- the hit box width (wider than the disc when a label sits under it)
	badge: (number | string)?,
	onActivate: (() -> ())?,
	sound: Sounds.Hook?,
}

export type Button = {
	root: Frame, -- fixed holder: placement, size and the badge live here
	body: TextButton,
	label: TextLabel?,
	iconHolder: Frame?,
	badge: Arcade.Badge,
	size: Vector2, -- the root's design size
	trove: Trove.Trove,
	setBadge: (value: (number | string)?) -> (),
	setEnabled: (on: boolean) -> (),
	setIcons: (names: { string }) -> (),
	destroy: () -> (),
}

-- A white selection ring outside the boundary, shown on hover and gamepad / keyboard focus.
local function attachInteraction(trove: Trove.Trove, body: TextButton, ring: GuiObject, press: UIScale, spec: any)
	local enabled = true
	local last = -math.huge
	trove:Connect(body.Activated, function()
		local now = os.clock()
		if not enabled or now - last < 0.35 then
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
	trove:Add(function()
		Motion.cancelAll(press)
		if GuiService.SelectedObject == body then
			GuiService.SelectedObject = nil
		end
	end)
	return function(on: boolean)
		enabled = on
		body.Active = on
		body.Selectable = on
		if not on then
			press.Scale = 1
		end
	end
end

-- The Shop's rainbow: a field two widths wide whose gradient is two identical periods, slid left by exactly one width per
-- cycle (seamless). Frozen at its resting state in reduced motion, and paused while the button is not on screen.
local function attachRainbow(trove: Trove.Trove, root: Frame, face: Frame)
	local group = make("CanvasGroup", {
		Name = "RainbowField",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = face.ZIndex,
		Parent = face,
	})
	Arcade.corner(group)
	local bands = make("Frame", {
		Name = "Bands",
		Size = UDim2.fromScale(2, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = face.ZIndex,
		Parent = group,
	})
	make("UIGradient", { Color = Arcade.loopSequence(A.Fill.Rainbow, 2), Rotation = 0, Parent = bands })
	-- a soft top-to-bottom shade over the sideways bands so the label keeps its contrast
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
	local phase = 0
	local check = 0
	local shown = true
	local function onScreen(): boolean
		local node: Instance? = root
		while node do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			elseif node:IsA("LayerCollector") then
				return (node :: any).Enabled
			end
			node = node.Parent
		end
		return false
	end
	trove:Connect(RunService.Heartbeat, function(dt: number)
		check -= dt
		if check <= 0 then
			check = 0.25
			shown = onScreen()
		end
		if Motion.reduced() then
			if phase ~= 0 then
				phase = 0
				bands.Position = UDim2.fromScale(0, 0)
			end
			return
		end
		if not shown then
			return
		end
		phase = (phase + dt / A.Motion.RainbowDriftSeconds) % 1
		bands.Position = UDim2.fromScale(-phase, 0)
	end)
end

local function ringFor(body: TextButton, w: number, h: number, radius: number): Frame
	local ring = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w + 10, h + 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	Arcade.corner(ring, radius)
	Arcade.outline(ring, 3, Color3.new(1, 1, 1))
	body.SelectionImageObject = ring
	return ring
end

function HomeButton.square(parent: Instance, spec: SquareSpec): Button
	local trove = Trove.new()
	local w, h = spec.w, spec.h
	local hitH = math.max(h, Tokens.Touch.Minimum)
	local root = trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(w, hitH + B.DepthOffset),
		BackgroundTransparency = 1,
		Parent = parent,
	}))
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
	local lip = make("Frame", {
		Name = "Lip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, B.DepthOffset),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = A.Ink,
		ZIndex = 3,
		Parent = body,
	})
	Arcade.corner(lip, 8)
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = body,
	})
	Arcade.corner(face, 8)
	Arcade.outline(face, "Button")
	local isRainbow = spec.fill == "Rainbow"
	make("UIGradient", { Color = A.Fill[spec.fill], Rotation = if isRainbow then 0 else 90, Parent = face })
	if isRainbow and spec.drift then
		attachRainbow(trove, root, face)
	end
	Arcade.gloss(face)

	-- icon and label: over each other (Stack) or side by side (Row)
	local stack = spec.style == "Stack"
	local iconSize = if stack then math.max(24, math.min(w - 28, h - LABEL_H - 12)) else math.floor(h * 0.7)
	local holder = make("Frame", {
		Name = "Icon",
		AnchorPoint = if stack then Vector2.new(0.5, 0) else Vector2.new(0, 0.5),
		Position = if stack then UDim2.new(0.5, 0, 0, 5) else UDim2.new(0, 6, 0.5, -1),
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		ZIndex = face.ZIndex + 4,
		Parent = face,
	})
	IconArt.draw(holder, spec.icons)
	local label = Arcade.text(face, {
		text = spec.label,
		role = "Button",
		name = "Label",
		size = if stack then 20 else 22,
		xAlign = if stack then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		z = face.ZIndex + 5,
	})
	if stack then
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -3)
		label.Size = UDim2.new(1, -8, 0, LABEL_H)
	else
		local left = iconSize + 12
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(0, left, 0.5, 0)
		label.Size = UDim2.new(1, -left - 4, 0, h - 8)
	end
	-- a long label shrinks to fit rather than clipping, never below the 16 px minimum
	local maxSize = label.TextSize
	make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = Tokens.TextSize.Minimum, Parent = label })
	label.TextScaled = true

	local ring = ringFor(body, w, h, 11)
	local badge = Arcade.badge(root, spec.badge)
	badge.frame.Position = UDim2.new(1, -2, 0, (hitH - h) / 2 + 2)
	local press = make("UIScale", { Name = "Press", Parent = body })
	local setEnabled = attachInteraction(trove, body, ring, press, spec)

	return {
		root = root,
		body = body,
		label = label,
		iconHolder = holder,
		badge = badge,
		size = Vector2.new(w, hitH + B.DepthOffset),
		trove = trove,
		setBadge = badge.set,
		setEnabled = setEnabled,
		setIcons = function(names: { string })
			IconArt.draw(holder, names)
		end,
		destroy = function()
			trove:Destroy()
		end,
	}
end

function HomeButton.round(parent: Instance, spec: RoundSpec): Button
	local trove = Trove.new()
	local d = spec.d
	local labelH = if spec.label then ROUND_LABEL_H else 0
	local colW = math.max(spec.colW, d)
	local hitH = d + (if labelH > 0 then labelH + 2 else 0)
	local root = trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(colW, hitH + B.DepthOffset),
		BackgroundTransparency = 1,
		Parent = parent,
	}))
	local body = make("TextButton", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(colW, hitH),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Selectable = true,
		Parent = root,
	})
	local lip = make("Frame", {
		Name = "Lip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, B.DepthOffset),
		Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = A.Ink,
		ZIndex = 3,
		Parent = body,
	})
	Arcade.corner(lip, d)
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = body,
	})
	Arcade.corner(face, d)
	Arcade.outline(face, "Button")
	make("UIGradient", { Color = A.Fill[spec.fill], Rotation = 90, Parent = face })
	Arcade.gloss(face)
	local holder = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.floor(d * 0.66), math.floor(d * 0.66)),
		BackgroundTransparency = 1,
		ZIndex = face.ZIndex + 4,
		Parent = face,
	})
	if spec.glyph then
		local g = Arcade.text(holder, {
			text = spec.glyph,
			role = "Button",
			name = "Glyph",
			size = 28,
			z = face.ZIndex + 5,
		})
		g.Size = UDim2.fromScale(1, 1)
	else
		IconArt.draw(holder, spec.icons)
	end
	local label: TextLabel? = nil
	if spec.label then
		local text = Arcade.text(body, {
			text = spec.label,
			role = "Label",
			name = "Label",
			size = Tokens.TextSize.Minimum,
			z = face.ZIndex + 5,
		})
		text.AnchorPoint = Vector2.new(0.5, 0)
		text.Position = UDim2.new(0.5, 0, 0, d + 2)
		text.Size = UDim2.fromOffset(colW, ROUND_LABEL_H)
		label = text
	end
	-- the ring hugs the disc
	local ring = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(d + 10, d + 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	ring.Position = UDim2.new(0.5, 0, 0, -5)
	Arcade.corner(ring, d + 10)
	Arcade.outline(ring, 3, Color3.new(1, 1, 1))
	body.SelectionImageObject = ring
	local badge = Arcade.badge(root, spec.badge)
	-- the badge pins to the disc's top-right, not the (wider) hit box
	badge.frame.Position = UDim2.new(0.5, d / 2 - 4, 0, 4)
	local press = make("UIScale", { Name = "Press", Parent = face })
	local setEnabled = attachInteraction(trove, body, ring, press, spec)

	return {
		root = root,
		body = body,
		label = label,
		iconHolder = holder,
		badge = badge,
		size = Vector2.new(colW, hitH + B.DepthOffset),
		trove = trove,
		setBadge = badge.set,
		setEnabled = setEnabled,
		setIcons = function(names: { string })
			if not spec.glyph then
				IconArt.draw(holder, names)
			end
		end,
		destroy = function()
			trove:Destroy()
		end,
	}
end

return HomeButton
