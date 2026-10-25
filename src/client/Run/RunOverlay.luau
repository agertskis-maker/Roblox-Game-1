--!strict
-- Temporary run read-outs for the Lane 1 prototype: Foot Dash timer, banners, a rare-car alert,
-- the tray of cars caught this run, Rider Level, and the end card with Revive and Retry.
-- Lane 3 (Adam) designs and draws the real versions (Figma-first); these exist only so the
-- driving can be playtested and are labelled as such. Heat and Distance go to Adam's RunHud.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Results = {
	metres: number,
	hops: number,
	claimed: { string },
	joyrides: number,
	saves: number,
	cause: string,
	seed: number,
}

export type RunOverlay = {
	gui: ScreenGui,
	setFootDash: (self: RunOverlay, remaining: number?) -> (),
	banner: (self: RunOverlay, text: string, colour: Color3?) -> (),
	alert: (self: RunOverlay, text: string, colour: Color3) -> (),
	setHint: (self: RunOverlay, visible: boolean) -> (),
	setLevel: (self: RunOverlay, level: number, revives: number) -> (),
	addToTray: (self: RunOverlay, title: string, colour: Color3, isNew: boolean) -> (),
	showResults: (self: RunOverlay, results: Results, revivesLeft: number, onRevive: () -> (), onRetry: () -> ()) -> (),
	hideResults: (self: RunOverlay) -> (),
	destroy: (self: RunOverlay) -> (),
	_trove: any,
	_dash: Frame,
	_dashFill: Frame,
	_banner: TextLabel,
	_alert: TextLabel,
	_hint: TextLabel,
	_level: TextLabel,
	_tray: Frame,
	_results: Frame?,
	_bannerToken: number,
	_alertToken: number,
}

local RunOverlay = {}
RunOverlay.__index = RunOverlay

