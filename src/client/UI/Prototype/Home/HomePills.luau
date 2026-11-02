--!strict
-- Home/HomePills: the top-centre column of the Round 2 Home HUD (Lane 3, N7-01 / N7-04a, 2026-11-02): ONE notification pill
-- for an event ("RACEWAY LEVEL 5!", "NEW CAR!", "3 CARS EARNED $1,250") over ONE goal pill with a progress bar ("NEXT WORLD
-- READY! Walk into its portal!"), as in IMG-09 and reference A. They stack neatly: the goal pill rises into the notification's
-- place while no event shows. While the tutorial runs the whole column slides away (setSuppressed(true)): the tutorial
-- banner takes this spot, and nothing here ever draws over it.
--
--   local pills = HomePills.new(parent)
--   pills:place(plan, scale)                   -- HomeLayout.TopPlan and the HUD scale
--   pills:notify(text, icon?)                  -- one event; a repeat of the shown text within 1 s only extends its dwell
--   pills:setGoal(spec?)                       -- { title, subtitle?, progress? 0..1, icon?, onActivate? }; nil clears it
--   pills:setSuppressed(on)  pills:setVisible(on)  pills:getDebugState()  pills:destroy()
--
-- Motion (N7-04a starting values): a pill slides in over 0.18 s and out over 0.14 s, a notification is readable for 2.5 s,
-- the bar fills over 0.25 s. Events wait in a short queue (at most 4; the oldest waiting one is dropped, an event is
-- information, not a claim). Reduced motion: no slide and no bar tween; the pills just appear and disappear. A soft "Toast"
-- sound plays through the UI SoundGroup when a notification appears (the sound throttle keeps it from stacking).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local HomeLayout = require(script.Parent.HomeLayout)
local HomeView = require(script.Parent.HomeView)
local IconArt = require(script.Parent.IconArt)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make
local A = PreviewTokens.Arcade
local DEPTH = A.Button.DepthOffset

local DWELL = 2.5
local SLIDE_IN = 0.18
local SLIDE_OUT = 0.14
local QUEUE_LIMIT = 4
local COALESCE_WINDOW = 1
local GAP = 6
local PILL = Color3.fromRGB(20, 26, 48)

export type GoalSpec = {
	title: string,
	subtitle: string?,
	progress: number?,
	icon: string?,
	onActivate: (() -> ())?,
}

export type Pills = {
	place: (self: Pills, plan: HomeLayout.TopPlan, scale: number) -> (),
	notify: (self: Pills, text: string, icon: string?) -> (),
	setGoal: (self: Pills, spec: GoalSpec?) -> (),
	setSuppressed: (self: Pills, on: boolean) -> (),
	setVisible: (self: Pills, on: boolean) -> (),
	getDebugState: (self: Pills) -> { [string]: any },
	destroy: (self: Pills) -> (),
}

type Queued = { text: string, icon: string? }

local HomePills = {}
HomePills.__index = HomePills

local function measure(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

-- THE NOTIFICATION PILL ---------------------------------------------------------------------------------------------

function HomePills._buildNotification(self: any)
	local holder = make("Frame", {
		Name = "Notification",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.fromOffset(240, 44),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = self.root,
	})
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, DEPTH),
		Size = UDim2.new(1, 0, 1, -DEPTH),
		BackgroundColor3 = A.Ink,
		ZIndex = 6,
		Parent = holder,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = lip })
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -DEPTH),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 7,
		Parent = holder,
	})
	Arcade.surface(body, "Gold")
	local corner = body:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = body,
	})
	local text = Arcade.text(body, {
		text = "",
		role = "Value",
		name = "Text",
		size = Tokens.TextSize.Value,
		xAlign = Enum.TextXAlignment.Center,
		z = 9,
	})
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.new(0, 44, 0.5, 0)
	text.Size = UDim2.new(1, -56, 0, 30)
	make(
		"UITextSizeConstraint",
		{ MaxTextSize = Tokens.TextSize.Value, MinTextSize = Tokens.TextSize.Minimum, Parent = text }
	)
	text.TextScaled = true
	self._n = { holder = holder, icon = icon, text = text, height = 44 }
end

