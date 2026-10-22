--!strict
-- Templates for the island's decorative wildlife (Lane 3, build-time). The creatures move only
-- on each client (src/client/Home/Island/Wildlife.client.luau), which clones these hidden pieces.
-- Every template is placed with KitAssets.place at ORIGIN, so a client gets each piece's offset
-- from its joint (the mesh origin) as ORIGIN:ToObjectSpace(template.CFrame). The folder also
-- carries the particle textures the client needs (the client cannot read AssetIds).

local AssetIds = require(script.Parent.AssetIds)
local KitAssets = require(script.Parent.KitAssets)

local WildlifeKit = {}

-- far below the island, out of every view and below the water and terrain box
local ORIGIN = CFrame.new(0, -480, 0)

local PIECES = {
	"Duck",
	"Duckling",
	"Raccoon",
	"RaccoonHead",
	"ButterflyBody",
	"ButterflyWingL",
	"ButterflyWingR",
	"ButterflyBlueWingL",
	"ButterflyBlueWingR",
	"DragonflyBody",
	"DragonflyWings",
	"Frog",
	"FishOrange",
	"FishSilver",
}

function WildlifeKit.build(parent: Instance): { pieces: number, triangles: number }
	local old = parent:FindFirstChild("WildlifeKit")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "WildlifeKit"
	root:SetAttribute("Origin", ORIGIN.Position)
	root:SetAttribute("PollenTexture", AssetIds.Textures.Sparkle)
	root:SetAttribute("FireflyTexture", AssetIds.Textures.Glow)
	local triangles = 0
	for _, name in PIECES do
		local part = KitAssets.place(name, ORIGIN, 1)
		part.Transparency = 1
		part.CastShadow = false
		part.Parent = root
		triangles += KitAssets.info(name).triangles
	end
	-- where the raccoon's head joins its body (kit_animals.py, raccoon "neck", in mesh space)
	root:SetAttribute("RaccoonNeck", Vector3.new(0.95, 1.25, 0))
	root.Parent = parent
	return { pieces = #PIECES, triangles = triangles }
end

return WildlifeKit
