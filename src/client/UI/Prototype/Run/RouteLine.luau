--!strict
-- Route line for the run view (Lane 3 preview, Round 2: R2-R1 route line, R2-R2 record and cycle).
-- Top centre. A subway-style line replaces the district strip: five named stations, each with an original
-- compact landmark icon (Icons2 "District_<id>") and a readable name, a travelled line in the World's colour
-- over an untraveled grey one, a round avatar marker with a pointer, a callout (distance, next district and
-- the metres to it), a checkered BEST badge at the right end and, when the supplied personal best lies in the
-- shown cycle, a small checkered marker at its correct place. Display only: it reads store.run.districtPlan,
-- run.distance, run.recordM and run.recordVerified as supplied and decides nothing.
--
-- HONEST SPACE (R2-R1). The line is schematic: station i sits at visual position (i - 1) / N and the cycle
-- ends at 1.0 (where the badge is), but the marker moves from the plan's EXPLICIT boundaries, so unequal
-- district lengths set its pace. The distance unit is the plan's (metres, a fixture scale until Lane 1 supplies
-- the real conversion; nothing here converts studs). The visual position is smoothed, then clamped to the
-- current district's stretch, so it can never contradict the district the banner just named.
--
-- RECORD (R2-R2). BEST is a distance record, not the end of an endless World. The badge at the right end is
-- visually distinct from the stations. recordM inside the shown cycle gets a second marker at its correct
-- distance; otherwise the label says ahead or behind. NEW BEST fires ONCE per run, on the update that carries
-- the distance across the pre-run record (only when the record is verified), is never saved from here, and
-- never replays on later or reordered updates. No prior best: no label, no marker, no NEW BEST.
--
-- CYCLE. The total distance is monotonic (a stale lower value is ignored for the run) and never shows zero. After
-- the last district a repeating plan starts a new cycle: only the local progress resets, with a short sweep back
-- along the line (none in reduced motion) and a LAP n tag. This is a district-route cycle, not a Speedway income
-- lap. A station's arrival emphasis plays once per (cycle, district) however often a boundary is crossed.
--
-- Stable layout: nothing reflows on distance ticks; the callout writes at most 10 times a second. Hidden when
-- districtPlan is nil.
--
--   local line = RouteLine.new(ctx)
--   line:layout(), line:setVisible(on), line:destroy(), line:getDebugState()
--   RouteLine.locate = RouteMath.locate   (pure, for tests)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RouteMath = require(script.Parent.RouteMath)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local TEXT_INTERVAL = 0.1 -- the callout writes at most 10 times a second
local FOLLOW_RATE = 14 -- 1/s: how quickly the shown marker follows the supplied position
local WRAP_SECONDS = 0.45 -- the sweep back to the first station at a new cycle
local LAP_WORD = "LAP" -- PROPOSED tag word (owner check)

local DEFAULT_WORLD: Store.WorldInfo = { id = "Downtown", name = "Downtown", colour = Color3.fromRGB(52, 168, 255) }
local TRACK_GREY = Color3.fromRGB(176, 186, 206)
local NODE_GREY = Color3.fromRGB(148, 158, 180)
local GOLD = Color3.fromRGB(255, 214, 64)
local GOLD_HEX = "FFE27A"
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(64, 74, 100)
local PILL = A.Ink
local NAME_VISITED = Color3.new(1, 1, 1)
local NAME_CURRENT = Color3.fromRGB(255, 226, 120)
local NAME_UPCOMING = Color3.fromRGB(208, 218, 236)

local RouteLine = {}
RouteLine.__index = RouteLine
RouteLine.locate = RouteMath.locate

export type Location = RouteMath.Location

type Station = {
	holder: Frame,
	fit: UIScale,
	ring: UIStroke,
	dim: Frame,
	node: Frame,
	name: TextLabel,
	district: string,
	state: string,
}

local function firstWord(name: string): string
	return string.match(name, "^%S+") or name
end

local function label(d: Store.District, compact: boolean): string
	if compact then
		return d.short or firstWord(d.name)
	end
	return d.name
end

local function planKey(plan: Store.DistrictPlan): string
	local parts = { if plan.world then plan.world.id else "-" }
	for _, d in plan.districts do
		table.insert(parts, d.id)
	end
	return table.concat(parts, ",")
