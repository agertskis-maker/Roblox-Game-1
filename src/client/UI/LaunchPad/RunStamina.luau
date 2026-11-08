--!strict
-- Stamina in the real run: the lightning bolts (Lane 3, Round 3; Adam: "so people can't have infinite runs"). One Stamina is spent
-- on each hop that really happens, a refused press spends nothing, and at zero there are no more hops, so the ride ends the run.
-- Lives in the beta from outside Brian R's files: his input calls run:requestHop(), so a field of that name on this run object goes
-- first and his method does the hop. Move the rule into his RunController when agreed.
--
-- Stamina Shop (Adam, 2026-11-05): every run starts with 5 Stamina (the tutorial run too) and each Stamina Shop level adds one, up
-- to 15 (EconomyPreview.staminaFor; the level is the server's BetaStaminaLevel attribute). The screen never shows more than five
-- bolts: a bolt's colour says what it holds. Yellow holds 1 Stamina, red holds 2 (a hop empties half of it), purple holds 3 (a hop
-- empties a third). A part-used bolt is drawn part full, drained from the top. The tier is picked from the run's maximum, so a
-- run never changes colour while it is played.
--
--   local s = RunStamina.attach(run, { max = n? })   s:value()   s:isOut()   s:refill(n)   s:destroy()
--   RunStamina.playerMax() -> number          the local player's Stamina per run, from the save's level
--   RunStamina.layout(max) -> (tier, bolts)   which tier a maximum uses and how many bolts it draws
--
-- Nothing is bought or saved here: a new run starts full. Effects (aura, glow behind each full bolt, twinkles, a shimmer, a burst
-- of sparks on each hop) stop under Reduce Motion; the bolts and their fill stay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = script.Parent.Parent.Prototype
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local StaminaBolt = require(Prototype.Run.StaminaBolt) :: any
local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
local EconomyPreview = require(ReplicatedStorage.Shared:WaitForChild("UI"):WaitForChild("EconomyPreview"))

local make = CarKit.make

local RunStamina = {}

RunStamina.Max = EconomyPreview.StaminaStart -- 5, Tunable (Launch Pad redesign B-01; Adam 2026-11-05)
RunStamina.ReviveRefill = 2 -- Tunable
RunStamina.TutorialMax = 5 -- Tunable. Adam, 2026-11-05: 5 bolts for every run by default, the tutorial run too (it was 8)
RunStamina.Slots = 5 -- never more bolts than this on screen

export type Tier = { per: number, colour: Color3, light: Color3, name: string }

RunStamina.Tiers = {
	{ per = 1, colour = Color3.fromRGB(255, 216, 50), light = Color3.fromRGB(255, 244, 170), name = "Yellow" },
	{ per = 2, colour = Color3.fromRGB(255, 64, 70), light = Color3.fromRGB(255, 176, 160), name = "Red" },
	{ per = 3, colour = Color3.fromRGB(176, 84, 255), light = Color3.fromRGB(228, 196, 255), name = "Purple" },
} :: { Tier }

local SPENT = Color3.fromRGB(60, 68, 92)
local WHITE = Color3.new(1, 1, 1)

function RunStamina.playerMax(): number
	return EconomyPreview.staminaFor(Players.LocalPlayer:GetAttribute(BetaConfig.StaminaAttribute) :: number?)
end

