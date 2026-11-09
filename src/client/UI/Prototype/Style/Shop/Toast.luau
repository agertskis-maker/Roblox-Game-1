--!strict
-- Toast (Lane 3 Round 8, C-07): the "Equipped!" pill on the Style Shop's stage, with a little burst of sparkles. It slides in,
-- stays a moment and fades. Reduce Motion: the pill just appears and goes, with no sparkles.
--
--   Toast.show(parent: GuiObject, words: string, options: { z: number?, reduced: boolean?, seconds: number? })

local TweenService = game:GetService("TweenService")

local Prototype = script.Parent.Parent.Parent
local CarKit = require(Prototype.CarKit)

local make = CarKit.make

local Toast = {}

local CREAM = Color3.fromRGB(255, 244, 218)
local NAVY = Color3.fromRGB(20, 33, 63)
local GREEN = Color3.fromRGB(73, 200, 87)
local GOLD = Color3.fromRGB(247, 198, 76)

local SPARKLES = 9

function Toast.show(parent: GuiObject, words: string, options: { z: number?, reduced: boolean?, seconds: number? }?)
	local o = options or {}
	local z = o.z or 20
	local reduced = o.reduced == true
	local hold = o.seconds or 1.5
	local pill = make("Frame", {
		Name = "Toast",
		BackgroundColor3 = CREAM,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if reduced then 12 else 30),
		Size = UDim2.fromOffset(220, 44),
		ZIndex = z,
	}, parent) :: Frame
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
	make("UIStroke", { Thickness = 3, Color = GREEN, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pill)
	local label = make("TextLabel", {
		Name = "Words",
		BackgroundTransparency = 1,
		FontFace = CarKit.body(),
		Text = words,
		TextColor3 = NAVY,
		TextScaled = true,
		Size = UDim2.new(1, -24, 0.72, 0),
		Position = UDim2.new(0, 12, 0.14, 0),
		ZIndex = z + 1,
	}, pill) :: TextLabel
	make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, label)
	if reduced then
		task.delay(hold, function()
			pill:Destroy()
		end)
		return
	end
	pill.BackgroundTransparency = 1
	label.TextTransparency = 1
	TweenService:Create(pill, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 12),
		BackgroundTransparency = 0,
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
	for i = 1, SPARKLES do
		local angle = (i / SPARKLES) * math.pi * 2 + 0.3
		local reach = 70 + (i % 3) * 22
		local spark = make("Frame", {
			Name = "Sparkle",
			BackgroundColor3 = if i % 2 == 0 then GOLD else Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 34),
			Size = UDim2.fromOffset(12, 12),
			Rotation = 45,
			ZIndex = z + 2,
		}, parent) :: Frame
		TweenService:Create(spark, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * reach * 1.5, 0, 34 + math.sin(angle) * reach * 0.8),
			Size = UDim2.fromOffset(3, 3),
			BackgroundTransparency = 1,
			Rotation = 225,
		}):Play()
		task.delay(0.75, function()
			spark:Destroy()
		end)
	end
	task.delay(hold, function()
		if pill.Parent == nil then
			return
		end
		TweenService
			:Create(pill, TweenInfo.new(0.3), { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0) })
			:Play()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		for _, d in pill:GetDescendants() do
			if d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.35, function()
			pill:Destroy()
		end)
	end)
end

return Toast
