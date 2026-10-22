--!strict
-- Island walking boost (Lane 3, client side, the local character only). Authorized by Adam in
-- the Task 4 brief (2026-10-22, IRW-155). Spec: vault/design/specs/walk-boost.md.
--
-- While the local character's HumanoidRootPart is over an avenue boost strip (the glowing
-- chevrons, Workspace.Lane3_IslandEnvironment.BoostLanes), its WalkSpeed is the base x 1.5
-- (16 to 24). Stepping off keeps the boost for 0.5 s, then it eases back to the exact base over
-- 0.5 s. Numbers and the state machine: ReplicatedStorage.Shared.Island.WalkBoostLogic. The speed
-- goes through ReplicatedStorage.Shared.Movement.SpeedModifiers (one source, "IslandBoostLane",
-- largest-wins), so it never stacks and never overwrites a base speed set by anyone else.
--
-- THE SWITCH: WalkBoost.ENABLED below. false turns the whole boost off (the starter script
-- creates nothing). At run time the LocalPlayer attribute "Lane3WalkBoostEnabled" = false turns
-- it off too (exact base speed back at once, every per-character connection and effect gone);
-- removing the attribute or setting it true turns it on again.
--
-- TAKEOVER (Lane 1, Brian R): a movement system that owns walking speed sets the LocalPlayer
-- attribute "MovementSpeedOwner" to its name (any non-empty string). The boost then stands
-- aside completely: it clears its source, removes its effects, stops its frame loop and touches
-- nothing until the attribute is removed. That system can consume the boost instead with
-- WalkBoost.new({ write = false, respectTakeover = false }), reading :multiplier() or Changed,
-- or replace SpeedModifiers behind the same API. Details in the spec.
--
-- Feedback (client only, never replicated): two soft wind trails at the feet and a few stretched
-- speed streaks behind the character while boosted and moving, plus a faint steady glow at the
-- feet. Reduced motion (GuiService.ReducedMotionEnabled, or the preview-only LocalPlayer attribute
-- "Lane3ReducedMotionOverride") keeps only the steady glow: no trails, no particles. A change in
-- either applies at once, mid-boost. Built-in engine textures only; nothing is uploaded.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local SpeedModifiers = require(ReplicatedStorage.Shared.Movement.SpeedModifiers)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WalkBoostLogic = require(ReplicatedStorage.Shared.Island.WalkBoostLogic)

local WalkBoost = {}

WalkBoost.ENABLED = true -- THE switch for the whole island walking boost

WalkBoost.Source = "IslandBoostLane" -- the SpeedModifiers source name
WalkBoost.SwitchAttribute = "Lane3WalkBoostEnabled" -- LocalPlayer, false = off at run time
WalkBoost.TakeoverAttribute = "MovementSpeedOwner" -- LocalPlayer, a name = another system owns speed
WalkBoost.PublishAttribute = "IslandBoostMultiplier" -- LocalPlayer, read-only status (live runner)
WalkBoost.EffectPrefix = "Lane3WalkBoost"

local ROOT_NAME = "Lane3_IslandEnvironment"
local LANES_NAME = "BoostLanes"
local OVERRIDE = "Lane3ReducedMotionOverride"
local STREAK_RATE = 22 -- streaks per second at full boost and full running speed (Tunable)
local GLOW = 0.45 -- the steady feet glow's brightness at full boost (Tunable)
local TRAIL_FROM = 0.3 -- trails show above this boost intensity (they fade out in the ease)
local WIND = Color3.fromRGB(236, 246, 255)

export type Strip = WalkBoostLogic.Strip

export type Options = {
	player: Player?, -- default Players.LocalPlayer
	strips: { Strip }?, -- fixed strips (tests); default: read from the built island
	halfWidth: number?, -- with strips
	clock: (() -> number)?, -- default os.clock
	manual: boolean?, -- no frame loop: the caller drives :update(now) (tests)
	write: boolean?, -- default true; false computes and reports but never touches WalkSpeed
	effects: boolean?, -- default true
	publish: boolean?, -- write PublishAttribute on the player (the live runner)
	respectTakeover: boolean?, -- default true
	switchAttribute: string?, -- default WalkBoost.SwitchAttribute (tests use their own)
}

export type Status = {
	enabled: boolean,
	takenOver: boolean,
	bound: boolean,
	pending: boolean,
	character: Model?,
	multiplier: number,
	onStrip: boolean,
	walkSpeed: number?,
	base: number?,
	connections: number,
	strips: number,
	reducedMotion: boolean,
	trails: boolean,
	streakRate: number,
	streaksEnabled: boolean,
	glow: number,
	destroyed: boolean,
}

