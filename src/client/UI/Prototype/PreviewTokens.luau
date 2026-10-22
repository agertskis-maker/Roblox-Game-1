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

PreviewTokens.Font = Tokens.font
PreviewTokens.FontBody = function(): Font
	-- readable label face candidate (verified Roblox family; preview choice)
	return Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
end

return table.freeze(PreviewTokens)
