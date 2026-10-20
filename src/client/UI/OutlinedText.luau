--!strict
-- Floating outlined text shared by the HUD numbers (Lane 3): a gradient face
-- with a dark character outline, and a drop shadow that carries its own
-- outline. Cash and Distance use the same outline thickness, outline colour
-- and shadow convention so they read as one family.
--
-- Fading: every layer is driven from one fade value (setFade). Each layer keeps
-- its resting opacity relative to the others while visible and all reach
-- fully transparent together, so no outline or shadow is left behind.
--
-- Glyph metrics: Fredoka One ink measured in Studio (2026-10-19, pixel
-- analysis of a 3x capture), as fractions of TextSize, without the outline.
-- Used to align icons with the visible digits rather than the label box.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local OutlinedText = {}

OutlinedText.Outline = 3.5
OutlinedText.ShadowOffset = 3
OutlinedText.ShadowTransparency = 0.35

-- Visible height of a lining digit (cap height), and how far the digit centre
-- sits below the centre of a TextLabel whose height is TextSize + 2 * Outline
-- (TextYAlignment Center). Fractions of TextSize. Digits sit on the baseline,
-- so the baseline is DigitCentreEm + DigitHeightEm / 2 below the centre.
OutlinedText.DigitHeightEm = 0.666
OutlinedText.DigitCentreEm = 0.028
-- Distance from the label's left edge to the first visible ink of "$" and of
-- a digit, without the outline. Fractions of TextSize.
OutlinedText.DollarInkLeftEm = 0.025
OutlinedText.DigitInkLeftEm = 0.015

export type Parts = {
	holder: Frame,
	face: TextLabel,
	faceStroke: UIStroke,
	shadow: TextLabel,
	shadowStroke: UIStroke,
}

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

-- Builds the text inside a holder that fills `parent`.
function OutlinedText.build(
	parent: Instance,
	name: string,
	size: number,
	top: Color3,
	bottom: Color3,
	palette: Tokens.Palette,
	z: number
): Parts
	local holder = make("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local shadow = make("TextLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, OutlinedText.ShadowOffset),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = size,
		TextColor3 = palette.CashShadow,
		TextTransparency = OutlinedText.ShadowTransparency,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = z,
		Parent = holder,
	})
	local shadowStroke = make("UIStroke", {
		Color = palette.CashShadow,
		Thickness = OutlinedText.Outline,
		Transparency = OutlinedText.ShadowTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = shadow,
	})
	local face = make("TextLabel", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = size,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = z + 1,
		Parent = holder,
	})
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(top, bottom),
		Parent = face,
	})
	local faceStroke = make("UIStroke", {
		Color = palette.CashOutline,
		Thickness = OutlinedText.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = face,
	})
	return {
		holder = holder,
		face = face,
		faceStroke = faceStroke,
		shadow = shadow,
		shadowStroke = shadowStroke,
	}
end

function OutlinedText.setText(parts: Parts, text: string)
	parts.face.Text = text
	parts.shadow.Text = text
end

-- fade 0 = resting opacity, 1 = fully transparent, for every layer at once.
function OutlinedText.setFade(parts: Parts, fade: number)
	local f = math.clamp(fade, 0, 1)
	local shadow = 1 - (1 - OutlinedText.ShadowTransparency) * (1 - f)
	parts.face.TextTransparency = f
	parts.faceStroke.Transparency = f
	parts.shadow.TextTransparency = shadow
	parts.shadowStroke.Transparency = shadow
end

return OutlinedText