function HomePills._showNext(self: any)
	if self._destroyed or self._nShown or self._suppressed or not self._visible then
		return
	end
	local item: Queued? = table.remove(self._queue, 1)
	if not item then
		return
	end
	local n = self._n
	local plan: HomeLayout.TopPlan? = self._plan
	local maxW = if plan then plan.width else 400
	local phone = plan ~= nil and plan.compact
	local h = if phone then 40 else 46
	n.height = h
	n.text.Text = item.text
	local textW = measure(item.text, Tokens.TextSize.Value)
	local w = math.clamp(math.ceil(textW) + 44 + 24, 160, maxW)
	n.holder.Size = UDim2.fromOffset(w, h + DEPTH)
	local iconSize = h - 12
	n.icon.Size = UDim2.fromOffset(iconSize, iconSize)
	IconArt.draw(n.icon, if item.icon then { item.icon, "Star" } else { "Star" })
	self._nShown = item
	self._nToken += 1
	local token: number = self._nToken
	self:_layoutStack(true)
	n.holder.Visible = true
	Sounds.play("Toast")
	local rest = UDim2.fromScale(0.5, 0)
	if Motion.reduced() then
		Motion.cancelAll(n.holder)
		n.holder.Position = rest
	else
		n.holder.Position = UDim2.new(0.5, 0, 0, -(h + 16))
		Motion.tween(n.holder, "slide", Motion.info(SLIDE_IN, Enum.EasingStyle.Back), { Position = rest })
	end
	self._nShownAt = os.clock()
	self._nThread = task.spawn(function()
		-- the dwell can be extended by a repeat of the same text
		while not self._destroyed and token == self._nToken do
			local left = self._nShownAt + DWELL - os.clock()
			if left <= 0 then
				break
			end
			task.wait(math.min(left, 0.25))
		end
		if self._destroyed or token ~= self._nToken then
			return
		end
		self:_hideNotification(token)
	end)
end

function HomePills._hideNotification(self: any, token: number)
	local n = self._n
	local function finish()
		if token ~= self._nToken then
			return
		end
		n.holder.Visible = false
		self._nShown = nil
		self:_layoutStack(true)
		self:_showNext()
	end
	if Motion.reduced() then
		finish()
		return
	end
	local tw = Motion.tween(
		n.holder,
		"slide",
		Motion.info(SLIDE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, 0, 0, -(n.height + 16)) }
	)
	tw.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			finish()
		end
	end)
end

function HomePills.notify(self: any, text: string, icon: string?)
	if self._destroyed or type(text) ~= "string" or text == "" then
		return
	end
	local now = os.clock()
	local shown: Queued? = self._nShown
	if shown and shown.text == text then
		-- a repeat of the pill on screen: keep one pill, give it a little more time (coalescing)
		if now - self._nShownAt <= DWELL then
			self._nShownAt = math.max(self._nShownAt, now - DWELL + COALESCE_WINDOW + 0.5)
		end
		return
	end
	for _, q in self._queue do
		if q.text == text then
			return
		end
	end
	if #self._queue >= QUEUE_LIMIT then
		table.remove(self._queue, 1)
	end
	table.insert(self._queue, { text = text, icon = icon })
	self:_showNext()
end

-- THE GOAL PILL -----------------------------------------------------------------------------------------------------

function HomePills._buildGoal(self: any)
	local holder = make("Frame", {
		Name = "Goal",
		Position = UDim2.fromOffset(0, -120),
		Size = UDim2.fromOffset(300, 70),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = self.root,
	})
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, DEPTH),
		Size = UDim2.new(1, 0, 1, -DEPTH),
		BackgroundColor3 = A.Ink,
		ZIndex = 5,
		Parent = holder,
	})
	Arcade.corner(lip, 18)
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -DEPTH),
		BackgroundColor3 = PILL,
		BackgroundTransparency = 0.04,
		ZIndex = 6,
		Parent = holder,
	})
	Arcade.corner(body, 18)
	Arcade.outline(body, "Button")
	Arcade.gloss(body)
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = body,
	})
	local title = Arcade.text(body, {
		text = "",
		role = "Label",
		name = "Title",
		size = 20,
		face = "Keys",
		outline = "Major",
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	local subtitle = Arcade.text(body, {
		text = "",
		role = "Small",
		name = "Subtitle",
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	local track = make("Frame", {
		Name = "Track",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.2,
		ZIndex = 8,
		Parent = body,
	})
	Arcade.corner(track, 8)
	Arcade.outline(track, "Minor")
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = 9,
		Parent = track,
	})
	Arcade.corner(fill, 8)
	make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = fill })
	local hit = make("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		ZIndex = 12,
		Visible = false,
		Parent = body,
	})
	self._trove:Connect(hit.Activated, function()
		local spec: GoalSpec? = self._goal
		if spec and spec.onActivate then
			Sounds.play("Tap")
			spec.onActivate()
		end
	end)
	self._g = {
		holder = holder,
		body = body,
		icon = icon,
		title = title,
		subtitle = subtitle,
		track = track,
		fill = fill,
		hit = hit,
	}
