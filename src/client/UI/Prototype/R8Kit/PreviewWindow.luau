--!strict
-- R8Kit.PreviewWindow (Lane 3 Round 8, U-01/U-02/U-04): the trackside-TV window of a card: a dark navy bezel with four corner bolts
-- around a picture area, and a small gold tag ("NEXT LEVEL", "MAX LEVEL") on its top edge. The bezel is 9-slice art
-- ("r8_card_bezel", the hole is transparent and its rounded corners hide the square corners of the picture) or, until it is
-- uploaded, a navy rounded frame with bolt dots. Put a ViewportFrame (or any GuiObject) in `content`.
--
--   local w = PreviewWindow.new(parent: GuiObject, props: Props) -> PreviewWindow
--     Props: { size: UDim2? (439 x 372 design px), position: UDim2?, anchor: Vector2?, zIndex: number?,
--              tag: string? (nil = no tag), inset: number? (bezel thickness, 20), artKey: string?, metrics: Metrics? }
--   w.frame: Frame        the bezel rectangle
--   w.content: Frame      the picture area (clips its children; a sky-blue gradient is its background)
--   w.tag: TextLabel?     the tag's live text            w:setTag(text: string?)         w:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Metrics = require(script.Parent.Metrics)
local Palette = require(script.Parent.Palette)

local PreviewWindow = {}

export type Props = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	tag: string?,
	inset: number?,
	artKey: string?,
	metrics: any?,
}

export type PreviewWindow = {
	frame: Frame,
	content: Frame,
	tag: TextLabel?,
	setTag: (self: PreviewWindow, text: string?) -> (),
	destroy: (self: PreviewWindow) -> (),
}

local TAG_W, TAG_H = 226, 52

local Obj = {}
Obj.__index = Obj

function PreviewWindow.new(parent: GuiObject, props: Props): PreviewWindow
	local trove = Trove.new()
	local metrics = props.metrics or Metrics.new(Vector2.new(988, 527))
	local inset = props.inset or 20
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = "PreviewWindow",
		Size = props.size or UDim2.fromOffset(439, 372),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 1,
	}))
	local content: Frame = Build.make("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
		BackgroundColor3 = Color3.new(1, 1, 1), -- the UIGradient below is the sky
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = frame,
	})
	Build.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(110, 190, 255), Color3.fromRGB(200, 232, 255)),
		Parent = content,
	})
	-- the bezel, above the picture
	local bezel: ImageLabel = Build.make("ImageLabel", {
		Name = "Bezel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})
	local key = props.artKey or "r8_card_bezel"
	if Art.apply(bezel, key) then
		Art.fitSlice(trove, bezel, key, "x")
	else
		-- code-drawn bezel: a navy rounded frame drawn as four bars round the picture, bolts in the corners
		local ring: Frame = Build.make("Frame", {
			Name = "Ring",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = frame,
		})
		for _, bar in
			{
				{ UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, inset) },
				{ UDim2.new(0, 0, 1, -inset), UDim2.new(1, 0, 0, inset) },
				{ UDim2.fromScale(0, 0), UDim2.new(0, inset, 1, 0) },
				{ UDim2.new(1, -inset, 0, 0), UDim2.new(0, inset, 1, 0) },
			}
		do
			Build.make("Frame", {
				Name = "Bar",
				Position = bar[1],
				Size = bar[2],
				BackgroundColor3 = Palette.Navy,
				BorderSizePixel = 0,
				Parent = ring,
			})
		end
		Build.stroke(ring, 3, Palette.NavyDeep)
		for _, at in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
			local bolt = Build.make("Frame", {
				Name = "Bolt",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(
					at[1],
					if at[1] == 0 then inset * 0.9 else -inset * 0.9,
					at[2],
					if at[2] == 0 then inset * 0.9 else -inset * 0.9
				),
				Size = UDim2.fromOffset(inset * 0.7, inset * 0.7),
				BackgroundColor3 = Palette.Chrome,
				BorderSizePixel = 0,
				Parent = ring,
			})
			Build.corner(bolt, UDim.new(0.5, 0))
		end
	end
	local self = setmetatable({ frame = frame, content = content, tag = nil, trove = trove, metrics = metrics }, Obj)
	local tagText = props.tag
	if tagText then
		(self :: any):setTag(tagText)
	end
	frame.Parent = parent
	return (self :: any) :: PreviewWindow
end

function Obj.setTag(self: any, text: string?)
	local existing = self.tag :: TextLabel?
	if text == nil then
		if existing then
			existing.Parent:Destroy()
			self.tag = nil
		end
		return
	end
	if existing then
		existing.Text = text
		return
	end
	local holder: Frame = Build.make("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -9),
		Size = UDim2.fromOffset(TAG_W, TAG_H),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = self.frame,
	})
	local art: ImageLabel = Build.make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = holder,
	})
	if Art.apply(art, "r8_card_tag_gold") then
		Art.fitSlice(self.trove, art, "r8_card_tag_gold", "y")
	else
		local fill: Frame = Build.make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.Gold,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = holder,
		})
		Build.corner(fill, UDim.new(0.5, 0))
		Build.stroke(fill, 4, Palette.Navy)
		Build.make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Palette.GoldBright, Palette.GoldDeep),
			Parent = fill,
		})
	end
	local label = Build.label(holder, "Text", text, {
		ZIndex = 2,
		TextColor3 = Palette.Navy,
		TextScaled = true,
		Size = UDim2.fromScale(0.86, 0.66),
		Position = UDim2.fromScale(0.07, 0.17),
	})
	Build.make("UITextSizeConstraint", { MaxTextSize = 32, MinTextSize = self.metrics:textSize(16), Parent = label })
	self.trove:Add(self.metrics.changed:Connect(function()
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		if limit then
			limit.MinTextSize = self.metrics:textSize(16)
		end
	end))
	self.tag = label
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return PreviewWindow
