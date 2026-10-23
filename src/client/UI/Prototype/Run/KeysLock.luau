--!strict
-- KEYS LOCK: the signature capture sequence (Lane 3 preview, HUD rebuild worker HR; K-01..K-07).
-- A full redesign of the overnight KeysRing (retired): a bold gold SEGMENTED ring
-- (PreviewTokens.Arcade.Keys.Segments, 8) on a deep dark boundary with a restrained inner
-- shadow, a readable key-in-lock centre (HA's Icons2.keyLock, else a kit-built padlock and key),
-- the percentage secondary under the ring, and one short instruction above it with a thin rarity
-- underline. Gold = capture, teal = Hop; rarity colour is only a supporting accent (the thin
-- inner accent ring and the underline). An already-owned car (authoritative owned == true, or an
-- AlreadyOwned event) shows the SILVER variant, only as part of the Joyride presentation.
--
-- Display only. Progress comes from store.run.keys as supplied; ownership comes ONLY from the
-- explicit KeysConfirmed event for that capture id. 100% is never ownership.
--
-- STATE MACHINE (identity = keys.id / event.captureId; rank only rises; a capture that reached
-- rank 3 is remembered in a bounded "final" table, so duplicates and late events never replay):
--   phase        rank  enters on                                   shows
--   Idle          0    nothing (no ring for irrelevant cars)       nothing
--   Progress      1    KeysStart or keys{id, Holding}              ring + key appear together
--                                                                  (brief scale/fade), HOLD ON;
--                                                                  segments light with progress,
--                                                                  the key turns a step per
--                                                                  segment, a small highlight
--                                                                  runs over each new segment,
--                                                                  glow grows a little, riser
--                                                                  pitch follows progress;
--                                                                  ALMOST! once at AlmostAt
--   Pending       2    keys{Pending} (or keys{Confirmed} before    ring full, key poised,
--                      the event: the store status alone is NOT    SECURING…, slow restrained
--                      a confirmation)                             highlight; no ownership,
--                                                                  no fanfare, no count
--   Confirmed     3    KeysConfirmed{captureId}                    shackle opens (~150 ms), then
--                                                                  hand-off to CaptureRibbon
--   Joyride       3    AlreadyOwned{captureId}                     silver lock opens; the ribbon
--                                                                  says JOYRIDE BONUS
--   Canceled      3    KeysCanceled / keys{Lost|Canceled}          ring gently fractures, short
--                                                                  truthful reason ("You hopped
--                                                                  off"); nothing is lost
--   Unconfirmed   3    Pending with no answer for 8 s (proposal)   fracture + "Not confirmed"
-- Late truth: Canceled/Unconfirmed + a late KeysConfirmed -> recorded Confirmed, NO ring replay
-- (the ribbon presents it). Confirmed never returns to Pending; a late KeysCanceled after
-- Confirmed is ignored and counted in getDebugState().ignored. A new capture id replaces an
-- unfinished one quietly (one Keys at a time).
--
-- Placement (K-01): rider-relative. Camera:WorldToViewportPoint of the supplied rider/car part
-- (options.anchor or setAnchor), mapped into the canvas (RunLayout.worldToCanvas). The ring sits
-- beside the rider at the overnight KeysRing's approved relative location: just right of the
-- protected road-ahead region at the rider's height (left of it if the right is blocked; above
-- it in phone portrait). It never enters the protected region, the top block, Heat or Hop.
-- Stable tracking: a 1.5 px deadband plus a critically damped follow (omega 14), so tiny camera
-- moves never jitter it. Consistent screen size: Keys.RingSize design px clamped to 64..24% of
-- the short canvas side. Kept inside the safe area. Off screen or behind the camera: pinned to
-- the nearest edge with a small arrow toward the rider. No part / despawned: the static
-- fallback (RunLayout.keysRect). The per-frame follow is connected only while the lock shows.
--
-- Reduced motion: stable outline and segments, key-state changes as swaps, short fades, calm
-- confirmation; no spinning, flight, bounce, fracture movement or moving highlight.
--
--   local keys = KeysLock.new(ctx, { anchor = rideModelOrPart? })
--   keys:setAnchor(instance?)
--   keys:layout(), keys:setVisible(on), keys:destroy(), keys:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local K = A.Keys
local make = Arcade.make

-- TOKEN CANDIDATES (proposal values)
local PENDING_TIMEOUT = 8 -- seconds of Pending before "Not confirmed"
local FOLLOW_OMEGA = 14 -- critically damped follow stiffness (1/s)
local DEADBAND = 1.5 -- design px
local SCAN_EVERY = 0.2 -- seconds between fallback placement scans
local PAD = 14 -- room around the ring for the fracture and glow
local INSTR_H = 28
local PERCENT_H = 24
local FINAL_MEMORY = 64

local RANK = table.freeze({
	Idle = 0,
	Progress = 1,
	Pending = 2,
	Confirmed = 3,
	Joyride = 3,
	Canceled = 3,
	Unconfirmed = 3,
})

local KeysLock = {}
KeysLock.__index = KeysLock
KeysLock.Rank = RANK

-- avoid: extra design-px rects the ring keeps clear of (the host knows where the run-time Cash and
-- car count sit; seen in Studio: the ring over them on phone portrait)
export type Options = { anchor: Instance?, avoid: (() -> { RunLayout.Rect })? }

type Capture = {
	id: string,
	car: Store.CarRef?,
	phase: string,
	progress: number,
	lit: number,
	almost: boolean,
	silver: boolean,
	pendingToken: number,
}

type Visual = {
	trove: Trove.Trove,
	size: number,
	group: CanvasGroup,
	pop: UIScale,
	glow: Frame,
	accent: UIStroke,
	segments: { Frame },
	segGrads: { UIGradient },
	shines: { Frame },
	basePos: { UDim2 },
	angles: { number },
	lock: RunKit.KeyLockParts,
	shackleBase: UDim2,
	keyBase: number,
	instr: TextLabel,
	underline: Frame,
	percent: TextLabel,
	arrow: Frame,
	ringCentreY: number,
	width: number,
	height: number,
}

function KeysLock.new(ctx: RunLayout.Ctx, options: Options?)
	local self = setmetatable({}, KeysLock)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._anchor = if options then options.anchor else nil
	self._extraAvoid = if options then options.avoid else nil
	self._scanBest = nil :: Vector2?
	self._scanAt = 0
	self._cap = nil :: Capture?
	self._final = {} :: { [string]: string }
	self._finalOrder = {} :: { string }
	self._log = {} :: { string }
	self._ignored = 0
	self._showing = false
	self._token = 0
	self._follow = nil :: RBXScriptConnection?
	self._pendingLoop = nil :: RBXScriptConnection?
	self._pos = nil :: Vector2?
	self._vel = Vector2.zero
	self._track = "None"
	self._rising = false
	self._ticks = 0
	self._visual = nil :: Visual?

	local root = self._trove:Add(RunLayout.canvas(ctx, "KeysLock"))
	self.root = root

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_applyStore()
	end))
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		self:_onEvent(event)
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Run" then
			self:_hide(true)
			self._cap = nil
			self:_stopRise()
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		local v = self._visual
		if v then
			v.pop.Scale = 1
		end
		self:_applyPendingLoop()
	end))
	self._trove:Add(function()
		self._token += 1
		self:_stopRise()
		self:_stopFollow()
		self:_stopPendingLoop()
		if self._visual then
			self._visual.trove:Destroy()
			self._visual = nil
		end
	end)
	self:layout()
	return self
