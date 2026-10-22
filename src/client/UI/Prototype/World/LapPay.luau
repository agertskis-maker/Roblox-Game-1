--!strict
-- Lap Pay world feedback (Lane 3 preview, worker H3): a "+$120" label rising about 3 studs above
-- a local-owned fixture car, lasting about 1.2 s. VISUAL ONLY: it displays the amount it is
-- given (FIXTURE values from the preview adapter); it calculates and grants nothing. Brian L owns
-- the real rate, its units and when a lap pays.
--
--   * only within about 120 studs of the camera (BillboardGui.MaxDistance plus a distance check
--     before showing, so nothing far away is even allocated);
--   * at most 4 visible at once from a fixed pool of 4 BillboardGuis (never created per event);
--   * combined when they would overlap: a new pay on the same car, or one whose screen position
--     is within 56 px of a visible label, adds into that label (+$240) and restarts it; when the
--     pool is full it adds into the nearest visible label;
--   * reduced motion: no rise; the label appears, holds and fades in place.
--   * sound: Sounds.play("LapPay") at most once per 0.25 s.
--
-- Events: store event { kind = "LapPay", amount = number, worldPosition = Vector3? }. With a
-- worldPosition the nearest registered car within 10 studs is used, else a pooled anchor at that
-- position. Direct calls: lapPay:pay(part, amount).
--
--   local lp = LapPay.new(ctx)
--   lp:setCars({ BasePart })      -- the local-owned fixture cars (their main parts)
--   lp:pay(part: BasePart, amount: number) -> boolean   -- false when out of range / invalid
--   lp:layout() (billboard scale), lp:setVisible(on), lp:destroy(), lp:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.UI.Format)
local Gloss = require(script.Parent.Parent.Gloss)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local M = PreviewTokens.Motion
local make = Gloss.make

local POOL = 4
local RISE = 3
local START = 1.5 -- studs above the top of the car at spawn
local MERGE_PX = 56
local NEAREST_CAR = 10
local SIZE = Vector2.new(150, 48)

local LapPay = {}
LapPay.__index = LapPay

type Label = {
	board: BillboardGui,
	text: TextLabel,
	scale: UIScale,
	anchor: Part,
	source: BasePart?,
	amount: number,
	busy: boolean,
	token: number,
	top: number,
}

function LapPay.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, LapPay)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._cars = {} :: { BasePart }
	self._labels = {} :: { Label }
	self._shown = 0
	self._merged = 0
	self._outOfRange = 0
	self._lastSound = -math.huge
	self._sounds = 0

	local folder = self._trove:Add(make("Folder", { Name = "LapPay", Parent = ctx.world }))
	self._folder = folder
	for i = 1, POOL do
		local anchor = make("Part", {
			Name = "LapPayAnchor" .. i,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			Parent = folder,
		})
		local board = make("BillboardGui", {
			Name = "LapPay" .. i,
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = M.LapPayRange,
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			Enabled = false,
			ResetOnSpawn = false,
			Parent = folder,
		})
		local scale = make("UIScale", { Name = "HudScale", Scale = 1 })
		local holder = make("Frame", {
			Name = "Holder",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			Parent = board,
			Children = { scale },
		})
		local text = Gloss.title(holder, "+$0", 30, C.CashLight, C.CashDeep)
		text.Size = UDim2.fromScale(1, 1)
		table.insert(self._labels, {
			board = board,
			text = text,
			scale = scale,
			anchor = anchor,
			source = nil,
			amount = 0,
			busy = false,
			token = 0,
			top = 0,
		})
	end

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind ~= "LapPay" or type(event.amount) ~= "number" then
			return
		end
		local amount = event.amount :: number
		local pos = event.worldPosition
		if pos then
			local car = self:_nearestCar(pos)
			if car then
				self:pay(car, amount)
			else
				self:payAt(pos, amount)
			end
		elseif #self._cars > 0 then
			self:pay(self._cars[1], amount)
		end
	end)
	self._trove:Add(function()
		for _, l in self._labels do
			l.token += 1
			Motion.cancelAll(l.board)
			Motion.cancelAll(l.text)
		end
	end)
	self:layout()
	return self
end

export type LapPay = typeof(LapPay.new((nil :: any) :: RunLayout.Ctx))

function LapPay._nearestCar(self: LapPay, pos: Vector3): BasePart?
	local best, bestD = nil, NEAREST_CAR
	for _, part in self._cars do
		if part.Parent then
			local d = (part.Position - pos).Magnitude
			if d <= bestD then
				best, bestD = part, d
			end
		end
	end
	return best
end

local function cameraPos(): Vector3?
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

local function screenPos(world: Vector3): Vector2?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local p, onScreen = camera:WorldToViewportPoint(world)
	if not onScreen then
		return nil
	end
	return Vector2.new(p.X, p.Y)
end

-- Where a label currently is in the world (for overlap checks).
local function labelWorld(l: Label): Vector3
	local base = if l.source and l.source.Parent then (l.source :: BasePart).Position else l.anchor.Position
	return base + l.board.StudsOffsetWorldSpace
end

function LapPay.setCars(self: LapPay, cars: { BasePart })
	self._cars = table.clone(cars)
end

