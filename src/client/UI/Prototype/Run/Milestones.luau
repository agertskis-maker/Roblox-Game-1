--!strict
-- Distance milestones for the run view (Lane 3 preview, worker H3). On a store event
-- { kind = "Milestone", text = "1 KM!" } it shows a brief upper-screen message (1.2 s) centred
-- under Distance + coins (RunLayout.messageY, which also clears a tutorial banner), so it never
-- collides with Distance or the banner. The text is supplied; this module never decides a
-- milestone.
--
-- Arbitration: milestones use the shared message slot at the lowest priority (1). While the
-- capture celebration or the Already-owned note holds the slot, milestones wait in a small queue
-- (at most 2; an older waiting milestone is replaced by a newer one, and a duplicate text is
-- merged). A new milestone while one is showing replaces it.
--
--   local ms = Milestones.new(ctx)
--   ms:show(text)   -- the same as the event (preview)
--   ms:layout(), ms:setVisible(on), ms:destroy(), ms:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

local SECONDS = 1.2
local QUEUE = 2
local TEXT_SIZE = Tokens.TextSize.Display -- 36
local OWNER = "Milestones"
local PRIORITY = 1

local Milestones = {}
Milestones.__index = Milestones

function Milestones.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, Milestones)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._showing = nil :: string?
	self._queue = {} :: { string }
	self._shown = 0
	self._replaced = 0
	self._dropped = 0
	self._token = 0
	self._slot = RunLayout.slot(ctx.screen)

	local root = self._trove:Add(RunLayout.canvas(ctx, "Milestones"))
	self.root = root
	local holder = make("CanvasGroup", {
		Name = "Milestone",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(300, TEXT_SIZE + 16),
		Parent = root,
	})
	self._holder = holder
	local inner = make("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	self._inner = inner
	local icon = make("Frame", {
		Name = "Flag",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = inner,
	})
	Icons.draw(icon, "Flag", C.White)
	local text = Gloss.title(inner, "", TEXT_SIZE, C.White, Tokens.Color.FloatTextCream)
	text.Name = "Text"
	text.AnchorPoint = Vector2.new(1, 0.5)
	text.Position = UDim2.new(1, -6, 0.5, 0)
	text.TextXAlignment = Enum.TextXAlignment.Right
	text.ZIndex = 3
	self._text = text

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "Milestone" and type(event.text) == "string" then
			self:show(event.text)
		end
	end)
	self._trove:Connect(self._slot.Preempted, function(owner: string)
		if owner == OWNER and self._showing then
			-- a more important message took the slot: hide now, do not re-show this one
			self:_hide(true)
		end
	end)
	self._trove:Connect(self._slot.Freed, function()
		if not self._showing and #self._queue > 0 then
			task.defer(function()
				self:_next()
			end)
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Run" then
			table.clear(self._queue)
			self:_hide(true)
		end
	end)
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(holder)
		if self._showing then
			self._slot.release(OWNER)
		end
	end)
	self:layout()
	return self
end

export type Milestones = typeof(Milestones.new((nil :: any) :: RunLayout.Ctx))

function Milestones.layout(self: Milestones)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local d = RunLayout.design(ctx)
	self._holder.Position = UDim2.fromOffset(d.X / 2, RunLayout.messageY(ctx))
	self:_size()
end

function Milestones._size(self: Milestones)
	local d = RunLayout.design(self._ctx)
	local w = TextService:GetTextSize(self._text.Text, TEXT_SIZE, Enum.Font.FredokaOne, Vector2.new(4096, 128)).X
	local total = math.min(math.ceil(w) + 8 + 34 + 12 + 10, d.X - 24)
	self._holder.Size = UDim2.fromOffset(total, TEXT_SIZE + 16)
	self._text.Size = UDim2.new(1, -(34 + 16), 0, TEXT_SIZE + 8)
end

function Milestones.show(self: Milestones, text: string)
	if self._showing == text then
		return -- merged duplicate
	end
	local holder = self._slot.holder()
	if holder ~= nil and holder ~= OWNER then
		-- a more important message is up: wait (bounded queue, newest wins)
		local i = table.find(self._queue, text)
		if i then
			return
		end
		table.insert(self._queue, text)
		while #self._queue > QUEUE do
			table.remove(self._queue, 1)
			self._dropped += 1
		end
		return
	end
	if self._showing then
		self._replaced += 1
	end
	self:_present(text)
end

function Milestones._next(self: Milestones)
	local h = self._slot.holder()
	if self._showing or (h ~= nil and h ~= OWNER) then
		return
	end
	local text = table.remove(self._queue, #self._queue)
	if #self._queue > 0 then
		self._dropped += #self._queue -- only the newest waiting milestone is still relevant
		table.clear(self._queue)
	end
	if text then
		self:_present(text)
	end
end

function Milestones._present(self: Milestones, text: string)
	if not self._slot.claim(OWNER, PRIORITY) then
		table.insert(self._queue, text)
		return
	end
	self._token += 1
	local token = self._token
	self._showing = text
	self._shown += 1
	self._text.Text = text
	self:layout()
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
	if not self._showing then
		return
	end
	self._showing = nil
	local holder = self._holder
	local token = self._token
	if immediate then
		Motion.cancelAll(holder)
		holder.GroupTransparency = 1
		holder.Visible = false
	else
		local t = Motion.tween(holder, "fade", Motion.info(0.18), { GroupTransparency = 1 })
		t.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and token == self._token then
				holder.Visible = false
			end
		end)
	end
	self._slot.release(OWNER)
end

function Milestones.setVisible(self: Milestones, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		table.clear(self._queue)
		self:_hide(true)
	end
end

function Milestones.getDebugState(self: Milestones): { [string]: any }
	local top = RunLayout.top(self._ctx.screen)
	local y = self._holder.Position.Y.Offset
	return {
		visible = self._visible,
		showing = self._showing,
		queued = table.clone(self._queue),
		shown = self._shown,
		replaced = self._replaced,
		dropped = self._dropped,
		textFits = self._text.TextFits,
		y = y,
		clearOfDistance = y >= top.stackBottom,
		slotHolder = self._slot.holder(),
	}
end

function Milestones.destroy(self: Milestones)
	self._trove:Destroy()
end

return Milestones