end

export type KeysLock = typeof(KeysLock.new((nil :: any) :: RunLayout.Ctx))

----------------------------------------------------------------------------------------------
-- Visual

local function ringSize(ctx: RunLayout.Ctx): number
	local d = RunLayout.design(ctx)
	-- phone landscape is short: a smaller cap keeps the ring between the ride chip and Hop
	local cap = if ctx.screen:profile().name == "PhoneLandscape" then 0.19 else 0.24
	return math.floor(math.clamp(K.RingSize, 64, math.max(64, math.min(d.X, d.Y) * cap)))
end

function KeysLock._build(self: KeysLock, R: number)
	if self._visual then
		self._visual.trove:Destroy()
	end
	local trove = Trove.new()
	local N = K.Segments
	local area = R + 2 * PAD
	local width = math.max(area, 170)
	local height = INSTR_H + 2 + area + PERCENT_H
	local group = trove:Add(make("CanvasGroup", {
		Name = "Keys",
		AnchorPoint = Vector2.new(0.5, (INSTR_H + 2 + area / 2) / height),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = self.root,
	}))
	RunKit.nonInteractive(group)
	local inner = make("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = group,
	})
	local pop = make("UIScale", { Name = "Pop", Parent = inner })
	-- instruction + rarity underline
	local instr = Arcade.text(inner, { text = "HOLD ON", role = "Label", name = "Instruction", size = 20, z = 20 })
	instr.Position = UDim2.fromOffset(0, 0)
	instr.Size = UDim2.new(1, 0, 0, INSTR_H - 4)
	local underline = make("Frame", {
		Name = "Underline",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, INSTR_H - 4),
		Size = UDim2.fromOffset(64, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 20,
		Parent = inner,
	})
	Arcade.corner(underline, 2)
	Arcade.outline(underline, 1.25)
	-- ring area
	local ring = make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, INSTR_H + 2),
		Size = UDim2.fromOffset(area, area),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = inner,
	})
	local glow = RunKit.disc(ring, "Glow", R + 14, A.Fill.Gold.Keypoints[2].Value, 5)
	glow.BackgroundTransparency = 0.9
	local boundary = RunKit.disc(ring, "Boundary", R, A.Ink, 6)
	boundary.BackgroundTransparency = 0.04
	Arcade.outline(boundary, "Major", Color3.fromRGB(4, 8, 18))
	-- segments on a circle, each a short bar tangent to it
	local thick = math.max(10, math.floor(R * 0.15))
	local rs = R / 2 - 4 - thick / 2
	local circ = 2 * math.pi * rs
	local segLen = circ / N - math.max(4, R * 0.055)
	local segments, grads, shines, basePos, angles = {}, {}, {}, {}, {}
	for i = 1, N do
		local theta = (i - 0.5) / N * math.pi * 2
		local pos = UDim2.fromOffset(area / 2 + rs * math.sin(theta), area / 2 - rs * math.cos(theta))
		local seg = make("Frame", {
			Name = "Seg" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(segLen, thick),
			Rotation = math.deg(theta),
			BackgroundColor3 = RunKit.Slot,
			ClipsDescendants = true,
			ZIndex = 8,
			Parent = ring,
		})
		Arcade.corner(seg, 3)
		Arcade.outline(seg, "Minor")
		local grad = make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Enabled = false, Parent = seg })
		local shine = make("Frame", {
			Name = "Shine",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = seg,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 0.2),
				NumberSequenceKeypoint.new(0.55, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = shine,
		})
		segments[i], grads[i], shines[i], basePos[i], angles[i] = seg, grad, shine, pos, theta
	end
	-- thin rarity accent ring between the segments and the plate
	local plateSize = math.floor(R * 0.56)
	local accentHolder = RunKit.disc(ring, "Accent", plateSize + 8, Color3.new(), 9)
	accentHolder.BackgroundTransparency = 1
	local accent = make("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = accentHolder })
	-- restrained inner shadow under the plate, then the plate and the key-in-lock
	local shadow = RunKit.disc(ring, "PlateShadow", plateSize + 2, A.Ink, 10)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 2)
	shadow.BackgroundTransparency = 0.35
	local plate = RunKit.disc(ring, "Plate", plateSize, RunKit.Plate, 11)
	Arcade.outline(plate, "Major")
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 220, 204)),
		Parent = plate,
	})
	local lockHolder = make("Frame", {
		Name = "KeyLock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.floor(plateSize * 0.8), math.floor(plateSize * 0.8)),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = plate,
	})
	local lock = RunKit.keyLock(lockHolder)
	-- percentage (secondary)
	local percent = Arcade.text(inner, {
		text = "0%",
		role = "Label",
		name = "Percent",
		size = 20,
		italic = true,
		face = "Keys",
		z = 20,
	})
	percent.AnchorPoint = Vector2.new(0.5, 1)
	percent.Position = UDim2.fromScale(0.5, 1)
	percent.Size = UDim2.new(1, 0, 0, PERCENT_H)
	-- off-screen arrow (a small rotated square on the ring edge, pointing toward the rider)
	local arrow = make("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(area, area),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 7,
		Parent = ring,
	})
	local tip = make("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(14, 14),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 7,
		Parent = arrow,
	})
	Arcade.outline(tip, "Major")
	self._visual = {
		trove = trove,
		size = R,
		group = group,
		pop = pop,
		glow = glow,
		accent = accent,
		segments = segments,
		segGrads = grads,
		shines = shines,
		basePos = basePos,
		angles = angles,
		lock = lock,
		shackleBase = lock.shackle.Position,
		keyBase = lock.key.Rotation,
		instr = instr,
		underline = underline,
		percent = percent,
		arrow = arrow,
		ringCentreY = INSTR_H + 2 + area / 2,
		width = width,
		height = height,
	}
	trove:Add(function()
		Motion.cancelAll(group)
		Motion.cancelAll(pop)
	end)
