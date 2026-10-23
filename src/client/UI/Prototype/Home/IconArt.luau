--!strict
-- Home HUD icon helper (Lane 3 preview). Draws the first name in a list that has real art,
-- through the kit (Arcade.icon: Icons2, then the overnight Icons), and otherwise a neutral
-- "missing icon" glyph, so a holder is never left blank.
--
-- Why this exists: for a name the overnight Icons module does not know (e.g. "CashStack" before
-- Icons2 lands), Icons.draw creates an EMPTY "Art" frame and Arcade.icon reports success, which
-- would leave a blank hole. Reported to the lead (Arcade.icon is lead-owned); this helper treats
-- an empty frame as "no art".
--
--   IconArt.draw(holder, { "Gift", "Cart", "Shop" }) -> (drawnName: string?)
--   IconArt.hasArt(holder) -> boolean

local Arcade = require(script.Parent.Parent.Arcade)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)

local A = PreviewTokens.Arcade

local IconArt = {}

function IconArt.hasArt(holder: Instance): boolean
	local found = false
	for _, child in holder:GetChildren() do
		if child:GetAttribute("Icon") == "Missing" then
			return false
		end
		if child:IsA("GuiObject") and not (child:IsA("Frame") and #child:GetChildren() == 0) then
			found = true
		end
	end
	return found
end

local function clear(holder: Instance)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The neutral glyph (same look as the kit's): a pale rounded square with a "?".
function IconArt.missing(holder: Instance)
	clear(holder)
	local box = Arcade.make("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundColor3 = Color3.fromRGB(230, 236, 246),
		Parent = holder,
	})
	box:SetAttribute("Icon", "Missing")
	Arcade.corner(box, 6)
	Arcade.outline(box, "Minor")
	Arcade.make("TextLabel", {
		Name = "Q",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = PreviewTokens.Font(),
		Text = "?",
		TextScaled = true,
		TextColor3 = A.Ink,
		Parent = box,
	})
end

function IconArt.draw(holder: Frame, names: { string }): string?
	for _, name in names do
		clear(holder)
		local ok = pcall(Arcade.icon, holder, name)
		if ok and IconArt.hasArt(holder) then
			return name
		end
	end
	IconArt.missing(holder)
	return nil
end

return IconArt
