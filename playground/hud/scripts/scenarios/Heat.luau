--!strict
-- PLAYGROUND ONLY (Lane 3 preview, Round 3 worker W5, ledger R3-H): the ORIGINAL ENGINE HEAT panel's placement, scale
-- and coverage. Every value is a synthetic fixture played through the preview store; no remotes, saves, rewards or
-- purchases. The panel is Adam's approved HeatGauge, scaled uniformly and anchored; these scenarios measure where it
-- ends up. Results are real PASS / FAIL lines; the table lines start with HEATROW, HEATPROT, HEATSTAGE, HEATZONE,
-- HEATHOP, HEATALT and HEATMETHOD so the lead can grep and paste them.
--
-- How coverage is measured (the same method on every frame, in DEVICE px relative to the device frame):
--   panel     = everything the panel draws at rest (Calm): the card with its outline and shadow AND the title tab that
--               rises above it (RunLayout.heatRects(ctx, "Calm")); a stage adds its growth, halo, sirens and smoke.
--   protected = RunLayout.protectedRect(profile): the proposed road-ahead rectangle (fractions of the safe area).
--   roadOverlapPct   = area(panel intersect protected) / area(protected)      <- the headline figure (denominator: the road)
--   panelInsideRoadPct = area(panel intersect protected) / area(panel)       <- the other denominator Round 2 also quoted
--   Areas are exact unions (overlapping pieces are not counted twice). The rectangles are a model of what HeatGauge draws;
--   every frame the model is checked against the live instances (MEASURED PANEL), and the alarm model against the live
--   halo, sirens, title tab and smoke puffs (the alarm scenario).
--   centreOffsetPx = the live card's centre minus the full viewport's centre (device px). thumbOverlapPx = how far the panel
--   box reaches into the assumed Thumbstick zone horizontally (device px; the panel takes no input, so it is visual only).
--
-- Scenarios: coverage table (all frames) | centring through resize, mode change and alarm | reduced motion and HOP NOW! |
-- one original panel, build and destroy leave nothing | diagnostic overlay (toggle) | diagnostic overlay tour.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local UI = Prototype.Parent :: Instance
local Motion = require(Prototype:WaitForChild("Motion"))
local RunLayout = require(Prototype:WaitForChild("Run"):WaitForChild("RunLayout"))
local HeatPanelModule = require(Prototype:WaitForChild("Run"):WaitForChild("HeatPanel"))
local HeatGauge = require(UI:WaitForChild("RunHud"):WaitForChild("HeatGauge"))
local AlarmClock = require(UI:WaitForChild("AlarmClock"))

type Host = { [string]: any }
type Rect = { pos: Vector2, size: Vector2, name: string? } -- RunLayout.Rect (RunLayout is required by path, so untyped here)

local DIAG = "HeatDiag" -- name prefix of every debug outline this file creates
local SEQUENCE = { { 0.3, "Calm" }, { 0.7, "Warning" }, { 0.9, "Critical" }, { 1, "Meltdown" } }
-- Round 2's figures, kept as a HISTORICAL reference only (card alone, Round 2 placement and scales 1.0/0.92/0.89, the
-- share of the protected rectangle). They are not a baseline this round has to equal.
local HISTORY: { [string]: string } = {
	Desktop = "0%",
	Tablet = "6%",
	PhoneLandscape = "22%",
	PhoneSmall = "30%",
	PhoneLandscapeLeft = "21-23%",
	PhoneLandscapeRight = "21-23%",
}

local tally = { pass = 0, fail = 0 }
local diagConnection: any = nil

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	if ok then
		tally.pass += 1
	else
		tally.fail += 1
	end
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function finish(host: Host, title: string)
	host.log(string.format("%s: %d PASS, %d FAIL", title, tally.pass, tally.fail))
end

local function heatPanel(host: Host): any
	local panel = host.api.components and host.api.components.heat
	if not panel then
		tally.fail += 1
		host.log('FAIL Heat panel not mounted: add mount("heat", { "Run", "HeatPanel" }, "Run")')
	end
	return panel
end

-- RunLayout only reads store and screen from a context.
local function ctxOf(host: Host): any
	return { store = host.store, screen = host.api.screen }
end

-- A clean run (a new run state, Heat Calm) with the preview reduced-motion override cleared.
local function freshRun(host: Host)
	Motion.setOverride(nil)
	if host.store:get().mode == "Run" then
		host.store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.3)
end

local function setHeat(host: Host, heat: number, stage: string)
	host.runPatch({ heat = heat, stage = stage })
end

local function clearField(host: Host, field: string)
	local run = host.store:get().run
	if run then
		local n = table.clone(run) :: any
		n[field] = nil
		host.store:set("run", n)
	end
end

local function liveRect(host: Host, g: GuiObject): Rect
	local pos, size = host.api.screen:rectOf(g)
	return RunLayout.rect(pos.X, pos.Y, size.X, size.Y)
end

local function toDevice(ctx: any, list: { Rect }): { Rect }
	local out: { Rect } = {}
	for _, r in list do
		local pos, size = RunLayout.toDevice(ctx, r)
		table.insert(out, RunLayout.rect(pos.X, pos.Y, size.X, size.Y, r.name))
	end
	return out
