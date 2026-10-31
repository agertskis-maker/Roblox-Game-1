--!strict
-- The Speedway level-up reveal (Lane 3, client presentation only), about 1.5 seconds: a puff of
-- construction dust at each new piece, the new pieces drop into place with a springy bounce
-- (staggered), replaced pieces fade away, a short confetti burst and the banner "RACEWAY LEVEL 5!"
-- in the HUD style (Reveal.banner; vault/design/ui/raceway-level-banner.md, approved 2026-10-29). Nothing blocks input; a falling piece
-- does not collide until it lands (then a visitor standing inside it is lifted on top), and a
-- new reveal, a reset or a downgrade first snaps any running one to its end. Reduce Motion:
-- pieces fade in where they stand, no drop, no confetti, the banner fades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
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

-- The level-up banner (vault/design/ui/raceway-level-banner.md, approved by Adam 2026-10-29): exactly
-- "RACEWAY LEVEL N!" (no level name), cream Fredoka One with a navy outline on the navy pill with the
-- coral edge, the number in yellow, 14 % down the screen. One line wherever it fits in the safe area;
-- two lines ("RACEWAY" / "LEVEL N!") only when it does not, and 24 instead of 36 only when two lines
-- at 36 still do not fit. 0.18 s in (fade, settling from 0.94 to 1.0, no overshoot), 1.10 s hold,
-- 0.22 s out. Reduce Motion: opacity only. At most one banner: a new request cancels the running
-- tweens and the pending hold and shows only the latest level; Reveal.cancelBanner() fades it out
-- (a level-down or an owner change). It never takes input.
Reveal.BannerIn, Reveal.BannerHold, Reveal.BannerOut = 0.18, 1.1, 0.22

local NAVY = Color3.fromRGB(36, 58, 98)
local CREAM = Color3.fromRGB(255, 246, 224)
local YELLOW = Color3.fromRGB(250, 206, 70)
local CORAL = Color3.fromRGB(244, 127, 112)
local OUTLINE = Color3.fromRGB(20, 27, 51)
local PAD_X, PAD_TOP, PAD_BOTTOM = 28, 10, 12
local MARGIN = 16 -- the least screen margin either side of the pill (Tokens.Space.L)

type Banner = {
	screen: ScreenGui,
	group: CanvasGroup,
	settle: UIScale,
	tweens: { Tween },
	hold: thread?,
	token: number,
}
local banner: Banner? = nil
local bannerToken = 0

local function stopTweens(b: Banner)
	for _, t in b.tweens do
		t:Cancel()
	end
	table.clear(b.tweens)
	if b.hold then
		pcall(task.cancel, b.hold)
		b.hold = nil
	end
end

local function textWidth(text: string, size: number): number
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = Tokens.font()
		params.Size = size
		params.Width = 10000
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok and typeof(bounds) == "Vector2" then
		return bounds.X
	end
	return #text * 0.62 * size -- the spec's estimate when the measurement fails
end

