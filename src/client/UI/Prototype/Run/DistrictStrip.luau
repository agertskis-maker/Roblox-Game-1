--!strict
-- District strip for the run view (Lane 3 preview, HUD rebuild worker HR; U-01, U-02, U-03).
-- Top centre: original illustrated district tiles (HA's Icons2 "District_<id>" art on a district
-- ground colour) with names, the current tile highlighted, the player's avatar head and the
-- distance travelled (metres) beneath it. Display only: it reads store.run.districtPlan and
-- store.run.distance as supplied and decides nothing. Hidden when districtPlan is nil.
--
-- ENDLESS (U-03): a ROLLING WINDOW, never a finite row with an end cap:
--   desktop / tablet  previous (dimmed) | current (larger, white highlight) | next | faded stub
--   phones            current | progress track with the head | next
-- After the last district the plan repeats (plan.repeats) and the window keeps rolling: Skyline
-- Park -> Main Street. The fixture-local cycle index (1 = first pass) is derived from the plan's
-- total length; from the second pass the current tile wears a small "LAP 2" badge (PROPOSED
-- word, owner check). Visited / current / upcoming read by dimming, size and the white highlight
-- only: no locks, ticks, stars or reward marks.
--
-- Avatar position: from the plan's EXPLICIT boundaries (unequal lengths): the head sits at
-- (distance - start of the current district) / its length across the current tile (or the
-- phone track). Never equal spans.
--
-- Stable layout: tile slots never move or resize on distance ticks; only the head slides and
-- the fixed-width distance label changes text, at most 10 times a second. Tile content changes
-- only when a boundary is crossed (one small pop on the new current tile; none in reduced
-- motion).
--
--   local strip = DistrictStrip.new(ctx)
--   strip:layout(), strip:setVisible(on), strip:destroy(), strip:getDebugState()
--   DistrictStrip.locate(plan, distance) -> { index, cycle, fraction, start }   (pure, for tests)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local S = RunLayout.Strip
local make = Arcade.make

local TEXT_INTERVAL = 0.1 -- distance label updates at most 10 times a second
local LAP_WORD = "LAP" -- PROPOSED badge word (owner check)

local DistrictStrip = {}
DistrictStrip.__index = DistrictStrip

export type Location = { index: number, cycle: number, fraction: number, start: number }