end

-- Puts the visual in the state of the current capture (used after a rebuild and on start).
function KeysLock._paint(self: KeysLock)
	local v = self._visual
	local cap = self._cap
	if not v or not cap then
		return
	end
	local c = cap :: Capture
	local r = RunKit.rarity(c.car)
	v.accent.Color = r.light
	v.underline.BackgroundColor3 = r.light
	for i, seg in v.segments do
		Motion.cancelAll(seg)
		seg.Position = v.basePos[i]
		seg.Rotation = math.deg(v.angles[i])
		seg.BackgroundTransparency = 0
		local on = i <= c.lit
		v.segGrads[i].Enabled = on
		v.segGrads[i].Color = if c.silver then RunKit.SilverFill else A.Fill.Gold
		seg.BackgroundColor3 = if on then Color3.new(1, 1, 1) else RunKit.Slot
		v.shines[i].BackgroundTransparency = 1
	end
	v.glow.BackgroundColor3 = if c.silver then RunKit.SilverFill.Keypoints[2].Value else A.Fill.Gold.Keypoints[2].Value
	v.glow.BackgroundTransparency = 0.9 - 0.22 * c.progress
	v.lock.shackle.Position = v.shackleBase
	v.lock.key.Rotation = v.keyBase + 90 * (c.lit / K.Segments)
	v.percent.Text = string.format("%d%%", math.floor(c.progress * 100 + 1e-6))
	v.percent.Visible = true
	v.instr.Text = if c.phase == "Pending" then "SECURING…" elseif c.almost then "ALMOST!" else "HOLD ON"
	v.underline.Visible = true
