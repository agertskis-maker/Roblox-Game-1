--!strict
-- The Raceway shop's stats board and the big screen (Lane 3, client presentation only; Raceway
-- round 2, approved by Adam on 2026-10-29: vault/design/ui/speedway-upgrade-board.md R1 and R3).
-- The board beside the shop shows what the next level gives, not a picture: "RACEWAY LEVEL n",
-- "LAP PAY x1.35 -> x1.50" (the proposed Lap Pay table, Ladder.LapPay, Brian L's to replace),
-- "NEXT: LEVEL n+1", the "New:" line and "PRICE: SET BY ECONOMY" with a PREVIEW tag (no amount: prices
-- are Lane 2's). At level 12 it shows MAX LEVEL. Visitors see the same board (it is a sign; nothing
-- to press). The big screen (levels 8 to 12) shows "RACEWAY LEVEL n" near and a plain bar far.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Speedway = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("Speedway")
local Ladder = require(Speedway:WaitForChild("Ladder"))
local Look = require(Speedway:WaitForChild("Look"))
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Kiosk = {}

local NAVY = Color3.fromRGB(36, 58, 98)
local CREAM = Color3.fromRGB(255, 246, 224)
local OUTLINE = Color3.fromRGB(20, 27, 51)
local YELLOW = Color3.fromRGB(250, 206, 70)
local MINT = Color3.fromRGB(128, 216, 189)
local TEAL = Tokens.Color.Teal
local TEAL_LIGHT = Tokens.Color.TealLight

-- Outlined Fredoka text in a px box { x, y, w, h } of a 215 x 235 face, scaled to fit up to `size`.
local function text(
	parent: Instance,
	value: string,
	box: { number },
	size: number,
	colour: Color3,
	outline: number?
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(box[1], box[2])
	t.Size = UDim2.fromOffset(box[3], box[4])
	t.FontFace = Tokens.font()
	t.Text = value
	t.TextScaled = true
	t.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 12
	limit.Parent = t
	t.TextColor3 = colour
	local s = Instance.new("UIStroke")
	s.Color = OUTLINE
	s.Thickness = outline or math.max(1, math.floor(size / 14))
	s.Parent = t
	t.Parent = parent
	return t
end

local function box(parent: Instance, rect: { number }, colour: Color3, radius: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(rect[1], rect[2])
	f.Size = UDim2.fromOffset(rect[3], rect[4])
	f.BackgroundColor3 = colour
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

-- A line between two px points (for the arrows), `w` thick.
local function bar(parent: Instance, a: Vector2, b: Vector2, w: number, colour: Color3)
	local d = b - a
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(d.Magnitude + w, w)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.BackgroundColor3 = colour
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
end

-- "x1.35 -> (up cue) x1.50" centred in a row at y, h px high.
local function lapPayRow(parent: Instance, level: number, y: number, h: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.fromOffset(215, h)
	row.Parent = parent
	-- fixed pieces: 64 | 5 | arrow 20 | 5 | cue 14 | 3 | 64, centred in 215
	local x0 = (215 - (64 + 5 + 20 + 5 + 14 + 3 + 64)) / 2
	text(row, Ladder.lapPayText(level), { x0, 0, 64, h }, 24, CREAM)
	local ax = x0 + 69
	local mid = h / 2
	bar(row, Vector2.new(ax, mid), Vector2.new(ax + 18, mid), 3, CREAM)
	bar(row, Vector2.new(ax + 12, mid - 5), Vector2.new(ax + 18, mid), 3, CREAM)
	bar(row, Vector2.new(ax + 12, mid + 5), Vector2.new(ax + 18, mid), 3, CREAM)
	-- the up cue: a shape, not only a colour, says "more"
	local cx = ax + 25 + 7
	for _, w in { 6, 3 } do
		local colour = if w == 6 then OUTLINE else TEAL_LIGHT
		bar(row, Vector2.new(cx, mid + 8), Vector2.new(cx, mid - 6), w, colour)
		bar(row, Vector2.new(cx - 5, mid - 1), Vector2.new(cx, mid - 6), w, colour)
		bar(row, Vector2.new(cx + 5, mid - 1), Vector2.new(cx, mid - 6), w, colour)
	end
	text(row, Ladder.lapPayText(level + 1), { cx + 10, 0, 64, h }, 24, TEAL_LIGHT)
end

-- Dashed 2 px outline round a px rect (UIStroke has no dashes).
local function dashed(parent: Instance, rect: { number }, colour: Color3)
	local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
	local dash, gap = 5, 3
	local s = 0
	while s < w do
		local len = math.min(dash, w - s)
		box(parent, { x + s, y, len, 2 }, colour)
		box(parent, { x + s, y + h - 2, len, 2 }, colour)
		s += dash + gap
	end
	s = 0
	while s < h do
		local len = math.min(dash, h - s)
		box(parent, { x, y + s, 2, len }, colour)
		box(parent, { x + w - 2, y + s, 2, len }, colour)
		s += dash + gap
	end
end

local function faceOf(plot: Model, attribute: string): BasePart?
	local root = plot:FindFirstChild("SpeedwayLook")
	if not root then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(attribute) then
			return d
		end
	end
	return nil
end

-- Fills the plot's stats board for `level`.
function Kiosk.fill(plot: Model, level: number, _options: Look.Options?)
	local face = faceOf(plot, "KioskBoard")
	if not face then
		return
	end
	-- The board's SurfaceGui lives in PlayerGui, adorned to the face (kept from round 1, when a
	-- ViewportFrame needed it); it goes when the face does.
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local inWorld = face:FindFirstChildOfClass("SurfaceGui")
	local name = "Lane3KioskBoard_" .. plot.Name
	local existing = playerGui:FindFirstChild(name) :: SurfaceGui?
	if not existing then
		local made = Instance.new("SurfaceGui")
		made.Name = name
		made.Face = Enum.NormalId.Front
		made.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		made.PixelsPerStud = 50
		made.LightInfluence = 1
		made.MaxDistance = 400
		made.ResetOnSpawn = false
		made.Parent = playerGui
		existing = made
	end
	local board = existing :: SurfaceGui
	if board.Adornee ~= face then
		board.Adornee = face
		face.Destroying:Once(function()
			if board.Adornee == face or board.Adornee == nil then
				board:Destroy()
			end
		end)
	end
	board:ClearAllChildren()
	if inWorld then
		inWorld:Destroy()
	end
	local bg = box(board, { 0, 0, 215, 235 }, NAVY)
	bg.Size = UDim2.fromScale(1, 1)
	local current = Ladder.clamp(level)
	text(bg, "RACEWAY LEVEL " .. current, { 8, 10, 199, 26 }, 22, YELLOW)
	if current >= Ladder.MaxLevel then
		text(bg, "MAX LEVEL", { 8, 52, 199, 44 }, 34, CREAM, 2)
		box(bg, { 58, 97, 99, 6 }, TEAL, 3)
		text(bg, "LAP PAY", { 8, 126, 199, 20 }, 16, CREAM)
		text(bg, Ladder.lapPayText(current), { 8, 146, 199, 36 }, 30, CREAM)
		return
	end
	text(bg, "LAP PAY", { 8, 42, 199, 18 }, 16, CREAM)
	lapPayRow(bg, current, 58, 30)
	text(bg, "NEXT: LEVEL " .. (current + 1), { 8, 100, 199, 22 }, 18, CREAM)
	text(bg, Ladder.newText(current + 1) or "", { 14, 126, 187, 40 }, 16, CREAM)
	dashed(bg, { 12, 172, 191, 24 }, MINT)
	local price = text(bg, "PRICE: SET BY ECONOMY", { 18, 174, 179, 20 }, 14, MINT)
	price.Name = "PricePlaceholder"
	local pill = box(bg, { 78, 202, 59, 18 }, NAVY, 9)
	local ring = Instance.new("UIStroke")
	ring.Color = MINT
	ring.Thickness = 2
	ring.Parent = pill
	text(pill, "PREVIEW", { 4, 2, 51, 14 }, 12, MINT, 1)
end

-- each plot's big-screen face, found once per build (false: this plot has none now)
local screens: { [Model]: BasePart | false } = setmetatable({}, { __mode = "k" }) :: any

-- Fills the big screen (levels 8 to 12): "RACEWAY LEVEL n" with a small teal underline.
function Kiosk.fillScreen(plot: Model, level: number)
	screens[plot] = nil
	local face = faceOf(plot, "RacewayScreen")
	if not face then
		return
	end
	local label = face:FindFirstChild("ScreenLevel", true)
	if label and label:IsA("TextLabel") then
		label.Text = "RACEWAY LEVEL " .. Ladder.clamp(level)
	end
end

-- Near: the words; far (beyond `far` studs, with 10 studs of hysteresis): only the broad shapes.
Kiosk.ScreenFar = 80
function Kiosk.screenDetail(plot: Model, eye: Vector3)
	local cached = screens[plot]
	local face: BasePart? = if cached and cached.Parent then cached else nil
	if not face then
		-- look again only after a rebuild (the cache is cleared by fillScreen)
		if cached == false then
			return
		end
		face = faceOf(plot, "RacewayScreen")
		screens[plot] = face or false
		if not face then
			return
		end
	end
	local near = face:FindFirstChild("Near", true)
	local far = face:FindFirstChild("Far", true)
	if not (near and near:IsA("GuiObject") and far and far:IsA("GuiObject")) then
		return
	end
	local d = (face.Position - eye).Magnitude
	local isNear = near.Visible
	if isNear and d > Kiosk.ScreenFar + 10 then
		isNear = false
	elseif not isNear and d < Kiosk.ScreenFar then
		isNear = true
	end
	near.Visible = isNear
	far.Visible = not isNear
end

return Kiosk
