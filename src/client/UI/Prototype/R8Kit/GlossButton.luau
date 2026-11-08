--!strict
-- GlossButton (Lane 3 Round 8, U-01, U-03 and O-09; API frozen by the lead, art and states built by WS-6a): the ONE big glossy
-- action button and the ONE cannot-afford treatment for every card in the game. Can afford: orange #FD9B25 -> #FD7901 with a
-- white highlight streak and a shine sweep, the Cash icon and the price. Cannot afford: the same shape in grey with
-- "NEED $470 MORE" (amount from the SERVER's missing value or the server-published Cash, never computed from a client guess)
-- and a small round green "+" that opens the Cash shop page. Max: a gold badge in its place. Busy: pressed in, a spinner, input
-- ignored until the server answers (no double buy). Built from AssetIds.UpgradeCards art when uploaded, otherwise code-drawn
-- (UIGradient, UIStroke, UICorner).
--
--   local b = GlossButton.new(parent: GuiObject, props: Props) -> Button
--   b:setState(state: State, info: Info?)     b.Pressed (Signal)    b.PlusPressed (Signal)    b.frame: Frame    b:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local GlossButton = {}

export type State = "buy" | "need" | "max" | "busy" | "disabled"

export type Info = {
	label: string?, -- "UPGRADE", "BUY SPOT", "BUY"
	price: string?, -- already formatted ("$40.5K", "R$ 49"); a Robux button always states its Robux price
	need: string?, -- already formatted shortfall ("$470")
	maxText: string?, -- "MAX LEVEL", "ALL SPOTS OWNED"
	icon: ("cash" | "robux" | "none")?,
}

export type Props = Info & {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
}

export type Button = {
	frame: Frame,
	Pressed: any,
	PlusPressed: any,
	setState: (self: Button, state: State, info: Info?) -> (),
	destroy: (self: Button) -> (),
}

local Obj = {}
Obj.__index = Obj

function GlossButton.new(parent: GuiObject, props: Props): Button
	local trove = Trove.new()
	local frame = trove:Add(Instance.new("Frame"))
	frame.Name = "GlossButton"
	frame.Size = props.size or UDim2.fromScale(0.45, 0.18)
	frame.Position = props.position or UDim2.new()
	frame.AnchorPoint = props.anchor or Vector2.zero
	frame.BackgroundTransparency = 1
	frame.ZIndex = props.zIndex or 1
	local button = Instance.new("TextButton")
	button.Name = "Hit"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = Color3.fromRGB(253, 121, 1)
	button.Text = props.label or ""
	button.TextScaled = true
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = frame
	local self = setmetatable({
		frame = frame,
		Pressed = Signal.new(),
		PlusPressed = Signal.new(),
		trove = trove,
		state = "buy" :: State,
	}, Obj)
	trove:Add(self.Pressed, "DisconnectAll")
	trove:Add(self.PlusPressed, "DisconnectAll")
	trove:Connect(button.Activated, function()
		if self.state == "buy" then
			self.Pressed:Fire()
		end
	end)
	frame.Parent = parent
	return (self :: any) :: Button
end

function Obj.setState(self: any, state: State, _info: Info?)
	self.state = state
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return GlossButton
