--!strict
-- Custom ProximityPrompt presentation (Lane 3 preview, worker H3) for the lead's dummy objects
-- (Garage door, kiosk, portal). Presentation only: a triggered prompt calls the preview callback
-- it was attached with and nothing else (no teleport, purchase, unlock or reward).
--
--   * Style = Custom on every attached prompt, so the engine draws nothing and there is never a
--     default and a custom display at once (getDebugState counts any attached prompt that is
--     not Custom as a duplicate);
--   * a cream / navy card: ObjectText (small) over ActionText, and an input-specific cue drawn
--     from Frames: keyboard key cap with the KeyboardKeyCode letter ("E"), a gamepad face
--     button disc with the GamepadKeyCode letter ("X" for ButtonX; neutral navy, not a console
--     brand's colours), touch "TAP" / "HOLD" button (calls InputHoldBegin / InputHoldEnd);
--   * hold progress for HoldDuration prompts: a ring around the cue driven by
--     PromptButtonHoldBegan / PromptButtonHoldEnded, filling linearly over HoldDuration (an
--     information meter, so it still fills in reduced motion);
--   * built on PromptShown (with its inputType) and destroyed on PromptHidden;
--   * forceInputType("Keyboard" | "Gamepad" | "Touch" | nil) rebuilds open cards for captures;
--     forceShow(prompt, on) shows a card without walking up to the object (captures only).
-- Cards are BillboardGuis in the local PlayerGui (where touch input reaches them), adorned to
-- the prompt's parent, scaled by uiScale x the device-fit scale like the rest of the preview.
--
--   local prompts = Prompts.new(ctx)
--   prompts:attach(prompt, function(prompt) ... end)   -- preview callback only
--   prompts:detach(prompt)
--   prompts:forceInputType(kind?), prompts:forceShow(prompt, on)
--   prompts:layout(), prompts:setVisible(on), prompts:destroy(), prompts:getDebugState()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arc = require(script.Parent.Parent.Run.Arc)
local Gloss = require(script.Parent.Parent.Gloss)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

export type InputKind = "Keyboard" | "Gamepad" | "Touch"

local CUE = 52
local RING = 64
local PAD = 10
local HEIGHT = 84
local OBJECT_SIZE = Tokens.TextSize.Minimum -- 16
local ACTION_SIZE = Tokens.TextSize.Value -- 24

local Prompts = {}
Prompts.__index = Prompts

type Card = {
	trove: Trove.Trove,
	board: BillboardGui,
	body: Frame,
	scale: UIScale,
	arc: Arc.Arc?,
	value: NumberValue,
	input: InputKind,
}

type Entry = {
	prompt: ProximityPrompt,
	onTriggered: ((ProximityPrompt) -> ())?,
	trove: Trove.Trove,
	originalStyle: Enum.ProximityPromptStyle,
	shownInput: InputKind?,
	forced: boolean,
	card: Card?,
	triggers: number,
	holding: boolean,
}

local function kindOf(inputType: Enum.ProximityPromptInputType?): InputKind
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return "Gamepad"
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "Touch"
	end
	return "Keyboard"
end

local function gamepadLetter(code: Enum.KeyCode): string
	local map: { [string]: string } = { ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y" }
	return map[code.Name] or string.gsub(code.Name, "^Button", "")
end

local function keyLetter(code: Enum.KeyCode): string
	local name = code.Name
	if #name > 3 then
		return string.sub(name, 1, 3)
	end
	return name
end

local function adorneeOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if not parent then
		return nil
	end
	if parent:IsA("BasePart") or parent:IsA("Attachment") then
		return parent
	end
	if parent:IsA("Model") then
		return (parent :: Model).PrimaryPart
	end
	return nil
end

function Prompts.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, Prompts)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._forcedInput = nil :: InputKind?
	self._entries = {} :: { [ProximityPrompt]: Entry }
	self._built = 0
	self._destroyedCards = 0
	self._trove:Add(function()
		for prompt in self._entries do
			self:detach(prompt)
		end
	end)
	return self
end

export type Prompts = typeof(Prompts.new((nil :: any) :: RunLayout.Ctx))

function Prompts._scale(self: Prompts): number
	return self._ctx.screen:uiScale() * self._ctx.screen:fitScale()
end

function Prompts._cue(self: Prompts, entry: Entry, parent: Frame, kind: InputKind): Arc.Arc?
	local prompt = entry.prompt
	local hold = prompt.HoldDuration > 0
	local arc: Arc.Arc? = nil
	if hold then
		-- hold ring behind the cue
		local track = make("Frame", {
			Name = "HoldTrack",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(RING, RING),
			BackgroundColor3 = C.PanelShade,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = parent,
		})
		Gloss.corner(track, RING / 2)
		arc = Arc.new(parent, RING, C.PrimaryDeep, 0, 4)
	end
	if kind == "Keyboard" then
		local cap = make("Frame", {
			Name = "KeyCap",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CUE - 6, CUE - 6),
			BackgroundColor3 = C.PanelShade,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = parent,
		})
		Gloss.corner(cap, 10)
		Gloss.stroke(cap, 3, C.Ink)
		local face = make("Frame", {
			Name = "Face",
			Size = UDim2.new(1, 0, 1, -5),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = cap,
		})
		Gloss.corner(face, 10)
		make("TextLabel", {
			Name = "Key",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Tokens.font(),
			Text = keyLetter(prompt.KeyboardKeyCode),
			TextSize = ACTION_SIZE,
			TextColor3 = C.Ink,
			ZIndex = 8,
			Parent = face,
		})
	elseif kind == "Gamepad" then
		local disc = make("Frame", {
			Name = "PadButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CUE - 6, CUE - 6),
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = parent,
		})
		Gloss.corner(disc, (CUE - 6) / 2)
		Gloss.stroke(disc, 3, C.White)
		make("TextLabel", {
			Name = "Letter",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Tokens.font(),
			Text = gamepadLetter(prompt.GamepadKeyCode),
			TextSize = ACTION_SIZE,
			TextColor3 = C.White,
			ZIndex = 7,
			Parent = disc,
		})
	else
		local tap = make("TextButton", {
			Name = "TouchButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CUE, CUE),
			BackgroundColor3 = C.White,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 6,
			Parent = parent,
		})
		Gloss.corner(tap, CUE / 2)
		Gloss.stroke(tap, 3, C.Ink)
		Gloss.gradient(tap, C.PrimaryLight, C.PrimaryDeep)
		local label = make("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Tokens.font(),
			Text = if hold then "HOLD" else "TAP",
			TextSize = Tokens.TextSize.Minimum,
			TextColor3 = C.White,
			ZIndex = 7,
			Parent = tap,
		})
		Gloss.stroke(label, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)
		local card = entry.card
		local t = if card then card.trove else self._trove
		t:Connect(tap.InputBegan, function(input: InputObject)
			local kindIn = input.UserInputType
			if kindIn == Enum.UserInputType.Touch or kindIn == Enum.UserInputType.MouseButton1 then
				Motion.press(tap, true)
				prompt:InputHoldBegin()
			end
		end)
		t:Connect(tap.InputEnded, function(input: InputObject)
			local kindIn = input.UserInputType
			if kindIn == Enum.UserInputType.Touch or kindIn == Enum.UserInputType.MouseButton1 then
				Motion.press(tap, false)
				prompt:InputHoldEnd()
			end
		end)
	end
	return arc
