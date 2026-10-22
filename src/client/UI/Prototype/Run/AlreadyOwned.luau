--!strict
-- Already-owned note for the run view (Lane 3 preview). On a store event
-- { kind = "AlreadyOwned", car = CarRef?, amount = number? } it shows a small cream/navy ribbon
-- under Distance + coins for about 1.8 s: "JOYRIDE BONUS +$N" when the event carries an amount
-- (the Joyride Bonus is Decided in the GDD; the amount is supplied by the owning lane, synthetic
-- in the playground, never computed here), otherwise "Already in your Garage".
--
-- It shares the upper-screen message slot (priority 2: above milestones, below the capture
-- celebration). If the celebration holds the slot the note is skipped (the newer, more
-- important message wins); a milestone in the slot is replaced.
--
--   local note = AlreadyOwned.new(ctx)
--   note:show(car?, amount?)   -- the same as the event (preview)
--   note:layout(), note:setVisible(on), note:destroy(), note:getDebugState()

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

local TEXT = "Already in your Garage"
local HEIGHT = 40
local SECONDS = 1.8
local OWNER = "AlreadyOwned"
local PRIORITY = 2

local AlreadyOwned = {}
AlreadyOwned.__index = AlreadyOwned

function AlreadyOwned.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, AlreadyOwned)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._showing = false
	self._shows = 0
	self._skipped = 0
	self._token = 0
	self._car = nil :: string?
	self._slot = RunLayout.slot(ctx.screen)

	local root = self._trove:Add(RunLayout.canvas(ctx, "AlreadyOwned"))
	self.root = root
	local note = make("CanvasGroup", {
		Name = "Note",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(300, HEIGHT + 6),
		Parent = root,
	})
	self._note = note
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0, HEIGHT),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = note,
	})
	Gloss.corner(body, HEIGHT / 2)
	Gloss.stroke(body, 2.5, C.Ink)
	local icon = make("Frame", {
		Name = "GarageIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = body,
	})
	Icons.draw(icon, "Garage", C.InkSoft)
	self._label = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -56, 1, 0),
		FontFace = Tokens.font(),
		Text = TEXT,
		TextSize = Tokens.TextSize.Label,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = body,
	})

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "AlreadyOwned" then
			self:show(event.car, event.amount)
		end
	end)
	self._trove:Connect(self._slot.Preempted, function(owner: string)
		if owner == OWNER then
			self:hide()
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Run" then
			self:hide()
		end
	end)
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(note)
		self._slot.release(OWNER)
	end)
	self:layout()
	return self
end

export type AlreadyOwned = typeof(AlreadyOwned.new((nil :: any) :: RunLayout.Ctx))

function AlreadyOwned.layout(self: AlreadyOwned)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local d = RunLayout.design(ctx)
	local natural = TextService:GetTextSize(TEXT, Tokens.TextSize.Label, Enum.Font.FredokaOne, Vector2.new(4096, 64)).X
	local w = math.min(math.ceil(natural) + 56 + 6, d.X - 24)
	self._note.Size = UDim2.fromOffset(w, HEIGHT + 6)
	self._note.Position = UDim2.fromOffset(d.X / 2, RunLayout.messageY(ctx))
end

function AlreadyOwned.show(self: AlreadyOwned, car: Store.CarRef?, amount: number?)
	-- the Joyride Bonus is decided (GDD core loop); its amount comes from the event (synthetic
	-- in the playground, the server's in production) and is never computed here
	local label = self._note:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = if type(amount) == "number" and amount > 0
			then string.format("JOYRIDE BONUS +$%d", math.floor(amount))
			else TEXT
	end
	if not self._slot.claim(OWNER, PRIORITY) then
		self._skipped += 1
		return
	end
	self._token += 1
	local token = self._token
	self._shows += 1
	self._car = car and car.name
	self._showing = true
	self:layout()
	Sounds.play("Toast")
	local note = self._note
	note.Visible = true
	Motion.tween(note, "fade", Motion.info(if Motion.reduced() then 0.12 else 0.18), { GroupTransparency = 0 })
	task.delay(SECONDS, function()
		if token == self._token then
			self:hide()
		end
	end)
end

function AlreadyOwned.hide(self: AlreadyOwned)
	self._token += 1
	if not self._showing then
		return
	end
	self._showing = false
	self._slot.release(OWNER)
	local token = self._token
	local t = Motion.tween(self._note, "fade", Motion.info(0.18), { GroupTransparency = 1 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and token == self._token then
			self._note.Visible = false
		end
	end)
end

function AlreadyOwned.setVisible(self: AlreadyOwned, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:hide()
	end
end

function AlreadyOwned.getDebugState(self: AlreadyOwned): { [string]: any }
	return {
		visible = self._visible,
		showing = self._showing,
		text = self._label.Text,
		textFits = self._label.TextFits,
		car = self._car,
		shows = self._shows,
		skipped = self._skipped,
		showsMoney = false,
		box = string.format(
			"%dx%d at (%d,%d)",
			self._note.Size.X.Offset,
			self._note.Size.Y.Offset,
			self._note.Position.X.Offset - self._note.Size.X.Offset / 2,
			self._note.Position.Y.Offset
		),
	}
end

function AlreadyOwned.destroy(self: AlreadyOwned)
	self._trove:Destroy()
end

return AlreadyOwned
