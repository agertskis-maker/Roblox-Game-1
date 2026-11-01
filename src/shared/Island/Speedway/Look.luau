--!strict
-- The Speedway look module (Lane 3, presentation only). One additive kit assembles a plot's
-- Speedway for a level 1 to 12 (the recommended PREVIEW ladder, Ladder):
--
--   Look.apply(plot, level)  -- builds what the level adds, removes what it replaced
--
-- Each feature below exists over a range of levels; applying a level builds the features in
-- range that are missing and removes the ones out of range, so upgrading, downgrading and
-- repeating a level all end in the same pieces (no duplicate stands, no dirt under asphalt, no
-- leftover figures). Features hold three folders: Major (the silhouette, always shown), Minor
-- (small props, near only) and Life (animated figures, near only); Look.setDetail switches them.
--
-- Proposed contract for Lane 2 (Brian L, vault/design/specs/speedway-levels-for-brian-l.md): the
-- server sets the integer attribute "SpeedwayLevel" on the plot Model; every client assembles the
-- look from it (Home/Island/SpeedwayLooks). Nothing here pays, prices or saves.

local Ctx = require(script.Parent.Ctx)
local Ladder = require(script.Parent.Ladder)
local Props = require(script.Parent.Props)
local Track = require(script.Parent.Track)

local Look = {}

type Ctx = Ctx.Ctx
export type Parts = { major: Folder, minor: Folder, life: Folder }
export type Feature = { name: string, from: number, to: number, build: (Parts, Ctx) -> () }

local function f(name: string, from: number, to: number, build: (Parts, Ctx) -> ()): Feature
	return { name = name, from = from, to = to, build = build }
end

Look.Features = {
	-- road and edges
	f("Dirt", 1, 1, function(p, c)
		Track.dirt(p.major, c)
	end),
	f("DirtRaked", 2, 3, function(p, c)
		Track.dirtRaked(p.major, c)
	end),
	f("Ruts", 1, 1, function(p, c)
		Track.ruts(p.major, c)
	end),
	f("ChalkLine", 1, 3, function(p, c)
		Track.chalkLine(p.major, c)
	end),
	f("StartLine", 4, 4, function(p, c)
		Track.paintedLine(p.major, c)
	end),
	f("Checker", 5, 12, function(p, c)
		Track.checker(p.major, c)
	end),
	f("HayAll", 1, 1, function(p, c)
		Track.hay(p.major, c, false)
	end),
	f("HayTurns", 2, 3, function(p, c)
		Track.hay(p.major, c, true)
	end),
	f("Rope", 2, 3, function(p, c)
		Track.rope(p.major, c)
	end),
	f("TyresInner", 1, 3, function(p, c)
		Track.tyresInner(p.major, c)
	end),
	f("AsphaltFlat", 4, 8, function(p, c)
		Track.asphaltFlat(p.major, c)
	end),
	f("AsphaltBanked", 9, 9, function(p, c)
		Track.asphaltBanked(p.major, c)
	end),
	f("AsphaltGround", 10, 11, function(p, c)
		Track.asphaltGround(p.major, c)
	end),
	f("AsphaltLoopWide", 12, 12, function(p, c)
		Track.asphaltGround(p.major, c, true)
	end),
	f("Infield", 4, 12, function(p, c)
		Track.infield(p.major, c)
	end),
	f("TyreWallOval", 4, 8, function(p, c)
		Track.tyreWall(p.major, c, "oval")
	end),
	f("TyreWallStraights", 9, 9, function(p, c)
		Track.tyreWall(p.major, c, "straights")
	end),
	f("TyreWallGround", 10, 12, function(p, c)
		Track.tyreWall(p.major, c, "ground")
	end),
	f("BankWallNear", 9, 12, function(p, c)
		Track.bankWalls(p.major, p.minor, c, "near")
	end),
	f("BankWallFar", 9, 9, function(p, c)
		Track.bankWalls(p.major, p.minor, c, "far")
	end),
	f("FarCurveRaised", 10, 12, function(p, c)
		Track.farCurve(p.major, p.minor, c)
	end),
	f("Descent", 10, 12, function(p, c)
		Track.descent(p.major, p.minor, c)
	end),
	f("Loop", 12, 12, function(p, c)
		Track.loop(p.major, p.minor, c)
	end),
	f("Hump", 11, 12, function(p, c)
		Track.hump(p.major, p.minor, c)
	end),
	-- props
	f("OwnerSignWood", 1, 3, function(p, c)
		Props.ownerSignWood(p.major, c)
	end),
	f("OwnerBanner", 4, 12, function(p, c)
		Props.ownerBanner(p.major, c)
	end),
	f("WonkyFlag", 1, 4, function(p, c)
		Props.wonkyFlag(p.minor, c)
	end),
	f("StartBoard", 2, 7, function(p, c)
		Props.startBoard(p.major, c)
	end),
	f("Pennants", 2, 9, function(p, c)
		Props.pennants(p.minor, c)
	end),
	f("Bleachers", 3, 6, function(p, c)
		Props.bleachers(p.major, p.life, c)
	end),
	f("SnackCart", 3, 12, function(p, c)
		Props.snackCart(p.minor, c)
	end),
	f("LapBoard", 3, 6, function(p, c)
		Props.lapBoard(p.minor, c)
	end),
	f("Official", 5, 12, function(p, c)
		Props.official(p.major, c)
	end),
	f("StartLights", 5, 12, function(p, c)
		Props.startLights(p.minor, c)
	end),
	f("FlagLine", 5, 12, function(p, c)
		Props.flagLine(p.major, c)
	end),
	f("PitGarage", 6, 12, function(p, c)
		Props.pitGarage(p.major, c)
	end),
	f("PitProps", 6, 12, function(p, c)
		Props.pitProps(p.minor, c)
	end),
	f("PitPaint", 6, 12, function(p, c)
		Props.pitPaint(p.major, c)
	end),
	f("Mechanic", 6, 12, function(p, c)
		Props.mechanic(p.life, c)
	end),
	f("Grandstand", 7, 12, function(p, c)
		Props.grandstand(p.major, p.life, c)
	end),
	f("Announcer", 7, 12, function(p, c)
		Props.announcer(p.major, c)
	end),
	f("Floodlights", 8, 12, function(p, c)
		Props.floodlights(p.major, c)
	end),
	f("Gantry", 8, 12, function(p, c)
		Props.gantry(p.major, p.minor, c, false)
	end),
	f("BigScreen", 8, 12, function(p, c)
		Props.bigScreen(p.major, c)
	end),
	f("Blimp", 11, 12, function(p, c)
		Props.blimp(p.major, c)
	end),
	f("Statue", 12, 12, function(p, c)
		Props.statue(p.major, c)
	end),
	f("Roof", 12, 12, function(p, c)
		Props.roof(p.major, c)
	end),
	f("Cannons", 12, 12, function(p, c)
		Props.cannons(p.minor, c)
	end),
	f("GantryGold", 12, 12, function(p, c)
		Props.gantry(p.major, p.minor, c, true)
	end),
	f("KioskBoard", 1, 12, function(p, c)
		Props.kioskBoard(p.major, c)
	end),
	f("Shop", 1, 12, function(p, c)
		Props.shop(p.major, p.life, c)
	end),
} :: { Feature }

