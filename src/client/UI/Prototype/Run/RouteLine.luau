--!strict
-- Distance pill for the run view (Lane 3 preview, Round 3: R3-D). Top centre. ONE small pill: the run distance in
-- gold on the left and, in two compact lines on the right, the area ahead and how far away it is, for example
--     821 m  |  Cactus Flats
--             |  Next in 73 m
-- The Round 2 route line (landmark tiles, progress line, avatar marker, BEST badge, LAP tag) is removed together
-- with its tweens, its per-frame step and the height it reserved. District changes and distance stay meaningful in
-- an endless run; progress to a finish does not, so none is drawn. Display only: it reads store.run.districtPlan
-- and run.distance as supplied and decides nothing. The personal best (run.recordM, run.recordVerified) is still in
-- the store and in RouteMath; this overlay no longer draws it.
--
-- CURRENT OR UPCOMING (never ambiguous). While the plan has an area after the one the run is in (every repeating
-- plan, always), the pill names THAT area and says "Next in N m": the area is upcoming, never the current one.
-- Only when nothing lies ahead (the last area of a plan that does not repeat) does it name the area the run is in,
-- with "You are here". The area the run has just entered is announced by the arrival popup (DistrictBanner).
--
-- STABLE (no layout jumps). Fixed pill size; three fixed boxes: the distance right-aligned in its own box, the
-- area name and the hint left-aligned in theirs. The numbers use the kit's number face (Nunito, tabular digits:
-- every digit is the same width), so a ticking digit moves nothing. Text only changes when it differs, and the
-- pill writes at most a few strings a second at running speed.
--
-- UNITS. Metres up to 99,999 m (grouped, "12,345 m"); from 100,000 m the approved Format.distance (km). The plan's
-- unit is the plan's (metres, a fixture scale until Lane 1 supplies the real conversion; nothing here converts
-- studs). The shown distance never goes back within a run (a stale lower value is ignored) and never shows
-- NaN or infinity (treated as 0).
--
-- FIT. The area box fits the longest known area name at 18 px ("Red Rock Arches", 144 px of 154). A name that would
-- not fit is shown with its approved short label (District.short, else the first word), never in tiny text and
-- never with an ellipsis.
--
-- Hidden when districtPlan is nil or the mode is not Run. No tween, no per-frame connection, no thread: the pill
-- is static text that changes on a store update.
--
--   local line = RouteLine.new(ctx)
--   line:layout(), line:setVisible(on), line:destroy(), line:getDebugState()
--   RouteLine.describe(plan, distance) -> Pill?     (pure; the text the pill shows for a distance)
--   RouteLine.distanceText(metres) -> string        (pure)
--   RouteLine.locate = RouteMath.locate             (pure, for tests)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RouteMath = require(script.Parent.RouteMath)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local NAME_SIZE = A.Text.Label -- 18: the area name (the width of the area box is sized for this)
local METRES_LIMIT = 100000 -- from here the approved km format
local LABEL_PAD = 6 -- Arcade.text pads 3 px each side
local FIT_SLACK = 2

-- TOKEN CANDIDATE: the pill colours (dark ink with a cream rim reads on any backdrop; gold distance; light hint).
local PILL_FILL = A.Ink
local PILL_RIM = PreviewTokens.Color.Panel
local DIVIDER = PreviewTokens.Color.Panel
local HINT_COLOUR = Color3.fromRGB(208, 218, 236)

local RouteLine = {}
RouteLine.__index = RouteLine
RouteLine.locate = RouteMath.locate

export type Location = RouteMath.Location

export type Pill = {
	kind: "Upcoming" | "Current", -- Upcoming: the named area lies ahead; Current: the run is in it and nothing lies ahead
	distance: string, -- "821 m"
	area: string, -- the area name as supplied
	short: string, -- its approved short label
	areaId: string,
	hint: string, -- "Next in 73 m" | "You are here"
	toNext: number?, -- whole metres to the next area (Upcoming only)
	index: number, -- the district the run is in
	cycle: number,
}

local function firstWord(name: string): string
	return string.match(name, "^%S+") or name
end

local function nameOf(d: Store.District): string
	if d.name == "" then
		return "?"
	end
	return d.name
end

local function shortOf(d: Store.District): string
	local short = d.short
	if short and short ~= "" then
		return short
	end
	return firstWord(nameOf(d))
end

-- "821 m", "12,345 m", "123.4 km". Whole metres, never rounded up, never NaN.
function RouteLine.distanceText(metres: number): string
	local whole = math.floor(if metres ~= metres or metres < 0 then 0 else math.min(metres, 1e15))
	if whole < METRES_LIMIT then
		return Format.group(whole) .. " m"
	end
	return Format.distance(whole)
end

