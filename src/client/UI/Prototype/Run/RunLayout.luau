--!strict
-- Shared run-view geometry for the HUD prototype's run components (Lane 3 preview, worker H3).
-- Not a component. Every rectangle here is in DESIGN px on a component "canvas": a Frame that
-- fills ctx.layer and carries the UIScale "HudScale" = ctx.screen:uiScale(), so the canvas is
-- (safe size / scale) design px across and children are placed in design px.
--
--   RunLayout.canvas(ctx, name)       -> Frame (root with HudScale); RunLayout.fit(ctx, root)
--   RunLayout.design(ctx)             -> Vector2 canvas size in design px
--   RunLayout.landingBand(ctx)        -> Rect   (the car / landing view, kept clear)
--   RunLayout.zones(ctx)              -> { Rect } reserved touch zones in design px
--   RunLayout.heatPanelRect(ctx)      -> Rect   the approved ENGINE HEAT panel and its effects
--   RunLayout.gearRect / chipRect / hopRect / keysRect / dashRect(ctx) -> Rect (placement,
--                                        shared so siblings avoid each other without seeing
--                                        each other; the solver reports any leftover conflict)
--   RunLayout.publishTop / top / topChanged   -- RunLayer publishes the top stack (Distance +
--                                        coins) so Milestones, the ride chip and ribbons avoid it
--   RunLayout.slot(screen)            -- one upper-screen message slot with priorities
--
-- RESERVED LANDING VIEW (documented assumption, not a camera measurement): the third-person run
-- camera keeps the ridden car and the next landing target in the middle of the screen, so run
-- feedback never sits in the band: the middle 40% of the canvas width (30%..70%) x 45% of its
-- height (40%..85%), in every profile (a reversible preview choice). Diagnostics
-- (RunLayer:setDiagnostics) draw it as "LANDING VIEW (kept clear)". The approved Heat panel
-- (bottom centre) is the one approved element that already overlaps it on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Screen = require(script.Parent.Parent.Screen)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Store = require(script.Parent.Parent.Store)

local RunLayout = {}

export type Ctx = {
	store: Store.StoreObject,
	screen: Screen.ScreenObject,
	layer: Frame,
	world: Folder,
}

export type Rect = { pos: Vector2, size: Vector2, name: string? }

RunLayout.Margin = 12 -- Tokens.Space.M, the approved edge gap at scale 1
RunLayout.Gear = 48 -- options button (approved touch minimum)
RunLayout.SafeMargin = 24 -- the approved Heat panel's distance from the safe edge
RunLayout.HeatEffect = 10 -- HeatGauge.EffectMargin
RunLayout.HeatSize = Vector2.new(320, 92) -- HeatGauge.Size
RunLayout.HeatAbove = 30 -- title tab and the lowest smoke above the card (estimate)
RunLayout.Band = table.freeze({ top = 0.4, height = 0.45, width = 0.4 })

function RunLayout.rect(x: number, y: number, w: number, h: number, name: string?): Rect
	return { pos = Vector2.new(x, y), size = Vector2.new(w, h), name = name }
end

function RunLayout.overlaps(a: Rect, b: Rect): boolean
	local a0, a1 = a.pos, a.pos + a.size
	local b0, b1 = b.pos, b.pos + b.size
	return a0.X < b1.X and a1.X > b0.X and a0.Y < b1.Y and a1.Y > b0.Y
end

function RunLayout.inside(a: Rect, design: Vector2): boolean
	return a.pos.X >= 0 and a.pos.Y >= 0 and a.pos.X + a.size.X <= design.X and a.pos.Y + a.size.Y <= design.Y
end

function RunLayout.design(ctx: Ctx): Vector2
	local p = ctx.screen:profile()
	local s = ctx.screen:uiScale()
	local i = p.insets
	return Vector2.new((p.size.X - i.left - i.right) / s, (p.size.Y - i.top - i.bottom) / s)
end

function RunLayout.portrait(ctx: Ctx): boolean
	local d = RunLayout.design(ctx)
	return d.Y > d.X
end

-- Design px (canvas) -> device px (what Screen.overlapsReserved takes).
function RunLayout.toDevice(ctx: Ctx, r: Rect): (Vector2, Vector2)
	local p = ctx.screen:profile()
	local s = ctx.screen:uiScale()
	return Vector2.new(p.insets.left, p.insets.top) + r.pos * s, r.size * s
end

