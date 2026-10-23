--!strict
-- Parameterised world destination lettering (Lane 3 preview, HUD rebuild 2026-10-22, worker
-- HW; ledger W-01). Big glossy colour (or white) words with a dark outline and a controlled
-- depth layer, like a destination sign floating over the place it names. Test fixtures only;
-- written so a future island task could adopt it (W-04). No island change.
--
-- Choice: BillboardGui, not SurfaceGui. A destination word must read from every approach angle
-- (a SurfaceGui is unreadable edge-on and mirrored from behind); a billboard always faces the
-- camera. It is sized in pixels from the projected height of a real-size sign, clamped between
-- min and max screen bounds, so it behaves like a sign that shrinks with distance but never
-- becomes a speck (it holds the minimum size and fades out over the last 15% before
-- maxDistance) and never fills the screen up close (max bound).
--
-- Look: a face layer with a 3-stop gradient (light top "gloss", main colour, deep bottom), a
-- dark navy outline proportional to the size (about 7%), and ONE depth layer: the same word in
-- ink, offset down-right by about 6% (no blur, no grey drop shadow).
--
-- Occlusion policy: default `occluded = true` (AlwaysOnTop false): buildings, the destination
-- itself and anything else in front hide it, so it is never visible through the whole map;
-- MaxDistance = maxDistance is the hard backstop. Placement: the word's BOTTOM edge sits at
-- `verticalOffset` studs above the top of the destination's bounding box, so it never covers a
-- portal opening or doorway behind it (the billboard is twice the word's height with the word in
-- the top half, so its centre — the anchor — is the word's bottom edge).
-- Updates at 10 Hz and writes Size only when the 2 px size bucket changes.
--
--   local label = DestinationLabel.new(ctx, {
--       text = "DOWNTOWN", adornee = portalPart,
--       colours = { face = Color3, deep = Color3? } | preset = "Gold" | "Teal" | "Purple" | "Orange" | "White",
--       worldHeight = 5,        -- studs: the size of the "real" sign letters
--       minPx = 28, maxPx = 120, -- design px bounds (x the preview scale)
--       maxDistance = 400, occluded = true, verticalOffset = 3,
--   })
--   label:setText(text)  label:setAdornee(instance)
--   label:layout(), label:setVisible(on), label:destroy(), label:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local INK = PreviewTokens.Arcade.Ink
local TICK = 0.1
local FADE_FRACTION = 0.15
local OUTLINE = 0.07
local DEPTH = 0.06

export type Preset = "Gold" | "Teal" | "Purple" | "Orange" | "White" | "Green" | "Red"

-- TOKEN CANDIDATES: destination word colour presets (face, deep)
local PRESETS: { [string]: { face: Color3, deep: Color3 } } = {
	Gold = { face = Color3.fromRGB(255, 214, 60), deep = Color3.fromRGB(236, 140, 0) },
	Teal = { face = Color3.fromRGB(90, 236, 220), deep = Color3.fromRGB(0, 150, 150) },
	Purple = { face = Color3.fromRGB(210, 140, 255), deep = Color3.fromRGB(120, 50, 210) },
	Orange = { face = Color3.fromRGB(255, 170, 50), deep = Color3.fromRGB(235, 90, 10) },
	White = { face = Color3.fromRGB(255, 255, 255), deep = Color3.fromRGB(206, 218, 236) },
	Green = { face = Color3.fromRGB(140, 250, 110), deep = Color3.fromRGB(30, 170, 60) },
	Red = { face = Color3.fromRGB(255, 110, 100), deep = Color3.fromRGB(205, 30, 40) },
}

export type Params = {
	text: string,
	adornee: Instance?,
	preset: Preset?,
	colours: { face: Color3, deep: Color3? }?,
	worldHeight: number?,
	minPx: number?,
	maxPx: number?,
	maxDistance: number?,
	occluded: boolean?,
	verticalOffset: number?,
}

local DestinationLabel = {}
DestinationLabel.__index = DestinationLabel

local function makeText(parent: Instance, name: string, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Tokens.font()
	t.TextScaled = true
	t.TextWrapped = false
	t.TextColor3 = Color3.new(1, 1, 1)
	t.ZIndex = z
	t.Parent = parent
	return t
end

function DestinationLabel.new(ctx: WorldKit.Ctx, params: Params)
	local self = setmetatable({}, DestinationLabel)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._params = params
	self._worldHeight = params.worldHeight or 8 -- lead 2026-10-23: 5 read small in Studio
	self._minPx = math.max(params.minPx or 36, Tokens.TextSize.Minimum)
	self._maxPx = params.maxPx or 120
	self._maxDistance = params.maxDistance or 400
	self._offset = params.verticalOffset or 3
	self._px = 0
	self._alpha = -1
	self._acc = 0
	self._writes = 0
	self._dist = 0
	self._text = params.text
	self._anchorTop = 0
	local colours = params.colours
	local preset = PRESETS[params.preset or "Gold"] or PRESETS.Gold
	local face = if colours then colours.face else preset.face
	local deep = if colours then (colours.deep or colours.face:Lerp(Color3.new(0, 0, 0), 0.3)) else preset.deep

	local board = self._trove:Add(Instance.new("BillboardGui"))
	board.Name = "Destination_" .. params.text
	board.AlwaysOnTop = params.occluded == false
	board.LightInfluence = 0
	board.MaxDistance = self._maxDistance
	board.ResetOnSpawn = false
	board.ClipsDescendants = false
	board.Parent = ctx.world
	self._board = board
	local word = Instance.new("Frame")
	word.Name = "Word"
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromScale(1, 0.5) -- top half: the anchor is the word's bottom edge
	word.Parent = board
	local depth = makeText(word, "Depth", 1)
	depth.TextColor3 = INK
	local depthStroke = Instance.new("UIStroke")
	depthStroke.Color = INK
	depthStroke.LineJoinMode = Enum.LineJoinMode.Round
	depthStroke.Parent = depth
	local front = makeText(word, "Face", 2)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = front
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, face:Lerp(Color3.new(1, 1, 1), 0.55)),
		ColorSequenceKeypoint.new(0.42, face),
		ColorSequenceKeypoint.new(1, deep),
	})
	grad.Parent = front
	self._front, self._depth = front, depth
	self._stroke, self._depthStroke = stroke, depthStroke
	self:setText(params.text)
	self:setAdornee(params.adornee)

	self._trove:Connect(RunService.Heartbeat, function(dt: number)
		self._acc += dt
		if self._acc >= TICK then
			self._acc = 0
			self:_update()
		end
	end)
	self:_update()
	return self
