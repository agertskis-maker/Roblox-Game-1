--!strict
-- CloverMeshes (Round 8, L-01 / L-02): where the Lucky Clover's Blender meshes live and how big they are. One palette image
-- colours every mesh (the kit's palette trick), so each mesh is one draw call. `ready()` is true only when every mesh and the
-- palette can be shown; until then CloverStand draws its code-built fallback. Numbers come from Blender's rig.json (studs, Roblox
-- axes: X right, Y up, Z toward the viewer: every mesh FACES +Z in the file, so the stand turns them by CloverMeshes.FACING).
--
--   CloverMeshes.part(name) -> { key, size, offset }      CloverMeshes.ready() -> boolean
--   CloverMeshes.meshId(key) -> string                     CloverMeshes.palette() -> string
--   CloverMeshes.Pivots.eyeL / eyeR / hat / armL / armR     joint positions in the mascot's frame (before FACING)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)

local CloverMeshes = {}

CloverMeshes.PaletteKey = "r8_clover_palette"
-- studs per mesh unit after the upload; the Blender export is 1 unit = 1 stud (FBX unit scale applied). Check the first import.
CloverMeshes.SCALE = 1
CloverMeshes.FACING = CFrame.Angles(0, math.pi, 0)

export type Part = { key: string, size: Vector3, offset: Vector3, tris: number }

-- rig.json from blender-round8/build_clover.py (export); size is the bounding box, offset the box centre from the part's pivot.
CloverMeshes.Parts = {
	body = {
		key = "r8_clover_body",
		size = Vector3.new(3.261, 4.3926, 1.6674),
		offset = Vector3.new(0, -0.5658, 0.0978),
		tris = 2844,
	},
	eye = {
		key = "r8_clover_eye",
		size = Vector3.new(0.6287, 0.7647, 0.521),
		offset = Vector3.new(0, 0, 0.0055),
		tris = 576,
	},
	hat = {
		key = "r8_clover_hat",
		size = Vector3.new(1.5994, 0.9568, 1.5831),
		offset = Vector3.new(0, 0.4593, 0),
		tris = 550,
	},
	armL = {
		key = "r8_clover_arm_l",
		size = Vector3.new(1.111, 1.18, 0.5574),
		offset = Vector3.new(-0.5276, -0.4215, 0.1096),
		tris = 596,
	},
	armR = {
		key = "r8_clover_arm_r",
		size = Vector3.new(1.111, 1.18, 0.5574),
		offset = Vector3.new(0.5276, -0.4215, 0.1096),
		tris = 596,
	},
	sign = {
		key = "r8_clover_sign",
		size = Vector3.new(4.9166, 4.9166, 2.5507),
		offset = Vector3.new(0, 0, 0.1417),
		tris = 1584,
	},
	coin = { key = "r8_clover_coin", size = Vector3.new(1, 1, 0.546), offset = Vector3.new(0, 0, 0), tris = 656 },
	horseshoe = {
		key = "r8_clover_horseshoe",
		size = Vector3.new(1.8571, 1.6918, 0.264),
		offset = Vector3.new(0, -0.0841, 0.012),
		tris = 848,
	},
	awning = {
		key = "r8_clover_awning",
		size = Vector3.new(12.922, 3.4, 5.9829),
		offset = Vector3.new(0, -1.7, 0.1432),
		tris = 1368,
	},
} :: { [string]: Part }

CloverMeshes.Pivots = {
	eyeL = Vector3.new(-0.5605, 0.4788, 0.8795),
	eyeR = Vector3.new(0.5615, 0.4804, 0.8821),
	hat = Vector3.new(0.255, 1.207, 0.255),
	armL = Vector3.new(-1.36, -0.34, 0.0425),
	armR = Vector3.new(1.36, -0.34, 0.0425),
}
CloverMeshes.HatRest = CFrame.new(0, 0, 0, 0.9703, -0.23957, -0.03367, 0.24192, 0.96085, 0.13504, 0, -0.13917, 0.99027)

function CloverMeshes.part(name: string): Part
	return CloverMeshes.Parts[name]
end

local function localMeshes(): boolean
	local art = ReplicatedStorage:FindFirstChild("Lane3_LocalArt")
	return RunService:IsStudio() and art ~= nil and art:GetAttribute("CloverMeshes") == true
end

-- "rbxassetid://<id>" once the lead has uploaded the mesh (group-owned); in a Studio place that has the laptop-only preview files
-- (Lane3_LocalArt with the attribute CloverMeshes), the local .mesh; otherwise "".
function CloverMeshes.meshId(key: string): string
	local entry = AssetIds.entry(key)
	if entry == nil then
		return ""
	end
	if AssetIds.UseUploaded and entry.id then
		return "rbxassetid://" .. tostring(entry.id)
	end
	if localMeshes() then
		return "rbxasset://carhop/r8/" .. key .. ".mesh"
	end
	return ""
end

function CloverMeshes.palette(): string
	return AssetIds.image(CloverMeshes.PaletteKey)
end

function CloverMeshes.ready(): boolean
	if CloverMeshes.palette() == "" then
		return false
	end
	for _, p in CloverMeshes.Parts do
		if CloverMeshes.meshId(p.key) == "" then
			return false
		end
	end
	return true
end

return CloverMeshes
