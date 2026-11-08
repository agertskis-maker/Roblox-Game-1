--!strict
-- R8Kit.Chip (Lane 3 Round 8, U-01): one rounded "NEW AT NEXT LEVEL" chip: a small picture on top and one or two live words under
-- it. The chip body is the cream pill art ("r8_card_pill", same 9-slice as the stat pill) and the pictures are cells of one sprite
-- sheet ("r8_card_chipicons", 8 columns of 128 px cells, names in Chip.Icons). Until the art is uploaded the picture is a code-drawn
-- gold badge. The label wraps to two lines when the card is small (the 16 px text minimum), never below it.
--
--   local c = Chip.new(parent: GuiObject, props: Props) -> Chip
--     Props: { label: string, icon: string? (a name from Chip.Icons, default "star"), size: UDim2? (140 x 106 design px),
--              position: UDim2?, anchor: Vector2?, zIndex: number?, metrics: Metrics? }
--   c.frame: Frame     c.label: TextLabel      c:setLabel(text)      c:setIcon(name)      c:destroy()
--   Chip.Icons: { [string]: number }   the sprite sheet cell (1-based, row-major) of each picture
--   Chip.SheetKey = "r8_card_chipicons"   Chip.Columns = 8   Chip.CellPx = 128

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Metrics = require(script.Parent.Metrics)
local Palette = require(script.Parent.Palette)

local Chip = {}

Chip.SheetKey = "r8_card_chipicons"
Chip.Columns = 8
Chip.CellPx = 128
Chip.Icons = table.freeze({
	bleachers = 1,
	crowd = 2,
	gantry = 3,
	rope = 4,
	pennants = 5,
	snackcart = 6,
	asphalt = 7,
	tyrewall = 8,
	official = 9,
	startlights = 10,
	pitgarage = 11,
	marshals = 12,
	grandstand = 13,
	announcer = 14,
	floodlights = 15,
	bigscreen = 16,
	lightstrip = 17,
	banked = 18,
	raised = 19,
	ramp = 20,
	hump = 21,
	blimp = 22,
	loop = 23,
	statue = 24,
	skybeams = 25,
	fireworks = 26,
	startboard = 27,
	kerbs = 28,
	flagline = 29,
	lapboard = 30,
	roof = 31,
	star = 32,
} :: { [string]: number })

export type Props = {
	label: string,
	icon: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	metrics: any?,
}

export type Chip = {
	frame: Frame,
	label: TextLabel,
	setLabel: (self: Chip, text: string) -> (),
	setIcon: (self: Chip, name: string) -> (),
	destroy: (self: Chip) -> (),
}

local Obj = {}
Obj.__index = Obj

function Chip.new(parent: GuiObject, props: Props): Chip
	local trove = Trove.new()
	local metrics = props.metrics or Metrics.new(Vector2.new(988, 527))
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = "Chip",
		Size = props.size or UDim2.fromOffset(140, 106),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 1,
	}))
	local art: ImageLabel = Build.make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = frame,
	})
	if Art.apply(art, "r8_card_pill") then
		Art.fitSlice(trove, art, "r8_card_pill", "y")
	else
		local fill: Frame = Build.make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.CreamLight,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = frame,
		})
		Build.corner(fill, UDim.new(0, 20))
		Build.stroke(fill, 2, Color3.fromRGB(205, 172, 135))
	end
	local icon: ImageLabel = Build.make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.66, 0.5),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
		Parent = frame,
	})
	-- fallback badge, shown when the sprite sheet is not available
	local badge: Frame = Build.make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Palette.Gold,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})
	Build.corner(badge, UDim.new(0.5, 0))
	Build.stroke(badge, 3, Palette.Navy)
	Build.make(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Palette.GoldBright, Palette.GoldDeep), Parent = badge }
	)
	local label = Build.label(frame, "Label", props.label, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(0.94, 0.44),
		ZIndex = 2,
		TextColor3 = Palette.Navy,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTruncate = Enum.TextTruncate.None,
	})
	metrics:bindText(trove, label, 22)
	local self = setmetatable({ frame = frame, label = label, icon = icon, badge = badge, trove = trove }, Obj);
	(self :: any):setIcon(props.icon or "star")
	frame.Parent = parent
	return (self :: any) :: Chip
end

function Obj.setLabel(self: any, text: string)
	self.label.Text = text
end

function Obj.setIcon(self: any, name: string)
	local cell = Chip.Icons[name] or Chip.Icons.star
	local shown = Art.sprite(self.icon, Chip.SheetKey, cell, Chip.Columns, Chip.CellPx)
	self.badge.Visible = not shown
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return Chip
