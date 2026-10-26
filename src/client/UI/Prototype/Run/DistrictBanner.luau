--!strict
-- District entry banner: the orange arrival popup (Lane 3 preview, HUD rebuild worker HR; U-04). On an
-- explicit store event { kind = "DistrictEnter", district = District.id, cycle = n } it shows one district
-- icon and the district name on a bold orange arcade surface below the distance pill (Round 3, R3-D: it
-- is KEPT; the route line above it was removed): 0.2 s in (a short drop + fade), about 1.6 s hold, 0.25 s out.
-- Reduced motion: fade only. It never decides that a district was entered; it only presents the supplied event.
-- The popup is placed by RunLayout.bannerRect, BannerGap below the pill; its entry drop is never larger than
-- that gap minus 2 px, so it cannot touch the pill while it settles, and it stays clear of Cash, Heat and the
-- protected road view (RunLayout.protected) on every frame.
--
-- Arbitration (ctx.priority, Prototype/Priority.luau): requests the "Upper" slot at "District"
-- and waits up to 4 s. A Safety warning suppresses "Upper" (RunEnd / warning chip), so the
-- banner is deferred while it holds and dropped if it would be stale. It never stacks with:
--   * a capture ribbon (it waits while a Capture-level holder has the "Side" slot; a ribbon that
--     arrives while the banner shows calls banner:yield(), which hides it early),
--   * the tutorial banner (store.tutorial ~= nil: dropped; the route line still names the district),
--   * toasts (they should request "Upper" through the same arbiter; noted for the lead).
-- Dedupe: one banner per (district, cycle); repeats and late duplicates are ignored, and an event
-- for a district the run has already left (out of order) is dropped as stale. A newer
-- district replaces a waiting older one.
--
--   local banner = DistrictBanner.new(ctx)
--   banner:show(districtId, cycle?)   -- the same as the event (preview)
--   banner:yield()                    -- hide now (a higher feedback took over)
--   banner:layout(), banner:setVisible(on), banner:destroy(), banner:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local IN = 0.2
local HOLD = 1.6
local OUT = 0.25
local WAIT = 4 -- seconds a banner may wait for the slot before it is stale
local DROP = math.min(8, RunLayout.BannerGap - 2) -- design px drop on entry (none in reduced motion); never reaches the pill

local RouteMath = require(script.Parent.RouteMath)

local DistrictBanner = {}
DistrictBanner.__index = DistrictBanner

function DistrictBanner.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, DistrictBanner)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._seen = {} :: { [string]: boolean }
	self._handle = nil :: any
	self._waitingKey = nil :: string?
	self._showing = nil :: string?
	self._token = 0
	self._shown = 0
	self._dropped = 0
	self._deferred = 0
	self._stale = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "DistrictBanner"))
	self.root = root
	local group = make("CanvasGroup", {
		Name = "Banner",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	RunKit.nonInteractive(group)
	self._group = group
	local band = make("Frame", {
		Name = "Band",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = group,
	})
	-- Round 2 (R2-HM3): the arcade surface (bold orange fill, one thick dark outline, gloss) instead of the tapered dark band
	Arcade.surface(band, "Missions")
	local content = make("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = group,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	local icon = make("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 7,
		Parent = content,
	})
	local name = Arcade.text(content, {
		text = "",
		role = "Button",
		name = "Name",
		size = 28,
		autoWidth = true,
		z = 8,
	})
	name.LayoutOrder = 2
	self._icon = icon
	self._name = name

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "DistrictEnter" and type(event.district) == "string" then
			self:show(event.district :: string, event.cycle)
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Run" then
			self:_cancelWaiting()
			self:_hide(true)
		end
		if mode == "Run" then
			table.clear(self._seen) -- a new run: banners may show again
		end
	end)
	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(group)
		self:_cancelWaiting()
		if self._handle then
			RunBus.priority(ctx):release(self._handle)
			self._handle = nil
		end
		RunBus.unregister(ctx, "banner", self)
	end)
	RunBus.register(ctx, "banner", self)
	self:layout()
	return self
end

export type DistrictBanner = typeof(DistrictBanner.new((nil :: any) :: RunLayout.Ctx))

local function districtName(ctx: RunLayout.Ctx, id: string): string?
	local run = ctx.store:get().run
	local plan = run and run.districtPlan
	if plan then
		for _, d in plan.districts do
			if d.id == id then
				return d.name
			end
		end
	end
	return nil
end

function DistrictBanner._cancelWaiting(self: DistrictBanner)
	if self._handle and self._waitingKey then
		RunBus.priority(self._ctx):release(self._handle)
		self._handle = nil
	end
	self._waitingKey = nil
end

