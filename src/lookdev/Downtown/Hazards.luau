--!strict
-- Part-built HAZARD FALLBACKS for the Downtown look-dev fixture (Lane 3 preview). Builder uses
-- them only when a direction's layout has no hazard meshes of that group, so the fixture is
-- always complete. Non-functional previews at the fixture positions (identical in A, B, C):
--   construction: lane 4, s 100..125 (barriers, 8 cones, one sign); crane on the lot behind
--                 the right sidewalk, its jib pointing away from the road (never over it)
--   pothole:      lane 2, s 172, 2.5 across x 3.5 along, darker core, lighter broken rim
--   oil slick:    lane 3, s 205, 6 across x 4 along, dark glossy with a faint rainbow sheen
-- Each group is a labelled Model with attribute Proxy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fixture = require(script.Parent.Fixture)
local Parts = require(script.Parent.Parts)
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Hazards = {}

export type Groups = { construction: boolean?, pothole: boolean?, oil: boolean? }

local ORANGE = Color3.fromRGB(255, 122, 26)
local WHITE = Color3.fromRGB(246, 244, 238)
local CRANE = Color3.fromRGB(255, 190, 40)
local STEEL = Color3.fromRGB(96, 102, 116)

local function group(parent: Instance, name: string, note: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Proxy", note)
	m:SetAttribute("Hazard", true)
	m.Parent = parent
	return m
end

local function cone(parent: Instance, at: CFrame)
	Parts.block(parent, "ConeBase", Vector3.new(1.5, 0.2, 1.5), at * CFrame.new(0, 0.1, 0), ORANGE)
	local tiers = {
		{ 1.2, 0.8, ORANGE },
		{ 0.95, 0.5, WHITE },
		{ 0.75, 0.5, ORANGE },
		{ 0.55, 0.45, WHITE },
		{ 0.35, 0.4, ORANGE },
	}
	local y = 0.2
	for _, tier in tiers do
		local dia, h, colour = tier[1] :: number, tier[2] :: number, tier[3] :: Color3
		local p = Parts.block(
			parent,
			"Cone",
			Vector3.new(h, dia, dia),
			at * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			colour,
			Enum.PartType.Cylinder
		)
		p.CastShadow = true
		y += h
	end
end

-- An A-frame barrier board 6 long, striped orange/white, its long side along `at`'s X axis.
local function barrier(parent: Instance, at: CFrame)
	for _, x in { -2.4, 2.4 } do
		Parts.block(parent, "BarrierLeg", Vector3.new(0.3, 3, 1.4), at * CFrame.new(x, 1.5, 0), STEEL)
	end
	for i = 0, 4 do
		local colour = if i % 2 == 0 then ORANGE else WHITE
		Parts.block(
			parent,
			"BarrierBoard",
			Vector3.new(1.2, 0.9, 0.25),
			at * CFrame.new(-2.4 + i * 1.2, 2.35, 0),
			colour
		)
	end
	for i = 0, 4 do
		local colour = if i % 2 == 0 then WHITE else ORANGE
		Parts.block(
			parent,
			"BarrierBoard",
			Vector3.new(1.2, 0.5, 0.25),
			at * CFrame.new(-2.4 + i * 1.2, 1.25, 0),
			colour
		)
	end
end

local function workSign(parent: Instance, at: CFrame)
	Parts.block(parent, "SignPost", Vector3.new(0.25, 5, 0.25), at * CFrame.new(0, 2.5, 0.15), STEEL)
	local panel = Parts.block(
		parent,
		"SignPanel",
		Vector3.new(3.2, 3.2, 0.15),
		at * CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.rad(45)),
		ORANGE
	)
	local face = Parts.block(parent, "SignFace", Vector3.new(4.2, 1.6, 0.05), at * CFrame.new(0, 5.6, -0.1), ORANGE)
	face.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.MaxDistance = 300
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.FontFace = Tokens.font()
	text.TextColor3 = Tokens.Color.Text
	text.Text = "ROAD\nWORK"
	text.Parent = gui
	gui.Parent = face
	panel.CastShadow = true
end

