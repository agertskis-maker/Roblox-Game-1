--!strict
-- Raceway parking spots (Lane 3, presentation only; Raceway round 2, Adam 2026-10-29). The Paddock
-- has 15 bays; a plot owns 2 to 15 of them (Adam's decision: everyone starts with 2, more are
-- bought one at a time). Applying a count shows the owned bays as clean cream ground lines, the
-- next bay (if any) as an unowned bay with a short navy-and-cream barrier arm at its mouth and an
-- ADD SPOT plaque, and leaves the bays beyond as plain Paddock floor (no lines, no collision). The
-- parking sign beside the Paddock shows the owned count.
--
-- Proposed contract for Lane 2 (Brian L, vault/design/specs/speedway-levels-for-brian-l.md): the
-- server sets the integer plot attribute "ParkingSpots" (save field ParkingSpots, 2 to 15); every
-- client draws the bays from it (Home/Island/Speedway/ParkingLook). Nothing here prices, pays or
-- saves; the bay markers Lane 2 places cars at (Hub/Markers, Bay01..Bay15) are unchanged.

local Ctx = require(script.Parent.Ctx)
local Kit = require(script.Parent.Kit)

local Parking = {}

type Ctx = Ctx.Ctx

Parking.StartSpots = 2 -- Adam's decision (2026-10-29)
Parking.MaxSpots = 15
-- Round 4 (C-03, decision 0036): the Expanded Paddock pass gives 3 more bays on top of the 15 a plot can buy, so a pass
-- holder can park up to 18. The server marks such a plot with the attribute ExpandedPaddock = true and counts the 3 bays
-- in its ParkingSpots attribute (the saved field stays 2 to 15). The 3 bays sit at the two ends of row A, on a short floor
-- extension past the Paddock's edges (free ground: the pit lanes start behind row A), and the sign moves out to make room.
Parking.ExpandedSpots = 3
Parking.ExpandedMax = Parking.MaxSpots + Parking.ExpandedSpots
Parking.ExpandedAttribute = "ExpandedPaddock"

function Parking.hasExpanded(plot: Instance?): boolean
	return plot ~= nil and plot:GetAttribute(Parking.ExpandedAttribute) == true
end

-- The most bays this plot can have: 18 with the pass, 15 without.
function Parking.maxFor(plot: Instance?): number
	return if Parking.hasExpanded(plot) then Parking.ExpandedMax else Parking.MaxSpots
end

function Parking.clamp(n: number, max: number?): number
	return math.clamp(math.floor(n), Parking.StartSpots, max or Parking.MaxSpots)
end

-- The 15 bays in the order they are owned, as Island/Hub/Layout builds them (repeated here because
-- the bays are drawn on each client; Hub/Preview/SpeedwayChecks compares the two lists): row A (7,
-- nearest the park, cars face the park) then row B (8, cars face the oval), each from the centre out.
-- Plot frame: x to the right facing outward, u from the fountain centre.
local R0 = 247.187 -- the plot entrance radius (HubData plot.entranceRadius)
Parking.RowA = { R0 + 16, R0 + 32 }
Parking.RowB = { R0 + 42, R0 + 58 }
Parking.BayHalfWidth = 4.2 -- the painted outline (bays are 9 wide)

export type Bay = { index: number, row: string, x: number, u: number, back: number, mouth: number }

local function centreOut(count: number): { number }
	local offsets = {}
	for i = 1, count do
		table.insert(offsets, i - (count + 1) / 2)
	end
	table.sort(offsets, function(a, b)
		if math.abs(a) ~= math.abs(b) then
			return math.abs(a) < math.abs(b)
		end
		return a < b
	end)
	return offsets
end

local bays: { Bay } = {}
for _, k in centreOut(7) do
	table.insert(bays, {
		index = 0,
		row = "A",
		x = k * 9,
		u = R0 + 24,
		back = Parking.RowA[1] + 0.3,
		mouth = Parking.RowA[2] - 0.3,
	})
end
for _, k in centreOut(8) do
	table.insert(bays, {
		index = 0,
		row = "B",
		x = k * 9,
		u = R0 + 50,
		back = Parking.RowB[2] - 0.3,
		mouth = Parking.RowB[1] + 0.3,
	})
end
for i, bay in bays do
	bay.index = i
end
Parking.Bays = bays

-- The pass's 3 bays (16, 17, 18): row A's next places out from the centre, past the Paddock's 36-stud half width.
Parking.ExtraBays = table.freeze({
	{ index = 16, row = "A", x = 36, u = R0 + 24, back = Parking.RowA[1] + 0.3, mouth = Parking.RowA[2] - 0.3 },
	{ index = 17, row = "A", x = -36, u = R0 + 24, back = Parking.RowA[1] + 0.3, mouth = Parking.RowA[2] - 0.3 },
	{ index = 18, row = "A", x = 45, u = R0 + 24, back = Parking.RowA[1] + 0.3, mouth = Parking.RowA[2] - 0.3 },
}) :: { Bay }