end

function HomePills._layoutGoal(self: any)
	local g = self._g
	local spec: GoalSpec? = self._goal
	local plan: HomeLayout.TopPlan? = self._plan
	if not spec or not plan then
		return
	end
	local compact = plan.compact
	local hasSub = spec.subtitle ~= nil and spec.subtitle ~= ""
	local hasBar = type(spec.progress) == "number"
	local pad = if compact then 6 else 8
	local titleH = if compact then 22 else 24
	local subH = if hasSub then 20 else 0
	local barH = if hasBar then 10 else 0
	local gaps = (if hasSub then 1 else 0) + (if hasBar then 3 else 0)
	local h = math.max(pad * 2 + titleH + subH + barH + gaps, 52)
	local iconSize = math.min(h - 12, 44)
	local w = plan.width
	g.holder.Size = UDim2.fromOffset(w, h + DEPTH)
	g.icon.Size = UDim2.fromOffset(iconSize, iconSize)
	local textX = 8 + iconSize + 8
	local textW = w - textX - 12
	g.title.TextSize = if compact then 18 else 20
	g.title.Position = UDim2.fromOffset(textX, pad)
	g.title.Size = UDim2.fromOffset(textW, titleH)
	g.title.TextXAlignment = Enum.TextXAlignment.Left
	g.subtitle.Visible = hasSub
	g.subtitle.Position = UDim2.fromOffset(textX, pad + titleH + 1)
	g.subtitle.Size = UDim2.fromOffset(textW, subH)
	g.track.Visible = hasBar
	g.track.Position = UDim2.fromOffset(textX + 3, pad + titleH + subH + gaps)
	g.track.Size = UDim2.fromOffset(textW - 6, barH)
	g.hit.Visible = spec.onActivate ~= nil
	self._goalHeight = h + DEPTH
end

function HomePills.setGoal(self: any, spec: GoalSpec?)
	if self._destroyed then
		return
	end
	local g = self._g
	local previous: GoalSpec? = self._goal
	self._goal = spec
	if not spec then
		self._goalOn = false
		self:_layoutStack(false)
		return
	end
	g.title.Text = spec.title
	g.subtitle.Text = spec.subtitle or ""
	IconArt.draw(g.icon, if spec.icon then { spec.icon, "Portal", "Flag" } else { "Portal", "Flag" })
	self:_layoutGoal()
	local p = if type(spec.progress) == "number" then math.clamp(spec.progress, 0, 1) else 0
	if Motion.reduced() or previous == nil then
		Motion.cancelAll(g.fill)
		g.fill.Size = UDim2.fromScale(p, 1)
	else
		Motion.tween(g.fill, "fill", Motion.info(0.25), { Size = UDim2.fromScale(p, 1) })
	end
	self._goalP = p
	local wasOn: boolean = self._goalOn
	self._goalOn = true
	self:_layoutStack(not wasOn)
	if previous ~= nil and previous.title ~= spec.title and not Motion.reduced() then
		Motion.pop(g.body, 1.04)
	end
end

-- THE STACK ---------------------------------------------------------------------------------------------------------

