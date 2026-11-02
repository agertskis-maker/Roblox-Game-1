--!strict
-- StuntKit: the small shared pieces behind the Stunt Circuit screens (big round M17-04 and M17-05; Lane 3, PREVIEW): the
-- persistent PREVIEW caption, the three medal badges, the 1 to 5 stat pips and a stat row. Built on the Arcade kit and Style.
-- It knows no time, price or rule; the screens and StuntFixtures supply those.
--
--   StuntKit.previewChip(parent, text?, z?) -> Style.Stamp     -- the caption that never hides (attribute PersistentPreview)
--   StuntKit.medalBadge(parent, key, size, z) -> Frame         -- Bronze a circle, Silver a diamond, Gold an eight-point seal
--   StuntKit.pips(parent, value?, size, z) -> Frame            -- five diamonds; nil = all empty ("not set yet")
--   StuntKit.statRow(parent, label, value?, z) -> Frame        -- "Speed", pips, and the number or "--"
--   StuntKit.touchOk(report, minimum) -> { string }            -- the interactive objects smaller than `minimum` design px
--
-- Medals differ in SILHOUETTE as well as colour (M17-04a): a round Bronze, a diamond Silver, a pointed seal Gold, and each
-- carries its letter, and the screens always print its word beside it.

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local IconArt = require(Prototype.Home.IconArt)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)

local A = PreviewTokens.Arcade
local make = Arcade.make

local StuntKit = {}

local INK = A.Ink
local PIP_ON = Color3.fromRGB(255, 206, 60)
local PIP_OFF = Color3.fromRGB(20, 30, 62)

-- PREVIEW CAPTION ----------------------------------------------------------------------------------------------------

-- A small gold PREVIEW stamp. It carries PersistentPreview, NOT PreviewCaption: the harness can hide its own captions for a
-- player-facing capture, but this one is part of the screen and stays (M17-04b: a preview leaderboard has a persistent caption).
function StuntKit.previewChip(parent: Instance, text: string?, z: number?): Style.Stamp
	local stamp = Style.stamp(parent, text or StuntFixtures.Caption, "Gold", z or 9)
	stamp.frame.Name = "PreviewChip"
	stamp.frame.Rotation = 0
	stamp.frame:SetAttribute("PersistentPreview", true)
	return stamp
end

-- MEDAL BADGES -------------------------------------------------------------------------------------------------------

local function block(
	parent: Instance,
	name: string,
	side: number,
	colour: Color3,
	rotation: number,
	z: number,
	radius: number?
): Frame
	local f: Frame = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(side, side),
		Rotation = rotation,
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	if radius then
		Arcade.corner(f, radius)
	end
	return f
end

