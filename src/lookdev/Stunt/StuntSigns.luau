--!strict
-- Signs and gates of the Stunt Circuit (Lane 3, M17-01): a warning sign before every obstacle, a numbered checkpoint arch on
-- flat road, the start/finish gantry and the chevron boards at the four corners. All are made with the sign family
-- (SignKit, style "Race": navy plate, gold frame, checkered end caps) so they read as one language with the M5 signs. The
-- hazard header on each warning sign is orange and white, like the run's hazard boards.
--
--   Signs.build(root: Model) -> ()
--
-- The arches and the gantry are scenery. Which checkpoint a car has passed, and the time, are Brian R's logic: each arch
-- carries CheckpointIndex and its safe restart range as attributes for him to read.
--
-- Chevrons appear only where the road really turns (the four left-hand corner pads), never on a straight (the mock's finish
-- panel showed them on a straight road; that is a known mistake of the reference image).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(script.Parent.StuntParts)
local StuntData = require(script.Parent.StuntData)

local SignKit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("SignKit"))

local Signs = {}

local P = Parts.Palette
local GROUND = StuntData.Road.groundY
local HALF = StuntData.Road.totalWidth / 2
local PAINT = 0.12

-- WARNING SIGNS ---------------------------------------------------------------------------------------------------------

local function warningSign(folder: Folder, w: StuntData.Warning)
	local l = StuntData.legOf(w.s)
	local f = l.heading
	local right = f:Cross(Vector3.yAxis)
	local at = l.origin + f * (w.s - l.s0) + right * w.lateral
	-- facing the oncoming driver, turned 15 degrees toward the road
	local turn = math.rad(15)
	local out = (-f * math.cos(turn) - right * math.sin(turn)).Unit
	local width = math.clamp(10 + #w.text * 1.6, 20, 34)
	local height = 6.4
	local centre = Vector3.new(at.X, 9.5, at.Z)
	local cf = CFrame.lookAt(centre, centre + out)
	local model = Parts.model(folder, w.id)
	Parts.flagVisualOnly(model, w.id, "warning sign, looks only")
	model:SetAttribute("WarningFor", w.section)
	model:SetAttribute("LeadStuds", w.leadStuds)
	SignKit.sign(
		model,
		cf,
		{ style = "Race", text = w.text, width = width, height = height, mount = "posts", ground = GROUND }
	)
	-- the hazard header: alternating orange and white blocks along the top edge of the plate
	local blocks = math.max(math.floor(width / 4), 4)
	local blockW = width / blocks
	for i = 0, blocks - 1 do
		local x = -width / 2 + (i + 0.5) * blockW
		Parts.box(
			model,
			"HazardBlock",
			Vector3.new(blockW, 1.2, 0.5),
			cf * CFrame.new(x, height / 2 + 0.6, 0.25),
			if i % 2 == 0 then P.Orange else P.White
		)
	end
end

-- CHECKPOINT ARCHES -----------------------------------------------------------------------------------------------------

local function checkpointArch(folder: Folder, cp: StuntData.Checkpoint)
	local l = StuntData.legOf(cp.s)
	local u = cp.s - l.s0
	local depth = 4
	local model = Parts.model(folder, cp.id)
	model:SetAttribute("CheckpointIndex", cp.index)
	model:SetAttribute("SafeRestartS0", cp.restart.s0)
	model:SetAttribute("SafeRestartS1", cp.restart.s1)
	model:SetAttribute("Note", "scenery only: passing a checkpoint is Brian R's logic")
	for _, side in { -1, 1 } do
		local lat0 = if side > 0 then 41 else -45
		local lat1 = if side > 0 then 45 else -41
		Parts.along(model, "Pillar", l.origin, l.heading, u - depth / 2, u + depth / 2, lat0, lat1, GROUND, 23, P.Navy)
		-- a neon strip up the inside of each pillar (0.15 proud of it)
		local inner = if side > 0 then 41 - 0.15 else -41
		Parts.along(
			model,
			"GateStrip",
			l.origin,
			l.heading,
			u - 1,
			u + 1,
			inner,
			inner + 0.15,
			0,
			17,
			P.NeonCyan,
			{ material = Enum.Material.Neon }
		)
	end
	Parts.along(model, "Beam", l.origin, l.heading, u - depth / 2, u + depth / 2, -41, 41, 17, 23, P.Navy)
	-- the numbered plate on the face the driver sees
	local centre = l.origin + l.heading * u
	local out = -l.heading
	local at = centre + out * (depth / 2 + 0.5)
	SignKit.sign(
		model,
		CFrame.lookAt(Vector3.new(at.X, 20, at.Z), Vector3.new(at.X, 20, at.Z) + out),
		{ style = "Race", text = "CHECKPOINT " .. cp.index, width = 26, height = 5.2 }
	)
end

-- START / FINISH GANTRY -----------------------------------------------------------------------------------------------

local function gantry(folder: Folder)
	local l = StuntData.Legs[1]
	local model = Parts.model(folder, "StartFinishGantry")
	model:SetAttribute("Note", "scenery only; the line is the start line and the finish line")
	local depth = 5
	for _, side in { -1, 1 } do
		local lat0 = if side > 0 then 44 else -49
		local lat1 = if side > 0 then 49 else -44
		Parts.along(model, "Pillar", l.origin, l.heading, -depth / 2, depth / 2, lat0, lat1, GROUND + 2, 25, P.Navy)
		Parts.along(
			model,
			"PillarBase",
			l.origin,
			l.heading,
			-depth / 2 - 1,
			depth / 2 + 1,
			lat0 - 1,
			lat1 + 1,
			GROUND,
			GROUND + 2,
			P.ConcreteDark
		)
	end
	Parts.along(model, "Beam", l.origin, l.heading, -depth / 2, depth / 2, -44, 44, 17, 25, P.Navy)
	-- front (toward the finishing car and the start grid): START / FINISH. Back: the name of the course.
	local front = Vector3.new(0, 21, 0) + -l.heading * (depth / 2 + 0.5)
	SignKit.sign(
		model,
		CFrame.lookAt(front, front - l.heading),
		{ style = "Race", text = "START / FINISH", width = 44, height = 9 }
	)
	local back = Vector3.new(0, 21, 0) + l.heading * (depth / 2 + 0.5)
	SignKit.sign(
		model,
		CFrame.lookAt(back, back + l.heading),
		{ style = "Race", text = "STUNT CIRCUIT", width = 40, height = 8 }
	)
end

-- CORNER CHEVRONS ----------------------------------------------------------------------------------------------------

local function chevronBoard(folder: Folder, corner: StuntData.Corner, incoming: StuntData.Leg)
	local f = incoming.heading
	local out = -f
	local centre = corner.centre + f * (HALF + 0.9) + Vector3.new(0, 10, 0)
	local model = Parts.model(folder, "Chevrons" .. corner.id)
	model:SetAttribute("Note", "the route turns left here; scenery only")
	local cf = CFrame.lookAt(centre, centre + out)
	Parts.box(model, "Board", Vector3.new(32, 8, 0.8), cf, P.Navy)
	for _, x in { -12, 12 } do
		Parts.box(model, "Post", Vector3.new(1, 2.6, 1), cf * CFrame.new(x, -5.3, 0), P.Steel)
	end
	-- three chevrons pointing to the driver's left (+X of the board is the driver's left)
	local w, h, thick = 3.4, 3, 1.2
	local armLength = math.sqrt(w * w + h * h)
	local phi = math.atan2(h, w)
	for i = -1, 1 do
		local cx = i * 9
		Parts.box(
			model,
			"ChevronUpper",
			Vector3.new(armLength, thick, PAINT),
			cf * CFrame.new(cx, h / 2, -(0.4 + PAINT / 2)) * CFrame.Angles(0, 0, -phi),
			P.Gold
		)
		-- the lower arm is a second layer, 0.12 out from the first, so the two never share a plane where they cross
		Parts.box(
			model,
			"ChevronLower",
			Vector3.new(armLength, thick, PAINT),
			cf * CFrame.new(cx, -h / 2, -(0.4 + PAINT * 1.5)) * CFrame.Angles(0, 0, phi),
			P.Gold
		)
	end
end

-- ENTRY ------------------------------------------------------------------------------------------------------------------------

function Signs.build(root: Model)
	local folder = Parts.folder(root, "Signs")
	for _, w in StuntData.Warnings do
		warningSign(folder, w)
	end
	local arches = Parts.folder(root, "Checkpoints")
	for _, cp in StuntData.Checkpoints do
		checkpointArch(arches, cp)
	end
	gantry(arches)
	for i, corner in StuntData.Corners do
		chevronBoard(folder, corner, StuntData.Legs[i])
	end
end

return Signs
