--!strict
-- Shared run-view geometry for the HUD prototype's run components (Lane 3 preview; HUD rebuild
-- worker HR, 2026-10-22). Not a component. Every rectangle here is in DESIGN px on a component
-- "canvas": a Frame that fills ctx.layer and carries the UIScale "HudScale" =
-- ctx.screen:uiScale(), so the canvas is (safe size / scale) design px across.
--
--   RunLayout.canvas(ctx, name) -> Frame (root with HudScale); RunLayout.fit(ctx, root)
--   RunLayout.design(ctx)       -> Vector2 canvas size in design px
--   RunLayout.compact(ctx)      -> true on phones (compact strip, tray, Heat)
--   RunLayout.protectedRect(profile) -> Rect in DEVICE px (relative to the device frame)
--   RunLayout.protected(ctx)    -> Rect in design px (same region; landingBand is an alias)
--   RunLayout.worldToCanvas(ctx, worldPos) -> (Vector2 design px, onScreen, depth)
--   RunLayout.stripRect / cashRect / trayRect / bannerRect / sideRect / heatRect / hopRect /
--     keysRect / dashRect(ctx) -> Rect (placement, shared so siblings avoid each other without
--     seeing each other; the solver reports any leftover conflict as a second return)
--   RunLayout.upperY(ctx)       -> design y of the "Upper" message row (banner, milestones)
--
-- PROTECTED ROAD-AHEAD REGION (L-05; a reversible PROPOSAL from the preview chase camera, not a
-- camera measurement): the ridden car, the next Hop target and the landing trajectory stay in
-- the middle of the screen, so no run component may sit in it. Fractions of the safe area:
--   Desktop / Tablet   x 30%..70%, y 40%..85%   (the overnight band)
--   PhoneLandscape     x 28%..72%, y 42%..84%   (the strip and banner fit above it)
--   PhoneSmall / PhoneLandscapeLeft / PhoneLandscapeRight   the PhoneLandscape fractions
-- Diagnostics (RunLayer:setDiagnostics) draw it as "PROTECTED ROAD AHEAD".

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HomeLayout = require(script.Parent.Parent.Home.Layout)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Screen = require(script.Parent.Parent.Screen)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Store = require(script.Parent.Parent.Store)

local RunLayout = {}

export type Ctx = {
	store: Store.StoreObject,
	screen: Screen.ScreenObject,
	layer: Frame,
	world: Folder,
	priority: any?, -- Prototype/Priority arbiter (RunBus.priority falls back to a shared local one)
}

export type Rect = { pos: Vector2, size: Vector2, name: string? }

RunLayout.Margin = 12 -- Tokens.Space.M, the approved edge gap at scale 1
RunLayout.Gear = 48 -- options button (approved touch minimum)
RunLayout.SafeMargin = 24

RunLayout.Protected = table.freeze({
	Desktop = table.freeze({ x0 = 0.30, x1 = 0.70, y0 = 0.40, y1 = 0.85 }),
	Tablet = table.freeze({ x0 = 0.30, x1 = 0.70, y0 = 0.40, y1 = 0.85 }),
	PhoneLandscape = table.freeze({ x0 = 0.28, x1 = 0.72, y0 = 0.42, y1 = 0.84 }),
	PhoneSmall = table.freeze({ x0 = 0.28, x1 = 0.72, y0 = 0.42, y1 = 0.84 }),
	PhoneLandscapeLeft = table.freeze({ x0 = 0.28, x1 = 0.72, y0 = 0.42, y1 = 0.84 }),
	PhoneLandscapeRight = table.freeze({ x0 = 0.28, x1 = 0.72, y0 = 0.42, y1 = 0.84 }),
})

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

function RunLayout.compact(ctx: Ctx): boolean
	return ctx.screen:profile().kind == "Phone"
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

local function zone(ctx: Ctx, name: string): Rect?
	for _, z in RunLayout.zones(ctx) do
		if z.name == name then
			return z
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------
-- Protected road-ahead region

-- In device px, relative to the device frame's top-left (insets included).
function RunLayout.protectedRect(profile: Screen.Profile): Rect
	local f = RunLayout.Protected[profile.name] or RunLayout.Protected.Desktop
	local i = profile.insets
	local w = profile.size.X - i.left - i.right
	local h = profile.size.Y - i.top - i.bottom
	return RunLayout.rect(i.left + f.x0 * w, i.top + f.y0 * h, (f.x1 - f.x0) * w, (f.y1 - f.y0) * h, "Protected")
end