function RunLayout.zones(ctx: Ctx): { Rect }
	local p = ctx.screen:profile()
	local s = ctx.screen:uiScale()
	local origin = Vector2.new(p.insets.left, p.insets.top)
	local out = {}
	for _, z in p.zones do
		table.insert(out, { pos = (z.position - origin) / s, size = z.size / s, name = z.name })
	end
	return out
end

function RunLayout.landingBand(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local b = RunLayout.Band
	return RunLayout.rect((1 - b.width) / 2 * d.X, b.top * d.Y, b.width * d.X, b.height * d.Y, "LandingView")
end

-- Bottom of the approved Heat panel in canvas px, matching RunHud's rule (24 px + halo inside
-- the safe area, one touch row higher in portrait).
function RunLayout.heatBottomOffset(ctx: Ctx): number
	local s = ctx.screen:uiScale()
	local touchRow = if RunLayout.portrait(ctx) then 56 + 24 else 0
	return RunLayout.SafeMargin / s + RunLayout.HeatEffect + touchRow
end

function RunLayout.heatPanelRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local w = RunLayout.HeatSize.X + 2 * RunLayout.HeatEffect
	local h = RunLayout.HeatSize.Y + RunLayout.HeatAbove + RunLayout.HeatEffect
	local bottom = d.Y - RunLayout.heatBottomOffset(ctx) + RunLayout.HeatEffect
	return RunLayout.rect(d.X / 2 - w / 2, bottom - h, w, h, "HeatPanel")
end

-- Picks the first candidate rectangle that is fully inside the canvas and clear of every avoid
-- rectangle and reserved zone. Returns the chosen rect and the name of what it still overlaps
-- (nil when clear; the first candidate is used when nothing is clear).
function RunLayout.solve(ctx: Ctx, candidates: { Rect }, avoid: { Rect }): (Rect, string?)
	local d = RunLayout.design(ctx)
	local zones = RunLayout.zones(ctx)
	local function conflict(r: Rect): string?
		if not RunLayout.inside(r, d) then
			return "Edge"
		end
		for _, z in zones do
			if RunLayout.overlaps(r, z) then
				return z.name or "Zone"
			end
		end
		for _, a in avoid do
			if RunLayout.overlaps(r, a) then
				return a.name or "Avoid"
			end
		end
		return nil
	end
	for _, c in candidates do
		if conflict(c) == nil then
			return c, nil
		end
	end
	local first = candidates[1]
	return first, conflict(first)
end

local function centred(cx: number, cy: number, size: Vector2, name: string): Rect
	return RunLayout.rect(cx - size.X / 2, cy - size.Y / 2, size.X, size.Y, name)
end

----------------------------------------------------------------------------------------------
-- Top stack publishing (RunLayer -> siblings)

export type Top = {
	row: number, -- 1: Distance beside Cash / Heat; 2: Distance on its own row (narrow screens)
	distance: Rect,
	coins: Rect,
	stackBottom: number, -- design y just below Distance + coins
	leftBottom: number, -- design y below Cash / the proposal Heat bar
}

local tops: { [any]: Top } = setmetatable({}, { __mode = "k" }) :: any
local topSignals: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

function RunLayout.topChanged(screen: any): any
	local s = topSignals[screen]
	if not s then
		s = Signal.new()
		topSignals[screen] = s
	end
	return s
end

function RunLayout.publishTop(screen: any, top: Top)
	tops[screen] = top
	RunLayout.topChanged(screen):Fire(top)
end

-- The published top stack, or a conservative default (one row, Distance about 190 x 44 centred)
-- if RunLayer has not laid out yet.
function RunLayout.top(screen: any): Top
	local t = tops[screen]
	if t then
		return t
	end
	return {
		row = 1,
		distance = RunLayout.rect(0, 12, 0, 44),
		coins = RunLayout.rect(0, 58, 0, 28),
		stackBottom = 88,
		leftBottom = 72,
	}
end

----------------------------------------------------------------------------------------------
-- Placement of the run pieces

-- Options gear (top right) and the ride chip beneath it (row 1), or the chip under Cash on the
-- left when Distance has its own row (narrow portrait).
RunLayout.ChipSize = Vector2.new(220, 44)
function RunLayout.gearRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local g = RunLayout.Gear
	return RunLayout.rect(d.X - RunLayout.Margin - g, RunLayout.Margin, g, g + 4, "Options")
end

