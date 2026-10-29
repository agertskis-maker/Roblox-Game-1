--!strict
-- Island walking speed and boost lanes (Lane 3, client side, the local character only). The boost
-- was authorized by Adam in the Task 4 brief (2026-10-22, IRW-155); the island base speed and the
-- new feedback are Adam's Raceway round 2, Part 6 / Design 6 (2026-10-29). Spec:
-- vault/design/specs/walk-boost.md.
--
-- ISLAND BASE: on the home island the local character walks at WalkBoostLogic.IslandBase, exactly
-- 32 (Roblox's default is 16). It is written ONCE per character, when the controller binds to it
-- (first spawn, respawn, or the player coming back from a takeover), and never again: if anyone
-- else writes WalkSpeed afterwards, their value simply is the base from then on (the island does
-- not fight it). Letting go (takeover, switch off, death, destroy) writes back the exact WalkSpeed
-- the humanoid had before the island set 32 (usually 16), but only if WalkSpeed is still the value
-- the island wrote; a value someone else wrote since is left alone.
--
-- BOOST LANES: while the HumanoidRootPart is over an avenue boost strip (the glowing chevrons,
-- Workspace.Lane3_IslandEnvironment.BoostLanes), WalkSpeed is the base x 1.5, so 32 x 1.5 = 48. The
-- boost multiplies the base; it is not a maximum. Stepping off keeps it for 0.5 s, then it eases back
-- to exactly the base over 0.5 s. Numbers and the state machine: ReplicatedStorage.Shared.Island.
-- WalkBoostLogic. The speed goes through ReplicatedStorage.Shared.Movement.SpeedModifiers (one
-- source, "IslandBoostLane", largest-wins, always computed from the base), so it never stacks, never
-- compounds, and never goes above 48 (a foreign base such as 40 x 1.5 is held to 48; a base already
-- above 48 is left as it is).
--
-- STATE GUARD (review M1): being over a strip only counts while the humanoid is walking
-- (Running, RunningNoPhysics, Landed), or in the air (Jumping, Freefall) for at most 1 s
-- (WalkBoostLogic.AirGrace), so a hop keeps the boost. Climbing, PlatformStand, Physics,
-- Ragdoll, FallingDown, GettingUp and any other state do not count: the boost runs its normal
-- 0.5 s linger and 0.5 s ease. Seated (Sit or a SeatPart), Swimming and Dead reset it to the exact
-- base at once, on the event. Standing up on a strip boosts again; off one, it does not. The state is
-- cached from Humanoid.StateChanged and Sit changes, both in the per-character Trove; the
-- classification is WalkBoostLogic.gait / stepGated (unit-tested).
--
-- THE SWITCHES. Two separate ones, so turning the lanes off does not take the island speed away:
--   lane boost  WalkBoost.ENABLED (code) and the LocalPlayer attribute "Lane3WalkBoostEnabled" = false
--               (run time): the boost, its dust and the strip reading are off; the island base stays.
--   island base WalkBoost.ISLAND_BASE_ENABLED (code) and the LocalPlayer attribute
--               "Lane3IslandBaseEnabled" = false (run time): WalkSpeed is left as the game has it
--               (the pre-island value comes back at once); lanes still multiply that base.
-- Both off: the starter creates nothing. Removing an attribute (or true) turns it back on. These are
-- client attributes: testing and debugging aids, not access control. A change to either switch
-- ends the current hold and starts a new one (restore, then re-apply), within the same call.
--
-- TRANSITION OWNERSHIP, home / boost / run (Lane 1, Brian R): a movement system that owns walking
-- speed (a run, a race, driving) sets the LocalPlayer attribute "MovementSpeedOwner" to its name (any
-- non-empty string) BEFORE it writes WalkSpeed. The island then releases completely: it clears the
-- boost, writes back the pre-island WalkSpeed, removes its effects, stops its frame loop and every
-- per-character connection, and writes NOTHING until the attribute is removed. When the attribute
-- is removed the island binds again and applies the base 32 once (the speed the humanoid has at that
-- moment is remembered as the new pre-island value). That system can consume the boost instead with
-- WalkBoost.new({ write = false, respectTakeover = false }), reading :multiplier() or Changed, or
-- replace SpeedModifiers behind the same API. Details in the spec.
--
-- FEEDBACK (Adam's Design 6, client only, never replicated): no effect at normal walking. Only while
-- the character is walking along a boost lane faster than 2 studs/s, one low, soft sand-coloured
-- dust puff behind a foot, at most 4 a second (WalkBoostLogic.PuffInterval), each lasting 0.25 s and
-- 0.15 to 0.35 stud across. None at rest, off the lane, in the air, after leaving the lane, under
-- Reduced Motion (GuiService.ReducedMotionEnabled, or the preview-only LocalPlayer attribute
-- "Lane3ReducedMotionOverride") or at low graphics detail (UserGameSettings.SavedQualityLevel 1 to
-- 3; Automatic is not low; the preview-only attribute "Lane3LowGraphicsOverride" = true/false forces
-- it). A change in either applies at once. No trails, streaks, glow, HUD or label; no camera, field of
-- view, jump or animation change. The built-in engine smoke texture only; nothing is uploaded.

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

WalkBoost.ENABLED = true -- the lane boost: the speed-up on the boost lanes and its dust puffs
WalkBoost.ISLAND_BASE_ENABLED = true -- the island base WalkSpeed (32); separate from the lane boost

WalkBoost.Source = "IslandBoostLane" -- the SpeedModifiers source name
WalkBoost.SwitchAttribute = "Lane3WalkBoostEnabled" -- LocalPlayer, false = lane boost off at run time
WalkBoost.BaseSwitchAttribute = "Lane3IslandBaseEnabled" -- LocalPlayer, false = island base off at run time
WalkBoost.TakeoverAttribute = "MovementSpeedOwner" -- LocalPlayer, a name = another system owns speed
WalkBoost.PublishAttribute = "IslandBoostMultiplier" -- LocalPlayer, read-only status (live runner)
WalkBoost.LowGraphicsOverride = "Lane3LowGraphicsOverride" -- LocalPlayer, preview only: forces low detail on/off
WalkBoost.EffectPrefix = "Lane3WalkBoost"

local ROOT_NAME = "Lane3_IslandEnvironment"
local LANES_NAME = "BoostLanes"
local OVERRIDE = "Lane3ReducedMotionOverride"
local SAND = Color3.fromRGB(226, 208, 172) -- soft sand / cream
local PUFF_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- built into the engine
local SPEED_EPSILON = 1e-3 -- WalkSpeed is stored as a float, so read-backs differ slightly

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
	islandBase: boolean?, -- default true; false: this controller never applies the island base
	baseSwitchAttribute: string?, -- default WalkBoost.BaseSwitchAttribute (tests use their own)
}

export type Status = {
	enabled: boolean, -- the lane boost switches are on
	islandEnabled: boolean, -- the island base switches are on (and this controller may write)
	takenOver: boolean,
	bound: boolean,
	pending: boolean,
	boosting: boolean, -- the binding runs the lane boost
	island: boolean, -- the binding holds (or held) the island base
	islandHeld: boolean, -- the island base is held right now
	islandWrites: number, -- times this controller has written the island base (once per bind)
	preIsland: number?, -- the WalkSpeed to write back when the island lets go
	character: Model?,
	multiplier: number,
	onStrip: boolean,
	overStrip: boolean,
	gait: WalkBoostLogic.Gait?,
	walkSpeed: number?,
	base: number?,
	connections: number,
	strips: number,
	reducedMotion: boolean,
	lowGraphics: boolean,
	dust: boolean, -- dust puffs are allowed now (neither Reduced Motion nor low graphics)
	puffs: number, -- dust puffs made so far
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
	dust: ParticleEmitter,
	at: Attachment, -- moved behind the foot of each puff
	feet: number, -- the ground under the root, root space
}

type Binding = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	trove: Trove.Trove,
	effects: Effects?,
	stateType: Enum.HumanoidStateType, -- the humanoid's state, kept by StateChanged (no polling)
	boost: boolean, -- runs the lane boost (state guard, frame loop, effects)
	island: boolean, -- holds the island base
	islandHeld: boolean,
	preIsland: number, -- WalkSpeed before the island wrote its base
	islandWrote: number, -- the WalkSpeed after that write (the stored float)
	lastPuff: number?,
	foot: number, -- 1 or -1, the side of the next puff
}

