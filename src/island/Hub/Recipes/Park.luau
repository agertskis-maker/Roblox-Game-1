--!strict
-- The shared park, greybox: fountain plaza and basin, promenade arc, avenues, garden ring,
-- portal approaches, stage and lakeside walks, the S stream with a bridge at every path
-- crossing, the Garage, Stunt Circuit gate, gazebo, food stands, leaderboards and the
-- portal row. Portals are frameless glowing discs in each World's placeholder colour;
-- the locked ones are dimmed behind a chain with a low sign. All placeholders.

local Bridges = require(script.Parent.Parent.Environment.Bridges)
local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.Parent.WorldPalette)

local Park = {}

local SURFACE = Layout.SurfaceY
local park = Layout.Data.park
local W = Layout.planToWorld

local PATH_TOP = SURFACE + 0.08
local STREAM_TOP = SURFACE + 0.06

type Cut = { at: Vector2, half: number }

-- Strips along a polyline; `cuts` leave gaps (where a bridge deck crosses open water).
local function polyline(
	parent: Instance,
	points: { Vector2 },
	width: number,
	topY: number,
	options: Kit.PartOptions,
	cuts: { Cut }?
)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local dir = (b - a) / length
		-- pieces of [0, length] that stay after the cuts
		local pieces = { { 0, length } }
		for _, cut in cuts or {} do
			local s = (cut.at - a):Dot(dir)
			local off = math.abs((cut.at - a):Dot(Vector2.new(-dir.Y, dir.X)))
			if off < 3 then
				local kept = {}
				for _, piece in pieces do
					local c0, c1 = s - cut.half, s + cut.half
					if c1 <= piece[1] or c0 >= piece[2] then
						table.insert(kept, piece)
					else
						if c0 > piece[1] then
							table.insert(kept, { piece[1], c0 })
						end
						if c1 < piece[2] then
							table.insert(kept, { c1, piece[2] })
						end
					end
				end
				pieces = kept
			end
		end
		for _, piece in pieces do
			if piece[2] - piece[1] > 0.05 then
				-- the segment's own ends run on by 0.15 x width (covering the lens between a square
				-- end and the curving plaza edge, and the joints between segments); an end at a
				-- bridge cut stops exactly at the deck. Task 4 review J7: one cut used to drop the
				-- run-on at every end of that segment, leaving grass crescents at the plaza.
				local s0 = if piece[1] <= 0 then -width * 0.15 else piece[1]
				local s1 = if piece[2] >= length then length + width * 0.15 else piece[2]
				Kit.strip(parent, W(a + dir * s0), W(a + dir * s1), width, 0.1, topY, options, 0)
			end
		end
	end
end

-- The environment build (Task 2) writes the lake and stream as terrain water.
local function hasTerrainWater(): boolean
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	return env ~= nil and env:GetAttribute("TerrainWritten") == true
end

-- With the park dressing built (Workspace.Lane3_IslandEnvironment.ParkDressing), the fountain,
-- bridges, gazebo and food stands here stay only as invisible colliders under the kit objects.
local function dressed(): boolean
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	return env ~= nil and env:FindFirstChild("ParkDressing") ~= nil
end

-- With the Task 4 destinations built (Environment/Destinations), the greybox Garage, Stunt gate
-- and leaderboard placeholders are not drawn.
local function hasDestinations(): boolean
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	return env ~= nil and env:FindFirstChild("Destinations") ~= nil
end

local function hidden(o: Kit.PartOptions): Kit.PartOptions
	if dressed() then
		o.transparency = 1
		o.castShadow = false
	end
	return o
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