function DistrictBanner.show(self: DistrictBanner, district: string, cycle: number?)
	local key = district .. ":" .. tostring(cycle or 1)
	if self._seen[key] then
		return -- duplicate or late repeat for the same (district, cycle)
	end
	self._seen[key] = true
	local ctx = self._ctx
	if ctx.store:get().mode ~= "Run" or not self._visible then
		self._dropped += 1
		return
	end
	if ctx.store:get().tutorial ~= nil then
		self._dropped += 1 -- never stacks with the tutorial banner; the route line still names it
		return
	end
	local name = districtName(ctx, district)
	if not name then
		self._dropped += 1 -- unknown district id: show nothing rather than a guessed name
		return
	end
	-- a late, out-of-order event for a district the run has already left is stale: drop it
	local run = ctx.store:get().run
	if run and run.districtPlan then
		local loc = RouteMath.locate(run.districtPlan, run.distance)
		local here = loc and run.districtPlan.districts[loc.index]
		if not here or here.id ~= district or (cycle ~= nil and loc ~= nil and loc.cycle ~= cycle) then
			self._stale += 1
			return
		end
	end
	-- a newer district replaces a waiting older one
	self:_cancelWaiting()
	local arb = RunBus.priority(ctx)
	local requestedAt = os.clock()
	local handle: any = nil
	local function tryShow()
		if self._waitingKey ~= key then
			return
		end
		-- a capture ribbon holding the side column wins; wait (bounded) for it to finish
		local _, sideLevel = arb:holder("Side")
		if sideLevel == "Capture" or sideLevel == "Safety" or RunBus.flags(ctx).ended then
			self._deferred += 1
			if os.clock() - requestedAt > WAIT or RunBus.flags(ctx).ended then
				self._dropped += 1
				self:_cancelWaiting()
				return
			end
			task.delay(0.3, tryShow)
			return
		end
		self._waitingKey = nil
		self:_present(key, district, name :: string, handle)
	end
	self._waitingKey = key
	handle = arb:request("Upper", "District", "district-" .. key, {
		grant = tryShow,
		revoke = function()
			if self._showing == key then
				self:_hide(true)
			end
		end,
		wait = WAIT,
	})
	self._handle = handle
	if handle == nil then
		self._waitingKey = nil
		self._dropped += 1
	end
end

function DistrictBanner._present(self: DistrictBanner, key: string, district: string, name: string, handle: any)
	self._token += 1
	local token = self._token
	self._showing = key
	self._handle = handle
	self._shown += 1
	self._icon:ClearAllChildren()
	Arcade.icon(self._icon, "District_" .. district)
	self._name.Text = string.upper(name)
	self:layout()
	local group = self._group
	local rect = RunLayout.bannerRect(self._ctx)
	local reduced = Motion.reduced()
	group.Visible = true
	group.GroupTransparency = 1
	if reduced then
		group.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
		Motion.tween(group, "fade", Motion.info(IN), { GroupTransparency = 0 })
	else
		group.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y - DROP)
		Motion.tween(group, "fade", Motion.info(IN), { GroupTransparency = 0 })
		Motion.tween(group, "move", Motion.info(IN, Enum.EasingStyle.Back), {
			Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y),
		})
	end
	task.delay(IN + HOLD, function()
		if token == self._token then
			self:_hide(false)
		end
	end)
end

function DistrictBanner._hide(self: DistrictBanner, immediate: boolean)
	self._token += 1
	local token = self._token
	local group = self._group
	if self._showing then
		self._showing = nil
		if self._handle then
			RunBus.priority(self._ctx):release(self._handle)
			self._handle = nil
		end
	end
	if immediate then
		Motion.cancelAll(group)
		group.GroupTransparency = 1
		group.Visible = false
		return
	end
	local t = Motion.tween(group, "fade", Motion.info(OUT), { GroupTransparency = 1 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and token == self._token then
			group.Visible = false
		end
	end)
end

function DistrictBanner.yield(self: DistrictBanner)
	if self._showing then
		self:_hide(false)
	end
end

function DistrictBanner.layout(self: DistrictBanner)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect = RunLayout.bannerRect(ctx)
	self._group.Size = UDim2.fromOffset(rect.size.X, rect.size.Y)
	self._group.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
	local compact = RunLayout.compact(ctx)
	local iconSize = if compact then 30 else 40
	self._icon.Size = UDim2.fromOffset(iconSize, iconSize)
	self._name.TextSize = if compact then 22 else 28
end

function DistrictBanner.setVisible(self: DistrictBanner, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:_cancelWaiting()
		self:_hide(true)
	end
end

function DistrictBanner.getDebugState(self: DistrictBanner): { [string]: any }
	local seen = 0
	for _ in self._seen do
		seen += 1
	end
	local rect = RunLayout.bannerRect(self._ctx)
	local pill = RunLayout.routeRect(self._ctx)
	return {
		visible = self._visible,
		showing = self._showing,
		waiting = self._waitingKey,
		shown = self._shown,
		dropped = self._dropped,
		deferredChecks = self._deferred,
		stale = self._stale,
		seenKeys = seen,
		text = self._name.Text,
		box = RunLayout.describe(rect),
		overlapsProtected = RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
		overlapsPill = RunLayout.overlaps(rect, pill),
		overlapsCash = RunLayout.overlaps(rect, RunLayout.cashRect(self._ctx)),
		overlapsHeat = RunLayout.overlaps(rect, (RunLayout.heatRect(self._ctx))),
		-- the highest the popup ever is (the start of its entry drop) against the bottom of the pill
		topWithDrop = rect.pos.Y - DROP,
		pillBottom = pill.pos.Y + pill.size.Y,
		-- the popup draws in one CanvasGroup: no tween is left once it has faded out
		groupVisible = self._group.Visible,
	}
end

function DistrictBanner.destroy(self: DistrictBanner)
	self._trove:Destroy()
end

return DistrictBanner