end

export type DestinationLabel = typeof(DestinationLabel.new((nil :: any) :: WorldKit.Ctx, { text = "" }))

function DestinationLabel.setText(self: DestinationLabel, text: string)
	self._text = text
	self._front.Text = text
	self._depth.Text = text
	self._px = 0
end

function DestinationLabel.setAdornee(self: DestinationLabel, adornee: Instance?)
	local part = WorldKit.mainPart(adornee)
	self._board.Adornee = part
	self._anchorTop = 0
	if adornee and part then
		local box, size = WorldKit.box(adornee)
		self._anchorTop = box.Position.Y + size.Y / 2 - part.Position.Y
	end
	self._board.StudsOffsetWorldSpace = Vector3.new(0, self._anchorTop + self._offset, 0)
end

function DestinationLabel._update(self: DestinationLabel)
	local board = self._board
	local camera = Workspace.CurrentCamera
	local part = board.Adornee :: BasePart?
	if not camera or not part or not part.Parent or not self._visible then
		if board.Enabled then
			board.Enabled = false
		end
		return
	end
	local anchor = part.Position + board.StudsOffsetWorldSpace
	local dist = (anchor - camera.CFrame.Position).Magnitude
	self._dist = dist
	if dist > self._maxDistance then
		if board.Enabled then
			board.Enabled = false
		end
		return
	end
	-- projected pixel height of a real sign `worldHeight` studs tall at this distance
	local fov = math.rad(camera.FieldOfView)
	local projected = self._worldHeight * camera.ViewportSize.Y / (2 * math.max(dist, 1) * math.tan(fov / 2))
	local s = WorldKit.billboardScale(self._ctx)
	local px = math.clamp(projected, self._minPx * s, self._maxPx * s)
	px = math.floor(px / 2 + 0.5) * 2
	local fadeStart = self._maxDistance * (1 - FADE_FRACTION)
	local alpha = 1 - math.clamp((dist - fadeStart) / (self._maxDistance - fadeStart), 0, 1)
	alpha = WorldKit.quantise(alpha, 0.1)
	if px ~= self._px then
		self._px = px
		self._writes += 1
		local chars = math.max(#self._text, 1)
		local width = px * (0.62 * chars + 0.6)
		board.Size = UDim2.fromOffset(math.ceil(width), px * 2)
		local t = math.max(1, math.floor(px * OUTLINE + 0.5))
		self._stroke.Thickness = t
		self._depthStroke.Thickness = t
		local o = math.max(1, math.floor(px * DEPTH + 0.5))
		self._depth.Position = UDim2.fromOffset(o, o)
	end
	if alpha ~= self._alpha then
		self._alpha = alpha
		local tr = 1 - alpha
		self._front.TextTransparency = tr
		self._depth.TextTransparency = tr
		self._stroke.Transparency = tr
		self._depthStroke.Transparency = tr
	end
	if not board.Enabled then
		board.Enabled = true
	end
end

function DestinationLabel.layout(self: DestinationLabel)
	self._px = 0
	self:_update()
end

function DestinationLabel.setVisible(self: DestinationLabel, on: boolean)
	self._visible = on
	self:_update()
end

function DestinationLabel.getDebugState(self: DestinationLabel): { [string]: any }
	return {
		text = self._text,
		enabled = self._board.Enabled,
		px = self._px,
		alpha = self._alpha,
		distance = math.floor(self._dist),
		maxDistance = self._maxDistance,
		alwaysOnTop = self._board.AlwaysOnTop,
		sizeWrites = self._writes,
		bottomAboveTop = self._offset,
	}
end

function DestinationLabel.destroy(self: DestinationLabel)
	self._trove:Destroy()
end

return DestinationLabel
