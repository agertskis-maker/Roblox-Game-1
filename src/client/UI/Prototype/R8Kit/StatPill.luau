--!strict
-- R8Kit.StatPill (Lane 3 Round 8, U-01/U-02): the cream stat pill of a card: a stopwatch icon, a small caption ("LAP PAY"), the
-- number you have now in navy, a chunky green arrow and the number you get next as big OUTLINED GRADIENT figures. All words and
-- numbers are live TextLabels; the pill, the stopwatch and the arrow are art ("r8_card_pill", "r8_card_stopwatch",
-- "r8_card_arrow") or code-drawn until uploaded. Also exports `bigNumber`, the outlined gradient number, for the Parking card.
--
--   local s = StatPill.new(parent: GuiObject, props: Props) -> StatPill
--     Props: { caption: string? ("LAP PAY"), from: string?, to: string?, icon: ("stopwatch" | "none")? (stopwatch),
--              size: UDim2? (443 x 97 design px), position: UDim2?, anchor: Vector2?, zIndex: number?, metrics: Metrics? }
--   s.frame: Frame (the pill)      s.content: Frame (above the art: add your own pieces)
--   s:setValues(from: string?, to: string?)   both -> "from -> to"; to only (nil from) -> the one big number (top level)
--   s:setCaption(text: string)                s:destroy()
--   StatPill.bigNumber(parent, text, props: { size: UDim2, position: UDim2?, anchor: Vector2?, designSize: number?,
--                      tone: ("green" | "gold" | "navy")?, zIndex: number?, metrics: Metrics? }) -> TextLabel

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Metrics = require(script.Parent.Metrics)
local Palette = require(script.Parent.Palette)

local StatPill = {}

export type Props = {
	caption: string?,
	from: string?,
	to: string?,
	icon: ("stopwatch" | "none")?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	metrics: any?,
}

export type StatPill = {
	frame: Frame,
	content: Frame,
	setValues: (self: StatPill, from: string?, to: string?) -> (),
	setCaption: (self: StatPill, text: string) -> (),
	destroy: (self: StatPill) -> (),
}

local TONES = {
	green = { top = Palette.GreenLight, bottom = Palette.GreenDeep },
	gold = { top = Palette.GoldBright, bottom = Palette.GoldDeep },
	navy = { top = Color3.fromRGB(60, 78, 124), bottom = Palette.Navy },
}

local Obj = {}
Obj.__index = Obj

-- An outlined gradient number: white text tinted by a UIGradient, a navy outline, TextScaled inside its box.
function StatPill.bigNumber(parent: GuiObject, text: string, props: { [string]: any }): TextLabel
	local metrics = props.metrics or Metrics.new(Vector2.new(988, 527))
	local tone = TONES[props.tone or "green"] or TONES.green
	local label = Build.label(parent, "BigNumber", text, {
		Size = props.size or UDim2.fromOffset(130, 70),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		ZIndex = props.zIndex or 2,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = props.align or Enum.TextXAlignment.Center,
	})
	Build.make("UITextSizeConstraint", {
		MaxTextSize = props.designSize or 70,
		MinTextSize = metrics:textSize(16),
		Parent = label,
	})
	Build.stroke(label, 5, Palette.NavyDeep, Enum.ApplyStrokeMode.Contextual)
	Build.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(tone.top, tone.bottom),
		Parent = label,
	})
	return label
end