-- Where `distance` (metres) falls in the plan. Pure; explicit boundaries only.
function DistrictStrip.locate(plan: Store.DistrictPlan, distance: number): Location?
	local list = plan.districts
	if #list == 0 then
		return nil
	end
	local total = 0
	for _, d in list do
		total += math.max(d.length, 0)
	end
	if total <= 0 then
		return { index = 1, cycle = 1, fraction = 0, start = 0 }
	end
	local dist = math.max(if distance ~= distance then 0 else distance, 0)
	local cycle = 1
	local within = dist
	if plan.repeats then
		cycle = math.floor(dist / total) + 1
		within = dist - (cycle - 1) * total
	elseif within >= total then
		local last = list[#list]
		return { index = #list, cycle = 1, fraction = 1, start = total - math.max(last.length, 0) }
	end
	local start = 0
	for i, d in list do
		local len = math.max(d.length, 0)
		if within < start + len or i == #list then
			local f = if len > 0 then math.clamp((within - start) / len, 0, 1) else 0
			return { index = i, cycle = cycle, fraction = f, start = start }
		end
		start += len
	end
	return nil
end

type Tile = {
	frame: Frame,
	ground: Frame,
	art: Frame,
	name: TextLabel,
	dim: Frame,
	pop: UIScale,
	district: string?,
}

local function buildTile(parent: Instance, slot: string, w: number, h: number, current: boolean, z: number): Tile
	local frame = make("Frame", {
		Name = slot,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local pop = make("UIScale", { Name = "Pop", Parent = frame })
	local ground = make("Frame", {
		Name = "Ground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RunKit.districtColour(nil),
		ClipsDescendants = true,
		ZIndex = z,
		Parent = frame,
	})
	Arcade.corner(ground, 6)
	Arcade.outline(ground, if current then "Button" else "Major")
	-- a soft lower shade so the name band reads over any art
	local shade = make("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = z + 3,
		Parent = ground,
	})
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
		Parent = shade,
	})
	local art = make("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(h - 8, h - 8),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = ground,
	})
	local name = Arcade.text(ground, {
		text = "",
		role = "Small",
		name = "Name",
		z = z + 5,
	})
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -1)
	name.Size = UDim2.new(1, -4, 0, if current then 22 else 20)
	name.TextWrapped = true
	name.TextScaled = true
	make("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = if current then 18 else 16, Parent = name })
	local dim = make("Frame", {
		Name = "Visited",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(70, 78, 96),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = z + 6,
		Parent = ground,
	})
	if current then
		-- white highlight ring just inside the dark boundary (state by structure, not colour alone)
		local hi = make("Frame", {
			Name = "Highlight",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
			ZIndex = z + 7,
			Parent = ground,
		})
		Arcade.corner(hi, 4)
		make("UIStroke", { Thickness = 2.5, Color = Color3.new(1, 1, 1), Parent = hi })
	end
	return { frame = frame, ground = ground, art = art, name = name, dim = dim, pop = pop, district = nil }
end

function DistrictStrip.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, DistrictStrip)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._compact = false
	self._windowKey = ""
	self._loc = nil :: Location?
	self._distanceText = ""
	self._lastText = -math.huge
	self._textWrites = 0
	self._windowChanges = 0
	self._built = nil :: any

	local root = self._trove:Add(RunLayout.canvas(ctx, "DistrictStrip"))
	self.root = root

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:_apply()
	end)
	self:layout()
	return self
end

export type DistrictStrip = typeof(DistrictStrip.new((nil :: any) :: RunLayout.Ctx))

