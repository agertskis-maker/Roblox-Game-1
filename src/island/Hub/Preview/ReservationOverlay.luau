--!strict
-- DEVELOPMENT OVERLAY (Lane 3). Draws every stored plot reservation, the sector rays and the
-- viewing corridors as see-through helpers in Workspace.Lane3_IslandPreview.Helpers, so they
-- can be hidden or left out (build({ helpers = false })). Never collides, queries or touches.
-- Future upgrade space is a box as tall as its height allowance; base items are flat.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.Parent.WorldPalette)

local Overlay = {}

local SURFACE = Layout.SurfaceY
local OUTLINE_STEP = 12

local function outline(parent: Instance, bearing: number, poly: { Vector2 }, y: number, colour: Color3, name: string)
	-- resample long outlines so curves stay cheap
	local pts: { Vector2 } = {}
	local stride = math.max(1, math.floor(#poly / 24))
	for i = 1, #poly, stride do
		table.insert(pts, poly[i])
	end
	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]
		if (b - a).Magnitude > 0.01 then
			Kit.strip(
				parent,
				Layout.plotToWorld(bearing, a),
				Layout.plotToWorld(bearing, b),
				0.6,
				0.05,
				y,
				{ name = name, color = colour, transparency = 0.2, castShadow = false },
				0.3
			)
		end
	end
end

local function isRect(poly: { Vector2 }): boolean
	if #poly ~= 4 then
		return false
	end
	for i = 1, 4 do
		local a, b = poly[i], poly[i % 4 + 1]
		if math.abs(a.X - b.X) > 1e-6 and math.abs(a.Y - b.Y) > 1e-6 then
			return false
		end
	end
	return true
end

function Overlay.buildPlot(helpers: Instance, index: number, withLabels: boolean)
	local bearing = Layout.plotBearing(index)
	local folder = Instance.new("Folder")
	folder.Name = string.format("Plot%02d", index)
	for _, r in Layout.Data.reservations do
		local base = r.layer == "base"
		local colour = if base then Palette.HelperBase else Palette.HelperReserve
		if isRect(r.poly) then
			local x0, u0, x1, u1 = Layout.bounds(r.poly)
			local height = if base then 0.1 else math.max(r.height, 0.2)
			local part = Kit.strip(
				folder,
				Layout.plotToWorld(bearing, Vector2.new((x0 + x1) / 2, u0)),
				Layout.plotToWorld(bearing, Vector2.new((x0 + x1) / 2, u1)),
				x1 - x0,
				height,
				SURFACE + 0.07 + height,
				{
					name = r.id,
					color = colour,
					transparency = if base then 0.6 else 0.85,
					castShadow = false,
				},
				0
			)
			if part then
				part:SetAttribute("Use", r.use)
				part:SetAttribute("Occupants", r.occupants)
				part:SetAttribute("Height", r.height)
			end
		else
			outline(folder, bearing, r.poly, SURFACE + 0.09, colour, r.id)
			if #r.ring > 0 then
				outline(folder, bearing, r.ring, SURFACE + 0.09, colour, r.id .. "Inner")
			end
			if r.id == "ElevatedEnvelope" then
				outline(folder, bearing, r.poly, SURFACE + r.height, colour, r.id .. "Top")
			end
		end
		if withLabels then
			local x0, u0, x1, u1 = Layout.bounds(r.poly)
			local label = if r.height > 0 then string.format("%s (h %d)", r.id, r.height) else r.id
			Kit.label(
				folder,
				Layout.plotToWorld(
					bearing,
					Vector2.new((x0 + x1) / 2, (u0 + u1) / 2),
					SURFACE + math.max(r.height, 4) + 2
				),
				label,
				12
			)
		end
	end
	Kit.label(
		folder,
		Layout.plotToWorld(bearing, Vector2.new(0, Layout.StraightsStart + Layout.Straight / 2), SURFACE + 46),
		string.format("PLOT %02d", index),
		28
	)
	folder.Parent = helpers
end

function Overlay.buildHub(helpers: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	local data = Layout.Data
	-- sector rays between plots, from the promenade to the plot outer radius
	for k = 0, data.plotCount do
		local bearing = -90 + data.sectorDeg * k
		Kit.strip(
			folder,
			Layout.planToWorld(Layout.polar(bearing, Layout.EntranceRadius)),
			Layout.planToWorld(Layout.polar(bearing, data.plot.outerRadius)),
			1,
			0.05,
			SURFACE + 0.1,
			{ name = "SectorRay", color = Palette.HelperDivider, transparency = 0.2, castShadow = false },
			0
		)
	end
	-- viewing corridors: entrance to both ends of the portal row
	for i, tri in data.park.corridors do
		for k = 2, 3 do
			local a = Layout.planToWorld(tri[1])
			local b = Layout.planToWorld(tri[k])
			local length = (b - a).Magnitude
			local steps = math.max(1, math.ceil(length / (OUTLINE_STEP * 20)))
			for s = 0, steps - 1 do
				Kit.strip(folder, a:Lerp(b, s / steps), a:Lerp(b, (s + 1) / steps), 0.5, 0.05, SURFACE + 0.2, {
					name = string.format("Corridor%02d", i),
					color = Palette.HelperCentre,
					transparency = 0.4,
					castShadow = false,
				}, 0)
			end
		end
	end
	folder.Parent = helpers
end

return Overlay