export type Controller = {
	update: (now: number?) -> number,
	refresh: () -> (),
	multiplier: () -> number,
	status: () -> Status,
	destroy: () -> (),
	Changed: Signal.Signal<number>,
}

type Effects = {
	trails: { Trail },
	streaks: ParticleEmitter,
	glow: PointLight,
}

type Binding = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	trove: Trove.Trove,
	effects: Effects?,
}

-- The built island's boost strips: one inlay beam per strip, under BoostLanes. Strips whose
-- attachments are not streamed in yet are skipped (the model is re-read when it changes).
function WalkBoost.readStrips(model: Instance): ({ Strip }, number)
	local out: { Strip } = {}
	for _, d in model:GetChildren() do
		if d:IsA("Beam") and (d:GetAttribute("BoostStrip") == true or string.match(d.Name, "^Avenue%d+Inlay")) then
			local a0, a1 = d.Attachment0, d.Attachment1
			if a0 and a1 then
				local p0, p1 = a0.WorldPosition, a1.WorldPosition
				table.insert(out, {
					from = WalkBoostLogic.toPlan(p0),
					to = WalkBoostLogic.toPlan(p1),
					y = math.min(p0.Y, p1.Y),
				})
			end
		end
	end
	local hw = model:GetAttribute("StripHalfWidth")
	return out, if type(hw) == "number" then hw else WalkBoostLogic.HalfWidth
end

-- The BoostLanes model in the built island, if it is there.
function WalkBoost.lanesModel(): Instance?
	local root = Workspace:FindFirstChild(ROOT_NAME)
	return if root then root:FindFirstChild(LANES_NAME) else nil
end

