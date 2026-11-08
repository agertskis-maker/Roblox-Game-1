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

export type Part = { key: string, size: Vector3, offset: Vector3 }

-- rig.json from blender-round8/build_clover.py (export); size is the bounding box, offset the box centre from the part's pivot.
CloverMeshes.Parts = {
	body = { key = "r8_clover_body", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	eye = { key = "r8_clover_eye", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	hat = { key = "r8_clover_hat", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	armL = { key = "r8_clover_arm_l", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	armR = { key = "r8_clover_arm_r", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	sign = { key = "r8_clover_sign", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	coin = { key = "r8_clover_coin", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	horseshoe = { key = "r8_clover_horseshoe", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
	awning = { key = "r8_clover_awning", size = Vector3.new(1, 1, 1), offset = Vector3.zero },
} :: { [string]: Part }

CloverMeshes.Pivots = {
	eyeL = Vector3.zero,
	eyeR = Vector3.zero,
	hat = Vector3.zero,
	armL = Vector3.zero,
	armR = Vector3.zero,
}
CloverMeshes.HatRest = CFrame.new()

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