local function smallText(
	parent: Instance,
	name: string,
	text: string,
	box: { number },
	designSize: number,
	color: Color3,
	align: Enum.TextXAlignment,
	trove: Trove.Trove,
	metrics: any
): TextLabel
	local label = Build.label(parent, name, text, {
		Position = UDim2.fromOffset(box[1], box[2]),
		Size = UDim2.fromOffset(box[3], box[4]),
		ZIndex = 3,
		TextColor3 = color,
		TextXAlignment = align,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	metrics:bindText(trove, label, designSize)
	return label
end

function StatPill.new(parent: GuiObject, props: Props): StatPill
	local trove = Trove.new()
	local metrics = props.metrics or Metrics.new(Vector2.new(988, 527))
	-- a pill wider than the 443 px design stretches its number columns with it (the stopwatch and caption stay at the left)
	local kx = if props.size and props.size.X.Offset > 0 then props.size.X.Offset / 443 else 1
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = "StatPill",
		Size = props.size or UDim2.fromOffset(443, 97),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 1,
	}))
	-- the pill
	local art: ImageLabel = Build.make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = frame,
	})
	if Art.apply(art, "r8_card_pill") then
		Art.fitSlice(trove, art, "r8_card_pill", "y")
	else
		local fill: Frame = Build.make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.CreamLight,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = frame,
		})
		Build.corner(fill, UDim.new(0, 26))
		Build.stroke(fill, 2, Color3.fromRGB(205, 172, 135))
	end
	local content: Frame = Build.make("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = frame,
	})
	-- the stopwatch
	if props.icon ~= "none" then
		local icon: ImageLabel = Build.make("ImageLabel", {
			Name = "Stopwatch",
			Position = UDim2.fromOffset(14, 7),
			Size = UDim2.fromOffset(83, 83),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = content,
		})
		if not Art.apply(icon, "r8_card_stopwatch") then
			-- code-drawn: a round gold face with a navy outline and a hand
			icon.Visible = true
			icon.BackgroundTransparency = 0
			icon.BackgroundColor3 = Palette.GoldBright
			Build.corner(icon, UDim.new(0.5, 0))
			Build.stroke(icon, 4, Palette.Navy)
			local face = Build.make("Frame", {
				Name = "Face",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.52),
				Size = UDim2.fromScale(0.7, 0.7),
				BackgroundColor3 = Palette.White,
				Parent = icon,
			})
			Build.corner(face, UDim.new(0.5, 0))
			Build.make("Frame", {
				Name = "Hand",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.52),
				Size = UDim2.fromOffset(4, 24),
				BackgroundColor3 = Palette.Red,
				BorderSizePixel = 0,
				Rotation = 30,
				Parent = icon,
			})
		end
	end
	local self = setmetatable({
		frame = frame,
		content = content,
		trove = trove,
		metrics = metrics,
		kx = kx,
		fromLabel = nil,
		toLabel = nil,
		arrow = nil,
		captionLabel = nil,
	}, Obj)
	local s: any = self
	s.captionLabel = smallText(
		content,
		"Caption",
		props.caption or "LAP PAY",
		{ 102, 6, 190, 34 },
		30,
		Palette.Navy,
		Enum.TextXAlignment.Left,
		trove,
		metrics
	)
	s.fromLabel = smallText(
		content,
		"From",
		props.from or "",
		{ 106, 40, 120, 52 },
		50,
		Palette.Navy,
		Enum.TextXAlignment.Left,
		trove,
		metrics
	)
	local arrow: ImageLabel = Build.make("ImageLabel", {
		Name = "Arrow",
		Position = UDim2.fromOffset(238 * kx, 44),
		Size = UDim2.fromOffset(52, 38),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = content,
	})
	if not Art.apply(arrow, "r8_card_arrow") then
		arrow.Visible = true
		arrow.BackgroundTransparency = 1
		local shaft = Build.make("Frame", {
			Name = "Shaft",
			Position = UDim2.fromOffset(0, 12),
			Size = UDim2.fromOffset(30, 14),
			BackgroundColor3 = Palette.Green,
			BorderSizePixel = 0,
			Parent = arrow,
		})
		Build.stroke(shaft, 2, Palette.Navy)
		local head = Build.make("Frame", {
			Name = "Head",
			Position = UDim2.fromOffset(26, 4),
			Size = UDim2.fromOffset(22, 30),
			BackgroundColor3 = Palette.Green,
			BorderSizePixel = 0,
			Rotation = 0,
			Parent = arrow,
		})
		Build.corner(head, UDim.new(0.3, 0))
		Build.stroke(head, 2, Palette.Navy)
	end
	s.arrow = arrow
	s.toLabel = StatPill.bigNumber(content, props.to or "", {
		size = UDim2.fromOffset(136 * kx, 72),
		position = UDim2.fromOffset(294 * kx, 12),
		designSize = 70,
		tone = "green",
		zIndex = 3,
		metrics = metrics,
	})
	s:setValues(props.from, props.to)
	frame.Parent = parent
	return s :: StatPill
end

function Obj.setValues(self: any, from: string?, to: string?)
	if from ~= nil and to ~= nil then
		self.fromLabel.Visible = true
		self.arrow.Visible = true
		self.fromLabel.Text = from
		self.toLabel.Text = to
		self.toLabel.Position = UDim2.fromOffset(294 * self.kx, 12)
		self.toLabel.Size = UDim2.fromOffset(136 * self.kx, 72)
	else
		-- the top level: one big number to the right of the caption
		self.fromLabel.Visible = false
		self.arrow.Visible = false
		self.toLabel.Text = to or from or ""
		self.toLabel.Position = UDim2.fromOffset(196 * self.kx, 12)
		self.toLabel.Size = UDim2.fromOffset(234 * self.kx, 72)
	end
end

function Obj.setCaption(self: any, text: string)
	self.captionLabel.Text = text
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return StatPill
