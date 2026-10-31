--!strict
-- Island environment motion (Lane 3, client presentation only). The waterfall's beams scroll
-- on their own; this script scales the activity around them and the park fountain's jets,
-- time-based and cheap:
--   distance: particle rates full near the falls (or the fountain), reduced in the middle
--     distance and off far away (the beams keep a moving impression from every plot);
--   reduced motion: beam scroll slowed but still flowing, spray, droplets and whitewater cut
--     back hard, mist and ripples halved, fireflies off;
--   rainbow: strongest when the sun is behind the viewer, faded otherwise and far away;
--   boost lanes: the avenue chevrons flow toward where they point and breathe softly; reduced
--     motion holds them still and steady (the route stays marked).
-- Reduced motion follows GuiService.ReducedMotionEnabled (the player's Roblox setting); the
-- development preview may set the LocalPlayer attribute "Lane3ReducedMotionOverride" (never
-- saved), which wins while it is set. Settings refresh four times a second, not every frame.
-- Does nothing unless Workspace.Lane3_IslandEnvironment exists; the place streams in to a
-- joining client over several seconds, so it waits for the falls without a time limit.

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ROOT_NAME = "Lane3_IslandEnvironment"
local OVERRIDE = "Lane3ReducedMotionOverride"
local NEAR, FAR = 350, 900 -- studs from the camera to the falls (Tunable)
local FOUNTAIN_NEAR, FOUNTAIN_FAR = 120, 420 -- studs from the camera to the fountain (Tunable)
local FOUNTAIN_AT = Vector3.new(0, 2, 0)
local REFRESH = 0.25 -- seconds between updates

-- Reduced-motion multipliers by emitter name ending (Tunable)
local CALM: { [string]: number } = {
	Splash = 0.25,
	Plume = 0.6, -- the fountain keeps a calmer, still flowing jet
	Arc = 0.6,
	Droplets = 0.25,
	Whitewater = 0.3,
	Churn = 0.5,
	Ripples = 0.5,
	LowMist = 0.5,
	CliffMist = 0.5,
	GrottoDrips = 0.5,
	GrottoFireflies = 0,
}
local CALM_BEAM = 0.45

local player = Players.LocalPlayer

local function reducedMotion(): boolean
	local override = player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

local function calmFactor(name: string): number
	for suffix, f in CALM do
		if string.sub(name, -#suffix) == suffix then
			return f
		end
	end
	return 0.5
end

-- emitter rates under host by distance and reduced motion, from their BaseRate attributes
local function scaleEmitters(host: Instance, near: number, calm: boolean)
	for _, d in host:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local base = d:GetAttribute("BaseRate")
			if type(base) == "number" then
				local scale = if near > 0 then 0.35 + 0.65 * near else 0
				if calm then
					scale *= calmFactor(d.Name)
				end
				d.Rate = base * scale
			end
		end
	end
end

local function restoreEmitters(host: Instance)
	for _, d in host:GetDescendants() do
		if d:IsA("ParticleEmitter") and type(d:GetAttribute("BaseRate")) == "number" then
			d.Rate = d:GetAttribute("BaseRate") :: number
		end
	end
end

-- The grand fountain's slow choreography (after the distance and reduced-motion rates): the
-- plume rises and falls over 14 s (its lifetime follows, so it still lands in the top bowl); a
-- gentle wave runs round the eight arcs every 9 s, each arc a little fuller and longer as it
-- passes. Reduced motion holds the plume at a steady middle height and keeps every other arc
-- running, steady, so the display stays complete but calm.
local PLUME_PERIOD, WAVE_PERIOD = 14, 9
local G, PLUME_DROP = 26, 2.75 -- the plume's gravity and its fall from the nozzle to the top pool
local function choreograph(fountain: Instance, now: number, calm: boolean)
	local rise = if calm then 0.5 else 0.5 + 0.5 * math.sin(now * 2 * math.pi / PLUME_PERIOD)
	for _, d in fountain:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local base = d:GetAttribute("BaseSpeed")
			if type(base) == "number" then
				if d.Name == "Plume" or d.Name == "PlumeDroplets" then
					local v = base * (0.82 + 0.36 * rise)
					d.Speed = NumberRange.new(v - 0.5, v + 0.5)
					local life = (v + math.sqrt(v * v + 2 * G * PLUME_DROP)) / G
					d.Lifetime = NumberRange.new(life * 0.95, life * 1.02)
				elseif d.Name == "Arc" then
					local k = d:GetAttribute("Index") :: number? or 0
					if calm then
						d.Speed = NumberRange.new(base - 0.2, base + 0.2)
						if k % 2 == 1 then
							d.Rate = 0
						end
					else
						local w = 0.5 + 0.5 * math.sin(now * 2 * math.pi / WAVE_PERIOD - k * math.pi / 4)
						local v = base * (0.95 + 0.06 * w)
						d.Speed = NumberRange.new(v - 0.2, v + 0.2)
						d.Rate *= 0.6 + 0.4 * w
					end
				end
			end
		end
	end
end

local function animate(trove: Trove.Trove, root: Instance, waterfall: Instance)
	local host = waterfall:WaitForChild("WaterHost") :: BasePart
	local centre = Vector3.new(-102, 60, 280) -- the falls (Task 4: moved 18 east, Cascade.X)
	local last = 0
	local lanes: { Beam } = {}
	local lanesFolder: Instance? = nil
	local calmLanes: boolean? = nil
	trove:Connect(RunService.RenderStepped, function()
		local now = os.clock()
		-- boost lanes, every frame (a few dozen beams): a slow breathing glow
		local folder = root:FindFirstChild("BoostLanes")
		if folder ~= lanesFolder then
			lanesFolder = folder
			calmLanes = nil
			table.clear(lanes)
			if folder then
				for _, d in folder:GetChildren() do
					if d:IsA("Beam") and d:GetAttribute("BoostLane") then
						table.insert(lanes, d)
					end
				end
			end
		end
		local calmNow = reducedMotion()
		if calmNow then
			if calmLanes ~= true then
				for _, b in lanes do
					b.TextureSpeed = 0
					b.Transparency = NumberSequence.new(0.25)
				end
				calmLanes = true
			end
		else
			if calmLanes ~= false then
				for _, b in lanes do
					b.TextureSpeed = b:GetAttribute("BaseSpeed") :: number? or 0.6
				end
				calmLanes = false
			end
			for _, b in lanes do
				local phase = (b:GetAttribute("Avenue") :: number? or 0) * 0.9
				b.Transparency = NumberSequence.new(0.18 + 0.16 * (0.5 + 0.5 * math.sin(now * 2.1 + phase)))
			end
		end
		if now - last < REFRESH then
			return
		end
		last = now
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local distance = (camera.CFrame.Position - centre).Magnitude
		local near = 1 - math.clamp((distance - NEAR) / (FAR - NEAR), 0, 1)
		local calm = reducedMotion()
		scaleEmitters(host, near, calm)
		-- the park fountain (ParkDressing is rebuilt by redress, so it is looked up each time)
		local park = root:FindFirstChild("ParkDressing")
		local fountain = park and park:FindFirstChild("Fountain")
		if fountain then
			local d = (camera.CFrame.Position - FOUNTAIN_AT).Magnitude
			scaleEmitters(fountain, 1 - math.clamp((d - FOUNTAIN_NEAR) / (FOUNTAIN_FAR - FOUNTAIN_NEAR), 0, 1), calm)
			choreograph(fountain, now, calm)
			for _, b in fountain:GetDescendants() do
				if b:IsA("Beam") and type(b:GetAttribute("BaseSpeed")) == "number" then
					local speed = b:GetAttribute("BaseSpeed") :: number
					b.TextureSpeed = if calm then speed * 0.45 else speed
				end
			end
		end
		for _, d in waterfall:GetDescendants() do
			if d:IsA("Beam") then
				local base = d:GetAttribute("BaseSpeed")
				if type(base) == "number" then
					d.TextureSpeed = if calm then base * CALM_BEAM else base
				end
				local baseT = d:GetAttribute("BaseTransparency")
				if type(baseT) == "number" then
					-- the mist rainbow: always faintly there by day (the sun stands north of the
					-- falls, so a strictly physical rainbow would never show from the park), a
					-- little stronger with the sun behind the viewer, fading out far away
					local view = (centre - camera.CFrame.Position).Unit
					local antiSun = -Lighting:GetSunDirection()
					local align = math.clamp((view:Dot(antiSun) + 0.2) / 0.8, 0, 1)
					local visible = (0.7 + 0.3 * align) * (1 - math.clamp((distance - 650) / 350, 0, 1))
					local t = 1 - (1 - baseT) * visible
					-- a soft-ended bow (Task 4) keeps its clear feet: SoftEnds is the faded fraction
					-- at each end, the same shape as Waterfall.softEnds on the build side
					local ends = d:GetAttribute("SoftEnds")
					if type(ends) == "number" and ends > 0 and ends < 0.5 then
						d.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(ends, t),
							NumberSequenceKeypoint.new(1 - ends, t),
							NumberSequenceKeypoint.new(1, 1),
						})
					else
						d.Transparency = NumberSequence.new(t)
					end
				end
			end
		end
	end)
	trove:Add(function()
		-- leave the built settings in place
		restoreEmitters(waterfall)
		local park = root:FindFirstChild("ParkDressing")
		local fountain = park and park:FindFirstChild("Fountain")
		if fountain then
			restoreEmitters(fountain)
		end
		for _, d in waterfall:GetDescendants() do
			if d:IsA("Beam") and type(d:GetAttribute("BaseSpeed")) == "number" then
				d.TextureSpeed = d:GetAttribute("BaseSpeed") :: number
			end
		end
	end)
end

local current: Trove.Trove? = nil
local function attach(root: Instance)
	if current then
		current:Destroy()
	end
	local trove = Trove.new()
	current = trove
	trove:Add(task.spawn(function()
		animate(trove, root, root:WaitForChild("Waterfall"))
	end))
	trove:Connect(root.AncestryChanged, function()
		if not root:IsDescendantOf(Workspace) then
			trove:Destroy()
			if current == trove then
				current = nil
			end
		end
	end)
end

local existing = Workspace:FindFirstChild(ROOT_NAME)
if existing then
	attach(existing)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == ROOT_NAME then
		attach(child)
	end
end)
