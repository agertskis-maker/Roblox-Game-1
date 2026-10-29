--!strict
-- Stamina demo meter (Lane 3 preview; Round 2 R2-S1, revised in Round 3 R3-S1 / R3-S2 / R3-F15). PRESENTATION OF A
-- PROPOSAL, off by default: it draws store.run.stamina = { value, max, ... } and nothing else. The rule (10 per run, one
-- spent per ACCEPTED hop, no Hop at zero while the current ride continues) belongs to Lane 1 and the upgrade/restore
-- questions to the team; a fixture adapter in the playground stands in for them, and nothing here blocks input, spends,
-- saves or ends a run.
--
-- Look (Round 3): a sharp zigzag lightning bolt with a thick dark edge (Run/StaminaBolt), the exact number beside it,
-- and ten small bolt pips (the same shape, simpler) that are counted by colour: lit = the state colour, unlit = dark.
-- The number is primary, so nobody has to count pips under pressure. `max` is configurable: up to 10 each pip is one
-- unit; above 10 there are still 10 pips, each standing for ceil(max / 10) units, and the number carries the exact
-- value ("14 / 20").
--
-- EXACT STATES for a maximum of 10 (StaminaMeter.stateFor, the one pure function; other maxima scale by the same
-- 60% / 40% lines, with integer arithmetic so there is no rounding at a boundary):
--   6 to 10   Normal  yellow
--   4 to 5    Orange  orange (an early warning: bolt, number and lit pips)
--   1 to 3    Red     red + LOW STAMINA + a restrained glow pulse (the "5 or fewer" idea does NOT override this)
--   0         Empty   grey, a crack across the bolt, OUT OF STAMINA (persistent), pips hidden, Hop unavailable
-- The Hop button reads the same store value (HopState.resolve: stamina.value <= 0 = OutOfStamina), so nothing is sent to
-- it; getDebugState().hopUnavailable only mirrors that fact for the tests.
--
-- Motion rules: nothing animates except on a transition. A value change pops the number and the bolt once; a drained
-- pip shrinks and settles, a refilled pip pops in (one tween per pip, cancelled by the next change); the Red glow is
-- ONE looping tween on one frame, started when Red begins and cancelled when it ends, the meter hides, or Reduce Motion
-- turns on (then the glow is steady and strong and the words are static). getDebugState().activeTweens counts them.
--   * a restoring pickup (fixture switch, off by default): value rises, one pip refills; with a world position a small
--     bolt flies from the projected pickup to the meter; nothing flies when already full or in reduced motion.
--   * EMPTY TAPS: a tap on the unavailable Hop button is reported as the store event HopRejected { reason =
--     "OutOfStamina" } (or by calling meter:emptyTap(); also reachable as RunBus.get(ctx, "stamina")). The feedback (a
--     small pop of OUT OF STAMINA and one Warning sound) happens at most once per EMPTY_THROTTLE (1.5 s); every other
--     tap in the window is counted and ignored. It never ends the run.
--
-- Placement (R3-F15, thumb clearance): the meter draws from the TOP of RunLayout.staminaRect and on phones sizes its
-- one row to the room that really lies above the thumbstick zone (ctx rect top to the zone's top, a 1 px margin), never
-- below MIN_ROW. The rectangle itself may still sink into the zone (RunLayout.staminaSoft): the CONTENT does not.
-- getDebugState reports the content's overlap with the reserved zones, measured two ways (the layout numbers, and the
-- real AbsolutePosition through ctx.screen:overlapsReserved).
--
--   local meter = StaminaMeter.new(ctx)
--   meter:layout(), meter:setVisible(on), meter:destroy(), meter:getDebugState()
--   meter:emptyTap() -> boolean              -- true when the throttled feedback played
--   StaminaMeter.stateFor(value, max) -> "Normal" | "Orange" | "Red" | "Empty"
--   StaminaMeter.pipsFor(max) -> (pips, unitsPerPip)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local StaminaBolt = require(script.Parent.StaminaBolt)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

export type MeterState = "Normal" | "Orange" | "Red" | "Empty"

local MAX_PIPS = 10
local LOW_WORD_SECONDS = 2.5 -- phones: how long LOW STAMINA replaces the pips
local FLIGHT_SECONDS = 0.45
local FLIGHT_WINDOW = 0.6 -- a pickup event this recent explains a value increase
local FLIGHT_SIZE = 34
-- TOKEN CANDIDATE: the Round 3 timings (the brief fixes the 1.5 s; the glow values are a calm preview choice)
local EMPTY_THROTTLE = 1.5 -- seconds: at most one empty-tap feedback (and one sound) per window
local PULSE_SECONDS = 0.9 -- each half of the Red glow; one full cycle is 1.8 s (0.55 Hz, calm)
local HALO_STRONG = 0.45 -- Red glow transparency at its peak, and the steady value in reduced motion
local HALO_SOFT = 0.8 -- ... at its low