end

local function boxOf(list: { Rect }): Rect
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, r in list do
		x0, y0 = math.min(x0, r.pos.X), math.min(y0, r.pos.Y)
		x1, y1 = math.max(x1, r.pos.X + r.size.X), math.max(y1, r.pos.Y + r.size.Y)
	end
	return RunLayout.rect(x0, y0, x1 - x0, y1 - y0)
end

-- Exact area of the union of `list`, optionally clipped to `clip` (coordinate compression: the lists are short).
local function unionArea(list: { Rect }, clip: Rect?): number
	local boxes: { { number } } = {}
	local xs: { number } = {}
	local ys: { number } = {}
	for _, r in list do
		local x0, y0, x1, y1 = r.pos.X, r.pos.Y, r.pos.X + r.size.X, r.pos.Y + r.size.Y
		if clip then
			x0, y0 = math.max(x0, clip.pos.X), math.max(y0, clip.pos.Y)
			x1, y1 = math.min(x1, clip.pos.X + clip.size.X), math.min(y1, clip.pos.Y + clip.size.Y)
		end
		if x1 > x0 and y1 > y0 then
			table.insert(boxes, { x0, y0, x1, y1 })
			table.insert(xs, x0)
			table.insert(xs, x1)
			table.insert(ys, y0)
			table.insert(ys, y1)
		end
	end
	table.sort(xs)
	table.sort(ys)
	local area = 0
	for i = 1, #xs - 1 do
		for j = 1, #ys - 1 do
			local w, h = xs[i + 1] - xs[i], ys[j + 1] - ys[j]
			if w > 0 and h > 0 then
				local cx, cy = xs[i] + w / 2, ys[j] + h / 2
				for _, b in boxes do
					if cx > b[1] and cx < b[3] and cy > b[2] and cy < b[4] then
						area += w * h
						break
					end
				end
			end
		end
	end
	return area
end

type Cover = { road: number, inside: number, area: number, box: Rect }

-- The two coverage figures for the panel in `stage` (device px, protected rectangle `prot`).
local function cover(ctx: any, stage: string, plan: any, prot: Rect): Cover
	local rects = toDevice(ctx, RunLayout.heatRects(ctx, stage, plan))
	local inter = unionArea(rects, prot)
	local area = unionArea(rects, nil)
	return {
		road = 100 * inter / (prot.size.X * prot.size.Y),
		inside = if area > 0 then 100 * inter / area else 0,
		area = area,
		box = boxOf(rects),
	}
end

local function zoneRect(profile: any, name: string): Rect?
	for _, z in profile.zones do
		if z.name == name then
			return RunLayout.rect(z.position.X, z.position.Y, z.size.X, z.size.Y, name)
		end
	end
	return nil
end

-- Live items that stick out of the card in an alarm, for the model check: each must lie inside the model rectangle of the
-- same kind (a tolerance of 2 device px covers whole-pixel UDim offsets).
local function liveEffects(panel: any): { { kind: string, gui: GuiObject } }
	local out: { { kind: string, gui: GuiObject } } = {}
	for _, d in panel:parts().root:GetDescendants() do
		if d:IsA("GuiObject") then
			local kind: string? = nil
			if d.Name == "Halo" then
				kind = "Halo"
			elseif d.Name == "Glow" then
				kind = "Siren"
			elseif d.Name == "TitleTab" then
				kind = "Tab"
			elseif string.match(d.Name, "^Smoke%d$") then
				kind = "Smoke"
			end
			if kind and (kind == "Tab" or d.BackgroundTransparency < 0.97) then
				table.insert(out, { kind = kind, gui = d })
			end
		end
	end
	return out
end

-- How many visible live effects there are and how many lie outside the model (and by how much, device px, at worst).
local function containment(host: Host, panel: any, ctx: any, plan: any, stage: string): (number, number, number)
	local model = toDevice(ctx, RunLayout.heatRects(ctx, stage, plan))
	local tol = 2
	local checked, outside, worst = 0, 0, 0
	for _, item in liveEffects(panel) do
		checked += 1
		local live = liveRect(host, item.gui)
		local best = math.huge
		for _, m in model do
			if m.name == item.kind then
				local over = math.max(
					m.pos.X - live.pos.X,
					m.pos.Y - live.pos.Y,
					live.pos.X + live.size.X - (m.pos.X + m.size.X),
					live.pos.Y + live.size.Y - (m.pos.Y + m.size.Y)
				)
				best = math.min(best, over)
			end
		end
		if best > tol then
			outside += 1
		end
		if best ~= math.huge then
			worst = math.max(worst, best)
		end
	end
	return checked, outside, worst
end

