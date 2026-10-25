--!strict
-- Temporary run read-outs for the Lane 1 prototype: the Keys meter, the Foot Dash timer, short
-- banners and a plain Results card with Retry. Lane 3 (Adam) designs and draws the real versions
-- (Figma-first); these exist only so the driving can be playtested and are labelled as such.
-- Heat, Cash and Distance go to Adam's RunHud instead.

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
	setKeys: (self: RunOverlay, progress: number?, label: string?) -> (),
	setFootDash: (self: RunOverlay, remaining: number?) -> (),
	banner: (self: RunOverlay, text: string, colour: Color3?) -> (),
	setHint: (self: RunOverlay, visible: boolean) -> (),
	showResults: (self: RunOverlay, results: Results, onRetry: () -> ()) -> (),
	hideResults: (self: RunOverlay) -> (),
	destroy: (self: RunOverlay) -> (),
	_trove: any,
	_keys: Frame,
	_keysFill: Frame,
	_keysLabel: TextLabel,
	_dash: Frame,
	_dashFill: Frame,
	_banner: TextLabel,
	_hint: TextLabel,
	_results: Frame?,
	_bannerToken: number,
}

local RunOverlay = {}
RunOverlay.__index = RunOverlay

local CREAM = Color3.fromRGB(255, 248, 232)
local NAVY = Color3.fromRGB(28, 40, 72)
local ORANGE = Color3.fromRGB(255, 140, 40)
local GREEN = Color3.fromRGB(70, 190, 100)
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

local function meter(parent: Instance, y: number, colour: Color3): (Frame, Frame, TextLabel)
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(300, 54),
		BackgroundColor3 = CREAM,
		Visible = false,
	}, parent)
	corner(frame, 14)
	make("UIStroke", { Color = NAVY, Thickness = 2 }, frame)
	local text = label(frame, "", 18, { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 4) })
	local track = make("Frame", {
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 0, 12),
		BackgroundColor3 = Color3.fromRGB(220, 214, 200),
	}, frame)
	corner(track, 6)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colour }, track)
	corner(fill, 6)
	return frame, fill, text
end

function RunOverlay.new(parent: Instance): RunOverlay
	local trove = Trove.new()
	local gui: ScreenGui = trove:Add(make("ScreenGui", {
		Name = "Lane1RunOverlay",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}))

	local keys, keysFill, keysLabel = meter(gui, 96, ORANGE)
	local dash, dashFill, dashLabel = meter(gui, 160, RED)
	dashLabel.Text = "On foot! Hop onto a car!"

	local banner = label(gui, "", 36, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(600, 60),
		TextColor3 = CREAM,
		TextStrokeColor3 = NAVY,
		TextStrokeTransparency = 0,
		TextTransparency = 1,
	})

	local hint = label(gui, "Steer: A / D or drag   ·   Hop: Space or tap", 18, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(520, 30),
		TextColor3 = CREAM,
		TextStrokeColor3 = NAVY,
		TextStrokeTransparency = 0.2,
	})

	label(gui, "Lane 1 run prototype · greybox stand-ins · nothing is saved", 16, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -8),
		Size = UDim2.fromOffset(460, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = CREAM,
		TextStrokeColor3 = NAVY,
		TextStrokeTransparency = 0.3,
	})

	gui.Parent = parent
	local self = setmetatable({
		gui = gui,
		_trove = trove,
		_keys = keys,
		_keysFill = keysFill,
		_keysLabel = keysLabel,
		_dash = dash,
		_dashFill = dashFill,
		_banner = banner,
		_hint = hint,
		_results = nil,
		_bannerToken = 0,
	}, RunOverlay)
	return (self :: any) :: RunOverlay
end

function RunOverlay.setKeys(self: RunOverlay, progress: number?, text: string?)
	self._keys.Visible = progress ~= nil
	if progress then
		self._keysFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		self._keysLabel.Text = text or "Keys"
	end
end

function RunOverlay.setFootDash(self: RunOverlay, remaining: number?)
	self._dash.Visible = remaining ~= nil
	if remaining then
		self._dashFill.Size = UDim2.fromScale(math.clamp(remaining, 0, 1), 1)
	end
end

function RunOverlay.banner(self: RunOverlay, text: string, colour: Color3?)
	self._bannerToken += 1
	local token = self._bannerToken
	local b = self._banner
	b.Text = text
	b.TextColor3 = colour or CREAM
	b.TextTransparency = 0
	b.TextStrokeTransparency = 0
	task.delay(1.1, function()
		if self._bannerToken == token and b.Parent then
			TweenService:Create(b, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function RunOverlay.setHint(self: RunOverlay, visible: boolean)
	self._hint.Visible = visible
end

function RunOverlay.showResults(self: RunOverlay, results: Results, onRetry: () -> ())
	self:hideResults()
	local card = make("Frame", {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 330),
		BackgroundColor3 = CREAM,
	}, self.gui)
	corner(card, 18)
	make("UIStroke", { Color = NAVY, Thickness = 3 }, card)
	label(card, "Run over", 36, { Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 10) })
	local claimed = if #results.claimed > 0 then table.concat(results.claimed, ", ") else "none"
	local lines = {
		string.format("Distance: %d m", math.floor(results.metres)),
		string.format("Hops: %d   ·   Nice saves: %d", results.hops, results.saves),
		"Cars claimed: " .. claimed,
		string.format("Joyride Bonuses: %d", results.joyrides),
		"Ended by: " .. results.cause,
	}
	label(card, table.concat(lines, "\n"), 18, {
		Size = UDim2.new(1, -32, 0, 150),
		Position = UDim2.fromOffset(16, 64),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
	})
	local retry = make("TextButton", {
		Name = "Retry",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(220, 56),
		BackgroundColor3 = GREEN,
		FontFace = Tokens.font(),
		Text = "Retry",
		TextSize = 24,
		TextColor3 = CREAM,
		AutoButtonColor = true,
	}, card)
	corner(retry, 14)
	retry.Activated:Connect(onRetry)
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