end

----------------------------------------------------------------------------------------------
-- State machine

function KeysLock._logLine(self: KeysLock, text: string)
	table.insert(self._log, text)
	if #self._log > 16 then
		table.remove(self._log, 1)
	end
end

function KeysLock._setFinal(self: KeysLock, id: string, phase: string)
	if self._final[id] == nil then
		table.insert(self._finalOrder, id)
		if #self._finalOrder > FINAL_MEMORY then
			self._final[table.remove(self._finalOrder, 1) :: string] = nil
		end
	end
	self._final[id] = phase
end

function KeysLock._stopRise(self: KeysLock)
	if self._rising then
		self._rising = false
	end
	Sounds.stopRise("KeysRise")
end

function KeysLock._start(self: KeysLock, id: string, car: Store.CarRef?)
	local old = self._cap
	if old and RANK[old.phase] < 3 then
		-- one Keys at a time: an unfinished capture is replaced quietly
		self:_logLine(old.id .. ": replaced by " .. id)
	end
	self:_stopRise()
	self._cap = {
		id = id,
		car = car,
		phase = "Progress",
		progress = 0,
		lit = 0,
		almost = false,
		silver = car ~= nil and car.owned == true,
		pendingToken = 0,
	}
	self:_logLine(id .. ": Idle -> Progress")
	self:_show()
end

function KeysLock._progress(self: KeysLock, p: number)
	local cap = self._cap
	if not cap or cap.phase ~= "Progress" then
		return
	end
	local c = cap :: Capture
	local progress = math.max(c.progress, math.clamp(if p ~= p then 0 else p, 0, 1))
	c.progress = progress
	local N = K.Segments
	local lit = math.floor(progress * N + 1e-6)
	local v = self._visual
	local reduced = Motion.reduced()
	if v then
		v.percent.Text = string.format("%d%%", math.floor(progress * 100 + 1e-6))
		v.glow.BackgroundTransparency = 0.9 - 0.22 * progress
		for i = c.lit + 1, lit do
			local seg = v.segments[i]
			v.segGrads[i].Enabled = true
			seg.BackgroundColor3 = Color3.new(1, 1, 1)
			if not reduced then
				-- a small highlight runs over the new segment
				local shine = v.shines[i]
				local g = shine:FindFirstChildOfClass("UIGradient") :: UIGradient
				shine.BackgroundTransparency = 0
				g.Offset = Vector2.new(-1, 0)
				Motion.tween(g, "shine", Motion.info(0.3), { Offset = Vector2.new(1, 0) })
				Motion.tween(shine, "shine", Motion.info(0.3), { BackgroundTransparency = 1 })
			end
		end
		if lit > c.lit then
			local rot = v.keyBase + 90 * (lit / N)
			if reduced then
				v.lock.key.Rotation = rot
			else
				Motion.tween(v.lock.key, "turn", Motion.info(0.12), { Rotation = rot })
			end
		end
	end
	if lit > c.lit then
		self._ticks += lit - c.lit
	end
	c.lit = lit
	if progress > 0 then
		self._rising = true
		Sounds.rise("KeysRise", progress)
	end
	if not c.almost and progress >= K.AlmostAt then
		c.almost = true -- exactly once per capture
		if v then
			v.instr.Text = "ALMOST!"
			if not reduced then
				Motion.pop(v.instr, 1.12)
			end
		end
		self:_logLine(c.id .. ": ALMOST!")
	end
end

