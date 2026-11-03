--!strict
-- TutorialWaypoints: the walkable-path graph the tutorial trail follows (BRIEF M11-03), so the chevrons run along the real
-- paths and never cut across water, flower beds or buildings.
--
-- SOURCE OF THE DATA (copied, not required at run time, because src/island/Hub is build-time data that does not exist on
-- the client): src/island/Hub/HubData.luau (generated from assets/island/rework/island-layout.js), read on 2026-11-01 and
-- turned into the NODES and EDGES tables below by a throwaway script (avenue points, plaza and entrance radii, the portal
-- front line). Plan frame: x east, y north toward the plots, origin at the fountain centre; Roblox world X = x, Z = -y. If
-- the island layout changes, regenerate NODES and EDGES from HubData. The names:
--   Gate<n>        the plot gate on the plot's centre line at the entrance radius (247.187)
--   Av<n>Start     the avenue's first point on the promenade inner edge (r 227.187); Gate<n> to it is promenade paving
--   Av<n>End       the avenue's last point at the plaza edge (r 40); the avenue (with its bridge deck over the stream) is the
--                  straight segment Av<n>Start to Av<n>End, so following it never leaves the paving
--   Ring<k>        24 points on a circle of radius 24 inside the plaza, round the fountain basin (radius 12), every 15 degrees
--                  from the south (Ring0 = bearing 180); each avenue joins the ring at its own bearing
--   PlazaSouth     (0, -40), where the Downtown approach leaves the plaza
--   PortalDowntown (0, -56): the portal front line (HubData.park.portal.frontY)
--   Plot<n>Aisle / Plot<n>Front   points on plot n's centre line inside its Paddock (u = r0 + 37) and near its Speedway
--                  front (u = r0 + 93), so a target inside the plot is reached through the gate along the plot axis
-- Every edge is a straight segment of paving (avenue, promenade, plaza, approach) or the open plot axis, so the trail never
-- crosses the fountain basin, the stream (it uses the bridges) or the lawns where the beds are.
--
-- CALIBRATION: the table assumes the Hub sits at the world origin (Layout.planToWorld). graph:calibrate(position) shifts the
-- whole graph in X and Z so PortalDowntown lands on the real Downtown portal field, when the client can find it.
--
-- API
--   Waypoints.new(options?) -> Graph       options.y: ground height of the trail (default 0.3, above the plaza top 0.24)
--   graph:calibrate(portalFieldPosition)   translate the graph so PortalDowntown is under that point (XZ only)
--   graph:nodePosition(name) -> Vector3?
--   graph:plotNode(index, "Gate" | "Aisle" | "Front") -> Vector3?
--   graph:route(from, to) -> { Vector3 }   a polyline from the player's spot to the target, along the graph
--   graph:getDebugState() -> { ... }
--   Waypoints.straight(from, to, spacing?) -> { Vector3 }   a straight polyline (playground fixtures with no island)
--   Waypoints.trimStart(points, distance) -> { Vector3 }    drops the first `distance` studs (the trail starts ahead of the feet)
--   Waypoints.length(points) -> number

