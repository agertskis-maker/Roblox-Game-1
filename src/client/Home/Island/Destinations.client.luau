--!strict
-- Park destinations presentation (Lane 3, client only; brief sections 9, 10 and 12). Reads what
-- Hub/Environment/Destinations built in Workspace.Lane3_IslandEnvironment.Destinations:
--   turntables: the three showroom discs and their preview cars turn slowly (DegPerSec, 6) about
--     their own centres; reduced motion puts them back at their three-quarter rest pose at once
--     and holds them there while it is on;
--   start lights: a slow preview countdown on the five Stunt Circuit lights (lights 1 to 5 come
--     on red one per second, all five hold 1 s, all off, 3 s pause, repeat). It only previews the
--     look: no race starts. Reduced motion holds all five unlit and steady (lens meta);
--   "Open Garage": pressing the prompt shows "Not connected yet" in its ObjectText for 3 s, to
--     the pressing player only. Nothing is sent to the server and nothing is saved;
--   Play stand-ins: while a destination's meshes are session-only previews (Source "preview"),
--     they do not reach a playtest, so its colliders and lamp balls show as simple blocks here.
-- Reduced motion follows GuiService.ReducedMotionEnabled, or the preview-only LocalPlayer
-- attribute "Lane3ReducedMotionOverride" (never saved) while it is set, checked every frame so a
-- toggle applies at once. Every change is local to this client; the Trove restores it.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ENV_NAME = "Lane3_IslandEnvironment"
local FOLDER_NAME = "Destinations"
local OVERRIDE = "Lane3ReducedMotionOverride"
local RESCAN = 3 -- seconds between looks for pieces that streamed in late
local SPIN_RANGE = 420 -- studs from the camera; farther turntables hold still (Tunable)
local LIGHT_STEP = 1.0 -- seconds per light coming on (Tunable)
local LIGHT_HOLD = 1.0 -- all five lit (Tunable)
local LIGHT_PAUSE = 3.0 -- all off before the next round (Tunable)
local LIGHT_CYCLE = 5 * LIGHT_STEP + LIGHT_HOLD + LIGHT_PAUSE
local LIT_RED = Color3.fromRGB(235, 52, 45)
local LAMP_OFF = Color3.fromRGB(46, 46, 54) -- the stand-in balls when unlit (the smoked lens)

local player = Players.LocalPlayer

local function reducedMotion(): boolean
	local override = player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

type SpinPart = { part: BasePart, base: CFrame }
type SpinModel = { model: Model, base: CFrame }
type Spinner = {
	centre: Vector3,
	rate: number, -- degrees per second
	parts: { SpinPart },
	models: { SpinModel },
	angle: number,
	applied: number,
}
type Lamp = {
	part: BasePart,
	index: number,
	material: Enum.Material,
	colour: Color3,
	texture: string?, -- MeshPart lenses only
	transparency: number,
	standIn: boolean,
}

local function litCount(t: number): number
	local c = t % LIGHT_CYCLE
	if c < 5 * LIGHT_STEP then
		return math.floor(c / LIGHT_STEP) + 1
	elseif c < 5 * LIGHT_STEP + LIGHT_HOLD then
		return 5
	end
	return 0
end