function KeysLock._pending(self: KeysLock)
	local cap = self._cap
	if not cap or RANK[cap.phase] >= RANK.Pending then
		return
	end
	local c = cap :: Capture
	c.phase = "Pending"
	c.progress = 1
	c.lit = K.Segments
	self:_stopRise()
	self:_logLine(c.id .. ": Progress -> Pending")
	self:_paint()
	c.pendingToken += 1
	local token = c.pendingToken
	task.delay(PENDING_TIMEOUT, function()
		if self._cap == c and c.phase == "Pending" and c.pendingToken == token then
			self:_end("Unconfirmed", "NotConfirmed")
		end
	end)
	self:_applyPendingLoop()
end

-- Terminal phases. `reason` is a code or a supplied sentence (RunKit.keysReason).
function KeysLock._end(self: KeysLock, phase: string, reason: string?)
	local cap = self._cap
	if not cap then
		return
	end
	local c = cap :: Capture
	if RANK[c.phase] >= 3 then
		return
	end
	local from = c.phase
	c.phase = phase
	self:_setFinal(c.id, phase)
	self:_stopRise()
	self:_stopPendingLoop()
	self:_logLine(c.id .. ": " .. from .. " -> " .. phase)
	local v = self._visual
	if not v or not self._showing then
		return
	end
	self._token += 1
	local token = self._token
	local reduced = Motion.reduced()
	if phase == "Confirmed" or phase == "Joyride" then
		if phase == "Joyride" then
			c.silver = true
		end
		c.progress, c.lit = 1, K.Segments
		self:_paint()
		v.instr.Text = ""
		v.underline.Visible = false
		v.percent.Visible = false
		local up = v.shackleBase + UDim2.fromScale(0, -0.2)
		if reduced then
			v.lock.shackle.Position = up
		else
			Motion.tween(v.lock.shackle, "open", Motion.info(K.ReleaseSeconds, Enum.EasingStyle.Back), {
				Position = up,
			})
		end
		task.delay(if reduced then 0.35 else 0.55, function()
			if token == self._token then
				self:_hide(false)
			end
		end)
		return
	end
	-- Canceled / Unconfirmed: a gentle fracture with a short truthful reason
	local text = RunKit.keysReason(reason)
	v.instr.Text = text or ""
	v.underline.Visible = false
	v.percent.Visible = false
	if not reduced then
		for i, seg in v.segments do
			local theta = v.angles[i]
			local out = Vector2.new(math.sin(theta), -math.cos(theta)) * 12
			local base = v.basePos[i]
			Motion.tween(seg, "fracture", Motion.info(0.45), {
				Position = base + UDim2.fromOffset(out.X, out.Y),
				Rotation = math.deg(theta) + (if i % 2 == 0 then 10 else -10),
				BackgroundTransparency = 0.6,
			})
		end
	end
	task.delay(if text then 1.2 else 0.5, function()
		if token == self._token then
			self:_hide(false)
		end
	end)
end

function KeysLock._idFromKeys(keys: Store.KeysState): string
	return keys.id or ("target:" .. keys.target.id)
end

function KeysLock._applyStore(self: KeysLock)
	local state = self._ctx.store:get()
	if state.mode ~= "Run" then
		return
	end
	local run = state.run
	local keys = run and run.keys
	if not keys then
		local cap = self._cap
		if cap and cap.phase == "Progress" then
			-- the meter went away without a reason: end quietly (no invented reason)
			self:_end("Canceled", nil)
		end
		-- Pending stays visible until the confirmation, a cancel or the timeout
		return
	end
	local k = keys :: Store.KeysState
	local id = KeysLock._idFromKeys(k)
	if self._final[id] then
		return -- this capture already finished: late or duplicate state is ignored
	end
	local cap = self._cap
	if not cap or cap.id ~= id then
		self:_start(id, k.target)
		cap = self._cap
	end
	local c = cap :: Capture
	if c.car == nil then
		c.car = k.target
	end
	if k.status == "Holding" then
		self:_progress(k.progress)
	elseif k.status == "Pending" or k.status == "Confirmed" then
		self:_progress(k.progress)
		self:_pending()
	elseif k.status == "Lost" or k.status == "Canceled" then
		self:_end("Canceled", k.reason)
	end
end