local NODES: { { any } } = {
	{ "Ring0", 0, -24 },
	{ "Ring1", -6.21, -23.18 },
	{ "Ring2", -12, -20.78 },
	{ "Ring3", -16.97, -16.97 },
	{ "Ring4", -20.78, -12 },
	{ "Ring5", -23.18, -6.21 },
	{ "Ring6", -24, 0 },
	{ "Ring7", -23.18, 6.21 },
	{ "Ring8", -20.78, 12 },
	{ "Ring9", -16.97, 16.97 },
	{ "Ring10", -12, 20.78 },
	{ "Ring11", -6.21, 23.18 },
	{ "Ring12", 0, 24 },
	{ "Ring13", 6.21, 23.18 },
	{ "Ring14", 12, 20.78 },
	{ "Ring15", 16.97, 16.97 },
	{ "Ring16", 20.78, 12 },
	{ "Ring17", 23.18, 6.21 },
	{ "Ring18", 24, 0 },
	{ "Ring19", 23.18, -6.21 },
	{ "Ring20", 20.78, -12 },
	{ "Ring21", 16.97, -16.97 },
	{ "Ring22", 12, -20.78 },
	{ "Ring23", 6.21, -23.18 },
	{ "Gate1", -238.76, 63.98 },
	{ "Av1Start", -219.44, 58.8 },
	{ "Av1End", -38.64, 10.35 },
	{ "Plot1Aisle", -274.5, 73.55 },
	{ "Plot1Front", -328.6, 88.05 },
	{ "Gate2", -174.79, 174.79 },
	{ "Av2Start", -160.65, 160.65 },
	{ "Av2End", -28.28, 28.28 },
	{ "Plot2Aisle", -200.95, 200.95 },
	{ "Plot2Front", -240.55, 240.55 },
	{ "Gate3", -63.98, 238.76 },
	{ "Av3Start", -58.8, 219.45 },
	{ "Av3End", -10.35, 38.64 },
	{ "Plot3Aisle", -73.55, 274.5 },
	{ "Plot3Front", -88.05, 328.6 },
	{ "Gate4", 63.98, 238.76 },
	{ "Av4Start", 58.8, 219.45 },
	{ "Av4End", 10.35, 38.64 },
	{ "Plot4Aisle", 73.55, 274.5 },
	{ "Plot4Front", 88.05, 328.6 },
	{ "Gate5", 174.79, 174.79 },
	{ "Av5Start", 160.65, 160.65 },
	{ "Av5End", 28.28, 28.28 },
	{ "Plot5Aisle", 200.95, 200.95 },
	{ "Plot5Front", 240.55, 240.55 },
	{ "Gate6", 238.76, 63.98 },
	{ "Av6Start", 219.45, 58.8 },
	{ "Av6End", 38.64, 10.35 },
	{ "Plot6Aisle", 274.5, 73.55 },
	{ "Plot6Front", 328.6, 88.05 },
	{ "PlazaSouth", 0, -40 },
	{ "PortalDowntown", 0, -56 },
}
local EDGES: { { string } } = {
	{ "Ring0", "Ring1" },
	{ "Ring1", "Ring2" },
	{ "Ring2", "Ring3" },
	{ "Ring3", "Ring4" },
	{ "Ring4", "Ring5" },
	{ "Ring5", "Ring6" },
	{ "Ring6", "Ring7" },
	{ "Ring7", "Ring8" },
	{ "Ring8", "Ring9" },
	{ "Ring9", "Ring10" },
	{ "Ring10", "Ring11" },
	{ "Ring11", "Ring12" },
	{ "Ring12", "Ring13" },
	{ "Ring13", "Ring14" },
	{ "Ring14", "Ring15" },
	{ "Ring15", "Ring16" },
	{ "Ring16", "Ring17" },
	{ "Ring17", "Ring18" },
	{ "Ring18", "Ring19" },
	{ "Ring19", "Ring20" },
	{ "Ring20", "Ring21" },
	{ "Ring21", "Ring22" },
	{ "Ring22", "Ring23" },
	{ "Ring23", "Ring0" },
	{ "Gate1", "Av1Start" },
	{ "Av1Start", "Av1End" },
	{ "Av1End", "Ring7" },
	{ "Gate1", "Plot1Aisle" },
	{ "Plot1Aisle", "Plot1Front" },
	{ "Gate2", "Av2Start" },
	{ "Av2Start", "Av2End" },
	{ "Av2End", "Ring9" },
	{ "Gate2", "Plot2Aisle" },
	{ "Plot2Aisle", "Plot2Front" },
	{ "Gate3", "Av3Start" },
	{ "Av3Start", "Av3End" },
	{ "Av3End", "Ring11" },
	{ "Gate3", "Plot3Aisle" },
	{ "Plot3Aisle", "Plot3Front" },
	{ "Gate4", "Av4Start" },
	{ "Av4Start", "Av4End" },
	{ "Av4End", "Ring13" },
	{ "Gate4", "Plot4Aisle" },
	{ "Plot4Aisle", "Plot4Front" },
	{ "Gate5", "Av5Start" },
	{ "Av5Start", "Av5End" },
	{ "Av5End", "Ring15" },
	{ "Gate5", "Plot5Aisle" },
	{ "Plot5Aisle", "Plot5Front" },
	{ "Gate6", "Av6Start" },
	{ "Av6Start", "Av6End" },
	{ "Av6End", "Ring17" },
	{ "Gate6", "Plot6Aisle" },
	{ "Plot6Aisle", "Plot6Front" },
	{ "Ring0", "PlazaSouth" },
	{ "PlazaSouth", "PortalDowntown" },
}

