--!strict
-- ShopMotion: the Shop's ONE scoped animator (Lane 3, BRIEF N6-02, N6-02a, N6-02b, N6-02c, 2026-11-01).
--
-- Every continuous visual effect of the Shop (moving gradients, the diagonal shine, the price-button breathing, the few
-- pooled sparkles and the carousel's tick) is an EFFECT RECORD registered here. One Heartbeat connection drives all of
-- them, about 30 times a second, from ELAPSED TIME (os.clock), never from frame counts. The connection exists only
-- while the Shop is open: start() connects it, stop() disconnects it and puts every effect in its resting state.
--
--   local animator = ShopMotion.new()                 -- the Shop's own animator (explicit start / stop)
--   animator.start()  animator.stop()  animator.destroy()  animator.clear()  animator.rescan()
--   animator.setViewport(page)                        -- anything outside this rectangle is "offscreen" and rests
--   animator.gradient({ gradient, recipe, phase, host, priority }) -> Handle   -- a moving UIGradient
--   animator.shine({ host, play, period, phase }) -> Handle                    -- calls play() every `period` seconds
--   animator.breathe({ scale, host, frozen }) -> Handle                        -- 1 to 1.02 and back over 2.4 s
--   animator.sparkles({ parent, z, marks, region, seed }) -> Handle            -- pooled star marks
--   animator.every({ seconds, fn, host }) -> Handle                            -- a low-rate callback (the carousel)
--   animator.stats() -> Stats                                                  -- for the debug state and the tests
--
--   ShopMotion.movingGradient(gradient, options?) -> stop    -- the same moving gradient for ANY other screen (the group
--                                                               reward pop-up, an offer pop-up): a shared animator that
--                                                               connects only while at least one gradient is registered
--
-- BUDGET (N6-02c): at most 6 continuously animated gradients, 1 breathing button and 4 sparkle marks are ACTIVE at once;
-- a record whose host is hidden or outside the viewport is not active and rests. The budget is handed out in priority
-- order (a lower number is kept first). Reduced Motion (Motion.reduced: Roblox's own setting plus the preview-only
-- override) keeps every colour and rests every effect: nothing moves. The sparkles and the shine never exceed 3 flashes
-- a second (marks are small, staggered and each flash lasts 0.9 s).
--
-- Gradients use UIGradient.Offset and UIGradient.Rotation only; the Color and Transparency sequences are never touched.
-- The only tweens in the Shop's motion are discrete events (open, close, press, a shine sweep) started by their owners.

local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Motion)

local ShopMotion = {}

local TAU = math.pi * 2

-- Open, close and press timings (N6-02b). The kit and the screen read these, so there is one set of numbers.
ShopMotion.Timing = table.freeze({
	OpenSeconds = 0.18,
	OpenFrom = 0.97,
	CloseSeconds = 0.12,
	CloseTo = 0.97,
	ReducedFade = 0.1,
	PressScale = 0.97, -- a mouse press (N6-02b)
	PressScaleTouch = 0.95, -- a finger hides the button, so the squash is a little stronger on touch
	PressSeconds = 0.06,
	ReleaseSeconds = 0.10,
	ShineSeconds = 0.7,
	ShinePeriod = 6,
	BreathSeconds = 2.4,
	BreathAmount = 0.02,
	SparkleSeconds = 0.9,
})

ShopMotion.Budget = table.freeze({
	Gradients = 6,
	Breathing = 1,
	SparkleMarks = 4,
	UpdatesPerSecond = 30,
	ScanSeconds = 0.25,
})

local STEP = 1 / ShopMotion.Budget.UpdatesPerSecond
local SPARKLE_CYCLE = 2.1 -- one mark: 0.9 s on, then a pause, so the marks never read as a strobe

export type Recipe = {
	period: number, -- seconds for one full cycle
	offsetX: number, -- amplitude of UIGradient.Offset.X
	offsetY: number,
	rotation: number, -- amplitude of the UIGradient.Rotation swing, in degrees
	lag: number, -- the rotation lags the offset by this fraction of a cycle (0 = in step)
}