function KeysLock._onEvent(self: KeysLock, event: Store.Event)
	local kind = event.kind
	if kind == "RunEnded" then
		-- the run is over: get out of the way of OVERHEATED / Results; a late confirmation is
		-- still honoured (the ribbon records it for Results)
		self:_stopRise()
		self:_hide(false)
		return
	end
	if kind ~= "KeysStart" and kind ~= "KeysConfirmed" and kind ~= "KeysCanceled" and kind ~= "AlreadyOwned" then
		return
	end
	local id = event.captureId
	if not id then
		local cap = self._cap
		id = if cap then cap.id else nil
	end
	if not id then
		return
	end
	local capId = id :: string
	local cap = self._cap
	local current = cap ~= nil and cap.id == capId and RANK[cap.phase] < 3
	if kind == "KeysStart" then
		if not self._final[capId] and not (cap and cap.id == capId) and self._ctx.store:get().mode == "Run" then
			self:_start(capId, event.car)
		end
	elseif kind == "KeysConfirmed" then
		if current then
			self:_end("Confirmed", nil)
		elseif self._final[capId] ~= "Confirmed" and self._final[capId] ~= "Joyride" then
			-- late truth (after Canceled / Unconfirmed / unseen): recorded, ribbon only, no replay
			self:_setFinal(capId, "Confirmed")
			self:_logLine(capId .. ": late Confirmed (ribbon only)")
		else
			self._ignored += 1
		end
	elseif kind == "KeysCanceled" then
		if current then
			self:_end("Canceled", event.reason)
		elseif self._final[capId] == nil then
			self:_setFinal(capId, "Canceled")
		else
			self._ignored += 1 -- e.g. a late cancel after Confirmed: never reverses it
		end
	elseif kind == "AlreadyOwned" then
		if current then
			self:_end("Joyride", nil)
		elseif self._final[capId] == nil then
			self:_setFinal(capId, "Joyride")
		else
			self._ignored += 1
		end
	end
end

----------------------------------------------------------------------------------------------
-- Show / hide and tracking

function KeysLock._show(self: KeysLock)
	local v = self._visual
	if not v then
		return
	end
	self._token += 1
	self:_paint()
	local group = v.group
	local reduced = Motion.reduced()
	if not self._showing then
		self._showing = true
		self._pos = nil
		group.Visible = self._visible
		group.GroupTransparency = 1
		Motion.tween(group, "fade", Motion.info(if reduced then 0.12 else 0.15), { GroupTransparency = 0 })
		if not reduced then
			v.pop.Scale = 0.82
			Motion.tween(v.pop, "start", Motion.info(0.2, Enum.EasingStyle.Back), { Scale = 1 })
		else
			v.pop.Scale = 1
		end
		self:_startFollow()
	end
end

function KeysLock._hide(self: KeysLock, immediate: boolean)
	self:_stopPendingLoop()
	local v = self._visual
	if not self._showing or not v then
		self._showing = false
		self:_stopFollow()
		return
	end
	self._showing = false
	self._token += 1
	local token = self._token
	local group = v.group
	if immediate then
		Motion.cancelAll(group)
		group.GroupTransparency = 1
		group.Visible = false
		self:_stopFollow()
		return
	end
	local t = Motion.tween(group, "fade", Motion.info(if Motion.reduced() then 0.15 else 0.25), {
		GroupTransparency = 1,
	})
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and token == self._token then
			group.Visible = false
			self:_stopFollow()
		end
	end)
end

function KeysLock._stopFollow(self: KeysLock)
	if self._follow then
		self._follow:Disconnect()
		self._follow = nil
	end
end

function KeysLock._startFollow(self: KeysLock)
	if self._follow then
		return
	end
	self:_place(0)
	self._follow = RunService.Heartbeat:Connect(function(dt)
		self:_place(dt)
	end)
end

function KeysLock._stopPendingLoop(self: KeysLock)
	if self._pendingLoop then
		self._pendingLoop:Disconnect()
		self._pendingLoop = nil
	end
	local v = self._visual
	if v then
		for _, s in v.shines do
			if not Motion.reduced() then
				s.BackgroundTransparency = 1
			end
		end
	end
end

-- Pending: one slow highlight lap per 1.6 s over the full ring (none in reduced motion).
function KeysLock._applyPendingLoop(self: KeysLock)
	if self._pendingLoop then
		self._pendingLoop:Disconnect()
		self._pendingLoop = nil
	end
	local cap = self._cap
	local v = self._visual
	if not cap or cap.phase ~= "Pending" or not v or not self._showing then
		return
	end
	for _, s in v.shines do
		s.BackgroundTransparency = 1
	end
	if Motion.reduced() then
		return
	end
	local t = 0
	local last = 0
	self._pendingLoop = RunService.Heartbeat:Connect(function(dt)
		t += dt
		local idx = math.floor(t / 0.2) % K.Segments + 1
		if idx ~= last then
			if last > 0 then
				v.shines[last].BackgroundTransparency = 1
			end
			last = idx
			local s = v.shines[idx]
			local g = s:FindFirstChildOfClass("UIGradient") :: UIGradient
			g.Offset = Vector2.zero
			s.BackgroundTransparency = 0.55
		end
	end)