local function word(parent: Instance, text: string, size: number, colour: Color3, order: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Word"
	t.LayoutOrder = order
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.BackgroundTransparency = 1
	t.FontFace = Tokens.font()
	t.TextSize = size
	t.TextColor3 = colour
	t.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function row(parent: Instance, gap: number, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.LayoutOrder = order
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	list.Parent = f
	f.Parent = parent
	return f
end

-- "LEVEL" + "5!" (the number yellow, the mark cream, no gap between them)
local function levelWords(parent: Instance, level: number, size: number, order: number, withRaceway: boolean)
	local r = row(parent, math.floor(size * 0.28), order)
	if withRaceway then
		word(r, "RACEWAY", size, CREAM, 1)
	end
	word(r, "LEVEL", size, CREAM, 2)
	local n = row(r, 0, 3)
	word(n, tostring(level), size, YELLOW, 1)
	word(n, "!", size, CREAM, 2)
end

-- Chooses the layout for the safe width (design px): one line at 36, two lines at 36, two lines at 24.
function Reveal.bannerLayout(level: number, safeWidth: number): (number, number)
	local limit = safeWidth - 2 * PAD_X - 2 * MARGIN
	local display, value = Tokens.TextSize.Display, Tokens.TextSize.Value
	if textWidth(string.format("RACEWAY LEVEL %d!", level), display) <= limit then
		return 1, display
	end
	local wider = math.max(textWidth("RACEWAY", display), textWidth(string.format("LEVEL %d!", level), display))
	if wider <= limit then
		return 2, display
	end
	return 2, value
end

function Reveal.cancelBanner()
	bannerToken += 1
	local b = banner
	if not b then
		return
	end
	stopTweens(b)
	local token = bannerToken
	local out = TweenService:Create(b.group, TweenInfo.new(Reveal.BannerOut), { GroupTransparency = 1 })
	table.insert(b.tweens, out)
	out:Play()
	out.Completed:Once(function()
		if bannerToken == token and banner == b then
			b.screen:Destroy()
			banner = nil
		end
	end)
end

-- Shows "RACEWAY LEVEL <level>!" (only the latest request is ever shown).
function Reveal.banner(level: number, calm: boolean)
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	bannerToken += 1
	local token = bannerToken
	local b = banner
	if b then
		stopTweens(b)
		b.screen:Destroy()
		banner = nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "Lane3SpeedwayBanner"
	screen.ResetOnSpawn = false
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.DisplayOrder = 20
	screen.Parent = gui
	local camera = workspace.CurrentCamera
	local scaleValue = Tokens.uiScaleFor(if camera then camera.ViewportSize else Vector2.new(1920, 1080))
	local safe = screen.AbsoluteSize.X
	if safe <= 0 and camera then
		safe = camera.ViewportSize.X
	end
	local lines, size = Reveal.bannerLayout(level, safe / scaleValue)
	if token ~= bannerToken then
		screen:Destroy() -- a newer request arrived while measuring
		return
	end

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale(0.5, 0.14)
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.BackgroundTransparency = 1
	holder.Active = false
	local rootScale = Instance.new("UIScale")
	rootScale.Scale = scaleValue
	rootScale.Parent = holder
	local group = Instance.new("CanvasGroup")
	group.Name = "Fade"
	group.AutomaticSize = Enum.AutomaticSize.XY
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = holder
	local settle = Instance.new("UIScale")
	settle.Scale = if calm then 1 else 0.94
	settle.Parent = group
	-- the coral border is drawn outside the pill: keep a 4 px margin so the canvas never clips it
	local margin = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(margin :: any)[side] = UDim.new(0, 4)
	end
	margin.Parent = group
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.BackgroundColor3 = NAVY
	pill.BackgroundTransparency = 0.05
	pill.Parent = group
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.Color = CORAL
	edge.Thickness = 4
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, PAD_X), UDim.new(0, PAD_X)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, PAD_TOP), UDim.new(0, PAD_BOTTOM)
	pad.Parent = pill
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = pill
	if lines == 1 then
		levelWords(pill, level, size, 1, true)
	else
		local top = row(pill, 0, 1)
		word(top, "RACEWAY", size, CREAM, 1)
		levelWords(pill, level, size, 2, false)
	end
	holder.Parent = screen
	screen:SetAttribute("Level", level)
	screen:SetAttribute("Lines", lines)
	screen:SetAttribute("TextSize", size)

	local made: Banner = { screen = screen, group = group, settle = settle, tweens = {}, hold = nil, token = token }
	banner = made
	local fadeIn = TweenService:Create(
		group,
		TweenInfo.new(Reveal.BannerIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 0 }
	)
	table.insert(made.tweens, fadeIn)
	fadeIn:Play()
	if not calm then
		local grow = TweenService:Create(
			settle,
			TweenInfo.new(Reveal.BannerIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		table.insert(made.tweens, grow)
		grow:Play()
	end
	made.hold = task.delay(Reveal.BannerIn + Reveal.BannerHold, function()
		made.hold = nil
		if banner ~= made then
			return
		end
		local out = TweenService:Create(
			group,
			TweenInfo.new(Reveal.BannerOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ GroupTransparency = 1 }
		)
		table.insert(made.tweens, out)
		out:Play()
		out.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and banner == made then
				screen:Destroy()
				banner = nil
			end
		end)
	end)
end

-- For Studio tests: the live banner's level, line count and text size (nil when none is showing).
function Reveal.bannerState(): { [string]: any }?
	local b = banner
	if not b then
		return nil
	end
	return {
		level = b.screen:GetAttribute("Level"),
		lines = b.screen:GetAttribute("Lines"),
		textSize = b.screen:GetAttribute("TextSize"),
		screens = (function()
			local n = 0
			for _, c in (b.screen.Parent :: Instance):GetChildren() do
				if c.Name == "Lane3SpeedwayBanner" then
					n += 1
				end
			end
			return n
		end)(),
	}
end

return Reveal
