--!strict
-- The World portals' build-time rig (Lane 3). The energy fields are drawn and animated on each
-- client (src/client/Home/Island/Portals.client.luau); this module only lays down what every
-- client shares:
--   per World, an invisible anchor at the field centre (its LookVector faces the plots), with the
--   field size and the ground height under it as attributes;
--   per World, the gate round the field (PortalGates: two columns, a crest with the World name,
--   inlay bands for the clients to light, colliders), the same for everyone;
--   a hidden PortalKit folder of the lock pieces from the gates kit family (chain runs and wraps,
--   padlock body and shackle, LOCKED plaque, requirement plaque), placed at ORIGIN so a client
--   can read each piece's offset from its joint, with each piece's meta and points as
--   attributes; the World emblems as GUI templates; and the portal textures, sign icons and
--   sounds as attributes (the client cannot read AssetIds).
-- The lock itself is per player and presentation only (a visual chain is not security): no
-- collision or shared state here depends on any player's lock.

local AssetIds = require(script.Parent.AssetIds)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)
local PortalGates = require(script.Parent.PortalGates)

local PortalRig = {}

local park = Layout.Data.park
local ORIGIN = CFrame.new(0, -520, 0)
PortalRig.FieldWidth = 20
PortalRig.FieldHeight = 30
PortalRig.FieldBottom = 2.5 -- above the ground; the field floats over its pool of light

local PIECES = {
	"GateChainRun",
	"GateChainWrap",
	"GatePadlockBody",
	"GatePadlockShackle",
	"GateLockedPlaque",
	"GateRequirementPlaque",
}

local terrainAndPlaza = RaycastParams.new()
terrainAndPlaza.FilterType = Enum.RaycastFilterType.Include

local function groundAt(x: number, z: number): number
	local list: { Instance } = { workspace.Terrain }
	local preview = workspace:FindFirstChild("Lane3_IslandPreview")
	if preview then
		table.insert(list, preview)
	end
	terrainAndPlaza.FilterDescendantsInstances = list
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), terrainAndPlaza)
	return if hit then hit.Position.Y else Layout.SurfaceY
end

function PortalRig.build(parent: Instance): { worlds: number, triangles: number }
	local old = parent:FindFirstChild("Portals")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Portals"
	local spec = park.portal
	local tex = AssetIds.Textures
	local triangles = 0
	for _, q in park.portals do
		-- the field stands where the greybox disc stood, facing the plots (plan +y = world -z)
		local planY = spec.frontY - spec.depth / 2
		local ground = groundAt(q.x, -planY)
		local centre = Vector3.new(q.x, ground + PortalRig.FieldBottom + PortalRig.FieldHeight / 2, -planY)
		local anchor = Instance.new("Part")
		anchor.Name = q.id
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.CFrame = CFrame.lookAt(centre, centre + Vector3.new(0, 0, -1))
		anchor:SetAttribute("World", q.id)
		anchor:SetAttribute("Width", PortalRig.FieldWidth)
		anchor:SetAttribute("Height", PortalRig.FieldHeight)
		anchor:SetAttribute("Ground", ground)
		anchor.Parent = root

		-- the gate: origin on the ground at the field's centre line, mesh front (+Z) toward the
		-- plots (plan +y): yaw = atan2(f.X, -f.Y) with f = (0, 1), a half turn
		local origin = CFrame.new(q.x, ground, -planY) * CFrame.Angles(0, math.pi, 0)
		triangles += PortalGates.build(q.id, origin, groundAt, root)
		-- how far the ground under the columns differs from the centre (the gate stands level)
		local spread = 0
		for _, dx in { -13, 13 } do
			spread = math.max(spread, math.abs(groundAt(q.x + dx, -planY) - ground))
		end
		local gate = root:FindFirstChild(q.id .. "Gate")
		if gate then
			gate:SetAttribute("GroundSpread", math.round(spread * 100) / 100)
		end
	end

	-- the lock pieces, hidden, for the clients to clone
	local kit = Instance.new("Folder")
	kit.Name = "PortalKit"
	kit:SetAttribute("Origin", ORIGIN.Position)
	for _, name in PIECES do
		local part = KitAssets.place(name, ORIGIN, 1)
		part.Transparency = 1
		part.CastShadow = false
		part.Parent = kit
		local info = KitAssets.info(name)
		for k, v in info.meta do
			part:SetAttribute(PortalGates.attributeName(k), v)
		end
		for k, v in info.points do
			part:SetAttribute("pt_" .. PortalGates.attributeName(k), v)
		end
		local w, h = info.meta["sign_faces.1.size.1"], info.meta["sign_faces.1.size.2"]
		if w and h then
			part:SetAttribute("FaceSize", Vector2.new(w, h))
		end
		-- "preview" when the mesh is not uploaded yet: a preview mesh does not reach a playtest,
		-- so the clients build that piece from parts instead
		part:SetAttribute("Source", KitAssets.sources()[name] or "")
	end
	-- the World emblems (the same shapes as the crests) for the clients' padlock faces
	local emblems = Instance.new("Folder")
	emblems.Name = "Emblems"
	for _, q in park.portals do
		PortalGates.emblem(q.id).Parent = emblems
	end
	emblems.Parent = kit
	for _, name in
		{
			"PortalSwirlA",
			"PortalSwirlB",
			"PortalCloudTile",
			"PortalCore",
			"PortalVeil",
			"PortalVeilB",
			"PortalMask",
			"PortalBeam",
			"PortalDepth",
			"PortalCloudBall",
			"PortalCloudBallB",
			"PortalBand",
			"GroundPool",
			"Mote",
			"Ember",
			"Shimmer",
			"Sparkle",
			"Glow",
		}
	do
		local id = (tex :: any)[name]
		if id then
			kit:SetAttribute(name, id)
		end
	end
	-- the sign icons (Figma art) for the clients' requirement plaque faces
	for _, name in { "IconCoin", "IconGarage", "IconTick" } do
		kit:SetAttribute(name, AssetIds.SignArt[name])
	end
	for name, id in AssetIds.Sounds do
		kit:SetAttribute("Sound" .. name, id)
	end
	kit.Parent = root
	root.Parent = parent
	return { worlds = #park.portals, triangles = triangles }
end

return PortalRig