function RunStamina.layout(max: number): (Tier, number)
	local tier = RunStamina.Tiers[math.clamp(math.ceil(max / RunStamina.Slots), 1, #RunStamina.Tiers)]
	return tier, math.max(1, math.ceil(max / tier.per))
end

local function circle(parent: Instance, name: string, colour: Color3, transparency: number, z: number): Frame
	local f = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = colour,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent) :: Frame
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	return f
end

type Pip = { holder: Frame, clip: Frame, glow: Frame, height: number, fill: number }

function RunStamina.attach(run: any, options: { max: number? }?): { [string]: any }
	local max = math.max(1, math.floor(options and options.max or RunStamina.playerMax()))
	local value = max
	local tier, count = RunStamina.layout(max)
	local viewport = (workspace.CurrentCamera :: Camera).ViewportSize
	local phone = math.min(viewport.X, viewport.Y) < 500
	local gui = make("ScreenGui", {
		Name = "Lane3RunStamina",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
	}, Players.LocalPlayer:WaitForChild("PlayerGui")) :: ScreenGui
	local boltPx = if phone then 22 else 28
	local heroPx = if phone then 32 else 42
	local boardH = if phone then 58 else 72
	local step = boltPx * 0.8 + 6
	local pipsX = heroPx * 0.75 + 18
	local width = pipsX + step * RunStamina.Slots + 10
	local board = CarKit.board(gui, {
		size = UDim2.fromOffset(width, boardH),
		position = UDim2.new(0, if phone then 10 else 18, 0.5, 40),
		anchor = Vector2.new(0, 0.5),
		radius = 12,
		top = Color3.fromRGB(20, 26, 50):Lerp(tier.colour, 0.12),
		bottom = Color3.fromRGB(10, 14, 30),
		name = "Stamina",
	})
	-- a coloured aura round the board, in the tier's colour
	local aura = make(
		"UIStroke",
		{
			Name = "Aura",
			Color = tier.colour,
			Thickness = 2,
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
		make("Frame", {
			Name = "AuraRing",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-4, -4),
			Size = UDim2.new(1, 8, 1, 8),
			ZIndex = 2,
		}, board)
	) :: UIStroke
	make("UICorner", { CornerRadius = UDim.new(0, 15) }, aura.Parent :: Instance)

	-- the hero bolt, with a glow and (red and purple) a chip saying what one bolt holds
	local heroGlow = circle(board, "HeroGlow", tier.colour, 0.72, 3)
	heroGlow.Position = UDim2.new(0, 8 + heroPx * 0.36, 0.5, 0)
	heroGlow.Size = UDim2.fromOffset(heroPx * 1.25, heroPx * 1.25)
	local hero = StaminaBolt.new(board, { height = heroPx, colour = tier.colour, shine = true, crack = true })
	hero.root.AnchorPoint = Vector2.new(0, 0.5)
	hero.root.Position = UDim2.new(0, 8, 0.5, 0)
	hero.root.ZIndex = 4
	if tier.per > 1 then
		local chip = make("Frame", {
			Name = "TierChip",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 8 + heroPx * 0.62, 1, -10),
			Size = UDim2.fromOffset(26, 18),
			BackgroundColor3 = tier.colour,
			BorderSizePixel = 0,
			ZIndex = 8,
		}, board)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, chip)
		make("UIStroke", { Color = CarKit.Ink, Thickness = 2 }, chip)
		CarKit.text(chip, "x" .. tier.per, 14, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
			stroke = 1.5,
			z = 9,
			name = "Per",
		})
	end

	-- the pips: a spent bolt underneath, the coloured bolt over it in a clip frame that shrinks from the top
	local pips: { Pip } = {}
	for i = 1, count do
		local metricsW = StaminaBolt.metrics(boltPx, nil, 0.9)
		local holder = make("Frame", {
			Name = "Pip" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(metricsW, boltPx),
			Position = UDim2.fromOffset(pipsX + (i - 1) * step, (boardH - boltPx) / 2),
			ZIndex = 4,
		}, board) :: Frame
		local glow = circle(holder, "Glow", tier.colour, 0.7, 3)
		glow.Size = UDim2.fromOffset(boltPx * 1.15, boltPx * 1.15)
		local base = StaminaBolt.new(holder, { height = boltPx, colour = SPENT, slim = 0.9, z = 4 })
		base.root.Position = UDim2.fromOffset(0, 0)
		local clip = make("Frame", {
			Name = "Fill",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
		}, holder) :: Frame
		local lit = StaminaBolt.new(clip, { height = boltPx, colour = tier.colour, slim = 0.9, z = 5 })
		lit.root.AnchorPoint = Vector2.new(0, 1)
		lit.root.Position = UDim2.fromScale(0, 1)
		table.insert(pips, { holder = holder, clip = clip, glow = glow, height = boltPx, fill = 1 })
	end

	-- twinkles round the board and a shimmer that sweeps over the bolts
	local twinkles: { Frame } = {}
	for i = 1, 7 do
		local t = make("Frame", {
			Name = "Twinkle" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = tier.light,
			BorderSizePixel = 0,
			Rotation = 45,
			Size = UDim2.fromOffset(5, 5),
			ZIndex = 9,
		}, board) :: Frame
		table.insert(twinkles, t)
	end
	local sweep = make("Frame", {
		Name = "Shimmer",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(pipsX - 4, 4),
		Size = UDim2.new(1, -(pipsX + 2), 1, -8),
		ZIndex = 7,
	}, board) :: Frame
	local bar = make("Frame", {
		Name = "Bar",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 14, 1.6, 0),
		Position = UDim2.fromScale(-0.2, -0.3),
		Rotation = 20,
		ZIndex = 7,
	}, sweep) :: Frame
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, bar)

	local out = CarKit.title(gui, "OUT OF BOLTS!", if phone then 26 else 34, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromOffset(420, 44),
		position = UDim2.fromScale(0.5, 0.38),
		anchor = Vector2.new(0.5, 0.5),
		top = CarKit.Yellow,
		bottom = CarKit.Orange,
		z = 4,
		name = "Out",
	})
	out.Visible = false

	local function fillOf(i: number): number
		return math.clamp(value - (i - 1) * tier.per, 0, tier.per) / tier.per
	end

	local function draw(animate: boolean?)
		hero:setColour(if value > 0 then tier.colour else SPENT)
		hero:setCracked(value <= 0)
		heroGlow.Visible = value > 0
		for i, pip in pips do
			local f = fillOf(i)
			pip.fill = f
			local goal = UDim2.fromScale(1, f)
			if animate and not Motion.reduced() then
				Motion.tween(pip.clip, "fill", Motion.info(0.35, Enum.EasingStyle.Quad), { Size = goal })
			else
				pip.clip.Size = goal
			end
			pip.glow.Visible = f >= 1
		end
	end
	draw()

	-- a burst of sparks from the bolt a hop just drained, and a white flash over it
	local function burst(pip: Pip)
		if Motion.reduced() then
			return
		end
		local centre = pip.holder.Position + UDim2.fromOffset(pip.holder.Size.X.Offset / 2, pip.height / 2)
		for k = 1, 7 do
			local angle = (k / 7) * math.pi * 2 + math.random() * 0.6
			local dist = 16 + math.random() * 12
			local spark = make("Frame", {
				Name = "Spark",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = centre,
				Size = UDim2.fromOffset(5, 5),
				Rotation = 45,
				BackgroundColor3 = if k % 2 == 0 then WHITE else tier.light,
				BorderSizePixel = 0,
				ZIndex = 10,
			}, board) :: Frame
			Motion.tween(spark, "fly", Motion.info(0.45, Enum.EasingStyle.Quad), {
				Position = centre + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(2, 2),
			})
			task.delay(0.5, function()
				spark:Destroy()
			end)
		end
		local flash = circle(pip.holder, "Flash", WHITE, 0.2, 6)
		flash.Size = UDim2.fromOffset(pip.height * 0.6, pip.height * 0.6)
		Motion.tween(flash, "flash", Motion.info(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(pip.height * 1.6, pip.height * 1.6),
			BackgroundTransparency = 1,
		})
		task.delay(0.35, function()
			flash:Destroy()
		end)
	end

	local shownOut = 0
	local function refused()
		out.Visible = true
		shownOut += 1
		local token = shownOut
		if not Motion.reduced() then
			Motion.pop(board, 1.12)
		end
		task.delay(1.2, function()
			if token == shownOut then
				out.Visible = false
			end
		end)
	end

	-- one render loop for every effect; it does nothing under Reduce Motion
	local born = os.clock()
	local loop = RunService.RenderStepped:Connect(function()
		local reduced = Motion.reduced()
		sweep.Visible = not reduced
		for _, t in twinkles do
			t.Visible = not reduced and value > 0
		end
		if reduced then
			aura.Transparency = 0.35
			return
		end
		local now = os.clock() - born
		local pulse = (math.sin(now * 3) + 1) / 2
		local low = value > 0 and value <= tier.per
		aura.Transparency = 0.15 + 0.45 * (1 - pulse)
		aura.Thickness = 2 + pulse * (if low then 3 else 1.5)
		heroGlow.Size = UDim2.fromOffset(heroPx * (1.15 + 0.2 * pulse), heroPx * (1.15 + 0.2 * pulse))
		heroGlow.BackgroundTransparency = if low then 0.45 + 0.3 * (1 - pulse) else 0.7
		for i, pip in pips do
			local p = (math.sin(now * 3 + i * 0.7) + 1) / 2
			pip.glow.BackgroundTransparency = 0.62 + 0.25 * p
		end
		local size = board.AbsoluteSize
		for i, t in twinkles do
			-- each twinkle runs round the board's edge at its own pace and blinks
			local s = (now * 0.08 + i / #twinkles) % 1
			local per = 2 * (size.X + size.Y)
			local d = s * per
			local x, y
			if d < size.X then
				x, y = d, 0
			elseif d < size.X + size.Y then
				x, y = size.X, d - size.X
			elseif d < 2 * size.X + size.Y then
				x, y = size.X - (d - size.X - size.Y), size.Y
			else
				x, y = 0, size.Y - (d - 2 * size.X - size.Y)
			end
			t.Position = UDim2.fromOffset(x, y)
			local blink = (math.sin(now * 5 + i * 1.9) + 1) / 2
			t.BackgroundTransparency = 0.1 + 0.8 * blink
			t.Size = UDim2.fromOffset(3 + 4 * (1 - blink), 3 + 4 * (1 - blink))
		end
		local cycle = (now % 2.6) / 2.6
		bar.Position = UDim2.fromScale(-0.2 + 1.4 * cycle, -0.3)
		bar.Visible = value > 0
	end)

	local original = run.requestHop
	run.requestHop = function(selfRun: any)
		if value <= 0 then
			refused()
			return
		end
		local before = selfRun:getDebugState().hops
		original(selfRun)
		if selfRun:getDebugState().hops > before then
			local drained = pips[math.clamp(math.ceil(value / tier.per), 1, #pips)]
			value -= 1
			draw(true)
			if drained then
				burst(drained)
			end
			if value <= 0 then
				refused()
			end
		end
	end

	local self: { [string]: any } = {}

	function self.value(_self: any): number
		return value
	end

	function self.max(_self: any): number
		return max
	end

	function self.isOut(_self: any): boolean
		return value <= 0
	end

	function self.refill(_self: any, n: number)
		value = math.min(value + n, max)
		draw(true)
	end

	function self.destroy(_self: any)
		loop:Disconnect()
		run.requestHop = nil
		gui:Destroy()
	end

	return self
end

return RunStamina