-- UserGameSettings, looked up once; nil when it is not available (every read is guarded).
local gameSettings: UserGameSettings? = nil
local gameSettingsTried = false

local function readQuality(settings: UserGameSettings): number
	return settings.SavedQualityLevel.Value
end

-- True when the player's saved graphics quality is low (levels 1 to 3). Automatic (0) is not low.
local function lowGraphicsSetting(): boolean
	if not gameSettingsTried then
		gameSettingsTried = true
		local ok, found = pcall(function()
			return UserSettings():GetService("UserGameSettings")
		end)
		if ok then
			gameSettings = found
		end
	end
	local settings = gameSettings
	if not settings then
		return false
	end
	local ok, level = pcall(readQuality, settings)
	return ok and type(level) == "number" and WalkBoostLogic.lowGraphics(level)
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < SPEED_EPSILON
end

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

-- The dust puff emitter at the feet: Rate 0 and never Enabled, puffs are made one at a time with
-- :Emit(1) by the controller (so the rate limit is exact and testable). Low, soft sand, opaque-looking
-- for most of its 0.25 s, then gone; the sizes are the limits of WalkBoostLogic.
local function makeEffects(t: Trove.Trove, humanoid: Humanoid, root: BasePart): Effects
	local feet = -(humanoid.HipHeight + root.Size.Y / 2) -- the ground under the root, root space
	local at = Instance.new("Attachment")
	at.Name = WalkBoost.EffectPrefix .. "DustAt"
	at.Position = Vector3.new(0, feet + 0.12, 0.6) -- behind the character (it faces -Z)
	at.Parent = root
	t:Add(at)
	local mid = (WalkBoostLogic.PuffSizeMin + WalkBoostLogic.PuffSizeMax) / 2
	local spread = (WalkBoostLogic.PuffSizeMax - WalkBoostLogic.PuffSizeMin) / 2
	local dust = Instance.new("ParticleEmitter")
	dust.Name = WalkBoost.EffectPrefix .. "Dust"
	dust.Texture = PUFF_TEXTURE
	dust.Color = ColorSequence.new(SAND)
	dust.Lifetime = NumberRange.new(WalkBoostLogic.PuffLifetime)
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, mid, spread), -- a random size between the limits
		NumberSequenceKeypoint.new(1, mid, spread),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.EmissionDirection = Enum.NormalId.Back -- behind the character
	dust.Speed = NumberRange.new(0.5, 1.5)
	dust.SpreadAngle = Vector2.new(25, 25)
	dust.Acceleration = Vector3.new(0, 1.5, 0)
	dust.Drag = 3
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.LightEmission = 0
	dust.LightInfluence = 1
	dust.LockedToPart = false -- the puffs stay where they were made as the character moves on
	dust.Rate = 0
	dust.Enabled = false
	dust.Parent = at
	t:Add(dust)
	return { dust = dust, at = at, feet = feet }