-- The same region in design px on a canvas.
function RunLayout.protected(ctx: Ctx): Rect
	local p = ctx.screen:profile()
	local f = RunLayout.Protected[p.name] or RunLayout.Protected.Desktop
	local d = RunLayout.design(ctx)
	return RunLayout.rect(f.x0 * d.X, f.y0 * d.Y, (f.x1 - f.x0) * d.X, (f.y1 - f.y0) * d.Y, "Protected")
end
RunLayout.landingBand = RunLayout.protected -- legacy name (overnight components)

-- World position -> design px on a canvas. The playground ScreenGui uses IgnoreGuiInset and
-- ScreenInsets None, so viewport pixels equal GUI absolute pixels; the virtual device frame is
-- then undone (Screen.toDevice), its insets removed and the HudScale divided out.
function RunLayout.worldToCanvas(ctx: Ctx, worldPos: Vector3): (Vector2, boolean, number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector2.zero, false, 0
	end
	local v, _ = camera:WorldToViewportPoint(worldPos)
	local screen = ctx.screen
	-- viewport px count from the window top, AbsolutePosition from below the top bar (Studio,
	-- 2026-10-23: the projected rider was 58 px low)
	local origin = screen.root.AbsolutePosition + GuiService:GetGuiInset()
	local device = screen:toDevice(Vector2.new(v.X, v.Y) - origin)
	local p = screen:profile()
	local s = screen:uiScale()
	local design = (device - Vector2.new(p.insets.left, p.insets.top)) / s
	local d = RunLayout.design(ctx)
	local on = v.Z > 0 and design.X >= 0 and design.Y >= 0 and design.X <= d.X and design.Y <= d.Y
	return design, on, v.Z
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
-- District strip (top centre). Geometry lives here so siblings can place themselves under it
-- without the strip being mounted.

RunLayout.Strip = table.freeze({
	Top = 8,
	-- full: previous / current / next tiles + a faded stub that says "more beyond"
	TileW = 112,
	TileH = 64,
	CurrentW = 128,
	CurrentH = 74,
	StubW = 36,
	Gap = 6,
	Head = 36,
	HeadY = 76, -- head top, just under the tile row (it covered the current name at 60)
	DistanceH = 26,
	-- compact (phones): current + progress track + next
	CompactCurrentW = 104,
	CompactCurrentH = 62,
	CompactTrackW = 60,
	CompactNextW = 84,
	CompactNextH = 52,
	CompactHead = 32,
	CompactGap = 8,
})

function RunLayout.stripSize(compact: boolean): Vector2
	local S = RunLayout.Strip
	if compact then
		local w = S.CompactCurrentW + S.CompactGap + S.CompactTrackW + S.CompactGap + S.CompactNextW
		return Vector2.new(w, S.CompactCurrentH + 4 + S.DistanceH)
	end
	local w = S.TileW + S.Gap + S.CurrentW + S.Gap + S.TileW + S.Gap + S.StubW
	return Vector2.new(w, S.HeadY + S.Head + S.DistanceH)
end

function RunLayout.stripRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local size = RunLayout.stripSize(RunLayout.compact(ctx))
	return RunLayout.rect(d.X / 2 - size.X / 2, RunLayout.Strip.Top, size.X, size.Y, "DistrictStrip")
end

----------------------------------------------------------------------------------------------
-- Run-time Cash (Round 2, R2-C1): the compact Cash line, top-left of the safe area below the core UI
-- inset. There is no separate coin counter: road coins are Cash pickups. Position and size come from
-- Home/Layout so StatsStack and every run component agree on the same rectangle.

function RunLayout.cashRect(_ctx: Ctx): Rect
	local pos = HomeLayout.RunCashPos
	local size = HomeLayout.runCashSize()
	return RunLayout.rect(pos.X, pos.Y, size.X, size.Y, "Cash")
end

----------------------------------------------------------------------------------------------
-- Claim tray ("claimed this run"): left middle, below the compact Cash, above the thumbstick zone.

RunLayout.Tray = table.freeze({
	Thumb = 56,
	ThumbCompact = 46,
	Gap = 6,
	Header = 30,
})

export type TrayGeometry = {
	rect: Rect,
	columns: number,
	rows: number,
	thumb: number,
}

function RunLayout.trayGeometry(ctx: Ctx): TrayGeometry
	local T = RunLayout.Tray
	local d = RunLayout.design(ctx)
	local m = RunLayout.Margin
	local compact = ctx.screen:profile().kind == "Phone"
	local thumb = if compact then T.ThumbCompact else T.Thumb
	local columns = 2
	local rows = if compact then 1 else 2
	local w = math.max(columns * thumb + (columns - 1) * T.Gap, 128)
	local h = T.Header + rows * thumb + (rows - 1) * T.Gap
	-- left middle, centred around 45% height, kept above the thumbstick zone
	local cy = d.Y * 0.45
	local top = cy - h / 2
	local thumbstick = zone(ctx, "Thumbstick")
	if thumbstick then
		top = math.min(top, thumbstick.pos.Y - 6 - h)
	end
	local cash = RunLayout.cashRect(ctx)
	top = math.max(top, cash.pos.Y + cash.size.Y + 8)
	return {
		rect = RunLayout.rect(m, top, w, h, "ClaimTray"),
		columns = columns,
		rows = rows,
		thumb = thumb,
	}
end

function RunLayout.trayRect(ctx: Ctx): Rect
	return RunLayout.trayGeometry(ctx).rect
end

----------------------------------------------------------------------------------------------
-- Upper message row (district banner, milestones): under the strip, and under a run-time tutorial
-- banner if one is shown.

RunLayout.BannerH = 44
RunLayout.BannerHCompact = 36

function RunLayout.upperY(ctx: Ctx): number
	local strip = RunLayout.stripRect(ctx)
	local y = strip.pos.Y + strip.size.Y + 4
	-- Assumption: a run-time tutorial banner (Home worker's component) sits directly under the
	-- top of the safe area; the banner never stacks with it (DistrictBanner defers instead).
	return y
end
RunLayout.messageY = RunLayout.upperY -- legacy name

function RunLayout.bannerRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local compact = RunLayout.compact(ctx)
	local h = if compact then RunLayout.BannerHCompact else RunLayout.BannerH
	local w = math.min(if compact then 300 else 420, d.X - 2 * RunLayout.Margin)
	return RunLayout.rect(d.X / 2 - w / 2, RunLayout.upperY(ctx), w, h, "Banner")
end

----------------------------------------------------------------------------------------------
-- Side slot (capture ribbon): the left column outside the protected region.

function RunLayout.sideRect(ctx: Ctx): Rect
	local m = RunLayout.Margin
	local prot = RunLayout.protected(ctx)
	local profile = ctx.screen:profile()
	local phone = profile.kind == "Phone"
	-- phone landscape: at least 300 wide so YOU GOT THE KEYS! never truncates (it then reaches
	-- a little into the sky band of the protected region, not the road)
	local w = math.min(math.max(prot.pos.X - 2 * m, if phone then 300 else 0), 360)
	local h = if RunLayout.compact(ctx) then 78 else 96
	local banner = RunLayout.bannerRect(ctx)
	local top = banner.pos.Y + 2
	-- below the run-time top-row stats (phone landscape, tablet: HudPlayground setRunAnchor)
	if phone or profile.kind == "Tablet" then
		top = math.max(top, 80)
	end
	-- keep clear of the claim tray below it
	local tray = RunLayout.trayRect(ctx)
	if top + h > tray.pos.Y - 6 then
		top = math.max(RunLayout.cashRect(ctx).pos.Y + RunLayout.cashRect(ctx).size.Y + 4, tray.pos.Y - 6 - h)
	end
	return RunLayout.rect(m, top, w, h, "Side")
end

----------------------------------------------------------------------------------------------
-- Top stack publishing (legacy: RideChip reads it). DistrictStrip publishes the strip block.

export type Top = {
	row: number,
	distance: Rect, -- the strip block (its head + distance live inside it)
	cash: Rect,
	stackBottom: number,
	leftBottom: number,
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

function RunLayout.top(screen: any): Top
	local t = tops[screen]
	if t then
		return t
	end
	return {
		row = 1,
		distance = RunLayout.rect(0, 8, 0, 122),
		cash = RunLayout.rect(12, 12, 150, 32),
		stackBottom = 130,
		leftBottom = 44,
	}
end

----------------------------------------------------------------------------------------------
-- Placement of the run pieces

RunLayout.ChipSize = Vector2.new(220, 44)
function RunLayout.gearRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	-- the labelled red Settings rectangle (Arcade Small) replaced the 48 px gear
	local w = PreviewTokens.Arcade.Button.SmallW
	local g = RunLayout.Gear
	local r = RunLayout.rect(d.X - RunLayout.Margin - w, RunLayout.Margin, w, g + 4, "Options")
	-- narrow screens: below the district strip when they would touch
	local strip = RunLayout.stripRect(ctx)
	if RunLayout.overlaps(r, strip) then
		r = RunLayout.rect(r.pos.X, strip.pos.Y + strip.size.Y + 6, w, g + 4, "Options")
	end
	return r
end

-- The ride chip (legacy RideChip) under the gear; moved below the strip when they would touch.
function RunLayout.chipRect(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local m = RunLayout.Margin
	local s = RunLayout.ChipSize
	local gear = RunLayout.gearRect(ctx)
	local w = math.min(s.X, d.X - 2 * m)
	local r = RunLayout.rect(d.X - m - w, gear.pos.Y + gear.size.Y + 8, w, s.Y, "RideChip")
	local strip = RunLayout.stripRect(ctx)
	if RunLayout.overlaps(r, strip) then
		r = RunLayout.rect(d.X - m - w, strip.pos.Y + strip.size.Y + 6, w, s.Y, "RideChip")
	end
	return r
end

-- Everything at the top of the screen (Cash, strip, options, ride chip).
function RunLayout.topBlock(ctx: Ctx): Rect
	local d = RunLayout.design(ctx)
	local strip = RunLayout.stripRect(ctx)
	local cash = RunLayout.cashRect(ctx)
	local bottom = math.max(strip.pos.Y + strip.size.Y, cash.pos.Y + cash.size.Y)
	return RunLayout.rect(0, 0, d.X, bottom + 4, "TopStack")
end

-- Hop button (touch and desktop): bottom right; on touch beside (left of) the Roblox Jump zone,
-- else above it, else the corner. Never in a reserved zone or the protected region.
RunLayout.HopSize = Vector2.new(96, 96 + 4)
function RunLayout.hopRect(ctx: Ctx): (Rect, string?)
	local d = RunLayout.design(ctx)
	local size = RunLayout.HopSize
	local m = 8
	local jump = zone(ctx, "Jump")
	local candidates = {}
	if jump then
		local j = jump :: Rect
		local bottom = math.min(j.pos.Y + j.size.Y, d.Y - 4)
		table.insert(candidates, RunLayout.rect(j.pos.X - m - size.X, bottom - size.Y, size.X, size.Y, "Hop"))
		local cx = math.min(j.pos.X + j.size.X / 2, d.X - m - size.X / 2)
		table.insert(candidates, RunLayout.rect(cx - size.X / 2, j.pos.Y - m - size.Y, size.X, size.Y, "Hop"))
	end
	table.insert(
		candidates,
		RunLayout.rect(d.X - RunLayout.Margin - size.X, d.Y - RunLayout.Margin - size.Y, size.X, size.Y, "Hop")
	)
	return RunLayout.solve(ctx, candidates, { RunLayout.protected(ctx) })
end
RunLayout.HintSize = RunLayout.HopSize
RunLayout.hintRect = function(ctx: Ctx): Rect
	return (RunLayout.hopRect(ctx))
end

-- Heat (bottom centre; Round 2): the ORIGINAL ENGINE HEAT panel (RunHud.HeatGauge, 320 x 92 design px),
-- scaled to fit. Placement keeps it bottom-centre when it can: centred if clear; else shifted clear of
-- the thumbstick zone; else centred in the gap between the thumbstick zone and Hop; each tried at the
-- scales in HeatScales (1.0, then 0.92, then 0.89: the stage label stays at least 16.0 design px, the approved minimum). If even the
-- smallest scale does not fit clear of the (conservative, assumed) thumbstick zone, it is placed against
-- Hop with its left edge allowed to reach up to HeatSoftOverlap px into that zone and the rect reports the
-- conflict "ThumbstickSoft" (phone sizes only; recorded in the ledger). It never overlaps Hop.
RunLayout.HeatFull = Vector2.new(320, 92) -- HeatGauge.Size (kept in step by HeatPanel's debug check)
RunLayout.HeatScales = table.freeze({ 1, 0.92, 0.89 })
RunLayout.HeatSoftOverlap = 60
RunLayout.HeatCompact = Vector2.new(320 * 0.89, 92 * 0.89)
RunLayout.HeatBottomGap = 8
function RunLayout.heatRect(ctx: Ctx): (Rect, string?)
	local d = RunLayout.design(ctx)
	local hop = RunLayout.hopRect(ctx)
	local thumb = zone(ctx, "Thumbstick")
	local leftLimit = if thumb then thumb.pos.X + thumb.size.X + 6 else RunLayout.Margin
	local gapL, gapR = leftLimit, hop.pos.X - 6
	local candidates: { Rect } = {}
	for _, k in RunLayout.HeatScales do
		local size = RunLayout.HeatFull * k
		local y = d.Y - RunLayout.HeatBottomGap - size.Y
		table.insert(candidates, RunLayout.rect(d.X / 2 - size.X / 2, y, size.X, size.Y, "Heat"))
		table.insert(candidates, RunLayout.rect(math.max(leftLimit, d.X / 2 - size.X / 2), y, size.X, size.Y, "Heat"))
		if gapR - gapL >= size.X then
			table.insert(candidates, RunLayout.rect((gapL + gapR) / 2 - size.X / 2, y, size.X, size.Y, "Heat"))
		end
	end
	local found, conflict = RunLayout.solve(ctx, candidates, { hop })
	if conflict == nil then
		return found, nil
	end
	-- soft fallback (phone sizes): the smallest scale, right-aligned against Hop, reaching at most
	-- HeatSoftOverlap into the thumbstick zone
	local k = RunLayout.HeatScales[#RunLayout.HeatScales]
	local size = RunLayout.HeatFull * k
	local y = d.Y - RunLayout.HeatBottomGap - size.Y
	local x = math.max(gapR - size.X, leftLimit - RunLayout.HeatSoftOverlap)
	local r = RunLayout.rect(x, y, size.X, size.Y, "Heat")
	if RunLayout.overlaps(r, hop) then
		return r, "Hop"
	end
	return r, "ThumbstickSoft"
end

RunLayout.heatPanelRect = function(ctx: Ctx): Rect
	return (RunLayout.heatRect(ctx))
end

-- The static fallback for Keys (no rider part supplied, or it despawned): right of the
-- protected region in its lower half (the overnight KeysRing's approved relative location).
RunLayout.KeysSize = Vector2.new(150, 160)
function RunLayout.keysRect(ctx: Ctx): (Rect, string?)
	local d = RunLayout.design(ctx)
	local band = RunLayout.protected(ctx)
	local size = RunLayout.KeysSize
	local m = RunLayout.Margin
	local lowY = band.pos.Y + band.size.Y * 0.55
	local candidates = {
		centred(band.pos.X + band.size.X + m + size.X / 2, lowY, size, "Keys"),
		centred(band.pos.X + band.size.X + m + size.X / 2, band.pos.Y + band.size.Y * 0.35, size, "Keys"),
		centred(band.pos.X - m - size.X / 2, lowY, size, "Keys"),
		centred(d.X - 8 - size.X / 2, lowY, size, "Keys"),
	}
	local avoid = { band, RunLayout.topBlock(ctx), (RunLayout.hopRect(ctx)), (RunLayout.heatRect(ctx)) }
	return RunLayout.solve(ctx, candidates, avoid)
end

-- Foot Dash indicator (arc + DASH cue): left of the protected region in the lower third, else
-- beside Hop, else the left column under the tray.
RunLayout.DashSize = Vector2.new(84, 64 + 26)
function RunLayout.dashRect(ctx: Ctx): (Rect, string?)
	local d = RunLayout.design(ctx)
	local band = RunLayout.protected(ctx)
	local size = RunLayout.DashSize
	local m = RunLayout.Margin
	local hop = RunLayout.hopRect(ctx)
	local tray = RunLayout.trayRect(ctx)
	local lowY = math.min(band.pos.Y + band.size.Y * 0.7, d.Y - m - size.Y / 2)
	local candidates = {
		centred(band.pos.X - m - size.X / 2, lowY, size, "Dash"),
		centred(hop.pos.X - m - size.X / 2, hop.pos.Y + hop.size.Y / 2, size, "Dash"),
		centred(hop.pos.X + hop.size.X / 2, hop.pos.Y - m - size.Y / 2, size, "Dash"),
		centred(m + size.X / 2, tray.pos.Y + tray.size.Y + m + size.Y / 2, size, "Dash"),
	}
	local avoid = { band, (RunLayout.heatRect(ctx)), RunLayout.topBlock(ctx), tray, hop }
	return RunLayout.solve(ctx, candidates, avoid)
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

-- Converts an absolute (GUI) position into design px on `canvas` (a RunLayout canvas).
function RunLayout.absToCanvas(canvas: GuiObject, abs: Vector2, ctx: Ctx): Vector2
	local d = RunLayout.design(ctx)
	local size = canvas.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return Vector2.zero
	end
	return (abs - canvas.AbsolutePosition) / size * d
end

return RunLayout