end

local function holdBegan(entry: Entry)
	entry.holding = true
	local card = entry.card
	if not card then
		return
	end
	local d = entry.prompt.HoldDuration
	if d <= 0 then
		return
	end
	card.value.Value = 0
	Motion.tween(card.value, "hold", TweenInfo.new(d, Enum.EasingStyle.Linear), { Value = 1 })
end

local function holdEnded(entry: Entry)
	entry.holding = false
	local card = entry.card
	if not card then
		return
	end
	Motion.cancelAll(card.value)
	card.value.Value = 0
	local arc = card.arc
	if arc then
		arc:set(0)
	end
end

function Prompts._buildCard(self: Prompts, entry: Entry)
	self:_destroyCard(entry)
	local prompt = entry.prompt
	local adornee = adorneeOf(prompt)
	if not adornee or not self._visible then
		return
	end
	local kind: InputKind = self._forcedInput or entry.shownInput or "Keyboard"
	local trove = Trove.new()
	local s = self:_scale()
	local textW = math.max(
		TextService:GetTextSize(prompt.ActionText, ACTION_SIZE, Enum.Font.FredokaOne, Vector2.new(4096, 64)).X,
		TextService:GetTextSize(prompt.ObjectText, OBJECT_SIZE, Enum.Font.FredokaOne, Vector2.new(4096, 64)).X
	)
	local width = math.clamp(math.ceil(textW) + RING + 3 * PAD + 8, 200, 380)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local board = trove:Add(make("BillboardGui", {
		Name = "Lane3Prompt_" .. prompt.Name,
		Adornee = adornee,
		AlwaysOnTop = true,
		Active = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		MaxDistance = math.max(prompt.MaxActivationDistance * 2, 30),
		StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0),
		Size = UDim2.fromOffset((width + 8) * s, (HEIGHT + 8) * s),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui or self._ctx.world,
	}))
	local holder = make("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width + 8, HEIGHT + 8),
		Parent = board,
	})
	local scale = make("UIScale", { Name = "HudScale", Scale = s, Parent = holder })
	local body = Gloss.panel(holder, {
		name = "Card",
		size = UDim2.fromOffset(width, HEIGHT),
		position = UDim2.fromOffset(4, 2),
		colour = C.Panel,
		radius = 18,
		z = 2,
	})
	local cueHolder = make("Frame", {
		Name = "Cue",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, PAD, 0.5, 0),
		Size = UDim2.fromOffset(RING, RING),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = body,
	})
	local value = trove:Add(Instance.new("NumberValue"))
	local card: Card = {
		trove = trove,
		board = board,
		body = body,
		scale = scale,
		arc = nil,
		value = value,
		input = kind,
	}
	entry.card = card
	card.arc = self:_cue(entry, cueHolder, kind)
	trove:Connect(value.Changed, function(v: number)
		local arc = card.arc
		if arc then
			arc:set(v)
		end
	end)
	local textX = PAD + RING + PAD
	local object = make("TextLabel", {
		Name = "ObjectText",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(textX, 14),
		Size = UDim2.new(1, -(textX + PAD), 0, OBJECT_SIZE + 4),
		FontFace = Tokens.font(),
		Text = prompt.ObjectText,
		TextSize = OBJECT_SIZE,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
		Parent = body,
	})
	object.Visible = prompt.ObjectText ~= ""
	make("TextLabel", {
		Name = "ActionText",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(textX, if prompt.ObjectText ~= "" then 36 else 26),
		Size = UDim2.new(1, -(textX + PAD), 0, ACTION_SIZE + 6),
		FontFace = Tokens.font(),
		Text = prompt.ActionText,
		TextSize = ACTION_SIZE,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
		Parent = body,
	})
	trove:Add(function()
		Motion.cancelAll(value)
		Motion.cancelAll(body)
	end)
	self._built += 1
	if entry.holding then
		holdBegan(entry)
	end
	if not Motion.reduced() then
		Motion.pop(body, 1.06)
	end