-- TOKEN CANDIDATE: the state colours (yellow and orange keep the Round 2 values; red and grey are new)
local YELLOW = Color3.fromRGB(255, 214, 40)
local ORANGE = Color3.fromRGB(255, 140, 20)
local RED = Color3.fromRGB(236, 58, 52)
local GREY = Color3.fromRGB(170, 176, 190)
local PIP_EMPTY = Color3.fromRGB(58, 68, 98)

-- TOKEN CANDIDATE: layout numbers (design px). Phones: one row; the width stays left of the protected road view on the
-- smallest frame (x 182.6 there, the rectangle starts at 12). Full (desktop, tablet): the bolt and number, then the pips.
local MIN_ROW = 20 -- phones: the smallest row; below this the bolt stops being a bolt
local MAX_ROW = 28
local ZONE_CLEAR = 1 -- px kept between the content and the thumbstick zone
local COMPACT_WIDTH = 168
local FULL_ROW = 46
local FULL_HERO = 44
local FULL_PIP_H = 20
local FULL_PIP_PITCH = 18
local FULL_PIP_Y = 48
local PIP_SLIM = 0.8 -- pips are 20% narrower than the hero

-- pips: a one pixel edge when small, two when large (a whole number of pixels, see StaminaBolt)
local function pipOutline(pipH: number): number
	return if pipH >= 16 then 2 else 1
end

local function sequence(a: Color3, b: Color3, c: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.5, b),
		ColorSequenceKeypoint.new(1, c),
	})
end
local FACES: { [string]: ColorSequence } = {
	Normal = A.Face.Keys,
	Orange = sequence(Color3.fromRGB(255, 214, 120), ORANGE, Color3.fromRGB(226, 96, 0)),
	Red = A.Face.Danger,
	Empty = sequence(Color3.fromRGB(214, 218, 228), Color3.fromRGB(168, 174, 188), Color3.fromRGB(130, 136, 152)),
}
local TINTS: { [string]: Color3 } = { Normal = YELLOW, Orange = ORANGE, Red = RED, Empty = GREY }
local WORDS: { [string]: string } = { Red = "LOW STAMINA", Empty = "OUT OF STAMINA" }

type Pip = { holder: Frame, bolt: StaminaBolt.Bolt, scale: UIScale, lit: boolean }

type Metrics = {
	compact: boolean,
	rowH: number, -- height of the first row (the whole content on phones)
	heroH: number,
	heroW: number,
	heroY: number,
	numberX: number,
	numberSize: number,
	pipH: number,
	pipW: number,
	pipT: number, -- pip outline, px
	pitch: number,
	pipX: number,
	pipY: number,
	height: number, -- the whole content
}

type Part = { name: string, x: number, y: number, w: number, h: number } -- holder-local design px

local StaminaMeter = {}
StaminaMeter.__index = StaminaMeter

-- Pips for a configured max: (pip count, units per pip). Up to 10 each pip is one unit.
function StaminaMeter.pipsFor(max: number): (number, number)
	local n = math.max(1, math.floor(max))
	if n <= MAX_PIPS then
		return n, 1
	end
	return MAX_PIPS, math.ceil(n / MAX_PIPS)
end

-- THE state function (pure; the scenarios call it). Integer arithmetic: value / max >= 60% is Normal, >= 40% Orange,
-- anything above zero Red, zero Empty. For a maximum of 10: 6..10 Normal, 4..5 Orange, 1..3 Red, 0 Empty.
function StaminaMeter.stateFor(value: number, max: number): MeterState
	local cap = if max == max then math.max(1, math.floor(max)) else 1
	local v = if value == value then math.clamp(math.floor(value), 0, cap) else 0
	if v <= 0 then
		return "Empty"
	end
	if v * 5 >= cap * 3 then
		return "Normal"
	end
	if v * 5 >= cap * 2 then
		return "Orange"
	end
	return "Red"
end