end

-- A checkered square (the record badge and its marker). Dark squares on a white field.
local function checker(parent: Instance, name: string, side: number, cells: number, z: number): Frame
	local field = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		ZIndex = z,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0, math.max(3, side * 0.18)), Parent = field })
	local cell = 1 / cells
	for row = 0, cells - 1 do
		for col = 0, cells - 1 do
			if (row + col) % 2 == 0 then
				make("Frame", {
					Name = "Cell",
					Position = UDim2.fromScale(col * cell, row * cell),
					Size = UDim2.fromScale(cell, cell),
					BackgroundColor3 = A.Ink,
					BorderSizePixel = 0,
					ZIndex = z + 1,
					Parent = field,
				})
			end
		end
	end
	return field
end

local function pill(parent: Instance, name: string, w: number, h: number, order: number, z: number): (Frame, TextLabel)
	local frame = make("Frame", {
		Name = name,
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = PILL,
		BackgroundTransparency = 0.18,
		LayoutOrder = order,
		ZIndex = z,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	Arcade.outline(frame, "Minor")
	local text = Arcade.text(frame, {
		text = "",
		role = if h >= 28 then "Label" else "Small",
		name = "Text",
		z = z + 1,
	})
	text.Size = UDim2.fromScale(1, 1)
	text.RichText = true
	return frame, text
end

function RouteLine.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, RouteLine)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._compact = false
	self._built = nil :: any
	self._stations = {} :: { Station }
	self._stationTrove = nil :: any
	self._planKey = ""
	self._world = DEFAULT_WORLD
	self._n = 5
	-- per-run state (reset when the run identity changes)
	self._serial = 0
	self._runKey = ""
	self._maxDistance = 0
	self._lastEffective = nil :: number?
	self._bestFired = false
	self._furthest = 0
	self._windowKey = ""
	self._cycle = 0
	-- presentation
	self._loc = nil :: Location?
	self._shownT = 0
	self._targetT = 0
	self._lo = 0
	self._hi = 1
	self._wrap = nil :: { elapsed: number, from: number }?
	self._record = { kind = "None", delta = 0 } :: RouteMath.Record
	self._calloutText = ""
	self._recordText = ""
	self._lastText = -math.huge
	-- counters for tests and review
	self._textWrites = 0
	self._windowChanges = 0
	self._arrivals = 0
	self._newBestCount = 0
	self._lapWraps = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "RouteLine"))
	self.root = root

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode == "Run" then
			self._serial += 1 -- a new run: NEW BEST, arrivals and the monotonic distance start again
		end
		self:_apply()
	end)
	self._trove:Connect(RunService.RenderStepped, function(dt: number)
		self:_step(dt)
	end)
	self._trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced then
			self._wrap = nil
			self._shownT = self._targetT
			self:_place()
		end
	end))
	self:layout()
	return self
end

export type RouteLine = typeof(RouteLine.new((nil :: any) :: RunLayout.Ctx))

-- STATIC PARTS (rebuilt only when the profile changes between full and compact) ---------------