function RouteLine.describe(plan: Store.DistrictPlan, distance: number): Pill?
	local loc = RouteMath.locate(plan, distance)
	if not loc then
		return nil
	end
	local here = plan.districts[loc.index]
	local nextDistrict = RouteMath.upcoming(plan, loc)
	local shown = RouteLine.distanceText(distance)
	if nextDistrict then
		local to = math.ceil(RouteMath.remaining(plan, loc))
		return {
			kind = "Upcoming",
			distance = shown,
			area = nameOf(nextDistrict),
			short = shortOf(nextDistrict),
			areaId = nextDistrict.id,
			hint = "Next in " .. RouteLine.distanceText(to),
			toNext = to,
			index = loc.index,
			cycle = loc.cycle,
		}
	end
	return {
		kind = "Current",
		distance = shown,
		area = nameOf(here),
		short = shortOf(here),
		areaId = here.id,
		hint = "You are here",
		toNext = nil,
		index = loc.index,
		cycle = loc.cycle,
	}
end

local function measure(text: string): number
	return TextService:GetTextSize(text, NAME_SIZE, Enum.Font.FredokaOne, Vector2.new(4096, 64)).X
end

function RouteLine.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, RouteLine)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._built = nil :: any
	-- per-run state (reset when the run identity changes)
	self._serial = 0
	self._runKey = ""
	self._maxDistance = 0
	self._windowKey = ""
	self._furthest = 0
	self._cycle = 0
	-- presentation
	self._pill = nil :: Pill?
	self._shownArea = ""
	self._fits = true -- the full area name fitted its box (false: the short label is shown)
	self._worldId = "Downtown"
	self._widths = {} :: { [string]: number } -- measured area-name widths (a handful of names per run)
	self._connections = 0
	-- counters for tests and review
	self._textWrites = 0
	self._windowChanges = 0
	self._arrivals = 0
	self._shortened = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "RouteLine"))
	self.root = root

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._connections += 1
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode == "Run" then
			self._serial += 1 -- a new run: the monotonic distance and the arrivals start again
		end
		self:_apply()
	end)
	self._connections += 1
	self:layout()
	return self
end

export type RouteLine = typeof(RouteLine.new((nil :: any) :: RunLayout.Ctx))

-- STATIC PARTS (built once: the pill has the same size on every frame) ----------------------------

function RouteLine._build(self: RouteLine)
	local trove = Trove.new()
	local G = RunLayout.routeGeometry()
	local block = trove:Add(make("Frame", {
		Name = "Pill",
		BackgroundColor3 = PILL_FILL,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(G.size.X, G.size.Y),
		Visible = false,
		ZIndex = 2,
		Parent = self.root,
	}))
	RunKit.nonInteractive(block)
	Arcade.corner(block, 12)
	Arcade.outline(block, "Major", PILL_RIM)

	local distance = Arcade.text(block, {
		text = "",
		role = "Timer",
		name = "Distance",
		face = "Keys",
		italic = true,
		xAlign = Enum.TextXAlignment.Right,
		z = 4,
	})
	distance.Position = UDim2.fromOffset(G.distanceX, 0)
	distance.Size = UDim2.fromOffset(G.distanceW, G.size.Y)

	local bar = make("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, G.dividerX, 0.5, 0),
		Size = UDim2.fromOffset(RunLayout.Route.Divider, G.size.Y - 2 * RunLayout.Route.PadY - 6),
		BackgroundColor3 = DIVIDER,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = block,
	})
	Arcade.corner(bar, 2)

	local area = Arcade.text(block, {
		text = "",
		role = "Label",
		name = "Area",
		xAlign = Enum.TextXAlignment.Left,
		z = 4,
	})
	area.Position = UDim2.fromOffset(G.areaX, G.nameY)
	area.Size = UDim2.fromOffset(G.areaW, G.nameH)

	local hint = Arcade.text(block, {
		text = "",
		role = "Small",
		name = "Hint",
		italic = true,
		colour = HINT_COLOUR,
		xAlign = Enum.TextXAlignment.Left,
		z = 4,
	})
	hint.Position = UDim2.fromOffset(G.areaX, G.hintY)
	hint.Size = UDim2.fromOffset(G.areaW, G.hintH)

	self._built = {
		trove = trove,
		block = block,
		distance = distance,
		area = area,
		hint = hint,
		geometry = G,
	}
end

local function write(self: RouteLine, label: TextLabel, text: string)
	if label.Text ~= text then
		label.Text = text
		self._textWrites += 1
	end
end

-- THE STORE UPDATE ----------------------------------------------------------------------------

