--!strict
-- The Speedway level-up reveal (Lane 3, client presentation only), about 1.5 seconds: a puff of
-- construction dust at each new piece, the new pieces drop into place with a springy bounce
-- (staggered), replaced pieces fade away, a short confetti burst and a banner
-- "SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!" in the HUD style. Nothing blocks input; a falling piece
-- does not collide until it lands (then a visitor standing inside it is lifted on top), and a
-- new reveal, a reset or a downgrade first snaps any running one to its end. Reduce Motion:
-- pieces fade in where they stand, no drop, no confetti, the banner fades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Reveal = {}

Reveal.Seconds = 1.5 -- Tunable
local DROP = 7 -- studs the pieces fall from (Tunable)
local STAGGER = 0.45 -- spread of start times across the pieces (Tunable)

type Item = { part: BasePart, final: CFrame, transparency: number, delay: number, collide: boolean }
type Run = {
	items: { Item },
	removed: { Folder },
	started: number,
	calm: boolean,
	connection: RBXScriptConnection?,
	done: boolean,
}

local runs: { [Model]: Run } = {}

local function finish(run: Run)
	if run.done then
		return
	end
	run.done = true
	if run.connection then
		run.connection:Disconnect()
	end
	for _, it in run.items do
		if it.part.Parent then
			it.part.CFrame = it.final
			it.part.LocalTransparencyModifier = 0
			if it.collide then
				it.part.CanCollide = true
			end
		end
	end
	for _, f in run.removed do
		f:Destroy()
	end
	-- a visitor caught inside a piece that just landed stands on top of it instead
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		for _, it in run.items do
			if it.collide and it.part.Parent then
				local p = it.part.CFrame:PointToObjectSpace(root.Position)
				local half = it.part.Size / 2
				if math.abs(p.X) < half.X + 1 and math.abs(p.Y) < half.Y + 2.5 and math.abs(p.Z) < half.Z + 1 then
					local top = it.part.Position.Y + it.part.Size.Magnitude / 2
					if root.Position.Y < top then
						character:PivotTo(character:GetPivot() + Vector3.yAxis * (top + 3 - root.Position.Y))
					end
				end
			end
		end
	end
end

-- Snaps a running reveal on `plot` to its end (call before any other change to the plot).
function Reveal.finish(plot: Model)
	local run = runs[plot]
	if run then
		finish(run)
		runs[plot] = nil
	end
end

-- True while a reveal is still running on `plot`.
function Reveal.active(plot: Model): boolean
	local run = runs[plot]
	return run ~= nil and not run.done
end

-- Spring-like ease out with one overshoot (back out), 0..1.
local function backOut(x: number): number
	local c1 = 1.9
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function burst(at: Vector3, colour: Color3, count: number, parent: Instance)
	local p = Instance.new("Part")
	p.Name = "RevealPuff"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(at)
	p.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(colour)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Enabled = false
	e.Parent = p
	e:Emit(count)
	task.delay(1.4, function()
		p:Destroy()
	end)
end

local CONFETTI = {
	Color3.fromRGB(244, 127, 112),
	Color3.fromRGB(250, 206, 70),
	Color3.fromRGB(128, 216, 189),
	Color3.fromRGB(80, 140, 230),
}

local function confetti(at: Vector3, parent: Instance)
	for _, c in CONFETTI do
		local p = Instance.new("Part")
		p.Name = "RevealConfetti"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.CFrame = CFrame.new(at)
		p.Parent = parent
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(c)
		e.Size = NumberSequence.new(0.35)
		e.Lifetime = NumberRange.new(1, 1.4)
		e.Speed = NumberRange.new(14, 24)
		e.SpreadAngle = Vector2.new(40, 40)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -22, 0)
		e.Drag = 1.5
		e.RotSpeed = NumberRange.new(-300, 300)
		e.Rotation = NumberRange.new(0, 360)
		e.Enabled = false
		e.Parent = p
		e:Emit(18)
		task.delay(1.6, function()
			p:Destroy()
		end)
	end
end

