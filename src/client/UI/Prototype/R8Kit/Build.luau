--!strict
-- R8Kit.Build (Lane 3 Round 8): tiny Instance builders shared by the kit and the cards. Internal helpers; no state.
--
--   Build.make(className, props) -> any        creates an Instance, sets props, parents last
--   Build.corner(parent, radius: UDim)         UICorner
--   Build.stroke(parent, thickness, color, mode?) -> UIStroke
--   Build.label(parent, name, text, props?) -> TextLabel   Fredoka One, transparent, one line, centred
--   Build.font() -> Font

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Build = {}

function Build.font(): Font
	return Tokens.font()
end

function Build.make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

function Build.corner(parent: Instance, radius: UDim): UICorner
	return Build.make("UICorner", { CornerRadius = radius, Parent = parent })
end

function Build.stroke(parent: Instance, thickness: number, color: Color3, mode: Enum.ApplyStrokeMode?): UIStroke
	return Build.make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Build.label(parent: Instance, name: string, text: string, props: { [string]: any }?): TextLabel
	local label: TextLabel = Build.make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		FontFace = Build.font(),
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

return Build
