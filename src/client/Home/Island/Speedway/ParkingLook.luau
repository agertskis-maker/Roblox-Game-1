--!strict
-- Raceway parking spots on this client (Lane 3, presentation only; Raceway round 2, Adam
-- 2026-10-29). Draws each plot's owned bays, the next bay's barrier and the parking sign from the
-- plot's owned spot count (Shared/Island/Speedway/Parking), and plays the short unlock reveal when
-- the count goes up by one (about 0.9 s: the old barrier lifts over 0.25 s, the new bay's cream lines
-- fade in over 0.30 s, 8 to 12 small confetti pieces gone within 0.6 s, then the barrier appears at
-- the next bay). Reduce Motion: a short fade, no confetti. A count comes from, in order:
--   in Studio only, the LocalPlayer attribute "Lane3ParkingPreviewSpots_PlotNN" (the preview),
--   the plot's "ParkingSpots" attribute (the proposed Lane 2 contract: the server sets it),
--   else the 2 every plot starts with (Adam's decision).
-- Nothing here prices, pays, saves or sends anything to the server. The Raceway level never
-- changes the spot count and the spot count never changes the level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Speedway = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("Speedway")
local Ctx = require(Speedway:WaitForChild("Ctx"))
local Parking = require(Speedway:WaitForChild("Parking"))
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local ParkingLook = {}

ParkingLook.LiftSeconds = 0.25
ParkingLook.LineSeconds = 0.3
ParkingLook.Seconds = 1.05 -- the unlock (about 0.9 s) and the next barrier's 0.15 s fade-in
ParkingLook.CalmSeconds = 0.15
ParkingLook.LiftAngle = math.rad(80)
local CONFETTI = { Color3.fromRGB(244, 236, 214), Color3.fromRGB(34, 138, 146), Color3.fromRGB(244, 127, 112) }

type Run = { connection: RBXScriptConnection?, temp: { Instance }, built: Parking.Built }
type State = { built: Parking.Built?, run: Run?, busy: boolean, want: number?, wantReveal: boolean }

local states: { [Model]: State } = {}

function ParkingLook.resolve(plot: Model, index: number): number
	if RunService:IsStudio() then
		local own = Players.LocalPlayer:GetAttribute(string.format("Lane3ParkingPreviewSpots_Plot%02d", index))
		if type(own) == "number" then
			return Parking.clamp(own)
		end
	end
	local real = plot:GetAttribute("ParkingSpots")
	if type(real) == "number" then
		return Parking.clamp(real)
	end
	return Parking.StartSpots
end

local function fade(parts: { BasePart }, value: number)
	for _, p in parts do
		p.LocalTransparencyModifier = value
	end
end

local function partsOf(folder: Instance?): { BasePart }
	local out = {}
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- Ends a running reveal at its final state.
local function finish(state: State)
	local run = state.run
	if not run then
		return
	end
	state.run = nil
	if run.connection then
		run.connection:Disconnect()
	end
	for _, t in run.temp do
		t:Destroy()
	end
	fade(partsOf(run.built.folder), 0)
end

local function confetti(at: Vector3, fx: Instance)
	local host = Instance.new("Part")
	host.Name = "ParkingConfetti"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one * 0.2
	host.CFrame = CFrame.new(at)
	host.Parent = fx
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.45, 0.6)
	e.Speed = NumberRange.new(7, 11)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 2
	e.Size = NumberSequence.new(0.28, 0.2)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-240, 240)
	e.LightInfluence = 1
	e.Parent = host
	local count = 10 -- 8 to 12 pieces in all, a third per colour
	for i, colour in CONFETTI do
		e.Color = ColorSequence.new(colour)
		e:Emit(if i == 1 then count - 2 * math.floor(count / 3) else math.floor(count / 3))
	end
	task.delay(0.7, function()
		host:Destroy()
	end)
end

local SIGN_CREAM = Color3.fromRGB(255, 246, 224)
local SIGN_OUTLINE = Color3.fromRGB(20, 27, 51)