-- The badge fits a size x size box. The dark outline is built as a bigger dark shape UNDER the fill, so a shape made of two
-- squares (the seal) never draws one square's outline across the other's fill.
function StuntKit.medalBadge(parent: Instance, key: string, size: number, z: number): Frame
	local info = (StuntFixtures.Medals :: { [string]: StuntFixtures.MedalInfo })[key] or StuntFixtures.Medals.bronze
	local root: Frame = make("Frame", {
		Name = "Medal_" .. info.word,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	root:SetAttribute("Medal", info.key)
	local edge = math.max(3, math.floor(size * 0.04))
	if info.key == "bronze" then
		block(root, "Outline", size, INK, 0, z, size)
		block(root, "Face", size - edge * 2, info.colour, 0, z + 1, size)
		block(root, "Ring", size * 0.64, info.deep, 0, z + 2, size)
		block(root, "Core", size * 0.64 - edge * 2, info.colour, 0, z + 3, size)
	elseif info.key == "silver" then
		local side = size / 1.42
		block(root, "Outline", side, INK, 45, z, math.floor(side * 0.12))
		block(root, "Face", side - edge * 2, info.colour, 45, z + 1, math.floor(side * 0.1))
		block(root, "Ring", side * 0.64, info.deep, 45, z + 2, math.floor(side * 0.08))
		block(root, "Core", side * 0.64 - edge * 2, info.colour, 45, z + 3, math.floor(side * 0.06))
	else
		local side = size / 1.42
		block(root, "OutlineA", side, INK, 0, z, 4)
		block(root, "OutlineB", side, INK, 45, z, 4)
		block(root, "FaceA", side - edge * 2, info.colour, 0, z + 1, 3)
		block(root, "FaceB", side - edge * 2, info.colour, 45, z + 1, 3)
		block(root, "Ring", size * 0.58, info.deep, 0, z + 2, size)
		block(root, "Core", size * 0.58 - edge * 2, info.colour, 0, z + 3, size)
	end
	local letter = Arcade.text(root, {
		text = info.letter,
		role = "Value",
		name = "Letter",
		size = math.max(16, math.floor(size * 0.34)),
		colour = INK,
		z = z + 5,
	})
	letter.AnchorPoint = Vector2.new(0.5, 0.5)
	letter.Position = UDim2.fromScale(0.5, 0.5)
	letter.Size = UDim2.fromOffset(size * 0.5, size * 0.5)
	local stroke = letter:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Enabled = false -- a dark letter on a light disc needs no outline
	end
	if info.key == "gold" then
		-- a small star above the letter keeps Gold apart from Silver even in grey
		local star: Frame = make("Frame", {
			Name = "Star",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, math.floor(size * 0.2)),
			Size = UDim2.fromOffset(math.floor(size * 0.2), math.floor(size * 0.2)),
			BackgroundTransparency = 1,
			ZIndex = z + 5,
			Parent = root,
		})
		IconArt.draw(star, { "Star" })
		letter.Position = UDim2.fromScale(0.5, 0.58)
	end
	return root
end

-- PIPS AND STAT ROWS ---------------------------------------------------------------------------------------------------

-- Five diamonds, the first `value` filled. Filled and empty differ in fill AND in a thicker outline, so the count reads
-- without colour. nil is "not set yet": every diamond empty.
function StuntKit.pips(parent: Instance, value: number?, size: number, z: number): Frame
	local holder: Frame = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size * 5 + 6 * 4, size),
		ZIndex = z,
		Parent = parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	local filled = if value == nil then 0 else math.clamp(math.floor(value), 0, 5)
	holder:SetAttribute("Filled", filled)
	holder:SetAttribute("Known", value ~= nil)
	for i = 1, 5 do
		local on = i <= filled
		local pip: Frame = make("Frame", {
			Name = "Pip" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(size * 0.78, size * 0.78),
			Rotation = 45,
			BackgroundColor3 = if on then PIP_ON else PIP_OFF,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = holder,
		})
		pip:SetAttribute("On", on)
		Arcade.outline(pip, if on then 2.5 else 1.5)
	end
	return holder
end

-- A label, five pips and the number (or "--" when the value is not set yet). The row is 30 tall unless `height` says otherwise.
function StuntKit.statRow(parent: Instance, label: string, value: number?, z: number, height: number?): Frame
	local row: Frame = make("Frame", {
		Name = "Stat_" .. label,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 30),
		ZIndex = z,
		Parent = parent,
	})
	local name = Style.text(row, label, "Label", { name = "Name", z = z + 1 })
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.fromScale(0, 0.5)
	name.Size = UDim2.fromOffset(70, math.min(26, (height or 30) - 2))
	local pips = StuntKit.pips(row, value, 20, z + 1)
	pips.AnchorPoint = Vector2.new(0, 0.5)
	pips.Position = UDim2.new(0, 76, 0.5, 0)
	local number = Style.text(row, if value == nil then "--" else tostring(math.floor(value)) .. "/5", "Small", {
		name = "Number",
		xAlign = Enum.TextXAlignment.Right,
		z = z + 1,
	})
	number.AnchorPoint = Vector2.new(1, 0.5)
	number.Position = UDim2.fromScale(1, 0.5)
	number.Size = UDim2.fromOffset(40, 24)
	return row
end

-- TOUCH ----------------------------------------------------------------------------------------------------------------

-- From SupportKit.touchReport rows: the names of the interactive objects smaller than `minimum` design px on either side.
function StuntKit.touchOk(report: { { name: string, w: number, h: number } }, minimum: number): { string }
	local bad: { string } = {}
	for _, row in report do
		if row.w < minimum - 0.5 or row.h < minimum - 0.5 then
			table.insert(bad, string.format("%s %.0fx%.0f", row.name, row.w, row.h))
		end
	end
	return bad
end

return StuntKit