function Parking.bay(i: number): Bay
	return Parking.Bays[i] or Parking.ExtraBays[i - Parking.MaxSpots]
end

-- the parking sign: in the Paddock's free left margin beside row A (x -36 to -31.5), facing the park
Parking.SignAt = Vector2.new(-33.8, 264.2)
-- with the pass's bays drawn, bay 17 takes that margin: the sign stands further out, past bay 17 (x -40.5)
Parking.ExpandedSignAt = Vector2.new(-46.6, 264.2)
-- the floor extension each side (plot x ranges), row A's depth
Parking.ExtensionX = table.freeze({ { 36, 49.5 }, { -49.5, -36 } })
local FLOOR = Color3.fromRGB(206, 200, 190) -- the Paddock floor (Hub/Recipes/Plot)
local FLOOR_TOP = 0.2

local CREAM = Color3.fromRGB(244, 236, 214)
local LINE_TOP = 0.27 -- just over the Paddock floor (its top is the road's, 0.2 above the surface)

-- The plan direction the bay opens toward (the aisle).
local function opening(bay: Bay): Vector2
	return if bay.row == "A" then Vector2.new(0, 1) else Vector2.new(0, -1)
end
Parking.opening = opening

-- Cream ground lines of one bay: both sides and the back line (open toward the aisle).
function Parking.lines(folder: Instance, ctx: Ctx, bay: Bay): { BasePart }
	local made: { BasePart } = {}
	local h = Parking.BayHalfWidth
	local options = { name = "BayLine", color = CREAM, castShadow = false }
	for _, sx in { -h, h } do
		local p = Kit.slab(
			folder,
			Ctx.at(ctx, bay.x + sx, bay.back, LINE_TOP),
			Ctx.at(ctx, bay.x + sx, bay.mouth, LINE_TOP),
			Vector3.yAxis,
			0.25,
			0.03,
			options,
			0
		)
		if p then
			table.insert(made, p)
		end
	end
	local back = Kit.slab(
		folder,
		Ctx.at(ctx, bay.x - h - 0.125, bay.back, LINE_TOP),
		Ctx.at(ctx, bay.x + h + 0.125, bay.back, LINE_TOP),
		Vector3.yAxis,
		0.25,
		0.03,
		options,
		0
	)
	if back then
		table.insert(made, back)
	end
	return made
end

-- The barrier frame of a bay: the arm's pivot frame (arm along +X, up +Y, the plaque facing the
-- aisle along +Z) and the post's base, so the arm can be turned up about the frame's Z axis.
function Parking.barrierFrames(ctx: Ctx, bay: Bay): (CFrame, CFrame)
	local toAisle = opening(bay)
	-- the arm runs across the bay mouth; X x Y = Z must face the aisle
	local up = Vector3.yAxis
	local z = Ctx.dir(ctx, toAisle)
	local x = up:Cross(z).Unit -- so that x:Cross(up) == z
	local mouthU = bay.mouth - 0.5 * toAisle.Y
	-- the post stands at the end the arm starts from (the -X side of the bay along the frame's X)
	local centre = Ctx.at(ctx, bay.x, mouthU, 0)
	local postFoot = centre - x * (Parking.BayHalfWidth - 0.2)
	local post = CFrame.fromMatrix(postFoot, x, up)
	local pivot = Kit.point("SwBayBarrierPost", "pivot", post) or (postFoot + up * 1.6 + z * 0.32)
	return CFrame.fromMatrix(pivot, x, up), post
end

export type Built = {
	folder: Folder,
	spots: number,
	lines: { [number]: { BasePart } }, -- bay index -> its line parts
	arm: BasePart?, -- the next bay's barrier arm
	armBase: CFrame?, -- its closed frame (the arm lifts about the frame's Z axis)
	plaque: Part?,
	sign: BasePart?,
	signFace: Part?,
	signAnchor: Part?,
}

-- The barrier and plaque of the next (unowned) bay.
local function barrier(folder: Folder, ctx: Ctx, bay: Bay, out: Built)
	local armBase, postBase = Parking.barrierFrames(ctx, bay)
	local post = Kit.place("SwBayBarrierPost", postBase)
	if post then
		post.Name = "BarrierPost"
		post.Parent = folder
	end
	local arm = Kit.place("SwBayBarrierArm", armBase)
	if not arm then
		return
	end
	arm.Name = "BarrierArm"
	arm:SetAttribute("BayIndex", bay.index)
	arm.Parent = folder
	out.arm = arm
	out.armBase = armBase
	local m = Kit.info("SwBayBarrierArm").meta
	local cx, cz = m["plaque.centre.1"], m["plaque.centre.2"]
	local w, h, py = m["plaque.size.1"], m["plaque.size.2"], m["plaque.plane_y"]
	if cx and cz and w and h and py then
		-- recipe (x, y, z) -> mesh-local (x, z, -y): the plaque faces local +Z (the aisle)
		local p = armBase * CFrame.new(cx, cz, -py + 0.03)
		local face = Kit.part(folder, Vector3.new(w, h, 0.02), p, {
			name = "AddSpotPlaque",
			transparency = 1,
			castShadow = false,
		})
		face:SetAttribute("AddSpotPlaque", true)
		face:SetAttribute("PlaqueOffset", armBase:ToObjectSpace(face.CFrame))
		out.plaque = face
	end
end

local function sign(folder: Folder, ctx: Ctx, out: Built, at: Vector2)
	local base = Ctx.face(ctx, at.X, at.Y, Vector2.new(0, -1))
	local board = Kit.place("SwParkingSign", base)
	if not board then
		return
	end
	board.Name = "ParkingSign"
	board.Parent = folder
	out.sign = board
	-- only the post collides (an invisible slim box), so the board never snags a visitor
	Kit.part(folder, Vector3.new(0.4, 3.8, 0.4), base * CFrame.new(0, 1.9, 0), {
		name = "ParkingSignCollider",
		transparency = 1,
		collide = true,
		castShadow = false,
	})
	local m = Kit.info("SwParkingSign").meta
	local cx, cz = m["face.centre.1"] or 0, m["face.centre.2"] or 2.6
	local w, h, py = m["face.size.1"] or 2.8, m["face.size.2"] or 2, m["face.plane_y"] or -0.22
	local p = base:PointToWorldSpace(Vector3.new(cx, cz, -py + 0.03))
	-- the face's Front points the way the board faces (the mesh front, base local +Z)
	local face =
		Kit.part(folder, Vector3.new(w, h, 0.02), CFrame.lookAt(p, p + base:VectorToWorldSpace(Vector3.new(0, 0, 1))), {
			name = "ParkingSignFace",
			transparency = 1,
			castShadow = false,
		})
	face:SetAttribute("ParkingSignFace", true)
	out.signFace = face
	-- 0.7 in front of the board: still inside the Paddock edge (u 263.187), which the sign stands 1 from
	local anchor = Kit.part(folder, Vector3.one * 0.4, base * CFrame.new(0, 2.4, 0.7), {
		name = "ParkingPromptAnchor",
		transparency = 1,
		castShadow = false,
	})
	anchor:SetAttribute("ParkingPromptAnchor", true)
	out.signAnchor = anchor
end

-- Builds the plot's parking look for `spots` owned bays (replacing any earlier one).
function Parking.build(plot: Model, ctx: Ctx, spots: number): Built
	local old = plot:FindFirstChild("ParkingLook")
	if old then
		old:Destroy()
	end
	local max = Parking.maxFor(plot)
	local n = Parking.clamp(spots, max)
	local folder = Instance.new("Folder")
	folder.Name = "ParkingLook"
	folder:SetAttribute("Spots", n)
	folder:SetAttribute("MaxSpots", max)
	local out: Built = { folder = folder, spots = n, lines = {} }
	-- the pass's floor extension and the moved sign, once the base Paddock is full
	local extended = max > Parking.MaxSpots and n >= Parking.MaxSpots
	if extended then
		local ext = Instance.new("Folder")
		ext.Name = "PaddockExtension"
		ext.Parent = folder
		local uMid = (Parking.RowA[1] + Parking.RowA[2]) / 2
		for _, span in Parking.ExtensionX do
			Kit.slab(
				ext,
				Ctx.at(ctx, span[1], uMid, FLOOR_TOP),
				Ctx.at(ctx, span[2], uMid, FLOOR_TOP),
				Vector3.yAxis,
				Parking.RowA[2] - Parking.RowA[1],
				0.3,
				{
					name = "ExtensionFloor",
					color = FLOOR,
					material = Enum.Material.Concrete,
					collide = true,
					castShadow = false,
				},
				0
			)
		end
	end
	for i = 1, n do
		local bay = Parking.bay(i)
		local f = Instance.new("Folder")
		f.Name = string.format("Bay%02d", i)
		f.Parent = folder
		out.lines[i] = Parking.lines(f, ctx, bay)
	end
	if n < max then
		local next = Instance.new("Folder")
		next.Name = "NextBay"
		next.Parent = folder
		barrier(next, ctx, Parking.bay(n + 1), out)
	end
	sign(folder, ctx, out, if extended then Parking.ExpandedSignAt else Parking.SignAt)
	folder.Parent = plot
	return out
end

return Parking
