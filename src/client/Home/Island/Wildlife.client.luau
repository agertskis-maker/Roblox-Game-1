--!strict
-- Island wildlife (Lane 3, client presentation only, decorative). Small creatures and motes
-- near the camera, cloned on this client from the hidden templates in the environment's
-- WildlifeKit folder and placed at the build's WildlifeAnchors:
--   a duck with four ducklings on a loop of calm lake water (DuckRoute),
--   a raccoon beside its hollow log, looking about and toward a close camera (RaccoonLog),
--   butterflies over flower drifts (ButterflyDrift), dragonflies darting by the reeds
--   (DragonflyReeds), frogs on lily pads with an occasional hop (FrogPad), fish circling in the
--   shallows (FishShallows), pollen motes over the flowers and fireflies in shady fern spots
--   (FireflyShade).
-- One shared budget: at most BUDGET creatures and EMITTER_BUDGET particle emitters at once, the
-- nearest groups within each kind's range first; everything outside is not created at all.
-- Reduced motion (GuiService.ReducedMotionEnabled, or the preview-only LocalPlayer attribute
-- "Lane3ReducedMotionOverride") hides the fast fliers, pollen and fireflies, slows the ducks
-- and fish and keeps the raccoon and frogs still. Nothing here replicates; the Trove removes
-- every clone, emitter and connection when the environment goes away. The live counts and their
-- peaks are kept as LocalPlayer attributes (Lane3Wildlife*) for measuring.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ROOT_NAME = "Lane3_IslandEnvironment"
local OVERRIDE = "Lane3ReducedMotionOverride"
local BUDGET = 36 -- creatures at once, all kinds together (Tunable)
local EMITTER_BUDGET = 8 -- pollen and firefly emitters at once (Tunable)
local REPICK = 0.5 -- seconds between choosing which groups are live
local RESCAN = 5 -- seconds between looking for streamed-in anchors
local DUCKLINGS = 4
local RANGE: { [string]: number } = { -- studs from the camera (Tunable)
	Ducks = 260,
	Raccoon = 110,
	Butterflies = 90,
	Dragonfly = 110,
	Frog = 80,
	Fish = 70,
	Pollen = 70,
	Fireflies = 90,
}
-- kinds hidden under reduced motion
local CALM_HIDDEN: { [string]: boolean } = { Butterflies = true, Dragonfly = true, Pollen = true, Fireflies = true }

local player = Players.LocalPlayer

type Live = {
	step: (t: number, calm: boolean, parts: { BasePart }, frames: { CFrame }) -> (),
	destroy: () -> (),
}
type Group = { kind: string, at: Vector3, cost: number, emitter: boolean, make: () -> Live, live: Live? }

local function reducedMotion(): boolean
	local override = player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

-- a stable 0..1 number for a place, so every client and every visit looks the same
local function hash(v: Vector3, salt: number): number
	local x = math.sin(v.X * 12.9898 + v.Z * 78.233 + salt * 37.719) * 43758.5453
	return x - math.floor(x)
end

-- mesh space faces +X; CFrame.lookAt faces -Z
local FACE_X = CFrame.Angles(0, math.pi / 2, 0)
local function facing(at: Vector3, dir: Vector3): CFrame
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-4 then
		return CFrame.new(at) * FACE_X
	end
	return CFrame.lookAt(at, at + flat) * FACE_X
end

