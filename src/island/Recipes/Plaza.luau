--!strict
-- Central plaza, Stage A greybox: promenade, plaza and court discs, the Garage footprint
-- (floor, back wall with door and passages, roof outline), three turntables, the portal
-- row, the Stunt Circuit gate and the two leaderboard slabs. Footprints and walls only.

local Kit = require(script.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.WorldPalette)

local PlazaRecipe = {}

local SURFACE = Layout.SurfaceY

local function P(bearing: number, radius: number, y: number?): Vector3
	return Layout.plazaToWorld(Layout.polar(bearing, radius), y)
end

local function inGap(bearing: number): boolean
	local g = Layout.Garage
	local doorHalf = math.deg(math.asin(g.doorHalfWidth / g.wallRadius))
	local passHalf = math.deg(math.asin(g.passageHalfWidth / g.wallRadius))
	if math.abs(bearing) <= doorHalf then
		return true
	end
	for _, p in g.passages do
		if math.abs(bearing - p) <= passHalf then
			return true
		end
	end
	return false
end

function PlazaRecipe.build(plazaModel: Model, helpers: Folder)
	local plaza = Layout.Plaza
	local floor = Instance.new("Folder")
	floor.Name = "Floor"
	Kit.disc(
		floor,
		Vector3.zero,
		plaza.promenadeOuter * 2,
		0.4,
		SURFACE + 0.06,
		{ name = "Promenade", color = Palette.Promenade, collide = true, castShadow = false }
	)
	Kit.disc(
		floor,
		Vector3.zero,
		plaza.plazaRadius * 2,
		0.4,
		SURFACE + 0.08,
		{ name = "Plaza", color = Palette.Paving, collide = true, castShadow = false }
	)
	Kit.disc(
		floor,
		Vector3.zero,
		plaza.courtRadius * 2,
		0.4,
		SURFACE + 0.1,
		{ name = "Court", color = Palette.Court, collide = true, castShadow = false }
	)
	floor.Parent = plazaModel

	-- Garage
	local g = Layout.Garage
	local garage = Instance.new("Model")
	garage.Name = "Garage"
	local mid = (g.floorInner + g.floorOuter) / 2
	local step = 5
	for b = -g.span, g.span - step, step do
		Kit.strip(
			garage,
			P(b, mid),
			P(b + step, mid),
			g.floorOuter - g.floorInner,
			0.3,
			SURFACE + 0.14,
			{ name = "Floor", color = Palette.Cream, collide = true, castShadow = false },
			1.2
		)
	end
	local wallStep = 2.5
	for b = -g.span, g.span - wallStep, wallStep do
		if not inGap(b + wallStep / 2) then
			Kit.wall(
				garage,
				P(b, g.wallRadius),
				P(b + wallStep, g.wallRadius),
				1,
				8,
				SURFACE,
				{ name = "BackWall", color = Palette.Navy, collide = true }
			)
		end
	end
	local turntables = Instance.new("Folder")
	turntables.Name = "Turntables"
	turntables.Parent = garage
	local spots = { { 0, g.heroRadius, "Hero" } }
	for _, b in g.flanks do
		table.insert(spots, { b, g.flankRadius, if b < 0 then "FlankWest" else "FlankEast" })
	end
	for _, spot in spots do
		local c = P(spot[1] :: number, spot[2] :: number)
		Kit.disc(
			turntables,
			c,
			g.turntableRim,
			0.5,
			SURFACE + 0.3,
			{ name = (spot[3] :: string) .. "Rim", color = Palette.Navy, collide = true, castShadow = false }
		)
		local platform = Kit.disc(
			turntables,
			c,
			g.turntablePlatform,
			0.5,
			SURFACE + 0.5,
			{ name = (spot[3] :: string) .. "Platform", color = Palette.Turntable, collide = true, castShadow = false }
		)
		platform:SetAttribute("PlatformDiameter", g.turntablePlatform)
	end
	garage.Parent = plazaModel

	-- Portal row: one arch shape, three colours
	local portalColors = { Palette.Coral, Color3.fromRGB(217, 138, 86), Color3.fromRGB(143, 181, 216) }
	local pr = Layout.Portals
	local portals = Instance.new("Model")
	portals.Name = "Portals"
	for i, x in pr.xs do
		local arch = Instance.new("Model")
		arch.Name = pr.names[i]
		local pillarWidth = (pr.outerWidth - pr.opening) / 2
		for _, side in { -1, 1 } do
			local px = x + side * (pr.opening / 2 + pillarWidth / 2)
			Kit.part(
				arch,
				Vector3.new(pillarWidth, pr.height, pr.depth),
				CFrame.new(Layout.plazaToWorld(Vector2.new(px, pr.lineY), SURFACE + pr.height / 2)),
				{ name = "Pillar", color = portalColors[i], collide = true }
			)
		end
		Kit.part(
			arch,
			Vector3.new(pr.outerWidth, 2, pr.depth),
			CFrame.new(Layout.plazaToWorld(Vector2.new(x, pr.lineY), SURFACE + pr.height - 1)),
			{ name = "Crown", color = portalColors[i] }
		)
		arch.Parent = portals
	end
	portals.Parent = plazaModel

	-- Stunt Circuit gate (west), opening along north-south
	local st = Layout.Stunt
	local stunt = Instance.new("Model")
	stunt.Name = "StuntGate"
	local c = Layout.polar(st.bearing, st.radius)
	local pillarWidth = (st.outerWidth - st.opening) / 2
	for _, side in { -1, 1 } do
		local p = c + Vector2.new(0, side * (st.opening / 2 + pillarWidth / 2))
		Kit.part(
			stunt,
			Vector3.new(st.depth, st.height, pillarWidth),
			CFrame.new(Layout.plazaToWorld(p, SURFACE + st.height / 2)),
			{ name = "Pillar", color = Palette.Yellow, collide = true }
		)
	end
	Kit.part(
		stunt,
		Vector3.new(st.depth, 2, st.outerWidth),
		CFrame.new(Layout.plazaToWorld(c, SURFACE + st.height - 1)),
		{ name = "Beam", color = Palette.Yellow }
	)
	stunt.Parent = plazaModel

	-- Leaderboards (honest empty slabs; no data)
	local bd = Layout.Boards
	local boards = Instance.new("Model")
	boards.Name = "Leaderboards"
	for i, b in bd.bearings do
		local pos = P(b, bd.radius, SURFACE + bd.height / 2)
		Kit.part(
			boards,
			Vector3.new(bd.width, bd.height, bd.depth),
			CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
			{ name = "Board" .. i, color = Palette.Navy, collide = true }
		)
	end
	boards.Parent = plazaModel

	-- Helpers: roof outline and labels
	local h = Instance.new("Folder")
	h.Name = "Plaza"
	for _, r in { g.roofInner, g.roofOuter } do
		for b = -g.span, g.span - step, step do
			Kit.strip(
				h,
				P(b, r),
				P(b + step, r),
				0.5,
				0.05,
				SURFACE + 0.2,
				{ name = "RoofOutline", color = Palette.HelperClearance, castShadow = false },
				0.2
			)
		end
	end
	Kit.label(h, P(0, 40, SURFACE + 14), "GARAGE: floor r 30-48, roof r 28-50, crest 22 (Stage B)", 14)
	Kit.label(h, P(0, g.heroRadius, SURFACE + 4), "Turntables 17 (car turns in 13.74)", 13)
	Kit.label(
		h,
		Layout.plazaToWorld(Vector2.new(0, pr.lineY), SURFACE + 19),
		"Portals: Downtown (east), Dusty Highway, Summit Pass (west)",
		13
	)
	Kit.label(h, Layout.plazaToWorld(c, SURFACE + 17), "Stunt Circuit gate (coming soon)", 13)
	Kit.label(h, P(90, bd.radius, SURFACE + 19), "Leaderboards (empty)", 13)
	h.Parent = helpers
end

return PlazaRecipe