function RouteLine._build(self: RouteLine)
	if self._built then
		self._built.trove:Destroy()
		self._built = nil
	end
	self._stations = {}
	self._planKey = ""
	local trove = Trove.new()
	local compact = RunLayout.compact(self._ctx)
	self._compact = compact
	local G = RunLayout.routeGeometry(compact)
	local block = trove:Add(make("Frame", {
		Name = "Route",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(G.size.X, G.size.Y),
		Visible = false,
		ZIndex = 2,
		Parent = self.root,
	}))
	RunKit.nonInteractive(block)

	-- the track: grey underneath, the World colour over the travelled part
	local base = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(G.x1, G.trackY),
		Size = UDim2.fromOffset(G.badgeX - G.x1, G.trackH),
		BackgroundColor3 = TRACK_GREY,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = block,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = base })
	Arcade.outline(base, "Minor")
	local fill = make("Frame", {
		Name = "Travelled",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = self._world.colour,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = base,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = fill })

	-- the record badge at the right end (not a station)
	local badge = checker(block, "BestBadge", G.badge, 4, 5)
	badge.Position = UDim2.fromOffset(G.badgeX, G.trackY)
	local badgeStroke = Arcade.outline(badge, "Major")
	local badgeName = Arcade.text(block, {
		text = "BEST",
		role = "Small",
		name = "BestName",
		z = 6,
	})
	badgeName.AnchorPoint = Vector2.new(0.5, 0)
	badgeName.Position = UDim2.fromOffset(G.badgeX, G.trackY + G.badge / 2 + 1)
	badgeName.Size = UDim2.fromOffset(56, 22)

	-- the record marker (only when the record lies inside the shown cycle)
	local recordSide = if compact then 14 else 18
	local record = checker(block, "BestMarker", recordSide, 2, 8)
	record.Visible = false
	Arcade.outline(record, "Minor")

	-- avatar marker: a pointer behind a round frame
	local pointer = make("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		Rotation = 45,
		BackgroundColor3 = WHITE,
		ZIndex = 9,
		Parent = block,
	})
	Arcade.outline(pointer, "Minor")
	local head = make("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(G.marker, G.marker),
		BackgroundColor3 = WHITE,
		ZIndex = 10,
		Parent = block,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = head })
	Arcade.outline(head, "Major")
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -5, 1, -5),
		BackgroundColor3 = Color3.fromRGB(196, 226, 255),
		ClipsDescendants = true,
		ZIndex = 11,
		Parent = head,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = face })
	RunKit.avatar(face, trove)

	-- the callout row: lap tag, distance and next district, record label
	local row = make("Frame", {
		Name = "Callout",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, G.calloutY),
		Size = UDim2.fromOffset(G.size.X, G.calloutH),
		ZIndex = 12,
		Parent = block,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local lapChip = make("Frame", {
		Name = "Lap",
		Size = UDim2.fromOffset(if compact then 52 else 56, G.calloutH),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Visible = false,
		ZIndex = 12,
		Parent = row,
	})
	Arcade.surface(lapChip, "Gold", { outline = "Minor" })
	local lapText = Arcade.text(lapChip, { text = "", role = "Badge", name = "Text", z = 14 })
	lapText.Size = UDim2.fromScale(1, 1)
	local _, calloutText = pill(row, "Next", if compact then 232 else 316, G.calloutH, 2, 12)
	local recordPill, recordLabel = pill(row, "Record", if compact then 128 else 196, G.calloutH, 3, 12)
	recordPill.Visible = false

	self._built = {
		trove = trove,
		block = block,
		base = base,
		fill = fill,
		badge = badge,
		badgeStroke = badgeStroke,
		badgeName = badgeName,
		record = record,
		pointer = pointer,
		head = head,
		lapChip = lapChip,
		lapText = lapText,
		calloutText = calloutText,
		recordPill = recordPill,
		recordLabel = recordLabel,
		geometry = G,
	}
	self._calloutText = ""
	self._recordText = ""
	self._windowKey = ""
	self._wrap = nil
	self:_place() -- the new frames start at the shown position, not at the origin
end

-- STATIONS (rebuilt when the route changes, e.g. another World) --------------------------------

function RouteLine._ensureStations(self: RouteLine, plan: Store.DistrictPlan)
	local built = self._built
	if not built then
		return
	end
	local key = planKey(plan)
	if key == self._planKey then
		return
	end
	self._planKey = key
	self._windowKey = ""
	if self._stationTrove then
		self._stationTrove:Destroy()
	end
	local trove = Trove.new()
	self._stationTrove = trove
	self._stations = {}
	self._world = plan.world or DEFAULT_WORLD
	built.fill.BackgroundColor3 = self._world.colour
	local G = built.geometry
	local n = #plan.districts
	self._n = n
	local span = G.xEnd - G.x1
	local compact = self._compact
	local nodeD = if compact then 12 else 16
	local nameW = math.floor(span / n) - 2
	for i, d in plan.districts do
		local x = G.x1 + (i - 1) * span / n
		local holder = trove:Add(make("Frame", {
			Name = "Station" .. i,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(x, G.iconBottom),
			Size = UDim2.fromOffset(G.icon, G.icon),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = built.block,
		}))
		local fit = make("UIScale", { Name = "Fit", Parent = holder })
		local art = make("Frame", {
			Name = "Art",
			Size = UDim2.fromOffset(G.icon, G.icon),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = holder,
		})
		Arcade.icon(art, "District_" .. d.id)
		local dim = make("Frame", {
			Name = "Upcoming",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = DIM,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 8,
			Parent = holder,
		})
		make("UICorner", { CornerRadius = UDim.new(0, math.floor(G.icon * 0.2)), Parent = dim })
		local ringFrame = make("Frame", {
			Name = "Ring",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 9,
			Parent = holder,
		})
		make("UICorner", { CornerRadius = UDim.new(0, math.floor(G.icon * 0.2)), Parent = ringFrame })
		local ring = make("UIStroke", {
			Thickness = 3,
			Color = WHITE,
			Enabled = false,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = ringFrame,
		})
		local node = trove:Add(make("Frame", {
			Name = "Node" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, G.trackY),
			Size = UDim2.fromOffset(nodeD, nodeD),
			BackgroundColor3 = NODE_GREY,
			ZIndex = 5,
			Parent = built.block,
		}))
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = node })
		Arcade.outline(node, "Minor")
		local name = trove:Add(Arcade.text(built.block, {
			text = label(d, compact),
			role = "Small",
			name = "Name" .. i,
			colour = NAME_UPCOMING,
			yAlign = Enum.TextYAlignment.Top,
			z = 6,
		}))
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.fromOffset(x, G.nameY)
		name.Size = UDim2.fromOffset(nameW, G.nameH)
		name.TextWrapped = not compact
		table.insert(self._stations, {
			holder = holder,
			fit = fit,
			ring = ring,
			dim = dim,
			node = node,
			name = name,
			district = d.id,
			state = "",
		})
	end
