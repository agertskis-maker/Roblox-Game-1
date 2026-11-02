--!strict
-- Home/HomeWorld: the in-world pieces of the Round 2 Home HUD (Lane 3, N7-01, 2026-11-02), each a small reusable thing that
-- shows ONLY what the caller says is real:
--
--   world:setTrail(points?)                    a chevron trail along a polyline of Vector3 to ONE target (Home/TutorialRoute:
--                                              pooled white chevrons, nothing is pathfound here); nil or < 2 points clears it
--   world:setBubble(id, target, kind?, height?) an UNLOCK! / OPEN! bubble over a portal (kind "Unlock" | "Open"; nil removes
--                                              it). The caller decides eligibility: OPEN! is never drawn for a locked portal.
--                                              A bubble bobs gently (still in reduced motion) and sounds once when it appears.
--   world:floatCash(at, amount)                a "+$1,250" label rising from a Vector3 or a BasePart (pool of 4, never one
--   world:float(at, text)                      per event; combined when full). float() takes any short text.
--   world:setRate(id, target, rate?)           a persistent "$18.9K/s" label over an earning sign; nil removes it. Real rates only
--   world:setCircle(id, position, diameter, colour?, active?)   a ground circle at an interactive spot (Prototype/World/GroundMarker);
--                                              world:removeCircle(id)
--   world:layout()  world:setVisible(on)  world:getDebugState()  world:destroy()
--
-- Everything is local to this client: anchored, non-colliding, non-queryable parts and BillboardGuis in one Folder (the
-- `folder` option, or a new one in Workspace). Billboards size from HomeView:billboardScale(), so they match the HUD at every
-- screen size. Reduced motion: no rise, no bob; labels hold and fade in place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arcade = require(script.Parent.Parent.Arcade)
local Fade = require(script.Parent.Fade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local GroundMarker = require(script.Parent.Parent.World.GroundMarker)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TutorialRoute = require(script.Parent.TutorialRoute)

local make = Arcade.make
local A = PreviewTokens.Arcade

local FLOAT_POOL = 4
local FLOAT_RISE = 3.5 -- studs
local FLOAT_SECONDS = 1.1
local FLOAT_RANGE = 140
local BUBBLE_RANGE = 160
local MAX_CIRCLES = 8
local MAX_BUBBLES = 4
local MAX_RATES = 4

export type Options = {
	folder: Folder?, -- where the world pieces live (default: a new Folder in Workspace)
	view: { billboardScale: (any) -> number }?, -- HomeView: design px to real px for billboards
}

export type World = {
	setTrail: (self: World, points: { Vector3 }?) -> (),
	setBubble: (self: World, id: string, target: Instance?, kind: string?, height: number?) -> (),
	floatCash: (self: World, at: Vector3 | BasePart, amount: number) -> (),
	float: (self: World, at: Vector3 | BasePart, text: string) -> (),
	setRate: (self: World, id: string, target: Instance?, rate: number?) -> (),
	setCircle: (
		self: World,
		id: string,
		position: Vector3,
		diameter: number,
		colour: Color3?,
		active: boolean?
	) -> (),
	removeCircle: (self: World, id: string) -> (),
	layout: (self: World) -> (),
	setVisible: (self: World, on: boolean) -> (),
	getDebugState: (self: World) -> { [string]: any },
	destroy: (self: World) -> (),
}

local HomeWorld = {}
HomeWorld.__index = HomeWorld

-- The thing a billboard attaches to, and how high above it the label should sit.
local function adorneeFor(target: Instance): (Instance?, number)
	if target:IsA("BasePart") then
		return target, (target :: BasePart).Size.Y / 2 + 2
	elseif target:IsA("Attachment") then
		return target, 2
	elseif target:IsA("Model") then
		local model = target :: Model
		local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		local _, size = model:GetBoundingBox()
		return part, size.Y / 2 + 2
	end
	return nil, 2
end

local function newBoard(parent: Instance, name: string, size: Vector2, range: number): (BillboardGui, UIScale, Frame)
	local board = make("BillboardGui", {
		Name = name,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = range,
		Size = UDim2.fromOffset(size.X, size.Y),
		Enabled = false,
		ResetOnSpawn = false,
		Parent = parent,
	})
	local holder = make("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = board,
	})
	local scale = make("UIScale", { Name = "HudScale", Scale = 1, Parent = holder })
	return board, scale, holder
