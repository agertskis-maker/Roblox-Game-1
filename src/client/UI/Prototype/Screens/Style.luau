--!strict
-- Style: the arcade family for the prototype's full screens and their cards (Lane 3 HUD rebuild,
-- PREVIEW only; vault/design/specs/hud-rebuild-worker-guide.md). Built on the lead's kit
-- (Prototype/Arcade.luau) so screens share its outlines, fills and outlined text; this file only
-- adds what a screen needs and the kit does not have: a deep panel with a hard dark lip, a
-- coloured header band, dark inset wells, tabs and a styled scroll frame.
--
-- No pale-cream dashboard: panels are deep navy with a thick near-black boundary and limited
-- rounding, text is white with a dark outline, and colour comes from the kit fills.
--
--   local shell = Style.panel(parent, { name = "Panel", z = 3 })  -- { root, body, lip }
--   Style.header(shell.body, { fill = "Garage", title = "GARAGE", icon = "Garage" })
--   Style.well(parent, "Row", z)                -- a dark inset row with a dark outline
--   Style.plate(parent, "Row", z, fill?)        -- a bright arcade plate (kit fill, one outline, gloss)
--   Style.chip(parent, "Chip", z)                -- a small floating HUD chip (Stunt)
--   Style.text(parent, text, role, opts?)        -- kit text, left aligned, shrinks to fit (>= 16)
--   Style.paragraph(parent, text, size?, soft?)  -- wrapped outlined copy that grows downward
--   Style.tab(parent, { name, label, onActivate }) -- a selectable tab (selected = Garage fill)
--   Style.scroll(parent, name, z)                -- a vertical ScrollingFrame, styled bar
--   Style.stamp(parent, text, fill, z)           -- a small tilted kit stamp (NEW BEST!, SECURED)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local Style = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TOKEN CANDIDATE: screen panel body gradient (deep navy, top -> bottom).
Style.PanelTop = rgb(66, 124, 226)
-- TOKEN CANDIDATE
Style.PanelBottom = rgb(34, 70, 168)
-- TOKEN CANDIDATE: inset wells (rows, grid holder, detail pane) inside a panel.
Style.Well = rgb(20, 38, 96)
-- TOKEN CANDIDATE (Round 3): the bright plate fill for rows inside a panel (top -> bottom; the middle is 40, 110, 235).
Style.PlateFill = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(86, 160, 255)),
	ColorSequenceKeypoint.new(0.5, rgb(40, 110, 235)),
	ColorSequenceKeypoint.new(1, rgb(22, 72, 190)),
})
-- TOKEN CANDIDATE: well transparency (the panel gradient shows through a little).
Style.WellTransparency = 0.2
-- TOKEN CANDIDATE: subordinate text colour on the dark panel (still outlined).
Style.TextSoft = rgb(226, 238, 255)
-- TOKEN CANDIDATE: panel corner radius (limited rounding, like the kit's 7 on buttons).
Style.Radius = 10
-- TOKEN CANDIDATE: panel lip depth (hard dark offset, no soft shadow).
Style.Lip = 5
-- TOKEN CANDIDATE: header band height (wide / short screens).
Style.HeaderHeight = 60
Style.HeaderHeightShort = 50

Style.Ink = A.Ink

-- PANEL ------------------------------------------------------------------------------------

export type Panel = {
	root: Frame, -- size and place this
	body: Frame, -- put content here
	lip: Frame,
}

export type PanelSpec = {
	name: string?,
	z: number?,
	top: Color3?,
	bottom: Color3?,
}

function Style.panel(parent: Instance, spec: PanelSpec): Panel
	local z = spec.z or 3
	local root: Frame = make("Frame", {
		Name = spec.name or "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 400),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local lip: Frame = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, Style.Lip),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(lip, Style.Radius)
	local body: Frame = make("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(body, Style.Radius)
	Arcade.outline(body, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(spec.top or Style.PanelTop, spec.bottom or Style.PanelBottom),
		Rotation = 90,
		Parent = body,
	})
	return { root = root, body = body, lip = lip }
end

-- HEADER BAND --------------------------------------------------------------------------------

export type Header = {
	band: Frame,
	title: TextLabel,
	icon: Frame?,
	setHeight: (number) -> (),
}

export type HeaderSpec = {
	fill: Arcade.FillName?,
	colours: ColorSequence?, -- instead of a kit fill (a world identity)
	title: string,
	icon: string?,
	height: number?,
	z: number?,
	rightInset: number?, -- room kept free on the right (a close button)
}

function Style.header(body: Frame, spec: HeaderSpec): Header
	local z = (spec.z or body.ZIndex) + 1
	local band: Frame = make("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, spec.height or Style.HeaderHeight),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = body,
	})
	Arcade.corner(band, Style.Radius)
	make("UIGradient", {
		Color = spec.colours or A.Fill[spec.fill or "Garage"],
		Rotation = if spec.fill == "Rainbow" then 0 else 90,
		Parent = band,
	})
	-- square off the band's lower corners with a strip, then a hard dark rule under it
	local foot: Frame = make("Frame", {
		Name = "Foot",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, Style.Radius),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = band,
	})
	make("UIGradient", {
		Color = spec.colours or A.Fill[spec.fill or "Garage"],
		Rotation = if spec.fill == "Rainbow" then 0 else 90,
		Offset = Vector2.new(0, 0.4),
		Parent = foot,
	})
	local rule: Frame = make("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = band,
	})
	local _ = rule
	if spec.fill == "Rainbow" then
		-- the same soft shade the kit puts on rainbow buttons, so the white title keeps contrast
		local shade: Frame = make("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = band,
		})
		Arcade.corner(shade, Style.Radius)
	end
	Arcade.gloss(band)
	local iconHolder: Frame? = nil
	local left = 16
	if spec.icon then
		local h = math.floor((spec.height or Style.HeaderHeight) * 0.86)
		local holder: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(h, h),
			BackgroundTransparency = 1,
			ZIndex = z + 3,
			Parent = band,
		})
		Arcade.icon(holder, spec.icon)
		iconHolder = holder
		left = 10 + h + 6
	end
	local title = Arcade.text(band, {
		text = spec.title,
		role = "Display",
		name = "Title",
		xAlign = Enum.TextXAlignment.Left,
		z = z + 4,
	})
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.new(0, left, 0.5, 0)
	title.Size = UDim2.new(1, -left - (spec.rightInset or 12), 0, A.Text.Display + 8)
	make("UITextSizeConstraint", {
		MaxTextSize = A.Text.Display,
		MinTextSize = Tokens.TextSize.Minimum,
		Parent = title,
	})
	title.TextScaled = true
	local function setHeight(h: number)
		band.Size = UDim2.new(1, 0, 0, h)
		local holder = iconHolder
		if holder then
			local s = math.floor(h * 0.86)
			holder.Size = UDim2.fromOffset(s, s)
			left = 10 + s + 6
			title.Position = UDim2.new(0, left, 0.5, 0)
			title.Size = UDim2.new(1, -left - (spec.rightInset or 12), 0, math.min(A.Text.Display + 8, h - 6))
		else
			title.Size = UDim2.new(1, -left - (spec.rightInset or 12), 0, math.min(A.Text.Display + 8, h - 6))
		end
	end
	return { band = band, title = title, icon = iconHolder, setHeight = setHeight }