end

function WalkBoost.new(options: Options?): Controller
	local opts: Options = options or {}
	local player = opts.player or Players.LocalPlayer
	assert(player, "WalkBoost needs a player")
	local clock = opts.clock or os.clock
	local switchName = opts.switchAttribute or WalkBoost.SwitchAttribute
	local baseSwitchName = opts.baseSwitchAttribute or WalkBoost.BaseSwitchAttribute
	local write = opts.write ~= false
	local wantEffects = opts.effects ~= false
	local respectTakeover = opts.respectTakeover ~= false
	local islandAllowed = write and opts.islandBase ~= false -- a consumer never writes, so no base either

	local trove = Trove.new()
	local stripsTrove = trove:Extend()
	local changed = Signal.new() :: Signal.Signal<number>
	trove:Add(changed)
	local live = 0 -- live connections made by this controller
	local destroyed = false
	local state = WalkBoostLogic.newState()
	local bound: Binding? = nil
	local pending: { character: Model, trove: Trove.Trove, boost: boolean, island: boolean }? = nil
	local current = 1
	local lastOn = false -- the last sample counted as on a strip (over one, in a counting gait)
	local lastOver = false -- the last sample was over a strip (geometry only)
	local stripsModel: Instance? = nil
	local stripsDirty = true
	local strips: { Strip } = {}
	local halfWidth = WalkBoostLogic.HalfWidth
	local islandWrites = 0 -- times the island base was written (once per bind)
	local puffTotal = 0 -- dust puffs made

	local function track(t: Trove.Trove, signal: RBXScriptSignal, fn: (...any) -> ())
		local c = signal:Connect(fn)
		live += 1
		t:Add(function()
			c:Disconnect()
			live -= 1
		end)
	end

	local function boostSwitchOn(): boolean
		return WalkBoost.ENABLED and player:GetAttribute(switchName) ~= false
	end

	local function islandSwitchOn(): boolean
		return islandAllowed and WalkBoost.ISLAND_BASE_ENABLED and player:GetAttribute(baseSwitchName) ~= false
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

	local function lowGraphics(): boolean
		local override = player:GetAttribute(WalkBoost.LowGraphicsOverride)
		if type(override) == "boolean" then
			return override
		end
		return lowGraphicsSetting()
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

	-- No puff left on screen (Reduced Motion or low detail switched on, the lane left, a drop gait).
	local function clearDust(b: Binding)
		local e = b.effects
		if e then
			e.dust:Clear()
		end
	end

	-- Dust puffs, one per call at most: only while walking along a lane, moving, with motion and
	-- detail allowed (WalkBoostLogic.puffWanted), and at most one every PuffInterval (puffDue).
	local function dust(b: Binding, now: number, counted: boolean, gait: WalkBoostLogic.Gait)
		local e = b.effects
		if not e or not counted or gait ~= "walk" then
			return
		end
		local v = b.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if not WalkBoostLogic.puffWanted(counted, gait, speed, reducedMotion(), lowGraphics()) then
			return
		end
		if not WalkBoostLogic.puffDue(b.lastPuff, now) then
			return
		end
		b.lastPuff = now
		b.foot = -b.foot
		e.at.Position = Vector3.new(0.4 * b.foot, e.feet + 0.12, 0.6) -- behind the left or right foot
		e.dust:Emit(1)
		puffTotal += 1
	end

	local function setMultiplier(m: number)
		if m ~= current then
			current = m
			publish(m)
			changed:Fire(m)
		end
	end

	-- The island base, written once when a binding starts: the WalkSpeed the humanoid has now is
	-- remembered as the pre-island value, then 32 is written (nothing is written if it is already 32).
	local function holdIsland(b: Binding)
		local h = b.humanoid
		b.preIsland = h.WalkSpeed
		if not near(h.WalkSpeed, WalkBoostLogic.IslandBase) then
			h.WalkSpeed = WalkBoostLogic.IslandBase
			islandWrites += 1
		end
		b.islandWrote = h.WalkSpeed -- the stored (float) value, so the later comparison matches
		b.islandHeld = true
	end

	-- Lets go of the island base: the exact pre-island WalkSpeed comes back, but only if WalkSpeed is
	-- still what the island wrote. Anything else is someone else's value and stays. The boost source
	-- is cleared before this, so the value compared is the base itself.
	local function releaseIsland(b: Binding)
		if not b.islandHeld then
			return
		end
		b.islandHeld = false
		local h = b.humanoid
		if near(h.WalkSpeed, b.islandWrote) then
			h.WalkSpeed = b.preIsland
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
		lastOver = false
		if write then
			SpeedModifiers.clear(b.humanoid, WalkBoost.Source) -- the exact base comes back
			releaseIsland(b)
		end
		b.trove:Destroy()
		stripsTrove:Clean()
		stripsModel = nil
		setMultiplier(1)
		publish(nil)
	end

	-- The state guard's gait for the bound humanoid (WalkBoostLogic.gait): the cached state plus
	-- the Sit, SeatPart and PlatformStand properties, which change before the state does.
	local function gaitOf(b: Binding): WalkBoostLogic.Gait
		local h = b.humanoid
		return WalkBoostLogic.gait(b.stateType, h.Sit or h.SeatPart ~= nil, h.PlatformStand)
	end

	local function apply(b: Binding, m: number)
		if write then
			if m > 1 then
				SpeedModifiers.set(b.humanoid, WalkBoost.Source, m)
			else
				SpeedModifiers.clear(b.humanoid, WalkBoost.Source)
			end
		end
		setMultiplier(m)
	end

	local function update(nowArg: number?): number
		local b = bound
		if destroyed or not b or not b.boost then
			return 1
		end
		local now = nowArg or clock()
		local list, hw = currentStrips()
		local over = b.root.Parent ~= nil
			and b.humanoid.Health > 0
			and WalkBoostLogic.overStrip(b.root.Position, list, hw)
		local gait = gaitOf(b)
		local m, counted = WalkBoostLogic.stepGated(state, now, over, gait)
		lastOver = over
		lastOn = counted
		apply(b, m)
		dust(b, now, counted, gait)
		return m
	end

	-- A drop gait (seated, swimming, dead) takes effect on the event, without waiting for a frame:
	-- exact base speed and no puff at once. Other gait changes wait for the next update, whose
	-- time comes from the clock (the event handler has no time of its own).
	local function guard(b: Binding)
		if bound == b and b.boost and gaitOf(b) == "drop" then
			WalkBoostLogic.reset(state)
			lastOn = false
			apply(b, 1)
			clearDust(b)
		end
	end

	local function bind(character: Model, boost: boolean, island: boolean)
		unbind()
		local t = Trove.new()
		local p = { character = character, trove = t, boost = boost, island = island }
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
				effects = if boost and wantEffects then makeEffects(t, humanoid, root) else nil,
				stateType = humanoid:GetState(),
				boost = boost,
				island = island,
				islandHeld = false,
				preIsland = humanoid.WalkSpeed,
				islandWrote = humanoid.WalkSpeed,
				foot = 1,
			}
			bound = binding
			WalkBoostLogic.reset(state)
			track(t, humanoid.Died, function()
				if bound == binding then
					unbind()
				end
			end)
			if island and humanoid.Health > 0 then
				holdIsland(binding) -- the one write of 32 for this character
			end
			if not boost then
				return
			end
			-- the state guard: the state is cached from StateChanged; Sit covers seats and scripted
			-- sits alike (Humanoid.Seated only fires for seat parts)
			track(t, humanoid.StateChanged, function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
				binding.stateType = new
				guard(binding)
			end)
			track(t, humanoid:GetPropertyChangedSignal("Sit"), function()
				guard(binding)
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
		local away = takenOver()
		local wantBoost = boostSwitchOn() and not away
		local wantIsland = islandSwitchOn() and not away
		if (wantBoost or wantIsland) and character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health <= 0 then
				unbind() -- a dead character waits for its replacement
				return
			end
			local b, p = bound, pending
			if b and b.character == character and b.boost == wantBoost and b.island == wantIsland then
				return
			end
			if p and p.character == character and p.boost == wantBoost and p.island == wantIsland then
				return
			end
			bind(character, wantBoost, wantIsland)
		else
			unbind()
		end
	end

	-- Reduced Motion or low detail switched on: no puff stays on screen.
	local function settle()
		local b = bound
		if b and (reducedMotion() or lowGraphics()) then
			clearDust(b)
		end
	end

	track(trove, player.AttributeChanged, function(name: string)
		if name == switchName or name == baseSwitchName or name == WalkBoost.TakeoverAttribute then
			refresh()
		elseif name == OVERRIDE or name == WalkBoost.LowGraphicsOverride then
			settle()
		end
	end)
	track(trove, GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), settle)
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
			return {
				enabled = boostSwitchOn(),
				islandEnabled = islandSwitchOn(),
				takenOver = takenOver(),
				bound = b ~= nil,
				pending = pending ~= nil,
				boosting = b ~= nil and b.boost,
				island = b ~= nil and b.island,
				islandHeld = b ~= nil and b.islandHeld,
				islandWrites = islandWrites,
				preIsland = if b and b.islandHeld then b.preIsland else nil,
				character = if b then b.character else nil,
				multiplier = current,
				onStrip = lastOn,
				overStrip = lastOver,
				gait = if b then gaitOf(b) else nil,
				walkSpeed = if b then b.humanoid.WalkSpeed else nil,
				base = if b then SpeedModifiers.base(b.humanoid) else nil,
				connections = live,
				strips = #(if opts.strips then opts.strips else strips),
				reducedMotion = reducedMotion(),
				lowGraphics = lowGraphics(),
				dust = not reducedMotion() and not lowGraphics(),
				puffs = puffTotal,
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
-- reduced motion, character added and removing. A binding adds Died (the island base only needs
-- that one); a lane-boost binding adds the two state-guard watchers (StateChanged, Sit) and, unless
-- manual, the frame loop; reading the built lanes (no fixed strips) adds two strip watchers while
-- the boost is bound.
WalkBoost.IdleConnections = 4
WalkBoost.IslandConnections = 1 -- Died (island base only)
WalkBoost.GuardConnections = 2 -- StateChanged + Sit
WalkBoost.BoundConnections = 4 -- Died + guard + frame loop (manual: 3)
WalkBoost.StripWatchConnections = 2

return WalkBoost