function RouteLine._resetRun(self: RouteLine, key: string)
	self._runKey = key
	self._maxDistance = 0
	self._windowKey = ""
	self._furthest = 0
	self._cycle = 0
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
		self._pill = nil
		return
	end
	local p = plan :: Store.DistrictPlan
	self._worldId = if p.world then p.world.id else "Downtown"
	local key = run.runId or ("run#" .. self._serial)
	if key ~= self._runKey then
		self:_resetRun(key)
	end
	-- the total distance is monotonic within a run: a stale lower update never moves the number back; NaN and
	-- infinity are not distances
	local supplied = run.distance
	if supplied ~= supplied or supplied == math.huge or supplied == -math.huge then
		supplied = 0
	end
	local effective = math.max(self._maxDistance, supplied, 0)
	self._maxDistance = effective
	local pill = RouteLine.describe(p, effective)
	if not pill then
		built.block.Visible = false
		self._pill = nil
		return
	end
	self._pill = pill

	-- arrivals: counted once per (cycle, district), however often a boundary is crossed back and forth
	local windowKey = pill.cycle .. ":" .. pill.index
	if windowKey ~= self._windowKey then
		local first = self._windowKey == ""
		self._windowKey = windowKey
		self._windowChanges += 1
		local progress = (pill.cycle - 1) * #p.districts + pill.index
		if not first and progress > self._furthest then
			self._arrivals += 1
		end
		self._furthest = math.max(self._furthest, progress)
		self._cycle = pill.cycle
	end

	-- the area: its full name when that fits the box, else the approved short label (never tiny, never "...")
	local box = built.geometry.areaW - LABEL_PAD - FIT_SLACK
	local shownArea = pill.area
	self._fits = true
	local width = self._widths[pill.area]
	if width == nil then
		width = measure(pill.area)
		self._widths[pill.area] = width
	end
	if width > box then
		shownArea = pill.short
		self._fits = false
		self._shortened += 1
	end
	self._shownArea = shownArea
	write(self, built.distance, pill.distance)
	write(self, built.area, shownArea)
	write(self, built.hint, pill.hint)
end

function RouteLine.layout(self: RouteLine)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	if not self._built then
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
	local pill = self._pill
	local rect = RunLayout.routeRect(self._ctx)
	local cash = RunLayout.cashRect(self._ctx)
	local gear = RunLayout.gearRect(self._ctx)
	local images, viewports, stations = 0, 0, 0
	local texts: { string } = {}
	if built then
		for _, d in built.block:GetDescendants() do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then
				images += 1
			elseif d:IsA("ViewportFrame") then
				viewports += 1
			elseif d:IsA("TextLabel") then
				table.insert(texts, d.Name)
			end
			-- the Round 2 route-line pieces; none may be left behind
			if
				string.match(d.Name, "^Station%d")
				or string.match(d.Name, "^Node%d")
				or d.Name == "Track"
				or d.Name == "Travelled"
				or d.Name == "Marker"
				or d.Name == "Pointer"
				or d.Name == "BestBadge"
				or d.Name == "BestMarker"
				or d.Name == "Lap"
			then
				stations += 1
			end
		end
	end
	-- the text width against the room inside the label's padding (design px; UIScale does not enter either number)
	local function bounds(label: TextLabel?): any
		if not label then
			return nil
		end
		local pad = label:FindFirstChildOfClass("UIPadding")
		local room = label.Size.X.Offset - (if pad then pad.PaddingLeft.Offset + pad.PaddingRight.Offset else 0)
		return {
			text = label.Text,
			size = label.TextSize,
			boundsX = label.TextBounds.X,
			boxX = room,
			fits = label.TextBounds.X <= room + 0.5,
			alignment = label.TextXAlignment.Name,
		}
	end
	return {
		visible = self._visible,
		shown = built ~= nil and built.block.Visible,
		kind = pill and pill.kind,
		areaId = pill and pill.areaId,
		index = pill and pill.index,
		cycle = pill and pill.cycle,
		toNext = pill and pill.toNext,
		distance = self._maxDistance,
		distanceText = built and built.distance.Text or nil,
		areaText = built and built.area.Text or nil,
		hintText = built and built.hint.Text or nil,
		nameFits = self._fits,
		shortened = self._shortened,
		distanceBox = bounds(built and built.distance),
		areaBox = bounds(built and built.area),
		hintBox = bounds(built and built.hint),
		world = self._worldId,
		arrivals = self._arrivals,
		windowChanges = self._windowChanges,
		textWrites = self._textWrites,
		box = RunLayout.describe(rect),
		width = rect.size.X,
		height = rect.size.Y,
		overlapsProtected = RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
		overlapsCash = RunLayout.overlaps(rect, cash),
		overlapsGear = RunLayout.overlaps(rect, gear),
		overlapsBanner = RunLayout.overlaps(rect, RunLayout.bannerRect(self._ctx)),
		instances = if built then #built.block:GetDescendants() else 0,
		textLabels = #texts,
		-- the removed Round 2 pieces: all must be zero
		imageLabels = images,
		viewportFrames = viewports,
		routePieces = stations,
		tweens = 0,
		threads = 0,
		renderStepped = false,
		connections = self._connections,
	}
end

function RouteLine.destroy(self: RouteLine)
	if self._built then
		self._built.trove:Destroy()
		self._built = nil
	end
	self._trove:Destroy()
	self._connections = 0
end

return RouteLine