end

-- WELLS AND CHIPS -----------------------------------------------------------------------------

function Style.well(parent: Instance, name: string, z: number?): Frame
	local f: Frame = make("Frame", {
		Name = name,
		BackgroundColor3 = Style.Well,
		BackgroundTransparency = Style.WellTransparency,
		BorderSizePixel = 0,
		ZIndex = z or 5,
		Parent = parent,
	})
	Arcade.corner(f, 8)
	Arcade.outline(f, "Minor")
	return f
end

-- Round 3 (R2-HM3): a bright arcade plate for a row inside a panel (the Results rows and the Cash tally), the
-- same recipe as the card's Lap Pay plate: a kit fill, ONE dark outline (Minor, because it sits inside a panel
-- that already has the heavy one) and the narrow gloss band. Style.well stays for the screens that still use it.
-- Without a kit `fill` the plate takes Style.PlateFill: the Garage family deepened, because the kit's Garage middle
-- gives the green Cash digits only 1.6:1 (white 2.6:1); this one gives them 2.8:1 and white text 4.7:1.
function Style.plate(parent: Instance, name: string, z: number?, fill: Arcade.FillName?): Frame
	local f: Frame = make("Frame", {
		Name = name,
		BorderSizePixel = 0,
		ZIndex = z or 5,
		Parent = parent,
	})
	Arcade.corner(f, 8)
	Arcade.surface(f, fill or "Garage", { outline = "Minor" })
	local gradient = f:FindFirstChildOfClass("UIGradient")
	if gradient and not fill then
		gradient.Color = Style.PlateFill
	end
	return f
end

-- A floating chip over gameplay (Stunt): the panel gradient, the button boundary, a hard lip.
function Style.chip(parent: Instance, name: string, z: number?): Frame
	local f: Frame = make("Frame", {
		Name = name,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z or 4,
		Parent = parent,
	})
	Arcade.corner(f, 7)
	Arcade.outline(f, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(Style.PanelTop, Style.PanelBottom),
		Rotation = 90,
		Parent = f,
	})
	return f
end

-- TEXT --------------------------------------------------------------------------------------