-- ---------------------------------------------------------------- path joins (Task 4, brief §5)
-- A flat paving triangle (two wedges) with its top at topY, plan corners a, b, c.
local function triangle(parent: Instance, a: Vector2, b: Vector2, c: Vector2, topY: number, colour: Color3)
	local thickness = 0.1
	local A, B, C = W(a, topY - thickness / 2), W(b, topY - thickness / 2), W(c, topY - thickness / 2)
	-- the standard two-wedge triangle: relabel so BC is the longest side, drop the foot of the
	-- apex A onto it, and fill each half with a wedge whose right angle sits at the foot (Task 4
	-- review J7: the earlier orientation test flipped some halves and left grass slivers)
	local ab, ac, bc = B - A, C - A, C - B
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		A, C = C, A
	elseif acd > bcd and acd > abd then
		A, B = B, A
	end
	ab, ac, bc = B - A, C - A, C - B
	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-6 or bc.Magnitude < 0.05 then
		return
	end
	local right = normal.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.05 then
		return
	end
	for _, half in { { B, ab, right, back }, { C, ac, -right, -back } } do
		local corner, edge, r, bk = half[1], half[2], half[3], half[4]
		local len = math.abs(edge:Dot(back))
		if len > 0.05 then
			local w = Instance.new("WedgePart")
			w.Name = "JoinFill"
			w.Anchored = true
			w.CanCollide = true
			w.CastShadow = false
			w.CanTouch = false
			w.Material = Enum.Material.SmoothPlastic
			w.Color = colour
			w.TopSurface = Enum.SurfaceType.Smooth
			w.BottomSurface = Enum.SurfaceType.Smooth
			w.Size = Vector3.new(thickness, height, len)
			w.CFrame = CFrame.fromMatrix((A + corner) / 2, r, up, bk)
			w.Parent = parent
		end
	end
end

local function lineIntersect(p: Vector2, u: Vector2, q: Vector2, v: Vector2): Vector2?
	local den = u.X * v.Y - u.Y * v.X
	if math.abs(den) < 1e-6 then
		return nil
	end
	local d = q - p
	local t = (d.X * v.Y - d.Y * v.X) / den
	return p + u * t
end

local function nearestOn(points: { Vector2 }, p: Vector2): (number, Vector2)
	local best, dir = math.huge, Vector2.new(1, 0)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		if ab.Magnitude > 1e-6 then
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			local d = (p - (a + ab * t)).Magnitude
			if d < best then
				best, dir = d, ab.Unit
			end
		end
	end
	return best, dir
end

-- The four corners where straight edges of path P (through J along dirP, half width hP) and
-- path Q (along dirQ, half width hQ) meet get a chamfer fillet of radius r. A corner is filled
-- only where both paths really continue past it (`onP` and `onQ` say whether a point is paved).
local function filletCorners(
	parent: Instance,
	J: Vector2,
	dirP: Vector2,
	hP: number,
	dirQ: Vector2,
	hQ: number,
	r: number,
	onP: (Vector2) -> boolean,
	onQ: (Vector2) -> boolean,
	colour: Color3
): number
	local nP, nQ = Vector2.new(-dirP.Y, dirP.X), Vector2.new(-dirQ.Y, dirQ.X)
	local made = 0
	for _, sP in { 1, -1 } do
		for _, sQ in { 1, -1 } do
			local C = lineIntersect(J + nP * sP * hP, dirP, J + nQ * sQ * hQ, dirQ)
			if C and (C - J).Magnitude < 4 * (hP + hQ + 1) then
				local u1 = dirP * (if dirP:Dot(nQ) * sQ >= 0 then 1 else -1)
				local u2 = dirQ * (if dirQ:Dot(nP) * sP >= 0 then 1 else -1)
				local cosT = math.clamp(u1:Dot(u2), -0.99, 0.99)
				local theta = math.acos(cosT)
				local t = math.min(r / math.tan(theta / 2), 3 * r)
				local T1, T2 = C + u1 * t, C + u2 * t
				-- the corner must face grass, and each tangent point must sit on its own path edge
				if onP(T1) and onQ(T2) then
					triangle(parent, C - (u1 + u2) * 0.05, T1, T2, PATH_TOP, colour)
					made += 1
				end
			end
		end
	end
	return made
end

-- The round fillets where the paths meet the plaza (Layout.PlazaFillets), each drawn as a
-- triangle fan from the corner where the path edge crosses the plaza circle. Task 4 review J7:
-- straight fillets ended on the circle's tangent line and left thin grass crescents between that
-- line and the curving plaza edge. The fan's inner chord falls inside the plaza disc, under it.
local FILLET_SEGMENTS = 6
local function plazaFillets(parent: Instance, colour: Color3): number
	for _, f in Layout.PlazaFillets do
		local O = f.centre
		local a1 = math.atan2(f.t1.Y - O.Y, f.t1.X - O.X)
		local a2 = math.atan2(f.t2.Y - O.Y, f.t2.X - O.X)
		local sweep = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi -- the short way round
		local prev = f.t1
		for k = 1, FILLET_SEGMENTS do
			local a = a1 + sweep * k / FILLET_SEGMENTS
			local q = O + Vector2.new(math.cos(a), math.sin(a)) * f.radius
			triangle(parent, f.corner, prev, q, PATH_TOP, colour)
			prev = q
		end
	end
	return #Layout.PlazaFillets
