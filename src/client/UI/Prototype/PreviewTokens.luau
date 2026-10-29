--!strict
-- PREVIEW tokens for the overnight HUD prototype (Lane 3, 2026-10-22). Additive proposals only:
-- the approved shared tokens stay in ReplicatedStorage.Shared.UI.Tokens and are used first.
-- Nothing here is approved for production; every value is a labelled preview choice
-- (vault/design/specs/hud-downtown-overnight.md, "Decisions I made for you").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local PreviewTokens = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Colour roles (the brief's starting values, tuned only where approved tokens exist).
PreviewTokens.Color = table.freeze({
	Ink = rgb(22, 36, 63), -- #16243F dark navy outlines and text
	InkSoft = rgb(52, 66, 99),
	Panel = rgb(255, 246, 227), -- #FFF6E3 warm cream panels
	PanelShade = rgb(240, 226, 196),
	White = rgb(255, 255, 255),
	-- Cash reuses the approved CashTop / CashBottom / CashOutline tokens; these are the
	-- glossy button versions for Cash-themed controls only
	CashLight = rgb(139, 255, 110), -- #8BFF6E
	CashDeep = rgb(24, 178, 58), -- #18B23A
	PrimaryLight = rgb(255, 164, 31), -- #FFA41F
	PrimaryDeep = rgb(255, 94, 0), -- #FF5E00
	KeysLight = rgb(255, 210, 74), -- #FFD24A
	KeysDeep = rgb(242, 169, 0), -- #F2A900
	GarageLight = rgb(98, 226, 255),
	GarageDeep = rgb(18, 150, 214),
	MissionsLight = rgb(255, 178, 64),
	MissionsDeep = rgb(240, 110, 20),
	SettingsLight = rgb(70, 92, 150),
	SettingsDeep = rgb(30, 44, 86),
	HopLight = rgb(120, 255, 230), -- teal Hop cues only
	HopDeep = rgb(0, 168, 160),
	TutorialLight = rgb(255, 228, 92),
	TutorialDeep = rgb(255, 190, 40),
	Success = rgb(61, 190, 108), -- matches Tokens.Color.Success
	SuccessLight = rgb(140, 236, 150),
	Info = rgb(255, 246, 227),
	Unlock = rgb(255, 210, 74),
	Badge = rgb(229, 72, 77), -- genuine notifications only (matches Tokens.Color.Danger)
	HeatLow = rgb(255, 214, 64),
	HeatMid = rgb(255, 140, 30),
	HeatHigh = rgb(232, 60, 50),
	Shadow = rgb(22, 36, 63),
})

-- The rarity ladder (live vocabulary incl. Uncommon; colour is never the only signal: each has
-- a label and a pip count, 1 to 5, drawn as shapes, so it reads without colour).
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
PreviewTokens.Rarity = table.freeze({
	Common = table.freeze({ label = "COMMON", pips = 1, light = rgb(214, 220, 230), deep = rgb(130, 140, 158) }),
	Uncommon = table.freeze({ label = "UNCOMMON", pips = 2, light = rgb(140, 236, 120), deep = rgb(40, 160, 70) }),
	Rare = table.freeze({ label = "RARE", pips = 3, light = rgb(110, 190, 255), deep = rgb(30, 100, 220) }),
	Epic = table.freeze({ label = "EPIC", pips = 4, light = rgb(206, 140, 255), deep = rgb(120, 50, 200) }),
	Legendary = table.freeze({ label = "LEGENDARY", pips = 5, light = rgb(255, 222, 90), deep = rgb(230, 150, 0) }),
})
PreviewTokens.RarityOrder = table.freeze({ "Common", "Uncommon", "Rare", "Epic", "Legendary" })

-- Variant treatments are not rarities.
export type Variant = "None" | "Gold" | "Chrome" | "Rainbow"

-- Sizes in design pixels at scale 1.0 (the approved UIScale rule scales them once per root).
PreviewTokens.Size = table.freeze({
	CashNumber = Tokens.TextSize.Cash, -- approved 40 at scale 1 (60 on 1080p after the 1.5 cap)
	MenuButton = 64, -- body; 96 on 1080p after the scale cap (brief: about 70 to 80 at 1080p)
	MenuButtonSmall = 48, -- Settings
	TouchMin = Tokens.Touch.Minimum, -- 48 (approved)
	TouchPrimary = Tokens.Touch.Primary, -- 56 (approved)
	HopButton = 96,
	DashButton = 68,
	KeysRing = 64,
	Outline = 3,
	ShadowOffset = 4,
	Corner = 16,
	BannerHeight = 56,
	ToastHeight = 44,
	CardWidth = 200,
	CardHeight = 280,
})

-- Motion vocabulary (seconds) shared by every prototype component.
PreviewTokens.Motion = table.freeze({
	Press = 0.1,
	Release = 0.14,
	Panel = 0.22,
	PanelOut = 0.16,
	CountUpMin = 0.4,
	CountUpMax = 0.8,
	Emphasis = 1.1, -- scale for a brief pop
	EmphasisSeconds = 0.18,
	ToastSeconds = 2.5,
	ToastMaxVisible = 2,
	ToastQueue = 6,
	ExactValueSeconds = 2,
	LapPaySeconds = 1.2,
	LapPayRange = 120,
	BigGainFraction = 0.1, -- preview-only celebration threshold (see the spec)
	BigGainMinimum = 500, -- and never for gains under this many dollars
	BigGainCooldown = 8,
})

-- ARCADE block (HUD rebuild, 2026-10-22; vault/design/specs/hud-rebuild-downtown-b.md). Scoped
-- tokens for the rebuilt look measured from Adam's two new HUD references
-- (vault/design/research/hud-ref-arcade-translation.md). Design px at scale 1.0; 1080p shows
-- them at 1.5x. Every value is a preview choice; the approved shared Tokens are unchanged.
local function seq(...: Color3): ColorSequence
	local colours = { ... }
	local points = {}
	for i, c in colours do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colours - 1), c))
	end
	return ColorSequence.new(points)