local byName: { [string]: Feature } = {}
for _, feature in Look.Features do
	byName[feature.name] = feature
end

-- the piece the kiosk picture shows and the ghost outlines, per level (Ladder.signature)
Look.SignatureFeature = {
	OwnerSign = "OwnerSignWood",
	StartBoard = "StartBoard",
	Bleachers = "Bleachers",
	TyreWall = "TyreWallOval",
	Official = "Official",
	PitGarage = "PitGarage",
	Grandstand = "Grandstand",
	Gantry = "Gantry",
	BankedWalls = "BankWallNear",
	Raised = "FarCurveRaised",
	Jump = "Hump",
	Loop = "Loop",
} :: { [string]: string }

export type State = {
	plot: Model,
	root: Folder,
	level: number,
	features: { [string]: Folder },
	detail: string, -- "full" or "far"
	held: { [Folder]: Instance }, -- Minor / Life folders taken out while far
}

local states: { [Model]: State } = {}

export type Options = {
	index: number,
	bearing: number,
	owner: string?,
	keepRemoved: boolean?, -- return removed feature folders still parented (the caller fades them)
}

export type Change = { added: { Folder }, removed: { Folder }, from: number, to: number }

local function makeParts(folder: Folder): Parts
	local function sub(name: string): Folder
		local s = Instance.new("Folder")
		s.Name = name
		s.Parent = folder
		return s
	end
	return { major = sub("Major"), minor = sub("Minor"), life = sub("Life") }
end

function Look.state(plot: Model): State?
	return states[plot]
end

