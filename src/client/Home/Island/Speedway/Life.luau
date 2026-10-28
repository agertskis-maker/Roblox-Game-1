--!strict
-- Speedway life (Lane 3, client presentation only): rigid figures and props animated in code.
--   fans          bob gently; clap when a car finishes; stand up and wave for a Rare or rarer car
--   flag official raises and waves the checkered flag on every finish crossing
--   mechanic      turns a wrench
--   blimp         circles slowly overhead
--   start lights  count down each lap; the gantry lights pulse on each finish; the lap board counts
--   Legendary     confetti cannons and soft fireworks at level 12
--   Lap Pay cue   a small "LAP PAY / PREVIEW" pop over the car as it crosses (no amount)
-- Only near plots animate (SpeedwayLooks switches far plots to their still silhouette).
-- Celebrations are local to the plot, bounded in time and coalesced: a celebration already
-- running is extended, never stacked. Reduce Motion: slow bob only, the flag raised and held
-- instead of waved, no stand-up bounce, lights steady, confetti and fireworks replaced by a soft
-- sparkle, the Lap Pay cue fades in place. The crossings come from the preview clock
-- (LappingPreview.Crossed); production would use Lane 2's Lap Pay event instead.

local RunService = game:GetService("RunService")

local Calm = require(script.Parent.Calm)

local Life = {}

type Figure = {
	model: Model,
	kind: string,
	base: CFrame,
	bodyRest: CFrame,
	parts: { { part: BasePart, rest: CFrame, pivot: Vector3? } },
	phase: number,
}
type PlotLife = {
	plot: Model,
	level: number,
	active: boolean,
	figures: { Figure },
	lamps: { BasePart },
	gantry: { BasePart },
	lapBoards: { TextLabel },
	cannons: { BasePart },
	racks: { BasePart },
	clapUntil: number,
	cheerUntil: number,
	waveAt: number,
	celebrateAt: number,
	laps: number,
}

local plots: { [Model]: PlotLife } = {}
local fxFolder: Instance? = nil

local LAMP_OFF = Color3.fromRGB(60, 64, 76)
local LAMP_RED = Color3.fromRGB(240, 70, 60)
local LAMP_GREEN = Color3.fromRGB(80, 220, 120)

function Life.setFx(folder: Instance)
	fxFolder = folder
end

local function collect(plot: Model): PlotLife
	local existing = plots[plot]
	local pl: PlotLife = existing
		or {
			plot = plot,
			level = 0,
			active = false,
			figures = {},
			lamps = {},
			gantry = {},
			lapBoards = {},
			cannons = {},
			racks = {},
			clapUntil = 0,
			cheerUntil = 0,
			waveAt = -100,
			celebrateAt = -100,
			laps = 0,
		}
	table.clear(pl.figures)
	table.clear(pl.lamps)
	table.clear(pl.gantry)
	table.clear(pl.lapBoards)
	table.clear(pl.cannons)
	table.clear(pl.racks)
	local root = plot:FindFirstChild("SpeedwayLook")
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Figure") and d.PrimaryPart then
				local kind = d:GetAttribute("Figure") :: string
				local base = d:GetAttribute("BaseCFrame") :: CFrame
				local bodyRest = (d.PrimaryPart :: BasePart):GetAttribute("Rest")
				local fig: Figure = {
					model = d,
					kind = kind,
					base = base,
					bodyRest = if typeof(bodyRest) == "CFrame" then bodyRest else CFrame.identity,
					parts = {},
					phase = (d:GetAttribute("Phase") or 0) :: number,
				}
				for _, p in d:GetChildren() do
					if p:IsA("BasePart") and p ~= d.PrimaryPart then
						local rest = p:GetAttribute("Rest")
						local pivot = p:GetAttribute("Shoulder")
						table.insert(fig.parts, {
							part = p,
							rest = if typeof(rest) == "CFrame" then rest else base:ToObjectSpace(p.CFrame),
							pivot = if typeof(pivot) == "Vector3" then pivot else nil,
						})
					end
				end
				table.insert(pl.figures, fig)
			elseif d:IsA("BasePart") then
				if d:GetAttribute("StartLamp") then
					table.insert(pl.lamps, d)
				elseif d:GetAttribute("GantryLights") then
					table.insert(pl.gantry, d)
				elseif d:GetAttribute("ConfettiCannon") then
					table.insert(pl.cannons, d)
				elseif d:GetAttribute("FireworkRack") then
					table.insert(pl.racks, d)
				elseif d:GetAttribute("LapCounter") then
					local t = d:FindFirstChild("LapCount", true)
					if t and t:IsA("TextLabel") then
						table.insert(pl.lapBoards, t)
					end
				end
			end
		end
	end
	table.sort(pl.lamps, function(a, b)
		return (a:GetAttribute("StartLamp") :: number) < (b:GetAttribute("StartLamp") :: number)
	end)
	plots[plot] = pl
	return pl