end

function RouteLine._renderStations(self: RouteLine, loc: Location, animate: boolean)
	local G = (self._built :: any).geometry
	local grow = G.iconCurrent / G.icon
	for i, st in self._stations do
		local state = if i < loc.index then "visited" elseif i == loc.index then "current" else "upcoming"
		if st.state ~= state then
			st.state = state
			local goal = if state == "current" then grow else 1
			if animate and not Motion.reduced() then
				Motion.tween(st.fit, "fit", Motion.info(0.18, Enum.EasingStyle.Back), { Scale = goal })
			else
				st.fit.Scale = goal
			end
			st.dim.Visible = state == "upcoming"
			st.ring.Enabled = state ~= "upcoming"
			st.ring.Color = if state == "current" then WHITE else self._world.colour
			st.ring.Thickness = if state == "current" then 3.5 else 3
			st.node.BackgroundColor3 = if state == "visited"
				then self._world.colour
				elseif state == "current" then WHITE
				else NODE_GREY
			st.name.TextColor3 = if state == "visited"
				then NAME_VISITED
				elseif state == "current" then NAME_CURRENT
				else NAME_UPCOMING
		end
	end
end

-- Moves the marker, the pointer and the travelled part of the line to the shown position.
function RouteLine._place(self: RouteLine)
	local built = self._built
	if not built then
		return
	end
	local G = built.geometry
	local x = G.x1 + self._shownT * (G.xEnd - G.x1)
	built.head.Position = UDim2.fromOffset(x, G.trackY)
	built.pointer.Position = UDim2.fromOffset(x, G.trackY - G.marker / 2 + 1)
	built.fill.Size = UDim2.new(0, math.max(x - G.x1, 0), 1, 0)
end

function RouteLine._step(self: RouteLine, dt: number)
	local built = self._built
	if not built or not built.block.Visible then
		return
	end
	local shown = self._shownT
	local wrap = self._wrap
	if wrap then
		wrap.elapsed += dt
		local k = math.min(wrap.elapsed / WRAP_SECONDS, 1)
		shown = wrap.from * (1 - k) * (1 - k) -- eased sweep back to the first station
		if k >= 1 then
			self._wrap = nil
			shown = 0
		end
	else
		if Motion.reduced() then
			shown = self._targetT
		else
			shown += (self._targetT - shown) * (1 - math.exp(-FOLLOW_RATE * dt))
		end
		-- never show the marker outside the district the run is in (it must not contradict the banner)
		shown = math.clamp(shown, self._lo, self._hi)
	end
	if math.abs(shown - self._shownT) > 1e-4 then
		self._shownT = shown
		self:_place()
	end
end

