--!strict
-- The one icon family of the game (Lane 3, Round 2 N5): original image icons, one key per meaning. Every
-- screen gets them by name through here, directly with GameIcons.image or by the old painter names, which
-- Icons2.draw sends here first, so no screen keeps its own copy of an icon.
--
-- Where an image comes from, best first:
--   1. its uploaded asset id (GameIconIds, filled in after the group upload);
--   2. a local preview: ReplicatedStorage.Lane3_IconPreview holds the pixels as modules in Adam's local test
--      places only (outside Git, Car-Hop-Art/review/round2/icons/preview), shown through an EditableImage;
--   3. nothing here: the caller falls back to the code-drawn art (Icons2), so a screen never shows a hole.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameIconIds = require(script.Parent.GameIconIds)

local GameIcons = {}

-- The old painter names, for the screens that still ask by name.
GameIcons.Painter = {
	Shop = "shop",
	Garage = "garage",
	Index = "index",
	Missions = "missions",
	Goals = "goals",
	Settings = "settings",
	Music = "music",
	Raceway = "raceway",
	Upgrade = "raceway",
	Parking = "parkingSpot",
	Paddock = "parkingSpot",
	Park = "parkingSpot",
	Trophy = "goals",
	Leaderboard = "leaderboard",
	StuntCircuit = "stuntCircuit",
	Portal = "portal",
	Lock = "lock",
	Padlock = "lock",
	Gift = "freeGift",
	Group = "group",
	Close = "close",
	Plus = "plus",
	Info = "info",
	Check = "check",
	Cash = "cash",
	CashBag = "cash",
	Earn = "cash",
	CashPerSecond = "cashPerSecond",
	CashChest = "bundle",
	CashVault = "bundle",
	Bundle = "bundle",
	Bolt = "stamina",
	Flame = "heat",
	Keys = "keys",
	Key = "keys",
	StarterPack = "starterPack",
	VipCrown = "vip",
	DoubleLapPay = "doubleLapPay",
	PaintBucket = "paint",
	Decal = "decal",
	Wheel = "wheel",
	Steer = "steer",
	Hop = "hop",
	Home = "home",
	Medal = "medal",
	Ready = "medal",
	Retry = "retry",
	Moon = "moon",
}

type Cached = { content: Content }
local previews: { [string]: Cached | false } = {}

local function hexValue(byte: number): number
	return if byte <= 57 then byte - 48 elseif byte >= 97 then byte - 87 else byte - 55
end

local function preview(key: string): Content?
	local cached = previews[key]
	if cached ~= nil then
		return if cached then cached.content else nil
	end
	previews[key] = false
	local folder = ReplicatedStorage:FindFirstChild("Lane3_IconPreview")
	local module = folder and folder:FindFirstChild(key)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, content = pcall(function(): Content
		local data = (require :: any)(module)
		local size = Vector2.new(data.w, data.h)
		local bytes = data.w * data.h * 4
		local pixels = buffer.create(bytes)
		local hex = data.hex
		for i = 0, bytes - 1 do
			local a, b = string.byte(hex, i * 2 + 1, i * 2 + 2)
			buffer.writeu8(pixels, i, hexValue(a :: number) * 16 + hexValue(b :: number))
		end
		local image = AssetService:CreateEditableImage({ Size = size })
		image:WritePixelsBuffer(Vector2.zero, size, pixels)
		return Content.fromObject(image)
	end)
	if not ok then
		warn("[GameIcons] preview of " .. key .. " failed: " .. tostring(content))
		return nil
	end
	previews[key] = { content = content }
	return content
end

-- True when `key` has real art here (an uploaded id or a local preview).
function GameIcons.has(key: string): boolean
	return GameIconIds[key] ~= nil or preview(key) ~= nil
end

local function apply(label: ImageLabel, key: string): boolean
	local id = GameIconIds[key]
	if id then
		label.Image = id
		return true
	end
	local content = preview(key)
	if content then
		label.ImageContent = content
		return true
	end
	return false
end

-- An ImageLabel of icon `key` under `parent`. `size` is pixels (a number) or a UDim2; the default fills the
-- parent. Returns nil when there is no art, so the caller can draw its fallback.
function GameIcons.image(parent: Instance, key: string, size: (number | UDim2)?, position: UDim2?): ImageLabel?
	local label = Instance.new("ImageLabel")
	label.Name = "Icon_" .. key
	label.BackgroundTransparency = 1
	label.ScaleType = Enum.ScaleType.Fit
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position or UDim2.fromScale(0.5, 0.5)
	label.Size = if type(size) == "number"
		then UDim2.fromOffset(size, size)
		elseif typeof(size) == "UDim2" then size
		else UDim2.fromScale(1, 1)
	if not apply(label, key) then
		label:Destroy()
		return nil
	end
	label.Parent = parent
	return label
end

-- Draws the icon for an old painter name into `holder`, as Icons2.draw would. False when there is no art.
function GameIcons.drawInto(holder: Frame, name: string): boolean
	local key = GameIcons.Painter[name]
	if not key then
		return false
	end
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art:SetAttribute("Icon", name)
	art:SetAttribute("IconSet", "GameIcons")
	if not GameIcons.image(art, key) then
		art:Destroy()
		return false
	end
	art.Parent = holder
	return true
end

return GameIcons
