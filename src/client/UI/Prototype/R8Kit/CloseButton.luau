--!strict
-- R8Kit.CloseButton (Lane 3 Round 8, U-01/U-02): the round glossy red close button that sits ON TOP of a card's frame, never cut
-- by it. Art "r8_card_close" (the white X is part of the art, a UI symbol) or a code-drawn red disc with two white bars. The
-- touch target is never smaller than 44 real pixels, whatever the card's scale.
--
--   local c = CloseButton.new(parent: GuiObject, props: Props) -> CloseButton
--     Props: { size: number? (disc diameter, 80 design px), position: UDim2?, anchor: Vector2?, zIndex: number?, metrics: Metrics? }
--   c.frame: Frame (the disc's box)     c.button: TextButton (the hit area)     c.Pressed (Signal, no arguments)     c:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Metrics = require(script.Parent.Metrics)
local Palette = require(script.Parent.Palette)

local CloseButton = {}

CloseButton.MinTouchPx = 44

export type Props = {
	size: number?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	metrics: any?,
}

export type CloseButton = {
	frame: Frame,
	button: TextButton,
	Pressed: any,
	destroy: (self: CloseButton) -> (),
}

local Obj = {}
Obj.__index = Obj

function CloseButton.new(parent: GuiObject, props: Props): CloseButton
	local trove = Trove.new()
	local metrics = props.metrics or Metrics.new(Vector2.new(988, 527))
	local disc = props.size or 80
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = "CloseButton",
		Size = UDim2.fromOffset(disc, disc),
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
	if not Art.apply(art, "r8_card_close") then
		local face: Frame = Build.make("Frame", {
			Name = "Face",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.RedBright,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = frame,
		})
		Build.corner(face, UDim.new(0.5, 0))
		Build.stroke(face, 5, Palette.Navy)
		Build.make(
			"UIGradient",
			{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 110, 110), Palette.RedDeep), Parent = face }
		)
		local ring: Frame = Build.make("Frame", {
			Name = "Rim",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.82, 0.82),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = frame,
		})
		Build.corner(ring, UDim.new(0.5, 0))
		Build.stroke(ring, 3, Palette.White)
		for _, angle in { 45, -45 } do
			local bar = Build.make("Frame", {
				Name = "X",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.13),
				Rotation = angle,
				BackgroundColor3 = Palette.White,
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = frame,
			})
			Build.corner(bar, UDim.new(0.5, 0))
			Build.stroke(bar, 2, Palette.Navy)
		end
	end
	-- the hit area: at least 44 real px, centred on the disc
	local button: TextButton = Build.make("TextButton", {
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
		Parent = frame,
	})
	local function fit()
		local side = math.max(disc, math.ceil(CloseButton.MinTouchPx / metrics.scale))
		button.Size = UDim2.fromOffset(side, side)
	end
	fit()
	trove:Add(metrics.changed:Connect(fit))
	local pressed = Signal.new()
	trove:Add(pressed, "DisconnectAll")
	trove:Add(button.Activated:Connect(function()
		pressed:Fire()
	end))
	frame.Parent = parent
	local self = setmetatable({ frame = frame, button = button, Pressed = pressed, trove = trove }, Obj)
	return (self :: any) :: CloseButton
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return CloseButton
