--!strict
-- DEVELOPMENT CHECKS (Lane 3, Task 4): the park destinations built by
-- Hub/Environment/Destinations (Garage, Stunt Circuit entrance, the two leaderboards). Each
-- failure names the object:
--   envelope   every placed part inside its destination's envelope (frame-local, from the
--              model's EnvelopeMin / EnvelopeMax; Garage forecourt pieces use ForecourtMin / Max)
--   loop       the stunt loop inside its sightline-clear box in the right side strip
--   gantry     the built gantry beam centre against HubData park.gantry
--   textFaces  every SignFace on a mesh face lies within FaceTolerance of the recorded face
--              (recomputed from KitManifest and the model's Frame) and faces the same way
--   colliders  every collider is grounded: its bottom within GroundTolerance above the
--              ground under it (terrain or the plaza; the destinations and the greybox
--              placeholders are ignored) and buried no deeper than BuryTolerance
--   prompt     exactly one "Open Garage" ProximityPrompt, at the recorded PromptPoint
--   corridors  nothing taller than 3 studs above the surface reaches into a viewing corridor
--   snapshot   instance counts per destination, to compare two builds (idempotency)
--
--   local I = game.ServerStorage.Island:Clone()
--   local C = require(I.Hub.Preview.DestinationChecks)
--   C.run()                 -- every check; returns { failures = {...}, summary = {...} }
--   C.snapshot()            -- counts per destination
--   C.idempotency()         -- rebuilds twice into the environment folder and compares (edit mode)

local RunService = game:GetService("RunService")

local Destinations = require(script.Parent.Parent.Environment.Destinations)
local KitManifest = require(script.Parent.Parent.Environment.KitManifest)
local Layout = require(script.Parent.Parent.Layout)

local DestinationChecks = {}

DestinationChecks.EnvelopeTolerance = 0.06
DestinationChecks.FaceTolerance = 0.1
DestinationChecks.NormalDot = 0.995
DestinationChecks.GroundTolerance = 0.35
DestinationChecks.BuryTolerance = 2.0
DestinationChecks.GantryTolerance = 0.1
DestinationChecks.PromptTolerance = 0.05
DestinationChecks.CorridorHeight = 3

local ENV_NAME = "Lane3_IslandEnvironment"
local EXPECTED = { "Garage", "StuntGate", "LeaderboardGarage", "LeaderboardStunt" }

local function fmt(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

function DestinationChecks.root(): Instance?
	local env = workspace:FindFirstChild(ENV_NAME)
	return env and env:FindFirstChild(Destinations.FolderName)
end

local function corners(part: BasePart): { Vector3 }
	local h = part.Size / 2
	local out = {}
	for _, x in { -h.X, h.X } do
		for _, y in { -h.Y, h.Y } do
			for _, z in { -h.Z, h.Z } do
				table.insert(out, part.CFrame:PointToWorldSpace(Vector3.new(x, y, z)))
			end
		end
	end
	return out
end

local function models(): ({ Model }, { any })
	local fails = {}
	local out = {}
	local root = DestinationChecks.root()
	if not root then
		return out, { { check = "built", problem = "no Workspace." .. ENV_NAME .. "." .. Destinations.FolderName } }
	end
	for _, name in EXPECTED do
		local m = root:FindFirstChild(name)
		if m and m:IsA("Model") then
			table.insert(out, m)
		else
			table.insert(fails, { check = "built", problem = "missing " .. name })
		end
	end
	return out, fails
end

function DestinationChecks.envelope(): ({ any }, number)
	local fails = {}
	local checked = 0
	local list, missing = models()
	for _, f in missing do
		table.insert(fails, f)
	end
	local tol = DestinationChecks.EnvelopeTolerance
	for _, m in list do
		local base = m:GetAttribute("Frame") :: CFrame?
		local lo = m:GetAttribute("EnvelopeMin") :: Vector3?
		local hi = m:GetAttribute("EnvelopeMax") :: Vector3?
		if not (base and lo and hi) then
			table.insert(fails, { check = "envelope", object = m:GetFullName(), problem = "no Frame or envelope" })
			continue
		end
		local flo = (m:GetAttribute("ForecourtMin") :: Vector3?) or lo
		local fhi = (m:GetAttribute("ForecourtMax") :: Vector3?) or hi
		for _, d in m:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			checked += 1
			local zoneLo, zoneHi = lo, hi
			if d:GetAttribute("Zone") == "Forecourt" then
				zoneLo, zoneHi = flo, fhi
			end
			local worst = 0
			local points = corners(d)
			if d.Name == "Disc" or d.Name == "Ring" then
				-- a round turntable: its bounding box corners stick out when it is turned, the
				-- disc itself does not (justified joint: test the circle, not the box)
				local r = math.max(d.Size.X, d.Size.Z) / 2
				local pc = base:PointToObjectSpace(d.Position)
				points = {}
				for _, off in
					{ Vector3.new(r, 0, 0), Vector3.new(-r, 0, 0), Vector3.new(0, 0, r), Vector3.new(0, 0, -r) }
				do
					table.insert(points, base:PointToWorldSpace(pc + off))
				end
			end
			for _, c in points do
				local p = base:PointToObjectSpace(c)
				worst = math.max(
					worst,
					zoneLo.X - p.X,
					p.X - zoneHi.X,
					zoneLo.Y - p.Y,
					p.Y - zoneHi.Y,
					zoneLo.Z - p.Z,
					p.Z - zoneHi.Z
				)
			end
			if worst > tol then
				table.insert(fails, {
					check = "envelope",
					object = d:GetFullName(),
					outBy = math.round(worst * 1000) / 1000,
					local_ = fmt(base:PointToObjectSpace(d.Position)),
				})
			end
		end
	end
	return fails, checked
end

function DestinationChecks.loop(): { any }
	local root = DestinationChecks.root()
	local stunt = root and root:FindFirstChild("StuntGate")
	local loop = stunt and stunt:FindFirstChild("Loop", true)
	if not (stunt and loop and loop:IsA("BasePart")) then
		return { { check = "loop", problem = "no StuntGate Loop part" } }
	end
	local base = stunt:GetAttribute("Frame") :: CFrame
	local lo = stunt:GetAttribute("LoopBoxMin") :: Vector3
	local hi = stunt:GetAttribute("LoopBoxMax") :: Vector3
	local worst = 0
	for _, c in corners(loop) do
		local p = base:PointToObjectSpace(c)
		worst = math.max(worst, lo.X - p.X, p.X - hi.X, p.Y - hi.Y, lo.Z - p.Z, p.Z - hi.Z)
	end
	if worst > DestinationChecks.EnvelopeTolerance then
		return { { check = "loop", object = loop:GetFullName(), outOfClearBoxBy = math.round(worst * 1000) / 1000 } }
	end
	return {}
end

function DestinationChecks.gantry(): { any }
	local root = DestinationChecks.root()
	local stunt = root and root:FindFirstChild("StuntGate")
	local want = (Layout.Data.park :: any).gantry :: Vector2?
	if not (stunt and want) then
		return { { check = "gantry", problem = "no StuntGate model or no park.gantry" } }
	end
	local at = stunt:GetAttribute("GantryPoint") :: Vector3
	local off = (Layout.worldToPlan(at) - want).Magnitude
	if off > DestinationChecks.GantryTolerance then
		return { { check = "gantry", object = stunt:GetFullName(), offFromLayout = math.round(off * 1000) / 1000 } }
	end
	return {}
end

function DestinationChecks.textFaces(): ({ any }, number)
	local fails = {}
	local checked = 0
	local list = models()
	for _, m in list do
		local base = m:GetAttribute("Frame") :: CFrame?
		for _, d in m:GetDescendants() do
			if not (d:IsA("BasePart") and d:GetAttribute("SignFace") ~= nil) then
				continue
			end
			if d:GetAttribute("OwnFace") == true then
				continue -- a plaque that is its own face (no mesh face under it)
			end
			checked += 1
			local mesh = d:GetAttribute("FaceMesh")
			local key = d:GetAttribute("FaceKey")
			local entry = if type(mesh) == "string" then (KitManifest :: any)[mesh] else nil
			local c = entry and type(key) == "string" and entry.points[key .. ".centre"]
			local n = entry and type(key) == "string" and entry.points[key .. ".normal"]
			if not (base and c and n) then
				table.insert(fails, { check = "textFace", object = d:GetFullName(), problem = "no recorded face" })
				continue
			end
			local wantC = base:PointToWorldSpace(c)
			local wantN = base:VectorToWorldSpace(n).Unit
			local front = d.CFrame:PointToWorldSpace(Vector3.new(0, 0, -d.Size.Z / 2))
			local off = (front - wantC).Magnitude
			local dot = d.CFrame.LookVector:Dot(wantN)
			local surface = d:FindFirstChildOfClass("SurfaceGui")
			if off > DestinationChecks.FaceTolerance or dot < DestinationChecks.NormalDot then
				table.insert(fails, {
					check = "textFace",
					object = d:GetFullName(),
					offFromMeshFace = math.round(off * 1000) / 1000,
					normalDot = math.round(dot * 10000) / 10000,
				})
			elseif not surface or surface.Face ~= Enum.NormalId.Front then
				table.insert(
					fails,
					{ check = "textFace", object = d:GetFullName(), problem = "no SurfaceGui on Face = Front" }
				)
			end
		end
	end
	return fails, checked
end

-- The ground under a point: terrain and the hub, ignoring the destinations and the greybox
-- placeholder buildings and boards.
local function groundBelow(at: Vector3): number?
	local ignore: { Instance } = {}
	local root = DestinationChecks.root()
	if root then
		table.insert(ignore, root)
	end
	local preview = workspace:FindFirstChild("Lane3_IslandPreview")
	local buildings = preview and preview:FindFirstChild("Buildings", true)
	if buildings then
		table.insert(ignore, buildings)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else nil
end

function DestinationChecks.colliders(): ({ any }, number)
	local fails = {}
	local checked = 0
	local list = models()
	for _, m in list do
		for _, d in m:GetDescendants() do
			if not (d:IsA("BasePart") and d:GetAttribute("Collider") == true) then
				continue
			end
			checked += 1
			if not d.CanCollide then
				table.insert(fails, { check = "collider", object = d:GetFullName(), problem = "CanCollide is off" })
			end
			-- the bottom corners, and the bottom centre
			local h = d.Size / 2
			local points = { d.CFrame:PointToWorldSpace(Vector3.new(0, -h.Y, 0)) }
			for _, x in { -h.X, h.X } do
				for _, z in { -h.Z, h.Z } do
					table.insert(points, d.CFrame:PointToWorldSpace(Vector3.new(x * 0.95, -h.Y, z * 0.95)))
				end
			end
			local floating, buried = -math.huge, -math.huge
			local missing = 0
			for _, p in points do
				local g = groundBelow(p)
				if g then
					floating = math.max(floating, p.Y - g)
					buried = math.max(buried, g - p.Y)
				else
					missing += 1
				end
			end
			if missing == #points then
				table.insert(fails, { check = "collider", object = d:GetFullName(), problem = "no ground under it" })
			elseif floating > DestinationChecks.GroundTolerance then
				table.insert(fails, {
					check = "collider",
					object = d:GetFullName(),
					floatsBy = math.round(floating * 1000) / 1000,
				})
			elseif buried > DestinationChecks.BuryTolerance then
				table.insert(fails, {
					check = "collider",
					object = d:GetFullName(),
					buriedBy = math.round(buried * 1000) / 1000,
				})
			end
		end
	end
	return fails, checked
end

function DestinationChecks.prompt(): { any }
	local root = DestinationChecks.root()
	local garage = root and root:FindFirstChild("Garage")
	if not garage then
		return { { check = "prompt", problem = "no Garage" } }
	end
	local prompts = {}
	for _, d in garage:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			table.insert(prompts, d)
		end
	end
	if #prompts ~= 1 then
		return { { check = "prompt", problem = string.format("%d prompts in the Garage, want 1", #prompts) } }
	end
	local p = prompts[1]
	local fails = {}
	if p.ActionText ~= "Open Garage" or not p.Enabled or p.MaxActivationDistance <= 0 then
		table.insert(fails, { check = "prompt", object = p:GetFullName(), problem = "ActionText, Enabled or distance" })
	end
	local holder = p.Parent
	local base = garage:GetAttribute("Frame") :: CFrame
	local want = KitManifest.GarageShell.points["PromptPoint.position"]
	if holder and holder:IsA("BasePart") and want then
		local off = (holder.Position - base:PointToWorldSpace(want)).Magnitude
		if off > DestinationChecks.PromptTolerance then
			table.insert(fails, { check = "prompt", object = holder:GetFullName(), offFromPromptPoint = off })
		end
	else
		table.insert(fails, { check = "prompt", object = p:GetFullName(), problem = "not on a part at PromptPoint" })
	end
	return fails
end

local function inTriangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2): boolean
	local function side(p1: Vector2, p2: Vector2, p3: Vector2): number
		return (p1.X - p3.X) * (p2.Y - p3.Y) - (p2.X - p3.X) * (p1.Y - p3.Y)
	end
	local d1, d2, d3 = side(p, a, b), side(p, b, c), side(p, c, a)
	local neg = d1 < 0 or d2 < 0 or d3 < 0
	local pos = d1 > 0 or d2 > 0 or d3 > 0
	return not (neg and pos)
end

function DestinationChecks.corridors(): { any }
	local fails = {}
	local list = models()
	local tris = Layout.Data.park.corridors
	for _, m in list do
		for _, d in m:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			local cs = corners(d)
			local top = -math.huge
			for _, c in cs do
				top = math.max(top, c.Y)
			end
			if top - Layout.SurfaceY <= DestinationChecks.CorridorHeight then
				continue
			end
			local probe = { Layout.worldToPlan(d.Position) }
			for _, c in cs do
				table.insert(probe, Layout.worldToPlan(c))
			end
			for i, tri in tris do
				local hit = false
				for _, q in probe do
					if inTriangle(q, tri[1], tri[2], tri[3]) then
						hit = true
						break
					end
				end
				if hit then
					table.insert(fails, { check = "corridor", corridor = i, object = d:GetFullName() })
					break
				end
			end
		end
	end
	return fails
end

-- Instance counts per destination (and how many of each there are), for a before / after
-- rebuild comparison.
function DestinationChecks.snapshot(): { [string]: number }
	local out: { [string]: number } = {}
	local env = workspace:FindFirstChild(ENV_NAME)
	if not env then
		return out
	end
	local folders = 0
	for _, child in env:GetChildren() do
		if child.Name == Destinations.FolderName then
			folders += 1
		end
	end
	out.destinationFolders = folders
	local root = env:FindFirstChild(Destinations.FolderName)
	if not root then
		return out
	end
	for _, m in root:GetChildren() do
		out[m.Name .. ".copies"] = (out[m.Name .. ".copies"] or 0) + 1
		local counts = { parts = 0, guis = 0, lights = 0, attachments = 0, prompts = 0, labels = 0 }
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				counts.parts += 1
			elseif d:IsA("SurfaceGui") then
				counts.guis += 1
			elseif d:IsA("Light") then
				counts.lights += 1
			elseif d:IsA("Attachment") then
				counts.attachments += 1
			elseif d:IsA("ProximityPrompt") then
				counts.prompts += 1
			elseif d:IsA("TextLabel") then
				counts.labels += 1
			end
		end
		for k, v in counts do
			out[m.Name .. "." .. k] = v
		end
	end
	return out
end

function DestinationChecks.compare(a: { [string]: number }, b: { [string]: number }): { any }
	local diffs = {}
	for k, v in a do
		if b[k] ~= v then
			table.insert(diffs, { key = k, first = v, second = b[k] })
		end
	end
	for k, v in b do
		if a[k] == nil then
			table.insert(diffs, { key = k, first = nil, second = v })
		end
	end
	return diffs
end

-- Builds the destinations twice into the environment folder and compares the snapshots: a second
-- build must leave exactly one set. Edit mode only (it rebuilds).
function DestinationChecks.idempotency(): { [string]: any }
	assert(RunService:IsStudio() and not RunService:IsRunning(), "idempotency rebuilds: edit mode only")
	local env = workspace:FindFirstChild(ENV_NAME)
	assert(env, "build the environment first")
	Destinations.build(env)
	local first = DestinationChecks.snapshot()
	Destinations.build(env)
	local second = DestinationChecks.snapshot()
	local diffs = DestinationChecks.compare(first, second)
	local one = second.destinationFolders == 1
	for _, name in EXPECTED do
		one = one and second[name .. ".copies"] == 1
	end
	return { identical = #diffs == 0, exactlyOneSet = one, diffs = diffs, snapshot = second }
end

function DestinationChecks.run(): { [string]: any }
	local failures = {}
	local function add(list: { any })
		for _, f in list do
			table.insert(failures, f)
		end
	end
	local e, envelopeChecked = DestinationChecks.envelope()
	add(e)
	add(DestinationChecks.loop())
	add(DestinationChecks.gantry())
	local t, facesChecked = DestinationChecks.textFaces()
	add(t)
	local c, collidersChecked = DestinationChecks.colliders()
	add(c)
	add(DestinationChecks.prompt())
	add(DestinationChecks.corridors())
	return {
		failures = failures,
		summary = {
			failures = #failures,
			partsInEnvelopes = envelopeChecked,
			textFaces = facesChecked,
			colliders = collidersChecked,
		},
		snapshot = DestinationChecks.snapshot(),
	}
end

return DestinationChecks
