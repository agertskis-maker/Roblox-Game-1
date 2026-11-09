--!strict
-- Headshot (Lane 3 Round 8, H-01; Adam: "it doesn't actually have your avatar, it just has an empty picture next to your name").
-- One place that puts a player's face in a round holder, for the plot badges (PlotOwners) and the RICHEST RACERS board.
--
-- What was wrong (found 2026-11-08, see Car-Hop-Art/review/round8/agents/ws7.md): PlotOwners asked Roblox for the face once per
-- UserId and, while that one request was still running, dropped every later request for the same id WITHOUT keeping its callback.
-- The server sets a plot's Owner and then its OwnerDisplayName, so the badge was built twice in a row; the second badge asked
-- for a face that was "already being fetched", got nothing back, and the first badge (the one the answer went to) had been
-- destroyed. The second badge sat on Roblox's grey GuiImagePlaceholder for ever. Here every caller keeps its own callback, the
-- answer goes to all of them, and an answer is only used if the caller still wants that player.
--
--   Headshot.attach(holder, userId, displayName, stillWanted?) -> () -> ()    fills `holder` (a round Frame) and returns a cancel
--   Headshot.content(userId) -> string      the client-side content string, rbxthumb://type=AvatarHeadShot&id=<id>&w=150&h=150
--   Headshot.isReal(userId) -> boolean      false for 0 and the negative ids of local Studio test players (they have no face)
--   Headshot.letter(name) -> string         the first letter, for the placeholder
--   Headshot.colour(userId) -> Color3       the placeholder's circle colour, one per player
--
-- How a face is found: (1) the rbxthumb content string, checked with ContentProvider:PreloadAsync; (2) if that fails,
-- Players:GetUserThumbnailAsync in a pcall (one bounded retry when Roblox says it is not ready yet); (3) otherwise a designed
-- placeholder stays: the player's first letter on a coloured circle in the game font, never an empty square. Answers are cached by
-- UserId (a failure is remembered for FAIL_COOLDOWN seconds so a broken service is not asked every frame).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Headshot = {}

local LOAD_SECONDS = 8 -- one try, then the next route
local NOT_READY_WAIT = 2 -- Roblox said "not ready": the one retry waits this long
local FAIL_COOLDOWN = 30

local NAVY = Color3.fromRGB(20, 33, 63)
-- placeholder circles: bright, kid-friendly, readable under navy letters
local CIRCLES = {
	Color3.fromRGB(255, 180, 75), -- orange
	Color3.fromRGB(110, 210, 140), -- green
	Color3.fromRGB(110, 175, 255), -- blue
	Color3.fromRGB(255, 140, 150), -- coral
	Color3.fromRGB(190, 150, 255), -- violet
	Color3.fromRGB(120, 215, 220), -- teal
}

type Cached = { content: string?, failedAt: number? }
local cache: { [number]: Cached } = {}
local waiting: { [number]: { (string?) -> () } } = {}

function Headshot.isReal(userId: number): boolean
	return userId > 0
end

function Headshot.content(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

function Headshot.letter(name: string): string
	if name == "" then
		return "?"
	end
	local ok, stop = pcall(utf8.offset, name, 2)
	local first = if ok and stop then string.sub(name, 1, stop - 1) else string.sub(name, 1, 1)
	return string.upper(first)
end

function Headshot.colour(userId: number): Color3
	return CIRCLES[(math.abs(userId) % #CIRCLES) + 1]
end

-- Loads `content` into a throw-away ImageLabel and says whether Roblox delivered it within LOAD_SECONDS.
local function loads(content: string): boolean
	local probe = Instance.new("ImageLabel")
	probe.Image = content
	local result: boolean? = nil
	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ probe }, function(_id: string, status: Enum.AssetFetchStatus)
				result = status == Enum.AssetFetchStatus.Success
			end)
		end)
		if not ok and result == nil then
			result = false
		end
		if result == nil then
			result = probe.IsLoaded
		end
	end)
	local t0 = os.clock()
	while result == nil and os.clock() - t0 < LOAD_SECONDS do
		task.wait(0.1)
	end
	local loaded = result == true
	probe:Destroy()
	return loaded
end

-- Finds the face of one player: the content string that loaded, or nil. Yields.
local function fetch(userId: number): string?
	if not Headshot.isReal(userId) then
		return nil
	end
	local direct = Headshot.content(userId)
	if loads(direct) then
		return direct
	end
	for attempt = 1, 2 do
		local ok, content, ready = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and type(content) == "string" and content ~= "" and ready ~= false and loads(content) then
			return content
		end
		if attempt == 1 then
			task.wait(NOT_READY_WAIT)
		end
	end
	return nil
end

-- `done(content)` runs (in its own thread) once the face of `userId` is known, `content` nil when there is none. Every caller
-- gets its answer, also when another caller asked first.
local function resolve(userId: number, done: (string?) -> ())
	local known = cache[userId]
	if known then
		if known.content then
			task.spawn(done, known.content)
			return
		end
		if known.failedAt and (not Headshot.isReal(userId) or os.clock() - known.failedAt < FAIL_COOLDOWN) then
			task.spawn(done, nil)
			return
		end
	end
	local list = waiting[userId]
	if list then
		table.insert(list, done)
		return
	end
	waiting[userId] = { done }
	task.spawn(function()
		local content = fetch(userId)
		cache[userId] = if content then { content = content } else { failedAt = os.clock() }
		local callbacks = waiting[userId] or {}
		waiting[userId] = nil
		for _, callback in callbacks do
			task.spawn(callback, content)
		end
	end)
end

-- Fills `holder` (a round Frame: the caller gives it the circle, its UICorner and any ring) with the placeholder, and swaps the
-- face in when it has loaded and `stillWanted()` (default: always) still says this player is the one to show. Returns a cancel.
function Headshot.attach(
	holder: GuiObject,
	userId: number,
	displayName: string,
	stillWanted: (() -> boolean)?
): () -> ()
	local circle = Instance.new("Frame")
	circle.Name = "Placeholder"
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundColor3 = Headshot.colour(userId)
	circle.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = circle
	local letter = Instance.new("TextLabel")
	letter.Name = "Letter"
	letter.BackgroundTransparency = 1
	letter.AnchorPoint = Vector2.new(0.5, 0.5)
	letter.Position = UDim2.fromScale(0.5, 0.5)
	letter.Size = UDim2.fromScale(0.7, 0.7)
	letter.FontFace = Tokens.font()
	letter.Text = Headshot.letter(displayName)
	letter.TextColor3 = NAVY
	letter.TextScaled = true
	letter.Parent = circle
	circle.Parent = holder

	local face = Instance.new("ImageLabel")
	face.Name = "Headshot"
	face.BackgroundTransparency = 1
	face.Size = UDim2.fromScale(1, 1)
	face.ScaleType = Enum.ScaleType.Crop
	face.Visible = false
	local faceRound = Instance.new("UICorner")
	faceRound.CornerRadius = UDim.new(1, 0)
	faceRound.Parent = face
	face.Parent = holder

	local cancelled = false
	if Headshot.isReal(userId) then
		resolve(userId, function(content: string?)
			if cancelled or not face.Parent or not content then
				return
			end
			if stillWanted and not stillWanted() then
				return -- the plot or the row changed hands while the face was on its way
			end
			face.Image = content
			face.Visible = true
			circle.Visible = false
		end)
	end
	return function()
		cancelled = true
	end
end

return Headshot