local function rgbText(c: Color3): string
	return string.format(
		"%d,%d,%d",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

-- The thumbstick zone in design px, when this frame has one that sits above/below the meter's columns.
local function thumbZone(ctx: RunLayout.Ctx, rect: RunLayout.Rect): RunLayout.Rect?
	for _, z in RunLayout.zones(ctx) do
		if z.name == "Thumbstick" and z.pos.X < rect.pos.X + rect.size.X and z.pos.X + z.size.X > rect.pos.X then
			return z
		end
	end
	return nil
end

-- How far (design px, vertically) `r` reaches into the deepest reserved zone, and which zone.
local function zoneDepth(ctx: RunLayout.Ctx, r: RunLayout.Rect): (number, string?)
	local best, name = 0, nil :: string?
	for _, z in RunLayout.zones(ctx) do
		local dx = math.min(r.pos.X + r.size.X, z.pos.X + z.size.X) - math.max(r.pos.X, z.pos.X)
		local dy = math.min(r.pos.Y + r.size.Y, z.pos.Y + z.size.Y) - math.max(r.pos.Y, z.pos.Y)
		if dx > 0 and dy > 0 and dy > best then
			best, name = dy, z.name
		end
	end
	return best, name
end

function StaminaMeter.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, StaminaMeter)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._shown = false
	self._wasShown = false
	self._dirty = true
	self._value = -1
	self._max = 10
	self._state = "Normal" :: MeterState
	self._chars = 2 -- characters reserved for the number (the widest it gets for this max)
	self._compact = false
	self._rect = nil :: RunLayout.Rect?
	self._m = nil :: Metrics?
	self._parts = {} :: { Part }
	self._pips = {} :: { Pip }
	self._pipSpec = "" :: string
	self._hero = nil :: StaminaBolt.Bolt?
	self._heroSpec = "" :: string
	self._live = {} :: { [Tween]: boolean } -- every tween this meter made that has not finished
	self._pulse = nil :: Tween?
	self._drains = 0
	self._refills = 0
	self._flights = 0
	self._flightsLive = 0
	self._ticks = 0
	self._emptyTaps = 0
	self._emptyWarnings = 0
	self._emptySounds = 0
	self._emptyThrottled = 0
	self._lastEmpty = -math.huge
	self._lowWordUntil = 0
	self._swapTimer = nil :: thread? -- the one pending "LOW STAMINA" swap-back, never more than one
	self._dead = false
	self._pickup = nil :: { at: number, pos: Vector2? }?
	self._connections = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "StaminaMeter"))
	self.root = root
	local holder = make("Frame", { Name = "Meter", BackgroundTransparency = 1, ZIndex = 2, Parent = root })
	RunKit.nonInteractive(holder)
	self._holder = holder

	-- the Red glow: one soft ellipse behind the bolt (hidden unless Red)
	local halo = make("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = RED,
		BackgroundTransparency = HALO_STRONG,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = holder,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = halo })
	self._halo = halo

	local heroHolder = make("Frame", {
		Name = "Bolt",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = holder,
	})
	local heroPop = make("UIScale", { Name = "Pop", Parent = heroHolder })
	self._heroHolder = heroHolder

	local number = Arcade.text(holder, {
		text = "",
		role = "Value",
		name = "Number",
		italic = true,
		face = "Keys",
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 4,
	})
	number.AnchorPoint = Vector2.new(0, 0.5)
	local numberPop = make("UIScale", { Name = "Pop", Parent = number })
	self._number = number
	self._numberGrad = number:FindFirstChildOfClass("UIGradient") :: UIGradient

	local word = Arcade.text(holder, {
		text = "",
		role = "Small",
		name = "Word",
		face = "Danger",
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 4,
	})
	word.AnchorPoint = Vector2.new(0, 0.5)
	word.Visible = false
	local wordPop = make("UIScale", { Name = "Pop", Parent = word })
	self._word = word
	self._wordGrad = word:FindFirstChildOfClass("UIGradient") :: UIGradient

	local pips = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = holder,
	})
	self._pipRow = pips

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode == "Run" and from ~= "Run" then
			self._value = -1 -- a new run: show the first state without an animation
		end
		self._dirty = true
		self:_apply()
	end)
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "StaminaPickup" then
			local pos: Vector2? = nil
			if event.worldPosition then
				local p, on = RunLayout.worldToCanvas(ctx, event.worldPosition)
				if on then
					pos = p
				end
			end
			self._pickup = { at = os.clock(), pos = pos }
		elseif event.kind == "HopRejected" and event.reason == "OutOfStamina" then
			self:emptyTap()
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		if not self._dead then
			self._dirty = true
			self:_apply()
		end
	end))
	self._connections = 4
	self._trove:Add(function()
		self._dead = true
		local timer = self._swapTimer
		if timer then
			self._swapTimer = nil
			pcall(task.cancel, timer)
		end
		Motion.cancelAll(halo)
		Motion.cancelAll(heroPop)
		Motion.cancelAll(numberPop)
		Motion.cancelAll(wordPop)
		for _, pip in self._pips do
			Motion.cancelAll(pip.scale)
		end
		for t in self._live do
			pcall(function()
				t:Cancel()
			end)
		end
		table.clear(self._live)
		RunBus.unregister(ctx, "stamina", self)
	end)
	RunBus.register(ctx, "stamina", self)
	self:layout()
	return self
