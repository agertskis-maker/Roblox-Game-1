--!strict
-- Hop guidance for the two-press Hop (Round 8, WS-10, R-01 and R-02; Brian R's lane, one new file). Client visuals only: it reads
-- where the run's best target is and draws; the run (RunController) and the server decide everything else (a dive is still checked
-- by time and distance exactly as Round 7 set it).
--
-- Quiet then loud, like the reference game (review/round7/references/hop-sequence-sheet.jpg, R8-IMG-27):
--   RIDING   no arrows on the road. The best car in reach gets one thin, faint yellow ring on the road under it (about 40% opaque,
--            a slow pulse) and its floating label grows a little. Nothing at all when no car is reachable.
--   FLOAT    after the first press the same ring becomes the big bright landing ring (full strength, thicker, a pulse, a soft glow
--            on the road) with three small chevrons round it pointing inward and turning slowly; the target car gets a soft yellow
--            outline; and a dive path of five small chevrons runs on a curve from just below the player to the ring, sliding toward
--            the car. With no car in reach there is no ring and no path.
--   DIVE     the ring closes in on the car as the player lands on it.
-- When the best target changes during the float the ring swings to the new car in about SWING_TIME (the ring's offset to the car
-- decays, so it still tracks the moving car exactly) and plays a soft tick. The run keeps a car as the target until another one beats
-- it by SWITCH_MARGIN and SWITCH_DWELL seconds have passed, so it never flickers between two cars (keepCurrent below).
-- In the tutorial and the first two runs (options.floatHelp) the ring, glow and path are a little brighter.
-- Reduce Motion (GuiService.ReducedMotionEnabled, or the preview override attribute): no pulse, the chevrons stand still.
--
--   local guide = HopGuide.new(zoneFolder, { floatHelp = bool?, onSwing = (() -> ())? })
--   guide:update(view)           -- once a frame, before the camera moves: the ring, the outline, the label (world objects)
--   guide:updateScreen()         -- once a frame, after the camera moved: the dive path (screen space, so it needs the final camera)
--   guide:noteDive(target, dist) / guide:noteLanding(car)            -- measurements for the R-04 feel check
--   guide:hide()  guide:getDebugState()  guide:destroy()
--   HopGuide.keepCurrent(currentScore, bestScore, sinceSwitch) -> boolean   -- the target hysteresis (pure)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CarTags = require(script.Parent.CarTags)
local RunRoad = require(script.Parent.RunRoad)

local HopGuide = {}
HopGuide.__index = HopGuide

-- Recorded values (R-02). Targeting scores are studs: the distance to the car plus the steering bias (RunController.findTarget).
HopGuide.SWITCH_MARGIN = 6 -- a challenger must score at least this much better than the current target to take over
HopGuide.SWITCH_DWELL = 0.15 -- seconds a target is kept before any switch
HopGuide.SWING_TIME = 0.12 -- seconds for the ring to reach a new car
local SWING_TAU = HopGuide.SWING_TIME / 3 -- exp(-3) is 5% left after SWING_TIME

local PATH_COUNT = 5
local YELLOW = Color3.fromRGB(255, 226, 70)
local GOLD = Color3.fromRGB(255, 196, 40)
local WHITE = Color3.fromRGB(255, 255, 255)
local WARN = Color3.fromRGB(255, 96, 86)
local CANVAS = 320 -- the SurfaceGui's fixed canvas in pixels
local RING_SIZE = 196 -- the ring's diameter inside the canvas, pixels (room left for the glow and the dive's closing-in scale)

export type Target = {
	index: number,
	model: Model,
	tag: BillboardGui?,
	along: number,
	lateral: number,
	width: number,
	length: number,
}

export type View = {
	mode: string, -- "Riding" | "Float" | "Dive" | "Recover" | "Ended" ...
	target: Target?, -- the run's best target in reach right now (with the hysteresis)
	diveTarget: Target?, -- the car being dived onto, in mode "Dive"
	rider: { along: number, lateral: number, up: number },
	hopA: number, -- 0..1: progress of the float or the dive
	tooStrong: boolean,
}