local CREAM = Color3.fromRGB(255, 248, 232)
local NAVY = Color3.fromRGB(28, 40, 72)
local GREEN = Color3.fromRGB(70, 190, 100)
local ORANGE = Color3.fromRGB(255, 140, 40)
local RED = Color3.fromRGB(230, 60, 50)

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function label(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = text,
		TextSize = size,
		TextColor3 = NAVY,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	return l
end

local function outlined(parent: Instance, text: string, size: number, props: { [string]: any }): TextLabel
	local l = label(parent, text, size, props)
	l.TextColor3 = (props.TextColor3 :: Color3?) or CREAM
	l.TextStrokeColor3 = NAVY
	l.TextStrokeTransparency = 0
	return l
end

local function button(parent: Instance, text: string, colour: Color3, position: UDim2, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		Name = text,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		Size = UDim2.fromOffset(160, 56),
		BackgroundColor3 = colour,
		FontFace = Tokens.font(),
		Text = text,
		TextSize = 24,
		TextColor3 = CREAM,
		AutoButtonColor = true,
	}, parent)
	corner(b, 14)
	make("UIStroke", { Color = NAVY, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	b.Activated:Connect(onClick)
	return b
end

function RunOverlay.new(parent: Instance): RunOverlay
	local trove = Trove.new()
	local gui: ScreenGui = trove:Add(make("ScreenGui", {
		Name = "Lane1RunOverlay",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}))

	local dash = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(300, 54),
		BackgroundColor3 = CREAM,
		Visible = false,
	}, gui)
	corner(dash, 14)
	make("UIStroke", { Color = NAVY, Thickness = 2 }, dash)
	label(dash, "On foot! Hop onto a car!", 18, { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 4) })
	local track = make("Frame", {
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 0, 12),
		BackgroundColor3 = Color3.fromRGB(220, 214, 200),
	}, dash)
	corner(track, 6)
	local dashFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED }, track)
	corner(dashFill, 6)

	local banner = outlined(gui, "", 36, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.fromOffset(700, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	local alert = outlined(gui, "", 24, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(700, 36),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	local hint = outlined(gui, "Steer: A / D or drag   ·   Hop: Space or tap", 18, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(520, 30),
	})

	local level = outlined(gui, "", 18, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(260, 48),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local tray = make("Frame", {
		Name = "Tray",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -120),
		Size = UDim2.fromOffset(240, 300),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, tray)

	outlined(gui, "Lane 1 run prototype · stand-in cars and labels · nothing is saved", 16, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -8),
		Size = UDim2.fromOffset(560, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.3,
	})

	gui.Parent = parent
	local self = setmetatable({
		gui = gui,
		_trove = trove,
		_dash = dash,
		_dashFill = dashFill,
		_banner = banner,
		_alert = alert,
		_hint = hint,
		_level = level,
		_tray = tray,
		_results = nil,
		_bannerToken = 0,
		_alertToken = 0,
	}, RunOverlay)
	return (self :: any) :: RunOverlay
end

function RunOverlay.setFootDash(self: RunOverlay, remaining: number?)
	self._dash.Visible = remaining ~= nil
	if remaining then
		self._dashFill.Size = UDim2.fromScale(math.clamp(remaining, 0, 1), 1)
	end
end

local function flash(l: TextLabel, hold: number, token: () -> boolean)
	l.TextTransparency = 0
	l.TextStrokeTransparency = 0
	local scale = l:FindFirstChildOfClass("UIScale") or make("UIScale", {}, l)
	scale.Scale = 1.25
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(hold, function()
		if token() and l.Parent then
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function RunOverlay.banner(self: RunOverlay, text: string, colour: Color3?)
	self._bannerToken += 1
	local token = self._bannerToken
	self._banner.Text = text
	self._banner.TextColor3 = colour or CREAM
	flash(self._banner, 1.1, function()
		return self._bannerToken == token
	end)
end

function RunOverlay.alert(self: RunOverlay, text: string, colour: Color3)
	self._alertToken += 1
	local token = self._alertToken
	self._alert.Text = text
	self._alert.TextColor3 = colour
	flash(self._alert, 2.5, function()
		return self._alertToken == token
	end)
end

function RunOverlay.setHint(self: RunOverlay, visible: boolean)
	self._hint.Visible = visible
end

function RunOverlay.setLevel(self: RunOverlay, level: number, revives: number)
	self._level.Text = string.format("Rider Level %d\nFree revives: %d", level, revives)
end

function RunOverlay.addToTray(self: RunOverlay, title: string, colour: Color3, isNew: boolean)
	local card = make("Frame", {
		Size = UDim2.fromOffset(240, 40),
		BackgroundColor3 = CREAM,
		LayoutOrder = #self._tray:GetChildren(),
	}, self._tray)
	corner(card, 10)
	make("UIStroke", { Color = colour, Thickness = 3 }, card)
	label(card, (if isNew then "NEW  " else "JOYRIDE  ") .. title, 16, {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local scale = make("UIScale", { Scale = 0.2 }, card)
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local cards = {}
	for _, c in self._tray:GetChildren() do
		if c:IsA("Frame") then
			table.insert(cards, c)
		end
	end
	if #cards > 6 then
		cards[1]:Destroy()
	end
end

function RunOverlay.showResults(
	self: RunOverlay,
	results: Results,
	revivesLeft: number,
	onRevive: () -> (),
	onRetry: () -> ()
)
	self:hideResults()
	local card = make("Frame", {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 360),
		BackgroundColor3 = CREAM,
	}, self.gui)
	corner(card, 18)
	make("UIStroke", { Color = NAVY, Thickness = 3 }, card)
	local caught = #results.claimed + results.joyrides
	label(card, string.format("You caught %d car%s!", caught, if caught == 1 then "" else "s"), 36, {
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 10),
	})
	local claimed = if #results.claimed > 0 then table.concat(results.claimed, ", ") else "none yet"
	local lines = {
		string.format("Distance: %d m", math.floor(results.metres)),
		string.format("Hops: %d   ·   Nice saves: %d", results.hops, results.saves),
		"New cars: " .. claimed,
		string.format("Joyride Bonuses: %d", results.joyrides),
		"Ended by: " .. results.cause,
	}
	label(card, table.concat(lines, "\n"), 18, {
		Size = UDim2.new(1, -32, 0, 170),
		Position = UDim2.fromOffset(16, 64),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
	})
	if revivesLeft > 0 then
		button(card, string.format("Revive (%d)", revivesLeft), ORANGE, UDim2.new(0.28, 0, 1, -18), onRevive)
		button(card, "Retry", GREEN, UDim2.new(0.72, 0, 1, -18), onRetry)
	else
		button(card, "Retry", GREEN, UDim2.new(0.5, 0, 1, -18), onRetry)
	end
	self._results = card
end

function RunOverlay.hideResults(self: RunOverlay)
	if self._results then
		self._results:Destroy()
		self._results = nil
	end
end

function RunOverlay.destroy(self: RunOverlay)
	self._trove:Destroy()
end

return RunOverlay
