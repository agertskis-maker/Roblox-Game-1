--!strict
-- The World portals' build-time rig (Lane 3). The portals are frameless energy fields drawn and
-- animated on each client (src/client/Home/Island/Portals.client.luau); this module only lays
-- down what every client shares:
--   per World, an invisible anchor at the field centre (its LookVector faces the plots), with the
--   field size and the ground height under it as attributes;
--   per World, the physical requirement sign (a kit mesh, the same for everyone) standing in the
--   portal row beside its field, with an anchor for each plank's face so a client can show its own
--   locked or ready content;
--   a hidden PortalKit folder of the lock pieces (chain link, padlock body and shackle, anchor
--   post), placed at ORIGIN so a client can read each piece's offset from its joint, and the
--   portal textures and sounds as attributes (the client cannot read AssetIds).
-- The lock itself is per player and presentation only (a visual chain is not security): no
-- collision or shared state here depends on any player's lock.

local AssetIds = require(script.Parent.AssetIds)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)

local PortalRig = {}

local park = Layout.Data.park
local ORIGIN = CFrame.new(0, -520, 0)
PortalRig.FieldWidth = 20
PortalRig.FieldHeight = 30
PortalRig.FieldBottom = 2.5 -- above the ground; the field floats over its pool of light

local PIECES = { "ChainLink", "PadlockBody", "PadlockShackle", "ChainAnchorPost" }

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

-- Plan x of each World's sign: in the gap beside its field, in the field's own plane, so from
-- every entrance it sits beside the field and never in front of it.
local SIGN_SIDE = { SummitPass = -1, Downtown = 1, DustyHighway = 1 }

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

		-- the requirement sign beside the field
		local side = SIGN_SIDE[q.id] or 1
		local signX = q.x + side * (PortalRig.FieldWidth / 2 + 4)
		local signGround = groundAt(signX, -planY)
		-- mesh front (+Z) toward the plots (world -Z): a half turn
		local base = CFrame.new(signX, signGround, -planY - 0.4) * CFrame.Angles(0, math.pi, 0)
		local sign = KitAssets.place("PortalSign", base, 1, true)
		sign.Name = q.id .. "Sign"
		sign:SetAttribute("World", q.id)
		sign.Parent = root
		triangles += KitAssets.info("PortalSign").triangles
		-- each plank's face (kit_portal.py): 5.5 x 1.1, centres 4.54, 3.22 and 1.90 up, the face
		-- plane 0.11 in front of the mesh origin (mesh front is +Z); text stays inside 4.6 wide
		for k, z in { 4.54, 3.22, 1.9 } do
			local a = Instance.new("Attachment")
			a.Name = "Plank" .. k
			a.Parent = sign -- parent first: WorldCFrame is relative to the parent part
			a.WorldCFrame = base * CFrame.new(0, z, 0.13)
			a:SetAttribute("Width", 5.5)
			a:SetAttribute("Height", 1.1)
			a:SetAttribute("SafeWidth", 4.6)
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
		for k, v in KitAssets.info(name).meta do
			part:SetAttribute(k, v)
		end
		-- "preview" when the mesh is not uploaded yet: a preview mesh does not reach a playtest,
		-- so the clients build that piece from parts instead
		part:SetAttribute("Source", KitAssets.sources()[name] or "")
	end
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
	-- the sign icons (Figma art) for the clients' requirement sign faces
	for _, name in { "IconLock", "IconPortal", "IconCoin", "IconGarage", "IconTick" } do
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
