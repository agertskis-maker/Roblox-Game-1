--!strict
-- R8Kit.Pips (Lane 3 Round 8, U-01/U-02/U-03): the row of level pips under the stats: one little flag per Raceway level (gold up to
-- the level you have, grey after; "r8_card_pip_gold" / "r8_card_pip_grey" art or a code-drawn flag). Any other row of equal cells
-- (WS-6b's parking bays) can reuse it: `cell(i)` gives each pip's frame and `goldKey` / `greyKey` swap the art. The next pip
-- pulses gently (not in Reduce Motion). At the top level every pip is gold. `pop(i)` is the "just upgraded" pop.
--
--   local p = Pips.new(parent: GuiObject, props: Props) -> Pips
--     Props: { count: number, filled: number, size: UDim2? (416 x 34 design px), position: UDim2?, anchor: Vector2?,
--              zIndex: number?, pulseNext: boolean? (default true), goldKey: string?, greyKey: string?,
--              metrics: Metrics? }
--   p.frame: Frame                p.count: number            p.filled: number
--   p:set(filled: number)         gold up to `filled` (clamped 0..count), grey after; restarts the next-pip pulse
--   p:pop(index: number)          the pop of pip `index` (a quick scale up and settle; a colour flash in Reduce Motion)
--   p:cell(index: number) -> Frame   the frame of one pip (WS-6b puts its own art in a bay cell)
--   p:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Calm = require(script.Parent.Calm)
local Palette = require(script.Parent.Palette)

local Pips = {}

export type Props = {
	count: number,
	filled: number,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	pulseNext: boolean?,
	goldKey: string?,
	greyKey: string?,
	metrics: any?,
}

export type Pips = {
	frame: Frame,
	count: number,
	filled: number,
	set: (self: Pips, filled: number) -> (),
	pop: (self: Pips, index: number) -> (),
	cell: (self: Pips, index: number) -> Frame,
	destroy: (self: Pips) -> (),
}

type Cell = {
	holder: Frame,
	scale: UIScale,
	art: ImageLabel,
	flag: Frame, -- the code-drawn fallback flag
	cloth: Frame,
}

local Obj = {}
Obj.__index = Obj

local function paint(self: any, cell: Cell, gold: boolean)
	local key = if gold then self.goldKey else self.greyKey
	if Art.apply(cell.art, key) then
		cell.flag.Visible = false
	else
		cell.flag.Visible = true
		cell.cloth.BackgroundColor3 = if gold then Palette.Gold else Palette.Grey
	end
end

local function stopPulse(self: any)
	if self.pulse then
		self.pulse:Cancel()
		self.pulse:Destroy()
		self.pulse = nil
	end
	if self.pulseCell then
		self.pulseCell.scale.Scale = 1
		self.pulseCell = nil
	end
end

local function startPulse(self: any)
	stopPulse(self)
	if self.props.pulseNext == false or Calm() or self.filled >= self.count then
		return
	end
	local cell = self.cells[self.filled + 1] :: Cell?
	if not cell then
		return
	end
	local tween = TweenService:Create(
		cell.scale,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.18 }
	)
	self.pulse = tween
	self.pulseCell = cell
	tween:Play()
end

function Pips.new(parent: GuiObject, props: Props): Pips
	local trove = Trove.new()
	local count = math.max(props.count, 1)
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = "Pips",
		Size = props.size or UDim2.fromOffset(416, 34),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 1,
	}))
	local cells: { Cell } = {}
	for i = 1, count do
		local holder: Frame = Build.make("Frame", {
			Name = "Pip" .. i,
			Position = UDim2.fromScale((i - 1) / count, 0),
			Size = UDim2.fromScale(1 / count, 1),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		local box: Frame = Build.make("Frame", {
			Name = "Box",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = holder,
		})
		Build.make(
			"UIAspectRatioConstraint",
			{ AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize, Parent = box }
		)
		local scale: UIScale = Build.make("UIScale", { Parent = box })
		local art: ImageLabel = Build.make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = box,
		})
		-- the code-drawn flag: a thin pole and a cloth
		local flag: Frame = Build.make("Frame", {
			Name = "Flag",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = box,
		})
		Build.make("Frame", {
			Name = "Pole",
			Position = UDim2.fromScale(0.16, 0.08),
			Size = UDim2.fromScale(0.1, 0.9),
			BackgroundColor3 = Palette.Navy,
			BorderSizePixel = 0,
			Parent = flag,
		})
		local cloth: Frame = Build.make("Frame", {
			Name = "Cloth",
			Position = UDim2.fromScale(0.26, 0.1),
			Size = UDim2.fromScale(0.62, 0.5),
			BackgroundColor3 = Palette.Grey,
			BorderSizePixel = 0,
			Parent = flag,
		})
		Build.corner(cloth, UDim.new(0.25, 0))
		Build.stroke(cloth, 2, Palette.Navy)
		cells[i] = { holder = holder, scale = scale, art = art, flag = flag, cloth = cloth }
	end
	local self = setmetatable({
		frame = frame,
		count = count,
		filled = 0,
		cells = cells,
		props = props,
		goldKey = props.goldKey or "r8_card_pip_gold",
		greyKey = props.greyKey or "r8_card_pip_grey",
		pulse = nil,
		pulseCell = nil,
		trove = trove,
	}, Obj)
	trove:Add(function()
		stopPulse(self)
	end);
	(self :: any):set(props.filled)
	frame.Parent = parent
	return (self :: any) :: Pips
end

function Obj.set(self: any, filled: number)
	self.filled = math.clamp(math.floor(filled), 0, self.count)
	for i, cell in self.cells do
		paint(self, cell, i <= self.filled)
	end
	startPulse(self)
end

function Obj.pop(self: any, index: number)
	local cell = self.cells[index] :: Cell?
	if not cell then
		return
	end
	if self.pulseCell == cell then
		stopPulse(self)
	end
	if Calm() then
		return -- Reduce Motion: the colour change is the whole feedback
	end
	cell.scale.Scale = 0.3
	local up = TweenService:Create(
		cell.scale,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1.5 }
	)
	local settle = TweenService:Create(
		cell.scale,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	self.trove:Add(up)
	self.trove:Add(settle)
	up.Completed:Once(function()
		settle:Play()
	end)
	up:Play()
end

function Obj.cell(self: any, index: number): Frame
	return (self.cells[index] :: Cell).holder
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return Pips
