--!strict
-- Home HUD: timer stack PROPOSAL (Lane 3 preview, HUD rebuild 2026-10-22; ledger H-11, C3).
-- OFF by default: shown only while store.proposals.timers is true, AND only inside the
-- harness's annotated-capture view (the whole content carries PreviewCaption = true, so the
-- playground hides it in player-facing captures). Never shown to ordinary players.
--
-- What it shows: one bottom-right row, an original Event icon (Icons2 "Event", fallback "Timer")
-- left of an italic outlined white timer "Stunt Race in 3m 25s", right-aligned, plus a small
-- caption "PROPOSAL · fixture countdown". The countdown is a FIXTURE: a local number of seconds
-- that counts down once per second while visible and starts again from the fixture value at 0.
-- There is no scheduled event, no server time, no authoritative clock and no reward. Children's
-- audience: no urgency colours, no flashing, no "hurry"/"last chance" wording.
--
-- Placement: Home/Layout timers (bottom-right; above the Jump zone on touch profiles).
--
-- API: TimerStack.new(ctx, Options?) -> TimerStack
--   :layout()  :setVisible(on)  :destroy()  :getDebugState()
--   :setFixture(label, seconds)     -- e.g. ("Stunt Race", 205)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

-- TOKEN CANDIDATE: timer event icon box (about 2x the timer cap, from the reference study).
local ICON = 44

export type Options = { label: string?, seconds: number? }

export type TimerStack = {
	root: Frame,
	layout: (self: TimerStack) -> (),
	setVisible: (self: TimerStack, on: boolean) -> (),
	destroy: (self: TimerStack) -> (),
	setFixture: (self: TimerStack, label: string, seconds: number) -> (),
	getDebugState: (self: TimerStack) -> { [string]: any },
}

local TimerStack = {}
TimerStack.__index = TimerStack

local function timeText(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%dm %02ds", s // 60, s % 60)
end
TimerStack.timeText = timeText

function TimerStack.new(ctx: Types.Ctx, options: Options?): TimerStack
	local self = setmetatable({}, TimerStack) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._destroyed = false
	self._wanted = true
	self._label = (options and options.label) or "Stunt Race"
	self._fixture = (options and options.seconds) or 205
	self._remaining = self._fixture
	self._thread = nil :: thread?

	local root = trove:Add(Arcade.make("Frame", {
		Name = "TimerStack",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(Layout.TimerWidth, Layout.TimerHeight + 20),
		Visible = false,
		ZIndex = 4,
		Parent = ctx.layer,
	}))
	pcall(function()
		(root :: any).Interactable = false
	end)
	self.root = root
	self._scale = Arcade.make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	-- the harness shows PreviewCaption content only in annotated review captures
	local content = Arcade.make("Frame", {
		Name = "Proposal",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	content:SetAttribute("PreviewCaption", true)
	self._content = content

	local row = Arcade.make("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(1, 0, 0, Layout.TimerHeight),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = content,
	})
	Arcade.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = row,
	})
	local icon = Arcade.make("Frame", {
		Name = "EventIcon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = row,
	})
	self._iconName = IconArt.draw(icon, { "Event", "Timer" })
	local text = Arcade.text(row, {
		text = "",
		role = "Timer",
		name = "Timer",
		italic = true,
		xAlign = Enum.TextXAlignment.Right,
		autoWidth = true,
		z = 6,
	})
	text.LayoutOrder = 2
	self._text = text
	local caption = Arcade.text(content, {
		text = "PROPOSAL · fixture countdown",
		role = "Small",
		name = "Caption",
		colour = Color3.fromRGB(255, 236, 140),
		xAlign = Enum.TextXAlignment.Right,
		z = 6,
	})
	caption.AnchorPoint = Vector2.new(1, 0)
	caption.Position = UDim2.fromScale(1, 0)
	caption.Size = UDim2.new(1, 0, 0, 20)

	trove:Add(ctx.store:subscribe("proposals", function()
		self:_apply()
	end))
	trove:Add(function()
		self:_stop()
	end)
	trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	self:_render()
	self:layout()
	self:_apply()
	return self :: TimerStack
end

function TimerStack._on(self: any): boolean
	local state: Store.State = self._ctx.store:get()
	local p = state.proposals
	return self._wanted and p ~= nil and p.timers == true
end

function TimerStack._render(self: any)
	self._text.Text = string.format("%s in %s", self._label, timeText(self._remaining))
end

function TimerStack._stop(self: any)
	local t: thread? = self._thread
	self._thread = nil
	if t and coroutine.status(t) ~= "dead" then
		pcall(task.cancel, t)
	end
end

-- One cancellable 1 Hz loop, running only while the proposal is shown.
function TimerStack._apply(self: any)
	local on = self:_on()
	self.root.Visible = on
	if not on then
		self:_stop()
		return
	end
	if self._thread then
		return
	end
	self._thread = task.spawn(function()
		while not self._destroyed do
			task.wait(1)
			self._remaining -= 1
			if self._remaining < 0 then
				self._remaining = self._fixture -- fixture loop, not a schedule
			end
			self:_render()
		end
	end)
end

function TimerStack.setFixture(self: any, label: string, seconds: number)
	self._label = label
	self._fixture = math.max(1, math.floor(seconds))
	self._remaining = self._fixture
	self:_render()
end

function TimerStack.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local t = Layout.forProfile(ctx.screen:profile(), scale).timers
	self.root.Position = UDim2.fromOffset(t.right * scale, t.bottom * scale) -- layer px
end

function TimerStack.setVisible(self: any, on: boolean)
	self._wanted = on
	self:_apply()
end

function TimerStack.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local pos, size = ctx.screen:rectOf(self.root)
	return {
		proposalOn = self:_on(),
		visible = self.root.Visible,
		captionLayerVisible = self._content.Visible,
		text = self._text.Text,
		remaining = self._remaining,
		icon = self._iconName or "Missing",
		loopRunning = self._thread ~= nil,
		devicePos = pos,
		deviceSize = size,
		reservedOverlap = ctx.screen:overlapsReserved(pos, size),
	}
end

function TimerStack.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return TimerStack
