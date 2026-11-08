--!strict
-- The fountain statue after dark (Brian L, 2026-11-08, for Adam's review). The island build (ParkDressing.decorateStatue)
-- makes the hoop's coloured spotlights and light shafts and the name signs' lights switched off, tagged StatueNightLight;
-- the name signs' SurfaceGuis are tagged StatueNightSign. Here, on each client: when Lighting.ClockTime is night
-- (before 6:18 or from 17:48), the lights turn on and the CAR CATCHERS text glows; in daylight they go back off.
-- Still light, no movement, so Reduce Motion needs nothing. The island has no day/night cycle yet: this waits for one.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Trove = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Trove"))

local LIGHT_TAG = "StatueNightLight"
local SIGN_TAG = "StatueNightSign"
local DUSK = 17.8
local DAWN = 6.3

local trove = Trove.new()
local night = false

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= DUSK or t < DAWN
end

local function applyLight(item: Instance)
	if item:IsA("Light") or item:IsA("Beam") then
		item.Enabled = night
	end
end

local function applySign(item: Instance)
	if item:IsA("SurfaceGui") then
		item.LightInfluence = if night then 0 else 0.15
		item.Brightness = if night then 2.2 else 1
	end
end

local function applyAll()
	for _, item in CollectionService:GetTagged(LIGHT_TAG) do
		applyLight(item)
	end
	for _, item in CollectionService:GetTagged(SIGN_TAG) do
		applySign(item)
	end
end

local function check()
	local now = isNight()
	if now ~= night then
		night = now
		applyAll()
	end
end

-- streamed-in or rebuilt parts take the current state as they arrive
trove:Connect(CollectionService:GetInstanceAddedSignal(LIGHT_TAG), applyLight)
trove:Connect(CollectionService:GetInstanceAddedSignal(SIGN_TAG), applySign)
trove:Connect(Lighting:GetPropertyChangedSignal("ClockTime"), check)
night = isNight()
applyAll()