end

function Prompts._destroyCard(self: Prompts, entry: Entry)
	local card = entry.card
	if card then
		entry.card = nil
		card.trove:Destroy()
		self._destroyedCards += 1
	end
end

-- Attach a prompt (a dummy object's ProximityPrompt). onTriggered is a PREVIEW callback only.
function Prompts.attach(self: Prompts, prompt: ProximityPrompt, onTriggered: ((ProximityPrompt) -> ())?)
	if self._entries[prompt] then
		self:detach(prompt)
	end
	local trove = Trove.new()
	local entry: Entry = {
		prompt = prompt,
		onTriggered = onTriggered,
		trove = trove,
		originalStyle = prompt.Style,
		shownInput = nil,
		forced = false,
		card = nil,
		triggers = 0,
		holding = false,
	}
	self._entries[prompt] = entry
	prompt.Style = Enum.ProximityPromptStyle.Custom
	trove:Connect(prompt.PromptShown, function(inputType: Enum.ProximityPromptInputType)
		entry.shownInput = kindOf(inputType)
		self:_buildCard(entry)
	end)
	trove:Connect(prompt.PromptHidden, function()
		entry.holding = false
		if not entry.forced then
			self:_destroyCard(entry)
		end
	end)
	trove:Connect(prompt.PromptButtonHoldBegan, function()
		holdBegan(entry)
	end)
	trove:Connect(prompt.PromptButtonHoldEnded, function()
		holdEnded(entry)
	end)
	trove:Connect(prompt.Triggered, function()
		entry.triggers += 1
		Sounds.play("Tap")
		local card = entry.card
		if card and not Motion.reduced() then
			Motion.pop(card.body, 1.08)
		end
		local fn = entry.onTriggered
		if fn then
			fn(prompt)
		end
	end)
	trove:Add(function()
		self:_destroyCard(entry)
	end)
end

function Prompts.detach(self: Prompts, prompt: ProximityPrompt)
	local entry = self._entries[prompt]
	if not entry then
		return
	end
	self._entries[prompt] = nil
	entry.trove:Destroy()
	if prompt.Parent then
		prompt.Style = entry.originalStyle
	end
end

-- Screenshot helper: force the cue art for every card (nil returns to the real input type).
function Prompts.forceInputType(self: Prompts, kind: InputKind?)
	if kind ~= nil and kind ~= "Keyboard" and kind ~= "Gamepad" and kind ~= "Touch" then
		return
	end
	self._forcedInput = kind
	for _, entry in self._entries do
		if entry.card then
			self:_buildCard(entry)
		end
	end
end

-- Screenshot helper: show (or hide) a prompt's card without walking up to it.
function Prompts.forceShow(self: Prompts, prompt: ProximityPrompt, on: boolean)
	local entry = self._entries[prompt]
	if not entry then
		return
	end
	entry.forced = on
	if on then
		self:_buildCard(entry)
	else
		self:_destroyCard(entry)
	end
end

function Prompts.layout(self: Prompts)
	-- rebuild open cards at the current profile's scale
	for _, entry in self._entries do
		if entry.card then
			self:_buildCard(entry)
		end
	end
end

function Prompts.setVisible(self: Prompts, on: boolean)
	self._visible = on
	for _, entry in self._entries do
		if not on then
			self:_destroyCard(entry)
		elseif entry.forced then
			self:_buildCard(entry)
		end
	end
end

function Prompts.getDebugState(self: Prompts): { [string]: any }
	local prompts = {}
	local duplicates = 0
	for prompt, entry in self._entries do
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			duplicates += 1
		end
		local card = entry.card
		table.insert(prompts, {
			name = prompt:GetFullName(),
			action = prompt.ActionText,
			object = prompt.ObjectText,
			hold = prompt.HoldDuration,
			style = prompt.Style.Name,
			cardShown = card ~= nil,
			cue = card and card.input,
			holdProgress = card and card.value.Value,
			triggers = entry.triggers,
			forced = entry.forced,
		})
	end
	return {
		visible = self._visible,
		forcedInput = self._forcedInput,
		prompts = prompts,
		duplicateDefaultDisplays = duplicates,
		cardsBuilt = self._built,
		cardsDestroyed = self._destroyedCards,
	}
end

function Prompts.destroy(self: Prompts)
	self._trove:Destroy()
end

return Prompts
