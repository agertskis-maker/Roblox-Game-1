--!strict
-- Shared UI style tokens for Car Hop (Lane 3 owns this module).
--
-- Approved by Adam on 2026-10-19: Fredoka One for game text (36 / 24 / 18,
-- 16 minimum), touch targets of 48 px (56 px for primary buttons), the
-- short-side scaling rule below, and following Roblox's Reduce Motion
-- setting. Colours, spacing, radii, strokes and motion timings are part of
-- the HUD sample that is still pending Adam's review
-- (vault/design/visual-direction.md).
--
-- Units: every size here is a design pixel at scale 1.0. Widgets are scaled
-- once, by a UIScale at each widget's root (see uiScaleFor). Components must
-- not multiply these numbers by the scale themselves.

local Tokens = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Palette = {
	Card: Color3,
	CardInset: Color3,
	Text: Color3,
	TextSecondary: Color3,
	Stroke: Color3,
	Shadow: Color3,
	Track: Color3,
	Primary: Color3,
	PrimaryPressed: Color3,
	Success: Color3,
	Danger: Color3,
	Warning: Color3,
	Calm: Color3,
	Coin: Color3,
	Steam: Color3,
	Smoke: Color3,
	SmokeLight: Color3,
	StripeLight: Color3,
	HeatOrange: Color3,
	DangerDeep: Color3,
	AlarmTint: Color3,
	SirenOff: Color3,
	Glass: Color3,
	Chrome: Color3,
	ChromeShade: Color3,
	HeatMist: Color3,
	HeatCream: Color3,
	CashTop: Color3,
	CashBottom: Color3,
	CashOutline: Color3,
	CashShadow: Color3,
	BillFace: Color3,
	BillLight: Color3,
	BillDark: Color3,
	BillBand: Color3,
	BillBandShade: Color3,
	Sparkle: Color3,
	FloatText: Color3,
	FloatTextCream: Color3,
	MeltdownBar: Color3,
	MeltdownStripe: Color3,
	MeltdownGlow: Color3,
	SmokeCore: Color3,
	Teal: Color3,
	TealLight: Color3,
}