local function signText(parent: Instance, text: string, rect: { number }, size: number, outline: number?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(rect[1], rect[2])
	t.Size = UDim2.fromOffset(rect[3], rect[4])
	t.FontFace = Tokens.font()
	t.Text = text
	t.TextColor3 = SIGN_CREAM
	t.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = t
	if outline then
		local s = Instance.new("UIStroke")
		s.Color = SIGN_OUTLINE
		s.Thickness = outline
		s.Parent = t
	end
	t.Parent = parent
	return t
end

local function faceGui(part: BasePart, pixelsPerStud: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pixelsPerStud
	g.LightInfluence = 1
	g.MaxDistance = 300
	g.Parent = part
	return g
end

-- The sign's teal inset (the mesh) gets the cream "P" with a small plus, PARKING and the live count;
-- the barrier's navy plaque gets ADD SPOT (vault/design/ui/raceway-parking-panel.md, approved
-- 2026-10-29). Live SurfaceGui text, never baked into a mesh.
local function decorate(built: Parking.Built)
	local face = built.signFace
	if face then
		-- 2.8 x 2.0 studs at 50 px per stud: 140 x 100 px
		local g = faceGui(face, 50)
		signText(g, "P", { 6, 4, 34, 40 }, 36, 1.5)
		local plus = Instance.new("Frame")
		plus.BackgroundTransparency = 1
		plus.Position = UDim2.fromOffset(36, 8)
		plus.Size = UDim2.fromOffset(12, 12)
		plus.Parent = g
		for _, size in { Vector2.new(12, 3), Vector2.new(3, 12) } do
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.Size = UDim2.fromOffset(size.X, size.Y)
			bar.BackgroundColor3 = SIGN_CREAM
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = bar
			bar.Parent = plus
		end
		signText(g, "PARKING", { 50, 8, 86, 32 }, 17, 1.5)
		local count = signText(g, string.format("%d / %d", built.spots, Parking.MaxSpots), { 0, 46, 140, 44 }, 34, 1.5)
		count.Name = "OwnedCount"
	end
	local plaque = built.plaque
	if plaque then
		-- 1.8 x 0.5 studs at 100 px per stud
		signText(faceGui(plaque, 100), "ADD SPOT", { 0, 6, 180, 38 }, 22)
	end
end

-- Builds (or rebuilds) the plot's parking look for `spots`. `reveal` plays the unlock when the
-- count went up by exactly one from what is shown now.
local function apply(
	plot: Model,
	index: number,
	bearing: number,
	spots: number,
	reveal: boolean,
	calm: boolean,
	fx: Instance
)
	local state = states[plot]
	if not state then
		state = { built = nil, run = nil, busy = false, want = nil, wantReveal = false }
		states[plot] = state
	end
	finish(state)
	local old = state.built
	if old and old.folder.Parent and old.spots == spots then
		return
	end
	local oldArm = old and old.arm
	local oldBase = old and old.armBase
	local revealing = reveal and old ~= nil and spots == old.spots + 1 and oldArm ~= nil and oldBase ~= nil
	-- the old barrier lives on (as a copy) only for the reveal
	local liftArm: BasePart? = nil
	local liftPlaque: BasePart? = nil
	if revealing and oldArm then
		liftArm = oldArm:Clone()
		local plaque = old and old.plaque
		if plaque then
			liftPlaque = plaque:Clone()
		end
	end
	local ctx = Ctx.new(plot, index, bearing, 1, "")
	local built = Parking.build(plot, ctx, spots)
	decorate(built)
	state.built = built
	if not revealing then
		return
	end
	local fresh = built.lines[spots] or {}
	local nextParts = partsOf(built.folder:FindFirstChild("NextBay"))
	local temp: { Instance } = {}
	local arm = liftArm :: BasePart
	arm.Parent = fx
	table.insert(temp, arm)
	if liftPlaque then
		liftPlaque.Parent = fx
		table.insert(temp, liftPlaque)
	end
	local base = oldBase :: CFrame
	local armRest = base:ToObjectSpace(arm.CFrame)
	local plaqueRest = if liftPlaque then base:ToObjectSpace(liftPlaque.CFrame) else nil
	-- the side lines grow from the bay mouth to the back; the back line fades in
	type Grow = { part: BasePart, cframe: CFrame, size: Vector3, mouth: Vector3 }
	local grows: { Grow } = {}
	local faders: { BasePart } = {}
	for i, p in fresh do
		if i <= 2 and not calm then
			-- the slab looks from the back toward the mouth (Parking.lines)
			table.insert(grows, {
				part = p,
				cframe = p.CFrame,
				size = p.Size,
				mouth = p.CFrame.Position + p.CFrame.LookVector * (p.Size.Z / 2),
			})
			p.LocalTransparencyModifier = 1
		else
			table.insert(faders, p)
		end
	end
	fade(faders, 1)
	fade(nextParts, 1)
	if calm then
		arm.LocalTransparencyModifier = 1 -- hidden at once, no pivot
		if liftPlaque then
			liftPlaque:Destroy()
			liftPlaque = nil
		end
	else
		local mid = Vector3.zero
		for _, p in fresh do
			mid += p.Position
		end
		if #fresh > 0 then
			local at = mid / #fresh + Vector3.yAxis * 1.5
			task.delay(0.25, function()
				if state.run and state.run.built == built then
					confetti(at, fx)
				end
			end)
		end
	end
	local started = os.clock()
	local run: Run = { connection = nil, temp = temp, built = built }
	state.run = run
	local total = if calm then ParkingLook.CalmSeconds else ParkingLook.Seconds
	run.connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if calm then
			-- the lines and the next barrier switch in a short fade, nothing moves
			local x = math.clamp(t / total, 0, 1)
			fade(faders, 1 - x)
			fade(nextParts, 1 - x)
		else
			-- lift about 80 degrees (0 to 0.25 s), fade the lifted arm (0.25 to 0.45), lines grow (0.25 to
			-- 0.55), the next barrier fades in at the next bay (0.9 to 1.05)
			local lift = math.clamp(t / ParkingLook.LiftSeconds, 0, 1)
			local eased = if lift < 0.5 then 2 * lift * lift else 1 - (-2 * lift + 2) ^ 2 / 2
			local turn = base * CFrame.Angles(0, 0, eased * ParkingLook.LiftAngle)
			arm.CFrame = turn * armRest
			arm.LocalTransparencyModifier = math.clamp((t - 0.25) / 0.2, 0, 1)
			if liftPlaque and plaqueRest then
				liftPlaque.CFrame = turn * plaqueRest
			end
			local g = math.clamp((t - 0.25) / ParkingLook.LineSeconds, 0, 1)
			local grown = 1 - (1 - g) ^ 2
			for _, item in grows do
				local len = math.max(item.size.Z * grown, 0.01)
				item.part.Size = Vector3.new(item.size.X, item.size.Y, len)
				item.part.CFrame = item.cframe
					+ (item.mouth - item.cframe.LookVector * (len / 2) - item.cframe.Position)
				item.part.LocalTransparencyModifier = if g > 0 then 0 else 1
			end
			fade(faders, 1 - g)
			fade(nextParts, 1 - math.clamp((t - 0.9) / 0.15, 0, 1))
		end
		if t >= total then
			finish(state)
		end
	end)