-- Builds the strip for the current profile (full or compact); rebuilt only on a profile change.
function DistrictStrip._build(self: DistrictStrip)
	if self._built then
		self._built.trove:Destroy()
	end
	local trove = Trove.new()
	local compact = RunLayout.compact(self._ctx)
	self._compact = compact
	local size = RunLayout.stripSize(compact)
	local strip = trove:Add(make("Frame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 2,
		Parent = self.root,
	}))
	RunKit.nonInteractive(strip)
	local tiles: { [string]: Tile } = {}
	local track: Frame? = nil
	local trackFill: Frame? = nil
	local stub: Frame? = nil
	if compact then
		tiles.current = buildTile(strip, "Current", S.CompactCurrentW, S.CompactCurrentH, true, 3)
		local trackX = S.CompactCurrentW + S.CompactGap
		local t = make("Frame", {
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(trackX, S.CompactCurrentH / 2),
			Size = UDim2.fromOffset(S.CompactTrackW, 10),
			BackgroundColor3 = RunKit.Slot,
			ZIndex = 3,
			Parent = strip,
		})
		Arcade.corner(t, 5)
		Arcade.outline(t, "Minor")
		local fill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = t,
		})
		Arcade.corner(fill, 5)
		track, trackFill = t, fill
		tiles.next = buildTile(strip, "Next", S.CompactNextW, S.CompactNextH, false, 3)
		tiles.next.frame.Position =
			UDim2.fromOffset(trackX + S.CompactTrackW + S.CompactGap, (S.CompactCurrentH - S.CompactNextH) / 2)
		tiles.next.name.Visible = false -- the art carries it on phones; the current tile is named
	else
		local y = (S.CurrentH - S.TileH) / 2
		tiles.prev = buildTile(strip, "Previous", S.TileW, S.TileH, false, 3)
		tiles.prev.frame.Position = UDim2.fromOffset(0, y)
		tiles.current = buildTile(strip, "Current", S.CurrentW, S.CurrentH, true, 4)
		tiles.current.frame.Position = UDim2.fromOffset(S.TileW + S.Gap, 0)
		tiles.next = buildTile(strip, "Next", S.TileW, S.TileH, false, 3)
		local nextX = S.TileW + S.Gap + S.CurrentW + S.Gap
		tiles.next.frame.Position = UDim2.fromOffset(nextX, y)
		-- the faded stub: more beyond, never an end cap
		local st = make("Frame", {
			Name = "MoreBeyond",
			Position = UDim2.fromOffset(nextX + S.TileW + S.Gap, y),
			Size = UDim2.fromOffset(S.StubW, S.TileH),
			BackgroundColor3 = RunKit.districtColour(nil),
			ZIndex = 3,
			Parent = strip,
		})
		Arcade.corner(st, 6)
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = st,
		})
		stub = st
	end
	-- lap badge (from the second pass of the repeating plan)
	local lap = Arcade.text(tiles.current.ground, {
		text = "",
		role = "Badge",
		name = "Lap",
		italic = true,
		face = "White",
		z = 20,
		autoWidth = true,
	})
	lap.AnchorPoint = Vector2.new(1, 0)
	lap.Position = UDim2.new(1, -2, 0, 0)
	lap.Visible = false

	-- avatar head + distance
	local headSize = if compact then S.CompactHead else S.Head
	local head = make("Frame", {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(headSize, headSize),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 12,
		Parent = strip,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = head })
	Arcade.outline(head, "Major")
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = Color3.fromRGB(196, 226, 255),
		ClipsDescendants = true,
		ZIndex = 13,
		Parent = head,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = face })
	RunKit.avatar(face, trove)
	local distance = Arcade.text(strip, {
		text = "0 m",
		role = "Label",
		name = "Distance",
		size = 20,
		italic = true,
		face = "White",
		z = 12,
	})
	distance.AnchorPoint = Vector2.new(0.5, 0)
	distance.Size = UDim2.fromOffset(112, S.DistanceH) -- fixed width: no reflow as digits change
	self._built = {
		trove = trove,
		strip = strip,
		tiles = tiles,
		track = track,
		trackFill = trackFill,
		stub = stub,
		lap = lap,
		head = head,
		distance = distance,
	}
	self._windowKey = ""
	self._distanceText = ""
end

function DistrictStrip._renderTile(_self: DistrictStrip, tile: Tile?, district: Store.District?, visited: boolean)
	if not tile then
		return
	end
	local t = tile :: Tile
	t.frame.Visible = district ~= nil
	if not district then
		t.district = nil
		return
	end
	local d = district :: Store.District
	if t.district ~= d.id then
		t.district = d.id
		t.art:ClearAllChildren()
		Arcade.icon(t.art, "District_" .. d.id)
		t.ground.BackgroundColor3 = RunKit.districtColour(d.id)
	end
	t.name.Text = d.name
	t.dim.Visible = visited
	t.name.TextTransparency = if visited then 0.25 else 0
end

