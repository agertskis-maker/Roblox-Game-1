--!strict
-- Anchors.DecalPanels (Round 8, C-05): where a car's decals may go. One entry per car in ReplicatedStorage.Cars, keyed by the Normal
-- model's name. Gold and Diamond editions use the Normal car's mesh; Rainbow editions have their own mesh files but the same part
-- sizes and positions, so they share the entry (DecalArt looks it up by the CarName attribute). Shape frozen in
-- vault/design/specs/lane3-round8-contracts.md.
--
-- Space: the car's own, at the size the model has in ReplicatedStorage.Cars (DecalArt scales it with the live car): origin at the
-- bottom centre (the pivot), +X to the car's right, +Y up, -Z toward the nose. Each side has one rectangle on the flat body panel
-- (the door or box panel under the window line): it must stay clear of the windows, lights, wheel arches, the nose and tail and the
-- gap between the doors. `left` and `right` are the panel's centre with +Z pointing out of the car and +Y up, so the picture's
-- right edge is toward the tail on the left side and toward the nose on the right side; `size` is the usable length and height.
--
-- STATUS: first pass, worked out from the models' part sizes and CFrames (wheel arch positions, body height, door length, a
-- window line guessed per body type). It is checked and corrected against renders of the real meshes with the audit in
-- src/client/UI/Prototype/Style/DecalAudit.luau; the status line below says when that has been done.
-- CHECKED: not yet (first pass only)
local Types = require(script.Parent.Types)

-- +Z out of the car's right side (+X), the picture's right edge toward the nose
local RIGHT = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.yAxis, Vector3.xAxis)
-- +Z out of the car's left side (-X), the picture's right edge toward the tail
local LEFT = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.yAxis, Vector3.new(-1, 0, 0))

-- panel(depth of the left panel, its centre along the car and up, the same for the right panel, usable length, usable height);
-- depths are how far out from the centre line the body surface is (X is -depth on the left, +depth on the right)
local function panel(
	leftDepth: number,
	leftZ: number,
	leftY: number,
	rightDepth: number,
	rightZ: number,
	rightY: number,
	length: number,
	height: number
): Types.DecalPanels
	return {
		left = CFrame.new(-leftDepth, leftY, leftZ) * LEFT,
		right = CFrame.new(rightDepth, rightY, rightZ) * RIGHT,
		size = Vector2.new(length, height),
	}
end

local data: { [string]: Types.DecalPanels } = {
	["Apex"] = panel(2.96, -0.03, 1.25, 2.96, -0.03, 1.25, 1.76, 1.2),
	["Beach Bug"] = panel(2.71, 0.13, 2.11, 2.71, 0.13, 2.11, 2.27, 0.88),
	["Bolt"] = panel(2.79, -0.5, 1.43, 2.79, -0.5, 1.43, 2.21, 1.44),
	["Brawler"] = panel(2.8, -0.51, 1.91, 2.8, -0.51, 1.91, 1.83, 1.26),
	["Commuter"] = panel(3.07, -1, 2.11, 3.07, -1, 2.11, 1.91, 1.99),
	["Cruiser"] = panel(3.02, -0.23, 1.53, 3.02, -0.23, 1.53, 2.15, 1.5),
	["Desert King"] = panel(3.21, -0.55, 2.49, 3.21, -0.55, 2.49, 1.25, 2.21),
	["Executive"] = panel(2.92, -0.93, 1.78, 2.92, -0.93, 1.78, 1.74, 1.53),
	["Family Hauler"] = panel(2.66, 0.62, 1.97, 2.66, 0.62, 1.97, 2.73, 1.56),
	["Minnow"] = panel(3.48, -0.23, 2.29, 3.48, -0.23, 2.29, 1.3, 2.12),
	["Monarch"] = panel(3.07, -0.85, 2.25, 3.07, -0.85, 2.25, 1.55, 1.96),
	["Night Rider"] = panel(2.88, -0.74, 1.57, 2.88, -0.74, 1.57, 2.17, 1.32),
	["Old Faithful"] = panel(2.79, -1.19, 1.76, 2.79, -1.19, 1.76, 1.84, 1.18),
	["Phantom"] = panel(3.22, -0.34, 1.22, 3.22, -0.34, 1.22, 2.07, 1.13),
	["Pizza Runner"] = panel(2.91, 2.35, 3.3, 2.91, 2.35, 3.3, 3.9, 2.6),
	["Putter"] = panel(3.64, -0.53, 2.58, 3.64, -0.53, 2.58, 2, 2.35),
	["Rally Dog"] = panel(3.08, -0.62, 2.75, 3.08, -0.62, 2.75, 1.13, 1.67),
	["Rustbucket"] = panel(3.37, -0.51, 2.16, 3.37, -0.51, 2.16, 1.92, 1.97),
	["Street Kid"] = panel(2.95, -0.17, 1.24, 2.95, -0.17, 1.24, 2.09, 1.13),
	["Sunny Camper"] = panel(2.82, -0.91, 2.17, 2.82, -0.91, 2.17, 1.48, 1.76),
	["Surf Wagon"] = panel(2.39, -1.26, 1.8, 2.39, -1.26, 1.8, 1.84, 1.67),
	["Thunder"] = panel(3.02, -0.46, 1.77, 3.02, -0.46, 1.77, 1.94, 1.38),
	["Trailblazer"] = panel(3.24, -0.66, 3.19, 3.24, -0.66, 3.19, 1.35, 2.65),
	["Velvet"] = panel(2.87, -0.41, 1.55, 2.87, -0.41, 1.55, 2.22, 1.37),
	["Viper Strike"] = panel(3.26, -0.22, 1.19, 3.26, -0.22, 1.19, 2.05, 1.05),
	["Workhorse"] = panel(2.89, -0.43, 2.71, 2.89, -0.43, 2.71, 1.25, 2.57),
	["Zip"] = panel(3.35, -0.11, 1.22, 3.35, -0.11, 1.22, 2.18, 1.13),
}

return data