end

-- Fills the corners where the paths join each other and the plaza, and the strip between the
-- plaza edge, the three portal approaches and the stage walk (the Task 4 before view showed
-- grass gaps and slivers there).
local function buildJoins(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Joins"
	folder.Parent = model
	local made = 0
	local function onPath(path: any): (Vector2) -> boolean
		return function(p: Vector2): boolean
			local d = nearestOn(path.points, p)
			return d <= path.width / 2 + 0.6
		end
	end
	made += plazaFillets(folder, Palette.Paving)
	for i, P in park.paths do
		local pts = P.points
		-- crossings and T-joins with every later path
		for k = i + 1, #park.paths do
			local Q = park.paths[k]
			local qpts = Q.points
			for a = 1, #pts - 1 do
				for b = 1, #qpts - 1 do
					local p0, p1, q0, q1 = pts[a], pts[a + 1], qpts[b], qpts[b + 1]
					local u, v = p1 - p0, q1 - q0
					local den = u.X * v.Y - u.Y * v.X
					if math.abs(den) > 1e-6 then
						local d = q0 - p0
						local t = (d.X * v.Y - d.Y * v.X) / den
						local s = (d.X * u.Y - d.Y * u.X) / den
						-- inclusive ends with a little slack, so a path ending on another counts
						local slackP, slackQ = 1.5 / u.Magnitude, 1.5 / v.Magnitude
						if t >= -slackP and t <= 1 + slackP and s >= -slackQ and s <= 1 + slackQ then
							local J = p0 + u * t
							made += filletCorners(
								folder,
								J,
								u.Unit,
								P.width / 2,
								v.Unit,
								Q.width / 2,
								math.min(P.width, Q.width) / 2,
								onPath(P),
								onPath(Q),
								if string.find(P.kind, "Promenade") or string.find(Q.kind, "Promenade")
									then Palette.Promenade
									else Palette.Paving
							)
						end
					end
				end
			end
		end
	end
	-- the stage forecourt: between the plaza edge and the stage walk across the portal row
	local pr = park.portal
	local edgeY = pr.frontY + 3 + 5 -- the stage walk's plaza-side edge
	local xMax = pr.spacing + 7
	local step = 5
	local x = -xMax
	while x < xMax - 1e-6 do
		local x1 = math.min(x + step, xMax)
		local y0 = -math.sqrt(math.max(0, park.plazaRadius ^ 2 - x ^ 2)) + 0.4
		local y1 = -math.sqrt(math.max(0, park.plazaRadius ^ 2 - x1 ^ 2)) + 0.4
		local a, b = Vector2.new(x, y0), Vector2.new(x1, y1)
		local c, d = Vector2.new(x1, edgeY - 0.4), Vector2.new(x, edgeY - 0.4)
		triangle(folder, a, b, c, PATH_TOP - 0.005, Palette.Paving)
		triangle(folder, a, c, d, PATH_TOP - 0.005, Palette.Paving)
		made += 2
		x = x1
	end
	folder:SetAttribute("Fillets", made)
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
		hidden({ name = "FountainRim", color = Palette.Cream, collide = true })
	)
	if dressed() then
		return
	end
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
	local water = hasTerrainWater()
	for _, p in park.paths do
		local colour = if string.find(p.kind, "Promenade") then Palette.Promenade else Palette.Paving
		-- each path strip ends exactly at its bridge deck (Task 4: flush decks, no overlap)
		local cuts: { Cut } = {}
		for _, b in park.bridges do
			if b.path == p.kind then
				table.insert(cuts, { at = b.at, half = Bridges.pathCut(b) })
			end
		end
		polyline(
			folder,
			p.points,
			p.width,
			PATH_TOP,
			{ name = p.kind, color = colour, collide = true, castShadow = false },
			cuts
		)
	end

	if not water then
		-- greybox water strip (no terrain yet), kept just under the decks and paths
		local stream = Instance.new("Folder")
		stream.Name = "Stream"
		stream.Parent = model
		polyline(
			stream,
			park.stream,
			park.streamWidth,
			STREAM_TOP,
			{ name = "Stream", color = Palette.ShallowWater, castShadow = false }
		)
	end

	-- one flush bridge at every river crossing (Environment/Bridges, Task 4)
	Bridges.build(model)
