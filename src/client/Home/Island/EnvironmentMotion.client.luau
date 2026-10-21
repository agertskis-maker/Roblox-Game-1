--!strict
-- Island environment motion (Lane 3, client presentation only). The waterfall's beams scroll
-- on their own; this script scales the activity around them, time-based and cheap:
--   distance: particle rates full near the falls, reduced in the middle distance and off far
--     away (the beams keep a moving impression from every plot);
--   reduced motion: beam scroll slowed but still flowing, spray, droplets and whitewater cut
--     back hard, mist and ripples halved, fireflies off;
--   rainbow: strongest when the sun is behind the viewer, faded otherwise and far away.
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
local REFRESH = 0.25 -- seconds between updates

-- Reduced-motion multipliers by emitter name ending (Tunable)
local CALM: { [string]: number } = {
	Splash = 0.25,
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

local function animate(trove: Trove.Trove, waterfall: Instance)
	local host = waterfall:WaitForChild("WaterHost") :: BasePart
	local centre = Vector3.new(-120, 60, 280)
	local last = 0
	trove:Connect(RunService.RenderStepped, function()
		local now = os.clock()
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
		for _, d in waterfall:GetDescendants() do
			if d:IsA("Beam") then
				local base = d:GetAttribute("BaseSpeed")
				if type(base) == "number" then
					d.TextureSpeed = if calm then base * CALM_BEAM else base
				end
				local baseT = d:GetAttribute("BaseTransparency")
				if type(baseT) == "number" then
					-- a rainbow shows with the sun behind the viewer, looking into the spray
					local view = (centre - camera.CFrame.Position).Unit
					local antiSun = -Lighting:GetSunDirection()
					local align = math.clamp((view:Dot(antiSun) - 0.35) / 0.45, 0, 1)
					local visible = align * (1 - math.clamp((distance - 500) / 400, 0, 1))
					local t = 1 - (1 - baseT) * visible
					d.Transparency = NumberSequence.new(t)
				end
			end
		end
	end)
	trove:Add(function()
		-- leave the built settings in place
		for _, d in waterfall:GetDescendants() do
			if d:IsA("ParticleEmitter") and type(d:GetAttribute("BaseRate")) == "number" then
				d.Rate = d:GetAttribute("BaseRate") :: number
			elseif d:IsA("Beam") and type(d:GetAttribute("BaseSpeed")) == "number" then
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
		animate(trove, root:WaitForChild("Waterfall"))
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