end

function HomeWorld.new(options: Options?): World
	local self = setmetatable({}, HomeWorld) :: any
	local opts: Options = options or {}
	self._trove = Trove.new()
	self._view = opts.view
	self._visible = true
	self._threads = {} :: { [thread]: boolean }
	local folder: Folder
	if opts.folder then
		folder = self._trove:Add(make("Folder", { Name = "HomeWorld", Parent = opts.folder }))
	else
		folder = self._trove:Add(make("Folder", { Name = "HomeHudWorld", Parent = Workspace }))
	end
	self._folder = folder
	-- the chevron trail reuses the tutorial's pooled route; it only needs ctx.world
	self._route = TutorialRoute.new({ world = folder } :: any)
	self._trove:Add(function()
		self._route:destroy()
		for thread in self._threads do
			pcall(task.cancel, thread)
		end
		table.clear(self._threads)
	end)
	self._bubbles = {} :: { [string]: any }
	self._rates = {} :: { [string]: any }
	self._circles = {} :: { [string]: any }
	self._floats = {} :: { any }
	self._floatNext = 1
	self._floatCount = 0
	for i = 1, FLOAT_POOL do
		local anchor = make("Part", {
			Name = "FloatAnchor" .. i,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			Parent = folder,
		})
		local board, scale, holder = newBoard(folder, "Float" .. i, Vector2.new(190, 56), FLOAT_RANGE)
		local text = Arcade.text(holder, {
			text = "",
			role = "Value",
			name = "Amount",
			size = 34,
			face = "Cash",
			italic = true,
			outline = "Major",
		})
		text.Size = UDim2.fromScale(1, 1)
		table.insert(self._floats, {
			board = board,
			scale = scale,
			anchor = anchor,
			text = text,
			fade = Fade.capture(text),
			token = 0,
			busy = false,
		})
	end
	self._trove:Add(function()
		for _, f in self._floats do
			f.token += 1
			f.fade:destroy()
			Motion.cancelAll(f.board)
		end
	end)
	self:layout()
	return self :: World
end

function HomeWorld._billboardScale(self: any): number
	local view = self._view
	if view then
		return view:billboardScale()
	end
	return 1
end

function HomeWorld.layout(self: any)
	local s = self:_billboardScale()
	for _, f in self._floats do
		f.scale.Scale = s
	end
	for _, b in self._bubbles do
		b.scale.Scale = s
	end
	for _, r in self._rates do
		r.scale.Scale = s
	end
end

-- TRAIL -------------------------------------------------------------------------------------------------------------

function HomeWorld.setTrail(self: any, points: { Vector3 }?)
	self._route:setRoute(points)
end

-- BUBBLES -----------------------------------------------------------------------------------------------------------

