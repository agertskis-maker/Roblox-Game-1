--!strict
-- The shared park, greybox: fountain plaza and basin, promenade arc, avenues, garden ring,
-- portal approaches, stage and lakeside walks, the S stream with a bridge at every path
-- crossing, the Garage, Stunt Circuit gate, gazebo, food stands, leaderboards and the
-- portal row. Portals are frameless glowing discs in each World's placeholder colour;
-- the locked ones are dimmed behind a chain with a low sign. All placeholders.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.Parent.WorldPalette)

local Park = {}

local SURFACE = Layout.SurfaceY
local park = Layout.Data.park
local W = Layout.planToWorld

local PATH_TOP = SURFACE + 0.08
local STREAM_TOP = SURFACE + 0.06
local BRIDGE_TOP = SURFACE + 0.35

local function polyline(parent: Instance, points: { Vector2 }, width: number, topY: number, options: Kit.PartOptions)
	for i = 1, #points - 1 do
		Kit.strip(parent, W(points[i]), W(points[i + 1]), width, 0.1, topY, options, width * 0.3)
	end
end

-- A box on the ground at a plan-frame centre, its front (-Z of the part) facing `facing`.
local function standing(
	parent: Instance,
	centre: Vector2,
	facing: Vector2,
	size: Vector3,
	baseY: number,
	options: Kit.PartOptions
): Part
	local pos = W(centre, baseY + size.Y / 2)
	return Kit.part(parent, size, CFrame.lookAt(pos, pos + W(facing) - W(Vector2.zero)), options)
end

local function buildPlaza(model: Model)
	Kit.disc(
		model,
		Vector3.zero,
		park.plazaRadius * 2,
		0.3,
		SURFACE + 0.12,
		{ name = "Plaza", color = Palette.Paving, collide = true, castShadow = false }
	)
	-- Fountain: a low rim (under 3, so it never blocks a view) round a water disc
	Kit.disc(
		model,
		Vector3.zero,
		park.basinRadius * 2,
		1.6,
		SURFACE + 1.6,
		{ name = "FountainRim", color = Palette.Cream, collide = true }
	)
	Kit.disc(
		model,
		Vector3.zero,
		park.basinRadius * 2 - 2,
		0.2,
		SURFACE + 1.65,
		{ name = "FountainWater", color = Palette.ShallowWater, castShadow = false }
	)
	Kit.disc(
		model,
		Vector3.zero,
		3,
		2.6,
		SURFACE + 2.8,
		{ name = "FountainSpout", color = Palette.Cream, collide = true }
	)
end

