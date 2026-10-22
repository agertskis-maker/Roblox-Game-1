--!strict
-- Foot Dash indicator for the run view (Lane 3 preview, worker H3). Display only: it shows
-- store.run.dash (remaining 0..1 while a Foot Dash runs, nil otherwise) as supplied and changes
-- no rule. A sneaker icon on a cream disc inside a draining white arc, with a "DASH" cue.
-- Optional mild edge desaturation: a very light grey tint on the screen edges only while a dash
-- runs (8% of the width each side, 10% of the height top and bottom, at most 12% opacity at the
-- very edge); none in reduced motion. Placement: RunLayout.dashRect (clear of the landing view,
-- Keys, Hop, the Heat panel and the touch zones).
--
--   local dash = FootDash.new(ctx)
--   dash:setEdgeEffect(on)    -- default on
--   dash:layout(), dash:setVisible(on), dash:destroy(), dash:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arc = require(script.Parent.Arc)
local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

local RING = 64
local INNER = 46
local EDGE_ALPHA = 0.12

local FootDash = {}
FootDash.__index = FootDash

function FootDash.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, FootDash)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._edgeEnabled = true
	self._active = false
	self._dash = 0
	self._starts = 0
	self._token = 0
	self._rect = nil :: RunLayout.Rect?
	self._conflict = nil :: string?

	local root = self._trove:Add(RunLayout.canvas(ctx, "FootDash"))
	self.root = root

	-- edge desaturation (under the indicator)
	local edge = make("Frame", {
		Name = "DashEdge",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Parent = root,
	})
	edge.Active = false
	self._edge = edge
	self._strips = {} :: { Frame }
	for _, spec in
		{
			{ "Left", UDim2.fromScale(0.08, 1), UDim2.new(), 0 },
			{ "Right", UDim2.fromScale(0.08, 1), UDim2.fromScale(0.92, 0), 180 },
			{ "Top", UDim2.fromScale(1, 0.1), UDim2.new(), 90 },
			{ "Bottom", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.9), 270 },
		}
	do
		local strip = make("Frame", {
			Name = spec[1],
			Size = spec[2],
			Position = spec[3],
			BackgroundColor3 = Color3.fromRGB(200, 204, 214),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = edge,
		})
		make("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = spec[4], Parent = strip })
		table.insert(self._strips, strip)
	end

	local group = make("CanvasGroup", {
		Name = "Dash",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(RunLayout.DashSize.X, RunLayout.DashSize.Y),
		ZIndex = 2,
		Parent = root,
	})
	self._group = group
	local ring = make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(RING, RING),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = group,
	})
	Gloss.corner(ring, RING / 2)
	Gloss.stroke(ring, 3, C.Ink)
	local arc = Arc.new(ring, RING, C.White, 0, 3)
	self._arc = arc
	local inner = make("Frame", {
		Name = "Centre",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(INNER, INNER),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = ring,
	})
	Gloss.corner(inner, INNER / 2)
	Gloss.stroke(inner, 2.5, C.Ink)
	local icon = make("Frame", {
		Name = "Sneaker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = inner,
	})
	Icons.draw(icon, "Sneaker", C.PrimaryDeep)
	local cue = make("TextLabel", {
		Name = "Cue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "DASH",
		TextSize = Tokens.TextSize.Label,
		TextColor3 = C.White,
		ZIndex = 6,
		Parent = group,
	})
	Gloss.stroke(cue, 2.5, C.Ink, Enum.ApplyStrokeMode.Contextual)
	self._cue = cue

	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(group)
		for _, s in self._strips do
			Motion.cancelAll(s)
		end
	end)
	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_applyEdge(true)
	end))
	self:layout()
	self:_apply()
	return self
end

export type FootDash = typeof(FootDash.new((nil :: any) :: RunLayout.Ctx))

function FootDash._applyEdge(self: FootDash, instant: boolean)
	local on = self._active and self._edgeEnabled and not Motion.reduced()
	local target = if on then 1 - EDGE_ALPHA else 1
	self._edge.Visible = on or not instant
	for _, s in self._strips do
		if instant then
			Motion.cancelAll(s)
			s.BackgroundTransparency = target
		else
			Motion.tween(s, "edge", Motion.info(0.3), { BackgroundTransparency = target })
		end
	end
	if not on and instant then
		self._edge.Visible = false
	end
end

function FootDash._apply(self: FootDash)
	local run = self._ctx.store:get().run
	local dash = if run then run.dash else nil
	local group = self._group
	if dash == nil then
		if self._active then
			self._active = false
			self._token += 1
			local token = self._token
			local t = Motion.tween(group, "fade", Motion.info(0.2), { GroupTransparency = 1 })
			t.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and token == self._token then
					group.Visible = false
				end
			end)
			self:_applyEdge(false)
		end
		return
	end
	local d = math.clamp(dash :: number, 0, 1)
	self._dash = d
	self._arc:set(d)
	if not self._active then
		self._active = true
		self._starts += 1
		self._token += 1
		Sounds.play("Dash")
		group.Visible = true
		Motion.tween(group, "fade", Motion.info(if Motion.reduced() then 0.1 else 0.15), { GroupTransparency = 0 })
		self:_applyEdge(Motion.reduced())
	end
end

function FootDash.layout(self: FootDash)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect, conflict = RunLayout.dashRect(ctx)
	self._rect = rect
	self._conflict = conflict
	RunLayout.place(self._group, rect)
end

function FootDash.setEdgeEffect(self: FootDash, on: boolean)
	self._edgeEnabled = on
	self:_applyEdge(true)
end

function FootDash.setVisible(self: FootDash, on: boolean)
	self._visible = on
	self.root.Visible = on
end

function FootDash.getDebugState(self: FootDash): { [string]: any }
	local rect = self._rect
	return {
		visible = self._visible,
		active = self._active,
		dash = self._dash,
		arc = self._arc:get(),
		cue = self._cue.Text,
		starts = self._starts,
		edgeEnabled = self._edgeEnabled,
		edgeAlpha = 1 - self._strips[1].BackgroundTransparency,
		box = rect and RunLayout.describe(rect),
		conflict = self._conflict,
		overlapsLandingView = rect ~= nil and RunLayout.overlaps(rect, RunLayout.landingBand(self._ctx)),
	}
end

function FootDash.destroy(self: FootDash)
	self._trove:Destroy()
end

return FootDash