end

export type StaminaMeter = typeof(StaminaMeter.new((nil :: any) :: RunLayout.Ctx))

-- TWEENS ---------------------------------------------------------------------------------------------------------

function StaminaMeter._track(self: StaminaMeter, t: Tween): Tween
	self._live[t] = true
	t.Completed:Connect(function()
		self._live[t] = nil
		if self._pulse == t then
			self._pulse = nil
		end
	end)
	return t
end

function StaminaMeter._tween(
	self: StaminaMeter,
	instance: Instance,
	key: string,
	info: TweenInfo,
	goal: { [string]: any }
): Tween
	return self:_track(Motion.tween(instance, key, info, goal))
end

-- A short emphasis on a "Pop" UIScale child; nothing in reduced motion.
function StaminaMeter._pop(self: StaminaMeter, target: GuiObject, scale: number)
	if Motion.reduced() then
		return
	end
	local ui = target:FindFirstChild("Pop") :: UIScale?
	if not ui then
		return
	end
	ui.Scale = 1
	local up = self:_tween(ui, "pop", Motion.info(0.08, Enum.EasingStyle.Back), { Scale = scale })
	up.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not self._dead then
			self:_tween(ui, "pop", Motion.info(0.1), { Scale = 1 })
		end
	end)
end

function StaminaMeter._stopPulse(self: StaminaMeter)
	local halo = self._halo :: Frame
	Motion.cancelAll(halo)
	self._pulse = nil
end

-- The Red glow: hidden unless Red and shown; steady and strong in reduced motion; otherwise one calm looping tween.
function StaminaMeter._applyHalo(self: StaminaMeter)
	local halo = self._halo :: Frame
	local on = self._shown and self._state == "Red"
	halo.Visible = on
	if not on then
		self:_stopPulse()
		return
	end
	if Motion.reduced() then
		self:_stopPulse()
		halo.BackgroundTransparency = HALO_STRONG
		return
	end
	if self._pulse == nil then
		halo.BackgroundTransparency = HALO_STRONG
		self._pulse = self:_tween(
			halo,
			"pulse",
			TweenInfo.new(PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = HALO_SOFT }
		)
	end
end

-- ART ------------------------------------------------------------------------------------------------------------

-- The room-aware numbers for the current layout (see the header: Placement).
function StaminaMeter._measure(self: StaminaMeter): Metrics
	local ctx = self._ctx
	local rect = self._rect or RunLayout.staminaRect(ctx)
	local count = StaminaMeter.pipsFor(self._max)
	local chars = self._chars
	if self._compact then
		local room = rect.size.Y
		local zone = thumbZone(ctx, rect)
		if zone then
			room = math.min(room, zone.pos.Y - rect.pos.Y - ZONE_CLEAR)
		end
		local rowH = math.clamp(math.floor(room), MIN_ROW, MAX_ROW)
		local heroW = StaminaBolt.metrics(rowH)
		local numberSize = math.clamp(math.floor(rowH * 0.72 + 0.5), 16, 22)
		local numberX = heroW + 3
		local pipX = math.floor(numberX + chars * 0.62 * numberSize + 9 + 2 + 0.5)
		local pitch = math.floor((COMPACT_WIDTH - pipX) / count) -- whole pixels: the pips are evenly spaced
		local pipH = math.min(rowH - 3, 16)
		local pipW = StaminaBolt.metrics(pipH, pipOutline(pipH), PIP_SLIM)
		while pipW > pitch - 2 and pipH > 9 do
			pipH -= 1
			pipW = StaminaBolt.metrics(pipH, pipOutline(pipH), PIP_SLIM)
		end
		return {
			compact = true,
			rowH = rowH,
			heroH = rowH,
			heroW = heroW,
			heroY = 0,
			numberX = numberX,
			numberSize = numberSize,
			pipH = pipH,
			pipW = pipW,
			pipT = pipOutline(pipH),
			pitch = pitch,
			pipX = pipX,
			pipY = math.floor((rowH - pipH) / 2),
			height = rowH,
		}
	end
	local heroW = StaminaBolt.metrics(FULL_HERO)
	local pipW = StaminaBolt.metrics(FULL_PIP_H, pipOutline(FULL_PIP_H), PIP_SLIM)
	return {
		compact = false,
		rowH = FULL_ROW,
		heroH = FULL_HERO,
		heroW = heroW,
		heroY = (FULL_ROW - FULL_HERO) / 2,
		numberX = heroW + 4,
		numberSize = A.Text.Value,
		pipH = FULL_PIP_H,
		pipW = pipW,
		pipT = pipOutline(FULL_PIP_H),
		pitch = FULL_PIP_PITCH,
		pipX = 2,
		pipY = FULL_PIP_Y,
		height = FULL_PIP_Y + FULL_PIP_H,
	}
