--!strict
-- A filled circular sector (Lane 3 preview helper, worker H3), drawn without images: two
-- half-width clipping frames, each holding a full disc whose UIGradient has a hard transparency
-- step at 0.5. Rotating each gradient moves the edge of the visible half-disc; the clip keeps
-- one half each, so the right half covers 0..180 degrees and the left half 180..360.
-- Fraction 0..1 runs clockwise from 12 o'clock. Layer a smaller disc on top to make a ring.
--
--   local arc = Arc.new(parent, 64, colour, transparency?, z?)
--   arc:set(0.4)                 -- 40% sector
--   arc:setColor(c) / arc:setTransparency(t)
--   arc.root                     -- Frame, AnchorPoint 0.5, 0.5, size x size
--
-- Geometry: a UIGradient's Rotation turns it clockwise; with the step sequence the visible
-- region is "behind the axis" (projection < 0). Right disc rotation = clamp(360f, 0, 180),
-- left disc rotation = clamp(360f, 180, 360). Writing Rotation only (never rebuilding the
-- sequence) follows the creator-docs advice to animate Rotation / Offset rather than Color.

local Arc = {}
Arc.__index = Arc

local STEP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 1),
})

function Arc.new(parent: Instance, size: number, colour: Color3, transparency: number?, z: number?)
	local self = setmetatable({}, Arc)
	local zIndex = z or 2
	local root = Instance.new("Frame")
	root.Name = "Arc"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundTransparency = 1
	root.ZIndex = zIndex
	self.root = root
	self._discs = {} :: { Frame }
	self._grads = {} :: { UIGradient }
	for i, side in { "Right", "Left" } do
		local clip = Instance.new("Frame")
		clip.Name = side
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.5, 1)
		clip.Position = if side == "Right" then UDim2.fromScale(0.5, 0) else UDim2.new()
		clip.ZIndex = zIndex
		clip.Parent = root
		local disc = Instance.new("Frame")
		disc.Name = "Disc"
		disc.BorderSizePixel = 0
		disc.Size = UDim2.fromScale(2, 1)
		disc.Position = if side == "Right" then UDim2.fromScale(-1, 0) else UDim2.new()
		disc.BackgroundColor3 = colour
		disc.BackgroundTransparency = transparency or 0
		disc.ZIndex = zIndex
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = disc
		local grad = Instance.new("UIGradient")
		grad.Transparency = STEP
		grad.Parent = disc
		disc.Parent = clip
		self._discs[i] = disc
		self._grads[i] = grad
	end
	self._fraction = -1
	self:set(0)
	root.Parent = parent
	return self
end

export type Arc = typeof(Arc.new(Instance.new("Folder"), 1, Color3.new()))

function Arc.set(self: Arc, fraction: number)
	local f = math.clamp(if fraction ~= fraction then 0 else fraction, 0, 1)
	if f == self._fraction then
		return
	end
	self._fraction = f
	local angle = f * 360
	self.root.Visible = f > 0.002
	-- Right half: 0..180; left half: 180..360. At 100% both halves are full.
	self._grads[1].Rotation = math.clamp(angle, 0, 180)
	self._grads[2].Rotation = math.clamp(angle, 180, 360)
	self._discs[2].Visible = angle > 180
end

function Arc.get(self: Arc): number
	return math.max(self._fraction, 0)
end

function Arc.setColor(self: Arc, colour: Color3)
	for _, d in self._discs do
		d.BackgroundColor3 = colour
	end
end

function Arc.setTransparency(self: Arc, t: number)
	for _, d in self._discs do
		d.BackgroundTransparency = t
	end
end

function Arc.destroy(self: Arc)
	self.root:Destroy()
end

return Arc
