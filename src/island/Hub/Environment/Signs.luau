--!strict
-- Sign and banner faces for the island (Lane 3, build-time), built by hand from the Figma mocks
-- and specs (vault/design/ui/island-signs.md, plot-track-signs.md; Figma "Car Hop UI", page
-- "Island signs"). Art made in Figma is an uploaded image (AssetIds.SignArt); text that will
-- later be live (a player's name) is a TextLabel over a text-free background. Fredoka One per
-- AGENTS.md. Placeholder text is marked with a "Placeholder" attribute. No prices, prompts or
-- buttons anywhere.

local AssetIds = require(script.Parent.AssetIds)

local Signs = {}

local FONT = Font.fromName("FredokaOne")
local CREAM = Color3.fromRGB(255, 246, 224)
local OUTLINE = Color3.fromRGB(59, 42, 30)

function Signs.texture(name: string): string
	return (AssetIds.Textures :: any)[name] or ""
end

local function art(name: string): string?
	local set = (AssetIds :: any).SignArt
	return set and set[name]
end

local function gui(part: BasePart, pixelsPerStud: number, face: Enum.NormalId?): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pixelsPerStud
	g.LightInfluence = 1
	g.MaxDistance = 400
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = part
	return g
end

local function image(parent: Instance, id: string): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = "Art"
	i.BackgroundTransparency = 1
	i.Size = UDim2.fromScale(1, 1)
	i.Image = id
	i.ScaleType = Enum.ScaleType.Stretch
	i.Parent = parent
	return i
end

local function label(parent: Instance, text: string, rect: { number }, sizePx: number, colour: Color3?): TextLabel
	-- rect = { x, y, w, h } as fractions of the face
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(rect[1], rect[2])
	t.Size = UDim2.fromScale(rect[3], rect[4])
	t.FontFace = FONT
	t.Text = text
	t.TextColor3 = colour or CREAM
	t.TextSize = sizePx
	t.TextScaled = false
	t.TextWrapped = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = math.max(2, math.floor(sizePx / 12))
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = t
	t.Parent = parent
	return t
end

-- A track banner (10 x 1.4 studs on the wall's inner face). Fictional brands from Figma; the
-- owner's banner has its name live over a text-free background.
function Signs.banner(part: BasePart, name: string, plotIndex: number)
	part:SetAttribute("Art", name)
	local id = art(if name == "Owner" then "OwnerBanner" else name)
	if not id then
		return -- blank until the art is in (never invented content)
	end
	local g = gui(part, 100)
	image(g, id)
	if name == "Owner" then
		local t = label(g, "PLAYER'S SPEEDWAY", { 0.04, 0.12, 0.92, 0.76 }, 96)
		-- fit the board whatever its size or the owner name's length (Task 4: it overflowed)
		t.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 200
		limit.Parent = t
		t:SetAttribute("Placeholder", "owner name, from Lane 2 plot ownership")
		part:SetAttribute("PlotIndex", plotIndex)
	end
end

-- The plot entrance nameplate (10 x 2.5 studs): a live name over the Figma background.
function Signs.nameplate(part: BasePart, plotIndex: number)
	local g = gui(part, 100)
	local id = art("Nameplate")
	if id then
		image(g, id)
	else
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(176, 132, 86)
		bg.BorderSizePixel = 0
		bg.Parent = g
	end
	local t = label(g, "PLAYER'S PLOT", { 0.05, 0.14, 0.9, 0.72 }, 120)
	t:SetAttribute("Placeholder", "owner name, from Lane 2 plot ownership")
	part:SetAttribute("PlotIndex", plotIndex)
end

-- ---------------------------------------------------------------- Task 4 plot gate (IRW-151)
-- vault/design/ui/island-task4-signs.md §4, PENDING Adam's approval (decisions 5, 6 and 7): the
-- text is live SurfaceGui text on the gate beam's recorded sign faces (gates/Plot, PlotGateBeam
-- sign_faces). Production moved the spec's label tab and hanging PREVIEW plate into the beam's
-- 17.4 x 2.0 name face (top 13.5 and opening 10.5 limits), so the face holds two rows: the owner
-- name, then YOUR SPEEDWAY with the PREVIEW car count and Income Tier.

-- Accent family by plot index (spec decision 7, pending Adam). Red and orange reuse the
-- Color.Danger and Color.Primary values decoratively, as plot-track-signs does.
Signs.PlotAccents = {
	Color3.fromRGB(229, 72, 77), -- 1 red #E5484D
	Color3.fromRGB(255, 138, 31), -- 2 orange #FF8A1F
	Color3.fromRGB(247, 197, 49), -- 3 yellow #F7C531
	Color3.fromRGB(61, 190, 108), -- 4 green #3DBE6C
	Color3.fromRGB(63, 143, 224), -- 5 blue #3F8FE0
	Color3.fromRGB(142, 91, 232), -- 6 purple #8E5BE8
}

local PLOT_PPS = 50 -- spec §4 PixelsPerStud: the 17.4 x 2.0 face is 870 x 100 px
local NAVY = Color3.fromRGB(30, 42, 74) -- Color.Text #1E2A4A
local INK = Color3.fromRGB(20, 27, 51) -- Color.CashOutline #141B33
local GOLD = Color3.fromRGB(255, 200, 61) -- Color.Coin #FFC83D
local PREVIEW_MAGENTA = Color3.fromRGB(194, 24, 122) -- spec proposal #C2187A
-- "Income Tier" is an economy concept and propose-first (spec §4, decision 6). The spec keeps the
-- words as a PREVIEW placeholder for now; set false to drop them if Adam decides so.
local SHOW_INCOME_TIER = false -- "Income Tier" is economy wording: propose-first (architecture review M5)

-- A horizontal chip in the info row: an optional rounded background with a border, and its text.
local function chip(
	parent: Instance,
	text: string,
	sizePx: number,
	colour: Color3,
	order: number,
	background: Color3?,
	border: Color3?
): Frame
	local f = Instance.new("Frame")
	f.Name = "Chip"
	f.LayoutOrder = order
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromScale(0, 1)
	f.BackgroundTransparency = if background then 0 else 1
	f.BackgroundColor3 = background or Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	if background then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = f
	end
	if border then
		local stroke = Instance.new("UIStroke")
		stroke.Color = border
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
	end
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.FontFace = FONT
	t.Text = text
	t.TextColor3 = colour
	t.TextSize = sizePx
	t.TextWrapped = false
	if not background then
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 2
		stroke.Parent = t
	end
	t.Parent = f
	f.Parent = parent
	return f
end

-- One plot gate name face (front or back of the beam; both show the same). The owner name is a
-- placeholder until Lane 2's plot ownership supplies it; every made-up value carries PREVIEW.
-- Not built yet (spec states, need ownership): the unclaimed state, and SPEEDWAY for non-owners.
function Signs.plotGateName(part: BasePart, plotIndex: number, accent: Color3)
	part:SetAttribute("PlotIndex", plotIndex)
	local g = gui(part, PLOT_PPS)
	g.Name = "PlotName"
	-- texture hook: an approved name-zone texture (AssetIds.SignArt "PlotGateName<n>"); none uploaded
	local id = art("PlotGateName" .. plotIndex)
	if id then
		image(g, id)
	end
	-- row 1: the owner name in upper case, scaled to fit, then truncated (spec §4 long-name state).
	-- Until Lane 2's plot ownership supplies a name, it reads YOUR SPEEDWAY (Task 4 complaint
	-- review J8: "PLAYER NAME" read as an unfilled template on all six homes)
	local name = label(g, "YOUR SPEEDWAY", { 0.03, 0.03, 0.94, 0.58 }, 58)
	name.Name = "OwnerName"
	name.TextScaled = true
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 58
	limit.MinTextSize = 24
	limit.Parent = name
	local nameStroke = name:FindFirstChildOfClass("UIStroke")
	if nameStroke then
		nameStroke.Color = INK
		nameStroke.Thickness = 3
	end
	name:SetAttribute("Placeholder", "owner name, from Lane 2 plot ownership (filtered display name)")
	name:SetAttribute("Preview", true)
	-- row 2: the PREVIEW stats (the YOUR SPEEDWAY / SPEEDWAY tab joins them once row 1 shows the
	-- owner name)
	local row = Instance.new("Frame")
	row.Name = "InfoRow"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0, 0.64)
	row.Size = UDim2.fromScale(1, 0.32)
	row.Parent = g
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 14)
	list.Parent = row
	local tag = chip(row, "PREVIEW", 18, PREVIEW_MAGENTA, 2, Color3.new(1, 1, 1), PREVIEW_MAGENTA)
	tag.Name = "PreviewTag"
	local cars = chip(row, "7 CARS", 22, NAVY, 3, CREAM, accent) -- the pill keeps the plot accent
	cars.Name = "CarCount"
	cars:SetAttribute("Preview", "made-up car count; no contract yet")
	if SHOW_INCOME_TIER then
		local tier = chip(row, "INCOME TIER 2", 22, GOLD, 4)
		tier.Name = "IncomeTier"
		tier:SetAttribute("Preview", "economy wording, propose-first (spec §4 decision 6); not a real value")
	end
