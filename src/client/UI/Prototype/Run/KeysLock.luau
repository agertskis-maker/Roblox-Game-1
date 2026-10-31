--!strict
-- KEYS LOCK: the signature capture sequence (Lane 3 preview, HUD rebuild worker HR; K-01..K-07; Round 3 R3-K1, R3-K2).
-- ROUND 3: ONE continuous yellow progress ring replaces the eight segmented boxes. The ring is our own design: a
-- bold gold ring on a readable slate track, inside a deep dark boundary with a restrained inner shadow. The centre
-- is unchanged: the original key-in-lock icon (HA's Icons2.keyLock, else a kit-built padlock and key), the
-- percentage secondary under the ring, and one short instruction ABOVE it ("HOLD ON", "ALMOST!", "SECURING…") with a
-- thin rarity underline. Gold = capture, teal = Hop; rarity colour is only a supporting accent (the thin inner
-- accent ring and the underline). An already-owned car (authoritative owned == true, or an AlreadyOwned event)
-- shows the SILVER variant, only as part of the Joyride presentation.
--
-- RING ORIGIN AND DIRECTION (one, everywhere): the fill starts at 12 o'clock (straight up) and grows CLOCKWISE through
-- the full circumference to 360 degrees. fill 0.25 = 3 o'clock, 0.5 = 6 o'clock, 0.75 = 9 o'clock, 1 = closed.
-- RING TECHNIQUE (no uploaded image): the classic two-half method. A transparent circle Frame (UICorner) with a
-- UIStroke draws the ring, so both edges are anti-aliased. Two copies sit inside two ClipsDescendants frames that
-- split the ring on the vertical centre line (the right half is 12 -> 6 o'clock, the left half 6 -> 12; the left
-- clip reaches 1 design px past the line, so rounding can never open a hairline at 6 o'clock). Each copy
-- carries ONE UIGradient on its stroke with a hard transparency stop at 0.5 (about 1.5 px soft, for an
-- anti-aliased cut), so its visible area is a half-plane through the ring centre; UIGradient.Rotation turns that
-- half-plane about the centre. With degrees = fill x 360 measured clockwise from 12 o'clock: right half Rotation =
-- clamp(degrees, 0, 180); left half Rotation = clamp(degrees, 180, 360). A half is hidden while empty and the right
-- gradient is off once the right half is complete, so there is no sliver at 0 or 180 degrees. A third copy (the
-- CLOSED ring: no gradient, no clip) replaces both halves at exactly 100%, so nothing seams or flashes at 360.
-- Cost: 18 instances for the whole ring (track, two halves, closed ring); one Heartbeat connection only while the
-- shown value differs from the supplied one; while it runs, three property writes a frame (two UIGradient.Rotation
-- and the key's Rotation). Visible and Enabled are written only when they change.
--
-- FOLLOWING THE REAL PROGRESS: the shown fill follows the supplied keys.progress (the real claim-time source; this
-- module has no duration of its own) with a straight ease of FILL_SECONDS (0.07 s) from the value shown when the
-- new progress arrived. It never passes the supplied value (progress only rises and the ease ends exactly on it),
-- is never early, and lags by at most FILL_SECONDS plus a frame. The connection stops as soon as the shown value
-- equals the supplied one. Reduced motion shows each supplied value at once.
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
--                                                                  the ring fills with progress,
--                                                                  the key turns with it, glow
--                                                                  grows a little, the chime ladder (Sounds.rise,
--                                                                  at most four discrete notes) follows progress;
--                                                                  ALMOST! once at AlmostAt
--   Pending       2    keys{Pending} (or keys{Confirmed} before    ring full and steady, key poised,
--                      the event: the store status alone is NOT    SECURING…; no ownership, no
--                      a confirmation)                             fanfare, no count
--   Confirmed     3    KeysConfirmed{captureId}                    shackle opens (~150 ms), then
--                                                                  hand-off to CaptureRibbon
--   Joyride       3    AlreadyOwned{captureId}                     silver lock opens; the ribbon
--                                                                  says JOYRIDE BONUS
--   Canceled      3    KeysCanceled / keys{Lost|Canceled}          the ring dims and settles, short
--                                                                  truthful reason ("You hopped
--                                                                  off"); nothing is lost
--   Unconfirmed   3    Pending with no answer for 8 s (proposal)   the same dim + "Not confirmed"
-- COMPLETION (R3-K2): the first time the shown fill reaches 100% the closed ring gets ONE bounded pulse (a 1.07 scale
-- pop of about 0.18 s) and settles as a steady, brighter, 2 px thicker ring. Reduced motion skips the pulse and shows
-- the steady emphasis at once. A full ring that arrives before the confirmation just holds (SECURING…): this module
-- never shows SECURED and never touches the tray; only the explicit confirmation hands off to the ribbon.
-- Late truth: Canceled/Unconfirmed + a late KeysConfirmed -> recorded Confirmed, NO ring replay
-- (the ribbon presents it). Confirmed never returns to Pending; a late KeysCanceled after
-- Confirmed is ignored and counted in getDebugState().ignored. A new capture id replaces an
-- unfinished one quietly (one Keys at a time).
--
-- Placement (K-01): rider-relative. Camera:WorldToViewportPoint of the supplied rider/car part
-- (options.anchor or setAnchor), mapped into the canvas (RunLayout.worldToCanvas). The ring sits
-- beside the rider at the overnight KeysRing's approved relative location: just right of the
-- protected road-ahead region at the rider's height (left of it if the right is blocked; above
-- it on a narrow phone). It never enters the protected region, the top block, Heat or Hop.
-- Stable tracking: a 1.5 px deadband plus a critically damped follow (omega 14), so tiny camera
-- moves never jitter it. Consistent screen size: Keys.RingSize design px clamped to 64..24% of
-- the short canvas side. Kept inside the safe area. Off screen or behind the camera: pinned to
-- the nearest edge with a small arrow toward the rider. No part / despawned: the static
-- fallback (RunLayout.keysRect). The per-frame follow is connected only while the lock shows.
-- (Round 3 changed none of this: the widget box, the ring diameter and every placement rule are the Round 2 ones.)
--
-- ROUND 2 ESCALATION (R2-K1), three tiers by supplied progress:
--   0-50%    HOLD ON: stable ring, restrained outline and glow;
--   50-75%   brighter glow, the chime ladder keeps climbing in discrete notes (Round 3: KeysTick is silent and there is no continuous riser);
--   75-100%  a larger ALMOST! (it appears deliberately ONCE, pops once and settles at its bigger size), a bounded
--            rhythmic pulse of the glow and the transparent rarity edges at ONE cycle per second (capped, never
--            faster, never a strobe; with the Heat alarm at most 1.25 a second the two stay under 2.5 peaks a
--            second), sparse sparks (at most 3 a second from a pool of 8) and a thicker rarity accent ring. The
--            world side (a rarity outline and sparkles on the ridden car) is World/CaptureFx.
-- Critical Heat and input warnings outrank all of this: while a warning or the run end is flagged
-- (RunBus.flags) the pulse, edges and sparks are held still.
-- COUNTDOWN (R2-K1): shown ONLY when the store supplies keys.remainingSeconds with keys.timingTrusted == true.
-- It is never derived from progress or from animation time; otherwise the percentage and ALMOST! say it.
-- SHUDDER: DEFERRED. A car shudder cannot be separated from the authoritative ridden vehicle in this preview
-- (its body is the model the player drives), so no vehicle, seat, character root or camera is ever moved here;
-- the capture outline and sparkles on the car (World/CaptureFx) carry the tension instead. Debug: bodyMotion.
--
-- Reduced motion: stable outline and ring (each supplied value shown at once), key-state changes as swaps, short
-- fades, calm confirmation; no spinning, flight, bounce, pulse, sparks, edges or settling movement; ALMOST! stays as
-- steady bigger text; completion is a steady brighter, thicker ring.
--
--   local keys = KeysLock.new(ctx, { anchor = rideModelOrPart? })
--   keys:setAnchor(instance?)
--   keys:layout(), keys:setVisible(on), keys:destroy(), keys:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local Music = require(script.Parent.Parent.Music)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
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
local TIER2_AT = 0.5 -- brighter, clicks
local PULSE_HZ = 1.0 -- the one pulse rate (capped): at most one peak a second
local SPARK_EVERY = 0.34 -- at most 3 sparks a second
local SPARKS = 8
local EDGE_WIDTH = 96 -- design px of the transparent rarity edge on each side
-- Round 3 ring (TOKEN CANDIDATES)
local FILL_SECONDS = 0.07 -- the shown fill reaches each supplied progress this fast (never early, never lagging past ~100 ms)
local TICK_STEPS = 8 -- progress clicks come at every eighth of the progress; the ring itself is continuous
local COMPLETE_EXTRA = 2 -- design px the closed ring grows outward at completion (steady emphasis)
local COMPLETE_POP = 1.07 -- the one bounded pulse at completion (skipped in reduced motion)
local KEY_TURN = 90 -- degrees the key turns between empty and full
local EDGE_SOFT_PX = 1.5 -- design px of anti-aliasing on the cut edge of the wedge
local SEAM_OVERLAP = 1 -- design px the left clip reaches past the centre line, so no hairline can open at 6 o'clock
local TRACK = Color3.fromRGB(74, 88, 124) -- the unfilled track: slate, lighter than the dark boundary so it reads
local ORIGIN = "12 o'clock (top)"
local DIRECTION = "clockwise"

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
-- Cash sits; seen in Studio: the ring over the run-time stats)
export type Options = { anchor: Instance?, avoid: (() -> { RunLayout.Rect })? }

type Capture = {
	id: string,
	car: Store.CarRef?,
	phase: string,
	progress: number, -- the supplied progress (the target of the shown fill)
	shown: number, -- the fill currently drawn, 0..progress
	shownFrom: number, -- where the current ease started
	shownAt: number, -- os.clock() when the current ease started
	easeTo: number, -- the supplied value the current ease is heading for (a repeat of it never restarts the ease)
	complete: boolean, -- the closed ring has been reached (the pulse plays once)
	step: number, -- eighths of progress passed (progress clicks)
	almost: boolean,
	tier: number,
	silver: boolean,
	pendingToken: number,
}

-- The continuous ring (see the header). Every half is a clipped copy of the same circle.
type RingParts = {
	holder: Frame,
	thick: number,
	outerRadius: number,
	trackStroke: UIStroke,
	rightClip: Frame,
	rightArc: Frame,
	rightStroke: UIStroke,
	rightGrad: UIGradient,
	leftClip: Frame,
	leftArc: Frame,
	leftStroke: UIStroke,
	leftGrad: UIGradient,
	closed: Frame,
	closedStroke: UIStroke,
	closedPop: UIScale,
}

type Visual = {
	trove: Trove.Trove,
	size: number,
	group: CanvasGroup,
	pop: UIScale,
	glow: Frame,
	accent: UIStroke,
	fill: RingParts,
	plate: Frame,
	keyHolder: Frame,
	lock: RunKit.KeyLockParts,
	shackleBase: UDim2,
	keyBase: number,
	instr: TextLabel,
	ring: Frame,
	sparks: { Frame },
	edges: { Frame },
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
	self._fill = nil :: RBXScriptConnection? -- the ring's ease; connected only while the shown fill differs from the supplied
	self._timers = {} :: { [thread]: boolean } -- delayed work (Pending time-out, hand-off hide); cancelled on any end
	self._pulses = 0
	self._pos = nil :: Vector2?
	self._vel = Vector2.zero
	self._track = "None"
	self._rising = false
	self._ticks = 0
	self._drive = nil :: RBXScriptConnection?
	self._driveT = 0
	self._sparkAt = 0
	self._sparksShown = 0
	self._countdownShown = false
	self._suppressed = false
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
			self:_cancelTimers()
			self:_stopRise()
			Music.cancel()
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		local v = self._visual
		local c = self._cap
		if v then
			v.pop.Scale = 1
			Motion.cancelAll(v.fill.closedPop)
			v.fill.closedPop.Scale = 1
		end
		if v and c and self._showing and Motion.reduced() then
			-- steady: the ring shows the supplied value at once, with the completion emphasis if it is complete
			self:_stopFill()
			self:_setShown(c.progress, false)
			self:_ringColours(true)
		end
		self:_applyDrive()
	end))
	self._trove:Add(function()
		self._token += 1
		Music.cancel()
		self:_stopRise()
		self:_stopFollow()
		self:_stopFill()
		self:_cancelTimers()
		self:_stopDrive()
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
	local cap = if ctx.screen:profile().kind == "Phone" then 0.19 else 0.24
	return math.floor(math.clamp(K.RingSize, 64, math.max(64, math.min(d.X, d.Y) * cap)))
end

-- The continuous ring (one UIStroke circle drawn three ways: the slate track, two clipped half copies with a
-- rotating half-plane gradient, and the closed ring). `outer` is the outer radius, `thick` the ring width, both in
-- design px. The stroke grows OUTWARD from its Frame, so each circle Frame is the ring's inner circle.
local function buildRing(parent: Frame, area: number, outer: number, thick: number): RingParts
	local innerD = 2 * (outer - thick)
	local halfArea = area / 2
	local base = A.Fill.Gold.Keypoints[2].Value
	local holder = make("Frame", {
		Name = "RingFill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(area, area),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = parent,
	})
	local function circle(name: string, into: Instance, pos: UDim2, z: number, colour: Color3): (Frame, UIStroke)
		local frame = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(innerD, innerD),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = into,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
		local stroke = make("UIStroke", {
			Thickness = thick,
			Color = colour,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
		return frame, stroke
	end
	local centre = UDim2.fromOffset(halfArea, halfArea)
	local _, trackStroke = circle("Track", holder, centre, 7, TRACK)
	-- a hard stop at the middle of the gradient: the visible area is the half-plane on the gradient's start side
	local soft = math.clamp(EDGE_SOFT_PX / innerD, 0.002, 0.2)
	local wedge = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5 - soft / 2, 0),
		NumberSequenceKeypoint.new(0.5 + soft / 2, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	local function half(name: string, clipX: number, arcX: number, clipW: number): (Frame, Frame, UIStroke, UIGradient)
		local clip = make("Frame", {
			Name = name,
			Position = UDim2.fromOffset(clipX, 0),
			Size = UDim2.fromOffset(clipW, area),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 8,
			Parent = holder,
		})
		local arc, stroke = circle(name .. "Arc", clip, UDim2.fromOffset(arcX, halfArea), 8, base)
		local grad = make("UIGradient", { Transparency = wedge, Rotation = 0, Parent = stroke })
		return clip, arc, stroke, grad
	end
	local rightClip, rightArc, rightStroke, rightGrad = half("RightHalf", halfArea, 0, halfArea)
	local leftClip, leftArc, leftStroke, leftGrad = half("LeftHalf", 0, halfArea, halfArea + SEAM_OVERLAP)
	local closed, closedStroke = circle("Closed", holder, centre, 8, base)
	closed.Visible = false
	local closedPop = make("UIScale", { Name = "Pop", Parent = closed })
	return {
		holder = holder,
		thick = thick,
		outerRadius = outer,
		trackStroke = trackStroke,
		rightClip = rightClip,
		rightArc = rightArc,
		rightStroke = rightStroke,
		rightGrad = rightGrad,
		leftClip = leftClip,
		leftArc = leftArc,
		leftStroke = leftStroke,
		leftGrad = leftGrad,
		closed = closed,
		closedStroke = closedStroke,
		closedPop = closedPop,
	}
end

-- A static ring at one fraction for the review specimens (no tween, no connection, nothing animates).
function KeysLock.drawRing(parent: Frame, area: number, outer: number, thick: number, fraction: number): Frame
	local ring = buildRing(parent, area, outer, thick)
	local degrees = math.clamp(fraction, 0, 1) * 360
	local closed = degrees >= 360
	ring.rightClip.Visible = not closed and degrees > 0
	ring.leftClip.Visible = not closed and degrees > 180
	ring.closed.Visible = closed
	ring.rightGrad.Enabled = degrees < 180
	ring.rightGrad.Rotation = math.clamp(degrees, 0, 180)
	ring.leftGrad.Rotation = math.clamp(degrees, 180, 360)
	return ring.holder
end

function KeysLock._build(self: KeysLock, R: number)
	if self._visual then
		self._visual.trove:Destroy()
	end
	local trove = Trove.new()
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
	-- the continuous ring: outer radius 4 px inside the boundary disc, as the segments' outer edge was
	local thick = math.max(10, math.floor(R * 0.15))
	local fill = buildRing(ring, area, R / 2 - 4, thick)
	-- thin rarity accent ring between the ring and the plate
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
	-- sparse sparks (tier 3, a pool; gold diamonds that drift off the ring edge) and the transparent rarity edges
	local sparks = {}
	for i = 1, SPARKS do
		sparks[i] = make("Frame", {
			Name = "Spark" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(7, 7),
			Rotation = 45,
			BackgroundColor3 = A.Fill.Gold.Keypoints[1].Value,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 16,
			Parent = ring,
		})
	end
	local edges = {}
	for i, side in { "Left", "Right" } do
		local edge = trove:Add(make("Frame", {
			Name = "Edge" .. side,
			AnchorPoint = Vector2.new(if i == 1 then 0 else 1, 0),
			Position = UDim2.fromScale(if i == 1 then 0 else 1, 0),
			Size = UDim2.new(0, EDGE_WIDTH, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
			Parent = self.root,
		}))
		make("UIGradient", {
			Rotation = if i == 1 then 0 else 180,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = edge,
		})
		RunKit.nonInteractive(edge)
		edges[i] = edge
	end
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
		fill = fill,
		plate = plate,
		keyHolder = lockHolder,
		lock = lock,
		shackleBase = lock.shackle.Position,
		keyBase = lock.key.Rotation,
		instr = instr,
		ring = ring,
		sparks = sparks,
		edges = edges,
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
		Motion.cancelAll(fill.closedPop)
		Motion.cancelAll(fill.closedStroke)
		Motion.cancelAll(fill.rightStroke)
		Motion.cancelAll(fill.leftStroke)
		Motion.cancelAll(lock.key)
		Motion.cancelAll(lock.shackle)
	end)
end

-- Puts the visual in the state of the current capture. `snap` = a fresh start or a rebuild (the ring shows the
-- supplied value at once and any earlier cancel dimming is undone); otherwise the ring eases to the supplied value.
function KeysLock._paint(self: KeysLock, snap: boolean)
	local v = self._visual
	local cap = self._cap
	if not v or not cap then
		return
	end
	local c = cap :: Capture
	local r = RunKit.rarity(c.car)
	v.accent.Color = r.light
	v.underline.BackgroundColor3 = r.light
	if snap then
		self:_stopFill()
		c.complete = false
		Motion.cancelAll(v.pop)
		v.pop.Scale = 1
		Motion.cancelAll(v.fill.closedPop)
		v.fill.closedPop.Scale = 1
	end
	self:_ringColours(snap)
	v.glow.BackgroundColor3 = if c.silver then RunKit.SilverFill.Keypoints[2].Value else A.Fill.Gold.Keypoints[2].Value
	v.glow.BackgroundTransparency = KeysLock._glowAlpha(c.progress, c.tier)
	v.accent.Thickness = if c.tier >= 3 then 3.5 else 2
	v.instr.TextSize = if c.almost then 26 else 20
	for _, edge in v.edges do
		edge.BackgroundColor3 = r.light
	end
	v.lock.shackle.Position = v.shackleBase
	if snap then
		self:_setShown(c.progress, false)
	else
		self:_retarget()
	end
	v.percent.Text = string.format("%d%%", math.floor(c.progress * 100 + 1e-6))
	-- the percentage is secondary (the ring says it): on the smallest phone frame it would sit under the Hop button, so it is not shown
	v.percent.Visible = self._ctx.screen:profile().name ~= "PhoneSmall"
	v.instr.Text = if c.phase == "Pending" then "SECURING…" elseif c.almost then "ALMOST!" else "HOLD ON"
	v.underline.Visible = true
end

----------------------------------------------------------------------------------------------
-- The ring

-- The ring colours for the current capture: gold (silver for an owned car) on the halves; the closed ring is
-- brighter and a little thicker once complete (the steady completion emphasis). `settle` also ends any running
-- emphasis tween on the closed ring and sets its final look (a rebuild, a fresh start, reduced motion); without it a
-- running completion tween is left to finish.
function KeysLock._ringColours(self: KeysLock, settle: boolean)
	local v = self._visual
	local c = self._cap
	if not v or not c then
		return
	end
	local palette = if c.silver then RunKit.SilverFill else A.Fill.Gold
	local base = palette.Keypoints[2].Value
	local ring = v.fill
	for _, stroke in { ring.rightStroke, ring.leftStroke } do
		Motion.cancelAll(stroke)
		stroke.Color = base
	end
	if settle or not c.complete then
		Motion.cancelAll(ring.closedStroke)
		ring.closedStroke.Color = if c.complete then palette.Keypoints[1].Value else base
		ring.closedStroke.Thickness = ring.thick + (if c.complete then COMPLETE_EXTRA else 0)
	end
end

-- Draws the ring at `fraction` (0..1 of the circumference, from 12 o'clock, clockwise). Empty and closed are handled
-- explicitly: nothing is shown at 0, and at exactly 1 the closed ring replaces both halves. `animate` = the pulse
-- may play when the ring first closes.
function KeysLock._setShown(self: KeysLock, fraction: number, animate: boolean)
	local v = self._visual
	local c = self._cap
	if not v or not c then
		return
	end
	local f = math.clamp(if fraction ~= fraction then 0 else fraction, 0, 1)
	c.shown = f
	local ring = v.fill
	local degrees = f * 360
	local closed = f >= 1
	local rightOn = not closed and degrees > 0
	local leftOn = not closed and degrees > 180
	if ring.rightClip.Visible ~= rightOn then
		ring.rightClip.Visible = rightOn
	end
	if ring.leftClip.Visible ~= leftOn then
		ring.leftClip.Visible = leftOn
	end
	if ring.closed.Visible ~= closed then
		ring.closed.Visible = closed
	end
	local rightFull = degrees >= 180
	if ring.rightGrad.Enabled == rightFull then
		ring.rightGrad.Enabled = not rightFull
	end
	ring.rightGrad.Rotation = math.clamp(degrees, 0, 180)
	ring.leftGrad.Rotation = math.clamp(degrees, 180, 360)
	v.lock.key.Rotation = v.keyBase + KEY_TURN * f
	if closed and not c.complete then
		c.complete = true
		self:_complete(animate)
	end
end

-- The ring has just closed: one bounded pulse then steady (a steady brighter, thicker ring in reduced motion).
function KeysLock._complete(self: KeysLock, animate: boolean)
	local v = self._visual
	local c = self._cap
	if not v or not c then
		return
	end
	local ring = v.fill
	local palette = if c.silver then RunKit.SilverFill else A.Fill.Gold
	local goal = { Thickness = ring.thick + COMPLETE_EXTRA, Color = palette.Keypoints[1].Value }
	if animate and not Motion.reduced() then
		Motion.tween(ring.closedStroke, "complete", Motion.info(0.14), goal)
		Motion.pop(ring.closed, COMPLETE_POP)
		self._pulses += 1
	else
		Motion.cancelAll(ring.closedStroke)
		ring.closedStroke.Thickness = goal.Thickness
		ring.closedStroke.Color = goal.Color
	end
end

function KeysLock._stopFill(self: KeysLock)
	if self._fill then
		self._fill:Disconnect()
		self._fill = nil
	end
end

-- The supplied progress changed: ease the shown fill to it (at once in reduced motion or while hidden). The
-- connection exists only while shown and supplied differ.
function KeysLock._retarget(self: KeysLock)
	local v = self._visual
	local c = self._cap
	if not v or not c then
		return
	end
	if c.shown >= c.progress - 1e-6 then
		return
	end
	if Motion.reduced() or not self._showing then
		self:_stopFill()
		self:_setShown(c.progress, false)
		return
	end
	if self._fill and c.easeTo == c.progress then
		return -- the same supplied value again (every store update calls this): the ease keeps its own timeline
	end
	c.easeTo = c.progress
	c.shownFrom = c.shown
	c.shownAt = os.clock()
	if self._fill then
		return
	end
	self._fill = RunService.Heartbeat:Connect(function()
		local cap = self._cap
		if not cap or not self._visual then
			self:_stopFill()
			return
		end
		local a = math.min((os.clock() - cap.shownAt) / FILL_SECONDS, 1)
		local f = math.min(cap.shownFrom + (cap.progress - cap.shownFrom) * a, cap.progress)
		if a >= 1 then
			f = cap.progress
			self:_stopFill()
		end
		self:_setShown(f, true)
	end)
end

-- Delayed work with a handle, so any end (cancel, lose, reset, destroy) can cancel it.
function KeysLock._later(self: KeysLock, seconds: number, fn: () -> ())
	local handle: thread? = nil
	handle = task.delay(seconds, function()
		if handle then
			self._timers[handle] = nil
		end
		fn()
	end)
	if handle then
		self._timers[handle] = true
	end
end

function KeysLock._cancelTimers(self: KeysLock)
	for handle in self._timers do
		task.cancel(handle)
	end
	table.clear(self._timers)
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

-- The glow gets brighter with the tiers (never below 0.5 transparency: restrained and transparent).
function KeysLock._glowAlpha(progress: number, tier: number): number
	local base = 0.9 - 0.22 * progress
	if tier >= 3 then
		return math.max(base - 0.1, 0.5)
	elseif tier >= 2 then
		return math.max(base - 0.05, 0.5)
	end
	return base
end

function KeysLock._start(self: KeysLock, id: string, car: Store.CarRef?)
	local old = self._cap
	if old and RANK[old.phase] < 3 then
		-- one Keys at a time: an unfinished capture is replaced quietly
		self:_logLine(old.id .. ": replaced by " .. id)
	end
	self:_stopRise()
	self:_cancelTimers() -- an earlier capture's time-out or hand-off hide never touches this one
	self._cap = {
		id = id,
		car = car,
		phase = "Progress",
		progress = 0,
		shown = 0,
		shownFrom = 0,
		shownAt = 0,
		easeTo = 0,
		complete = false,
		step = 0,
		almost = false,
		tier = 1,
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
	local step = math.floor(progress * TICK_STEPS + 1e-6)
	local v = self._visual
	local reduced = Motion.reduced()
	local tier = if progress >= K.AlmostAt then 3 elseif progress >= TIER2_AT then 2 else 1
	if tier > c.tier then
		c.tier = tier
		self:_logLine(c.id .. ": tier " .. tier)
	end
	if v then
		v.percent.Text = string.format("%d%%", math.floor(progress * 100 + 1e-6))
		v.glow.BackgroundTransparency = KeysLock._glowAlpha(progress, c.tier)
		self:_retarget() -- the ring (and the key with it) eases to the supplied progress
	end
	if step > c.step then
		self._ticks += step - c.step
		if c.tier >= 2 then
			Sounds.play("KeysTick") -- retired in Round 3 (the hook is silent: it would stack on the chime ladder); kept as a no-op call
		end
	end
	c.step = step
	if progress > 0 then
		self._rising = true
		Sounds.rise("KeysRise", progress)
		Music.tension(progress, "Holding") -- the run music's tension layer follows the supplied progress (Round 2)
	end
	if not c.almost and progress >= K.AlmostAt then
		c.almost = true -- exactly once per capture
		if v then
			v.instr.Text = "ALMOST!"
			v.instr.TextSize = 26 -- larger, then it settles: no perpetual bounce
			v.accent.Thickness = 3.5
			if not reduced then
				Motion.pop(v.instr, 1.2)
			end
		end
		self:_logLine(c.id .. ": ALMOST!")
	end
	self:_applyDrive()
end

-- Tier 3 decoration: one capped pulse of the glow and the transparent rarity edges, sparse sparks. Nothing else
-- moves. Held still while a warning or the run end is flagged (they outrank capture decoration), absent in reduced
-- motion.
function KeysLock._stopDrive(self: KeysLock)
	if self._drive then
		self._drive:Disconnect()
		self._drive = nil
	end
	local v = self._visual
	if v then
		for _, edge in v.edges do
			edge.Visible = false
		end
		for _, spark in v.sparks do
			Motion.cancelAll(spark)
			spark.Visible = false
		end
	end
	self._sparksShown = 0
end

function KeysLock._applyDrive(self: KeysLock)
	local cap = self._cap
	local v = self._visual
	local want = cap ~= nil and v ~= nil and self._showing and cap.phase == "Progress" and cap.tier >= 3
	if not want or Motion.reduced() then
		self:_stopDrive()
		return
	end
	if self._drive then
		return
	end
	self._driveT = 0
	self._sparkAt = 0
	self._drive = RunService.Heartbeat:Connect(function(dt: number)
		local vis = self._visual
		local c = self._cap
		if not vis or not c or c.phase ~= "Progress" then
			self:_stopDrive()
			return
		end
		local flags = RunBus.flags(self._ctx)
		local outranked = flags.warning or flags.ended
		self._suppressed = outranked
		local base = KeysLock._glowAlpha(c.progress, c.tier)
		for _, edge in vis.edges do
			edge.Visible = not outranked
		end
		if outranked then
			vis.glow.BackgroundTransparency = base
			return
		end
		self._driveT += dt
		local k = 0.5 - 0.5 * math.cos(2 * math.pi * PULSE_HZ * self._driveT) -- one peak a second
		vis.glow.BackgroundTransparency = base + 0.12 * (1 - k)
		for _, edge in vis.edges do
			edge.BackgroundTransparency = 0.8 + 0.12 * (1 - k)
		end
		if self._driveT - self._sparkAt >= SPARK_EVERY then
			self._sparkAt = self._driveT
			for _, spark in vis.sparks do
				if not spark.Visible then
					local a = math.random() * 2 * math.pi
					local rr = vis.size / 2
					local cx, cy = vis.size / 2 + PAD, vis.size / 2 + PAD
					spark.Position = UDim2.fromOffset(cx + math.sin(a) * rr, cy - math.cos(a) * rr)
					spark.BackgroundTransparency = 0.1
					spark.Visible = true
					self._sparksShown += 1
					local out = Vector2.new(math.sin(a), -math.cos(a)) * 16
					Motion.tween(spark, "spark", Motion.info(0.4), {
						Position = UDim2.fromOffset(cx + math.sin(a) * rr + out.X, cy - math.cos(a) * rr + out.Y),
						BackgroundTransparency = 1,
					}).Completed
						:Connect(function()
							spark.Visible = false
						end)
					break
				end
			end
		end
	end)
end

-- The countdown replaces the percentage only when the source says its number is trustworthy.
function KeysLock._countdown(self: KeysLock, keys: Store.KeysState)
	local v = self._visual
	local cap = self._cap
	if not v or not cap or cap.phase ~= "Progress" then
		self._countdownShown = false
		return
	end
	local left = keys.remainingSeconds
	if keys.timingTrusted == true and left ~= nil and left >= 0 and left == left then
		v.percent.Text = string.format("%.1fs", left)
		self._countdownShown = true
	else
		self._countdownShown = false -- unknown or variable: the percentage and ALMOST! say it
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
	c.step = TICK_STEPS
	self._countdownShown = false
	Music.tension(1, "Securing") -- holds at its peak until the confirmation (or a cancel) arrives
	Sounds.play("KeysPending") -- one quiet note: the ring is full but nothing is confirmed (never the fanfare)
	self:_stopRise()
	self:_stopDrive()
	self:_logLine(c.id .. ": Progress -> Pending")
	self:_paint(false) -- the ring eases to full and then holds, steady (no moving highlight)
	c.pendingToken += 1
	local token = c.pendingToken
	self:_later(PENDING_TIMEOUT, function()
		if self._cap == c and c.phase == "Pending" and c.pendingToken == token then
			self:_end("Unconfirmed", "NotConfirmed")
		end
	end)
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
	if phase == "Confirmed" then
		Music.resolve()
	else
		Music.cancel()
	end
	self:_stopRise()
	self:_cancelTimers() -- the Pending time-out (and any earlier hide) is over
	self:_stopDrive()
	self:_logLine(c.id .. ": " .. from .. " -> " .. phase)
	local v = self._visual
	local claimed = phase == "Confirmed" or phase == "Joyride"
	if not claimed or not v or not self._showing then
		self:_stopFill() -- a cancelled ring stops where it is; a claimed one that is hidden has nothing to ease
	end
	if not v or not self._showing then
		return
	end
	self._token += 1
	local token = self._token
	local reduced = Motion.reduced()
	if claimed then
		if phase == "Joyride" then
			c.silver = true
			self:_ringColours(true) -- the closed ring turns silver-bright
		end
		c.progress = 1
		self:_paint(false)
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
		self:_later(if reduced then 0.35 else 0.55, function()
			if token == self._token then
				self:_hide(false)
			end
		end)
		return
	end
	-- Canceled / Unconfirmed: the ring dims where it stands and settles a little, with a short truthful reason
	local text = RunKit.keysReason(reason)
	v.instr.Text = text or ""
	v.underline.Visible = false
	v.percent.Visible = false
	local ring = v.fill
	local dim = A.Fill.Disabled.Keypoints[2].Value
	for _, stroke in { ring.rightStroke, ring.leftStroke, ring.closedStroke } do
		Motion.cancelAll(stroke)
		if reduced then
			stroke.Color = dim
		else
			Motion.tween(stroke, "dim", Motion.info(0.35), { Color = dim })
		end
	end
	if not reduced then
		Motion.tween(v.pop, "settle", Motion.info(0.4), { Scale = 0.93 })
	end
	self:_later(if text then 1.2 else 0.5, function()
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
		self:_countdown(k)
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
		Music.cancel()
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
	self:_paint(true)
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
	self:_stopFill()
	self:_stopDrive()
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
	-- the top row piece by piece (strip, Cash, Settings) rather than the full-width top band, so
	-- the ring can use the right column under Settings on short screens
	local avoid = {
		prot,
		RunLayout.stripRect(ctx),
		RunLayout.cashRect(ctx),
		RunLayout.gearRect(ctx),
		(RunLayout.heatRect(ctx)),
		(RunLayout.hopRect(ctx)),
	}
	if ctx.screen:profile().kind ~= "Phone" then
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
		local chip = if ctx.screen:profile().kind == "Phone" then RunLayout.gearRect(ctx) else RunLayout.chipRect(ctx)
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
		-- only a capture that is still live comes back: an ended one (dimming before its hide) must not be re-shown, because
		-- _show() replaces the token its pending hide checks, and the ring would then stay on screen for good
		local live = self._cap ~= nil and RANK[(self._cap :: Capture).phase] < 3
		if wasShowing and live then
			self:_show()
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
		Music.cancel()
	end
end

-- Ring numbers read back from the real instances (not from what the code meant to set), for the scenarios.
function KeysLock._ringDebug(self: KeysLock): { [string]: any }
	local v = self._visual :: Visual
	local c = self._cap
	local ring = v.fill
	local shown = if c then c.shown else 0
	local degrees = shown * 360
	local holderPos, holderSize = ring.holder.AbsolutePosition, ring.holder.AbsoluteSize
	local function centreOf(g: GuiObject): Vector2
		return g.AbsolutePosition + g.AbsoluteSize / 2
	end
	local plateCentre = centreOf(v.plate)
	local offset = math.max(
		(centreOf(ring.rightArc) - plateCentre).Magnitude,
		(centreOf(ring.leftArc) - plateCentre).Magnitude,
		(centreOf(ring.closed) - plateCentre).Magnitude
	)
	local fillsCentre = false
	for _, g in { ring.holder, ring.rightClip, ring.rightArc, ring.leftClip, ring.leftArc, ring.closed } do
		if g.BackgroundTransparency < 1 then
			fillsCentre = true
		end
	end
	local side = math.max(holderSize.X, 1)
	return {
		technique = "two ClipsDescendants halves, UIStroke circles, hard-stop UIGradient half-plane (Rotation) + a closed ring",
		origin = ORIGIN,
		direction = DIRECTION,
		target = if c then c.progress else 0,
		shown = shown,
		degrees = degrees,
		expectedRightRotation = math.clamp(degrees, 0, 180),
		expectedLeftRotation = math.clamp(degrees, 180, 360),
		rightRotation = ring.rightGrad.Rotation,
		leftRotation = ring.leftGrad.Rotation,
		rightGradientOn = ring.rightGrad.Enabled,
		rightVisible = ring.rightClip.Visible,
		leftVisible = ring.leftClip.Visible,
		closedVisible = ring.closed.Visible,
		stepping = self._fill ~= nil,
		followSeconds = FILL_SECONDS,
		complete = c ~= nil and c.complete,
		pulses = self._pulses,
		popScale = ring.closedPop.Scale,
		thickness = ring.thick,
		outerDiameter = ring.outerRadius * 2,
		closedThickness = ring.closedStroke.Thickness,
		fillColour = ring.rightStroke.Color:ToHex(),
		closedColour = ring.closedStroke.Color:ToHex(),
		trackColour = ring.trackStroke.Color:ToHex(),
		splitX = (ring.rightClip.AbsolutePosition.X - holderPos.X) / side,
		leftEdgeX = (ring.leftClip.AbsolutePosition.X + ring.leftClip.AbsoluteSize.X - holderPos.X) / side,
		centreOffsetPx = offset,
		keyHolderOffsetPx = (centreOf(v.keyHolder) - plateCentre).Magnitude,
		fillsCentre = fillsCentre,
		segmented = false,
		instances = #ring.holder:GetDescendants() + 1,
		keyRotation = v.lock.key.Rotation,
		expectedKeyRotation = v.keyBase + KEY_TURN * shown,
	}
end

function KeysLock.getDebugState(self: KeysLock): { [string]: any }
	local cap = self._cap
	local v = self._visual
	local finals = 0
	for _ in self._final do
		finals += 1
	end
	local box = if v and self._pos then self:_box(self._pos :: Vector2) else nil
	local timers = 0
	for _ in self._timers do
		timers += 1
	end
	local connections = (if self._follow then 1 else 0) + (if self._drive then 1 else 0) + (if self._fill then 1 else 0)
	return {
		visible = self._visible,
		showing = self._showing,
		id = cap and cap.id,
		phase = if cap then cap.phase else "Idle",
		rank = if cap then RANK[cap.phase] else 0,
		progress = cap and cap.progress,
		ring = if v then self:_ringDebug() else nil,
		connections = connections,
		timers = timers,
		instances = #self.root:GetDescendants(),
		groupVisible = v ~= nil and v.group.Visible,
		almostShown = cap and cap.almost,
		tier = cap and cap.tier,
		pulsing = self._drive ~= nil and not self._suppressed,
		pulseHz = PULSE_HZ,
		decorationHeld = self._suppressed,
		sparksShown = self._sparksShown,
		edgesShown = v ~= nil and v.edges[1].Visible,
		countdownShown = self._countdownShown,
		bodyMotion = "none: a vehicle shudder is deferred; the ridden vehicle, seat, character root and camera are never moved",
		silver = cap and cap.silver,
		instruction = v and v.instr.Text,
		percent = if v and (v.percent.Visible or self._ctx.screen:profile().name == "PhoneSmall")
			then v.percent.Text
			else nil, -- the text is kept on PhoneSmall, where it is not shown
		percentShown = if v then v.percent.Visible else false,
		ringSize = v and v.size,
		tracking = self._track,
		following = self._follow ~= nil,
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