local function construction(parent: Instance)
	local m = group(parent, "Hazard_Construction", "part-built construction group (fallback for missing hazard meshes)")
	local laneD = Fixture.laneCentre(4) -- 18.75
	local edgeD = Fixture.HALF_WIDTH - Fixture.LANE_WIDTH -- lane 3/4 line, 12.5
	-- 4 taper cones before the zone, 4 along the lane line inside it
	for i = 0, 3 do
		local s = 90 + i * 3.3
		local d = (Fixture.HALF_WIDTH - 1.5) + (edgeD + 0.8 - (Fixture.HALF_WIDTH - 1.5)) * (i / 3)
		cone(m, Fixture.frame(s, d))
	end
	for i = 0, 3 do
		cone(m, Fixture.frame(104 + i * 6.5, edgeD + 0.8))
	end
	-- a barrier across the lane at the start, two along it
	barrier(m, Fixture.frame(101, laneD))
	barrier(m, Fixture.frame(112, edgeD + 2.2) * CFrame.Angles(0, math.pi / 2, 0))
	barrier(m, Fixture.frame(121, edgeD + 2.2) * CFrame.Angles(0, math.pi / 2, 0))
	-- work sign on the right sidewalk ahead of the zone, facing the driver
	workSign(m, Fixture.frame(86, Fixture.HALF_WIDTH + 4, Fixture.CURB_HEIGHT) * CFrame.Angles(0, math.pi, 0))

	-- crane on a lot behind the right sidewalk; the counter-jib stops well short of the road
	local base = Fixture.frame(112, Fixture.FRONTAGE + 22)
	-- local +X points away from the road
	Parts.block(m, "CraneFooting", Vector3.new(9, 1.6, 9), base * CFrame.new(0, 0.8, 0), STEEL)
	local mastH = 62
	for _, c in { { -1.2, -1.2 }, { 1.2, -1.2 }, { -1.2, 1.2 }, { 1.2, 1.2 } } do
		Parts.block(m, "CraneMast", Vector3.new(0.5, mastH, 0.5), base * CFrame.new(c[1], 1.6 + mastH / 2, c[2]), CRANE)
	end
	for y = 6, mastH, 8 do
		for _, side in { -1.2, 1.2 } do
			Parts.block(m, "CraneLattice", Vector3.new(2.9, 0.35, 0.35), base * CFrame.new(0, 1.6 + y, side), CRANE)
			Parts.block(m, "CraneLattice", Vector3.new(0.35, 0.35, 2.9), base * CFrame.new(side, 1.6 + y, 0), CRANE)
		end
	end
	local top = 1.6 + mastH
	Parts.block(m, "CraneCab", Vector3.new(3.6, 3, 3.6), base * CFrame.new(0, top + 1.5, 0), WHITE)
	Parts.block(m, "CraneJib", Vector3.new(44, 1.6, 1.6), base * CFrame.new(22, top + 3.8, 0), CRANE)
	Parts.block(m, "CraneCounterJib", Vector3.new(10, 1.4, 1.6), base * CFrame.new(-5, top + 3.8, 0), CRANE)
	Parts.block(m, "CraneWeight", Vector3.new(3, 3, 2.4), base * CFrame.new(-8.5, top + 2.6, 0), STEEL)
	Parts.block(m, "CraneTower", Vector3.new(1, 7, 1), base * CFrame.new(0, top + 7, 0), CRANE)
	Parts.block(m, "CraneCable", Vector3.new(0.15, 26, 0.15), base * CFrame.new(30, top + 3 - 13, 0), STEEL)
	Parts.block(m, "CraneHook", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(30, top + 3 - 26.6, 0), ORANGE)
end

local function pothole(parent: Instance)
	local m = group(parent, "Hazard_Pothole", "part-built pothole (fallback for a missing hazard mesh)")
	local at = Fixture.frame(172, Fixture.laneCentre(2))
	-- overlapping circles give a 2.5 x 3.5 oval; rim, hole and deep core stacked a hair apart
	for _, z in { -0.55, 0.55 } do
		Parts.disc(m, "PotholeRim", 3.0, 0.04, at * CFrame.new(0, 0.02, z), Color3.fromRGB(150, 146, 138))
		Parts.disc(m, "PotholeHole", 2.4, 0.04, at * CFrame.new(0.05, 0.045, z * 0.95), Color3.fromRGB(38, 38, 44))
		Parts.disc(m, "PotholeCore", 1.5, 0.04, at * CFrame.new(0.1, 0.07, z * 0.7), Color3.fromRGB(16, 16, 20))
	end
	-- a few broken-edge chips
	for i, offset in { Vector3.new(1.35, 0.05, -1.2), Vector3.new(-1.3, 0.05, 0.9), Vector3.new(0.6, 0.05, 1.85) } do
		Parts.block(
			m,
			"PotholeChip",
			Vector3.new(0.45, 0.08, 0.3),
			at * CFrame.new(offset) * CFrame.Angles(0, i * 0.9, 0),
			Color3.fromRGB(172, 168, 160)
		).CastShadow =
			false
	end
end

local function oil(parent: Instance)
	local m = group(parent, "Hazard_OilSlick", "part-built oil slick (fallback for a missing hazard mesh)")
	local at = Fixture.frame(205, Fixture.laneCentre(3))
	local body = Color3.fromRGB(20, 22, 32)
	for _, spot in { { -1, 0, 4 }, { 1, 0, 4 }, { 2.1, 0.8, 1.8 }, { -2.0, -0.9, 1.9 } } do
		local p = Parts.disc(m, "OilBody", spot[3], 0.04, at * CFrame.new(spot[1], 0.03, spot[2]), body)
		p.Reflectance = 0.3
	end
	-- faint rainbow sheen: two semi-transparent tints and a soft highlight
	local sheen = {
		{ -0.9, 0.35, 2.2, Color3.fromRGB(70, 180, 190) },
		{ 1.1, -0.4, 1.7, Color3.fromRGB(165, 95, 205) },
		{ 0.2, 0.9, 1.2, Color3.fromRGB(235, 205, 90) },
	}
	for _, s in sheen do
		local p = Parts.disc(
			m,
			"OilSheen",
			s[3] :: number,
			0.02,
			at * CFrame.new(s[1] :: number, 0.06, s[2] :: number),
			s[4] :: Color3
		)
		p.Transparency = 0.72
	end
	local glint = Parts.block(
		m,
		"OilGlint",
		Vector3.new(1.6, 0.02, 0.25),
		at * CFrame.new(-0.6, 0.075, -0.8) * CFrame.Angles(0, 0.4, 0),
		WHITE
	)
	glint.Transparency = 0.55
	glint.CastShadow = false
end

-- Builds the requested fallback groups under `parent`; returns the names built.
function Hazards.build(parent: Instance, groups: Groups): { string }
	local built = {}
	if groups.construction then
		construction(parent)
		table.insert(built, "construction")
	end
	if groups.pothole then
		pothole(parent)
		table.insert(built, "pothole")
	end
	if groups.oil then
		oil(parent)
		table.insert(built, "oil")
	end
	return built
end

-- Mesh-name patterns (lower case) that count as D1's hazard meshes for each group.
Hazards.PATTERNS = table.freeze({
	construction = { "cone", "barrier", "crane", "construction", "roadwork" },
	pothole = { "pothole" },
	oil = { "oilslick", "oil_slick", "oil-slick", "slick" },
})

return Hazards