-- Colour roles. Red (Danger) is reserved for danger; orange (Primary) for go/buy.
Tokens.Color = table.freeze({
	Card = rgb(255, 244, 220), -- #FFF4DC cream card
	CardInset = rgb(246, 230, 191), -- #F6E6BF
	Text = rgb(30, 42, 74), -- #1E2A4A navy
	TextSecondary = rgb(74, 85, 120), -- #4A5578
	Stroke = rgb(30, 42, 74), -- navy outlines
	Shadow = rgb(30, 42, 74),
	Track = rgb(255, 255, 255), -- empty gauge track
	Primary = rgb(255, 138, 31), -- #FF8A1F
	PrimaryPressed = rgb(217, 106, 0), -- #D96A00
	Success = rgb(61, 190, 108), -- #3DBE6C
	Danger = rgb(229, 72, 77), -- #E5484D
	Warning = rgb(255, 184, 28), -- #FFB81C
	Calm = rgb(63, 182, 216), -- #3FB6D8
	Coin = rgb(255, 200, 61), -- #FFC83D
	Steam = rgb(255, 255, 255),
	Smoke = rgb(150, 154, 168), -- #969AA8 grey smoke
	SmokeLight = rgb(198, 202, 214), -- #C6CAD6 lighter smoke layer
	StripeLight = rgb(255, 248, 236), -- #FFF8EC
	-- Heat scale additions (2026-10-19 HUD revision, pending review):
	HeatOrange = rgb(255, 143, 42), -- #FF8F2A between Warning and Danger; not the action orange
	DangerDeep = rgb(201, 48, 58), -- #C9303A deepest red at 100% Heat
	AlarmTint = rgb(255, 214, 210), -- #FFD6D2 light alarm red; navy text stays readable on it
	SirenOff = rgb(242, 196, 194), -- #F2C4C2 unlit siren
	Glass = rgb(234, 246, 251), -- #EAF6FB thermometer glass
	Chrome = rgb(214, 222, 232), -- #D6DEE8 radiator cap
	ChromeShade = rgb(140, 152, 170), -- #8C98AA cap shading
	-- Heat scale, revision 3 (Adam, 2026-10-19): no green anywhere in Heat.
	HeatMist = rgb(201, 213, 238), -- #C9D5EE pale periwinkle between blue and cream
	HeatCream = rgb(248, 230, 188), -- #F8E6BC pale cream at about 35%
	-- Cash counter (green is Cash's colour; Heat never uses it).
	CashTop = rgb(46, 230, 90), -- #2EE65A bright saturated green
	CashBottom = rgb(160, 246, 184), -- #A0F6B8 light mint
	CashOutline = rgb(20, 27, 51), -- #141B33 near-black navy outline
	CashShadow = rgb(20, 27, 51), -- drop shadow, used with transparency
	BillFace = rgb(52, 180, 90), -- #34B45A medium green bill
	BillLight = rgb(150, 228, 165), -- #96E4A5 inset border and emblem
	BillDark = rgb(31, 122, 60), -- #1F7A3C lower bills and edge shading
	BillBand = rgb(255, 184, 40), -- #FFB828 gold band
	BillBandShade = rgb(224, 123, 18), -- #E07B12 band shading
	Sparkle = rgb(214, 255, 222), -- #D6FFDE gain sparkles
	-- Distance (option B, approved 2026-10-19): white-to-cream number.
	FloatText = rgb(255, 255, 255), -- #FFFFFF top of the Distance number
	FloatTextCream = rgb(255, 236, 196), -- #FFECC4 bottom of the Distance number
	-- Meltdown hazard bar (revision 4).
	MeltdownBar = rgb(230, 30, 40), -- #E61E28 saturated danger red
	MeltdownStripe = rgb(140, 12, 24), -- #8C0C18 darker red hazard stripes
	MeltdownGlow = rgb(255, 170, 60), -- #FFAA3C bright edge glow
	SmokeCore = rgb(86, 90, 104), -- #565A68 charcoal smoke centre
	-- Raceway round 2 (approved by Adam 2026-10-29): the island kit teal, and a light teal for text
	-- on navy (where Teal is only 2.8:1).
	Teal = rgb(34, 138, 146), -- #228A92
	TealLight = rgb(81, 215, 209), -- #51D7D1
} :: Palette)

-- Fixed temperature scale for Heat, 0 to 1. The bar reveals this scale from
-- the left and the thermometer liquid uses heatColor, so the colour at the bar
-- tip always matches the liquid at the same Heat.
-- Revision 3 stops (approved by Adam): Calm blue at 0%, pale cream at about
-- 35%, Warning yellow at 60%, orange at about 75%, Danger red from 85%. A
-- pale periwinkle (HeatMist) sits between blue and cream because a straight
-- blue-to-cream blend passes through a pale aqua that reads green.
local HEAT_STOPS: { { at: number, role: string } } = {
	{ at = 0, role = "Calm" },
	{ at = 0.18, role = "HeatMist" },
	{ at = 0.35, role = "HeatCream" },
	{ at = 0.6, role = "Warning" },
	{ at = 0.75, role = "HeatOrange" },
	{ at = 0.85, role = "Danger" },
	{ at = 1, role = "DangerDeep" },
}

Tokens.FontFamily = "FredokaOne"

function Tokens.font(): Font
	return Font.fromName(Tokens.FontFamily)
end

Tokens.TextSize = table.freeze({
	Display = 36,
	Value = 24,
	Label = 18,
	Minimum = 16,
	Cash = 40, -- floating Cash counter (Adam, 2026-10-19)
	FloatDistance = 32, -- floating Distance number (option B, approved 2026-10-19)
})

Tokens.Space = table.freeze({
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
	XXL = 32,
})

Tokens.Radius = table.freeze({
	Small = UDim.new(0, 8),
	Card = UDim.new(0, 14),
	Panel = UDim.new(0, 20),
	Pill = UDim.new(1, 0),
})

Tokens.Stroke = table.freeze({
	Thin = 2,
	Regular = 3,
	Thick = 4,
})

Tokens.Shadow = table.freeze({
	OffsetY = 4,
	Transparency = 0.8,
})

-- Interactive elements never end up smaller than these on screen, because the
-- scale below never goes under 1.0.
Tokens.Touch = table.freeze({
	Minimum = 48,
	Primary = 56,
})

Tokens.Scale = table.freeze({
	BaseShortSide = 390,
	Min = 1,
	Max = 1.5,
})

-- The approved rule: the viewport's short side divided by 390, clamped to
-- 1.0 to 1.5 (cap lowered from 1.75 by Adam on 2026-10-19). Phones stay at
-- 1.0; a 1920 x 1080 screen gets 1.5.
function Tokens.uiScaleFor(viewport: Vector2): number
	local shortSide = math.min(viewport.X, viewport.Y)
	if shortSide <= 0 then
		return Tokens.Scale.Min
	end
	return math.clamp(shortSide / Tokens.Scale.BaseShortSide, Tokens.Scale.Min, Tokens.Scale.Max)
end

-- Motion timings. With reduced motion, decorative oscillation and fades are
-- removed and essential values snap.
--
-- Alarm counting (decision 0008, ceiling lowered by Adam on 2026-10-19):
-- one alarm cycle produces two distinct visible peaks. At phase 0 the panel
-- tint, the left siren, the Meltdown bar's edge glow and the HOP NOW! scale
-- pulse peak together; at phase 0.5 the right siren peaks. The hazard stripes
-- travel one stripe spacing per cycle at constant speed (no brightness peak).
-- So combined visible peaks per second = 2 x cycle rate. The cap AlarmMaxHz = 1.25 keeps the combined
-- rate at or under 2.5 per second; Meltdown uses 1.2 (2.4 per second) and
-- Critical stays lower (1.2 to 2.0 per second).
Tokens.Motion = table.freeze({
	Press = 0.1,
	Panel = 0.2,
	LabelFade = 0.15,
	-- Exponential smoothing rates (per second) for frame-rate-independent easing.
	HeatSmoothing = 10,
	EffectSmoothing = 6,
	AlarmCriticalStartHz = 0.6,
	AlarmCriticalEndHz = 1.0,
	AlarmMeltdownHz = 1.2,
	AlarmMaxHz = 1.25,
	VisiblePeaksPerCycle = 2,
	CombinedFlashCeiling = 2.5,
	BumpSeconds = 0.6,
	-- Cash counter (presentation only).
	CashGainSeconds = 0.35,
	CashSpendSeconds = 0.18,
	CashPunch = 0.12,
	CashPunchBig = 0.16,
	CashGainLabelSeconds = 0.7,
	CashCoalesceSeconds = 0.25,
})

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

-- Colour of the temperature scale at heat01 (0 to 1).
function Tokens.heatColor(heat01: number, palette: Palette?): Color3
	local p = (palette or Tokens.Color) :: any
	local h = math.clamp(heat01, 0, 1)
	for i = 2, #HEAT_STOPS do
		local a, b = HEAT_STOPS[i - 1], HEAT_STOPS[i]
		if h <= b.at then
			return lerpColor(p[a.role], p[b.role], (h - a.at) / (b.at - a.at))
		end
	end
	return p[HEAT_STOPS[#HEAT_STOPS].role]
end

-- The same scale as a ColorSequence for the bar's UIGradient.
function Tokens.heatColorSequence(palette: Palette?): ColorSequence
	local p = (palette or Tokens.Color) :: any
	local points = {}
	for _, stop in HEAT_STOPS do
		table.insert(points, ColorSequenceKeypoint.new(stop.at, p[stop.role]))
	end
	return ColorSequence.new(points)
end

-- Converts a colour to the grey of the same perceived brightness. Used by the
-- development preview to check that nothing depends on colour alone.
function Tokens.toGrey(color: Color3): Color3
	local l = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
	return Color3.new(l, l, l)
end

function Tokens.greyPalette(): Palette
	local source = Tokens.Color :: any
	local grey = {}
	for role, color in source do
		grey[role] = Tokens.toGrey(color)
	end
	return table.freeze(grey) :: any
end

return table.freeze(Tokens)