end

-- Re-reads the figures and props of `plot` after its look changed.
function Life.rescan(plot: Model, level: number)
	local pl = collect(plot)
	pl.level = level
end

function Life.setActive(plot: Model, active: boolean)
	local pl = plots[plot]
	if pl then
		pl.active = active
	end
end

function Life.forget(plot: Model)
	plots[plot] = nil
end

local function emitter(at: CFrame, colours: { Color3 }, props: { [string]: any }, count: number)
	if not fxFolder then
		return
	end
	local p = Instance.new("Part")
	p.Name = "SpeedwayFx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.5
	p.CFrame = at
	p.Parent = fxFolder
	for _, c in colours do
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(c)
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Enabled = false
		e.Parent = p
		e:Emit(count)
	end
	task.delay(3, function()
		p:Destroy()
	end)
end

local PARTY = {
	Color3.fromRGB(244, 127, 112),
	Color3.fromRGB(250, 206, 70),
	Color3.fromRGB(128, 216, 189),
	Color3.fromRGB(80, 140, 230),
}

local function celebrate(pl: PlotLife, calm: boolean)
	for _, c in pl.cannons do
		local mouth = c.CFrame * CFrame.new(0, c.Size.Y * 0.3, c.Size.Z * 0.3)
		if calm then
			emitter(mouth, { Color3.fromRGB(255, 240, 200) }, {
				Size = NumberSequence.new(0.3),
				Lifetime = NumberRange.new(1.2, 1.6),
				Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(60, 60),
				LightEmission = 0.4,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.6),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, 6)
		else
			emitter(mouth * CFrame.Angles(math.rad(45), 0, 0), PARTY, {
				Size = NumberSequence.new(0.3),
				Lifetime = NumberRange.new(1.2, 1.6),
				Speed = NumberRange.new(16, 24),
				SpreadAngle = Vector2.new(18, 18),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -20, 0),
				Drag = 1.2,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-240, 240),
			}, 12)
		end
	end
	if calm then
		return
	end
	-- soft fireworks: a slow rising spark that opens into a gentle bloom (no flash)
	for i, r in pl.racks do
		task.delay(0.25 * i, function()
			local top = r.Position + Vector3.yAxis * 28
			emitter(CFrame.new(top), { PARTY[(i % #PARTY) + 1], Color3.fromRGB(255, 246, 224) }, {
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) }),
				Lifetime = NumberRange.new(1, 1.4),
				Speed = NumberRange.new(10, 14),
				SpreadAngle = Vector2.new(180, 180),
				Drag = 2.5,
				Acceleration = Vector3.new(0, -4, 0),
				LightEmission = 0.7,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, 24)
		end)
	end
end