-- Where the goal pill sits: under the notification while one shows, else in the top place. It slides in from above when it
-- first appears and slides away when it is cleared or the tutorial takes the spot.
function HomePills._layoutStack(self: any, animateIn: boolean)
	local g = self._g
	local n = self._n
	local want = self._goalOn and not self._suppressed and self._visible
	local y = if self._nShown then n.height + DEPTH + GAP else 0
	local rest = UDim2.fromOffset(0, y)
	local height: number = self._goalHeight or 70
	if want then
		if not g.holder.Visible then
			g.holder.Visible = true
			if not Motion.reduced() then
				g.holder.Position = UDim2.fromOffset(0, -(height + 16))
			end
		end
		if Motion.reduced() then
			Motion.cancelAll(g.holder)
			g.holder.Position = rest
		else
			Motion.tween(g.holder, "stack", Motion.info(if animateIn then SLIDE_IN else 0.14), { Position = rest })
		end
	elseif g.holder.Visible then
		if Motion.reduced() then
			Motion.cancelAll(g.holder)
			g.holder.Visible = false
		else
			local tw = Motion.tween(
				g.holder,
				"stack",
				Motion.info(SLIDE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(0, -(height + 16)) }
			)
			tw.Completed:Connect(function(state)
				if
					state == Enum.PlaybackState.Completed
					and not (self._goalOn and not self._suppressed and self._visible)
				then
					g.holder.Visible = false
				end
			end)
		end
	end
	-- the notification column is hidden by the same rules
	if (self._suppressed or not self._visible) and self._nShown then
		self:_dropNotification()
	end
end

function HomePills._dropNotification(self: any)
	self._nToken += 1
	self._nShown = nil
	Motion.cancelAll(self._n.holder)
	self._n.holder.Visible = false
end

function HomePills.setSuppressed(self: any, on: boolean)
	if self._suppressed == on then
		return
	end
	self._suppressed = on
	if on then
		table.clear(self._queue)
	end
	self:_layoutStack(not on)
	if not on then
		self:_showNext()
	end
end

function HomePills.setVisible(self: any, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:_dropNotification()
	end
	self:_layoutStack(on)
	if on then
		self:_showNext()
	end
end

function HomePills.new(parent: Instance): Pills
	local self = setmetatable({}, HomePills) :: any
	self._trove = Trove.new()
	self._destroyed = false
	self._visible = true
	self._suppressed = false
	self._queue = {} :: { Queued }
	self._nShown = nil :: Queued?
	self._nShownAt = 0
	self._nToken = 0
	self._goal = nil :: GoalSpec?
	self._goalOn = false
	self._goalP = 0
	self._goalHeight = 70
	self._plan = nil :: HomeLayout.TopPlan?
	local root = self._trove:Add(make("Frame", {
		Name = "HomePills",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 130),
		ZIndex = 5,
		Parent = parent,
	}))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = 1, Parent = root })
	self:_buildNotification()
	self:_buildGoal()
	self._trove:Add(function()
		self._destroyed = true
		self._nToken += 1
		local thread: thread? = self._nThread
		if thread then
			pcall(task.cancel, thread)
		end
		Motion.cancelAll(self._n.holder)
		Motion.cancelAll(self._g.holder)
		Motion.cancelAll(self._g.fill)
		Motion.cancelAll(self._g.body)
	end)
	return self :: Pills
end

function HomePills.place(self: any, plan: HomeLayout.TopPlan, scale: number)
	self._plan = plan
	self._scale.Scale = scale
	self.root.Size = UDim2.fromOffset(plan.width, 140)
	self.root.Position = UDim2.fromOffset((plan.cx - plan.width / 2) * scale, plan.y * scale)
	if self._goal then
		self:_layoutGoal()
		self:_layoutStack(false)
	end
end

function HomePills.getDebugState(self: any): { [string]: any }
	local n = self._n
	local g = self._g
	return {
		suppressed = self._suppressed,
		notification = if self._nShown then (self._nShown :: Queued).text else nil,
		notificationVisible = n.holder.Visible,
		notificationAbsPos = HomeView.vec(n.holder.AbsolutePosition),
		notificationAbsSize = HomeView.vec(n.holder.AbsoluteSize),
		queued = #self._queue,
		goal = if self._goal then (self._goal :: GoalSpec).title else nil,
		goalVisible = g.holder.Visible,
		goalProgress = self._goalP,
		goalAbsPos = HomeView.vec(g.holder.AbsolutePosition),
		goalAbsSize = HomeView.vec(g.holder.AbsoluteSize),
		titleFits = g.title.TextFits,
		subtitleFits = g.subtitle.TextFits,
	}
end

function HomePills.destroy(self: any)
	self._trove:Destroy()
end

return HomePills
