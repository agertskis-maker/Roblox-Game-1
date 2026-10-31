--!strict
-- River bridges (Lane 3, build-time): one bridge at every entry of Layout.Data.park.bridges,
-- where a path crosses the Task 4 river loop. Each bridge is a Model "BridgeNN" inside one
-- Model "Bridges" under the given parent:
--   WalkCollider   one invisible, continuous walkable box the full span and deck width, its top
--                  exactly at the path strips' top face, so path, deck and path join flush
--                  (no raised deck lip, no ramp needed: the path strips are cut at the deck ends);
--   RailColliders  two invisible walls along the railings;
--   the look       the kit mesh (Spec.meshes, deck top at mesh y 0) when KitAssets has it and it
--                  loads, otherwise a part-built bridge of the same dimensions: plank deck, side
--                  fascia beams, stone abutments into the banks, a pile bent at mid-span down to
--                  the river bed, and low white railings with end posts.
-- Everything stands below 3 studs above the walking surface (the viewing-corridor rule) and is
-- far below the waterfall sight rays. Building twice leaves exactly one set.
--
-- Plan frame: x east, y north; world X = x, Z = -y.

local Field = require(script.Parent.Field)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)

local Bridges = {}

local rgb = Color3.fromRGB

-- Every dimension in one place. When the river bridge meshes are uploaded nothing here needs to
-- change (they are picked up by name); to force the part-built look, set useMeshes to false.
Bridges.Spec = {
	useMeshes = true,
	meshes = { avenue = "BridgeRiverAvenue", approach = "BridgeRiverApproach" },
	avenueWidth = 16, -- a deck at least this wide uses the avenue mesh (avenues 18, approaches 14)
	deckTop = Layout.SurfaceY + 0.08, -- the path strips' top face (Recipes/Park PATH_TOP)
	deckThickness = 0.5,
	fasciaDepth = 0.75, -- side beams under the deck edge; their bottom stays above the water
	fasciaWidth = 0.4,
	colliderThickness = 1,
	railHeight = 2.6, -- top rail, above the deck
	railInset = 0.35, -- railing line inside the deck edge
	railColliderWidth = 0.4,
	postSize = 0.45,
	postSpacing = 4.4, -- at most; posts are spread evenly over the span
	endPostSize = 0.8,
	endPostHeight = 2.85, -- under the 3-stud corridor rule with the deck top added
	midRailHeight = 1.25,
	abutmentLength = 6, -- along the path, from each deck end toward the water
	abutmentOverhang = 0.5, -- each side, past the deck width
	pierDiameter = 1.2,
	pierInset = 1.6, -- pile centres inside the deck edge
	capDepth = 0.4, -- the beam across the pile heads, under the deck
	bedY = Field.LakeLevel - Field.RiverBedDepth - 0.6, -- supports go below the river bed
	colours = {
		deck = rgb(176, 128, 84),
		fascia = rgb(140, 98, 64),
		rail = rgb(255, 244, 220), -- WorldPalette.Cream
		post = rgb(255, 244, 220),
		cap = rgb(32, 52, 77), -- WorldPalette.Navy, end post caps
		stone = rgb(150, 160, 166),
		pile = rgb(122, 86, 60), -- WorldPalette.Bark
	},
}
local S = Bridges.Spec

export type BridgeData = { path: string, at: Vector2, dir: Vector2, deckWidth: number, span: number }
export type FenceStop = { at: Vector2, dir: Vector2, bridge: number, path: string }

local function bridges(): { BridgeData }
	return (Layout.Data.park :: any).bridges
end

-- How far either side of a bridge's centre a path strip must be cut so it butts the deck end.
function Bridges.pathCut(b: BridgeData): number
	return b.span / 2
end

-- The plan points where a path-side fence must end in a post before a bridge: each deck corner
-- (deck end +- half the deck width). `dir` points from the bridge outward along the path, the
-- way a fence leaving that corner runs.
function Bridges.fenceStops(): { FenceStop }
	local stops: { FenceStop } = {}
	for i, b in bridges() do
		local dir = b.dir.Unit
		local side = Vector2.new(-dir.Y, dir.X)
		for _, s in { -1, 1 } do
			for _, k in { -1, 1 } do
				table.insert(stops, {
					at = b.at + dir * (s * b.span / 2) + side * (k * b.deckWidth / 2),
					dir = dir * s,
					bridge = i,
					path = b.path,
				})
			end
		end
	end
	return stops