type Chevron = {
	root: Frame,
	image: ImageLabel?,
	bars: { Frame },
	strokes: { UIStroke },
}

type DiveRecord = { shown: number?, pressed: number, dist: number, serverOk: boolean, landed: number? }

export type HopGuide = typeof(setmetatable(
	{} :: {
		_trove: any,
		_help: boolean,
		_onSwing: (() -> ())?,
		_part: Part,
		_gui: SurfaceGui,
		_scale: UIScale,
		_ring: UIStroke,
		_glowA: UIStroke,
		_glowB: UIStroke,
		_spin: Frame,
		_markers: { Chevron },
		_highlight: Highlight,
		_pathGui: ScreenGui,
		_path: { Chevron },
		_shown: Target?,
		_pos: Vector3,
		_swing: Vector3,
		_diameter: number,
		_alpha: number,
		_aim: number,
		_lastSwitch: number,
		_clock: number,
		_mode: string,
		_rider: Vector3,
		_hopA: number,
		_phase: number,
		_focus: { [BillboardGui]: number },
		_log: { DiveRecord },
		_dives: number,
		_landed: number,
		_matched: number,
		_swings: number,
		_shownFrames: number,
		_unreachable: number,
		_pathShown: number,
		_visFrames: number,
		_visDt: number,
		_visDtMax: number,
		_idleFrames: number,
		_idleDt: number,
		_cpuSum: number,
		_cpuMax: number,
		_cpuFrames: number,
	},
	HopGuide
))

local function reducedMotion(): boolean
	local player = Players.LocalPlayer
	local override = player and player:GetAttribute("Lane3ReducedMotionOverride")
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

-- The hysteresis, pure so it can be tested: keep the current target unless it is gone (nil score), or the dwell has passed and the
-- best car scores better than it by more than SWITCH_MARGIN. Scores are lower-is-better.
function HopGuide.keepCurrent(currentScore: number?, bestScore: number, sinceSwitch: number): boolean
	if currentScore == nil then
		return false
	end
	if sinceSwitch < HopGuide.SWITCH_DWELL then
		return true
	end
	return bestScore > currentScore - HopGuide.SWITCH_MARGIN
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- One small chevron, tip down: the uploaded art when it is there, two bars when not.
local function buildChevron(parent: Instance, size: number, name: string): Chevron
	local root = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local art = AssetIds.image("r8_hop_chevron")
	local chevron: Chevron = { root = root, image = nil, bars = {}, strokes = {} }
	if art ~= "" then
		chevron.image = make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = art,
			ImageTransparency = 1,
		}, root)
		return chevron
	end
	for i, side in { -1, 1 } do
		local bar = make("Frame", {
			Name = "Arm" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + side * 0.19, 0.5),
			Size = UDim2.fromScale(0.58, 0.17),
			Rotation = -side * 48,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, root)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
		local stroke = make("UIStroke", { Color = YELLOW, Thickness = 2, Transparency = 1 }, bar)
		table.insert(chevron.bars, bar)
		table.insert(chevron.strokes, stroke)
	end
	return chevron
end