local function run(trove: Trove.Trove, root: Instance)
	local spinners: { [Instance]: Spinner } = {}
	local known: { [Instance]: boolean } = {}
	local lamps: { Lamp } = {}
	local shown: { { part: BasePart, transparency: number, colour: Color3 } } = {}
	local lastLit = -1
	local lastScan = -math.huge

	local function isPreview(d: Instance): boolean
		local a: Instance? = d.Parent
		while a and a ~= root do
			if a:IsA("Model") and a:GetAttribute("Source") ~= nil then
				return a:GetAttribute("Source") == "preview"
			end
			a = a.Parent
		end
		return false
	end

	local function hookPrompt(prompt: ProximityPrompt)
		local original = prompt.ObjectText
		local pressed = prompt:GetAttribute("PressedText")
		local seconds = prompt:GetAttribute("PressedSeconds")
		local text = if type(pressed) == "string" then pressed else "Not connected yet"
		local hold = if type(seconds) == "number" then seconds else 3
		local pending: thread? = nil
		trove:Connect(prompt.Triggered, function(who: Player)
			if who ~= player then
				return
			end
			if pending then
				task.cancel(pending)
			end
			prompt.ObjectText = text
			pending = task.delay(hold, function()
				pending = nil
				prompt.ObjectText = original
			end)
		end)
		trove:Add(function()
			if pending then
				task.cancel(pending)
				pending = nil
			end
			prompt.ObjectText = original
		end)
	end

	local function scan()
		for _, d in root:GetDescendants() do
			if known[d] then
				continue
			end
			if d:IsA("ProximityPrompt") then
				known[d] = true
				hookPrompt(d)
			elseif d:GetAttribute("Spin") == true and (d:IsA("BasePart") or d:IsA("Model")) then
				local turntable = d.Parent
				local centre = turntable and turntable:GetAttribute("Centre")
				local rate = turntable and turntable:GetAttribute("DegPerSec")
				if turntable and typeof(centre) == "Vector3" then
					known[d] = true
					local s = spinners[turntable]
					if not s then
						s = {
							centre = centre,
							rate = if type(rate) == "number" then rate else 6,
							parts = {},
							models = {},
							angle = 0,
							applied = 0,
						}
						spinners[turntable] = s
					end
					local sp = s :: Spinner
					-- recorded at the built rest pose: a piece that streams in late arrives at the
					-- server's (rest) pose, and the next applySpin turns it with the others
					if d:IsA("BasePart") then
						table.insert(sp.parts, { part = d, base = d.CFrame })
					elseif d:IsA("Model") then
						table.insert(sp.models, { model = d, base = d:GetPivot() })
					end
				end
			elseif d:IsA("BasePart") and type(d:GetAttribute("Light")) == "number" then
				local isLens = d:GetAttribute("Lens") == true
				local isBall = d:GetAttribute("LampStandIn") == true
				if isLens or isBall then
					known[d] = true
					local preview = isPreview(d)
					local lamp: Lamp = {
						part = d,
						index = d:GetAttribute("Light") :: number,
						material = d.Material,
						colour = d.Color,
						texture = if d:IsA("MeshPart") then (d :: MeshPart).TextureID else nil,
						transparency = d.Transparency,
						-- the balls stand in only while the lens mesh is a preview
						standIn = isBall and preview,
					}
					if isBall and not preview then
						continue -- the real lens shows; the ball stays hidden
					end
					table.insert(lamps, lamp)
					if lamp.standIn then
						d.Transparency = 0
						d.Color = LAMP_OFF
					end
					lastLit = -1
				end
			elseif d:IsA("BasePart") and typeof(d:GetAttribute("StandInColour")) == "Color3" then
				known[d] = true
				if isPreview(d) then
					table.insert(shown, { part = d, transparency = d.Transparency, colour = d.Color })
					d.Transparency = 0
					d.Color = d:GetAttribute("StandInColour") :: Color3
				end
			end
		end
	end

	local function applySpin(s: Spinner)
		local turn = CFrame.new(s.centre) * CFrame.Angles(0, math.rad(s.angle), 0) * CFrame.new(-s.centre)
		for _, p in s.parts do
			if p.part.Parent then
				p.part.CFrame = turn * p.base
			end
		end
		for _, m in s.models do
			if m.model.Parent then
				m.model:PivotTo(turn * m.base)
			end
		end
		s.applied = s.angle
	end

	local function setLit(lamp: Lamp, on: boolean)
		local p = lamp.part
		if on then
			if p:IsA("MeshPart") then
				(p :: MeshPart).TextureID = "" -- lit: clear the swatch, red Neon (lens meta)
			end
			p.Material = Enum.Material.Neon
			p.Color = LIT_RED
		else
			if p:IsA("MeshPart") and lamp.texture then
				(p :: MeshPart).TextureID = lamp.texture
			end
			p.Material = lamp.material
			p.Color = if lamp.standIn then LAMP_OFF else lamp.colour
		end
	end

	scan()
	lastScan = os.clock()
	trove:Connect(RunService.RenderStepped, function(dt: number)
		local now = os.clock()
		if now - lastScan > RESCAN then
			lastScan = now
			scan()
		end
		local calm = reducedMotion()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		for _, s in spinners do
			if calm then
				s.angle = 0 -- the rest pose, at once
			elseif eye and (s.centre - eye).Magnitude < SPIN_RANGE then
				s.angle = (s.angle + s.rate * dt) % 360
			end
			if s.angle ~= s.applied then
				applySpin(s)
			end
		end
		-- reduced motion: all five lit and steady (the brief: "steady under reduced motion")
		local lit = if calm then 5 else litCount(now)
		if lit ~= lastLit then
			lastLit = lit
			for _, lamp in lamps do
				if lamp.part.Parent then
					setLit(lamp, lamp.index <= lit)
				end
			end
		end
	end)

	trove:Add(function()
		for _, s in spinners do
			s.angle = 0
			applySpin(s)
		end
		for _, lamp in lamps do
			if lamp.part.Parent then
				setLit(lamp, false)
				lamp.part.Transparency = lamp.transparency
				lamp.part.Color = lamp.colour
			end
		end
		for _, item in shown do
			if item.part.Parent then
				item.part.Transparency = item.transparency
				item.part.Color = item.colour
			end
		end
	end)
end

local rootTrove = Trove.new()
local current: Trove.Trove? = nil

local function attach(destinations: Instance)
	if current then
		current:Destroy()
	end
	local trove = Trove.new()
	current = trove
	run(trove, destinations)
	trove:Connect(destinations.AncestryChanged, function()
		if not destinations:IsDescendantOf(Workspace) then
			trove:Destroy()
			if current == trove then
				current = nil
			end
		end
	end)
end

local function watchEnvironment(env: Instance)
	local existing = env:FindFirstChild(FOLDER_NAME)
	if existing then
		attach(existing)
	end
	rootTrove:Connect(env.ChildAdded, function(child: Instance)
		if child.Name == FOLDER_NAME then
			attach(child)
		end
	end)
end

local env = Workspace:FindFirstChild(ENV_NAME)
if env then
	watchEnvironment(env)
end
rootTrove:Connect(Workspace.ChildAdded, function(child: Instance)
	if child.Name == ENV_NAME then
		watchEnvironment(child)
	end
end)