-- A small pop over the crossing car: "LAP PAY" and PREVIEW (no amount; Lane 2 owns Lap Pay).
local function lapPayCue(car: BasePart, calm: boolean)
	if not fxFolder then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "LapPayCue"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(car.Position + Vector3.yAxis * 4)
	anchor.Parent = fxFolder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 56)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 220
	bb.LightInfluence = 0
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.62)
	t.FontFace = Font.fromName("FredokaOne")
	t.TextSize = 30
	t.TextColor3 = Color3.fromRGB(250, 206, 70)
	t.Text = "LAP PAY"
	t.Parent = bb
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(20, 27, 51)
	s.Thickness = 3
	s.Parent = t
	local tag = Instance.new("TextLabel")
	tag.BackgroundTransparency = 1
	tag.Position = UDim2.fromScale(0, 0.62)
	tag.Size = UDim2.fromScale(1, 0.38)
	tag.FontFace = Font.fromName("FredokaOne")
	tag.TextSize = 16
	tag.TextColor3 = Color3.fromRGB(128, 216, 189)
	tag.Text = "PREVIEW"
	tag.Parent = bb
	local s2 = Instance.new("UIStroke")
	s2.Color = Color3.fromRGB(20, 27, 51)
	s2.Thickness = 2
	s2.Parent = tag
	local start = os.clock()
	local origin = anchor.CFrame
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local x = (os.clock() - start) / 1.0
		if x >= 1 or not anchor.Parent then
			conn:Disconnect()
			anchor:Destroy()
			return
		end
		if not calm then
			anchor.CFrame = origin + Vector3.yAxis * (3 * x)
		end
		local fade = if x > 0.6 then (x - 0.6) / 0.4 else 0
		t.TextTransparency, tag.TextTransparency = fade, fade
		s.Transparency, s2.Transparency = fade, fade
	end)
end

-- A finish crossing on `plot` by `car` (rarity from the preview fixture).
function Life.onCrossed(plot: Model, car: BasePart?, rarity: string, carIndex: number)
	local pl = plots[plot]
	if not pl or not pl.active then
		return
	end
	local now = os.clock()
	local calm = Calm()
	pl.waveAt = now
	pl.clapUntil = math.max(pl.clapUntil, now + 1.2)
	if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then
		pl.cheerUntil = math.max(pl.cheerUntil, now + 2.4)
	end
	if carIndex == 1 then
		pl.laps += 1
		for _, b in pl.lapBoards do
			b.Text = "LAP " .. pl.laps
		end
	end
	if rarity == "Legendary" and pl.level >= 12 and now - pl.celebrateAt > 3 then
		pl.celebrateAt = now
		celebrate(pl, calm)
	end
	if car then
		lapPayCue(car, calm)
	end
end

local function shoulderTurn(base: CFrame, item: { part: BasePart, rest: CFrame, pivot: Vector3? }, rot: CFrame): CFrame
	local pivot = item.pivot or Vector3.zero
	return base * CFrame.new(pivot) * rot * CFrame.new(-pivot) * item.rest
end