local function makeEffects(t: Trove.Trove, humanoid: Humanoid, root: BasePart): Effects
	local feet = -(humanoid.HipHeight + root.Size.Y / 2) -- the ground under the root, root space
	local function attachment(name: string, at: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = WalkBoost.EffectPrefix .. name
		a.Position = at
		a.Parent = root
		t:Add(a)
		return a
	end
	local trails: { Trail } = {}
	for _, side in { -1, 1 } do
		local low = attachment("TrailLow", Vector3.new(0.45 * side, feet + 0.25, 0.2))
		local high = attachment("TrailHigh", Vector3.new(0.45 * side, feet + 0.85, 0.2))
		local trail = Instance.new("Trail")
		trail.Name = WalkBoost.EffectPrefix .. "Wind"
		trail.Attachment0 = low
		trail.Attachment1 = high
		trail.Lifetime = 0.28
		trail.MinLength = 0.1
		trail.FaceCamera = true
		trail.Color = ColorSequence.new(WIND)
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		trail.LightEmission = 0.4
		trail.LightInfluence = 0.6
		trail.Enabled = false
		trail.Parent = root
		t:Add(trail)
		table.insert(trails, trail)
	end
	-- speed streaks: the engine's default particle texture, stretched along its motion
	local streakAt = attachment("Streaks", Vector3.new(0, feet + 1.6, 0.7))
	local streaks = Instance.new("ParticleEmitter")
	streaks.Name = WalkBoost.EffectPrefix .. "Streaks"
	streaks.EmissionDirection = Enum.NormalId.Back -- behind the character
	streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
	streaks.Speed = NumberRange.new(4, 7)
	streaks.Lifetime = NumberRange.new(0.22, 0.34)
	streaks.SpreadAngle = Vector2.new(18, 30)
	streaks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	streaks.Squash = NumberSequence.new(2.2)
	streaks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	streaks.Color = ColorSequence.new(WIND)
	streaks.LightEmission = 0.6
	streaks.Drag = 2
	streaks.Rate = 0
	streaks.Enabled = false
	streaks.Parent = streakAt
	t:Add(streaks)
	-- the steady glow at the feet (both motion modes; it only follows the boost level)
	local glowAt = attachment("Glow", Vector3.new(0, feet + 0.4, 0))
	local glow = Instance.new("PointLight")
	glow.Name = WalkBoost.EffectPrefix .. "Glow"
	glow.Color = Color3.fromRGB(200, 230, 255)
	glow.Range = 7
	glow.Brightness = 0
	glow.Shadows = false
	glow.Enabled = false
	glow.Parent = glowAt
	t:Add(glow)
	return { trails = trails, streaks = streaks, glow = glow }
end

function WalkBoost.new(options: Options?): Controller
	local opts: Options = options or {}
	local player = opts.player or Players.LocalPlayer
	assert(player, "WalkBoost needs a player")
	local clock = opts.clock or os.clock
	local switchName = opts.switchAttribute or WalkBoost.SwitchAttribute
	local write = opts.write ~= false
	local wantEffects = opts.effects ~= false
	local respectTakeover = opts.respectTakeover ~= false

	local trove = Trove.new()
	local stripsTrove = trove:Extend()
	local changed = Signal.new() :: Signal.Signal<number>
	trove:Add(changed)
	local live = 0 -- live connections made by this controller
	local destroyed = false
	local state = WalkBoostLogic.newState()
	local bound: Binding? = nil
	local pending: { character: Model, trove: Trove.Trove }? = nil
	local current = 1
	local lastOn = false
	local stripsModel: Instance? = nil
	local stripsDirty = true
	local strips: { Strip } = {}
	local halfWidth = WalkBoostLogic.HalfWidth

	local function track(t: Trove.Trove, signal: RBXScriptSignal, fn: (...any) -> ())
		local c = signal:Connect(fn)
		live += 1
		t:Add(function()
			c:Disconnect()
			live -= 1
		end)
	end

	local function enabledNow(): boolean
		return WalkBoost.ENABLED and player:GetAttribute(switchName) ~= false
	end

	local function takenOver(): boolean
		if not respectTakeover then
			return false
		end
		local owner = player:GetAttribute(WalkBoost.TakeoverAttribute)
		return owner == true or (type(owner) == "string" and owner ~= "")
	end

	local function reducedMotion(): boolean
		local override = player:GetAttribute(OVERRIDE)
		if type(override) == "boolean" then
			return override
		end
		return GuiService.ReducedMotionEnabled
	end

	local function currentStrips(): ({ Strip }, number)
		local fixed = opts.strips
		if fixed then
			return fixed, opts.halfWidth or WalkBoostLogic.HalfWidth
		end
		local model = WalkBoost.lanesModel()
		if model ~= stripsModel then
			stripsTrove:Clean()
			stripsModel = model
			stripsDirty = true
			if model then
				local function dirty()
					stripsDirty = true
				end
				track(stripsTrove, model.DescendantAdded, dirty)
				track(stripsTrove, model.DescendantRemoving, dirty)
			end
		end
		if stripsDirty then
			stripsDirty = false
			if model then
				strips, halfWidth = WalkBoost.readStrips(model)
			else
				table.clear(strips)
			end
		end
		return strips, halfWidth
	end

	local function publish(m: number?)
		if opts.publish then
			player:SetAttribute(WalkBoost.PublishAttribute, if m then math.round(m * 1000) / 1000 else nil)
		end
	end

	local function showEffects(b: Binding, m: number)
		local e = b.effects
		if not e then
			return
		end
		local k = WalkBoostLogic.intensity(m)
		local calm = reducedMotion()
		e.glow.Enabled = k > 0
		e.glow.Brightness = GLOW * k
		local full = not calm and k > TRAIL_FROM
		for _, trail in e.trails do
			if trail.Enabled ~= full then
				trail.Enabled = full
				if not full then
					trail:Clear()
				end
			end
		end
		local v = b.root.AssemblyLinearVelocity
		local running = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 12, 0, 1)
		local rate = if calm then 0 else STREAK_RATE * k * running
		e.streaks.Rate = rate
		local on = rate > 0
		if e.streaks.Enabled ~= on then
			e.streaks.Enabled = on
		end
		if calm then
			e.streaks:Clear() -- no particle left on screen under reduced motion
		end
	end

	local function setMultiplier(m: number)
		if m ~= current then
			current = m
			publish(m)
			changed:Fire(m)
		end
	end

	local function unbind()
		local p = pending
		if p then
			pending = nil
			p.trove:Destroy()
		end
		local b = bound
		if not b then
			return
		end
		bound = nil
		WalkBoostLogic.reset(state)
		lastOn = false
		if write then
			SpeedModifiers.clear(b.humanoid, WalkBoost.Source) -- the exact base comes back
		end
		b.trove:Destroy()
		stripsTrove:Clean()
		stripsModel = nil
		setMultiplier(1)
		publish(nil)
	end

	local function update(nowArg: number?): number
		local b = bound
		if destroyed or not b then
			return 1
		end
		local now = nowArg or clock()
		local list, hw = currentStrips()
		local on = b.root.Parent ~= nil
			and b.humanoid.Health > 0
			and WalkBoostLogic.overStrip(b.root.Position, list, hw)
		lastOn = on
		local m = WalkBoostLogic.step(state, now, on)
		if write then
			if m > 1 then
				SpeedModifiers.set(b.humanoid, WalkBoost.Source, m)
			else
				SpeedModifiers.clear(b.humanoid, WalkBoost.Source)
			end
		end
		showEffects(b, m)
		setMultiplier(m)
		return m
	end

	local function bind(character: Model)
		unbind()
		local t = Trove.new()
		local p = { character = character, trove = t }
		pending = p
		t:Add(task.spawn(function()
			local foundHumanoid = character:WaitForChild("Humanoid", 15)
			local foundRoot = character:WaitForChild("HumanoidRootPart", 15)
			if pending ~= p or destroyed then
				return
			end
			if not (foundHumanoid and foundHumanoid:IsA("Humanoid") and foundRoot and foundRoot:IsA("BasePart")) then
				return -- not a walking character; stays pending until it is replaced
			end
			local humanoid = foundHumanoid :: Humanoid
			local root = foundRoot :: BasePart
			pending = nil
			local binding: Binding = {
				character = character,
				humanoid = humanoid,
				root = root,
				trove = t,
				effects = if wantEffects then makeEffects(t, humanoid, root) else nil,
			}
			bound = binding
			WalkBoostLogic.reset(state)
			track(t, humanoid.Died, function()
				if bound == binding then
					unbind()
				end
			end)
			if not opts.manual then
				track(t, RunService.Heartbeat, function()
					update()
				end)
			end
			publish(1)
		end))
	end

	local function refresh()
		if destroyed then
			return
		end
		local character = player.Character
		local want = enabledNow() and not takenOver()
		if want and character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health <= 0 then
				unbind() -- a dead character waits for its replacement
				return
			end
			local b, p = bound, pending
			if (b and b.character == character) or (p and p.character == character) then
				return
			end
			bind(character)
		else
			unbind()
		end
	end

	track(trove, player.AttributeChanged, function(name: string)
		if name == switchName or name == WalkBoost.TakeoverAttribute then
			refresh()
		elseif name == OVERRIDE then
			local b = bound
			if b then
				showEffects(b, current)
			end
		end
	end)
	track(trove, GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), function()
		local b = bound
		if b then
			showEffects(b, current)
		end
	end)
	track(trove, player.CharacterAdded, function()
		refresh()
	end)
	track(trove, player.CharacterRemoving, function(character: Model)
		local b, p = bound, pending
		if (b and b.character == character) or (p and p.character == character) then
			unbind()
		end
	end)

	local controller: Controller = {
		update = update,
		refresh = refresh,
		multiplier = function(): number
			return current
		end,
		status = function(): Status
			local b = bound
			local e = b and b.effects
			local trails = false
			if e then
				for _, trail in e.trails do
					trails = trails or trail.Enabled
				end
			end
			return {
				enabled = enabledNow(),
				takenOver = takenOver(),
				bound = b ~= nil,
				pending = pending ~= nil,
				character = if b then b.character else nil,
				multiplier = current,
				onStrip = lastOn,
				walkSpeed = if b then b.humanoid.WalkSpeed else nil,
				base = if b then SpeedModifiers.base(b.humanoid) else nil,
				connections = live,
				strips = #(if opts.strips then opts.strips else strips),
				reducedMotion = reducedMotion(),
				trails = trails,
				streakRate = if e then e.streaks.Rate else 0,
				streaksEnabled = if e then e.streaks.Enabled else false,
				glow = if e and e.glow.Enabled then e.glow.Brightness else 0,
				destroyed = destroyed,
			}
		end,
		destroy = function()
			if destroyed then
				return
			end
			unbind()
			destroyed = true
			trove:Destroy()
		end,
		Changed = changed,
	}
	refresh()
	return controller
end

-- Connection counts, for leak tests. Idle (always, until destroy): the player's attributes,
-- reduced motion, character added and removing. Bound adds Died and, unless manual, the frame
-- loop; reading the built lanes (no fixed strips) adds two strip watchers while bound.
WalkBoost.IdleConnections = 4
WalkBoost.BoundConnections = 2 -- Died + frame loop (manual: 1)
WalkBoost.StripWatchConnections = 2

return WalkBoost