-- N6-02b starting recipes. "Page", "Hero" and "Deal" are the brief's table (Offset.X amplitude, period, Rotation swing);
-- "Card" (a pass card's glow) and "Popup" use the same family. A small Offset.Y rides along so the colour field moves
-- along the gradient axis whichever way the engine applies Offset (screen space or rotated space): the brief's numbers
-- stay as written for X. Tune them in Studio; nothing else in the Shop hard-codes a motion number.
local RECIPES: { [string]: Recipe } = {
	Page = { period = 8, offsetX = 0.15, offsetY = 0.08, rotation = 12, lag = 0 },
	Hero = { period = 6, offsetX = 0.25, offsetY = 0.12, rotation = 20, lag = 0.25 },
	Deal = { period = 5, offsetX = 0.2, offsetY = 0.1, rotation = 8, lag = 0.25 },
	Card = { period = 7, offsetX = 0.14, offsetY = 0.14, rotation = 9, lag = 0.25 },
	Popup = { period = 6, offsetX = 0.22, offsetY = 0.12, rotation = 16, lag = 0.25 },
}
ShopMotion.Recipes = RECIPES

export type Handle = { remove: () -> () }

export type GradientSpec = {
	gradient: UIGradient,
	recipe: string?, -- "Page" | "Hero" | "Deal" | "Card" | "Popup" (default "Card")
	phase: number?, -- seconds, so neighbouring cards are never in step
	host: GuiObject?, -- the thing that must be visible (default: the gradient's parent)
	priority: number?, -- lower is kept first when the budget is full (default 5)
}
export type ShineSpec = {
	host: GuiObject,
	play: () -> boolean, -- starts one sweep; false when it could not
	rest: (() -> ())?, -- hides the band (the host went offscreen, the Shop closed, Reduced Motion began)
	period: number?, -- default 6 s
	phase: number?, -- seconds; the hero and the deal are 3 s apart so two sweeps never overlap
	priority: number?,
}
export type BreatheSpec = {
	scale: UIScale,
	host: GuiObject,
	frozen: (() -> boolean)?, -- true while the button is hovered, pressed or not idle: it rests at 1
	priority: number?,
}
export type SparkleSpec = {
	parent: GuiObject,
	z: number,
	marks: number?, -- 1 to 4
	region: { number }?, -- x0, y0, x1, y1 as fractions of the parent
	seed: number?,
	size: number?, -- the mark's side in design px (default 18)
	priority: number?,
}
export type TickSpec = { seconds: number, fn: () -> (), host: GuiObject? }

export type Stats = {
	running: boolean,
	connections: number, -- 1 while the driver is connected, else 0
	effects: number,
	gradients: number, -- ACTIVE counts, right now
	breathing: number,
	sparkleMarks: number,
	shines: number,
	steps: number, -- driver updates since start()
	reduced: boolean,
}

export type Animator = {
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),
	clear: () -> (),
	rescan: () -> (),
	isRunning: () -> boolean,
	setViewport: (GuiObject?) -> (),
	gradient: (GradientSpec) -> Handle,
	shine: (ShineSpec) -> Handle,
	breathe: (BreatheSpec) -> Handle,
	sparkles: (SparkleSpec) -> Handle,
	every: (TickSpec) -> Handle,
	stats: () -> Stats,
}

type Kind = "gradient" | "breath" | "sparkle" | "shine" | "tick"

type Effect = {
	id: number,
	kind: Kind,
	priority: number,
	weight: number, -- sparkle marks this effect needs
	host: GuiObject?,
	active: boolean,
	dead: boolean,
	update: (t: number) -> (),
	rest: () -> (),
	cleanup: (() -> ())?,
}

-- Whether `host` can be seen right now: every ancestor is Visible (and any ScreenGui is Enabled), and, inside the
-- viewport's subtree, its rectangle overlaps the viewport. A hidden or scrolled-away card therefore never animates.
local function isShown(host: GuiObject?, viewport: GuiObject?): boolean
	if host == nil then
		return true
	end
	if not host:IsDescendantOf(game) then
		return false
	end
	local node: Instance? = host
	local guard = 0
	while node ~= nil and guard < 60 do
		guard += 1
		if node:IsA("GuiObject") then
			if not (node :: GuiObject).Visible then
				return false
			end
		elseif node:IsA("ScreenGui") then
			if not (node :: ScreenGui).Enabled then
				return false
			end
		end
		node = node.Parent
	end
	local view = viewport
	if view ~= nil and host ~= view and host:IsDescendantOf(view) then
		local p, s = host.AbsolutePosition, host.AbsoluteSize
		local vp, vs = view.AbsolutePosition, view.AbsoluteSize
		return p.X < vp.X + vs.X and p.X + s.X > vp.X and p.Y < vp.Y + vs.Y and p.Y + s.Y > vp.Y
	end
	return true
end

function ShopMotion.new(options: { auto: boolean? }?): Animator
	local auto = options ~= nil and options.auto == true
	local effects: { Effect } = {}
	local nextId = 0
	local running = false
	local connection: RBXScriptConnection? = nil
	local reducedWatch: (() -> ())? = nil
	local viewport: GuiObject? = nil
	local startedAt = 0
	local stepAcc = 0
	local scanAcc = 0
	local steps = 0
	local reduced = false
	local activeCount = 0
	local warned: { [number]: boolean } = {}
	local counts = { gradients = 0, breathing = 0, sparkleMarks = 0, shines = 0 }

	local animator: Animator

	local function restEffect(effect: Effect)
		local ok, err = pcall(effect.rest)
		if not ok and not warned[effect.id] then
			warned[effect.id] = true
			warn("[ShopMotion] rest failed: " .. tostring(err))
		end
	end

	-- Hands the budget out in priority order and rests whatever lost it or went offscreen.
	local function rescan()
		reduced = Motion.reduced()
		local gradients, breathing, marks, shines, active = 0, 0, 0, 0, 0
		for _, effect in effects do
			local allowed = false
			if running and not reduced and not effect.dead and isShown(effect.host, viewport) then
				local kind = effect.kind
				if kind == "gradient" then
					if gradients < ShopMotion.Budget.Gradients then
						gradients += 1
						allowed = true
					end
				elseif kind == "breath" then
					if breathing < ShopMotion.Budget.Breathing then
						breathing += 1
						allowed = true
					end
				elseif kind == "sparkle" then
					if marks + effect.weight <= ShopMotion.Budget.SparkleMarks then
						marks += effect.weight
						allowed = true
					end
				else
					if kind == "shine" then
						shines += 1
					end
					allowed = true
				end
			end
			if allowed then
				active += 1
			end
			if allowed and not effect.active then
				effect.active = true
			elseif not allowed and effect.active then
				effect.active = false
				restEffect(effect)
			end
		end
		activeCount = active
		counts.gradients, counts.breathing, counts.sparkleMarks, counts.shines = gradients, breathing, marks, shines
	end

	local function onHeartbeat(dt: number)
		scanAcc += dt
		if scanAcc >= ShopMotion.Budget.ScanSeconds then
			scanAcc = 0
			rescan()
		end
		stepAcc += dt
		if stepAcc < STEP then
			return
		end
		stepAcc = 0
		if activeCount == 0 then
			return
		end
		steps += 1
		local elapsed = os.clock() - startedAt
		for _, effect in effects do
			if effect.active then
				local ok, err = pcall(effect.update, elapsed)
				if not ok then
					-- a broken effect is switched off for good; the rest of the Shop keeps moving
					effect.dead = true
					effect.active = false
					activeCount = math.max(activeCount - 1, 0)
					warn("[ShopMotion] effect " .. effect.kind .. " stopped: " .. tostring(err))
					restEffect(effect)
				end
			end
		end
	end

	local function start()
		if running then
			return
		end
		running = true
		startedAt = os.clock()
		stepAcc = 0
		scanAcc = 0
		steps = 0
		connection = RunService.Heartbeat:Connect(onHeartbeat)
		reducedWatch = Motion.onReducedChanged(function()
			rescan()
		end)
		rescan()
	end

	local function stop()
		if not running then
			return
		end
		running = false
		local conn = connection
		connection = nil
		if conn then
			conn:Disconnect()
		end
		local watch = reducedWatch
		reducedWatch = nil
		if watch then
			watch()
		end
		rescan() -- running is false now: every active effect rests
		activeCount = 0
	end

	local function sortEffects()
		table.sort(effects, function(a: Effect, b: Effect): boolean
			if a.priority ~= b.priority then
				return a.priority < b.priority
			end
			return a.id < b.id
		end)
	end

	local function register(
		kind: Kind,
		priority: number?,
		weight: number,
		host: GuiObject?,
		update: (t: number) -> (),
		rest: () -> (),
		cleanup: (() -> ())?
	): Handle
		nextId += 1
		local effect: Effect = {
			id = nextId,
			kind = kind,
			priority = priority or 5,
			weight = weight,
			host = host,
			active = false,
			dead = false,
			update = update,
			rest = rest,
			cleanup = cleanup,
		}
		table.insert(effects, effect)
		sortEffects()
		if auto and not running then
			start()
		end
		local removed = false
		return {
			remove = function()
				if removed then
					return
				end
				removed = true
				local index = table.find(effects, effect)
				if index then
					table.remove(effects, index)
				end
				if effect.active then
					effect.active = false
					restEffect(effect)
				end
				local clean = effect.cleanup
				if clean then
					pcall(clean)
				end
				if auto and running and #effects == 0 then
					stop()
				end
			end,
		}
	end

	local function clear()
		for _, effect in table.clone(effects) do
			effect.active = false
			local clean = effect.cleanup
			if clean then
				pcall(clean)
			end
		end
		table.clear(effects)
		table.clear(warned)
		activeCount = 0
		counts.gradients, counts.breathing, counts.sparkleMarks, counts.shines = 0, 0, 0, 0
		if auto and running then
			stop()
		end
	end

	-- A moving gradient: Offset.X and Rotation follow the recipe; Color and Transparency are never touched.
	local function gradient(spec: GradientSpec): Handle
		local g = spec.gradient
		local recipe = RECIPES[spec.recipe or "Card"] or RECIPES.Card
		local phase = spec.phase or 0
		local baseRotation = g.Rotation
		local baseOffset = g.Offset
		local host: GuiObject? = spec.host
		if host == nil then
			local parent = g.Parent
			if parent ~= nil and parent:IsA("GuiObject") then
				host = parent :: GuiObject
			end
		end
		return register("gradient", spec.priority, 0, host, function(elapsed: number)
			local u = (elapsed + phase) / recipe.period * TAU
			g.Offset =
				Vector2.new(baseOffset.X + recipe.offsetX * math.sin(u), baseOffset.Y + recipe.offsetY * math.cos(u))
			g.Rotation = baseRotation + recipe.rotation * math.sin(u + recipe.lag * TAU)
		end, function()
			-- the resting look is the midpoint of the sway: attractive and still
			g.Offset = baseOffset
			g.Rotation = baseRotation
		end)
	end

	-- A sweep of light: play() is called once per period, only while the host is on screen. The first period after the
	-- host (re)appears is skipped, so a card that scrolls into view never starts with a half-finished sweep.
	local function shine(spec: ShineSpec): Handle
		local period = spec.period or ShopMotion.Timing.ShinePeriod
		local phase = spec.phase or 0
		local lastCycle = -1
		local armed = false
		return register("shine", spec.priority, 0, spec.host, function(elapsed: number)
			local cycle = math.floor((elapsed - phase) / period)
			if not armed then
				armed = true
				lastCycle = cycle
				return
			end
			if cycle > lastCycle then
				lastCycle = cycle
				if elapsed - phase >= 0 then
					spec.play()
				end
			end
		end, function()
			armed = false
			local rest = spec.rest
			if rest ~= nil then
				rest()
			end
		end)
	end

	-- The soft idle breathing of the main price button: Scale 1 to 1 + amount and back, sine eased.
	local function breathe(spec: BreatheSpec): Handle
		local target = spec.scale
		local amount = ShopMotion.Timing.BreathAmount
		local period = ShopMotion.Timing.BreathSeconds
		return register("breath", spec.priority, 0, spec.host, function(elapsed: number)
			local frozen = spec.frozen
			if frozen ~= nil and frozen() then
				target.Scale = 1
				return
			end
			target.Scale = 1 + amount * 0.5 * (1 - math.cos(elapsed / period * TAU))
		end, function()
			target.Scale = 1
		end)
	end

	-- A few tiny pooled star marks (never more than 4 in the whole Shop). Each mark lives 0.9 s (grow and fade), rests,
	-- then reappears somewhere else in the region; the marks are staggered so two never flash together.
	local function sparkles(spec: SparkleSpec): Handle
		local count = math.clamp(spec.marks or 3, 1, ShopMotion.Budget.SparkleMarks)
		local region = spec.region or { 0.1, 0.1, 0.9, 0.9 }
		local seed = spec.seed or 11
		local side = spec.size or 18
		local layer = Instance.new("Frame")
		layer.Name = "Sparkles"
		layer.BackgroundTransparency = 1
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = spec.z
		layer.Parent = spec.parent
		type Mark = { frame: Frame, scale: UIScale, bars: { Frame }, cycle: number }
		local marks: { Mark } = {}
		for _ = 1, count do
			local star = Instance.new("Frame")
			star.Name = "Star"
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Size = UDim2.fromOffset(side, side)
			star.BackgroundTransparency = 1
			star.Visible = false
			star.ZIndex = spec.z
			local starScale = Instance.new("UIScale")
			starScale.Scale = 0
			starScale.Parent = star
			local bars: { Frame } = {}
			for _, dims in { Vector2.new(side, side * 0.26), Vector2.new(side * 0.26, side) } do
				local bar = Instance.new("Frame")
				bar.Name = "Bar"
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Position = UDim2.fromScale(0.5, 0.5)
				bar.Size = UDim2.fromOffset(dims.X, dims.Y)
				bar.BackgroundColor3 = Color3.fromRGB(255, 250, 196)
				bar.BorderSizePixel = 0
				bar.ZIndex = spec.z
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 3)
				corner.Parent = bar
				bar.Parent = star
				table.insert(bars, bar)
			end
			star.Parent = layer
			table.insert(marks, { frame = star, scale = starScale, bars = bars, cycle = -1 })
		end
		local duration = ShopMotion.Timing.SparkleSeconds
		return register("sparkle", spec.priority, count, spec.parent, function(elapsed: number)
			for index, mark in marks do
				local cycles = (elapsed + (index - 1) * SPARKLE_CYCLE / count) / SPARKLE_CYCLE
				local whole = math.floor(cycles)
				local into = (cycles - whole) * SPARKLE_CYCLE
				if whole ~= mark.cycle then
					mark.cycle = whole
					local rng = Random.new(seed + index * 977 + whole)
					mark.frame.Position =
						UDim2.fromScale(rng:NextNumber(region[1], region[3]), rng:NextNumber(region[2], region[4]))
					mark.frame.Rotation = rng:NextNumber(-20, 20)
				end
				if into < duration then
					local envelope = math.sin(math.pi * into / duration)
					mark.frame.Visible = true
					mark.scale.Scale = envelope
					for _, bar in mark.bars do
						bar.BackgroundTransparency = 1 - envelope
					end
				else
					mark.frame.Visible = false
				end
			end
		end, function()
			for _, mark in marks do
				mark.frame.Visible = false
				mark.scale.Scale = 0
				mark.cycle = -1
			end
		end, function()
			layer:Destroy()
		end)
	end

	-- A low-rate callback (the carousel): fn() runs every `seconds` of elapsed time while its host is visible.
	local function every(spec: TickSpec): Handle
		local nextAt = 0
		return register("tick", 9, 0, spec.host, function(elapsed: number)
			if nextAt == 0 then
				nextAt = elapsed + spec.seconds
			end
			if elapsed >= nextAt then
				nextAt = elapsed + spec.seconds
				spec.fn()
			end
		end, function()
			nextAt = 0
		end)
	end

	animator = {
		start = start,
		stop = stop,
		destroy = function()
			stop()
			clear()
		end,
		clear = clear,
		rescan = rescan,
		isRunning = function(): boolean
			return running
		end,
		setViewport = function(view: GuiObject?)
			viewport = view
			if running then
				rescan()
			end
		end,
		gradient = gradient,
		shine = shine,
		breathe = breathe,
		sparkles = sparkles,
		every = every,
		stats = function(): Stats
			return {
				running = running,
				connections = if connection ~= nil then 1 else 0,
				effects = #effects,
				gradients = counts.gradients,
				breathing = counts.breathing,
				sparkleMarks = counts.sparkleMarks,
				shines = counts.shines,
				steps = steps,
				reduced = reduced,
			}
		end,
	}
	return animator
end

-- ANY OTHER SCREEN ---------------------------------------------------------------------------------------------------

local sharedAnimator: Animator? = nil

export type MovingOptions = {
	recipe: string?, -- default "Popup"
	phase: number?,
	host: GuiObject?, -- must be visible for the gradient to move (default: the gradient's parent)
	priority: number?, -- default 1: a pop-up's own background is the first thing the budget keeps
}

-- Makes `gradient` move like the Shop's pop-up backgrounds (a slow Offset and Rotation sway). It uses a shared animator
-- whose single driver connects only while at least one such gradient is registered and rests while the host is hidden.
-- Returns a stop function: put it in the screen's Trove. Reduced Motion keeps the colours and stops the motion.
function ShopMotion.movingGradient(gradient: UIGradient, options: MovingOptions?): () -> ()
	local opts: MovingOptions = options or {}
	local animator = sharedAnimator
	if animator == nil then
		animator = ShopMotion.new({ auto = true })
		sharedAnimator = animator
	end
	local shared = animator :: Animator
	local handle = shared.gradient({
		gradient = gradient,
		recipe = opts.recipe or "Popup",
		phase = opts.phase,
		host = opts.host,
		priority = opts.priority or 1,
	})
	return handle.remove
end

return ShopMotion