local function animate(pl: PlotLife, now: number, calm: boolean, parts: { BasePart }, cframes: { CFrame })
	local clapping = now < pl.clapUntil
	local cheering = now < pl.cheerUntil
	for _, fig in pl.figures do
		local base = fig.base
		if fig.kind == "Fan" then
			local bob = if calm then 0.04 * math.sin(now * 0.8 + fig.phase) else 0.08 * math.sin(now * 2 + fig.phase)
			local rise = 0
			if cheering and not calm then
				rise = 0.7 * math.min(1, (pl.cheerUntil - now) * 3, (now - (pl.cheerUntil - 2.4)) * 4)
			end
			local body = base * CFrame.new(0, bob + math.max(0, rise), 0)
			table.insert(parts, fig.model.PrimaryPart :: BasePart)
			table.insert(cframes, body * fig.bodyRest)
			for i, item in fig.parts do
				local side = if item.part.Name == "ArmL" then 1 else -1
				local rot = CFrame.identity
				if cheering then
					local wave = if calm then 0 else 0.35 * math.sin(now * 9 + fig.phase + i)
					rot = CFrame.Angles(-2.7, 0, side * (0.25 + wave))
				elseif clapping and not calm then
					rot = CFrame.Angles(-1.1 - 0.25 * math.abs(math.sin(now * 14 + fig.phase)), 0, -side * 0.45)
				end
				table.insert(parts, item.part)
				table.insert(cframes, shoulderTurn(body, item, rot))
			end
		elseif fig.kind == "Official" then
			local t = now - pl.waveAt
			local lift, sway = 0, 0
			if t < 1.4 then
				local up = math.clamp(t / 0.25, 0, 1) * math.clamp((1.4 - t) / 0.3, 0, 1)
				lift = -2.75 * up
				sway = if calm then 0 else 0.5 * math.sin(t * 16) * up
			end
			table.insert(parts, fig.model.PrimaryPart :: BasePart)
			table.insert(cframes, base * fig.bodyRest)
			for _, item in fig.parts do
				table.insert(parts, item.part)
				table.insert(cframes, shoulderTurn(base, item, CFrame.Angles(lift, 0, sway)))
			end
		elseif fig.kind == "Mechanic" then
			table.insert(parts, fig.model.PrimaryPart :: BasePart)
			table.insert(cframes, base * fig.bodyRest)
			for _, item in fig.parts do
				local spin = CFrame.Angles(0, 0, now * (if calm then 1.2 else 5))
				table.insert(parts, item.part)
				table.insert(cframes, shoulderTurn(base, item, spin))
			end
		elseif fig.kind == "Blimp" then
			local centre = fig.model:GetAttribute("Centre") :: Vector3
			local radius = fig.model:GetAttribute("Radius") :: number
			local a = now * (2 * math.pi / (if calm then 120 else 70)) + fig.phase
			local pos = centre
				+ Vector3.new(math.cos(a), 0, math.sin(a)) * radius
				+ Vector3.yAxis * math.sin(now * 0.4) * 1.2
			local ahead = Vector3.new(-math.sin(a), 0, math.cos(a))
			-- the placing frame: the mesh nose (recipe -y) is the frame's +Z, so it looks backward
			local pose = CFrame.lookAt(pos, pos - ahead)
			table.insert(parts, fig.model.PrimaryPart :: BasePart)
			table.insert(cframes, pose * fig.bodyRest)
			for _, item in fig.parts do
				table.insert(parts, item.part)
				table.insert(cframes, pose * item.rest)
			end
		end
	end
	-- start lights: five reds one by one, then green, each lap (steady green when calm)
	if #pl.lamps > 0 then
		local x = (now % 15) / 15
		for k, lamp in pl.lamps do
			local colour = LAMP_OFF
			local glow = false
			if calm then
				colour, glow = LAMP_GREEN, false
			elseif x < 0.25 then
				if x > (k - 1) * 0.05 then
					colour, glow = LAMP_RED, true
				end
			elseif x < 0.35 then
				colour, glow = LAMP_GREEN, true
			end
			lamp.Color = colour
			lamp.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	for _, g in pl.gantry do
		local t = now - pl.waveAt
		local pulse = if t < 0.8 then (if calm then 0.5 + 0.2 * (1 - t / 0.8) else 0.15 + 0.6 * (t / 0.8)) else 0.5
		g.Transparency = math.clamp(pulse, 0, 0.9)
	end
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local calm = Calm()
	table.clear(parts)
	table.clear(cframes)
	for plot, pl in plots do
		if pl.active and plot.Parent then
			animate(pl, now, calm, parts, cframes)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-- Live animated counts for the performance table.
function Life.stats(): { [string]: number }
	local out = { plots = 0, activePlots = 0, figures = 0, animatedParts = 0 }
	for _, pl in plots do
		out.plots += 1
		if pl.active then
			out.activePlots += 1
			out.figures += #pl.figures
			for _, f in pl.figures do
				out.animatedParts += 1 + #f.parts
			end
		end
	end
	return out
end

return Life
