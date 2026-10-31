--!strict
-- Floating name tags over traffic and the catch meter over the ridden car, so a player can judge
-- a car before hopping: size, rarity, "1 in N" odds, and "Needs N" against their Rider Level.
-- PLACEHOLDER presentation for the Lane 1 prototype: Lane 3 designs the real world labels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local CarTags = {}

local CREAM = Color3.fromRGB(255, 248, 232)
local NAVY = Color3.fromRGB(28, 40, 72)
local OK = Color3.fromRGB(120, 236, 140)
local NO = Color3.fromRGB(255, 96, 86)

CarTags.RARITY_TEXT = table.freeze({
	Common = Color3.fromRGB(228, 230, 236),
	Rare = Color3.fromRGB(110, 184, 255),
	Epic = Color3.fromRGB(206, 140, 255),
	Legendary = Color3.fromRGB(255, 212, 70),
} :: { [RunConfig.Rarity]: Color3 })

export type TagInfo = {
	family: string,
	rarity: RunConfig.Rarity,
	size: RunConfig.Size,
	variant: RunConfig.Variant,
	odds: number,
	needs: number,
	owned: boolean,
}

local function text(parent: Instance, name: string, y: number, h: number, size: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, h)
	l.Position = UDim2.fromOffset(0, y)
	l.FontFace = Tokens.font()
	l.TextSize = size
	l.TextColor3 = colour
	l.TextStrokeColor3 = NAVY
	l.TextStrokeTransparency = 0
	l.Parent = parent
	return l
end

function CarTags.formatOdds(odds: number): string
	if odds >= 1e9 then
		return string.format("1 in %.1fB", odds / 1e9)
	elseif odds >= 1e6 then
		return string.format("1 in %.1fM", odds / 1e6)
	elseif odds >= 1e4 then
		return string.format("1 in %.1fK", odds / 1e3)
	end
	return string.format("1 in %d", odds)
end

function CarTags.title(info: TagInfo): string
	local variant = if info.variant ~= "None" then string.upper(info.variant) .. " " else ""
	return RunConfig.SIZE_LABEL[info.size] .. variant .. info.rarity .. " " .. info.family
end

function CarTags.attach(model: Model, info: TagInfo, height: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(220, 66)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 4.5, 0)
	gui.MaxDistance = 170
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local title = text(gui, "Title", 0, 24, 18, CarTags.RARITY_TEXT[info.rarity])
	title.Text = CarTags.title(info)
	local odds = text(gui, "Odds", 22, 20, 16, CREAM)
	odds.Text = CarTags.formatOdds(info.odds) .. (if info.owned then "  ·  owned" else "")
	text(gui, "Needs", 42, 22, 16, OK)
	gui.Adornee = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) :: any
	gui.Parent = model
	return gui
end

-- Colours "Needs N" green when the Rider Level is enough, red when it is not.
function CarTags.setLevel(gui: BillboardGui, needs: number, level: number)
	local label = gui:FindFirstChild("Needs")
	if label and label:IsA("TextLabel") then
		local ok = level >= needs
		label.Text = string.format("Needs %d  (you %d)", needs, level)
		label.TextColor3 = if ok then OK else NO
	end
end

export type RideMeter = {
	gui: BillboardGui,
	fill: Frame,
	label: TextLabel,
}

-- The catch meter floating over the rider: fills while the Keys are being earned.
function CarTags.rideMeter(parent: Instance): RideMeter
	local gui = Instance.new("BillboardGui")
	gui.Name = "RideMeter"
	gui.Size = UDim2.fromOffset(200, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Enabled = false
	local label = text(gui, "Label", 0, 22, 16, CREAM)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(20, 24)
	track.Size = UDim2.new(1, -40, 0, 14)
	track.BackgroundColor3 = NAVY
	track.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = track
	local stroke = Instance.new("UIStroke")
	stroke.Color = CREAM
	stroke.Thickness = 2
	stroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 120, 170)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = fill
	gui.Parent = parent
	return { gui = gui, fill = fill, label = label }
end

return CarTags