local function inRange(world: Vector3): boolean
	local cam = cameraPos()
	return cam ~= nil and (world - (cam :: Vector3)).Magnitude <= M.LapPayRange
end

function LapPay._text(amount: number): string
	return "+" .. Format.cash(amount)
end

function LapPay._start(self: LapPay, l: Label, merged: boolean)
	l.token += 1
	local token = l.token
	l.busy = true
	l.text.Text = LapPay._text(l.amount)
	local board = l.board
	board.Enabled = self._visible
	local reduced = Motion.reduced()
	local startOffset = Vector3.new(0, l.top + START, 0)
	if not merged or reduced then
		board.StudsOffsetWorldSpace = if reduced then startOffset + Vector3.new(0, RISE * 0.5, 0) else startOffset
	end
	l.text.TextTransparency = 0
	for _, child in l.text:GetChildren() do
		if child:IsA("UIStroke") then
			child.Transparency = 0
		end
	end
	if not reduced then
		Motion.tween(board, "rise", Motion.info(M.LapPaySeconds, Enum.EasingStyle.Quad), {
			StudsOffsetWorldSpace = startOffset + Vector3.new(0, RISE, 0),
		})
		if merged then
			Motion.pop(l.text, 1.12)
		end
	end
	-- hold, then fade over the last 0.35 s
	task.delay(M.LapPaySeconds - 0.35, function()
		if token ~= l.token then
			return
		end
		Motion.tween(l.text, "fade", Motion.info(0.35), { TextTransparency = 1 })
		for _, child in l.text:GetChildren() do
			if child:IsA("UIStroke") then
				Motion.tween(child, "fade", Motion.info(0.35), { Transparency = 1 })
			end
		end
		task.delay(0.36, function()
			if token == l.token then
				l.busy = false
				l.board.Enabled = false
				l.source = nil
				l.amount = 0
			end
		end)
	end)
	local now = os.clock()
	if now - self._lastSound >= 0.25 then
		self._lastSound = now
		self._sounds += 1
		Sounds.play("LapPay")
	end
end

function LapPay._place(self: LapPay, source: BasePart?, world: Vector3, amount: number): boolean
	if not self._visible or amount ~= amount or amount <= 0 then
		return false
	end
	if not inRange(world) then
		self._outOfRange += 1
		return false
	end
	-- combine: same car, or a visible label within MERGE_PX on screen
	local here = screenPos(world)
	local nearest: Label? = nil
	local nearestD = math.huge
	for _, l in self._labels do
		if l.busy then
			if source and l.source == source then
				nearest, nearestD = l, 0
				break
			end
			local there = screenPos(labelWorld(l))
			if here and there then
				local d = ((here :: Vector2) - (there :: Vector2)).Magnitude
				if d < nearestD then
					nearest, nearestD = l, d
				end
			end
		end
	end
	if nearest and nearestD <= MERGE_PX then
		local l = nearest :: Label
		l.amount += amount
		self._merged += 1
		self:_start(l, true)
		return true
	end
	local free: Label? = nil
	for _, l in self._labels do
		if not l.busy then
			free = l
			break
		end
	end
	if not free then
		-- pool full: add into the nearest visible label (or the first) rather than stacking more
		local target = nearest or self._labels[1]
		target.amount += amount
		self._merged += 1
		self:_start(target, true)
		return true
	end
	local l = free :: Label
	l.amount = amount
	l.source = source
	if source then
		l.board.Adornee = source
		l.top = source.Size.Y / 2
	else
		l.anchor.CFrame = CFrame.new(world)
		l.board.Adornee = l.anchor
		l.top = 0
	end
	self._shown += 1
	self:_start(l, false)
	return true
end

-- Shows "+$amount" rising above a car part. Returns false when out of range or invalid.
function LapPay.pay(self: LapPay, part: BasePart, amount: number): boolean
	if not part or not part.Parent then
		return false
	end
	return self:_place(part, part.Position, amount)
end

-- Shows "+$amount" at a world position (no car part supplied).
function LapPay.payAt(self: LapPay, world: Vector3, amount: number): boolean
	return self:_place(nil, world, amount)
end

function LapPay.layout(self: LapPay)
	local s = self._ctx.screen:uiScale() * self._ctx.screen:fitScale()
	for _, l in self._labels do
		l.scale.Scale = s
		l.board.Size = UDim2.fromOffset(SIZE.X * s, SIZE.Y * s)
	end
end

function LapPay.setVisible(self: LapPay, on: boolean)
	self._visible = on
	for _, l in self._labels do
		l.board.Enabled = on and l.busy
	end
end

function LapPay.getDebugState(self: LapPay): { [string]: any }
	local visible, texts = 0, {}
	for _, l in self._labels do
		if l.busy and l.board.Enabled then
			visible += 1
			table.insert(texts, l.text.Text)
		end
	end
	return {
		visible = visible,
		pool = #self._labels,
		texts = texts,
		shown = self._shown,
		merged = self._merged,
		outOfRange = self._outOfRange,
		sounds = self._sounds,
		maxDistance = self._labels[1].board.MaxDistance,
		cars = #self._cars,
		textSize = 30,
	}
end

function LapPay.destroy(self: LapPay)
	self._trove:Destroy()
end

return LapPay