export type TextOptions = {
	name: string?,
	colour: Color3?,
	face: Arcade.FaceName?,
	italic: boolean?,
	xAlign: Enum.TextXAlignment?,
	z: number?,
	size: number?,
	fit: boolean?, -- default true: shrink to fit the box (never below 16)
}

-- Kit text that never overflows its box: TextScaled with the role size as the maximum and the
-- approved 16 as the minimum (the box decides; nothing is cut with an ellipsis).
function Style.text(parent: Instance, text: string, role: Arcade.TextRole, opts: TextOptions?): TextLabel
	local o: TextOptions = opts or {}
	local label = Arcade.text(parent, {
		text = text,
		role = role,
		name = o.name,
		colour = o.colour,
		face = o.face,
		italic = o.italic,
		size = o.size,
		xAlign = o.xAlign or Enum.TextXAlignment.Left,
		z = o.z,
	})
	if o.fit ~= false then
		make("UITextSizeConstraint", {
			MaxTextSize = math.max(o.size or Arcade.textSize(role), Tokens.TextSize.Minimum),
			MinTextSize = Tokens.TextSize.Minimum,
			Parent = label,
		})
		label.TextScaled = true
	end
	return label
end

-- Wrapped copy that grows downward inside a fixed width (white with the minor outline).
function Style.paragraph(parent: Instance, text: string, size: number?, soft: boolean?, z: number?): TextLabel
	local label: TextLabel = make("TextLabel", {
		Name = "Paragraph",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		FontFace = Tokens.font(),
		Text = text,
		TextSize = math.max(size or A.Text.Small, Tokens.TextSize.Minimum),
		TextWrapped = true,
		TextColor3 = if soft then Style.TextSoft else Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = z or 6,
		Parent = parent,
	})
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 3),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		Parent = label,
	})
	Arcade.outline(label, "Minor")
	return label
end

-- TABS --------------------------------------------------------------------------------------

export type Tab = {
	root: TextButton,
	label: TextLabel,
	set: (on: boolean) -> (),
	setText: (text: string) -> (),
	trove: Trove.Trove,
}

export type TabSpec = {
	name: string,
	label: string,
	onActivate: () -> (),
	z: number?,
}

-- A wide compact tab: selected = the Garage fill with a white outlined label; not selected =
-- a dark well with a soft label. State is never colour alone (the selected tab also has the
-- thicker boundary and a gloss band).
function Style.tab(parent: Instance, spec: TabSpec): Tab
	local trove = Trove.new()
	local z = spec.z or 6
	local root: TextButton = trove:Add(make("TextButton", {
		Name = spec.name,
		Size = UDim2.fromOffset(160, Tokens.Touch.Minimum),
		BackgroundColor3 = Style.Well,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = z,
		Parent = parent,
	}))
	Arcade.corner(root, A.Button.Radius)
	local stroke = Arcade.outline(root, "Minor")
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
	local ring: Frame = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	Arcade.corner(ring, A.Button.Radius + 5)
	Arcade.outline(ring, 3, Color3.new(1, 1, 1))
	root.SelectionImageObject = ring
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
		root.BackgroundColor3 = if on then Color3.new(1, 1, 1) else Style.Well
		root.BackgroundTransparency = if on then 0 else Style.WellTransparency
		stroke.Thickness = if on then A.OutlineButton else A.OutlineMinor
		label.TextColor3 = if on then Color3.new(1, 1, 1) else Style.TextSoft
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

-- SCROLL ------------------------------------------------------------------------------------

function Style.scroll(parent: Instance, name: string, z: number?): ScrollingFrame
	return make("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = 0.25,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Selectable = false,
		ZIndex = z or 5,
		Parent = parent,
	})
end

-- STAMP -------------------------------------------------------------------------------------

export type Stamp = { frame: Frame, label: TextLabel }

-- A small tilted kit stamp sized to its word (NEW BEST!, SECURED). It is placed by the caller
-- INSIDE its parent's bounds, so a clipping parent never cuts it.
function Style.stamp(parent: Instance, text: string, fill: Arcade.FillName, z: number?): Stamp
	local zi = z or 8
	local frame: Frame = make("Frame", {
		Name = "Stamp",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		Rotation = -6,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = zi,
		Parent = parent,
	})
	Arcade.corner(frame, 5)
	Arcade.outline(frame, 2.5)
	make("UIGradient", { Color = A.Fill[fill], Rotation = 90, Parent = frame })
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = frame })
	local label = Arcade.text(frame, {
		text = text,
		role = "Badge",
		name = "Text",
		autoWidth = true,
		z = zi + 1,
	})
	label.Size = UDim2.fromOffset(0, 28)
	return { frame = frame, label = label }
end

return Style