function DistrictStrip._apply(self: DistrictStrip)
	local built = self._built
	if not built then
		return
	end
	local state = self._ctx.store:get()
	local run = state.run
	local plan = if run then run.districtPlan else nil
	local show = self._visible and plan ~= nil and state.mode == "Run" and #(plan :: any).districts > 0
	built.strip.Visible = show
	if not show or not run or not plan then
		self._loc = nil
		return
	end
	local p = plan :: Store.DistrictPlan
	local loc = DistrictStrip.locate(p, run.distance)
	if not loc then
		built.strip.Visible = false
		return
	end
	local l = loc :: Location
	self._loc = l
	local list = p.districts
	local n = #list
	local function at(offset: number): Store.District?
		local i = l.index + offset
		local passes = l.cycle
		while i < 1 do
			i += n
			passes -= 1
		end
		while i > n do
			i -= n
			passes += 1
		end
		if passes < 1 or (not p.repeats and passes > 1) then
			return nil
		end
		return list[i]
	end
	local key = l.cycle .. ":" .. l.index
	if key ~= self._windowKey then
		local first = self._windowKey == ""
		self._windowKey = key
		self._windowChanges += 1
		local tiles = built.tiles
		self:_renderTile(tiles.prev, at(-1), true)
		self:_renderTile(tiles.current, at(0), false)
		self:_renderTile(tiles.next, at(1), false)
		if built.stub then
			local beyond = at(2)
			built.stub.Visible = beyond ~= nil
			built.stub.BackgroundColor3 = RunKit.districtColour(beyond and beyond.id)
		end
		built.lap.Visible = p.repeats and l.cycle >= 2
		built.lap.Text = LAP_WORD .. " " .. l.cycle
		if not first and not Motion.reduced() then
			Motion.pop(tiles.current.frame :: any, 1.08)
		end
	end
	-- head position from the explicit boundaries
	local headX: number
	if self._compact then
		local trackX = S.CompactCurrentW + S.CompactGap
		headX = trackX + l.fraction * S.CompactTrackW
		built.head.Position = UDim2.fromOffset(headX, S.CompactCurrentH / 2)
		if built.trackFill then
			built.trackFill.Size = UDim2.fromScale(l.fraction, 1)
		end
		local w = RunLayout.stripSize(true).X
		built.distance.Position = UDim2.fromOffset(math.clamp(headX, 56, w - 56), S.CompactCurrentH + 4)
	else
		local x0 = S.TileW + S.Gap
		headX = x0 + l.fraction * S.CurrentW
		built.head.Position = UDim2.fromOffset(headX, S.HeadY + S.Head / 2)
		built.distance.Position = UDim2.fromOffset(headX, S.HeadY + S.Head)
	end
	-- distance text: metres with thousands separators, throttled to 10 Hz
	local now = os.clock()
	local text = Format.group(math.max(0, math.floor(run.distance))) .. " m"
	if text ~= self._distanceText and (now - self._lastText >= TEXT_INTERVAL or self._distanceText == "") then
		self._distanceText = text
		self._lastText = now
		self._textWrites += 1
		built.distance.Text = text
	end
end

function DistrictStrip.layout(self: DistrictStrip)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	if not self._built or RunLayout.compact(ctx) ~= self._compact then
		self:_build()
	end
	local rect = RunLayout.stripRect(ctx)
	self._built.strip.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
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

function DistrictStrip.setVisible(self: DistrictStrip, on: boolean)
	self._visible = on
	self.root.Visible = on
	self:_apply()
end

function DistrictStrip.getDebugState(self: DistrictStrip): { [string]: any }
	local built = self._built
	local loc = self._loc
	local tiles: { [string]: any } = {}
	if built then
		for slot, t in built.tiles :: { [string]: Tile } do
			tiles[slot] = { district = t.district, shown = t.frame.Visible, visited = t.dim.Visible }
		end
	end
	return {
		visible = self._visible,
		shown = built ~= nil and built.strip.Visible,
		compact = self._compact,
		index = loc and loc.index,
		cycle = loc and loc.cycle,
		fraction = loc and loc.fraction,
		tiles = tiles,
		lap = built and built.lap.Visible and built.lap.Text or nil,
		distanceText = self._distanceText,
		textWrites = self._textWrites,
		windowChanges = self._windowChanges,
		box = RunLayout.describe(RunLayout.stripRect(self._ctx)),
		overlapsProtected = RunLayout.overlaps(RunLayout.stripRect(self._ctx), RunLayout.protected(self._ctx)),
		instances = if built then #built.strip:GetDescendants() else 0,
	}
end

function DistrictStrip.destroy(self: DistrictStrip)
	if self._built then
		self._built.trove:Destroy()
		self._built = nil
	end
	self._trove:Destroy()
end

return DistrictStrip