end

-- One plot number face on an accent disc at a beam end (2 x 2 studs): capitals 1.4 (spec §4).
function Signs.plotGateNumber(part: BasePart, plotIndex: number)
	part:SetAttribute("PlotIndex", plotIndex)
	local g = gui(part, PLOT_PPS)
	g.Name = "PlotNumber"
	-- TextSize = capitals 1.4 / 0.75 x 50 px per stud
	local t = label(g, tostring(plotIndex), { 0, 0, 1, 1 }, 93)
	t.Name = "Number"
	local stroke = t:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 6
	end
end

-- The upgrade kiosk's front panel: "UPGRADES" art (placeholder; no prices or prompts).
function Signs.kioskPanel(part: BasePart)
	local id = art("Kiosk")
	if not id then
		return
	end
	image(gui(part, 100), id)
end

-- A Paddock bay number painted on the floor tile (top face), readable from the aisle.
function Signs.bayNumber(part: BasePart, number: number, initial: boolean, facing: number)
	local g = gui(part, 20, Enum.NormalId.Top)
	g.LightInfluence = 1
	local t = label(
		g,
		tostring(number),
		{ 0.1, 0.62, 0.8, 0.3 },
		56,
		if initial then CREAM else Color3.fromRGB(236, 240, 244)
	)
	t.Rotation = if facing < 0 then 180 else 0
	t.TextTransparency = if initial then 0 else 0.35
