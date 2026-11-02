--!strict
-- Home/ReturnGuide: the returning-player guidance (Lane 3, N8-05, 2026-11-02). Shortly after a player joins or comes back
-- (reference A: the chevron trail, the goal pill, the "UNLOCK!" bubble), it points at the ONE most useful next thing:
--
--     1. an affordable Raceway upgrade   2. a ready portal   3. an unclaimed mission
--
-- It decides nothing about the game. The caller supplies the candidates from real data, already filtered to the ones that
-- are really available (an upgrade the player can afford right now, a portal that is really open, a mission that is really
-- complete); a candidate that is not real is simply never supplied, so the guide can never point at something false. It
-- draws the goal pill (HomeHud:setGoal), the chevron trail (HomeWorld:setTrail, the tutorial's pooled TutorialRoute) and,
-- for a portal, the UNLOCK! / OPEN! bubble. It never moves the player, grants anything or saves anything.
--
--   local guide = ReturnGuide.new(hud, {
--       getCandidates = function(): { Candidate } ... end,        -- real, available things only, in any order
--       getPlayerPosition = function(): Vector3? ... end,          -- nil = no trail (the pill still shows)
--       route = function(from: Vector3, to: Vector3): { Vector3 }? -- an optional path along the real walkways; nil = straight
--       seconds = 25,                                              -- how long it stays after show()
--       arriveStuds = 8,                                           -- the trail ends this near the target
--   })
--   guide:show()           -- pick the best candidate now and start (call it a moment after join / return)
--   guide:refresh()        -- the data changed: pick again (keeps the same one when it is still the best)
--   guide:hide()           -- the player did the thing, or opened a menu: it goes away at once
--   guide:setSuppressed(on)   -- the tutorial owns the screen: nothing shows while this is true
--   guide:getDebugState()  guide:destroy()
--
-- Candidate = { kind = "Upgrade" | "Portal" | "Mission", id: string, position: Vector3?, title: string?, subtitle: string?,
--               progress: number? (0..1, real progress toward it), bubble: { target: Instance, kind: "Unlock" | "Open" }? }
-- title / subtitle default to the words in TutorialStrings ("return.*").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(script.Parent.Parent.Parent.Tutorial.TutorialStrings)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Candidate = {
	kind: "Upgrade" | "Portal" | "Mission",
	id: string,
	position: Vector3?,
	title: string?,
	subtitle: string?,
	progress: number?,
	bubble: { target: Instance, kind: string }?,
}

export type Options = {
	getCandidates: () -> { Candidate },
	getPlayerPosition: (() -> Vector3?)?,
	route: ((from: Vector3, to: Vector3) -> { Vector3 }?)?,
	seconds: number?,
	arriveStuds: number?,
}

-- the host: HomeHud (or anything with these)
type Host = {
	setGoal: (self: any, spec: any?) -> (),
	world: { setTrail: (self: any, points: { Vector3 }?) -> (), setBubble: (self: any, ...any) -> () },
}

export type Guide = {
	show: (self: Guide) -> (),
	refresh: (self: Guide) -> (),
	hide: (self: Guide) -> (),
	setSuppressed: (self: Guide, on: boolean) -> (),
	getDebugState: (self: Guide) -> { [string]: any },
	destroy: (self: Guide) -> (),
}

local RANK: { [string]: number } = { Upgrade = 1, Portal = 2, Mission = 3 }
local TICK = 0.3
local TRAIL_SKIP = 3 -- studs of trail dropped at the player's feet, as the tutorial does
local BUBBLE_ID = "return-portal"

local ReturnGuide = {}
ReturnGuide.__index = ReturnGuide

-- The best candidate: lowest rank, then the order it was supplied in.
function ReturnGuide.pick(list: { Candidate }): Candidate?
	local best: Candidate? = nil
	for _, c in list do
		local rank = RANK[c.kind]
		if rank ~= nil and (best == nil or rank < RANK[(best :: Candidate).kind]) then
			best = c
		end
	end
	return best
end

local function words(c: Candidate): (string, string)
	local key = if c.kind == "Upgrade"
		then "return.upgrade"
		elseif c.kind == "Portal" then "return.portal"
		else "return.mission"
	return c.title or Strings.get(key .. ".title"), c.subtitle or Strings.get(key .. ".line")
end

-- Drops the first `studs` of a polyline (the stretch at the player's feet).
local function trimStart(points: { Vector3 }, studs: number): { Vector3 }
	if #points < 2 or studs <= 0 then
		return points
	end
	local out: { Vector3 } = {}
	local left = studs
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if #out == 0 then
			if len > left then
				table.insert(out, a:Lerp(b, left / len))
				table.insert(out, b)
			else
				left -= len
			end
		else
			table.insert(out, b)
		end
	end
	return out
end

function ReturnGuide.new(hud: Host, options: Options): Guide
	local self = setmetatable({}, ReturnGuide) :: any
	self._trove = Trove.new()
	self._hud = hud
	self._opts = options
	self._seconds = options.seconds or 25
	self._arrive = options.arriveStuds or 8
	self._active = false
	self._suppressed = false
	self._current = nil :: Candidate?
	self._ownsGoal = false
	self._startedAt = 0
	self._thread = nil :: thread?
	self._lastFrom = nil :: Vector3?
	self._trails = 0
	self._trove:Add(function()
		self:_clear()
	end)
	return self :: Guide
end

function ReturnGuide._stopLoop(self: any)
	local t: thread? = self._thread
	self._thread = nil
	if t and t ~= coroutine.running() and coroutine.status(t) ~= "dead" then
		pcall(task.cancel, t)
	end
end

-- Takes everything off the screen.
function ReturnGuide._clear(self: any)
	self:_stopLoop()
	self._current = nil
	self._lastFrom = nil
	local hud: Host = self._hud
	if self._ownsGoal then
		self._ownsGoal = false
		hud:setGoal(nil) -- only a goal this guide set; a goal the game set stays
	end
	hud.world:setTrail(nil)
	hud.world:setBubble(BUBBLE_ID, nil, nil)
end

function ReturnGuide._apply(self: any, c: Candidate)
	local hud: Host = self._hud
	local previous: Candidate? = self._current
	self._current = c
	local title, line = words(c)
	self._ownsGoal = true
	hud:setGoal({
		title = title,
		subtitle = line,
		progress = c.progress,
		icon = if c.kind == "Portal" then "Portal" else nil,
	})
	if c.bubble then
		hud.world:setBubble(BUBBLE_ID, c.bubble.target, c.bubble.kind)
	else
		hud.world:setBubble(BUBBLE_ID, nil, nil)
	end
	if previous == nil or previous.id ~= c.id then
		self._lastFrom = nil
		hud.world:setTrail(nil)
	end
end

-- The trail from where the player stands to the candidate, rebuilt only when the player has moved.
function ReturnGuide._trail(self: any)
	local c: Candidate? = self._current
	local hud: Host = self._hud
	local getPos = self._opts.getPlayerPosition
	if not c or not c.position or not getPos then
		hud.world:setTrail(nil)
		return
	end
	local from = getPos()
	if not from then
		hud.world:setTrail(nil)
		return
	end
	local to: Vector3 = c.position
	local flat = Vector3.new(from.X - to.X, 0, from.Z - to.Z).Magnitude
	if flat < self._arrive then
		hud.world:setTrail(nil) -- close enough: the goal pill and the bubble take over
		self._lastFrom = from
		return
	end
	local last: Vector3? = self._lastFrom
	if last and (from - last).Magnitude < 2 then
		return
	end
	self._lastFrom = from
	local points: { Vector3 }? = nil
	local routeFn = self._opts.route
	if routeFn then
		local ok, result = pcall(routeFn, from, to)
		if ok and type(result) == "table" and #result >= 2 then
			points = result
		end
	end
	hud.world:setTrail(trimStart(points or { from, to }, TRAIL_SKIP))
	self._trails += 1
end

function ReturnGuide._startLoop(self: any)
	self:_stopLoop()
	self._thread = task.spawn(function()
		while self._active and not self._suppressed do
			self:_trail()
			task.wait(TICK)
			if os.clock() - self._startedAt >= self._seconds then
				self:hide()
				return
			end
		end
	end)
end

function ReturnGuide.show(self: any)
	if self._suppressed then
		self._active = true -- remembered: it shows when the suppression ends
		self._startedAt = os.clock()
		return
	end
	self._active = true
	self._startedAt = os.clock()
	local ok, list = pcall(self._opts.getCandidates)
	local c = if ok and type(list) == "table" then ReturnGuide.pick(list) else nil
	if not c then
		self:_clear()
		self._active = false
		return
	end
	self:_apply(c)
	self:_startLoop()
end

function ReturnGuide.refresh(self: any)
	if not self._active or self._suppressed then
		return
	end
	local ok, list = pcall(self._opts.getCandidates)
	local c = if ok and type(list) == "table" then ReturnGuide.pick(list) else nil
	if not c then
		self:hide()
		return
	end
	self:_apply(c)
end

function ReturnGuide.hide(self: any)
	self._active = false
	self:_clear()
end

function ReturnGuide.setSuppressed(self: any, on: boolean)
	if self._suppressed == on then
		return
	end
	self._suppressed = on
	if on then
		self:_stopLoop()
		local hud: Host = self._hud
		-- only what this guide drew leaves; the tutorial banner takes the spot
		if self._current then
			if self._ownsGoal then
				self._ownsGoal = false
				hud:setGoal(nil)
			end
			hud.world:setTrail(nil)
			hud.world:setBubble(BUBBLE_ID, nil, nil)
			self._current = nil
		end
	elseif self._active then
		-- the tutorial is over: the guide resumes, with a fresh time allowance
		self:show()
	end
end

function ReturnGuide.getDebugState(self: any): { [string]: any }
	local c: Candidate? = self._current
	return {
		active = self._active,
		suppressed = self._suppressed,
		kind = if c then c.kind else nil,
		id = if c then c.id else nil,
		trailsBuilt = self._trails,
		secondsLeft = if self._active then math.max(0, self._seconds - (os.clock() - self._startedAt)) else 0,
	}
end

function ReturnGuide.destroy(self: any)
	self._active = false
	self._trove:Destroy()
end

return ReturnGuide
