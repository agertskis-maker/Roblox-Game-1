--!strict
-- TutorialSkipCard: the "Skip tutorial?" confirm (BRIEF M11-07): a small centred card with the question and two BIG buttons,
-- Yes (green) and No (blue), both at the 56 px primary touch size. It lives in the guide's overlay ScreenGui (above every
-- panel), so its size is design px times the HUD scale times the device-frame fit. It never dims or blocks the world: the
-- player can keep walking while it is open, and it asks nothing else. Escape and the gamepad's B mean No. It opens and
-- closes at once (no motion to calm). Every connection and the key binding belong to its Troves.
--
-- API: SkipCard.new(ctx, { topLayer: Frame, onYes: () -> (), onNo: (() -> ())?, title: string, yes: string, no: string })
--   :open()  :close()  :isOpen() -> boolean  :layout()  :destroy()  :getDebugState()
--   :getButtons() -> { yes: GuiObject, no: GuiObject }

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Prototype.Arcade)
local Motion = require(script.Parent.Parent.Prototype.Motion)
local PreviewTokens = require(script.Parent.Parent.Prototype.PreviewTokens)
local Sounds = require(script.Parent.Parent.Prototype.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local B = A.Button
local make = Arcade.make

local CARD_W = 300
local CARD_H = 156
local BUTTON_W = 124

local SkipCard = {}
SkipCard.__index = SkipCard

export type Options = {
	topLayer: Frame,
	onYes: () -> (),
	onNo: (() -> ())?,
	title: string,
	yes: string,
	no: string,
}

export type SkipCard = {
	open: (self: SkipCard) -> (),
	close: (self: SkipCard) -> (),
	isOpen: (self: SkipCard) -> boolean,
	layout: (self: SkipCard) -> (),
	destroy: (self: SkipCard) -> (),
	getButtons: (self: SkipCard) -> { yes: GuiObject, no: GuiObject },
	getDebugState: (self: SkipCard) -> { [string]: any },
}

function SkipCard.new(ctx: any, options: Options): SkipCard
	local self = setmetatable({}, SkipCard) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._open = false
	self._destroyed = false
	self._opens = 0
	self._action = "Lane3TutorialSkipBack_" .. HttpService:GenerateGUID(false)

	local root = trove:Add(make("Frame", {
		Name = "TutorialSkipCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 120,
		Parent = options.topLayer,
	}))
	self._root = root
	self._scale =
		make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale() * ctx.screen:fitScale(), Parent = root })
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, B.DepthOffset + 2),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		ZIndex = 120,
		Parent = root,
	})
	Arcade.corner(lip, 16)
	local card = make("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 28, 42),
		ZIndex = 121,
		SelectionGroup = true,
		Parent = root,
	})
	Arcade.corner(card, 16)
	Arcade.outline(card, "Button")
	local title = Arcade.text(card, {
		text = options.title,
		role = "Display",
		name = "Title",
		face = "Keys",
		size = Tokens.TextSize.Display - 6,
		z = 122,
	})
	title.Position = UDim2.fromOffset(0, 14)
	title.Size = UDim2.new(1, 0, 0, 44)
	local yes = Arcade.button(card, {
		name = "Yes",
		label = options.yes,
		fill = "Green",
		size = "Custom",
		width = BUTTON_W,
		height = Tokens.Touch.Primary,
		icon = "Check",
		sound = "Tap",
		position = UDim2.new(0.5, -BUTTON_W - 8, 1, -(Tokens.Touch.Primary + B.DepthOffset + 18)),
		onActivate = function()
			self:close()
			options.onYes()
		end,
	})
	trove:Add(yes.trove)
	yes.root.ZIndex = 122
	local no = Arcade.button(card, {
		name = "No",
		label = options.no,
		fill = "Garage",
		size = "Custom",
		width = BUTTON_W,
		height = Tokens.Touch.Primary,
		icon = "Close",
		sound = "Tap",
		position = UDim2.new(0.5, 8, 1, -(Tokens.Touch.Primary + B.DepthOffset + 18)),
		onActivate = function()
			self:close()
			if options.onNo then
				options.onNo()
			end
		end,
	})
	trove:Add(no.trove)
	no.root.ZIndex = 122
	self._yes = yes.body
	self._no = no.body
	self._onNo = options.onNo
	trove:Add(function()
		ContextActionService:UnbindAction(self._action)
		Motion.cancelAll(root)
	end)
	return self :: SkipCard
end

function SkipCard.open(self: any)
	if self._destroyed or self._open then
		return
	end
	self._open = true
	self._opens += 1
	self._scale.Scale = self._ctx.screen:uiScale() * self._ctx.screen:fitScale()
	self._root.Visible = true
	Sounds.play("Open")
	ContextActionService:BindActionAtPriority(
		self._action,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin and self._open then
				self:close()
				local cb = self._onNo
				if cb then
					cb()
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 20,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
end

function SkipCard.close(self: any)
	if self._destroyed or not self._open then
		return
	end
	self._open = false
	ContextActionService:UnbindAction(self._action)
	self._root.Visible = false
	Sounds.play("Close")
end

function SkipCard.isOpen(self: any): boolean
	return self._open
end

function SkipCard.layout(self: any)
	self._scale.Scale = self._ctx.screen:uiScale() * self._ctx.screen:fitScale()
end

function SkipCard.getButtons(self: any): { yes: GuiObject, no: GuiObject }
	return { yes = self._yes, no = self._no }
end

function SkipCard.getDebugState(self: any): { [string]: any }
	local ctx = self._ctx
	local yesPos, yesSize = ctx.screen:rectOf(self._yes)
	local noPos, noSize = ctx.screen:rectOf(self._no)
	return {
		open = self._open,
		opens = self._opens,
		yesSize = yesSize,
		noSize = noSize,
		yesPos = yesPos,
		noPos = noPos,
		designButtonHeight = Tokens.Touch.Primary,
	}
end

function SkipCard.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return SkipCard