end

-- Signpost destinations (vault/design/ui/island-signs.md): word, icon and badge colour.
Signs.Destinations = {
	Portals = { text = "PORTALS", icon = "IconPortal", badge = Color3.fromRGB(186, 92, 255) },
	Garage = { text = "GARAGE", icon = "IconGarage", badge = Color3.fromRGB(217, 80, 63) },
	Stunts = { text = "STUNTS", icon = "IconStunt", badge = Color3.fromRGB(247, 206, 88) },
	Plots = { text = "PLOTS", icon = "IconPlots", badge = Color3.fromRGB(255, 150, 60) },
	Lake = { text = "LAKE", icon = "IconLake", badge = Color3.fromRGB(81, 215, 209) },
}

-- One face of a signpost arrow board (420 x 95 px): badge, icon and word, icon first. x0 is 0
-- when the tip is on the right of this face and 60 when it is on the left (the spec's layout).
local function boardFace(part: BasePart, face: Enum.NormalId, destination: string, tipLeft: boolean)
	local d = (Signs.Destinations :: any)[destination]
	local g = gui(part, 100, face)
	g.Name = "Board" .. face.Name
	local x0 = if tipLeft then 60 else 0
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Position = UDim2.fromOffset(x0 + 12, 7.5)
	badge.Size = UDim2.fromOffset(80, 80)
	badge.BackgroundColor3 = d.badge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge
	local ring = Instance.new("UIStroke")
	ring.Color = OUTLINE
	ring.Thickness = 4
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = badge
	badge.Parent = g
	local icon = image(g, art(d.icon) or "")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Position = UDim2.fromOffset(x0 + 20, 15.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 2
	local t = label(g, d.text, { 0, 0, 0, 0 }, 52)
	t.Position = UDim2.fromOffset(x0 + 104, 16)
	t.Size = UDim2.fromOffset(248, 63)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 2
	local stroke = t:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 4
	end
end

-- A signpost board's two faces, on a face part whose +X points along the board to its tip.
-- Seen on the Front face the tip is on the viewer's left; on the Back face, on the right.
function Signs.signpostBoard(part: BasePart, destination: string)
	part:SetAttribute("Destination", destination)
	boardFace(part, Enum.NormalId.Front, destination, true)
	boardFace(part, Enum.NormalId.Back, destination, false)
end

-- A food stand header (3.0 x 1.6 studs): one picture, no words.
function Signs.header(part: BasePart, stand: string)
	local id = art("Header" .. stand)
	part:SetAttribute("Stand", stand)
	if not id then
		return
	end
	image(gui(part, 100), id)
end

return Signs