-- THE STORE UPDATE ----------------------------------------------------------------------------

function RouteLine._resetRun(self: RouteLine, key: string)
	self._runKey = key
	self._maxDistance = 0
	self._lastEffective = nil
	self._bestFired = false
	self._furthest = 0
	self._windowKey = ""
	self._cycle = 0
	self._wrap = nil
	self._calloutText = ""
	self._recordText = ""
end

function RouteLine._applyRecord(self: RouteLine, plan: Store.DistrictPlan, run: Store.RunState, effective: number)
	local built = self._built :: any
	local G = built.geometry
	local rec = RouteMath.record(plan, run.recordM, effective)
	self._record = rec
	if rec.kind == "Inside" and rec.t then
		built.record.Visible = true
		built.record.Position = UDim2.fromOffset(G.x1 + rec.t * (G.xEnd - G.x1), G.trackY)
	else
		built.record.Visible = false
	end
	local noRecord = rec.kind == "None"
	built.badge.BackgroundTransparency = if noRecord then 0.35 else 0
	built.badgeName.TextTransparency = if noRecord then 0.35 else 0
	built.badgeStroke.Color = if self._bestFired then GOLD else A.Ink
	-- the record label
	local text = ""
	if self._bestFired then
		text = "NEW BEST!"
	elseif rec.kind ~= "None" then
		local metres = Format.group(math.floor(math.abs(rec.delta) + 0.5))
		local compact = self._compact
		if rec.kind == "Inside" then
			text = "BEST " .. Format.group(math.floor((run.recordM or 0) + 0.5)) .. " m"
		elseif rec.kind == "Ahead" then
			text = if compact then "BEST +" .. metres .. " m" else "BEST " .. metres .. " m ahead"
		else
			text = if compact then "BEST -" .. metres .. " m" else "BEST " .. metres .. " m behind"
		end
	end
	built.recordPill.Visible = text ~= ""
	if text ~= self._recordText then
		self._recordText = text
		self._textWrites += 1
		built.recordLabel.Text = if self._bestFired
			then string.format('<font color="#%s">%s</font>', GOLD_HEX, text)
			else text
	end
end

function RouteLine._apply(self: RouteLine)
	local built = self._built
	if not built then
		return
	end
	local state = self._ctx.store:get()
	local run = state.run
	local plan = if run then run.districtPlan else nil
	local show = self._visible and plan ~= nil and state.mode == "Run" and #(plan :: any).districts > 0
	built.block.Visible = show
	if not show or not run or not plan then
		self._loc = nil
		return
	end
	local p = plan :: Store.DistrictPlan
	local key = run.runId or ("run#" .. self._serial)
	if key ~= self._runKey then
		self:_resetRun(key)
	end
	self:_ensureStations(p)
	-- the total distance is monotonic within a run: a stale lower update never moves the line back
	local supplied = if run.distance ~= run.distance then 0 else math.max(run.distance, 0)
	local first = self._lastEffective == nil
	local previous = self._lastEffective or supplied
	local effective = math.max(self._maxDistance, supplied)
	self._maxDistance = effective
	self._lastEffective = effective
	local loc = RouteMath.locate(p, effective)
	if not loc then
		built.block.Visible = false
		return
	end
	self._loc = loc
	local n = #p.districts

	-- NEW BEST: once per run, on the update that crosses the verified pre-run record
	if
		not self._bestFired
		and not first
		and run.recordVerified ~= false
		and RouteMath.crossed(previous, effective, run.recordM)
	then
		self._bestFired = true
		self._newBestCount += 1
		if not Motion.reduced() then
			Motion.pop(built.badge, 1.25)
			Motion.pop(built.recordPill, 1.12)
		end
	end

	-- stations, arrivals and the cycle tag
	local windowKey = loc.cycle .. ":" .. loc.index
	if windowKey ~= self._windowKey then
		local previousCycle = self._cycle
		self._windowKey = windowKey
		self._windowChanges += 1
		self:_renderStations(loc, previousCycle ~= 0)
		local progress = (loc.cycle - 1) * n + loc.index
		if previousCycle ~= 0 and progress > self._furthest then
			-- one short emphasis per (cycle, district), however often a boundary is crossed
			self._arrivals += 1
			local station = self._stations[loc.index]
			if station and not Motion.reduced() then
				Motion.pop(station.holder, 1.14)
			end
		end
		self._furthest = math.max(self._furthest, progress)
		if previousCycle ~= 0 and loc.cycle > previousCycle then
			self._lapWraps += 1
			if not Motion.reduced() then
				self._wrap = { elapsed = 0, from = self._shownT }
				Motion.pop(built.lapChip, 1.15)
			end
		end
		self._cycle = loc.cycle
	end
	built.lapChip.Visible = p.repeats and loc.cycle >= 2
	built.lapText.Text = LAP_WORD .. " " .. loc.cycle
	self._lo, self._hi = (loc.index - 1) / n, loc.index / n
	self._targetT = loc.t
	if first or Motion.reduced() then
		self._shownT = loc.t
		self._wrap = nil
		self:_place()
	end
	self:_applyRecord(p, run, effective)

	-- the callout: total distance, the next district and the metres to it (10 Hz at most)
	local nextDistrict = RouteMath.upcoming(p, loc)
	local metres = Format.group(math.floor(effective))
	local text = string.format('<font color="#%s">%s m</font>', GOLD_HEX, metres)
	if nextDistrict then
		local to = Format.group(math.ceil(RouteMath.remaining(p, loc)))
		text ..= if self._compact
			then "  •  " .. label(nextDistrict, true) .. " " .. to .. " m"
			else "  •  " .. nextDistrict.name .. " in " .. to .. " m"
	end
	local now = os.clock()
	if text ~= self._calloutText and (now - self._lastText >= TEXT_INTERVAL or self._calloutText == "") then
		self._calloutText = text
		self._lastText = now
		self._textWrites += 1
		built.calloutText.Text = text
	end
