--!strict
-- The next-level preview on the Paddock kiosk's upgrade board (Lane 3, client presentation
-- only): the current level, the next level's name, a small picture of what it adds (the next
-- level's main piece, drawn in a ViewportFrame) and a price placeholder marked PREVIEW (prices
-- are Lane 2's; no amount is shown). At the top level the board shows a completed state instead
-- of an invalid next level. Spec: vault/design/ui/speedway-upgrade-board.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Speedway = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("Speedway")
local Ladder = require(Speedway:WaitForChild("Ladder"))
local Look = require(Speedway:WaitForChild("Look"))
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Kiosk = {}

local CREAM = Color3.fromRGB(255, 246, 224)
local INK = Color3.fromRGB(20, 27, 51)
local YELLOW = Color3.fromRGB(250, 206, 70)
local MINT = Color3.fromRGB(128, 216, 189)

local function text(parent: Instance, value: string, y: number, h: number, size: number, colour: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.05, y)
	t.Size = UDim2.fromScale(0.9, h)
	t.FontFace = Tokens.font()
	t.Text = value
	-- scaled to fit the small board (a long level name shrinks instead of being cut), up to `size`
	t.TextScaled = true
	t.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = t
	t.TextColor3 = colour
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = math.max(1, math.floor(size / 14))
	s.Parent = t
	t.Parent = parent
	return t
end

-- A picture of the next level's main piece: its Major parts, framed by a camera.
local function picture(parent: Instance, plot: Model, level: number, options: Look.Options)
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Picture"
	frame.Position = UDim2.fromScale(0.08, 0.36)
	frame.Size = UDim2.fromScale(0.84, 0.36)
	frame.BackgroundColor3 = Color3.fromRGB(176, 218, 232)
	frame.BorderSizePixel = 0
	frame.Ambient = Color3.fromRGB(200, 200, 200)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-1, -2, -1)
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	-- build the piece away from the plot, then move it into the viewport
	local ghost = Look.signaturePiece(plot, level, options)
	if not ghost then
		return
	end
	for _, d in ghost:GetDescendants() do
		if d:IsA("SurfaceGui") or d:IsA("Beam") or d:IsA("Light") then
			d:Destroy()
		end
	end
	local model = Instance.new("Model")
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 0
			d.Color = Color3.fromRGB(244, 236, 214)
			local half = d.Size / 2
			lo = lo:Min(d.Position - half)
			hi = hi:Max(d.Position + half)
		end
	end
	ghost.Parent = model
	model.Parent = frame
	local cam = Instance.new("Camera")
	local centre = (lo + hi) / 2
	local radius = math.max(4, (hi - lo).Magnitude / 2)
	-- a three-quarter view from the plot's track centre (the side the pieces face), a little above
	local trackCentre = CFrame.Angles(0, -math.rad(options.bearing), 0) * Vector3.new(0, 0, -441)
	local toward = (trackCentre - centre) * Vector3.new(1, 0, 1)
	toward = if toward.Magnitude > 1e-3 then toward.Unit else Vector3.new(0, 0, 1)
	toward = (CFrame.Angles(0, math.rad(35), 0) * toward).Unit
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(centre + toward * radius * 1.9 + Vector3.yAxis * radius * 0.8, centre)
	cam.Parent = frame
	frame.CurrentCamera = cam
end

-- Fills the plot's kiosk board for `level`.
function Kiosk.fill(plot: Model, level: number, options: Look.Options)
	local root = plot:FindFirstChild("SpeedwayLook")
	if not root then
		return
	end
	local face: BasePart? = nil
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("KioskBoard") then
			face = d
			break
		end
	end
	if not face then
		return
	end
	-- The board's SurfaceGui lives in PlayerGui, adorned to the face: a ViewportFrame on a SurfaceGui
	-- parented in the Workspace does not draw (found in a Studio playtest, 2026-10-28). It goes
	-- when the face does.
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
		made.PixelsPerStud = if inWorld then inWorld.PixelsPerStud else 50
		made.LightInfluence = 1
		made.MaxDistance = 400
		made.ResetOnSpawn = false
		made.Parent = playerGui
		existing = made
	end
	local board = existing :: SurfaceGui
	board.Adornee = face
	board:ClearAllChildren()
	if inWorld then
		inWorld:Destroy()
	end
	face.Destroying:Once(function()
		if board.Adornee == face or board.Adornee == nil then
			board:Destroy()
		end
	end)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(36, 58, 98)
	bg.BorderSizePixel = 0
	bg.Parent = board
	local current = Ladder.get(level)
	text(bg, "SPEEDWAY LEVEL " .. current.level, 0.03, 0.09, 26, YELLOW)
	text(bg, current.name, 0.12, 0.08, 20, CREAM)
	if current.level >= Ladder.MaxLevel then
		text(bg, "TOP LEVEL!", 0.26, 0.09, 30, YELLOW)
		text(bg, "Every look is built.", 0.4, 0.1, 20, CREAM)
		text(bg, "PREVIEW", 0.86, 0.08, 18, MINT)
		return
	end
	local nextLevel = Ladder.get(current.level + 1)
	text(bg, "NEXT: " .. string.upper(nextLevel.name), 0.22, 0.12, 22, CREAM)
	picture(bg, plot, nextLevel.level, options)
	text(bg, nextLevel.adds, 0.73, 0.1, 17, CREAM)
	local price = text(bg, "PRICE: PREVIEW", 0.85, 0.09, 20, MINT)
	price.Name = "PricePlaceholder"
end

return Kiosk
