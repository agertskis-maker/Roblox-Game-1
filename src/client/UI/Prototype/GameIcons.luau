--!strict
-- The one icon family of the game (Lane 3, Round 2 N5): original image icons, one key per meaning. Every
-- screen gets them by name through here, directly with GameIcons.image or by the old painter names, which
-- Icons2.draw sends here first, so no screen keeps its own copy of an icon.
--
-- Where an image comes from, best first:
--   1. its uploaded asset id (GameIconIds, filled in after the one group upload);
--   2. a local file: only where ReplicatedStorage.Lane3_LocalArt exists (Adam's local test places, never the game), Studio
--      reads rbxasset://carhop/<key>.png from its own content folder (Car-Hop-Art/review/round3/art/install-local-art.ps1).
--      These load and mip like real uploads, unlike the 96 px EditableImage previews of Round 2, which were the blur;
--   3. nothing here: the caller falls back to the code-drawn art (Icons2), so a screen never shows a hole.
--
-- Art and icons share this one table of keys. GameIcons.preload fetches a list up front, and a local file that fails is
-- remembered as missing, so a Studio update that empties the content folder falls back instead of showing blanks.

local ContentProvider = game:GetService("ContentProvider")
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
	Trail = "trail",
}

-- What the Shop and the HUD show first: fetched at join, so nothing appears half loaded.
GameIcons.Common = {
	"shop",
	"garage",
	"missions",
	"settings",
	"cash",
	"plus",
	"close",
	"stamina",
	"vip",
	"leaderboard",
	"portal",
	"art_starter",
	"art_vip",
	"art_doublelap",
	"art_paddock",
	"art_bundle",
	"art_cash1",
	"art_cash2",
	"art_cash3",
	"art_cash4",
	"art_cash5",
	"art_trail",
	"art_gift",
	"stamp_seal",
	"fx_flag",
	"fx_glow",
	"fx_checker",
	"fx_speed",
	"fx_rays",
	"fx_chevron",
	"fx_stripes",
	"fx_tread",
	"fx_halftone",
	"item_stripe",
	"decal",
}

-- Keys drawn once and shown under two names.
GameIcons.Alias = {
	doubleLapPay = "art_doublelap",
	bundle = "art_bundle",
	cross = "close",
	-- Round 5 (S-01): the three pass cards no longer show a car (two reviewers read a car as "included"). Their new art is
	-- cut from R5-IMG-03 (Car-Hop-Art/review/round5/art): a gift with a Rare-gem key, a crown, three parking spots.
	starterPack = "art_pass_starter",
	art_starter = "art_pass_starter",
	-- VIP: the game's own transparent crown icon reads cleaner on the gold card than the reference tile's lounge square
	art_vip = "vip",
	art_paddock = "art_pass_paddock",
}

-- Art not uploaded yet (no id in GameIconIds) shows this uploaded icon instead outside Adam's local test places, never a car.
GameIcons.Fallback = {
	art_pass_starter = "art_gift",
	art_pass_vip = "vip",
	art_pass_paddock = "parkingSpot",
} :: { [string]: string }

local missing: { [string]: boolean } = {}

local function resolve(key: string): string
	return GameIcons.Alias[key] or key
end

-- The image address of `key` here, or nil when there is no art.
function GameIcons.uri(key: string): string?
	local k = resolve(key)
	local id = GameIconIds[k]
	if id then
		return id
	end
	if not missing[k] and ReplicatedStorage:FindFirstChild("Lane3_LocalArt") then
		return "rbxasset://carhop/" .. k .. ".png"
	end
	local fallback = GameIcons.Fallback[k]
	if fallback then
		return GameIconIds[fallback]
	end
	return nil
end

-- True when `key` has real art here.
function GameIcons.has(key: string): boolean
	return GameIcons.uri(key) ~= nil
end

-- Fetches images up front (yields). A local file that fails is marked missing. Returns how many loaded and how many failed.
function GameIcons.preload(keys: { string }, onStep: ((done: number, total: number) -> ())?): (number, number)
	local byUri: { [string]: string } = {}
	local uris: { string } = {}
	-- Labels, not bare strings: a bare rbxassetid string has no asset type, so an uploaded Image fails where a local file doesn't.
	local labels: { ImageLabel } = {}
	for _, key in keys do
		local uri = GameIcons.uri(key)
		if uri and not byUri[uri] then
			byUri[uri] = resolve(key)
			table.insert(uris, uri)
			local label = Instance.new("ImageLabel")
			label.Image = uri
			table.insert(labels, label)
		end
	end
	local done, failed = 0, 0
	local ok = pcall(function()
		ContentProvider:PreloadAsync(labels, function(uri: string, status: Enum.AssetFetchStatus)
			done += 1
			if status ~= Enum.AssetFetchStatus.Success then
				failed += 1
				local key = byUri[uri]
				if key and not GameIconIds[key] then
					missing[key] = true
				end
			end
			if onStep then
				onStep(done, #uris)
			end
		end)
	end)
	for _, label in labels do
		label:Destroy()
	end
	if not ok then
		warn("[GameIcons] preload failed")
	end
	return done - failed, failed
end

local function apply(label: ImageLabel, key: string): boolean
	local uri = GameIcons.uri(key)
	if uri then
		label.Image = uri
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