function HomeWorld.setBubble(self: any, id: string, target: Instance?, kind: string?, height: number?)
	local existing = self._bubbles[id]
	if target == nil or kind == nil then
		if existing then
			existing.trove:Destroy()
			self._bubbles[id] = nil
		end
		return
	end
	local adornee, autoHeight = adorneeFor(target)
	if not adornee then
		return
	end
	local want = if kind == "Open" then "Open" else "Unlock"
	if existing and existing.kind == want and existing.adornee == adornee then
		existing.board.StudsOffsetWorldSpace = Vector3.new(0, height or autoHeight, 0)
		return
	end
	if existing then
		existing.trove:Destroy()
		self._bubbles[id] = nil
	elseif next(self._bubbles) ~= nil then
		local count = 0
		for _ in self._bubbles do
			count += 1
		end
		if count >= MAX_BUBBLES then
			return
		end
	end
	local trove = Trove.new()
	local board, scale, holder = newBoard(self._folder, "Bubble_" .. id, Vector2.new(190, 96), BUBBLE_RANGE)
	trove:Add(board)
	board.Adornee = adornee
	board.StudsOffsetWorldSpace = Vector3.new(0, height or autoHeight, 0)
	board.Enabled = self._visible
	scale.Scale = self:_billboardScale()
	-- the bob lives on an inner frame so the billboard itself stays put
	local bob = make("Frame", {
		Name = "Bob",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	local bubble = make("Frame", {
		Name = "Bubble",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(176, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = bob,
	})
	Arcade.corner(bubble, 14)
	Arcade.outline(bubble, "Button")
	local fills: any = if want == "Open" then A.Fill.Green else PreviewTokens.Shop.Fill.Violet
	make("UIGradient", { Color = fills, Rotation = 90, Parent = bubble })
	Arcade.gloss(bubble)
	local word = Arcade.text(bubble, {
		text = if want == "Open" then "OPEN!" else "UNLOCK!",
		role = "Button",
		name = "Word",
		size = 30,
		z = 5,
	})
	word.Size = UDim2.fromScale(1, 1)
	-- the arrow: a gold diamond tucked under the bubble, pointing down at the portal
	local arrow = make("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(26, 26),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(255, 206, 40),
		ZIndex = 2,
		Parent = bob,
	})
	Arcade.corner(arrow, 4)
	Arcade.outline(arrow, "Minor")
	trove:Add(function()
		Motion.cancelAll(bob)
	end)
	local entry = { trove = trove, board = board, scale = scale, bob = bob, kind = want, adornee = adornee, id = id }
	self._bubbles[id] = entry
	self:_bob(entry)
	trove:Add(Motion.onReducedChanged(function()
		self:_bob(entry)
	end))
	Sounds.play("Unlock")
end

function HomeWorld._bob(_self: any, entry: any)
	Motion.cancelAll(entry.bob)
	entry.bob.Position = UDim2.new()
	if Motion.reduced() then
		return
	end
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	Motion.tween(entry.bob, "bob", info, { Position = UDim2.fromOffset(0, 6) })
end

-- FLOATING LABELS ---------------------------------------------------------------------------------------------------

function HomeWorld.float(self: any, at: Vector3 | BasePart, text: string)
	if not self._visible or type(text) ~= "string" or text == "" then
		return
	end
	local camera = Workspace.CurrentCamera
	local position: Vector3 = if typeof(at) == "Vector3" then at :: Vector3 else (at :: BasePart).Position
	if camera and (camera.CFrame.Position - position).Magnitude > FLOAT_RANGE then
		return -- nothing far away is even allocated
	end
	-- the next free label, else the oldest (its text is replaced, never a fifth one)
	local entry: any = nil
	for _, f in self._floats do
		if not f.busy then
			entry = f
			break
		end
	end
	if not entry then
		entry = self._floats[self._floatNext]
		self._floatNext = self._floatNext % FLOAT_POOL + 1
	end
	entry.token += 1
	local token: number = entry.token
	entry.busy = true
	entry.text.Text = text
	entry.anchor.Position = position
	entry.board.Adornee = entry.anchor
	entry.board.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	entry.board.Enabled = true
	entry.fade:set(0)
	Motion.cancelAll(entry.board)
	if not Motion.reduced() then
		Motion.tween(entry.board, "rise", Motion.info(FLOAT_SECONDS), {
			StudsOffsetWorldSpace = Vector3.new(0, 2 + FLOAT_RISE, 0),
		})
	end
	local thread = task.delay(FLOAT_SECONDS * 0.55, function()
		self._threads[coroutine.running()] = nil
		if self._destroyed or token ~= entry.token then
			return
		end
		entry.fade:tween(1, FLOAT_SECONDS * 0.45)
		local done = task.delay(FLOAT_SECONDS * 0.45 + 0.05, function()
			self._threads[coroutine.running()] = nil
			if self._destroyed or token ~= entry.token then
				return
			end
			entry.board.Enabled = false
			entry.busy = false
		end)
		self._threads[done] = true
	end)
	self._threads[thread] = true
	self._floatCount += 1
end

function HomeWorld.floatCash(self: any, at: Vector3 | BasePart, amount: number)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	self:float(at, "+" .. Format.cash(amount))
end

-- RATE LABELS -------------------------------------------------------------------------------------------------------

function HomeWorld.setRate(self: any, id: string, target: Instance?, rate: number?)
	local existing = self._rates[id]
	if target == nil or type(rate) ~= "number" or rate ~= rate or rate <= 0 then
		if existing then
			existing.trove:Destroy()
			self._rates[id] = nil
		end
		return
	end
	local adornee, height = adorneeFor(target)
	if not adornee then
		return
	end
	local text = Format.cash(rate) .. "/s"
	if existing then
		existing.text.Text = text
		existing.board.Adornee = adornee
		existing.board.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		return
	end
	local count = 0
	for _ in self._rates do
		count += 1
	end
	if count >= MAX_RATES then
		return
	end
	local trove = Trove.new()
	local board, scale, holder = newBoard(self._folder, "Rate_" .. id, Vector2.new(190, 48), BUBBLE_RANGE)
	trove:Add(board)
	board.Adornee = adornee
	board.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	board.Enabled = self._visible
	scale.Scale = self:_billboardScale()
	local label = Arcade.text(holder, {
		text = text,
		role = "Value",
		name = "Rate",
		size = Tokens.TextSize.Value,
		face = "Cash",
		italic = true,
		outline = "Major",
	})
	label.Size = UDim2.fromScale(1, 1)
	self._rates[id] = { trove = trove, board = board, scale = scale, text = label }
end

-- GROUND CIRCLES ----------------------------------------------------------------------------------------------------

function HomeWorld.setCircle(
	self: any,
	id: string,
	position: Vector3,
	diameter: number,
	colour: Color3?,
	active: boolean?
)
	local existing = self._circles[id]
	if existing then
		existing:moveTo(position)
		existing:setActive(active ~= false)
		return
	end
	local count = 0
	for _ in self._circles do
		count += 1
	end
	if count >= MAX_CIRCLES then
		return
	end
	-- GroundMarker only reads ctx.world; the rest of the preview ctx is not needed here
	local marker = GroundMarker.new({ world = self._folder } :: any, {
		position = position,
		diameter = diameter,
		colour = colour,
		active = active ~= false,
	})
	self._circles[id] = marker
end

function HomeWorld.removeCircle(self: any, id: string)
	local marker = self._circles[id]
	if marker then
		marker:destroy()
		self._circles[id] = nil
	end
end

-- STATE -------------------------------------------------------------------------------------------------------------

function HomeWorld.setVisible(self: any, on: boolean)
	self._visible = on
	self._route:setVisible(on)
	for _, b in self._bubbles do
		b.board.Enabled = on
	end
	for _, r in self._rates do
		r.board.Enabled = on
	end
	for _, c in self._circles do
		c:setVisible(on)
	end
	if not on then
		for _, f in self._floats do
			f.token += 1
			f.busy = false
			f.board.Enabled = false
		end
	end
end

function HomeWorld.getDebugState(self: any): { [string]: any }
	local bubbles: { [string]: any } = {}
	for id, b in self._bubbles do
		bubbles[id] = b.kind
	end
	local circles = 0
	for _ in self._circles do
		circles += 1
	end
	local rates: { [string]: any } = {}
	for id, r in self._rates do
		rates[id] = r.text.Text
	end
	local live = 0
	for _, f in self._floats do
		if f.busy then
			live += 1
		end
	end
	return {
		visible = self._visible,
		trail = self._route:getDebugState(),
		bubbles = bubbles,
		rates = rates,
		circles = circles,
		floatsLive = live,
		floatsShown = self._floatCount,
		billboardScale = self:_billboardScale(),
	}
end

function HomeWorld.destroy(self: any)
	self._destroyed = true
	for id in table.clone(self._bubbles) do
		self:setBubble(id, nil, nil)
	end
	for id in table.clone(self._rates) do
		self:setRate(id, nil, nil)
	end
	for id in table.clone(self._circles) do
		self:removeCircle(id)
	end
	self._trove:Destroy()
end

return HomeWorld
