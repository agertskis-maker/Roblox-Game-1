--!strict
-- Uploaded island environment assets (Lane 3). Every id here was uploaded for the island rework
-- under Adam's Roblox account peskaface (user 2393473976), authorised for Task 2 on 2026-10-21.
-- Sources and recipes: assets/island/kit/ (recipes in Git) and Car-Hop-Art/island-kit/ (art
-- outside Git). Full table with sizes, states and load checks: assets/island/kit/manifest.md.

local AssetIds = {}

local function id(n: number): string
	return "rbxassetid://" .. n
end

-- Effect textures (assets/island/kit/textures.js), uploaded 2026-10-21 through the Studio MCP.
AssetIds.Textures = {
	WaterBody = id(118829614143752),
	WaterStrandsFast = id(123432307138321),
	WaterStrandsSlow = id(80338760305637),
	WaterHighlights = id(111578838235188),
	WaterSpray = id(91396665960467),
	FoamTile = id(122795342152257),
	FoamPatch = id(99023600024403),
	Ripple = id(106407842749322),
	Droplet = id(109536997721772),
	Mist = id(114900109756669),
	Rainbow = id(72537598666370),
	Sparkle = id(87030054749344),
	Glow = id(109290330063558),
	Current = id(103576178978702),
}

-- The kit palette (assets/island/kit/kitlib.py, 16 x 16 swatches), uploaded 2026-10-21.
AssetIds.Palette = id(112727480640146)

-- Kit meshes (assets/island/kit/, KitManifest), by mesh name. A mesh not listed here is built as a
-- session-only preview from its mesh data (KitAssets).
AssetIds.Meshes = {} :: { [string]: string }

return AssetIds