end

-- (Re)builds the hero bolt when its size changed.
function StaminaMeter._ensureHero(self: StaminaMeter, m: Metrics)
	local spec = string.format("%.1f", m.heroH)
	if spec == self._heroSpec and self._hero then
		return
	end
	self._heroSpec = spec
	local old = self._hero
	if old then
		old:destroy()
	end
	local bolt = StaminaBolt.new(self._heroHolder, {
		height = m.heroH,
		colour = TINTS[self._state],
		shine = true,
		crack = true,
		name = "Art",
		z = 3,
	})
	bolt:setCracked(self._state == "Empty")
	self._hero = bolt
end

-- (Re)builds the pip row for `count` pips of the current size. Lit states survive a rebuild (no false animation).
function StaminaMeter._ensurePips(self: StaminaMeter, count: number, m: Metrics)
	local spec = string.format("%d:%d:%d", count, m.pipH, m.pitch)
	if spec == self._pipSpec then
		return
	end
	self._pipSpec = spec
	local before: { boolean } = {}
	for i, p in self._pips do
		before[i] = p.lit
		Motion.cancelAll(p.scale)
		p.holder:Destroy()
	end
	table.clear(self._pips)
	for i = 1, count do
		local h = make("Frame", {
			Name = "Pip" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((i - 1) * m.pitch + m.pipW / 2, m.pipH / 2),
			Size = UDim2.fromOffset(m.pipW, m.pipH),
			ZIndex = 3,
			Parent = self._pipRow,
		})
		local scale = make("UIScale", { Name = "Pop", Parent = h })
		local bolt = StaminaBolt.new(h, {
			height = m.pipH,
			colour = PIP_EMPTY,
			outline = m.pipT,
			slim = PIP_SLIM,
			name = "Art",
			z = 3,
		})
		table.insert(
			self._pips,
			{ holder = h, bolt = bolt, scale = scale, lit = if before[i] == nil then true else before[i] }
		)
	end
	self._pipRow.Size = UDim2.fromOffset(count * m.pitch, m.pipH)
end