local function buildPaths(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Paths"
	folder.Parent = model
	for _, p in park.paths do
		local colour = if string.find(p.kind, "Promenade") then Palette.Promenade else Palette.Paving
		polyline(
			folder,
			p.points,
			p.width,
			PATH_TOP,
			{ name = p.kind, color = colour, collide = true, castShadow = false }
		)
	end

	local stream = Instance.new("Folder")
	stream.Name = "Stream"
	stream.Parent = model
	polyline(
		stream,
		park.stream,
		park.streamWidth,
		STREAM_TOP + 0.04,
		{ name = "Stream", color = Palette.ShallowWater, castShadow = false }
	)

	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = model
	for i, b in park.bridges do
		local bridge = Instance.new("Model")
		bridge.Name = string.format("Bridge%02d", i)
		bridge:SetAttribute("Path", b.path)
		-- Where the stream crosses at a path junction, two bridges overlap; rails along one
		-- would cut across the other path, so that junction stays open (one wider bridge later).
		local shared = false
		for k, other in park.bridges do
			if k ~= i and (other.at - b.at).Magnitude < (b.span + other.deckWidth) / 2 then
				shared = true
			end
		end
		bridge:SetAttribute("SharedJunction", shared)
		local a = W(b.at - b.dir * b.span / 2)
		local c = W(b.at + b.dir * b.span / 2)
		Kit.strip(
			bridge,
			a,
			c,
			b.deckWidth,
			0.3,
			BRIDGE_TOP,
			{ name = "Deck", color = Palette.Cream, collide = true, castShadow = false },
			0
		)
		local side = Vector2.new(-b.dir.Y, b.dir.X)
		for _, s in if shared then {} else { -1, 1 } do
			local off = side * s * (b.deckWidth / 2 - 0.3)
			Kit.wall(
				bridge,
				W(b.at - b.dir * (b.span / 2 - 1) + off),
				W(b.at + b.dir * (b.span / 2 - 1) + off),
				0.5,
				2.2,
				BRIDGE_TOP,
				{ name = "Rail", color = Palette.Navy, collide = true }
			)
		end
		bridge.Parent = bridges
	end
end

local function buildBuildings(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Buildings"
	folder.Parent = model
	for _, b in park.buildings do
		local building = Instance.new("Model")
		building.Name = b.id
		building:SetAttribute("Placeholder", true)
		local side = Vector2.new(-b.facing.Y, b.facing.X)
		if b.id == "Garage" then
			standing(
				building,
				b.centre,
				b.facing,
				Vector3.new(b.width, b.height, b.depth),
				SURFACE,
				{ name = "Shell", color = Palette.Coral, collide = true }
			)
			standing(
				building,
				b.centre + b.facing * (b.depth / 2 + 0.1),
				b.facing,
				Vector3.new(14, 10, 0.4),
				SURFACE,
				{ name = "Door", color = Palette.Navy, castShadow = false }
			)
		elseif b.id == "StuntGate" then
			for _, s in { -1, 1 } do
				standing(
					building,
					b.centre + side * s * (b.width / 2 - 3),
					b.facing,
					Vector3.new(6, b.height, b.depth),
					SURFACE,
					{ name = "Pillar", color = Palette.Yellow, collide = true }
				)
			end
			standing(
				building,
				b.centre,
				b.facing,
				Vector3.new(b.width, 3, b.depth),
				SURFACE + b.height - 3,
				{ name = "Lintel", color = Palette.Yellow, collide = true }
			)
		elseif b.id == "Gazebo" then
			standing(
				building,
				b.centre,
				b.facing,
				Vector3.new(b.width, 0.6, b.depth),
				SURFACE,
				{ name = "Floor", color = Palette.Cream, collide = true }
			)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					standing(
						building,
						b.centre + side * sx * (b.width / 2 - 1) + b.facing * sz * (b.depth / 2 - 1),
						b.facing,
						Vector3.new(1, b.height - 1.5, 1),
						SURFACE + 0.6,
						{ name = "Post", color = Palette.Cream, collide = true }
					)
				end
			end
			standing(
				building,
				b.centre,
				b.facing,
				Vector3.new(b.width + 2, 1.5, b.depth + 2),
				SURFACE + b.height - 1.5,
				{ name = "Roof", color = Palette.Coral }
			)
		else -- FoodStands: three stalls
			for k = -1, 1 do
				standing(
					building,
					b.centre + side * k * (b.width / 3),
					b.facing,
					Vector3.new(b.width / 3 - 2, b.height, b.depth),
					SURFACE,
					{ name = "Stall", color = if k == 0 then Palette.Yellow else Palette.Mint, collide = true }
				)
			end
		end
		building.Parent = folder
	end

	for _, board in park.boards do
		local m = Instance.new("Model")
		m.Name = board.id
		m:SetAttribute("Placeholder", true)
		standing(
			m,
			board.centre,
			Vector2.new(0, 1),
			Vector3.new(board.width, board.height - 4, board.depth),
			SURFACE + 4,
			{ name = "Board", color = Palette.Navy, collide = true }
		)
		for _, s in { -1, 1 } do
			standing(
				m,
				board.centre + Vector2.new(s * (board.width / 2 - 1), 0),
				Vector2.new(0, 1),
				Vector3.new(1, 4, 1),
				SURFACE,
				{ name = "Leg", color = Palette.Navy, collide = true }
			)
		end
		m.Parent = folder
	end
end

local WORLD_COLOURS: { [string]: Color3 } = {
	Downtown = Palette.PortalDowntown,
	DustyHighway = Palette.PortalDustyHighway,
	SummitPass = Palette.PortalSummitPass,
}
-- Downtown is the first World; the others open later (outline 08 and the GDD).
local LOCKED: { [string]: boolean } = { Downtown = false, DustyHighway = true, SummitPass = true }

local function buildPortals(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Portals"
	folder.Parent = model
	local spec = park.portal
	local north = Vector2.new(0, 1)
	for _, q in park.portals do
		local portal = Instance.new("Model")
		portal.Name = q.id
		portal:SetAttribute("Placeholder", true)
		portal:SetAttribute("Locked", LOCKED[q.id])
		local colour = WORLD_COLOURS[q.id]
		local locked = LOCKED[q.id]
		local centre = Vector2.new(q.x, spec.frontY - spec.depth / 2)
		standing(
			portal,
			centre,
			north,
			Vector3.new(spec.width, 0.3, spec.depth),
			SURFACE,
			{ name = "Pad", color = Palette.Rock, collide = true, castShadow = false }
		)
		local discY = SURFACE + spec.width / 2 + 2
		local discCFrame = CFrame.new(W(centre, discY)) * CFrame.Angles(0, math.rad(90), 0)
		local glow = Kit.part(portal, Vector3.new(0.6, spec.width, spec.width), discCFrame, {
			name = "Swirl",
			color = if locked then colour:Lerp(Palette.Navy, 0.55) else colour,
			material = if locked then Enum.Material.SmoothPlastic else Enum.Material.Neon,
			transparency = if locked then 0.25 else 0.1,
			shape = Enum.PartType.Cylinder,
			castShadow = false,
		})
		Kit.part(portal, Vector3.new(0.3, spec.width + 4, spec.width + 4), discCFrame * CFrame.new(-1, 0, 0), {
			name = "Halo",
			color = colour,
			material = Enum.Material.Neon,
			transparency = if locked then 0.9 else 0.7,
			shape = Enum.PartType.Cylinder,
			castShadow = false,
		})
		if not locked then
			local light = Instance.new("PointLight")
			light.Color = colour
			light.Range = 30
			light.Brightness = 2
			light.Parent = glow
		else
			-- chain placeholder: an X of bars and a padlock across the dimmed swirl
			local front = W(centre + north * 0.8, discY)
			for _, tilt in { 45, -45 } do
				Kit.part(
					portal,
					Vector3.new(spec.width * 1.05, 0.9, 0.9),
					CFrame.new(front) * CFrame.Angles(0, 0, math.rad(tilt)),
					{ name = "Chain", color = Palette.Chain, material = Enum.Material.Metal }
				)
			end
			Kit.part(
				portal,
				Vector3.new(3, 3.5, 1.4),
				CFrame.new(front + Vector3.new(0, -1, -0.8)),
				{ name = "Padlock", color = Palette.Chain, material = Enum.Material.Metal }
			)
			-- low sign in front (under 3 tall so it stays out of the viewing corridors)
			standing(
				portal,
				centre + Vector2.new(spec.width / 2 - 2, spec.depth / 2 + 2),
				north,
				Vector3.new(6, 2.8, 0.6),
				SURFACE,
				{ name = "LockSign", color = Palette.Cream, collide = true }
			)
		end
		portal.Parent = folder
	end
end

function Park.build(model: Model)
	buildPlaza(model)
	buildPaths(model)
	buildBuildings(model)
	buildPortals(model)
end

return Park