-- Plays the reveal for a level change on `plot` (Look.apply's change with keepRemoved). `fx` is
-- where transient effect parts go. Returns when the animation has been set up (it runs on).
function Reveal.play(plot: Model, added: { Folder }, removed: { Folder }, calm: boolean, fx: Instance)
	Reveal.finish(plot)
	local items: { Item } = {}
	local centres: { Vector3 } = {}
	for _, folder in added do
		local sum, n = Vector3.zero, 0
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(
					items,
					{ part = d, final = d.CFrame, transparency = d.Transparency, delay = 0, collide = d.CanCollide }
				)
				d.CanCollide = false
				sum += d.Position
				n += 1
			end
		end
		if n > 0 then
			table.insert(centres, sum / n)
		end
	end
	-- stagger: pieces nearer the ground first, so things build up
	local lo, hi = math.huge, -math.huge
	for _, it in items do
		lo, hi = math.min(lo, it.final.Y), math.max(hi, it.final.Y)
	end
	for i, it in items do
		local h = if hi > lo then (it.final.Y - lo) / (hi - lo) else 0
		it.delay = (h * 0.7 + ((i * 0.618) % 1) * 0.3) * STAGGER
		it.part.LocalTransparencyModifier = 1
		if not calm then
			it.part.CFrame = it.final + Vector3.yAxis * DROP
		end
	end
	for _, f in removed do
		for _, d in f:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(items, { part = d, final = d.CFrame, transparency = -1, delay = 0, collide = false })
			end
		end
	end
	if not calm then
		for _, c in centres do
			burst(c, Color3.fromRGB(226, 196, 150), 14, fx)
		end
		local mid = Vector3.zero
		for _, c in centres do
			mid += c
		end
		if #centres > 0 then
			confetti(mid / #centres + Vector3.yAxis * 6, fx)
		end
	end
	local run: Run =
		{ items = items, removed = removed, started = os.clock(), calm = calm, connection = nil, done = false }
	runs[plot] = run
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	run.connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - run.started
		table.clear(parts)
		table.clear(cframes)
		for _, it in run.items do
			if not it.part.Parent then
				continue
			end
			if it.transparency < 0 then
				-- a replaced piece: fades out over the first third
				it.part.LocalTransparencyModifier = math.clamp(t / (Reveal.Seconds / 3), 0, 1)
				continue
			end
			local span = Reveal.Seconds - STAGGER
			local x = math.clamp((t - it.delay) / span, 0, 1)
			it.part.LocalTransparencyModifier = 1 - math.clamp(x * 2.5, 0, 1)
			if not calm then
				table.insert(parts, it.part)
				table.insert(cframes, it.final + Vector3.yAxis * DROP * (1 - backOut(x)))
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if t >= Reveal.Seconds then
			finish(run)
			if runs[plot] == run then
				runs[plot] = nil
			end
		end
	end)
end

-- The HUD banner. Fredoka One at the Display size (Tokens), cream on a navy pill with a coral
-- edge; scales in with a bounce, holds, fades. Reduce Motion: fades in and out in place.
function Reveal.banner(text: string, calm: boolean)
	local player = Players.LocalPlayer
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local old = gui:FindFirstChild("Lane3SpeedwayBanner")
	if old then
		old:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "Lane3SpeedwayBanner"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 20
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.14)
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.BackgroundColor3 = Color3.fromRGB(36, 58, 98)
	pill.BackgroundTransparency = 0.05
	pill.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(244, 127, 112)
	edge.Thickness = 4
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 28)
	pad.PaddingRight = UDim.new(0, 28)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = pill
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundTransparency = 1
	label.FontFace = Tokens.font()
	label.TextSize = Tokens.TextSize.Display
	label.TextColor3 = Color3.fromRGB(255, 246, 224)
	label.Text = text
	label.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 27, 51)
	stroke.Thickness = 3
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = if calm then 1 else 0.6
	scale.Parent = pill
	local group = Instance.new("CanvasGroup")
	group.Name = "Fade"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.GroupTransparency = 1
	pill.Parent = group
	group.Parent = screen
	screen.Parent = gui
	TweenService:Create(group, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	if not calm then
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	task.delay(Reveal.Seconds + 1.2, function()
		if screen.Parent then
			local fade = TweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			screen:Destroy()
		end
	end)
end

return Reveal