end

-- The bridge's frame: origin on the deck top over its centre, X along the path, Y up, Z across.
local function frameOf(b: BridgeData): CFrame
	local d = b.dir.Unit
	local along = Vector3.new(d.X, 0, -d.Y)
	return CFrame.fromMatrix(Vector3.new(b.at.X, S.deckTop, -b.at.Y), along, Vector3.yAxis)
end

local function box(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function collider(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = box(parent, name, size, cf, rgb(255, 255, 255), Enum.Material.SmoothPlastic, true)
	p.Transparency = 1
	p.CastShadow = false
	return p
end

-- Invisible collision shared by both looks: the deck and the two railing lines.
local function colliders(model: Model, frame: CFrame, b: BridgeData)
	collider(
		model,
		"WalkCollider",
		Vector3.new(b.span, S.colliderThickness, b.deckWidth),
		frame * CFrame.new(0, -S.colliderThickness / 2, 0)
	)
	for k, side in { -1, 1 } do
		local z = side * (b.deckWidth / 2 - S.railInset)
		collider(
			model,
			"RailCollider" .. k,
			Vector3.new(b.span, S.railHeight, S.railColliderWidth),
			frame * CFrame.new(0, S.railHeight / 2, z)
		)
	end
end

-- The part-built look (until the river bridge meshes exist), the same dimensions as the meshes.
local function partBuilt(model: Model, frame: CFrame, b: BridgeData)
	local c = S.colours
	local half, w = b.span / 2, b.deckWidth
	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	visual.Parent = model
	-- deck: top flush with the paths (a hair lower than the collider so nothing flickers)
	box(
		visual,
		"Deck",
		Vector3.new(b.span, S.deckThickness, w),
		frame * CFrame.new(0, -S.deckThickness / 2 - 0.005, 0),
		c.deck,
		Enum.Material.WoodPlanks
	)
	for k, side in { -1, 1 } do
		box(
			visual,
			"Fascia" .. k,
			Vector3.new(b.span, S.fasciaDepth, S.fasciaWidth),
			frame * CFrame.new(0, -S.fasciaDepth / 2 - 0.01, side * (w / 2 - S.fasciaWidth / 2 + 0.05)),
			c.fascia,
			Enum.Material.Wood
		)
	end
	-- abutments: stone blocks from the deck ends into the banks, their feet below the bed
	local under = -S.deckThickness - 0.01 -- deck underside, frame y
	local bed = S.bedY - S.deckTop -- river bed, frame y
	local aHeight = under - bed
	for k, s in { -1, 1 } do
		local x = s * (half - S.abutmentLength / 2)
		box(
			visual,
			"Abutment" .. k,
			Vector3.new(S.abutmentLength, aHeight, w + 2 * S.abutmentOverhang),
			frame * CFrame.new(x, bed + aHeight / 2, 0),
			c.stone,
			Enum.Material.Cobblestone
		)
	end
	-- a pile bent at mid-span: two piles to the bed under a cap beam across the deck
	local capBottom = under - S.capDepth
	box(
		visual,
		"PierCap",
		Vector3.new(0.9, S.capDepth, w - 0.6),
		frame * CFrame.new(0, under - S.capDepth / 2, 0),
		c.fascia,
		Enum.Material.Wood
	)
	for k, side in { -1, 1 } do
		local pileHeight = capBottom - bed
		local pile = box(
			visual,
			"Pile" .. k,
			Vector3.new(pileHeight, S.pierDiameter, S.pierDiameter),
			frame * CFrame.new(0, bed + pileHeight / 2, side * (w / 2 - S.pierInset)) * CFrame.Angles(0, 0, math.pi / 2),
			c.pile,
			Enum.Material.Wood
		)
		pile.Shape = Enum.PartType.Cylinder
	end
	-- railings: evenly spaced posts, larger end posts with caps, a top rail and a mid rail
	local gaps = math.max(1, math.ceil(b.span / S.postSpacing))
	for k, side in { -1, 1 } do
		local z = side * (w / 2 - S.railInset)
		for j = 0, gaps do
			local x = -half + b.span * j / gaps
			local isEnd = j == 0 or j == gaps
			if isEnd then
				local inward = if j == 0 then S.endPostSize / 2 else -S.endPostSize / 2
				box(
					visual,
					"EndPost",
					Vector3.new(S.endPostSize, S.endPostHeight - 0.25, S.endPostSize),
					frame * CFrame.new(x + inward, (S.endPostHeight - 0.25) / 2, z),
					c.post,
					Enum.Material.Wood
				)
				box(
					visual,
					"EndPostCap",
					Vector3.new(S.endPostSize + 0.15, 0.25, S.endPostSize + 0.15),
					frame * CFrame.new(x + inward, S.endPostHeight - 0.125, z),
					c.cap,
					Enum.Material.SmoothPlastic
				)
			else
				box(
					visual,
					"Post",
					Vector3.new(S.postSize, S.railHeight, S.postSize),
					frame * CFrame.new(x, S.railHeight / 2, z),
					c.post,
					Enum.Material.Wood
				)
			end
		end
		local railLength = b.span - 2 * S.endPostSize
		box(
			visual,
			"TopRail" .. k,
			Vector3.new(railLength, 0.3, 0.38),
			frame * CFrame.new(0, S.railHeight - 0.15, z),
			c.rail,
			Enum.Material.Wood
		)
		box(
			visual,
			"MidRail" .. k,
			Vector3.new(railLength, 0.22, 0.26),
			frame * CFrame.new(0, S.midRailHeight, z),
			c.rail,
			Enum.Material.Wood
		)
	end
end

-- The kit mesh for this deck width, if the manifest has it and it loads; nil otherwise.
local function meshLook(model: Model, frame: CFrame, b: BridgeData): string?
	if not S.useMeshes then
		return nil
	end
	local name = if b.deckWidth >= S.avenueWidth then S.meshes.avenue else S.meshes.approach
	if not KitAssets.has(name) then
		return nil
	end
	-- the mesh's +X runs along the path; its deck top (mesh y 0) sits on the frame origin
	local ok, part = pcall(KitAssets.place, name, frame, 1, false)
	if not ok then
		model:SetAttribute("MeshError", tostring(part))
		return nil
	end
	local mesh = part :: MeshPart
	-- an oblique crossing has a longer span than the kit's 26-stud deck: stretch the deck along the
	-- path (the mesh is centred on its length) so both ends land on the bank
	local deck = KitAssets.info(name).meta.deck_length or 26
	if b.span > deck then
		mesh.Size = Vector3.new(mesh.Size.X * b.span / deck, mesh.Size.Y, mesh.Size.Z)
	end
	mesh.Name = "Mesh"
	mesh.Parent = model
	return name
end

-- Builds every bridge under `parent` as one Model "Bridges", replacing any earlier set there.
function Bridges.build(parent: Instance): Model
	for _, old in parent:GetChildren() do
		if old.Name == "Bridges" then
			old:Destroy()
		end
	end
	local root = Instance.new("Model")
	root.Name = "Bridges"
	root:SetAttribute("PreviewOf", "Lane 3 river bridges (Task 4)")
	root:SetAttribute("DeckTop", S.deckTop)
	local meshes, built = 0, 0
	for i, b in bridges() do
		local model = Instance.new("Model")
		model.Name = string.format("Bridge%02d", i)
		model:SetAttribute("Path", b.path)
		model:SetAttribute("Span", b.span)
		model:SetAttribute("DeckWidth", b.deckWidth)
		local frame = frameOf(b)
		colliders(model, frame, b)
		local mesh = meshLook(model, frame, b)
		if mesh then
			model:SetAttribute("Look", "mesh " .. mesh)
			meshes += 1
		else
			partBuilt(model, frame, b)
			model:SetAttribute("Look", "parts")
			built += 1
		end
		model.Parent = root
	end
	root:SetAttribute("MeshBridges", meshes)
	root:SetAttribute("PartBridges", built)
	root.Parent = parent
	return root
end

return Bridges
