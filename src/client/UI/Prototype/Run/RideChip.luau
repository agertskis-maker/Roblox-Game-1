--!strict
-- Current ride chip + options button for the run view (Lane 3 preview, worker H3).
-- Top right: a small navy options (gear) button, and beneath it a compact chip naming the car
-- being ridden: a mini rarity bar (colour plus 1..5 pips, so rarity reads without colour), the
-- car name and a family icon. On narrow screens the chip moves under
-- Cash on the left (RunLayout.chipRect). Display only: it shows store.run.ride as supplied.
--
-- The options button only calls the callback it is given. It never says "pause" and implies no
-- pause: a multiplayer run keeps going while options are open.
--
--   local chip = RideChip.new(ctx)
--   chip:setOptionsCallback(fn)     -- preview: called on activation (debounced by Gloss.button)
--   chip:layout(), chip:setVisible(on), chip:destroy(), chip:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

local NAME_SIZE = Tokens.TextSize.Label -- 18
local BAR_W = 12
local ICON = 26
local PAD = 8

local RideChip = {}
RideChip.__index = RideChip

function RideChip.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, RideChip)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._onOptions = nil :: (() -> ())?
	self._presses = 0
	self._car = nil :: Store.CarRef?
	self._rect = nil :: RunLayout.Rect?

	local root = self._trove:Add(RunLayout.canvas(ctx, "RideChip"))
	self.root = root

	-- HUD rebuild: the same red labelled Settings rectangle as the Home menu (Adam, §1)
	local gear = Arcade.button(root, {
		name = "Options",
		label = "Settings",
		fill = "Settings",
		size = "Small",
		anchor = Vector2.new(1, 0),
		sound = "Open",
		onActivate = function()
			self._presses += 1
			local fn = self._onOptions
			if fn then
				fn()
			end
		end,
	})
	self._trove:Add(gear.trove)
	self._gear = gear

	local chip = make("Frame", {
		Name = "Chip",
		BackgroundColor3 = Color3.fromRGB(30, 44, 86),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(RunLayout.ChipSize.X, RunLayout.ChipSize.Y),
		ZIndex = 3,
		Parent = root,
	})
	Arcade.corner(chip, 6)
	-- Round 2: a bold blue surface (was a navy card)
	Arcade.surface(chip, "Garage")
	chip.Active = false
	self._chip = chip
	local bar = make("Frame", {
		Name = "RarityBar",
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(0, BAR_W, 1, -10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = chip,
	})
	Gloss.corner(bar, 5)
	self._barGrad = Gloss.gradient(bar, C.White, C.White)
	local pips = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = bar,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pips,
	})
	self._pips = {} :: { Frame }
	for i = 1, 5 do
		local pip = make("Frame", {
			Name = "Pip" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(5, 5),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = pips,
		})
		Gloss.corner(pip, 3)
		Gloss.stroke(pip, 1, C.Ink)
		table.insert(self._pips, pip)
	end
	local iconHolder = make("Frame", {
		Name = "FamilyIcon",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -PAD, 0.5, 0),
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = chip,
	})
	Icons.draw(iconHolder, "Car", C.White)
	-- "RIDING" names what the chip is (reviewer, 2026-10-23: an unlabelled pill under Settings)
	local tag = make("TextLabel", {
		Name = "RidingTag",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5 + BAR_W + PAD, 2),
		Size = UDim2.new(1, -(5 + BAR_W + PAD) - (ICON + 2 * PAD), 0, Tokens.TextSize.Minimum),
		FontFace = Tokens.font(),
		Text = "RIDING",
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = C.PanelShade,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = chip,
	})
	Arcade.outline(tag, "Minor")
	self._name = make("TextLabel", {
		Name = "CarName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5 + BAR_W + PAD, Tokens.TextSize.Minimum),
		Size = UDim2.new(1, -(5 + BAR_W + PAD) - (ICON + 2 * PAD), 1, -Tokens.TextSize.Minimum - 2),
		FontFace = Tokens.font(),
		Text = "",
		TextSize = NAME_SIZE,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Parent = chip,
	})
	Arcade.outline(self._name, "Minor")

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	RunBus.register(ctx, "ride", self)
	self:layout()
	self:_apply()
	return self
end

export type RideChip = typeof(RideChip.new((nil :: any) :: RunLayout.Ctx))

-- (registered on RunBus as "ride" in new(); see the end of the constructor)

function RideChip._apply(self: RideChip)
	local run = self._ctx.store:get().run
	local car = if run then run.ride else nil
	self._car = car
	-- phone landscape: the chip steps aside while a capture is in progress (the Keys ring uses its
	-- space; the CAPTURING plate and the ring name the car)
	local k = run and run.keys
	local capturing = k ~= nil and (k.status == "Holding" or k.status == "Pending")
	local phoneL = self._ctx.screen:profile().kind == "Phone"
	-- Round 2: it also steps aside while the compact SECURED stack takes its place (phones only)
	local secured = RunBus.flags(self._ctx).secured
	self._chip.Visible = car ~= nil and not (phoneL and (capturing or secured))
	if not car then
		return
	end
	local r = PreviewTokens.Rarity[car.rarity] or PreviewTokens.Rarity.Common
	self._barGrad.Color = ColorSequence.new(r.light, r.deep)
	for i, pip in self._pips do
		pip.Visible = i <= r.pips
	end
	self._name.Text = car.name
	self:layout()
end

function RideChip.layout(self: RideChip)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local gearRect = RunLayout.gearRect(ctx)
	self._gear.root.Position = UDim2.fromOffset(gearRect.pos.X + gearRect.size.X, gearRect.pos.Y)
	local rect = RunLayout.chipRect(ctx)
	-- shrink-wrap the chip to the name, up to the slot width; long names truncate with "..."
	local name = self._name.Text
	local natural = TextService:GetTextSize(name, NAME_SIZE, Enum.Font.FredokaOne, Vector2.new(4096, 64)).X
	local w = math.clamp(math.ceil(natural) + 5 + BAR_W + PAD + ICON + 2 * PAD, 120, rect.size.X)
	local x = if RunLayout.top(ctx.screen).row == 2 then rect.pos.X else rect.pos.X + rect.size.X - w
	self._chip.Position = UDim2.fromOffset(x, rect.pos.Y)
	self._chip.Size = UDim2.fromOffset(w, rect.size.Y)
	self._rect = RunLayout.rect(x, rect.pos.Y, w, rect.size.Y, "RideChip")
end

function RideChip.setOptionsCallback(self: RideChip, fn: (() -> ())?)
	self._onOptions = fn
end

function RideChip.setVisible(self: RideChip, on: boolean)
	self._visible = on
	self.root.Visible = on
end

function RideChip.getDebugState(self: RideChip): { [string]: any }
	local car = self._car
	local shown = 0
	for _, pip in self._pips do
		if pip.Visible then
			shown += 1
		end
	end
	return {
		visible = self._visible,
		car = car and car.name,
		rarity = car and car.rarity,
		pips = shown,
		nameText = self._name.Text,
		nameFits = self._name.TextFits,
		chipBox = self._rect and RunLayout.describe(self._rect),
		gearBox = RunLayout.describe(RunLayout.gearRect(self._ctx)),
		gearSize = self._gear.body.Size.X.Offset,
		optionsPresses = self._presses,
		saysPause = false,
	}
end

-- Re-applies the visibility rule (the SECURED stack asks for it when it comes and goes).
function RideChip.refresh(self: RideChip)
	self:_apply()
end

function RideChip.destroy(self: RideChip)
	RunBus.unregister(self._ctx, "ride", self)
	self._trove:Destroy()
end

return RideChip