local function run(trove: Trove.Trove, root: Instance, kit: Instance)
	local origin = CFrame.new(kit:GetAttribute("Origin") :: Vector3)
	local templates: { [string]: BasePart } = {}
	local offsets: { [string]: CFrame } = {}
	for _, t in kit:GetChildren() do
		if t:IsA("BasePart") then
			templates[t.Name] = t
			offsets[t.Name] = origin:ToObjectSpace(t.CFrame)
		end
	end
	local neck = CFrame.new(kit:GetAttribute("RaccoonNeck") :: Vector3)
	local pollenTexture = kit:GetAttribute("PollenTexture") :: string
	local fireflyTexture = kit:GetAttribute("FireflyTexture") :: string

	local liveFolder = trove:Add(Instance.new("Folder"))
	liveFolder.Name = "Lane3_Wildlife"
	liveFolder.Parent = Workspace
	local host = Instance.new("Part")
	host.Name = "EmitterHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = CFrame.new()
	host.Parent = liveFolder

	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }

	local function piece(name: string): (BasePart, CFrame)
		local p = templates[name]:Clone()
		p.Transparency = 0
		p.Parent = liveFolder
		return p, offsets[name]
	end

	-- ------------------------------------------------------------------ group makers
	local function ducks(points: { Vector3 }): Live
		-- a closed Catmull-Rom loop through the route, sampled by arc length
		local pts: { Vector3 } = {}
		local n = #points
		for i = 1, n do
			local p0, p1 = points[(i - 2) % n + 1], points[i]
			local p2, p3 = points[i % n + 1], points[(i + 1) % n + 1]
			for k = 0, 23 do
				local u = k / 24
				local u2, u3 = u * u, u * u * u
				table.insert(
					pts,
					0.5
						* (
							(2 * p1)
							+ (-p0 + p2) * u
							+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2
							+ (-p0 + 3 * p1 - 3 * p2 + p3) * u3
						)
				)
			end
		end
		local cum = { 0 }
		for i = 2, #pts + 1 do
			cum[i] = cum[i - 1] + (pts[(i - 1) % #pts + 1] - pts[i - 1]).Magnitude
		end
		local length = cum[#cum]
		local function at(s: number): (Vector3, Vector3)
			s %= length
			local i = 1
			while cum[i + 1] < s do
				i += 1
			end
			local a, b = pts[i], pts[i % #pts + 1]
			local f = (s - cum[i]) / math.max(cum[i + 1] - cum[i], 1e-6)
			return a:Lerp(b, f), b - a
		end
		local family: { { part: BasePart, offset: CFrame, gap: number, phase: number } } = {}
		local mother, mo = piece("Duck")
		table.insert(family, { part = mother, offset = mo, gap = 0, phase = 0 })
		for i = 1, DUCKLINGS do
			local d, off = piece("Duckling")
			table.insert(family, { part = d, offset = off, gap = 2.6 + 1.25 * (i - 1), phase = i * 1.7 })
		end
		local travelled = 0
		local last = os.clock()
		return {
			step = function(t, calm, parts, frames)
				local now = os.clock()
				travelled += (now - last) * (if calm then 0.8 else 1.6)
				last = now
				for _, m in family do
					local pos, dir = at(travelled - m.gap)
					local bob = if calm then 0 else 0.04 * math.sin(t * 2.1 + m.phase)
					local wobble = if calm or m.gap == 0 then 0 else 0.18 * math.sin(t * 1.3 + m.phase)
					local frame = facing(pos + Vector3.new(0, bob, 0), dir) * CFrame.Angles(0, wobble, 0)
					table.insert(parts, m.part)
					table.insert(frames, frame * m.offset)
				end
			end,
			destroy = function()
				for _, m in family do
					m.part:Destroy()
				end
			end,
		}
	end

	local function raccoon(at: Vector3, yaw: number): Live
		local body, bo = piece("Raccoon")
		local head, ho = piece("RaccoonHead")
		local log = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
		local spot = log * Vector3.new(0, 0, 2.6)
		local hit = Workspace:Raycast(spot + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), terrainOnly)
		local ground = if hit then hit.Position else spot - Vector3.new(0, 0.3, 0)
		-- beside the log, facing along it
		local frame = facing(ground, log.RightVector)
		return {
			step = function(t, calm, parts, frames)
				local look = 0
				if not calm then
					local camera = Workspace.CurrentCamera
					local toCamera = if camera then camera.CFrame.Position - ground else Vector3.zero
					if toCamera.Magnitude < 28 then
						local localDir = frame:VectorToObjectSpace(toCamera)
						look = math.clamp(math.atan2(-localDir.Z, localDir.X), -0.9, 0.9)
					else
						look = 0.55 * math.sin(t * 0.37) + 0.15 * math.sin(t * 1.1)
					end
				end
				table.insert(parts, body)
				table.insert(frames, frame * bo)
				table.insert(parts, head)
				table.insert(frames, frame * neck * CFrame.Angles(0, look, 0) * ho)
			end,
			destroy = function()
				body:Destroy()
				head:Destroy()
			end,
		}
	end

	local function butterflies(at: Vector3, radius: number): Live
		local list = {}
		for i = 1, 2 do
			local blue = hash(at, i) < 0.5
			local body, bo = piece("ButterflyBody")
			local l, lo = piece(if blue then "ButterflyBlueWingL" else "ButterflyWingL")
			local r, ro = piece(if blue then "ButterflyBlueWingR" else "ButterflyWingR")
			table.insert(list, {
				body = body,
				bo = bo,
				l = l,
				lo = lo,
				r = r,
				ro = ro,
				a = 0.21 + 0.1 * hash(at, i + 3),
				b = 0.17 + 0.1 * hash(at, i + 5),
				phase = hash(at, i + 7) * 6.28,
			})
		end
		local reach = radius * 0.65
		local function path(it: any, t: number): Vector3
			return at
				+ Vector3.new(
					reach * math.sin(it.a * t * 6.28 + it.phase),
					0.6 * math.sin(t * 0.9 + it.phase) + 0.3 * math.sin(t * 2.3 + it.phase),
					reach * math.sin(it.b * t * 6.28 + it.phase * 1.3)
				)
		end
		return {
			step = function(t, _calm, parts, frames)
				for _, it in list do
					local pos = path(it, t)
					local frame = facing(pos, path(it, t + 0.1) - pos)
					-- the left wing lies on -Z, so a positive turn about X lifts it; the right mirrors it
					local flap = math.rad(12 + 58 * (0.5 + 0.5 * math.sin(t * 11 + it.phase)))
					table.insert(parts, it.body)
					table.insert(frames, frame * it.bo)
					table.insert(parts, it.l)
					table.insert(frames, frame * CFrame.Angles(flap, 0, 0) * it.lo)
					table.insert(parts, it.r)
					table.insert(frames, frame * CFrame.Angles(-flap, 0, 0) * it.ro)
				end
			end,
			destroy = function()
				for _, it in list do
					it.body:Destroy()
					it.l:Destroy()
					it.r:Destroy()
				end
			end,
		}
	end

	local function dragonfly(at: Vector3): Live
		local body, bo = piece("DragonflyBody")
		local wings, wo = piece("DragonflyWings")
		local rng = Random.new(math.floor(hash(at, 11) * 1e6))
		local from, to = at, at
		local leg, legStart = 1, os.clock()
		local heading = Vector3.xAxis
		return {
			step = function(t, _calm, parts, frames)
				local now = os.clock()
				if now - legStart > leg then
					-- hover, then dart to a nearby point
					from = to
					to = at + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-4, 4))
					heading = to - from
					leg = rng:NextNumber(1.4, 3.2)
					legStart = now
				end
				local f = math.clamp((now - legStart) / 0.45, 0, 1)
				local ease = 1 - (1 - f) * (1 - f)
				local pos = from:Lerp(to, ease) + Vector3.new(0, 0.05 * math.sin(t * 7), 0)
				local frame = facing(pos, heading)
				table.insert(parts, body)
				table.insert(frames, frame * bo)
				table.insert(parts, wings)
				table.insert(frames, frame * CFrame.Angles(math.rad(7) * math.sin(t * 55), 0, 0) * wo)
			end,
			destroy = function()
				body:Destroy()
				wings:Destroy()
			end,
		}
	end

	local function frog(at: Vector3): Live
		local body, off = piece("Frog")
		local yaw = hash(at, 13) * 6.28
		local rng = Random.new(math.floor(hash(at, 17) * 1e6))
		local nextHop, hopStart, fromYaw, toYaw = os.clock() + rng:NextNumber(2, 7), -math.huge, yaw, yaw
		return {
			step = function(_t, calm, parts, frames)
				local now = os.clock()
				if not calm and now > nextHop then
					hopStart, fromYaw = now, toYaw
					toYaw = fromYaw + rng:NextNumber(0.5, 1.1) * (if rng:NextNumber() < 0.5 then -1 else 1)
					nextHop = now + rng:NextNumber(4, 9)
				end
				local f = math.clamp((now - hopStart) / 0.35, 0, 1)
				local lift = if f < 1 then 0.5 * math.sin(f * math.pi) else 0
				local y = fromYaw + (toYaw - fromYaw) * f
				table.insert(parts, body)
				table.insert(frames, CFrame.new(at + Vector3.new(0, lift, 0)) * CFrame.Angles(0, y, 0) * off)
			end,
			destroy = function()
				body:Destroy()
			end,
		}
	end

	local function fish(at: Vector3, radius: number): Live
		local list = {}
		for i = 1, 2 do
			local p, off = piece(if i == 1 then "FishOrange" else "FishSilver")
			table.insert(list, {
				part = p,
				off = off,
				r = radius * (0.35 + 0.25 * i),
				dir = if i == 1 then 1 else -1,
				depth = 0.2 * i,
				angle = hash(at, i + 19) * 6.28,
			})
		end
		local last = os.clock()
		return {
			step = function(t, calm, parts, frames)
				local now = os.clock()
				local dt = now - last
				last = now
				for _, it in list do
					it.angle += dt * (if calm then 0.12 else 0.25) * it.dir
					local pos = at + Vector3.new(math.cos(it.angle) * it.r, -it.depth, math.sin(it.angle) * it.r)
					local tangent = Vector3.new(-math.sin(it.angle), 0, math.cos(it.angle)) * it.dir
					local wiggle = if calm then 0 else 0.12 * math.sin(t * 6 + it.angle)
					table.insert(parts, it.part)
					table.insert(frames, facing(pos, tangent) * CFrame.Angles(0, wiggle, 0) * it.off)
				end
			end,
			destroy = function()
				for _, it in list do
					it.part:Destroy()
				end
			end,
		}
	end

	local function motes(at: Vector3, firefly: boolean): Live
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		local e = Instance.new("ParticleEmitter")
		if firefly then
			e.Texture = fireflyTexture
			e.Color = ColorSequence.new(Color3.fromRGB(226, 255, 140))
			e.LightEmission = 1
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.3),
				NumberSequenceKeypoint.new(0.6, 0.12),
				NumberSequenceKeypoint.new(1, 0),
			})
			e.Rate = 1.6
			e.Lifetime = NumberRange.new(3, 5)
			e.Speed = NumberRange.new(0.2, 0.6)
			e.Acceleration = Vector3.new(0, 0.05, 0)
		else
			e.Texture = pollenTexture
			e.Color = ColorSequence.new(Color3.fromRGB(255, 246, 196))
			e.LightEmission = 0.3
			e.Size = NumberSequence.new(0.1)
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.35),
				NumberSequenceKeypoint.new(0.8, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Rate = 3
			e.Lifetime = NumberRange.new(4, 6)
			e.Speed = NumberRange.new(0.2, 0.5)
			e.Acceleration = Vector3.new(0.08, 0.04, 0.05)
		end
		e.SpreadAngle = Vector2.new(180, 180)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.Parent = a
		a.Parent = host
		return {
			step = function() end,
			destroy = function()
				a:Destroy()
			end,
		}
	end

	-- ------------------------------------------------------------------ groups from the anchors
	local groups: { Group } = {}
	local anchorCount = -1

	local function release()
		for _, g in groups do
			if g.live then
				g.live.destroy()
				g.live = nil
			end
		end
		table.clear(groups)
	end
	trove:Add(release)

	local function rebuild()
		local found: { Attachment } = {}
		for _, d in root:GetDescendants() do
			if d:IsA("Attachment") and d.Parent and d.Parent.Name == "WildlifeAnchors" then
				table.insert(found, d)
			end
		end
		if #found == anchorCount then
			return
		end
		anchorCount = #found
		release()
		local route: { Attachment } = {}
		for _, a in found do
			local p = a.WorldPosition
			local kind = a.Name
			if kind == "DuckRoute" then
				table.insert(route, a)
			elseif kind == "RaccoonLog" then
				local yaw = (a:GetAttribute("Yaw") :: number?) or 0
				table.insert(groups, {
					kind = "Raccoon",
					at = p,
					cost = 1,
					emitter = false,
					make = function()
						return raccoon(p, yaw)
					end,
				})
			elseif kind == "ButterflyDrift" then
				local radius = (a:GetAttribute("Radius") :: number?) or 8
				table.insert(groups, {
					kind = "Butterflies",
					at = p,
					cost = 2,
					emitter = false,
					make = function()
						return butterflies(p, radius)
					end,
				})
				table.insert(groups, {
					kind = "Pollen",
					at = p,
					cost = 1,
					emitter = true,
					make = function()
						return motes(p, false)
					end,
				})
			elseif kind == "DragonflyReeds" then
				table.insert(groups, {
					kind = "Dragonfly",
					at = p,
					cost = 1,
					emitter = false,
					make = function()
						return dragonfly(p)
					end,
				})
			elseif kind == "FrogPad" then
				table.insert(groups, {
					kind = "Frog",
					at = p,
					cost = 1,
					emitter = false,
					make = function()
						return frog(p)
					end,
				})
			elseif kind == "FishShallows" then
				local radius = (a:GetAttribute("Radius") :: number?) or 7
				table.insert(groups, {
					kind = "Fish",
					at = p,
					cost = 2,
					emitter = false,
					make = function()
						return fish(p, radius)
					end,
				})
			elseif kind == "FireflyShade" then
				table.insert(groups, {
					kind = "Fireflies",
					at = p,
					cost = 1,
					emitter = true,
					make = function()
						return motes(p, true)
					end,
				})
			end
		end
		if #route >= 3 then
			table.sort(route, function(a, b)
				return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
			end)
			local points: { Vector3 } = {}
			local centre = Vector3.zero
			for _, a in route do
				table.insert(points, a.WorldPosition)
				centre += a.WorldPosition
			end
			centre /= #points
			table.insert(groups, {
				kind = "Ducks",
				at = centre,
				cost = 1 + DUCKLINGS,
				emitter = false,
				make = function()
					return ducks(points)
				end,
			})
		end
	end

	-- ------------------------------------------------------------------ budget and motion
	local peak, emitterPeak = 0, 0
	local lastPick, lastScan, lastCalm = -math.huge, -math.huge, false
	local started = os.clock()
	trove:Connect(RunService.RenderStepped, function()
		local now = os.clock()
		if now - lastScan > RESCAN then
			lastScan = now
			rebuild()
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local calm = reducedMotion()
		if calm ~= lastCalm then
			lastCalm = calm
			lastPick = -math.huge
		end
		if now - lastPick > REPICK then
			lastPick = now
			local eye = camera.CFrame.Position
			local near: { { g: Group, d: number } } = {}
			for _, g in groups do
				local d = (g.at - eye).Magnitude
				if d < RANGE[g.kind] and not (calm and CALM_HIDDEN[g.kind]) then
					table.insert(near, { g = g, d = d })
				end
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
			local keep: { [Group]: boolean } = {}
			local creatures, emitters = 0, 0
			for _, c in near do
				if c.g.emitter then
					if emitters < EMITTER_BUDGET then
						emitters += 1
						keep[c.g] = true
					end
				elseif creatures + c.g.cost <= BUDGET then
					creatures += c.g.cost
					keep[c.g] = true
				end
			end
			for _, g in groups do
				if keep[g] and not g.live then
					g.live = g.make()
				elseif not keep[g] and g.live then
					g.live.destroy()
					g.live = nil
				end
			end
			peak = math.max(peak, creatures)
			emitterPeak = math.max(emitterPeak, emitters)
			player:SetAttribute("Lane3WildlifeActive", creatures)
			player:SetAttribute("Lane3WildlifeEmitters", emitters)
			player:SetAttribute("Lane3WildlifePeak", peak)
			player:SetAttribute("Lane3WildlifeEmitterPeak", emitterPeak)
		end
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		local t = now - started
		for _, g in groups do
			if g.live then
				g.live.step(t, calm, parts, frames)
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

local current: Trove.Trove? = nil
local function attach(root: Instance)
	if current then
		current:Destroy()
	end
	local trove = Trove.new()
	current = trove
	trove:Add(task.spawn(function()
		run(trove, root, root:WaitForChild("WildlifeKit"))
	end))
	trove:Connect(root.AncestryChanged, function()
		if not root:IsDescendantOf(Workspace) then
			trove:Destroy()
			if current == trove then
				current = nil
			end
		end
	end)
end

local existing = Workspace:FindFirstChild(ROOT_NAME)
if existing then
	attach(existing)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == ROOT_NAME then
		attach(child)
	end
end)