end

function RouteLine.layout(self: RouteLine)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	if not self._built or RunLayout.compact(ctx) ~= self._compact then
		self:_build()
	end
	local rect = RunLayout.routeRect(ctx)
	self._built.block.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
	local cash = RunLayout.cashRect(ctx)
	RunLayout.publishTop(ctx.screen, {
		row = 1,
		distance = rect,
		cash = cash,
		stackBottom = rect.pos.Y + rect.size.Y,
		leftBottom = cash.pos.Y + cash.size.Y,
	})
	self:_apply()
end

function RouteLine.setVisible(self: RouteLine, on: boolean)
	self._visible = on
	self.root.Visible = on
	self:_apply()
end

function RouteLine.getDebugState(self: RouteLine): { [string]: any }
	local built = self._built
	local loc = self._loc
	local stations: { any } = {}
	for _, st in self._stations do
		table.insert(
			stations,
			{ district = st.district, state = st.state, name = st.name.Text, nameSize = st.name.TextSize }
		)
	end
	local rect = RunLayout.routeRect(self._ctx)
	local cash = RunLayout.cashRect(self._ctx)
	return {
		visible = self._visible,
		shown = built ~= nil and built.block.Visible,
		compact = self._compact,
		world = self._world.id,
		index = loc and loc.index,
		cycle = loc and loc.cycle,
		fraction = loc and loc.fraction,
		targetT = self._targetT,
		shownT = self._shownT,
		stations = stations,
		distance = self._maxDistance,
		callout = built and built.calloutText.Text or nil,
		recordText = self._recordText,
		record = self._record.kind,
		recordDelta = self._record.delta,
		recordMarker = built ~= nil and built.record.Visible,
		newBest = self._bestFired,
		newBestCount = self._newBestCount,
		lap = built and built.lapChip.Visible and built.lapText.Text or nil,
		lapWraps = self._lapWraps,
		arrivals = self._arrivals,
		windowChanges = self._windowChanges,
		textWrites = self._textWrites,
		wrapping = self._wrap ~= nil,
		box = RunLayout.describe(rect),
		overlapsProtected = RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
		overlapsCash = RunLayout.overlaps(rect, cash),
		instances = if built then #built.block:GetDescendants() else 0,
	}
end

function RouteLine.destroy(self: RouteLine)
	if self._stationTrove then
		self._stationTrove:Destroy()
		self._stationTrove = nil
	end
	if self._built then
		self._built.trove:Destroy()
		self._built = nil
	end
	self._trove:Destroy()
end

return RouteLine