end

-- Refreshes one plot (one build at a time per plot; a change that arrives during a build is applied
-- right after it, so the last count always wins).
function ParkingLook.refresh(plot: Model, index: number, bearing: number, reveal: boolean, calm: boolean, fx: Instance)
	local state = states[plot]
	if not state then
		state = { built = nil, run = nil, busy = false, want = nil, wantReveal = false }
		states[plot] = state
	end
	if state.busy then
		state.want = ParkingLook.resolve(plot, index)
		state.wantReveal = reveal
		return
	end
	state.busy = true
	local ok, err = pcall(apply, plot, index, bearing, ParkingLook.resolve(plot, index), reveal, calm, fx)
	while ok and state.want ~= nil and plot.Parent do
		state.want = nil
		ok, err = pcall(apply, plot, index, bearing, ParkingLook.resolve(plot, index), state.wantReveal, calm, fx)
	end
	state.busy = false
	if not ok then
		warn("Raceway parking: " .. tostring(err))
	end
end

function ParkingLook.built(plot: Model): Parking.Built?
	local state = states[plot]
	return state and state.built
end

function ParkingLook.revealing(plot: Model): boolean
	local state = states[plot]
	return state ~= nil and state.run ~= nil
end

function ParkingLook.forget(plot: Model)
	local state = states[plot]
	if state then
		finish(state)
		if state.built and state.built.folder then
			state.built.folder:Destroy()
		end
	end
	states[plot] = nil
end

return ParkingLook