local Waypoints = {}
Waypoints.__index = Waypoints

export type Graph = typeof(setmetatable(
	{} :: {
		_y: number,
		_offset: Vector3,
		_pos: { [string]: Vector3 }, -- plan nodes already in world XZ (without the offset)
		_adj: { [string]: { { to: string, length: number } } },
		_edges: { { a: string, b: string } },
		_calibrated: boolean,
		_routes: number,
	},
	Waypoints
))

function Waypoints.new(options: { y: number? }?): Graph
	local y = if options and options.y then options.y else 0.3
	local pos: { [string]: Vector3 } = {}
	for _, n in NODES do
		pos[n[1] :: string] = Vector3.new(n[2] :: number, y, -(n[3] :: number))
	end
	local adj: { [string]: { { to: string, length: number } } } = {}
	local edges: { { a: string, b: string } } = {}
	for _, e in EDGES do
		local a, b = e[1], e[2]
		local length = (pos[a] - pos[b]).Magnitude
		adj[a] = adj[a] or {}
		adj[b] = adj[b] or {}
		table.insert(adj[a], { to = b, length = length })
		table.insert(adj[b], { to = a, length = length })
		table.insert(edges, { a = a, b = b })
	end
	local self = setmetatable({
		_y = y,
		_offset = Vector3.zero,
		_pos = pos,
		_adj = adj,
		_edges = edges,
		_calibrated = false,
		_routes = 0,
	}, Waypoints)
	return self
end

function Waypoints.calibrate(self: Graph, portalFieldPosition: Vector3)
	local planned = self._pos["PortalDowntown"]
	self._offset = Vector3.new(portalFieldPosition.X - planned.X, 0, portalFieldPosition.Z - planned.Z)
	self._calibrated = true
end

local function at(self: Graph, name: string): Vector3
	return self._pos[name] + self._offset
end

function Waypoints.nodePosition(self: Graph, name: string): Vector3?
	if self._pos[name] == nil then
		return nil
	end
	return at(self, name)
end

function Waypoints.plotNode(self: Graph, index: number, which: string): Vector3?
	return Waypoints.nodePosition(self, "Plot" .. tostring(index) .. which)
end

local function flat(v: Vector3, y: number): Vector3
	return Vector3.new(v.X, y, v.Z)
end

-- The nearest point of the graph to `p` (flat distance): returns the edge, the point and the distance.
local function project(self: Graph, p: Vector3): (number, Vector3, number)
	local bestEdge, bestPoint, bestDist = 1, at(self, self._edges[1].a), math.huge
	for i, e in self._edges do
		local a, b = at(self, e.a), at(self, e.b)
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
		local len2 = ab:Dot(ab)
		local t = if len2 > 1e-6 then math.clamp(ap:Dot(ab) / len2, 0, 1) else 0
		local q = a + ab * t
		local d = Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
		if d < bestDist then
			bestEdge, bestPoint, bestDist = i, q, d
		end
	end
	return bestEdge, flat(bestPoint, self._y), bestDist
end

