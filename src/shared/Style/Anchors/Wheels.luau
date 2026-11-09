--!strict
-- Anchors.Wheels (Round 8, W-02): per-car data keyed by the car model name under ReplicatedStorage.Cars (Normal edition name; Gold,
-- Diamond and Rainbow editions share it: their wheel meshes were measured and match the Normal car to 0.05 stud). Shape frozen in
-- vault/design/specs/lane3-round8-contracts.md; only the owning workstream edits this file.
--
-- MEASURED, not guessed: Car-Hop-Art/review/round8/agents/ws4-measure.js reads every Normal car's .rbxmx in assets/cars. Every
-- car is the same plan: four MeshParts named "<front|rear> <left|right> wheel_geom" whose X axis is the axle; the part position is
-- the hub, Size.X the tyre width, Size.Y the tyre diameter (the bottom touches the pivot's ground plane). Positions are in the
-- car's own space (relative to Model:GetPivot(), unscaled). Left hubs are turned half a turn so +X points OUT of the car on
-- both sides. hideParts: the car's own wheel parts that custom wheels hide. Brian L: nothing in assets/cars was edited; no
-- attachments were added (the hub frames live in this file).
local Types = require(script.Parent.Types)

local PI = math.pi

-- the car's own wheel parts, hidden (Transparency 1) while a custom wheel design is fitted
local OWN_WHEELS =
	{ "front left wheel_geom", "front right wheel_geom", "rear left wheel_geom", "rear right wheel_geom" }

local function right(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function left(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, PI, 0)
end

local function car(
	frontLeft: CFrame,
	frontRight: CFrame,
	rearLeft: CFrame,
	rearRight: CFrame,
	radius: number,
	width: number
): Types.Wheels
	return {
		hubs = { frontLeft, frontRight, rearLeft, rearRight },
		radius = radius,
		width = width,
		hideParts = OWN_WHEELS,
	}
end

local data: { [string]: Types.Wheels } = {
	Apex = car(
		left(-2.688, 0.977, -2.426),
		right(2.671, 0.972, -2.432),
		left(-2.702, 0.972, 3.271),
		right(2.685, 0.988, 3.274),
		0.971,
		0.761
	),
	["Beach Bug"] = car(
		left(-2.662, 1.606, -3.171),
		right(2.668, 1.613, -3.173),
		left(-2.659, 1.611, 3.429),
		right(2.666, 1.609, 3.42),
		1.604,
		1.17
	),
	Bolt = car(
		left(-2.356, 1.024, -3.167),
		right(2.363, 1.026, -3.169),
		left(-2.357, 1.02, 3.324),
		right(2.363, 1.022, 3.325),
		1.022,
		0.713
	),
	Brawler = car(
		left(-2.211, 1.173, -3.125),
		right(2.209, 1.173, -3.119),
		left(-2.278, 1.171, 3.035),
		right(2.277, 1.167, 3.035),
		1.166,
		1.1
	),
	Commuter = car(
		left(-2.612, 1.101, -3.564),
		right(2.618, 1.102, -3.567),
		left(-2.613, 1.105, 3.741),
		right(2.619, 1.103, 3.74),
		1.101,
		0.967
	),
	Cruiser = car(
		left(-2.789, 1.089, -2.945),
		right(2.775, 1.088, -2.94),
		left(-2.797, 1.092, 3.61),
		right(2.783, 1.096, 3.609),
		1.086,
		0.878
	),
	["Desert King"] = car(
		left(-3.016, 1.772, -3.5),
		right(3.024, 1.786, -3.496),
		left(-3.016, 1.801, 3.811),
		right(3.023, 1.795, 3.806),
		1.768,
		1.456
	),
	Executive = car(
		left(-2.558, 1.075, -3.363),
		right(2.556, 1.074, -3.365),
		left(-2.562, 1.074, 3.496),
		right(2.56, 1.073, 3.495),
		1.069,
		0.869
	),
	["Family Hauler"] = car(
		left(-2.244, 0.87, -3.942),
		right(2.235, 0.869, -3.941),
		left(-2.244, 0.869, 3.428),
		right(2.235, 0.87, 3.428),
		0.864,
		1.053
	),
	Minnow = car(
		left(-2.737, 1.178, -2.527),
		right(2.795, 1.18, -2.534),
		left(-2.736, 1.184, 2.744),
		right(2.794, 1.181, 2.738),
		1.178,
		1.032
	),
	Monarch = car(
		left(-2.646, 1.31, -3.426),
		right(2.648, 1.31, -3.428),
		left(-2.645, 1.317, 3.491),
		right(2.647, 1.318, 3.494),
		1.306,
		0.892
	),
	["Night Rider"] = car(
		left(-2.401, 1.092, -3.468),
		right(2.389, 1.091, -3.469),
		left(-2.399, 1.093, 3.102),
		right(2.388, 1.097, 3.103),
		1.087,
		1.106
	),
	["Old Faithful"] = car(
		left(-2.308, 0.928, -3.52),
		right(2.319, 0.929, -3.52),
		left(-2.311, 0.934, 3.241),
		right(2.322, 0.934, 3.241),
		0.929,
		0.874
	),
	Phantom = car(
		left(-2.967, 1.002, -2.937),
		right(2.963, 1.011, -2.942),
		left(-2.972, 1.023, 3.345),
		right(2.967, 1.023, 3.338),
		1.011,
		0.841
	),
	["Pizza Runner"] = car(
		left(-2.304, 0.89, -3.049),
		right(2.288, 0.888, -3.049),
		left(-2.309, 0.894, 3.341),
		right(2.294, 0.891, 3.342),
		0.889,
		0.953
	),
	Putter = car(
		left(-3.175, 1.208, -3.289),
		right(3.15, 1.21, -3.296),
		left(-3.171, 1.207, 3.272),
		right(3.146, 1.207, 3.273),
		1.205,
		1.179
	),
	["Rally Dog"] = car(
		left(-2.714, 1.658, -3.33),
		right(2.718, 1.655, -3.346),
		left(-2.716, 1.667, 3.363),
		right(2.72, 1.662, 3.369),
		1.644,
		1.525
	),
	Rustbucket = car(
		left(-2.831, 1.149, -3.193),
		right(2.804, 1.147, -3.187),
		left(-2.831, 1.161, 3.17),
		right(2.804, 1.158, 3.172),
		1.147,
		1.042
	),
	["Street Kid"] = car(
		left(-2.771, 1.004, -2.773),
		right(2.786, 1.008, -2.779),
		left(-2.786, 1.005, 3.499),
		right(2.801, 1.006, 3.501),
		1.005,
		0.899
	),
	["Sunny Camper"] = car(
		left(-2.439, 0.937, -3.078),
		right(2.431, 0.933, -3.088),
		left(-2.435, 0.935, 2.962),
		right(2.427, 0.936, 2.953),
		0.933,
		1.035
	),
	["Surf Wagon"] = car(
		left(-2.219, 0.872, -3.531),
		right(2.224, 0.875, -3.533),
		left(-2.217, 0.876, 3.1),
		right(2.222, 0.879, 3.099),
		0.873,
		1.003
	),
	Thunder = car(
		left(-2.529, 1.109, -3.074),
		right(2.532, 1.102, -3.077),
		left(-2.527, 1.11, 3.168),
		right(2.531, 1.11, 3.163),
		1.105,
		0.941
	),
	Trailblazer = car(
		left(-2.739, 1.477, -3.32),
		right(2.547, 1.477, -3.327),
		left(-2.74, 1.469, 2.69),
		right(2.548, 1.477, 2.703),
		1.467,
		1.583
	),
	Velvet = car(
		left(-2.561, 1.069, -3.15),
		right(2.559, 1.07, -3.152),
		left(-2.558, 1.075, 3.473),
		right(2.557, 1.074, 3.47),
		1.069,
		0.868
	),
	["Viper Strike"] = car(
		left(-2.944, 0.942, -2.751),
		right(2.869, 0.94, -2.763),
		left(-2.945, 0.979, 3.38),
		right(2.871, 0.98, 3.361),
		0.956,
		0.815
	),
	Workhorse = car(
		left(-2.717, 1.367, -2.924),
		right(2.725, 1.375, -2.933),
		left(-2.725, 1.364, 2.731),
		right(2.734, 1.365, 2.719),
		1.362,
		1.439
	),
	Zip = car(
		left(-2.777, 0.968, -2.797),
		right(2.757, 0.97, -2.786),
		left(-2.786, 0.99, 3.701),
		right(2.766, 0.988, 3.694),
		0.974,
		0.9
	),
}

return data