end

local function anchorPosition(anchor: Instance?): Vector3?
	if not anchor or not anchor.Parent then
		return nil
	end
	if anchor:IsA("BasePart") then
		return anchor.Position + Vector3.new(0, anchor.Size.Y / 2 + 1, 0)
	elseif anchor:IsA("Model") then
		local cf, size = anchor:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2 + 1, 0)
	elseif anchor:IsA("Attachment") then
		return anchor.WorldPosition
	end
	return nil
end

-- The widget box around a ring centre, in design px.
function KeysLock._box(self: KeysLock, centre: Vector2): RunLayout.Rect
	local v = self._visual :: Visual
	return RunLayout.rect(centre.X - v.width / 2, centre.Y - v.ringCentreY, v.width, v.height, "Keys")
end

function KeysLock._target(self: KeysLock): (Vector2, string, Vector2?)
	local ctx = self._ctx
	local v = self._visual :: Visual
	local d = RunLayout.design(ctx)
	local prot = RunLayout.protected(ctx)
	local m = RunLayout.Margin
	local halfW = v.width / 2
	local up = v.ringCentreY
	local down = v.height - v.ringCentreY
	-- the top row piece by piece (strip, coins, Settings) rather than the full-width top band, so
	-- the ring can use the right column under Settings on short screens
	local avoid = {
		prot,
		RunLayout.stripRect(ctx),
		RunLayout.coinsRect(ctx),
		RunLayout.gearRect(ctx),
		(RunLayout.heatRect(ctx)),
		(RunLayout.hopRect(ctx)),
	}
	if ctx.screen:profile().name ~= "PhoneLandscape" then
		table.insert(avoid, RunLayout.chipRect(ctx)) -- the chip only steps aside on phone landscape
	end
	local extra = self._extraAvoid
	if extra then
		for _, r in extra() do
			table.insert(avoid, r)
		end
	end
	-- never inside a reserved touch zone (seen in the thumbstick zone on phone landscape in Studio)
	for _, z in RunLayout.zones(ctx) do
		table.insert(avoid, z)
	end
	local function clampInside(c: Vector2): Vector2
		return Vector2.new(math.clamp(c.X, halfW + 4, d.X - halfW - 4), math.clamp(c.Y, up + 4, d.Y - down - 4))
	end
	local function clear(c: Vector2): boolean
		local box = self:_box(c)
		if not RunLayout.inside(box, d) then
			return false
		end
		for _, a in avoid do
			if RunLayout.overlaps(box, a) then
				return false
			end
		end
		return true
	end
	local world = anchorPosition(self._anchor)
	if not world then
		local rect = RunLayout.keysRect(ctx)
		return clampInside(rect.pos + rect.size / 2), "Fallback", nil
	end
	local p, on, depth = RunLayout.worldToCanvas(ctx, world :: Vector3)
	if not on then
		-- pinned to the nearest edge, with an arrow toward the rider
		local dir = if depth <= 0 then -(p - d / 2) else (p - d / 2)
		local pinned = clampInside(d / 2 + dir)
		return pinned, "Edge", dir
	end
	local y = math.clamp(p.Y, up + 4, d.Y - down - 4)
	local candidates = {
		Vector2.new(prot.pos.X + prot.size.X + m + halfW, y),
		Vector2.new(prot.pos.X - m - halfW, y),
		Vector2.new(p.X, prot.pos.Y - m - down),
		Vector2.new(prot.pos.X + prot.size.X + m + halfW, prot.pos.Y + prot.size.Y * 0.3),
	}
	-- short screens: the gap between the ride chip and Hop, right of the road
	do
		-- phone landscape: the ride chip hides during a capture, so the gap starts under the gear
		local chip = if ctx.screen:profile().name == "PhoneLandscape"
			then RunLayout.gearRect(ctx)
			else RunLayout.chipRect(ctx)
		local hop = RunLayout.hopRect(ctx)
		local gapTop = chip.pos.Y + chip.size.Y + 4
		local gapBottom = hop.pos.Y - 4
		local cy = gapTop + up + math.max(0, (gapBottom - gapTop - up - down) / 2)
		table.insert(candidates, Vector2.new(prot.pos.X + prot.size.X + m + halfW, cy))
		table.insert(candidates, Vector2.new(d.X - 8 - halfW, cy))
	end
	-- prefer the side the rider is on when it has drifted right of centre
	if p.X > d.X * 0.62 then
		candidates[1], candidates[2] = candidates[2], candidates[1]
	end
	for _, c in candidates do
		local cc = clampInside(c)
		if clear(cc) then
			return cc, "Rider", nil
		end
	end
	-- no preferred spot is clear (seen on phone landscape: the ring sat under Hop): scan the screen
	-- for the clear spot nearest the rider, else the spot with the least overlap
	local function overlapArea(c: Vector2): number
		local box = self:_box(c)
		local total = 0
		for _, a in avoid do
			local w = math.min(box.pos.X + box.size.X, a.pos.X + a.size.X) - math.max(box.pos.X, a.pos.X)
			local h = math.min(box.pos.Y + box.size.Y, a.pos.Y + a.size.Y) - math.max(box.pos.Y, a.pos.Y)
			if w > 0 and h > 0 then
				total += w * h
			end
		end
		return total
	end
	-- the scan is a few thousand boxes: at most SCAN_EVERY seconds apart (phone portrait hits it
	-- every frame), reusing the last result in between
	local now = os.clock()
	if self._scanBest and now - self._scanAt < SCAN_EVERY then
		return self._scanBest :: Vector2, "Rider", nil
	end
	local best, bestScore = clampInside(candidates[1]), math.huge
	for sy = up + 4, d.Y - down - 4, 8 do
		for sx = halfW + 4, d.X - halfW - 4, 8 do
			local c = Vector2.new(sx, sy)
			local score = overlapArea(c) * 1000 + (c - p).Magnitude
			if score < bestScore then
				best, bestScore = c, score
			end
		end
	end
	self._scanBest, self._scanAt = best, now
	return best, "Rider", nil