-- A polyline from `from` to `to` along the graph. The first leg joins the graph at the nearest path point and the last leg
-- leaves it there; both are straight and short for anything near the paths (a target inside a plot is reached from the
-- plot axis). Never throws: with nothing better it returns the straight line.
function Waypoints.route(self: Graph, from: Vector3, to: Vector3, _options: { [string]: any }?): { Vector3 }
	self._routes += 1
	local y = self._y
	local startEdge, startPoint = project(self, from)
	local endEdge, endPoint = project(self, to)
	local points: { Vector3 } = { flat(from, y), startPoint }

	if startEdge == endEdge then
		table.insert(points, endPoint)
		table.insert(points, flat(to, y))
		return points
	end

	-- Dijkstra with the two projection points as virtual ends (a small graph: a linear scan is fine)
	local sa, sb = self._edges[startEdge].a, self._edges[startEdge].b
	local dist: { [string]: number } = {}
	local prev: { [string]: string? } = {}
	local done: { [string]: boolean } = {}
	for name in self._pos do
		dist[name] = math.huge
	end
	dist[sa] = (startPoint - flat(at(self, sa), y)).Magnitude
	dist[sb] = (startPoint - flat(at(self, sb), y)).Magnitude
	while true do
		local current: string? = nil
		local best = math.huge
		for name, d in dist do
			if not done[name] and d < best then
				current, best = name, d
			end
		end
		if current == nil then
			break
		end
		done[current] = true
		for _, edge in self._adj[current] do
			local nd = best + edge.length
			if nd < dist[edge.to] then
				dist[edge.to] = nd
				prev[edge.to] = current
			end
		end
	end
	local ea, eb = self._edges[endEdge].a, self._edges[endEdge].b
	local costA = dist[ea] + (endPoint - flat(at(self, ea), y)).Magnitude
	local costB = dist[eb] + (endPoint - flat(at(self, eb), y)).Magnitude
	local last = if costA <= costB then ea else eb
	if dist[last] == math.huge then
		return { flat(from, y), flat(to, y) }
	end
	local chain: { string } = {}
	local walk: string? = last
	while walk ~= nil do
		table.insert(chain, 1, walk)
		walk = prev[walk]
	end
	for _, name in chain do
		table.insert(points, flat(at(self, name), y))
	end
	table.insert(points, endPoint)
	table.insert(points, flat(to, y))
	return points
end

function Waypoints.getDebugState(self: Graph): { [string]: any }
	return {
		nodes = #NODES,
		edges = #EDGES,
		calibrated = self._calibrated,
		offset = self._offset,
		routes = self._routes,
		groundY = self._y,
		source = "src/island/Hub/HubData.luau (copied 2026-11-01)",
	}
end

-- A straight polyline from `from` to `to` (a fixture with no island graph), points `spacing` studs apart.
function Waypoints.straight(from: Vector3, to: Vector3, spacing: number?): { Vector3 }
	local step = spacing or 12
	local length = (to - from).Magnitude
	local count = math.max(1, math.ceil(length / step))
	local points: { Vector3 } = {}
	for i = 0, count do
		table.insert(points, from:Lerp(to, i / count))
	end
	return points
end

function Waypoints.length(points: { Vector3 }): number
	local total = 0
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
	end
	return total
end

-- Drops the first `distance` studs of a polyline (the trail starts a few studs ahead of the player's feet).
function Waypoints.trimStart(points: { Vector3 }, distance: number): { Vector3 }
	if distance <= 0 or #points < 2 then
		return points
	end
	local out: { Vector3 } = {}
	local remaining = distance
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = (b - a).Magnitude
		if #out == 0 then
			if seg > remaining then
				table.insert(out, a:Lerp(b, remaining / seg))
				table.insert(out, b)
			else
				remaining -= seg
			end
		else
			table.insert(out, b)
		end
	end
	if #out == 0 then
		return { points[#points] }
	end
	return out
end

return Waypoints
