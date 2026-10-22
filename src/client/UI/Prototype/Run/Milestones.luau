--!strict
-- Distance milestones for the rebuilt run view (Lane 3 preview; overnight worker H3, restyled to
-- the Arcade kit and the priority hierarchy by HUD rebuild worker HR; U-08). On a store event
-- { kind = "Milestone", text = "1 KM!" } it shows a brief message (1.2 s) in the "Upper" row
-- under the district strip: a flag icon and a big white outlined italic number, no backing card.
-- The text is supplied; this module never decides a milestone.
--
-- Arbitration (ctx.priority): requests "Upper" at "Reward" (below District and Safety) and may
-- wait 1.5 s; a district banner or a Safety suppression wins (a showing milestone is revoked and
-- not re-shown). Only the newest waiting milestone matters (an older one is dropped); a duplicate
-- text is merged.
--
--   local ms = Milestones.new(ctx)
--   ms:show(text)   -- the same as the event (preview)
--   ms:layout(), ms:setVisible(on), ms:destroy(), ms:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local SECONDS = 1.2
local WAIT = 1.5

local Milestones = {}
Milestones.__index = Milestones

function Milestones.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, Milestones)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._showing = nil :: string?
	self._waiting = nil :: string?
	self._handle = nil :: any
	self._shown = 0
	self._dropped = 0
	self._revoked = 0
	self._token = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "Milestones"))
	self.root = root
	local holder = make("CanvasGroup", {
		Name = "Milestone",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(320, 52),
		Parent = root,
	})
	RunKit.nonInteractive(holder)
	self._holder = holder
	local inner = make("Frame", {
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inner,
	})
	self._inner = inner
	local icon = make("Frame", {
		Name = "Flag",
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 2,
		Parent = inner,
	})
	Arcade.icon(icon, "Flag")
	local text = Arcade.text(inner, {
		text = "",
		role = "Display",
		name = "Text",
		italic = true,
		face = "White",
		autoWidth = true,
		z = 3,
	})
	text.LayoutOrder = 2
	self._text = text

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "Milestone" and type(event.text) == "string" then
			self:show(event.text :: string)
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Run" then
			self:_cancelWaiting()
			self:_hide(true)
		end
	end)
	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(holder)
		self:_cancelWaiting()
		if self._handle then
			RunBus.priority(ctx):release(self._handle)
			self._handle = nil
		end
	end)
	self:layout()
	return self
end

export type Milestones = typeof(Milestones.new((nil :: any) :: RunLayout.Ctx))

function Milestones._cancelWaiting(self: Milestones)
	if self._waiting and self._handle then
		RunBus.priority(self._ctx):release(self._handle)
		self._handle = nil
	end
	self._waiting = nil
end

function Milestones.layout(self: Milestones)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local d = RunLayout.design(ctx)
	self._holder.Position = UDim2.fromOffset(d.X / 2, RunLayout.upperY(ctx))
	self._holder.Size = UDim2.fromOffset(math.min(360, d.X - 24), 52)
end

function Milestones.show(self: Milestones, text: string)
	if self._showing == text or self._waiting == text then
		return -- merged duplicate
	end
	if not self._visible or self._ctx.store:get().mode ~= "Run" then
		self._dropped += 1
		return
	end
	if self._waiting then
		self._dropped += 1 -- only the newest waiting milestone is still relevant
		self:_cancelWaiting()
	end
	if self._showing then
		self:_hide(true)
	end
	self._waiting = text
	local handle: any = nil
	handle = RunBus.priority(self._ctx):request("Upper", "Reward", "milestone-" .. text, {
		grant = function()
			if self._waiting == text then
				self._waiting = nil
				self:_present(text)
			end
		end,
		revoke = function()
			if self._showing == text then
				self._revoked += 1
				self._handle = nil
				self:_hide(true)
			end
		end,
		wait = WAIT,
	})
	self._handle = handle
	if handle == nil then
		self._waiting = nil
		self._dropped += 1
	end
end

function Milestones._present(self: Milestones, text: string)
	self._token += 1
	local token = self._token
	self._showing = text
	self._shown += 1
	self._text.Text = text
	Sounds.play("Milestone")
	local holder = self._holder
	holder.Visible = true
	local reduced = Motion.reduced()
	holder.GroupTransparency = 1
	Motion.tween(holder, "fade", Motion.info(if reduced then 0.12 else 0.16), { GroupTransparency = 0 })
	if not reduced then
		Motion.pop(self._inner, 1.08)
	end
	task.delay(SECONDS, function()
		if token == self._token then
			self:_hide(false)
		end
	end)
end

function Milestones._hide(self: Milestones, immediate: boolean)
	self._token += 1
	local holder = self._holder
	if self._showing then
		self._showing = nil
		if self._handle and not self._waiting then
			RunBus.priority(self._ctx):release(self._handle)
			self._handle = nil
		end
	end
	local token = self._token
	if immediate then
		Motion.cancelAll(holder)
		holder.GroupTransparency = 1
		holder.Visible = false
		return
	end
	local t = Motion.tween(holder, "fade", Motion.info(0.18), { GroupTransparency = 1 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and token == self._token then
			holder.Visible = false
		end
	end)
end

function Milestones.setVisible(self: Milestones, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:_cancelWaiting()
		self:_hide(true)
	end
end

function Milestones.getDebugState(self: Milestones): { [string]: any }
	return {
		visible = self._visible,
		showing = self._showing,
		waiting = self._waiting,
		shown = self._shown,
		dropped = self._dropped,
		revoked = self._revoked,
		y = self._holder.Position.Y.Offset,
		upperY = RunLayout.upperY(self._ctx),
	}
end

function Milestones.destroy(self: Milestones)
	self._trove:Destroy()
end

return Milestones