-- alpha 0..1 (1 = the chevron's full look: white at about 80% with a yellow edge)
local function fadeChevron(c: Chevron, alpha: number)
	c.root.Visible = alpha > 0.02
	local t = 1 - alpha * 0.82
	if c.image then
		c.image.ImageTransparency = t
	end
	for _, bar in c.bars do
		bar.BackgroundTransparency = t
	end
	for _, stroke in c.strokes do
		stroke.Transparency = 1 - alpha
	end
end

function HopGuide.new(zone: Instance, options: { floatHelp: boolean?, onSwing: (() -> ())? }?)
	local opts = options or {}
	local trove = Trove.new()

	-- the landing ring: a flat part on the road with a SurfaceGui (a ring, two glows, three inward chevrons)
	local part = make("Part", {
		Name = "HopRing",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(10, 0.1, 10),
		CFrame = CFrame.new(0, 0, 0),
	}, nil)
	trove:Add(part)
	local gui = make("SurfaceGui", {
		Name = "Ring",
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(CANVAS, CANVAS),
		LightInfluence = 0,
		AlwaysOnTop = false,
		Brightness = 2,
		Enabled = false,
	}, part)
	local scaler = make("Frame", {
		Name = "Scaler",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CANVAS, CANVAS),
		BackgroundTransparency = 1,
	}, gui)
	local scale = make("UIScale", { Scale = 1 }, scaler)
	local function circle(name: string, thickness: number, colour: Color3, transparency: number): UIStroke
		local f = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(RING_SIZE, RING_SIZE),
			BackgroundTransparency = 1,
		}, scaler)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		return make("UIStroke", { Color = colour, Thickness = thickness, Transparency = transparency }, f)
	end
	local glowA = circle("GlowOuter", 30, GOLD, 1)
	local glowB = circle("GlowInner", 18, YELLOW, 1)
	local ring = circle("Ring", 6, YELLOW, 1)
	local spin = make("Frame", {
		Name = "Spin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CANVAS, CANVAS),
		BackgroundTransparency = 1,
	}, scaler)
	local markers: { Chevron } = {}
	for i = 0, 2 do
		local phi = math.rad(-90 + i * 120)
		local c = buildChevron(spin, 58, "Marker" .. i)
		local radius = RING_SIZE / 2 + 2
		c.root.Position = UDim2.fromOffset(CANVAS / 2 + radius * math.cos(phi), CANVAS / 2 + radius * math.sin(phi))
		-- the art points down at rotation 0; this one points from its place on the ring to the centre
		c.root.Rotation = math.deg(math.atan2(math.cos(phi), -math.sin(phi)))
		table.insert(markers, c)
	end
	part.Parent = zone

	-- the soft outline on the target car (a Highlight: no fill, a faint yellow edge)
	local highlight = make("Highlight", {
		Name = "TargetOutline",
		FillTransparency = 1,
		OutlineColor = YELLOW,
		OutlineTransparency = 0.4,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Enabled = false,
	}, zone)
	trove:Add(highlight)

	-- the dive path: chevrons in screen space under the HUD
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local pathGui = make("ScreenGui", {
		Name = "HopGuidePath",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 3,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	trove:Add(pathGui)
	local path: { Chevron } = {}
	for i = 1, PATH_COUNT do
		table.insert(path, buildChevron(pathGui, 34, "Step" .. i))
	end
	pathGui.Parent = playerGui or Players.LocalPlayer:WaitForChild("PlayerGui")

	local self = setmetatable({
		_trove = trove,
		_help = opts.floatHelp == true,
		_onSwing = opts.onSwing,
		_part = part,
		_gui = gui,
		_scale = scale,
		_ring = ring,
		_glowA = glowA,
		_glowB = glowB,
		_spin = spin,
		_markers = markers,
		_highlight = highlight,
		_pathGui = pathGui,
		_path = path,
		_shown = nil :: Target?,
		_pos = Vector3.zero,
		_swing = Vector3.zero,
		_diameter = 10,
		_alpha = 0,
		_aim = 0,
		_lastSwitch = -math.huge,
		_clock = os.clock(),
		_mode = "Riding",
		_rider = Vector3.zero,
		_hopA = 0,
		_phase = 0,
		_focus = {},
		_log = {},
		_dives = 0,
		_landed = 0,
		_matched = 0,
		_swings = 0,
		_shownFrames = 0,
		_unreachable = 0,
		_pathShown = 0,
		_visFrames = 0,
		_visDt = 0,
		_visDtMax = 0,
		_idleFrames = 0,
		_idleDt = 0,
		_cpuSum = 0,
		_cpuMax = 0,
		_cpuFrames = 0,
	}, HopGuide)
	return self
end

local function centreOf(target: Target): Vector3
	return RunRoad.frame(target.along, target.lateral, 0.12).Position
end

-- the labels grow a little on the car in focus and ease back when it is not (CarTags.setFocus)
local function stepFocus(self: HopGuide, focused: BillboardGui?, dt: number)
	if focused and self._focus[focused] == nil then
		self._focus[focused] = 0
	end
	local k = 1 - math.exp(-dt * 12)
	for tag, amount in self._focus do
		if not tag.Parent then
			self._focus[tag] = nil
			continue
		end
		local want = if tag == focused then 1 else 0
		local nextAmount = amount + (want - amount) * k
		if want == 0 and nextAmount < 0.01 then
			CarTags.setFocus(tag, 0)
			self._focus[tag] = nil
		else
			self._focus[tag] = nextAmount
			CarTags.setFocus(tag, nextAmount)
		end
	end
end

local function addCpu(self: HopGuide, started: number)
	local spent = (os.clock() - started) * 1000
	self._cpuSum += spent
	self._cpuFrames += 1
	self._cpuMax = math.max(self._cpuMax, spent)
end

function HopGuide.update(self: HopGuide, view: View)
	-- the guide's own clock: the run's dt is slowed during the float, and the ring must swing in real time
	local now = os.clock()
	local dt = math.clamp(now - self._clock, 0, 0.1)
	self._clock = now
	local reduced = reducedMotion()
	local mode = view.mode
	local aiming = mode == "Float"
	local diving = mode == "Dive"
	local riding = mode == "Riding"
	self._mode = mode
	self._hopA = view.hopA
	self._rider = RunRoad.frame(view.rider.along, view.rider.lateral, view.rider.up).Position
	local target: Target? = if diving then view.diveTarget elseif riding or aiming then view.target else nil

	-- a new best target: the ring swings to it (its offset decays); in the float it also ticks
	if target ~= self._shown then
		local old = self._shown
		self._shown = target
		self._lastSwitch = now
		if target and old and self._alpha > 0.05 then
			self._swing = self._pos - centreOf(target)
			if aiming then
				self._swings += 1
				if self._onSwing then
					self._onSwing()
				end
			end
		else
			self._swing = Vector3.zero
		end
	end

	-- fade and ring state; "aim" is how loud the ring is (0 riding, 1 floating or diving), eased over about 0.12 s
	local k = 1 - math.exp(-dt * (if target then 18 else 12))
	self._alpha += ((if target then 1 else 0) - self._alpha) * k
	local wantAim = if aiming or diving then 1 else 0
	self._aim += (wantAim - self._aim) * (1 - math.exp(-dt * 18))
	if reduced then
		self._aim = wantAim
	end
	local alpha, aim = self._alpha, self._aim
	local live = alpha > 0.02
	self._gui.Enabled = live
	if not live and not target then
		self._highlight.Enabled = false
		stepFocus(self, nil, dt)
		self._swing = Vector3.zero
		addCpu(self, now)
		return
	end

	local centre = if target then centreOf(target) else self._pos - self._swing
	if target then
		self._swing *= math.exp(-dt / SWING_TAU)
		if self._swing.Magnitude < 0.01 then
			self._swing = Vector3.zero
		end
		local d = math.max(target.width, target.length * 0.7) + 3
		if math.abs(d - self._diameter) > 0.05 then
			self._diameter = d
			self._part.Size = Vector3.new(d * CANVAS / RING_SIZE, 0.1, d * CANVAS / RING_SIZE) -- the ring itself is RING_SIZE of the CANVAS
		end
	end
	self._pos = centre + self._swing
	self._part.CFrame = CFrame.new(self._pos)

	-- the ring: thin and faint riding, thick and bright floating; red on a car that is too strong (the gate is off in the beta)
	local colour = if view.tooStrong then WARN else YELLOW
	local brightness = if self._help then 1 else 0.9
	local ringOpacity = (0.4 + (brightness - 0.4) * aim) * alpha
	self._ring.Color = if diving then WHITE:Lerp(colour, view.hopA) else colour
	self._ring.Thickness = 5 + 7 * aim
	self._ring.Transparency = 1 - ringOpacity
	self._glowB.Transparency = 1 - 0.5 * aim * alpha * brightness
	self._glowA.Transparency = 1 - 0.3 * aim * alpha * brightness
	local pulse = 1
	if not reduced then
		pulse = if aim > 0.5
			then 1 + 0.05 * math.sin(now * 2 * math.pi * 2.2)
			else 1 + 0.025 * math.sin(now * 2 * math.pi * 0.9)
	end
	self._scale.Scale = if diving then 1.25 - 0.25 * view.hopA else pulse
	self._spin.Rotation = if reduced then 0 else (now * 40) % 360
	for _, m in self._markers do
		fadeChevron(m, aim * alpha * brightness)
	end

	-- the outline on the car, only while aiming or diving
	local outline = (aiming or diving) and target ~= nil and alpha > 0.3
	self._highlight.Adornee = if outline then (target :: Target).model else nil
	self._highlight.OutlineTransparency = if self._help then 0.2 else 0.4
	self._highlight.Enabled = outline

	stepFocus(self, if target then target.tag else nil, dt)

	-- measurements for the feel check: how often the ring shows a car the dive could not reach (it should be never)
	if target and aiming then
		self._shownFrames += 1
		local da = target.along - view.rider.along
		local dl = target.lateral - view.rider.lateral
		local dist = math.sqrt(da * da + dl * dl) - target.length * 0.25
		if dist > RunConfig.FLOAT_REACH + 0.5 then
			self._unreachable += 1
		end
	end
	-- frame time while the path is showing, and while it is not (Studio, this machine; not a device measurement)
	if aiming and target and alpha > 0.5 then
		self._visFrames += 1
		self._visDt += dt
		self._visDtMax = math.max(self._visDtMax, dt)
	else
		self._idleFrames += 1
		self._idleDt += dt
	end
	if not reduced then
		self._phase = (self._phase + dt * 1.1) % 1
	end
	addCpu(self, now)
end

-- The dive path: five small chevrons on a curve from just below the player to the near edge of the ring, sliding toward the car.
-- Screen space, after the camera has moved this frame.
function HopGuide.updateScreen(self: HopGuide)
	local started = os.clock()
	local camera = Workspace.CurrentCamera
	local target = self._shown
	local show = camera ~= nil and target ~= nil and self._mode == "Float" and self._alpha > 0.3
	if not show or not camera then
		for _, c in self._path do
			c.root.Visible = false
		end
		self._pathShown = 0
		addCpu(self, started)
		return
	end
	local from = self._rider + Vector3.new(0, -2.4, 0)
	-- end on the ring's near rim, so the path points at the car and never lies on top of it
	local back = Vector3.new(from.X - self._pos.X, 0, from.Z - self._pos.Z)
	back = if back.Magnitude > 0.5 then back.Unit else Vector3.new(0, 0, 1)
	local to = self._pos + back * (self._diameter * 0.5) + Vector3.new(0, 0.5, 0)
	local mid = (from + to) / 2 + Vector3.new(0, 0.28 * (to - from).Magnitude, 0)
	local function curve(t: number): Vector3
		local a = from:Lerp(mid, t)
		local b = mid:Lerp(to, t)
		return a:Lerp(b, t)
	end
	local viewport = camera.ViewportSize
	local tanHalf = math.tan(math.rad(camera.FieldOfView / 2))
	local brightness = if self._help then 1 else 0.85
	local reduced = reducedMotion()
	local phase = if reduced then 0.5 else self._phase
	local firstScreen: Vector2? = nil
	local lastScreen: Vector2? = nil
	local shown = 0
	local placed: { { pos: Vector2, rot: number, size: number, alpha: number } } = {}
	for i = 1, PATH_COUNT do
		local u = ((i - 1) + phase) / PATH_COUNT
		local t = 0.1 + 0.8 * u
		local p, depthOk = camera:WorldToViewportPoint(curve(t))
		local ahead = camera:WorldToViewportPoint(curve(math.min(t + 0.04, 1)))
		if p.Z <= 0.5 or ahead.Z <= 0.5 then
			table.insert(placed, { pos = Vector2.zero, rot = 0, size = 0, alpha = 0 })
			continue
		end
		local dx, dy = ahead.X - p.X, ahead.Y - p.Y
		local rot = if dx * dx + dy * dy > 0.25 then math.deg(math.atan2(-dx, dy)) else 0
		local pxPerStud = viewport.Y / (2 * p.Z * tanHalf)
		local size = math.clamp(1.5 * pxPerStud, 14, 0.06 * viewport.Y)
		-- fades in from the player and out toward the ring, so a chevron never pops when the slide wraps round
		local a = math.sin(math.pi * u) ^ 0.7 * brightness * self._aim * self._alpha
		if not depthOk then
			a *= 0.5
		end
		local pos = Vector2.new(p.X, p.Y)
		firstScreen = firstScreen or pos
		lastScreen = pos
		table.insert(placed, { pos = pos, rot = rot, size = size, alpha = a })
	end
	-- too close to draw a path (the ring alone says it)
	local tooShort = firstScreen == nil
		or lastScreen == nil
		or ((firstScreen :: Vector2) - (lastScreen :: Vector2)).Magnitude < 70
	for i, c in self._path do
		local item = placed[i]
		if tooShort or item.alpha <= 0.02 then
			c.root.Visible = false
			continue
		end
		shown += 1
		c.root.Position = UDim2.fromOffset(item.pos.X, item.pos.Y)
		c.root.Size = UDim2.fromOffset(item.size, item.size)
		c.root.Rotation = item.rot
		fadeChevron(c, item.alpha)
	end
	self._pathShown = shown
	addCpu(self, started)
end

-- R-04: the second press, as the guide saw it
function HopGuide.noteDive(self: HopGuide, target: Target, dist: number)
	local entry: DiveRecord = {
		shown = if self._shown then self._shown.index else nil,
		pressed = target.index,
		dist = dist,
		serverOk = dist <= RunConfig.HOP_REACH_MAX,
	}
	self._dives += 1
	table.insert(self._log, entry)
	if #self._log > 60 then
		table.remove(self._log, 1)
	end
end

function HopGuide.noteLanding(self: HopGuide, car: Target)
	local last = self._log[#self._log]
	if last and last.landed == nil then
		last.landed = car.index
		self._landed += 1
		if last.landed == last.pressed and last.shown == last.pressed then
			self._matched += 1
		end
	end
end

function HopGuide.hide(self: HopGuide)
	self._shown = nil
	self._alpha = 0
	self._aim = 0
	self._swing = Vector3.zero
	self._gui.Enabled = false
	self._highlight.Enabled = false
	self._highlight.Adornee = nil
	for _, c in self._path do
		c.root.Visible = false
	end
	for tag in self._focus do
		CarTags.setFocus(tag, 0)
	end
	table.clear(self._focus)
end

-- every dive since the run began (the last 60): the car the ring showed, the car pressed on, its distance and where it landed
function HopGuide.getDiveLog(self: HopGuide): { DiveRecord }
	return self._log
end

function HopGuide.getDebugState(self: HopGuide): { [string]: any }
	return {
		shown = if self._shown then self._shown.index else nil,
		ringEnabled = self._gui.Enabled,
		alpha = self._alpha,
		aim = self._aim,
		diameter = self._diameter,
		pathChevrons = self._pathShown,
		highlight = self._highlight.Enabled,
		swings = self._swings,
		switchMargin = HopGuide.SWITCH_MARGIN,
		switchDwell = HopGuide.SWITCH_DWELL,
		shownFrames = self._shownFrames,
		unreachableFrames = self._unreachable,
		visibleFrames = self._visFrames,
		visibleMs = if self._visFrames > 0 then self._visDt / self._visFrames * 1000 else 0,
		visibleMaxMs = self._visDtMax * 1000,
		idleMs = if self._idleFrames > 0 then self._idleDt / self._idleFrames * 1000 else 0,
		-- this module's own script time per call (update and updateScreen each count), milliseconds
		cpuMeanMs = if self._cpuFrames > 0 then self._cpuSum / self._cpuFrames else 0,
		cpuMaxMs = self._cpuMax,
		dives = self._dives,
		divesLanded = self._landed,
		divesOnShownCar = self._matched,
	}
end

function HopGuide.destroy(self: HopGuide)
	for tag in self._focus do
		CarTags.setFocus(tag, 0)
	end
	self._trove:Destroy()
end

return HopGuide
