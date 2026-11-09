--!strict
-- R8Kit.RibbonTitle (Lane 3 Round 8, U-01/U-02): the title ribbon across the top edge of a card. The Raceway card's is a
-- chequered-flag banner ("r8_card_ribbon", text-free art) with the title in white and a thick navy outline, live. The art (or, until
-- it is uploaded, a code-drawn chequered strip) is drawn behind the text; the words are always a live TextLabel.
--
--   local r = RibbonTitle.new(parent: GuiObject, props: Props) -> RibbonTitle
--     Props: { text: string, size: UDim2? (702 x 103 design px), position: UDim2?, anchor: Vector2?, zIndex: number?,
--              textSize: number? (design px, 54), artKey: string? (override, e.g. the Parking ribbon), metrics: Metrics? }
--   r.frame: Frame        r.label: TextLabel        r:setText(text: string)        r:destroy()
-- Place it so it straddles the card's top edge (the reference puts it 47 design px above the card, 56 px inside).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Metrics = require(script.Parent.Metrics)
local Palette = require(script.Parent.Palette)

local RibbonTitle = {}

export type Props = {
	text: string,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	textSize: number?,
	artKey: string?,
	metrics: any?,
}

export type RibbonTitle = {
	frame: Frame,
	label: TextLabel,
	setText: (self: RibbonTitle, text: string) -> (),
	destroy: (self: RibbonTitle) -> (),
}

local Obj = {}
Obj.__index = Obj

local function drawFallback(root: Frame, w: number, h: number)
	local base = Build.make("Frame", {
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.Navy,
		BorderSizePixel = 0,
		Parent = root,
	})
	Build.corner(base, UDim.new(0, 18))
	Build.stroke(base, 4, Palette.NavyDeep)
	local cell = math.floor(h / 4)
	local cols = math.floor(w / cell)
	for row = 0, 3 do
		if row == 1 or row == 2 then
			continue -- the middle rows stay navy: the text sits there
		end
		for col = 0, cols - 1 do
			if (row + col) % 2 == 0 then
				Build.make("Frame", {
					Name = "Check",
					Position = UDim2.fromOffset(col * cell + (w - cols * cell) / 2, row * cell),
					Size = UDim2.fromOffset(cell, cell),
					BackgroundColor3 = Palette.White,
					BorderSizePixel = 0,
					Parent = root,
				})
			end
		end
	end
end

function RibbonTitle.new(parent: GuiObject, props: Props): RibbonTitle
	local trove = Trove.new()
	local metrics = props.metrics or Metrics.new(Vector2.new(988, 527))
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = "RibbonTitle",
		Size = props.size or UDim2.fromOffset(702, 103),
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
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = frame,
	})
	if not Art.apply(art, props.artKey or "r8_card_ribbon") then
		local size = props.size or UDim2.fromOffset(702, 103)
		local fb: Frame = Build.make("Frame", {
			Name = "Fallback",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = frame,
		})
		drawFallback(
			fb,
			if size.X.Offset > 0 then size.X.Offset else 702,
			if size.Y.Offset > 0 then size.Y.Offset else 103
		)
	end
	local label = Build.label(frame, "Title", props.text, {
		ZIndex = 2,
		TextColor3 = Palette.White,
		TextTruncate = Enum.TextTruncate.None,
	})
	Build.stroke(label, 6, Palette.Navy, Enum.ApplyStrokeMode.Contextual)
	-- a long title shrinks to fit the ribbon, never below the 16 px minimum
	label.TextScaled = true
	local limit: UITextSizeConstraint = Build.make("UITextSizeConstraint", {
		MaxTextSize = props.textSize or 46,
		MinTextSize = metrics:textSize(16),
		Parent = label,
	})
	trove:Add(metrics.changed:Connect(function()
		limit.MinTextSize = metrics:textSize(16)
	end))
	label.Size = UDim2.fromScale(0.68, 0.62)
	label.Position = UDim2.fromScale(0.16, 0.14)
	frame.Parent = parent
	local self = setmetatable({ frame = frame, label = label, trove = trove }, Obj)
	return (self :: any) :: RibbonTitle
end

function Obj.setText(self: any, text: string)
	self.label.Text = text
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return RibbonTitle