end

PreviewTokens.Arcade = table.freeze({
	-- Outlines: near-black navy everywhere; major 2.5 design px (≈3.75 px at 1080p), minor 1.75.
	Ink = rgb(14, 20, 38),
	OutlineMajor = 2.5,
	OutlineMinor = 1.75,
	OutlineButton = 3, -- the dark button boundary (≈4.5 px at 1080p)
	-- Text roles (TextSize in design px). Display/Label use Fredoka One; Number/Timer use the
	-- italic candidate (Nunito Black Italic, verified installed).
	Text = table.freeze({
		Display = 36, -- headings (approved display size)
		Button = 28, -- wide button labels (measured cap 0.30–0.35 of the body height)
		ButtonSmall = 18, -- Settings
		Value = 40, -- Cash (approved counter size), car count
		ValueRun = 28, -- Cash / count while driving
		Earning = 22, -- the italic earning line (measured ≈ 0.6–0.85 of the numbers)
		Label = 18,
		Small = 16, -- minimum
		Badge = 16,
	}),
	-- Buttons (design px). Wide ≈ 2.3:1 from the references; phones keep ≥ 48 hit height.
	Button = table.freeze({
		WideW = 150, -- measured 2.2–2.5:1 (ref-04 236×105 px, ref-03 199×79 px at 1080p)
		WideH = 60,
		CompactW = 124, -- phones/tablet portrait
		CompactH = 50,
		SmallW = 108, -- Settings (100 still clipped at scale 1.0 on portrait) (84 clipped "Settings" in Studio; measured 35 design px tall: too small to touch, so the hit box is 48)
		SmallH = 40, -- visual body; hit box padded to 48
		Radius = 5, -- limited rounding (measured ≈ 0.075 × height)
		Gap = 8, -- measured stack gap ≈ 6–9
		IconScale = 0.74, -- icon box / body height (measured 0.41–0.74)
		IconOverhang = 0, -- measured: icons stay inside the outer edge
		GlossHeight = 0.22, -- narrow gloss band, fraction of body height
		DepthOffset = 4, -- shallow dark lip under the body
		Badge = 26,
	}),
	Stats = table.freeze({
		IconCash = 48, -- measured ≈ 1.6–1.9 × number cap height
		IconCars = 46,
		RowGap = 4,
		MarginLeft = 12,
		MarginBottom = 12,
	}),
	-- Fills (top -> bottom gradients; rotation 90). Rainbow drifts sideways.
	Fill = table.freeze({
		Rainbow = seq(
			rgb(255, 72, 72),
			rgb(255, 170, 40),
			rgb(255, 230, 60),
			rgb(80, 220, 90),
			rgb(60, 170, 255),
			rgb(170, 90, 255),
			rgb(255, 72, 200)
		),
		Garage = seq(rgb(110, 236, 255), rgb(30, 170, 240), rgb(20, 110, 220)),
		Missions = seq(rgb(255, 196, 70), rgb(255, 140, 30), rgb(240, 96, 16)),
		Settings = seq(rgb(255, 92, 92), rgb(222, 38, 46), rgb(176, 22, 34)),
		Retry = seq(rgb(255, 196, 70), rgb(255, 140, 30), rgb(240, 96, 16)),
		Home = seq(rgb(120, 245, 225), rgb(20, 196, 180), rgb(0, 140, 140)),
		Gold = seq(rgb(255, 236, 120), rgb(255, 200, 40), rgb(230, 150, 0)),
		Green = seq(rgb(150, 255, 120), rgb(60, 210, 80), rgb(24, 160, 58)),
		Disabled = seq(rgb(196, 202, 212), rgb(150, 158, 172), rgb(120, 128, 142)),
	}),
	-- Number faces (gradients on the glyphs, dark outline around them)
	Face = table.freeze({
		Cash = seq(rgb(170, 255, 120), rgb(70, 230, 80), rgb(30, 186, 60)),
		Cars = seq(rgb(150, 245, 255), rgb(50, 214, 250), rgb(20, 160, 230)),
		Keys = seq(rgb(255, 240, 140), rgb(255, 206, 50), rgb(240, 160, 0)),
		White = seq(rgb(255, 255, 255), rgb(255, 255, 255), rgb(228, 236, 248)),
		Heat = seq(rgb(255, 236, 90), rgb(255, 150, 30), rgb(232, 60, 50)),
		Danger = seq(rgb(255, 120, 100), rgb(240, 60, 50), rgb(200, 30, 40)),
	}),
	Badge = rgb(232, 36, 44), -- earned badges and the Settings red (requested treatments)
	Motion = table.freeze({
		RainbowDriftSeconds = 9, -- one slow sideways cycle; stopped in reduced motion
		Press = 0.08,
		Release = 0.12,
	}),
	-- Keys capture (proposal values; tune in recorded gameplay)
	Keys = table.freeze({
		Segments = 8, -- brief's 8–12 range, low end for phone clarity
		RingSize = 92, -- design px, clamped per device
		AlmostAt = 0.75,
		ReleaseSeconds = 0.15,
		RibbonHoldSeconds = 1.6,
	}),
})

PreviewTokens.FontItalicNumber = function(): Font
	-- verified in Studio's bundled font families (Nunito: "Black Italic", weight 900 = Enum.FontWeight.Heavy)
	return Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
end

PreviewTokens.Font = Tokens.font
PreviewTokens.FontBody = function(): Font
	-- readable label face candidate (verified Roblox family; preview choice)
	return Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
end

return table.freeze(PreviewTokens)