end

function KeysLock._place(self: KeysLock, dt: number)
	local v = self._visual
	if not v then
		return
	end
	local target, mode, arrowDir = self:_target()
	self._track = mode
	local pos = self._pos
	if pos == nil or dt <= 0 then
		pos = target
		self._vel = Vector2.zero
	else
		local current = pos :: Vector2
		local delta = target - current
		if delta.Magnitude > DEADBAND or self._vel.Magnitude > 0.5 then
			local step = math.min(dt, 1 / 30)
			local w = FOLLOW_OMEGA
			local acc = delta * (w * w) - self._vel * (2 * w)
			self._vel += acc * step
			pos = current + self._vel * step
		else
			self._vel = Vector2.zero
			pos = current
		end
	end
	self._pos = pos
	local p = pos :: Vector2
	v.group.Position = UDim2.fromOffset(math.floor(p.X + 0.5), math.floor(p.Y + 0.5))
	v.arrow.Visible = arrowDir ~= nil
	if arrowDir then
		local a = arrowDir :: Vector2
		v.arrow.Rotation = math.deg(math.atan2(a.X, -a.Y))
	end
end

----------------------------------------------------------------------------------------------
-- Component API

function KeysLock.setAnchor(self: KeysLock, anchor: Instance?)
	self._anchor = anchor
	self._pos = nil
end

function KeysLock.layout(self: KeysLock)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local R = ringSize(ctx)
	if not self._visual or self._visual.size ~= R then
		local wasShowing = self._showing
		self._showing = false
		self:_stopFollow()
		self:_build(R)
		if wasShowing and self._cap then
			self:_show()
			self:_applyPendingLoop()
		end
	end
	self._pos = nil
	if self._showing then
		self:_place(0)
	end
end

function KeysLock.setVisible(self: KeysLock, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:_stopRise()
	end
end

function KeysLock.getDebugState(self: KeysLock): { [string]: any }
	local cap = self._cap
	local v = self._visual
	local finals = 0
	for _ in self._final do
		finals += 1
	end
	local box = if v and self._pos then self:_box(self._pos :: Vector2) else nil
	return {
		visible = self._visible,
		showing = self._showing,
		id = cap and cap.id,
		phase = if cap then cap.phase else "Idle",
		rank = if cap then RANK[cap.phase] else 0,
		progress = cap and cap.progress,
		lit = cap and cap.lit,
		segments = K.Segments,
		almostShown = cap and cap.almost,
		silver = cap and cap.silver,
		instruction = v and v.instr.Text,
		percent = v and v.percent.Visible and v.percent.Text or nil,
		ringSize = v and v.size,
		tracking = self._track,
		following = self._follow ~= nil,
		pendingLoop = self._pendingLoop ~= nil,
		rising = self._rising,
		ticks = self._ticks,
		finals = finals,
		ignored = self._ignored,
		log = table.clone(self._log),
		box = box and RunLayout.describe(box),
		overlapsProtected = box ~= nil and RunLayout.overlaps(box, RunLayout.protected(self._ctx)),
		keyLockFallback = v and v.lock.fallback,
	}
end

function KeysLock.destroy(self: KeysLock)
	self._trove:Destroy()
end

return KeysLock