function StaminaMeter._flyBolt(self: StaminaMeter, from: Vector2)
	self._flights += 1
	local rect, m = self._rect, self._m
	if not rect or not m then
		return
	end
	local fly = make("Frame", {
		Name = "Flight",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(FLIGHT_SIZE, FLIGHT_SIZE),
		ZIndex = 20,
		Parent = self.root,
	})
	RunKit.nonInteractive(fly)
	local scale = make("UIScale", { Name = "Fly", Parent = fly })
	local bolt = StaminaBolt.new(fly, { height = FLIGHT_SIZE, colour = YELLOW, shine = true, name = "Art", z = 20 })
	bolt.root.AnchorPoint = Vector2.new(0.5, 0.5)
	bolt.root.Position = UDim2.fromScale(0.5, 0.5)
	self._flightsLive += 1
	local target = Vector2.new(rect.pos.X + m.heroW / 2, rect.pos.Y + m.heroY + m.heroH / 2)
	local info = Motion.info(FLIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	self:_tween(scale, "fly", info, { Scale = 0.7 })
	local t = self:_tween(fly, "fly", info, { Position = UDim2.fromOffset(target.X, target.Y) })
	t.Completed:Connect(function()
		self._flightsLive -= 1
		fly:Destroy()
	end)
end

-- APPLY ----------------------------------------------------------------------------------------------------------

function StaminaMeter._apply(self: StaminaMeter)
	local state = self._ctx.store:get()
	local run = state.run
	local st = if run then run.stamina else nil
	local shown = self._visible and state.mode == "Run" and st ~= nil
	self.root.Visible = self._visible
	self._holder.Visible = shown
	self._shown = shown
	if shown and not self._wasShown then
		self._dirty = true -- shown again: redo the glow and the layout even if the value did not change
	end
	self._wasShown = shown
	if not shown or st == nil then
		self:_applyHalo()
		return
	end
	local stamina = st :: Store.StaminaState
	local max = math.max(1, math.floor(stamina.max))
	local value = math.clamp(math.floor(stamina.value), 0, max) -- never negative or above max
	local level = StaminaMeter.stateFor(value, max)
	if not self._dirty and value == self._value and max == self._max and level == self._state then
		return -- the run state ticks at 10 Hz; nothing about the meter changed
	end
	self._dirty = false
	local previous = self._value
	local first = previous < 0
	local levelChanged = level ~= self._state
	self._value, self._max, self._state = value, max, level
	local count, units = StaminaMeter.pipsFor(max)
	self._chars = if units > 1 then #string.format("%d / %d", max, max) else #tostring(max)
	local reduced = Motion.reduced()
	if levelChanged and level == "Red" and not first then
		self._lowWordUntil = os.clock() + LOW_WORD_SECONDS
	end

	local m = self:_measure()
	self._m = m
	self:_ensureHero(m)
	self:_ensurePips(count, m)
	local tint = TINTS[level]
	local hero = self._hero :: StaminaBolt.Bolt
	hero:setColour(tint)
	hero:setCracked(level == "Empty")

	local litCount = math.clamp(math.ceil(value / units), 0, count)
	for i, pip in self._pips do
		local lit = i <= litCount
		local wasLit = pip.lit
		pip.lit = lit
		pip.bolt:setColour(if lit then tint else PIP_EMPTY)
		if first or reduced or wasLit == lit then
			Motion.cancelAll(pip.scale)
			pip.scale.Scale = 1
		elseif wasLit then
			-- one pip drains: it shrinks and settles
			self._drains += 1
			pip.scale.Scale = 0.55
			self:_tween(pip.scale, "flick", Motion.info(0.18, Enum.EasingStyle.Quad), { Scale = 1 })
		else
			-- a restored pip pops back in
			self._refills += 1
			pip.scale.Scale = 0.4
			self:_tween(pip.scale, "flick", Motion.info(0.2, Enum.EasingStyle.Back), { Scale = 1 })
		end
	end

	-- the number: exact value (with the max when the pips are grouped)
	local text = if units > 1 then string.format("%d / %d", value, max) else tostring(value)
	self._numberGrad.Color = FACES[level]
	local changed = text ~= self._number.Text
	self._number.Text = text
	self._ticks += if changed then 1 else 0
	self._word.Text = WORDS[level] or ""
	self._wordGrad.Color = if level == "Empty" then A.Face.White else A.Face.Danger

	-- animations: only on a real change after the first state, never in reduced motion
	if not first and not reduced and value ~= previous then
		self:_pop(self._number, 1.18)
		self:_pop(self._heroHolder, if levelChanged then 1.3 else 1.15)
		if value > previous then
			task.defer(function()
				-- decided one frame later so the pickup event is known whichever listener ran first
				if self._dead then
					return
				end
				local recent = self._pickup
				if recent and os.clock() - recent.at < FLIGHT_WINDOW and recent.pos then
					self:_flyBolt(recent.pos)
				end
			end)
		end
	end
	self:_applyHalo()
	self:_layoutInner()
end

function StaminaMeter._layoutInner(self: StaminaMeter)
	if not self._shown then
		return
	end
	local m = self:_measure()
	self._m = m
	local level = self._state
	local compact = m.compact
	local mid = m.rowH / 2
	local parts: { Part } = {}

	-- bolt (and its glow)
	local heroHolder = self._heroHolder :: Frame
	heroHolder.Position = UDim2.fromOffset(m.heroW / 2, m.heroY + m.heroH / 2)
	heroHolder.Size = UDim2.fromOffset(m.heroW, m.heroH)
	table.insert(parts, { name = "Bolt", x = 0, y = m.heroY, w = m.heroW, h = m.heroH })
	local halo = self._halo :: Frame
	halo.Position = heroHolder.Position
	halo.Size = UDim2.fromOffset(math.floor(m.heroW + m.heroH * 0.5), math.min(m.heroH + 2, m.rowH))

	-- number
	local number = self._number :: TextLabel
	number.Position = UDim2.fromOffset(m.numberX, mid)
	number.TextSize = m.numberSize
	number.Size = UDim2.fromOffset(0, m.rowH)
	local numberBox = #number.Text * 0.62 * m.numberSize + 9
	table.insert(parts, { name = "Number", x = m.numberX, y = 0, w = numberBox, h = m.rowH })

	-- the state word
	local word = self._word :: TextLabel
	local wordText = word.Text
	local wordOn = wordText ~= ""
	local compactSwap = compact and level == "Red" and os.clock() < self._lowWordUntil
	local showWord, showPips
	local wordSize = if compact then 16 else (if level == "Empty" then 18 else 16)
	word.TextSize = wordSize
	word.Size = UDim2.fromOffset(0, if compact then m.rowH else wordSize + 6)
	local wordW = #wordText * 0.56 * wordSize
	if compact then
		-- phones: the word takes the pips' slot at zero (persistently) and for a moment on turning red
		showWord = wordOn and (level == "Empty" or compactSwap)
		showPips = not showWord
		word.Position = UDim2.fromOffset(m.numberX + numberBox + 2, mid)
		if showWord then
			table.insert(parts, { name = "Word", x = m.numberX + numberBox + 2, y = 0, w = wordW, h = m.rowH })
		end
		if compactSwap and not self._swapTimer then
			-- one timer per swap window: _layoutInner runs on every change, and a timer per call piled up threads
			self._swapTimer = task.delay(LOW_WORD_SECONDS + 0.05, function()
				self._swapTimer = nil
				if self._dead or not self._ctx.store:get().run then
					return
				end
				self:_layoutInner()
			end)
		end
	elseif level == "Empty" then
		-- full layout, empty: the reason takes the pips' row (all ten would be dark anyway)
		showWord, showPips = wordOn, false
		word.Position = UDim2.fromOffset(2, m.pipY + m.pipH / 2)
		table.insert(parts, { name = "Word", x = 2, y = m.pipY, w = wordW, h = m.pipH })
	else
		-- full layout, red: LOW STAMINA beside the number; the pips stay
		showWord, showPips = wordOn, true
		word.Position = UDim2.fromOffset(m.numberX + numberBox + 2, mid)
		if wordOn then
			table.insert(parts, {
				name = "Word",
				x = m.numberX + numberBox + 2,
				y = mid - (wordSize + 6) / 2,
				w = wordW,
				h = wordSize + 6,
			})
		end
	end
	word.Visible = showWord
	self._pipRow.Visible = showPips
	self._pipRow.Position = UDim2.fromOffset(m.pipX, m.pipY)
	if showPips then
		table.insert(parts, { name = "Pips", x = m.pipX, y = m.pipY, w = #self._pips * m.pitch, h = m.pipH })
	end
	self._parts = parts
end

function StaminaMeter.layout(self: StaminaMeter)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect = RunLayout.staminaRect(ctx)
	self._rect = rect
	self._compact = RunLayout.compact(ctx)
	RunLayout.place(self._holder, rect)
	self._heroSpec = "" -- rebuild at the new size
	self._pipSpec = ""
	self._dirty = true
	self:_apply()
end

function StaminaMeter.setVisible(self: StaminaMeter, on: boolean)
	self._visible = on
	self._dirty = true
	self:_apply()
end

-- A tap on the unavailable Hop button. Feedback (a pop of the reason and one Warning sound) at most once per
-- EMPTY_THROTTLE; every other tap is only counted. Returns true when the feedback played. Never ends the run.
function StaminaMeter.emptyTap(self: StaminaMeter): boolean
	self._emptyTaps += 1
	if self._dead or not self._shown or self._state ~= "Empty" then
		return false
	end
	local now = os.clock()
	if now - self._lastEmpty < EMPTY_THROTTLE then
		self._emptyThrottled += 1
		return false
	end
	self._lastEmpty = now
	self._emptyWarnings += 1
	self._emptySounds += 1
	Sounds.play("Warning")
	self:_pop(self._word, 1.12) -- nothing in reduced motion: the reason is already steady on screen
	return true
end

-- DEBUG ----------------------------------------------------------------------------------------------------------

function StaminaMeter.getDebugState(self: StaminaMeter): { [string]: any }
	local ctx = self._ctx
	local lit = 0
	for _, p in self._pips do
		if p.lit then
			lit += 1
		end
	end
	local rect = self._rect
	local pipCount, units = StaminaMeter.pipsFor(self._max)
	local tweens = 0
	for _ in self._live do
		tweens += 1
	end

	-- content overlap with the reserved zones, by the layout numbers (design px) and by what is really on screen
	local zonePx, zoneName = 0, nil :: string?
	local trayHit = false
	local contentBox: RunLayout.Rect? = nil
	local widthUsed = 0
	if rect and self._shown then
		local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
		local tray = RunLayout.trayRect(ctx)
		for _, p in self._parts do
			local r = RunLayout.rect(rect.pos.X + p.x, rect.pos.Y + p.y, p.w, p.h, p.name)
			local depth, name = zoneDepth(ctx, r)
			if depth > zonePx then
				zonePx, zoneName = depth, name
			end
			trayHit = trayHit or RunLayout.overlaps(r, tray)
			x0, y0 = math.min(x0, r.pos.X), math.min(y0, r.pos.Y)
			x1, y1 = math.max(x1, r.pos.X + r.size.X), math.max(y1, r.pos.Y + r.size.Y)
		end
		if x1 > x0 then
			contentBox = RunLayout.rect(x0, y0, x1 - x0, y1 - y0, "StaminaContent")
			widthUsed = x1 - x0
		end
	end
	local realPx, realName = 0, nil :: string?
	local realRight = 0 -- right edge of the content, design px on the canvas (from the real AbsolutePosition)
	if self._shown then
		local scale = ctx.screen:uiScale()
		local profile = ctx.screen:profile()
		local zones = profile.zones
		for _, g in
			{
				self._heroHolder :: GuiObject,
				self._number :: GuiObject,
				self._word :: GuiObject,
				self._pipRow :: GuiObject,
			}
		do
			if g.Visible and g.AbsoluteSize.X > 0 then
				local pos, size = ctx.screen:rectOf(g)
				realRight = math.max(realRight, (pos.X + size.X - profile.insets.left) / scale)
				local hit = ctx.screen:overlapsReserved(pos, size)
				if hit then
					for _, z in zones do
						local dx = math.min(pos.X + size.X, z.position.X + z.size.X) - math.max(pos.X, z.position.X)
						local dy = math.min(pos.Y + size.Y, z.position.Y + z.size.Y) - math.max(pos.Y, z.position.Y)
						if dx > 0 and dy > 0 and dy / scale > realPx then
							realPx, realName = dy / scale, z.name
						end
					end
				end
			end
		end
	end
	local instances = #self.root:GetDescendants()
	local boltFrames = if self._hero then (self._hero :: StaminaBolt.Bolt).frames else 0
	return {
		shown = self._shown,
		value = self._value,
		max = self._max,
		state = self._state,
		mode = self._state, -- the Round 2 name for the same thing (Run scenarios read it)
		tint = rgbText(TINTS[self._state]),
		number = self._number.Text,
		word = if self._word.Visible then self._word.Text else "",
		wordText = self._word.Text,
		pips = #self._pips,
		pipsVisible = self._pipRow.Visible,
		pipsLit = lit,
		pipCount = pipCount,
		unitsPerPip = units,
		compact = self._compact,
		rowH = if self._m then self._m.rowH else 0,
		boltH = if self._m then self._m.heroH else 0,
		numberSize = if self._m then self._m.numberSize else 0,
		pipH = if self._m then self._m.pipH else 0,
		drains = self._drains,
		refills = self._refills,
		flights = self._flights,
		flightsLive = self._flightsLive,
		ticks = self._ticks,
		reducedMotion = Motion.reduced(),
		-- motion bookkeeping (leaks and accumulation)
		activeTweens = tweens,
		pulsing = self._pulse ~= nil,
		glowShown = self._halo.Visible,
		glowTransparency = self._halo.BackgroundTransparency,
		instances = instances,
		boltFrames = boltFrames,
		connections = self._connections,
		threads = if self._swapTimer then 1 else 0,
		-- Hop (it reads the same store value)
		hopUnavailable = self._state == "Empty",
		-- throttled empty feedback
		emptyTaps = self._emptyTaps,
		emptyWarnings = self._emptyWarnings,
		emptySounds = self._emptySounds,
		emptyThrottled = self._emptyThrottled,
		-- placement
		box = rect and RunLayout.describe(rect),
		content = contentBox and RunLayout.describe(contentBox),
		contentRect = contentBox and {
			x = contentBox.pos.X,
			y = contentBox.pos.Y,
			w = contentBox.size.X,
			h = contentBox.size.Y,
		},
		contentWidth = widthUsed,
		realRight = realRight,
		zonePx = zonePx, -- design px the content reaches into a reserved zone (layout numbers)
		zoneName = zoneName,
		realZonePx = realPx, -- the same, read from the real AbsolutePosition / AbsoluteSize
		realZoneName = realName,
		overlapsProtected = rect ~= nil and RunLayout.overlaps(rect, RunLayout.protected(ctx)),
		overlapsTray = rect ~= nil and RunLayout.overlaps(rect, RunLayout.trayRect(ctx)),
		contentOverlapsTray = trayHit,
		contentOverlapsProtected = contentBox ~= nil and RunLayout.overlaps(contentBox, RunLayout.protected(ctx)),
	}
end

function StaminaMeter.destroy(self: StaminaMeter)
	self._trove:Destroy()
	self._shown = false
	self._connections = 0
end

return StaminaMeter