function RunLayout.chipRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local m = RunLayout.Margin
	local s = RunLayout.ChipSize
	local top = RunLayout.top(ctx.screen)
	if top.row == 2 then
		local w = math.min(s.X, math.max(top.distance.pos.X - 2 * m, 120))
		return RunLayout.rect(m, top.distance.pos.Y, w, s.Y, "RideChip")
	end
	local gear = RunLayout.gearRect(ctx)
	return RunLayout.rect(d.X - m - s.X, gear.pos.Y + gear.size.Y + 8, s.X, s.Y, "RideChip")
end

-- Everything at the top of the screen (Cash / Heat bar, Distance + coins, options, ride chip).
function RunLayout.topBlock(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local top = RunLayout.top(ctx.screen)
	local chip = RunLayout.chipRect(ctx)
	local bottom = math.max(top.stackBottom, top.leftBottom, chip.pos.Y + chip.size.Y)
	return RunLayout.rect(0, 0, d.X, bottom + 4, "TopStack")
end

-- Desktop "SPACE: HOP" key hint, bottom right.
RunLayout.HintSize = Vector2.new(150, 40)
function RunLayout.hintRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local s = RunLayout.HintSize
	return RunLayout.rect(d.X - RunLayout.Margin - s.X, d.Y - RunLayout.Margin - s.Y, s.X, s.Y, "HopHint")
end

-- The phone Hop button (96 design px + shadow): beside the Roblox Jump zone on its left, else
-- above it, else the bottom-right corner. Never in a reserved zone, the band or the Heat panel.
RunLayout.HopSize = Vector2.new(96, 96 + 4)
function RunLayout.hopRect(ctx: Ctx): (Rect, string?)
	local d = RunLayout.design(ctx)
	local size = RunLayout.HopSize
	local m = 8
	local jump: Rect? = nil
	for _, z in RunLayout.zones(ctx) do
		if z.name == "Jump" then
			jump = z
		end
	end
	local candidates = {}
	if jump then
		local j = jump :: Rect
		local bottom = math.min(j.pos.Y + j.size.Y, d.Y - 4)
		table.insert(candidates, RunLayout.rect(j.pos.X - m - size.X, bottom - size.Y, size.X, size.Y, "Hop"))
		local cx = math.min(j.pos.X + j.size.X / 2, d.X - m - size.X / 2)
		table.insert(candidates, RunLayout.rect(cx - size.X / 2, j.pos.Y - m - size.Y, size.X, size.Y, "Hop"))
	end
	table.insert(candidates, RunLayout.rect(d.X - m - size.X, d.Y - 4 - size.Y, size.X, size.Y, "Hop"))
	return RunLayout.solve(ctx, candidates, { RunLayout.landingBand(ctx), RunLayout.heatPanelRect(ctx) })
end

-- Keys ring (64 ring + cue below). Lower third beside the landing band and the Heat panel; else
-- the right column (beside the band, then under the top-right stack); else left of the band.
RunLayout.KeysSize = Vector2.new(104, 64 + 26)
function RunLayout.keysRect(ctx: Ctx): (Rect, string?)
	local d = RunLayout.design(ctx)
	local band = RunLayout.landingBand(ctx)
	local heat = RunLayout.heatPanelRect(ctx)
	local block = RunLayout.topBlock(ctx)
	local size = RunLayout.KeysSize
	local m = RunLayout.Margin
	local lowY = math.min(d.Y * 0.72, d.Y - m - size.Y / 2)
	local colX = d.X - 8 - size.X / 2
	local candidates = {
		centred(band.pos.X + band.size.X + m + size.X / 2, lowY, size, "Keys"),
		centred(heat.pos.X + heat.size.X + m + size.X / 2, lowY, size, "Keys"),
		centred(colX, band.pos.Y + band.size.Y * 0.45, size, "Keys"),
		centred(colX, block.size.Y + m + size.Y / 2, size, "Keys"),
		centred(band.pos.X - m - size.X / 2, lowY, size, "Keys"),
	}
	local avoid = { band, heat, block }
	if ctx.screen:profile().touch then
		table.insert(avoid, (RunLayout.hopRect(ctx)))
	else
		table.insert(avoid, RunLayout.hintRect(ctx))
	end
	return RunLayout.solve(ctx, candidates, avoid)
end

-- Foot Dash indicator (arc + DASH cue). Left of the band in the lower third, else beside Keys,
-- else below Keys, else beside Hop, else the left column under the top stack.
RunLayout.DashSize = Vector2.new(84, 64 + 26)
function RunLayout.dashRect(ctx: Ctx): (Rect, string?)
	local d = RunLayout.design(ctx)
	local band = RunLayout.landingBand(ctx)
	local size = RunLayout.DashSize
	local m = RunLayout.Margin
	local keys = RunLayout.keysRect(ctx)
	local hop = RunLayout.hopRect(ctx)
	local block = RunLayout.topBlock(ctx)
	local lowY = math.min(d.Y * 0.72, d.Y - m - size.Y / 2)
	local candidates = {
		centred(band.pos.X - m - size.X / 2, lowY, size, "Dash"),
		centred(keys.pos.X - m - size.X / 2, keys.pos.Y + keys.size.Y / 2, size, "Dash"),
		centred(keys.pos.X + keys.size.X / 2, keys.pos.Y + keys.size.Y + m + size.Y / 2, size, "Dash"),
		centred(hop.pos.X - m - size.X / 2, hop.pos.Y + hop.size.Y / 2, size, "Dash"),
		centred(m + size.X / 2, block.size.Y + m + size.Y / 2, size, "Dash"),
	}
	local avoid = { band, RunLayout.heatPanelRect(ctx), keys, block }
	if ctx.screen:profile().touch then
		table.insert(avoid, hop)
	else
		table.insert(avoid, RunLayout.hintRect(ctx))
	end
	return RunLayout.solve(ctx, candidates, avoid)
end

-- Where an upper-screen message (milestone, ribbon, toast-like note) sits: centred under the
-- Distance + coins stack, and under the tutorial banner if one is shown.
function RunLayout.messageY(ctx: Ctx): number
	local top = RunLayout.top(ctx.screen)
	local y = top.stackBottom + 6
	-- Assumption: a run-time tutorial banner (Home worker's component) sits directly under the
	-- top stack, so a message moves one banner height (56) plus a gap below it.
	if ctx.store:get().tutorial ~= nil then
		y += 56 + 8
	end
	return y
end

----------------------------------------------------------------------------------------------
-- The upper-screen message slot (celebration 3, Already owned 2, Milestone 1). A claim with
-- priority >= the holder's preempts it (the holder gets Preempted(owner)).

export type Slot = {
	claim: (owner: string, priority: number) -> boolean,
	release: (owner: string) -> (),
	holder: () -> string?,
	Preempted: any, -- Signal(owner)
	Freed: any, -- Signal()
}

local slots: { [any]: Slot } = setmetatable({}, { __mode = "k" }) :: any

function RunLayout.slot(screen: any): Slot
	local existing = slots[screen]
	if existing then
		return existing
	end
	local current: { owner: string, priority: number }? = nil
	local preempted = Signal.new()
	local freed = Signal.new()
	local slot: Slot = {
		claim = function(owner: string, priority: number): boolean
			local c = current
			if c and c.owner ~= owner and c.priority > priority then
				return false
			end
			current = { owner = owner, priority = priority }
			if c and c.owner ~= owner then
				preempted:Fire(c.owner)
			end
			return true
		end,
		release = function(owner: string)
			local c = current
			if c and c.owner == owner then
				current = nil
				freed:Fire()
			end
		end,
		holder = function(): string?
			local c = current
			return if c then c.owner else nil
		end,
		Preempted = preempted,
		Freed = freed,
	}
	slots[screen] = slot
	return slot
end

----------------------------------------------------------------------------------------------
-- Canvas

function RunLayout.canvas(ctx: Ctx, name: string): Frame
	local root = Instance.new("Frame")
	root.Name = name
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Active = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = root
	RunLayout.fit(ctx, root)
	root.Parent = ctx.layer
	return root
end

-- The canvas fills the layer after scaling: size 1/s of the layer, then UIScale s.
function RunLayout.fit(ctx: Ctx, root: Frame)
	local s = ctx.screen:uiScale()
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	root.Position = UDim2.new()
	local hud = root:FindFirstChild("HudScale") :: UIScale?
	if hud then
		hud.Scale = s
	end
end

function RunLayout.describe(r: Rect): string
	return string.format("%dx%d at (%d,%d)", r.size.X, r.size.Y, r.pos.X, r.pos.Y)
end

-- Places a GuiObject (AnchorPoint 0,0) on a rect.
function RunLayout.place(g: GuiObject, r: Rect)
	g.AnchorPoint = Vector2.zero
	g.Position = UDim2.fromOffset(r.pos.X, r.pos.Y)
	g.Size = UDim2.fromOffset(r.size.X, r.size.Y)
end

return RunLayout
