--!strict
-- Island ambience under test (Lane 3, client presentation only). Adam approved testing the three
-- proposed Creator Store sounds on 2026-10-21 (manifest: assets/island/kit/manifest.md):
--   the falls: a looped stream at the lower falls, positional, full near the water and fading
--     out across the lake (inverse-tapered roll-off);
--   birdsong: a quiet looped park ambience at the plaza that fades out into the mountains;
--   the duck: one shared timer for the duck family, a quack every 20 to 40 seconds (random),
--     played on the mother duck only while the family is near this client (Wildlife spawns it
--     near the camera); a missed quack is skipped, never queued, so there are no catch-up bursts.
-- No player volume setting or audio mix exists in the project yet, so the three sounds share one
-- SoundGroup ("Lane3Ambience") that a future approved setting can drive; nothing is saved.
-- Everything is removed with the environment (Trove).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ROOT_NAME = "Lane3_IslandEnvironment"
local FALLS_SOUND = "rbxassetid://9120552550" -- Waterfall Steady Stream 1 (SFX), Pro Sound Effects
local BIRDS_SOUND = "rbxassetid://9113444360" -- Birds Park 2 (SFX), Pro Sound Effects
local QUACK_SOUND = "rbxassetid://1845012569" -- Quack Duck, APM
local FALLS_AT = Vector3.new(-121, 22, 270)
local PARK_AT = Vector3.new(0, 12, -20)
local QUACK_MIN, QUACK_MAX = 20, 40 -- seconds between quacks (Tunable)

local function emitterPart(trove: Trove.Trove, name: string, at: Vector3): Part
	local p = trove:Add(Instance.new("Part"))
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(at)
	p.Parent = Workspace
	return p
end

local function sound(parent: Instance, group: SoundGroup, id: string, props: { [string]: any }): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.SoundGroup = group
	for k, v in props do
		(s :: any)[k] = v
	end
	s.Parent = parent
	return s
end

local function run(trove: Trove.Trove)
	local group = trove:Add(Instance.new("SoundGroup"))
	group.Name = "Lane3Ambience"
	group.Volume = 1
	group.Parent = SoundService

	local falls = sound(emitterPart(trove, "Lane3_FallsSound", FALLS_AT), group, FALLS_SOUND, {
		Name = "Falls",
		Looped = true,
		Volume = 0.55,
		RollOffMode = Enum.RollOffMode.InverseTapered,
		RollOffMinDistance = 45,
		RollOffMaxDistance = 420,
	})
	falls:Play()

	local birds = sound(emitterPart(trove, "Lane3_ParkSound", PARK_AT), group, BIRDS_SOUND, {
		Name = "Birds",
		Looped = true,
		Volume = 0.14,
		RollOffMode = Enum.RollOffMode.InverseTapered,
		RollOffMinDistance = 160,
		RollOffMaxDistance = 650,
	})
	birds:Play()

	-- one quack template (never played itself); each quack is a short-lived copy on the mother
	-- duck, so it follows her and goes when Wildlife removes her
	local quack = sound(group, group, QUACK_SOUND, {
		Name = "Lane3_Quack",
		Volume = 0.45,
		RollOffMode = Enum.RollOffMode.InverseTapered,
		RollOffMinDistance = 8,
		RollOffMaxDistance = 70,
	})
	local rng = Random.new()
	trove:Add(task.spawn(function()
		while true do
			task.wait(rng:NextNumber(QUACK_MIN, QUACK_MAX))
			local live = Workspace:FindFirstChild("Lane3_Wildlife")
			local duck = live and live:FindFirstChild("Duck")
			if duck and duck:IsA("BasePart") then
				local q = quack:Clone()
				q.Parent = duck
				q.Ended:Once(function()
					q:Destroy()
				end)
				q:Play()
			end
		end
	end))
end

local current: Trove.Trove? = nil
local function attach(root: Instance)
	if current then
		current:Destroy()
	end
	local trove = Trove.new()
	current = trove
	run(trove)
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
