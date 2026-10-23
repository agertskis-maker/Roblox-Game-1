--!strict
-- One reused Highlight per world folder for the ridden car (Lane 3 preview, HUD rebuild
-- 2026-10-22, worker HW). Not a component. CaptureFx and WarnFx both write a LAYER here; the
-- highest layer that is set wins ("Warn" > "Capture"), so a capture outline is never stacked
-- on the warning tint: the warning wins and the capture outline comes back when it clears.
--
-- Why one Highlight: creating/removing a Highlight can trigger a geometry rebuild spike, while
-- changing its properties is lightweight; idle = Enabled false (docs: Highlight class/guide,
-- vault/design/research/capture-feedback.md section 4). The Highlight is parented to the
-- world folder and points at the car with Adornee, so the car model is never modified: its
-- materials, colours and variant finish stay exactly as they were.
--
--   local hl = CarHighlight.get(world)
--   hl:set("Capture", { adornee = model, outline = colour, outlineTransparency = 0.2 })
--   hl:set("Warn", { adornee = model, fill = red, fillTransparency = 0.7, outline = red })
--   hl:set("Capture", nil)          -- clears that layer
--   hl:active() -> "Warn" | "Capture" | nil
--   hl:release()                     -- each get() is paired with one release() on destroy

local CarHighlight = {}
CarHighlight.__index = CarHighlight

export type Layer = "Warn" | "Capture"

export type Spec = {
	adornee: Instance,
	outline: Color3,
	outlineTransparency: number, -- 0 opaque .. 1 hidden; callers cap intensity (>= 0.15)
	fill: Color3?,
	fillTransparency: number?, -- default 1 (outline only)
}

local ORDER: { Layer } = { "Warn", "Capture" }

local byWorld: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any

local function new(world: Instance)
	local self = setmetatable({}, CarHighlight)
	local h = Instance.new("Highlight")
	h.Name = "RiddenCarHighlight"
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Enabled = false
	h.Parent = world
	self.highlight = h
	self._layers = {} :: { [string]: Spec? }
	self._world = world
	self._users = 0
	return self
end

export type CarHighlight = typeof(new(Instance.new("Folder")))

-- Each user calls get() once and release() once (on destroy); the Highlight is destroyed when
-- the last user releases it.
function CarHighlight.get(world: Instance): CarHighlight
	local existing = byWorld[world]
	if existing and existing.highlight.Parent then
		existing._users += 1
		return existing
	end
	local created = new(world)
	created._users = 1
	byWorld[world] = created
	return created
end

function CarHighlight.release(self: CarHighlight)
	self._users -= 1
	if self._users <= 0 then
		if byWorld[self._world] == self then
			byWorld[self._world] = nil
		end
		self.highlight:Destroy()
	end
end

function CarHighlight.active(self: CarHighlight): Layer?
	for _, layer in ORDER do
		local spec = self._layers[layer]
		if spec and spec.adornee.Parent then
			return layer
		end
	end
	return nil
end

function CarHighlight._apply(self: CarHighlight)
	local h = self.highlight
	local layer = self:active()
	if not layer then
		h.Enabled = false
		h.Adornee = nil
		return
	end
	local spec = self._layers[layer] :: Spec
	if h.Adornee ~= spec.adornee then
		h.Adornee = spec.adornee
	end
	h.OutlineColor = spec.outline
	h.OutlineTransparency = math.clamp(spec.outlineTransparency, 0, 1)
	h.FillColor = spec.fill or spec.outline
	h.FillTransparency = math.clamp(spec.fillTransparency or 1, 0, 1)
	h.Enabled = true
end

function CarHighlight.set(self: CarHighlight, layer: Layer, spec: Spec?)
	self._layers[layer] = spec
	self:_apply()
end

function CarHighlight.layerSpec(self: CarHighlight, layer: Layer): Spec?
	return self._layers[layer]
end

function CarHighlight.debug(self: CarHighlight): { [string]: any }
	return {
		active = self:active(),
		enabled = self.highlight.Enabled,
		outlineTransparency = self.highlight.OutlineTransparency,
		fillTransparency = self.highlight.FillTransparency,
		highlights = 1,
	}
end

return CarHighlight