-- Assembles `plot`'s Speedway for `level` (clamped to 1..12). Returns what changed.
function Look.apply(plot: Model, level: number, options: Options): Change
	local target = Ladder.clamp(level)
	local state = states[plot]
	if not state or not state.root.Parent then
		local root = plot:FindFirstChild("SpeedwayLook")
		if root then
			root:Destroy()
		end
		local made = Instance.new("Folder")
		made.Name = "SpeedwayLook"
		made.Parent = plot
		state = { plot = plot, root = made, level = 0, features = {}, detail = "full", held = {} }
		states[plot] = state
	end
	local s = state :: State
	local change: Change = { added = {}, removed = {}, from = s.level, to = target }
	local ctx = Ctx.new(plot, options.index, options.bearing, target, options.owner or "")
	for _, feature in Look.Features do
		local want = target >= feature.from and target <= feature.to
		local have = s.features[feature.name]
		if have and not want then
			s.features[feature.name] = nil
			for _, sub in have:GetChildren() do
				s.held[sub :: Folder] = nil
			end
			if options.keepRemoved then
				table.insert(change.removed, have)
			else
				have:Destroy()
			end
		elseif want and not have then
			local folder = Instance.new("Folder")
			folder.Name = feature.name
			folder:SetAttribute("SpeedwayFeature", feature.name)
			folder:SetAttribute("FromLevel", feature.from)
			local parts = makeParts(folder)
			feature.build(parts, ctx)
			folder.Parent = s.root
			s.features[feature.name] = folder
			if s.detail == "far" then
				for _, sub in { parts.minor, parts.life } do
					s.held[sub] = folder
					sub.Parent = nil
				end
			end
			table.insert(change.added, folder)
		end
	end
	s.level = target
	s.root:SetAttribute("Level", target)
	plot:SetAttribute("SpeedwayLookLevel", target)
	return change
end

-- "full" shows every folder; "far" keeps only the Major folders (the silhouette).
function Look.setDetail(plot: Model, detail: string)
	local s = states[plot]
	if not s or s.detail == detail then
		return
	end
	s.detail = detail
	if detail == "far" then
		for _, folder in s.features do
			for _, name in { "Minor", "Life" } do
				local sub = folder:FindFirstChild(name)
				if sub then
					s.held[sub :: Folder] = folder
					sub.Parent = nil
				end
			end
		end
	else
		for sub, folder in s.held do
			if folder.Parent then
				sub.Parent = folder
			else
				sub:Destroy()
			end
		end
		table.clear(s.held)
	end
end

function Look.clear(plot: Model)
	local s = states[plot]
	if s then
		for sub in s.held do
			sub:Destroy()
		end
		s.root:Destroy()
		states[plot] = nil
	end
	local stray = plot:FindFirstChild("SpeedwayLook")
	if stray then
		stray:Destroy()
	end
	Look.clearGhost(plot)
end

-- A level's main piece (Major parts only), built for the plot but not parented: the kiosk
-- picture and the ghost use it.
function Look.signaturePiece(plot: Model, level: number, options: Options): Folder?
	if level < Ladder.MinLevel or level > Ladder.MaxLevel then
		return nil
	end
	local feature = byName[Look.SignatureFeature[Ladder.get(level).signature]]
	if not feature then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpeedwayPiece"
	local parts = makeParts(folder)
	feature.build(parts, Ctx.new(plot, options.index, options.bearing, level, options.owner or ""))
	parts.minor:Destroy()
	parts.life:Destroy()
	return folder
end

-- The next level's main piece as a faint, non-blocking outline (Major only, no text, no figures,
-- no lights, no collision). Off for clean captures: Look.clearGhost.
function Look.ghost(plot: Model, level: number, options: Options): Folder?
	Look.clearGhost(plot)
	local folder = Look.signaturePiece(plot, level, options)
	if not folder then
		return nil
	end
	folder.Name = "SpeedwayGhost"
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.82)
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Color = Color3.fromRGB(150, 220, 255)
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		elseif d:IsA("SurfaceGui") or d:IsA("Decal") or d:IsA("Beam") or d:IsA("Light") or d:IsA("ParticleEmitter") then
			d:Destroy()
		elseif d:IsA("Model") then
			d:SetAttribute("Figure", nil)
		end
	end
	folder:SetAttribute("GhostLevel", level)
	folder.Parent = plot
	return folder
end

function Look.clearGhost(plot: Model)
	local g = plot:FindFirstChild("SpeedwayGhost")
	if g then
		g:Destroy()
	end
end

-- Part and triangle counts of a plot's assembled look (Major only when `majorOnly`).
function Look.count(plot: Model): { [string]: number }
	local s = states[plot]
	local out = { parts = 0, meshParts = 0, triangles = 0, instances = 0, heldParts = 0 }
	if not s then
		return out
	end
	for _, d in s.root:GetDescendants() do
		out.instances += 1
		if d:IsA("BasePart") then
			out.parts += 1
			if d:IsA("MeshPart") then
				out.meshParts += 1
			end
		end
	end
	for sub in s.held do
		for _, d in sub:GetDescendants() do
			if d:IsA("BasePart") then
				out.heldParts += 1
			end
		end
	end
	return out
end

return Look
