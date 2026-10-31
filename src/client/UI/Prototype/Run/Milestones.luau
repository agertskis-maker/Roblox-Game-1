--!strict
-- Distance milestones for the rebuilt run view (Lane 3 preview; overnight worker H3, restyled to
-- the Arcade kit and the priority hierarchy by HUD rebuild worker HR; U-08). On a store event
-- { kind = "Milestone", text = "1 KM!" } it shows a brief message (1.2 s) in the "Upper" row
-- under the district strip: a flag icon and a big white outlined italic number on a bold gold
-- arcade surface (Round 3, R2-HM3: fill, ONE dark outline, gloss; it was a bare number with no
-- band, the round 1 look). The band is 52 design px tall while that clears the protected road
-- rectangle and slims to 36 (text 22) where it would reach into it. The text is supplied; this
-- module never decides a milestone.
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
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local SECONDS = 1.2
local WAIT = 1.5
-- Band heights (design px). BAND_H is the holder height Round 2 used; where it would reach into the protected road
-- rectangle the band slims, never below BAND_MIN (an icon and a number that still read; text never below 16).
local BAND_H = 52
local BAND_MIN = 36
local TEXT_MIN = 22
local ICON_MAX = 40
local EDGE = A.OutlineButton -- the band's outline thickness, kept inside the group's bounds (3 design px)

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
	self._timer = nil :: thread? -- the pending hide (cancelled on hide and destroy)
	self._conn = nil :: RBXScriptConnection? -- the fade-out completion in flight
	self._textSize = A.Text.Display
	self._bandH = BAND_H

	local root = self._trove:Add(RunLayout.canvas(ctx, "Milestones"))
	self.root = root
	local holder = make("CanvasGroup", {
		Name = "Milestone",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(320, BAND_H),
		Parent = root,
	})
	RunKit.nonInteractive(holder)
	self._holder = holder
	-- Round 3 (R2-HM3): the arcade surface behind the flag and the number (gold, ONE dark outline, gloss). A border
	-- outline grows outward from its frame and a CanvasGroup clips at its own edge, so the band sits EDGE px inside it.
	local band = make("Frame", {
		Name = "Band",
		Position = UDim2.fromOffset(EDGE, EDGE),
		Size = UDim2.new(1, -2 * EDGE, 1, -2 * EDGE),
		ZIndex = 1,
		Parent = holder,
	})
	Arcade.surface(band, "Gold")
	self._band = band
	local inner = make("Frame", {
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
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
		Size = UDim2.fromOffset(ICON_MAX, ICON_MAX),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 5,
		Parent = inner,
	})
	Arcade.icon(icon, "Flag")
	self._icon = icon
	local text = Arcade.text(inner, {
		text = "",
		role = "Display",
		name = "Text",
		italic = true,
		face = "White",
		autoWidth = true,
		z = 6,
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
		self:_clearTimer()
		self:_dropConn()
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

function Milestones._clearTimer(self: Milestones)
	local pending = self._timer
	self._timer = nil
	if pending then
		pcall(task.cancel, pending)
	end
end

function Milestones._dropConn(self: Milestones)
	local conn = self._conn
	self._conn = nil
	if conn then
		conn:Disconnect()
	end
end

function Milestones.layout(self: Milestones)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local d = RunLayout.design(ctx)
	local y = RunLayout.upperY(ctx)
	-- Round 3 (R2-HM3): the full band while it clears the protected road rectangle, else as slim as it can read
	-- (BAND_MIN): the room under the route line is smaller than the band on the tablet and every phone frame
	local room = RunLayout.protected(ctx).pos.Y - y
	local h = math.clamp(room, BAND_MIN, BAND_H)
	local textSize = math.clamp(h - 14, TEXT_MIN, A.Text.Display)
	local iconSize = math.min(ICON_MAX, h - 8)
	self._bandH = h
	self._textSize = textSize
	self._holder.Position = UDim2.fromOffset(d.X / 2, y)
	self._holder.Size = UDim2.fromOffset(math.min(360, d.X - 24), h)
	self._icon.Size = UDim2.fromOffset(iconSize, iconSize)
	self._text.TextSize = textSize
	self._text.Size = UDim2.fromOffset(0, textSize + 6)
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
	self:_clearTimer()
	local thread: thread
	thread = task.delay(SECONDS, function()
		if self._timer == thread then
			self._timer = nil
		end
		if token == self._token then
			self:_hide(false)
		end
	end)
	self._timer = thread
end

function Milestones._hide(self: Milestones, immediate: boolean)
	self._token += 1
	self:_clearTimer()
	self:_dropConn()
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
	local conn: RBXScriptConnection
	conn = t.Completed:Connect(function(state)
		if self._conn == conn then
			self._conn = nil
		end
		conn:Disconnect()
		if state == Enum.PlaybackState.Completed and token == self._token then
			holder.Visible = false
		end
	end)
	self._conn = conn
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
	local ctx = self._ctx
	local outlines, gradients = 0, 0
	for _, child in self._band:GetChildren() do
		if child:IsA("UIStroke") then
			outlines += 1
		elseif child:IsA("UIGradient") then
			gradients += 1
		end
	end
	-- the band against the protected road rectangle, in design px (0 = clear); the Upper row has only this much
	-- room under the route line on the tablet and the phone frames (the band slims, it cannot clear it)
	local prot = RunLayout.protected(ctx)
	local y = self._holder.Position.Y.Offset
	local bottom = y + self._bandH
	local width = self._holder.Size.X.Offset
	local left = self._holder.Position.X.Offset - width / 2
	local overlapX = math.max(0, math.min(left + width, prot.pos.X + prot.size.X) - math.max(left, prot.pos.X))
	local overlapY = math.max(0, math.min(bottom, prot.pos.Y + prot.size.Y) - math.max(y, prot.pos.Y))
	return {
		visible = self._visible,
		showing = self._showing,
		waiting = self._waiting,
		shown = self._shown,
		dropped = self._dropped,
		revoked = self._revoked,
		y = y,
		upperY = RunLayout.upperY(ctx),
		bandHeight = self._bandH,
		textSize = self._textSize,
		bandWidth = width,
		protectedOverlapX = overlapX,
		protectedOverlapY = overlapY, -- how far the band reaches down into the protected rectangle (design px)
		surface = { outlines = outlines, gradients = gradients, gloss = self._band:FindFirstChild("Gloss") ~= nil },
		timers = if self._timer ~= nil then 1 else 0, -- the pending hide (0 after destroy)
		connections = if self._conn ~= nil then 1 else 0, -- the fade-out completion in flight (0 after destroy)
		instances = #self.root:GetDescendants(), -- 0 after destroy
	}
end

function Milestones.destroy(self: Milestones)
	self._trove:Destroy()
end

return Milestones
