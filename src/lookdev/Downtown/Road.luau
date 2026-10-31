--!strict
-- Part-built ROAD PROXY for the Downtown look-dev fixture (Lane 3 preview). Used only when the
-- direction's layout has no road meshes, so every study can still be judged from the chase
-- camera. It follows Fixture exactly: 4 x 12.5 lanes, edge lines, 10-on/10-off dashes, curbs,
-- 12-stud sidewalks, the zebra at s 245 and the 30-stud cross street at s 265. Labelled as a
-- proxy; it is not Lane 1's road and not segment generation.

local Fixture = require(script.Parent.Fixture)
local Parts = require(script.Parent.Parts)

local Road = {}

local ASPHALT = Color3.fromRGB(70, 74, 84)
local PAINT = Color3.fromRGB(244, 242, 234)
local CURB = Color3.fromRGB(196, 192, 184)
local WALK = Color3.fromRGB(218, 212, 200)
local LOT = Color3.fromRGB(206, 200, 186)

local CURVE_STEP = 10 -- studs of centre line per curve segment
local S_FROM, S_TO = -60, 440 -- a little past both ends so the cameras never see the edge
local GAP_FROM = Fixture.INTERSECTION_S - Fixture.CROSS_WIDTH / 2 -- 250
local GAP_TO = Fixture.INTERSECTION_S + Fixture.CROSS_WIDTH / 2 -- 280

-- A band between offsets dLo..dHi, from sFrom to sTo, with its top at yTop. Straights are one
-- part; the curve is cut into segments sized for the band's outer (largest-radius) edge, so
-- the segments meet exactly on the outside and overlap slightly on the inside.
local function band(
	parent: Instance,
	name: string,
	dLo: number,
	dHi: number,
	sFrom: number,
	sTo: number,
	yTop: number,
	thickness: number,
	colour: Color3
): number
	local cuts = { sFrom }
	for _, b in { Fixture.CURVE_START, Fixture.CURVE_END } do
		if b > sFrom and b < sTo then
			table.insert(cuts, b)
		end
	end
	table.insert(cuts, sTo)
	local dMid, width = (dLo + dHi) / 2, dHi - dLo
	local count = 0
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		local mid = (a + b) / 2
		if mid <= Fixture.CURVE_START or mid >= Fixture.CURVE_END then
			Parts.block(
				parent,
				name,
				Vector3.new(width, thickness, b - a),
				Fixture.frame(mid, dMid, yTop - thickness / 2),
				colour
			)
			count += 1
		else
			local n = math.max(1, math.ceil((b - a) / CURVE_STEP))
			local step = (b - a) / n
			local stretch = (Fixture.RADIUS - dLo) / Fixture.RADIUS
			for k = 0, n - 1 do
				Parts.block(
					parent,
					name,
					Vector3.new(width, thickness, step * stretch + 0.02),
					Fixture.frame(a + (k + 0.5) * step, dMid, yTop - thickness / 2),
					colour
				)
				count += 1
			end
		end
	end
	return count
end

-- Builds the proxy road under `parent`; returns the folder and its part count.
function Road.build(parent: Instance): (Folder, number)
	local folder = Instance.new("Folder")
	folder.Name = "RoadProxy"
	folder:SetAttribute("Proxy", "part-built fixture road (preview values), not Lane 1's road")
	folder.Parent = parent
	local count = 0
	local hw = Fixture.HALF_WIDTH

	-- ground under everything (lots and frontage)
	local centre = Fixture.frame(Fixture.LENGTH / 2)
	Parts.block(folder, "Ground", Vector3.new(1600, 1, 1600), centre * CFrame.new(0, -0.6, 0), LOT).CastShadow = false
	count += 1

	count += band(folder, "Asphalt", -hw, hw, S_FROM, S_TO, 0, 1, ASPHALT)

	local walkInner = hw + Fixture.CURB_WIDTH
	local walkOuter = Fixture.FRONTAGE
	for _, piece in { { S_FROM, GAP_FROM }, { GAP_TO, S_TO } } do
		local a, b = piece[1], piece[2]
		for _, side in { -1, 1 } do
			local function sided(lo: number, hi: number): (number, number)
				if side > 0 then
					return lo, hi
				end
				return -hi, -lo
			end
			local eLo, eHi = sided(hw - 0.3 - Fixture.EDGE_LINE, hw - 0.3)
			count += band(folder, "EdgeLine", eLo, eHi, a, b, 0.04, 0.1, PAINT)
			local cLo, cHi = sided(hw, walkInner)
			count += band(folder, "Curb", cLo, cHi, a, b, Fixture.CURB_HEIGHT, 1.4, CURB)
			local wLo, wHi = sided(walkInner, walkOuter)
			count += band(folder, "Sidewalk", wLo, wHi, a, b, Fixture.CURB_HEIGHT, 1.4, WALK)
		end
	end

	-- dashed lane lines, kept clear of the zebra and the intersection
	local period = Fixture.DASH_ON + Fixture.DASH_OFF
	for lane = 1, Fixture.LANES - 1 do
		local d = -hw + Fixture.LANE_WIDTH * lane
		local s = 0
		while s < S_TO do
			local mid = s + Fixture.DASH_ON / 2
			if s + Fixture.DASH_ON < Fixture.ZEBRA_S - 7 or s > GAP_TO + 2 then
				Parts.block(
					folder,
					"LaneDash",
					Vector3.new(Fixture.LANE_LINE, 0.1, Fixture.DASH_ON),
					Fixture.frame(mid, d, 0.03),
					PAINT
				).CastShadow =
					false
				count += 1
			end
			s += period
		end
	end

	-- stylized zebra: 6 bars of 2.5 x 10 just before the intersection
	for i = 1, 6 do
		local d = -hw + (2 * hw / 6) * (i - 0.5)
		Parts.block(folder, "Zebra", Vector3.new(2.5, 0.1, 10), Fixture.frame(Fixture.ZEBRA_S, d, 0.03), PAINT).CastShadow =
			false
		count += 1
	end

	-- cross street at 90 degrees, with curbs and sidewalks on both sides
	local cross = Fixture.frame(Fixture.INTERSECTION_S)
	local half = Fixture.CROSS_WIDTH / 2
	Parts.block(
		folder,
		"CrossAsphalt",
		Vector3.new(600, 1, Fixture.CROSS_WIDTH),
		cross * CFrame.new(0, -0.505, 0),
		ASPHALT
	)
	count += 1
	local reach = 300
	local walkWidth = Fixture.SIDEWALK
	for _, sideF in { -1, 1 } do
		for _, sideR in { -1, 1 } do
			local length = reach - walkInner
			local x = sideR * (walkInner + length / 2)
			Parts.block(
				folder,
				"CrossCurb",
				Vector3.new(length + Fixture.CURB_WIDTH, 1.4, Fixture.CURB_WIDTH),
				cross
					* CFrame.new(
						x - sideR * Fixture.CURB_WIDTH / 2,
						Fixture.CURB_HEIGHT - 0.7,
						-sideF * (half + Fixture.CURB_WIDTH / 2)
					),
				CURB
			)
			Parts.block(
				folder,
				"CrossSidewalk",
				Vector3.new(length, 1.4, walkWidth),
				cross * CFrame.new(x, Fixture.CURB_HEIGHT - 0.7, -sideF * (half + Fixture.CURB_WIDTH + walkWidth / 2)),
				WALK
			)
			count += 2
		end
	end
	return folder, count
end

return Road