-- Everything about one frame; prints the table lines. Returns nothing: the verdicts carry the result.
local function frameReport(host: Host, panel: any, name: string)
	local screen = host.api.screen
	local ctx = ctxOf(host)
	local profile = screen:profile()
	local s = screen:uiScale()
	local design = RunLayout.design(ctx)
	local plan = RunLayout.heatPlan(ctx)
	local parts = panel:parts()
	local card = liveRect(host, parts.card)
	local tab = liveRect(host, parts.tab)
	local f = card.size.X / RunLayout.HeatFull.X -- live device px per panel px
	local liveScale = f / s
	local liveCentre = card.pos.X + card.size.X / 2
	local chosen = profile.insets.left + plan.centre * s
	local centreOff = liveCentre - profile.size.X / 2
	local safeCentre = profile.insets.left + (profile.size.X - profile.insets.left - profile.insets.right) / 2
	local protRect = RunLayout.protectedRect(profile)
	local protArea = protRect.size.X * protRect.size.Y

	-- 1. centre: the live card sits on the chosen centre (the full viewport's centre unless the safe area pulled it)
	verdict(
		host,
		name .. ": centred",
		math.abs(liveCentre - chosen) <= 1,
		string.format(
			"live centre %.2f, chosen %.2f, full-viewport centre %.2f (offset %.2f px), safe-area centre %.2f (differs %.1f px), pulled %.2f px",
			liveCentre,
			chosen,
			profile.size.X / 2,
			centreOff,
			safeCentre,
			safeCentre - profile.size.X / 2,
			plan.pulled * s
		)
	)

	-- 2. scale: the stated rule, and the live panel really has it
	local floorK = RunLayout.HeatTextFloor / (RunLayout.HeatSmallestText * s)
	verdict(
		host,
		name .. ": scale in range",
		plan.scale >= floorK - 0.002 and plan.scale <= 1.0001 and math.abs(liveScale - plan.scale) < 0.005,
		string.format(
			"scale %.3f (floor %.3f, max 1, live %.3f), HudScale %.2f, conflict %s",
			plan.scale,
			floorK,
			liveScale,
			s,
			tostring(plan.conflict)
		)
	)

	-- 3. text: the title tab (16 design px) and the stage label (18) in REAL device px at Calm
	local titlePx = RunLayout.HeatSmallestText * f
	local labelPx = RunLayout.HeatLabelText * f
	local title: any = parts.title
	local label: any = parts.label
	verdict(
		host,
		name .. ": text at least 16 px real",
		titlePx >= 15.95
			and labelPx >= 15.95
			and title ~= nil
			and title.TextSize == RunLayout.HeatSmallestText
			and label ~= nil
			and label.TextSize == RunLayout.HeatLabelText,
		string.format(
			"title %.2f px, stage label %.2f px, HOP NOW! %.2f px (TextSize %s / %s)",
			titlePx,
			labelPx,
			labelPx,
			tostring(title and title.TextSize),
			tostring(label and label.TextSize)
		)
	)

	-- 4. the model of the panel's shape matches the live instances (card, outline, shadow, title tab)
	local shadow: any = parts.body and parts.body:FindFirstChild("Shadow")
	local shadowRect = if shadow and shadow:IsA("GuiObject") then liveRect(host, shadow) else nil
	local shadowBottom = if shadowRect then shadowRect.pos.Y + shadowRect.size.Y else card.pos.Y + card.size.Y + 4 * f
	local steady = toDevice(ctx, RunLayout.heatRects(ctx, "Calm", plan))
	local steadyBox = boxOf(steady)
	local liveLeft, liveTop = card.pos.X - 3 * f, tab.pos.Y - 3 * f
	local liveRight, liveBottom = card.pos.X + card.size.X + 3 * f, shadowBottom
	local worstEdge = math.max(
		math.abs(steadyBox.pos.X - liveLeft),
		math.abs(steadyBox.pos.Y - liveTop),
		math.abs(steadyBox.pos.X + steadyBox.size.X - liveRight),
		math.abs(steadyBox.pos.Y + steadyBox.size.Y - liveBottom)
	)
	verdict(
		host,
		name .. ": measured panel matches the model",
		worstEdge <= 1.5,
		string.format(
			"model box (%.1f, %.1f, %.1f, %.1f) vs live (%.1f, %.1f, %.1f, %.1f), worst edge %.2f px",
			steadyBox.pos.X,
			steadyBox.pos.Y,
			steadyBox.size.X,
			steadyBox.size.Y,
			liveLeft,
			liveTop,
			liveRight - liveLeft,
			liveBottom - liveTop,
			worstEdge
		)
	)

	-- 5. inside the safe bounds in every stage (the alarm halo is decoration: reported, not judged)
	local insideAll = true
	local haloOut = 0
	for _, stage in { "Calm", "Warning", "Critical", "Meltdown" } do
		for _, r in RunLayout.heatRects(ctx, stage, plan) do
			if r.name == "Halo" then
				haloOut = math.max(haloOut, (r.pos.Y + r.size.Y - design.Y) * s)
			elseif not RunLayout.inside(r, design) then
				insideAll = false
			end
		end
	end
	verdict(
		host,
		name .. ": panel inside the safe bounds",
		insideAll,
		string.format(
			"card, outline, title tab, sirens and smoke in every stage inside the safe area; alarm halo (decoration) reaches %.1f px below it",
			math.max(0, haloOut)
		)
	)

	-- 6. clear of Hop in every stage (the growth cap does this) and the Hop gap
	local hop = RunLayout.hopRect(ctx)
	local meltCard = RunLayout.heatRects(ctx, "Meltdown", plan)[1]
	local gap = (hop.pos.X - (meltCard.pos.X + meltCard.size.X)) * s
	verdict(
		host,
		name .. ": clear of Hop",
		not RunLayout.overlaps(meltCard, hop),
		string.format(
			"gap to Hop at the largest growth %.1f px (growth capped at %.3f), conflict %s",
			gap,
			plan.maxGrowth,
			tostring(plan.conflict)
		)
	)

	-- 7. the table lines
	local steadyCover = cover(ctx, "Calm", plan, protRect)
	local thumbDepth, thumbArea = 0, 0
	local thumb = zoneRect(profile, "Thumbstick")
	if thumb then
		if RunLayout.overlaps(steadyCover.box, thumb) then
			thumbDepth = math.min(steadyCover.box.pos.X + steadyCover.box.size.X, thumb.pos.X + thumb.size.X)
				- math.max(steadyCover.box.pos.X, thumb.pos.X)
		end
		thumbArea = unionArea(steady, thumb)
	end
	host.log(
		string.format(
			"HEATROW|%s|%.3f|%.1f|%.1f|%.1f|%.1f|%.2f|%.1f|%.1f|%.1f",
			name,
			liveScale,
			steadyCover.box.pos.X,
			steadyCover.box.pos.Y,
			steadyCover.box.size.X,
			steadyCover.box.size.Y,
			centreOff,
			steadyCover.road,
			steadyCover.inside,
			thumbDepth
		)
	)
	host.log(
		string.format(
			"HEATPROT|%s|protected x %.1f y %.1f w %.1f h %.1f (device px) | panel area %.0f px2, protected area %.0f px2 | Round 2 reported (card only, other placement) %s",
			name,
			protRect.pos.X,
			protRect.pos.Y,
			protRect.size.X,
			protRect.size.Y,
			steadyCover.area,
			protArea,
			HISTORY[name] or "?"
		)
	)
	local zoneNote = "none (no reserved zones on this frame)"
	if thumb then
		zoneNote = string.format(
			"Thumbstick %.1f px deep, %.0f px2 = %.1f%% of the panel (visual only: the panel takes no input)",
			thumbDepth,
			thumbArea,
			if steadyCover.area > 0 then 100 * thumbArea / steadyCover.area else 0
		)
	end
	host.log(string.format("HEATZONE|%s|%s", name, zoneNote))
	host.log(
		string.format(
			"HEATHOP|%s|Hop at x %.1f y %.1f (design px); gap from the card at rest %.1f px, at the largest growth %.1f px",
			name,
			hop.pos.X,
			hop.pos.Y,
			(hop.pos.X - (plan.card.pos.X + plan.card.size.X)) * s,
			gap
		)
	)
	for _, stage in { "Warning", "Critical", "Meltdown" } do
		local c = cover(ctx, stage, plan, protRect)
		host.log(
			string.format(
				"HEATSTAGE|%s|%s|growth %.3f|roadOverlapPct %.1f|panelInsideRoadPct %.1f|top y %.1f",
				name,
				stage,
				math.min(RunLayout.HeatStageScale[stage] or 1, plan.maxGrowth),
				c.road,
				c.inside,
				c.box.pos.Y
			)
		)
	end
	for _, k in { 1, 0.92, 0.89 } do
		local alt = RunLayout.heatPlan(ctx, k)
		local c = cover(ctx, "Calm", alt, protRect)
		local cardOnly = unionArea(toDevice(ctx, { alt.card }), protRect)
		host.log(
			string.format(
				"HEATALT|%s|scale %.2f|title %.2f px|roadOverlapPct %.1f (with title tab and outline) / %.1f (card only, Round 2's way)",
				name,
				k,
				alt.title,
				c.road,
				100 * cardOnly / protArea
			)
		)
	end
end

-- The live card's centre minus the chosen centre (device px).
local function centreError(host: Host, panel: any): number
	local screen = host.api.screen
	local profile = screen:profile()
	local plan = RunLayout.heatPlan(ctxOf(host))
	local card = liveRect(host, panel:parts().card)
	return card.pos.X + card.size.X / 2 - (profile.insets.left + plan.centre * screen:uiScale())
end

----------------------------------------------------------------------------------------------
-- Debug overlay: outlines (never child-facing; a harness aid for screenshots)

local function clearOutlines(host: Host)
	for _, child in host.api.screen.root:GetChildren() do
		if string.sub(child.Name, 1, #DIAG) == DIAG then
			child:Destroy()
		end
	end
end

local function outline(parent: Instance, name: string, r: Rect, colour: Color3, text: string?)
	local f = Instance.new("Frame")
	f.Name = DIAG .. name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	f.Position = UDim2.fromOffset(r.pos.X, r.pos.Y)
	f.Size = UDim2.fromOffset(r.size.X, r.size.Y)
	f.ZIndex = 90
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	if text then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0, 1)
		label.Size = UDim2.fromOffset(260, 16)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 14
		label.TextColor3 = colour
		label.TextStrokeTransparency = 0.3
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.ZIndex = 91
		label.Parent = f
	end
	f.Parent = parent
end

-- Protected road rectangle (magenta), the live measured panel with its title tab (green), the model's Meltdown reach
-- (orange), the full-viewport centre (cyan) and the safe-area centre (yellow). Everything is in device px.
local function buildOutlines(host: Host)
	local screen = host.api.screen
	clearOutlines(host)
	local panel = host.api.components and host.api.components.heat
	if not panel then
		return
	end
	local ctx = ctxOf(host)
	local profile = screen:profile()
	local plan = RunLayout.heatPlan(ctx)
	outline(
		screen.root,
		"Protected",
		RunLayout.protectedRect(profile),
		Color3.fromRGB(255, 70, 210),
		"PROTECTED ROAD (debug outline)"
	)
	local parts = panel:parts()
	if parts.card and parts.tab and panel:getDebugState().shown then
		local card = liveRect(host, parts.card)
		local tab = liveRect(host, parts.tab)
		local f = card.size.X / RunLayout.HeatFull.X
		local top, bottom = tab.pos.Y - 3 * f, card.pos.Y + card.size.Y + 4 * f
		outline(
			screen.root,
			"Measured",
			RunLayout.rect(card.pos.X - 3 * f, top, card.size.X + 6 * f, bottom - top),
			Color3.fromRGB(80, 255, 120),
			"MEASURED PANEL with title tab (live)"
		)
	end
	local reach = boxOf(toDevice(ctx, RunLayout.heatRects(ctx, "Meltdown", plan)))
	outline(screen.root, "Reach", reach, Color3.fromRGB(255, 160, 30), "MELTDOWN REACH (model)")
	local safeCentre = profile.insets.left + (profile.size.X - profile.insets.left - profile.insets.right) / 2
	local line = Color3.fromRGB(70, 220, 255)
	outline(screen.root, "ViewportCentre", RunLayout.rect(profile.size.X / 2 - 1, 0, 2, profile.size.Y), line, nil)
	outline(
		screen.root,
		"SafeCentre",
		RunLayout.rect(safeCentre - 1, 0, 2, profile.size.Y),
		Color3.fromRGB(255, 235, 70),
		nil
	)
	screen:showReserved(true)
end

local function overlayOff(host: Host)
	if diagConnection then
		diagConnection:Disconnect()
		diagConnection = nil
	end
	clearOutlines(host)
	host.api.screen:showReserved(false)
end

----------------------------------------------------------------------------------------------
-- Scenarios

local S: { [string]: (Host) -> () } = {}

-- R3-H: placement, scale and coverage on every frame; prints the HEATROW table lines.
S["Heat: placement, scale and coverage (all frames)"] = function(host)
	tally.pass, tally.fail = 0, 0
	freshRun(host)
	local panel = heatPanel(host)
	if not panel then
		return
	end
	local start = host.api.screen:profile().name
	setHeat(host, 0.2, "Calm")
	host.log(
		"HEATMETHOD|roadOverlapPct = area(panel incl. title tab and outline, intersect protected road) / area(protected road); panelInsideRoadPct = the same intersection / area(panel); device px; Round 2 quoted the first figure for the card alone (its numbers are on the HEATPROT lines)"
	)
	host.log("HEATROW|frame|scale|x|y|w|h|centreOffsetPx|roadOverlapPct|panelInsideRoadPct|thumbOverlapPx")
	for _, name in host.api.profiles do
		host.api.setProfile(name)
		host.wait(0.7)
		frameReport(host, panel, name)
	end
	host.api.setProfile(start)
	finish(host, "Heat coverage")
end

-- R3-H: the centre survives a resize cycle, mode changes and the whole alarm; the shake restores exactly.
S["Heat: centring holds through resize, mode change and alarm"] = function(host)
	tally.pass, tally.fail = 0, 0
	freshRun(host)
	local panel = heatPanel(host)
	if not panel then
		return
	end
	local screen = host.api.screen
	local ctx = ctxOf(host)
	local names: { string } = host.api.profiles
	local start = screen:profile().name

	-- A. the anchor of every frame, as first laid out
	local rest: { [string]: any } = {}
	for _, name in names do
		host.api.setProfile(name)
		host.wait(0.3)
		local p = panel:parts()
		rest[name] = {
			slot = p.slot.Position,
			size = p.slot.Size,
			root = p.root.Position,
			scale = panel:getDebugState().scale,
		}
		verdict(
			host,
			name .. ": centred after layout",
			math.abs(centreError(host, panel)) <= 1,
			string.format("%.2f px from the chosen centre", centreError(host, panel))
		)
	end

	-- B. twenty layouts with changing profiles (every third also a viewport-resize notification), then back
	local drift, worst = 0, 0
	for i = 1, 20 do
		local name = names[(i * 5) % #names + 1]
		host.api.setProfile(name)
		if i % 3 == 0 then
			screen.Changed:Fire(screen:profile())
		end
		panel:layout()
		local p = panel:parts()
		local r = rest[name]
		if
			p.slot.Position ~= r.slot
			or p.slot.Size ~= r.size
			or p.root.Position ~= r.root
			or panel:getDebugState().scale ~= r.scale
		then
			drift += 1
		end
		host.wait(0.1)
		worst = math.max(worst, math.abs(centreError(host, panel)))
	end
	host.api.setProfile(start)
	host.wait(0.4)
	verdict(
		host,
		"resize cycle: anchor, size and scale unchanged",
		drift == 0,
		string.format("%d of 20 layouts differed from the first layout of that frame", drift)
	)
	verdict(
		host,
		"resize cycle: still centred",
		worst <= 1 and math.abs(centreError(host, panel)) <= 1,
		string.format(
			"worst %.2f px during the cycle, %.2f px after returning to %s",
			worst,
			centreError(host, panel),
			start
		)
	)

	-- C. Home and Run transitions
	local before = panel:parts().slot.Position
	local stable = true
	for i = 1, 3 do
		host.store:setMode("Home")
		host.wait(0.4)
		local hidden = panel:getDebugState()
		if hidden.shown ~= false or panel:parts().slot.Position ~= before then
			stable = false
		end
		host.enterRun()
		host.wait(0.5)
		local shown = panel:getDebugState()
		if shown.shown ~= true or panel:parts().slot.Position ~= before or math.abs(centreError(host, panel)) > 1 then
			stable = false
		end
		host.log(
			string.format(
				"mode round trip %d: hidden %s, shown again %s",
				i,
				tostring(hidden.shown),
				tostring(shown.shown)
			)
		)
	end
	verdict(host, "Home and Run transitions: hidden, shown, anchor and centre unchanged", stable, "three round trips")

	-- D. the alarm on every frame: nothing moves, growth follows the cap, effects stay inside the model, the shake restores
	for _, name in names do
		host.api.setProfile(name)
		host.wait(0.4)
		local plan = RunLayout.heatPlan(ctx)
		local p = panel:parts()
		local anchor, rootPos = p.slot.Position, p.root.Position
		local maxErr, moved, maxShake, growthBad = 0, false, 0, 0
		local checked, outside, over = 0, 0, 0
		local bumped = false
		setHeat(host, 0.1, "Calm")
		host.wait(0.6)
		for _, step in SEQUENCE do
			local stage = step[2] :: string
			setHeat(host, step[1] :: number, stage)
			local hold = if stage == "Meltdown" then 2.2 elseif stage == "Critical" then 1.4 else 1.0
			local t = 0
			while t < hold do
				host.wait(0.2)
				t += 0.2
				local dbg = panel:getDebugState()
				maxErr = math.max(maxErr, math.abs(centreError(host, panel)))
				if panel:parts().slot.Position ~= anchor or panel:parts().root.Position ~= rootPos then
					moved = true
				end
				maxShake = math.max(maxShake, math.abs(dbg.shakeX) + math.abs(dbg.shakeY))
				if stage == "Critical" and not bumped and t >= 0.4 then
					bumped = true
					host.emit("HeatBump", { amount = 1 })
				end
				if t >= 0.8 then
					local want = math.min(RunLayout.HeatStageScale[stage] or 1, plan.maxGrowth)
					if math.abs(dbg.stageScale - want) > 0.01 then
						growthBad += 1
					end
				end
				if t >= 0.6 and (stage == "Critical" or stage == "Meltdown") then
					local c, o, w = containment(host, panel, ctx, plan, stage)
					checked, outside, over = checked + c, outside + o, math.max(over, w)
				end
			end
		end
		setHeat(host, 0, "Calm") -- the Hop reset
		host.wait(1.6)
		local d = panel:getDebugState()
		verdict(
			host,
			name .. ": alarm never moves the anchor",
			not moved and panel:parts().slot.Position == anchor and panel:parts().root.Position == rootPos,
			string.format("slot and root Position identical at every sample (%s)", d.slotPosition)
		)
		verdict(
			host,
			name .. ": centred through every stage",
			maxErr <= 1,
			string.format(
				"worst %.2f px from the chosen centre over Calm, Warning, Critical (with a bump), Meltdown",
				maxErr
			)
		)
		verdict(
			host,
			name .. ": growth follows the cap",
			growthBad == 0,
			string.format("max growth %.3f; %d settled samples off by more than 0.01", plan.maxGrowth, growthBad)
		)
		verdict(
			host,
			name .. ": live effects inside the model",
			checked > 0 and outside == 0,
			string.format(
				"%d live halo, siren, tab and smoke samples, %d outside (worst overshoot %.1f px, tolerance 2)",
				checked,
				outside,
				over
			)
		)
		verdict(
			host,
			name .. ": shake restores exactly",
			d.shakeX == 0
				and d.shakeY == 0
				and d.capLiftX == 0
				and d.capLiftY == 0
				and d.stageScale == 1
				and d.alarm == 0
				and d.melt == 0
				and d.alarmRate == 0
				and (maxShake > 0 or Motion.reduced()),
			string.format(
				"after the reset: shake %s,%s cap lift %s,%s stageScale %s alarm %s melt %s rate %s; largest shake seen %.1f px",
				tostring(d.shakeX),
				tostring(d.shakeY),
				tostring(d.capLiftX),
				tostring(d.capLiftY),
				tostring(d.stageScale),
				tostring(d.alarm),
				tostring(d.melt),
				tostring(d.alarmRate),
				maxShake
			)
		)
	end
	host.api.setProfile(start)
	finish(host, "Heat centring")
end

-- R3-H: reduced motion, and the HOP NOW! interactions (hidden without a Hop, as in Round 2).
S["Heat: reduced motion and HOP NOW!"] = function(host)
	tally.pass, tally.fail = 0, 0
	freshRun(host)
	local panel = heatPanel(host)
	if not panel then
		return
	end
	-- Meltdown, motion on: HOP NOW! shows while a Hop is possible
	setHeat(host, 1, "Meltdown")
	host.wait(2.0)
	local d = panel:getDebugState()
	verdict(
		host,
		"Meltdown with a Hop possible shows HOP NOW!",
		d.stage == "Meltdown" and d.hopNowShown == true and d.hopFits == true,
		string.format(
			"stage %s, HOP NOW! shown %s, fits %s",
			tostring(d.stage),
			tostring(d.hopNowShown),
			tostring(d.hopFits)
		)
	)
	-- zero Stamina: hidden; Stamina back: shown
	host.runPatch({ stamina = { value = 0, max = 10, lowAt = 3, restore = false } })
	host.wait(0.4)
	verdict(host, "HOP NOW! hidden at zero Stamina", panel:getDebugState().hopNowShown == false, "Stamina value 0")
	host.runPatch({ stamina = { value = 3, max = 10, lowAt = 3, restore = false } })
	host.wait(0.4)
	verdict(
		host,
		"HOP NOW! shown again when a Hop is possible",
		panel:getDebugState().hopNowShown == true,
		"Stamina value 3"
	)
	clearField(host, "stamina")
	host.wait(0.3)
	-- off the car: hidden
	host.emit("Dismounted", { reason = "Overheated" })
	host.wait(0.4)
	d = panel:getDebugState()
	verdict(
		host,
		"HOP NOW! hidden once the rider is off the car",
		d.hopNowShown == false and d.ended == true,
		string.format("shown %s, ended %s", tostring(d.hopNowShown), tostring(d.ended))
	)

	-- reduced motion (preview override): everything decorative is still, essential styling stays
	freshRun(host)
	Motion.setOverride(true)
	host.wait(0.8)
	local anchor = panel:parts().slot.Position
	setHeat(host, 0.9, "Critical")
	host.wait(1.5)
	host.emit("HeatBump", { amount = 1 })
	host.wait(0.4)
	d = panel:getDebugState()
	verdict(
		host,
		"reduced motion, Critical: styled but still",
		d.reducedMotion == true
			and d.stage == "Critical"
			and d.alarm > 0
			and d.alarmRate == 0
			and d.shakeX == 0
			and d.shakeY == 0
			and d.bumpActive == false,
		string.format(
			"alarm styling %.2f, clock rate %s, shake %s,%s, bump active %s",
			d.alarm,
			tostring(d.alarmRate),
			tostring(d.shakeX),
			tostring(d.shakeY),
			tostring(d.bumpActive)
		)
	)
	setHeat(host, 1, "Meltdown")
	host.wait(1.5)
	d = panel:getDebugState()
	verdict(
		host,
		"reduced motion, Meltdown: full styling, no pulse, HOP NOW! steady",
		d.reducedMotion == true
			and d.melt == 1
			and d.alarmRate == 0
			and d.hopPulse == 1
			and d.shakeX == 0
			and d.shakeY == 0
			and d.hopNowShown == true,
		string.format(
			"melt %s, rate %s, HOP NOW! pulse %s, shake %s,%s, shown %s",
			tostring(d.melt),
			tostring(d.alarmRate),
			tostring(d.hopPulse),
			tostring(d.shakeX),
			tostring(d.shakeY),
			tostring(d.hopNowShown)
		)
	)
	verdict(
		host,
		"reduced motion: centred and the anchor unmoved",
		math.abs(centreError(host, panel)) <= 1 and panel:parts().slot.Position == anchor,
		string.format("%.2f px from the chosen centre", centreError(host, panel))
	)
	Motion.setOverride(nil)
	host.wait(0.8)
	setHeat(host, 0, "Calm")
	host.wait(1.2)
	d = panel:getDebugState()
	verdict(
		host,
		"override cleared: the panel follows the Roblox setting again",
		d.reducedMotion == Motion.reduced(),
		string.format("panel %s, setting %s", tostring(d.reducedMotion), tostring(Motion.reduced()))
	)
	finish(host, "Heat reduced motion and HOP NOW!")
end

-- R3-H: one mounted panel built from the original module; a second one built and destroyed leaves nothing behind.
S["Heat: one original panel, build and destroy leave nothing"] = function(host)
	tally.pass, tally.fail = 0, 0
	freshRun(host)
	local panel = heatPanel(host)
	if not panel then
		return
	end
	local d = panel:getDebugState()
	verdict(
		host,
		"exactly one HeatGauge is mounted",
		d.gauges == 1 and d.original == true,
		string.format("%s instance(s) named HeatGauge under the panel", tostring(d.gauges))
	)
	verdict(
		host,
		"the original module's size, thresholds and words are unchanged",
		HeatGauge.Size == RunLayout.HeatFull
			and HeatGauge.Thresholds.Warning == 0.6
			and HeatGauge.Thresholds.Critical == 0.85
			and HeatGauge.Labels.Calm == "Cool"
			and HeatGauge.Labels.Warning == "Hot"
			and HeatGauge.Labels.Critical == "Too hot!"
			and HeatGauge.Labels.Meltdown == "Losing control!"
			and d.sizeMatches == true
			and d.textMatches == true,
		"320 x 92, thresholds 0.6 / 0.85, labels Cool, Hot, Too hot!, Losing control! (the byte comparison with main is a git check, reported separately)"
	)
	verdict(
		host,
		"the mounted panel reports its counts",
		type(d.instances) == "number"
			and d.instances > 0
			and d.ownInstances > 0
			and d.connections > 0
			and d.threads == 0,
		string.format(
			"HeatGauge instances %s, adapter instances %s, listeners %s, threads %s",
			tostring(d.instances),
			tostring(d.ownInstances),
			tostring(d.connections),
			tostring(d.threads)
		)
	)

	-- a second panel on a throwaway layer
	local before = AlarmClock.stats().listeners
	local layer = Instance.new("Frame")
	layer.Name = DIAG .. "Layer"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Parent = host.api.screen.safe
	local backdrop: any = host.api.backdrop
	local extra: any = HeatPanelModule.new({
		store = host.store,
		screen = host.api.screen,
		layer = layer,
		world = backdrop and backdrop.world,
		priority = host.api.priority,
	})
	host.wait(0.3)
	local built = extra:getDebugState()
	local during = AlarmClock.stats().listeners
	verdict(
		host,
		"a second panel registers its counts",
		built.gauges == 1 and built.instances > 0 and built.connections > 0 and during == before + 1,
		string.format(
			"instances %s, adapter instances %s, listeners %s, clock listeners %d -> %d",
			tostring(built.instances),
			tostring(built.ownInstances),
			tostring(built.connections),
			before,
			during
		)
	)
	extra:destroy()
	host.wait(0.3)
	local gone = extra:getDebugState()
	local after = AlarmClock.stats().listeners
	verdict(
		host,
		"destroy leaves zero instances, listeners and threads",
		gone.instances == 0
			and gone.ownInstances == 0
			and gone.connections == 0
			and gone.threads == 0
			and #layer:GetDescendants() == 0
			and after == before,
		string.format(
			"instances %s, adapter instances %s, listeners %s, threads %s, layer descendants %d, clock listeners %d",
			tostring(gone.instances),
			tostring(gone.ownInstances),
			tostring(gone.connections),
			tostring(gone.threads),
			#layer:GetDescendants(),
			after
		)
	)
	layer:Destroy()
	finish(host, "Heat build and destroy")
end

-- Debug-only outlines for screenshots: run once to show, again to hide. They follow the frame buttons.
S["Heat: diagnostic overlay (toggle)"] = function(host)
	if diagConnection then
		overlayOff(host)
		host.log("Heat diagnostic overlay: off")
		return
	end
	if host.store:get().mode ~= "Run" then
		host.enterRun()
		host.wait(0.4)
	end
	if not heatPanel(host) then
		return
	end
	local screen = host.api.screen
	diagConnection = screen.Changed:Connect(function()
		task.delay(0.4, function()
			if diagConnection then
				buildOutlines(host)
			end
		end)
	end)
	buildOutlines(host)
	host.log(
		"Heat diagnostic overlay: on (magenta = protected road, green = measured panel with title tab, orange = Meltdown reach, cyan = full-viewport centre, yellow = safe-area centre); run this scenario again to hide it"
	)
end

-- The overlay on each frame, Calm then Meltdown, for screenshots.
S["Heat: diagnostic overlay tour"] = function(host)
	freshRun(host)
	local panel = heatPanel(host)
	if not panel then
		return
	end
	local start = host.api.screen:profile().name
	for _, name in host.api.profiles do
		host.api.setProfile(name)
		setHeat(host, 0.2, "Calm")
		host.wait(1.2)
		buildOutlines(host)
		host.log("Heat overlay tour: " .. name .. ", Calm")
		host.wait(2.5)
		setHeat(host, 1, "Meltdown")
		host.wait(1.5)
		buildOutlines(host)
		host.log("Heat overlay tour: " .. name .. ", Meltdown")
		host.wait(2.5)
		setHeat(host, 0, "Calm")
		host.wait(1.0)
	end
	host.api.setProfile(start)
	overlayOff(host)
end

return S
