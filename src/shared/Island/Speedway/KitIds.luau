--!strict
-- Asset ids the Speedway looks use (Lane 3). The images are the island's existing uploads (the
-- same ids as ServerStorage Island/Hub/Environment/AssetIds, repeated here because the Speedway
-- is assembled on each client). Meshes: the speedway kit (assets/island/kit/kit_speedway.py) is
-- not uploaded yet; until it is, Kit builds session-only previews from the mesh data that only
-- Adam's island preview project syncs (ReplicatedStorage.Lane3_SpeedwayKitData). After the
-- guided import, every mesh id goes in Meshes (name = "rbxassetid://..."); nothing else changes.

local KitIds = {}

local function id(n: number): string
	return "rbxassetid://" .. n
end

-- the island kit palette (256 x 256 swatch image) every kit mesh is UV-mapped to
KitIds.Palette = id(134121745235322)

KitIds.Textures = {
	Pennants = id(129394675251472),
	FlagChecker = id(113814256495528),
	FlagStripesA = id(97908223611462),
	FlagStripesB = id(81318556896008),
	FlagStar = id(93044374349935),
	BannerA = id(121463232337129), -- ZOOPA FIZZ (fictional)
	BannerB = id(110246953719901), -- CRUNCHKIN PUFFS (fictional)
	BannerC = id(78479045044254), -- STICKYTOE TYRES (fictional)
	BannerD = id(140634403555411), -- WOBBLEBOT TOYS (fictional)
}

-- name -> "rbxassetid://..." once uploaded (empty: previews only)
KitIds.Meshes = {} :: { [string]: string }

return KitIds