end

local function buildBuildings(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Buildings"
	folder.Parent = model
	for _, b in park.buildings do
		if (b.id == "Garage" or b.id == "StuntGate") and hasDestinations() then
			continue
		end
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
				hidden({ name = "Floor", color = Palette.Cream, collide = true })
			)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					standing(
						building,
						b.centre + side * sx * (b.width / 2 - 1) + b.facing * sz * (b.depth / 2 - 1),
						b.facing,
						Vector3.new(1, b.height - 1.5, 1),
						SURFACE + 0.6,
						hidden({ name = "Post", color = Palette.Cream, collide = true })
					)
				end
			end
			if dressed() then
				building.Parent = folder
				continue
			end
			standing(
				building,
				b.centre,
				b.facing,
				Vector3.new(b.width + 2, 1.5, b.depth + 2),
				SURFACE + b.height - 1.5,
				{ name = "Roof", color = Palette.Coral }
			)
		elseif not dressed() then -- FoodStands: three stalls (the dressing has its own stands)
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
		if hasDestinations() then
			continue
		end
		local m = Instance.new("Model")
		m.Name = board.id
		m:SetAttribute("Placeholder", true)
		local facing = board.facing or Vector2.new(0, 1)
		local across = Vector2.new(-facing.Y, facing.X)
		standing(
			m,
			board.centre,
			facing,
			Vector3.new(board.width, board.height - 4, board.depth),
			SURFACE + 4,
			{ name = "Board", color = Palette.Navy, collide = true }
		)
		for _, s in { -1, 1 } do
			standing(
				m,
				board.centre + across * s * (board.width / 2 - 1),
				facing,
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
			-- hidden under the Task 4 portal gate plinths once the island is dressed
			hidden({ name = "Pad", color = Palette.Rock, collide = true, castShadow = false })
		)
		-- with the environment dressed, the frameless fields (Environment/PortalRig and the
		-- client's Portals script) replace the greybox disc, halo, chains and sign
		if dressed() then
			portal.Parent = folder
			continue
		end
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

-- Paved pads under the snack corners (their whole 30 x 28 box) and a round one under the gazebo,
-- each with a one-stud border in the promenade tone; spurs in the layout join them to the paths
-- (Task 4 movement review M4: they stood on lawn with no approach). Paving tops sit with the paths.
local PADS = { SnackCornerEast = "box", SnackCornerWest = "box", Gazebo = "round" }
local BORDER = 1
local function buildPads(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Pads"
	folder.Parent = model
	for _, b in park.buildings do
		local kind = PADS[b.id]
		if kind == "round" then
			local d = math.max(b.width, b.depth) + 6
			local c = W(b.centre)
			Kit.disc(folder, c, d + 2 * BORDER, 0.1, PATH_TOP - 0.01, {
				name = b.id .. "PadBorder",
				color = Palette.Promenade,
				collide = true,
				castShadow = false,
			})
			Kit.disc(folder, c, d, 0.1, PATH_TOP, {
				name = b.id .. "Pad",
				color = Palette.Paving,
				collide = true,
				castShadow = false,
			})
		elseif kind == "box" then
			local pos = W(b.centre)
			local face = W(b.facing) - W(Vector2.zero)
			for _, layer in { { "PadBorder", BORDER, Palette.Promenade, 0.01 }, { "Pad", 0, Palette.Paving, 0 } } do
				local grow = (layer[2] :: number) * 2
				local top = PATH_TOP - (layer[4] :: number)
				local at = Vector3.new(pos.X, top - 0.05, pos.Z)
				Kit.part(folder, Vector3.new(b.width + grow, 0.1, b.depth + grow), CFrame.lookAt(at, at + face), {
					name = b.id .. (layer[1] :: string),
					color = layer[3] :: Color3,
					collide = true,
					castShadow = false,
				})
			end
		end
	end
end

function Park.build(model: Model)
	buildPlaza(model)
	buildPaths(model)
	buildPads(model)
	buildJoins(model)
	buildBuildings(model)
	buildPortals(model)
end

return Park
