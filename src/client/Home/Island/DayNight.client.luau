--!strict
-- Day and night on the island (Brian L, 2026-11-08, for Adam's review as the Lane 3 owner). Each client runs the same clock
-- from the server's time, so every player in a server sees the same time of day. One cycle is 17 minutes:
--   day 9 min (7:30 to 16:30), dusk 2 min (to 19:12), night 4 min (to 5:00), dawn 2 min (to 7:30).
-- Daytime is the island's own look as built (Adam's Look preset): its values are read once at start and used as the day
-- keyframe. Dusk and dawn warm everything to orange and pink; night is a friendly blue, never pitch black (the players are
-- mostly children), with stars and a big moon. Clouds take the colour of the time of day.
--
-- It pauses while a Launch Pad or a run has its own lighting (the LookDev Assembler marks Lighting with
-- Lane3LookDevOriginal_* attributes while that is on) and picks up again when the island lighting comes back.
--
-- Cost on every device: one small update every 0.25 s that sets a handful of Lighting properties; no new effects, no shadow
-- toggles, nothing per frame. The sun moving is slow enough that Reduce Motion needs nothing.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local rgb = Color3.fromRGB
local PAUSE_ATTRIBUTE = "Lane3LookDevOriginal_ClockTime"
local STEP = 0.25
-- Studio only: set this number attribute on Lighting during Play (for example 21) to hold that hour, to preview night.
local PREVIEW_ATTRIBUTE = "DayNightPreviewHour"

-- the cycle: { seconds this part lasts, clock hour it starts at, clock hour it ends at }
local PARTS = {
	{ 9 * 60, 7.5, 16.5 }, -- day
	{ 2 * 60, 16.5, 19.2 }, -- dusk
	{ 4 * 60, 19.2, 29.0 }, -- night (29 = 5:00 the next morning)
	{ 2 * 60, 5.0, 7.5 }, -- dawn
}
local CYCLE = 0
for _, part in PARTS do
	CYCLE += part[1]
end

type Look = {
	Brightness: number,
	ExposureCompensation: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereDensity: number,
	AtmosphereHaze: number,
	AtmosphereGlare: number,
	Tint: Color3,
	TintBrightness: number,
	CloudColor: Color3,
	SunRays: number,
	Bloom: number,
}

local DUSK: Look = {
	Brightness = 1.7,
	ExposureCompensation = 0.1,
	Ambient = rgb(125, 100, 100),
	OutdoorAmbient = rgb(175, 128, 116),
	AtmosphereColor = rgb(255, 176, 138),
	AtmosphereDecay = rgb(205, 112, 125),
	AtmosphereDensity = 0.36,
	AtmosphereHaze = 2.2,
	AtmosphereGlare = 0.6,
	Tint = rgb(255, 226, 206),
	TintBrightness = 0,
	CloudColor = rgb(255, 196, 176),
	SunRays = 0.12,
	Bloom = 0.4,
}

local NIGHT: Look = {
	Brightness = 0.7,
	ExposureCompensation = 0.3,
	Ambient = rgb(78, 88, 128),
	OutdoorAmbient = rgb(96, 110, 156),
	AtmosphereColor = rgb(46, 62, 110),
	AtmosphereDecay = rgb(28, 34, 76),
	AtmosphereDensity = 0.32,
	AtmosphereHaze = 1.0,
	AtmosphereGlare = 0,
	Tint = rgb(205, 218, 255),
	TintBrightness = 0.03,
	CloudColor = rgb(126, 136, 176),
	SunRays = 0,
	Bloom = 0.5,
}

local trove = Trove.new()
local day: Look? = nil

local function find(className: string, parent: Instance): Instance?
	return parent:FindFirstChildOfClass(className)
end

-- The island's own look, read once, as the day keyframe.
local function readDay(): Look
	local atmosphere = find("Atmosphere", Lighting) :: Atmosphere?
	local colour = find("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect?
	local clouds = find("Clouds", Workspace.Terrain) :: Clouds?
	local rays = find("SunRaysEffect", Lighting) :: SunRaysEffect?
	local bloom = find("BloomEffect", Lighting) :: BloomEffect?
	return {
		Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		AtmosphereColor = if atmosphere then atmosphere.Color else rgb(196, 220, 240),
		AtmosphereDecay = if atmosphere then atmosphere.Decay else rgb(120, 160, 200),
		AtmosphereDensity = if atmosphere then atmosphere.Density else 0.3,
		AtmosphereHaze = if atmosphere then atmosphere.Haze else 1.4,
		AtmosphereGlare = if atmosphere then atmosphere.Glare else 0.15,
		Tint = if colour then colour.TintColor else rgb(255, 255, 255),
		TintBrightness = if colour then colour.Brightness else 0,
		CloudColor = if clouds then clouds.Color else rgb(255, 255, 255),
		SunRays = if rays then rays.Intensity else 0.04,
		Bloom = if bloom then bloom.Intensity else 0.25,
	}
end

local function mix(a: Look, b: Look, t: number): Look
	local out: { [string]: any } = {}
	for key, value in a :: any do
		local other = (b :: any)[key]
		if typeof(value) == "Color3" then
			out[key] = (value :: Color3):Lerp(other, t)
		else
			out[key] = value + (other - value) * t
		end
	end
	return out :: any
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The clock hour now (0 to 24) and how far into night (0 = day, 1 = night) and into dusk/dawn colour (0 to 1).
local function clockNow(): number
	local preview = if RunService:IsStudio() then Lighting:GetAttribute(PREVIEW_ATTRIBUTE) else nil
	if type(preview) == "number" then
		return preview % 24
	end
	local s = Workspace:GetServerTimeNow() % CYCLE
	for _, part in PARTS do
		if s < part[1] then
			local hour = part[2] + (part[3] - part[2]) * (s / part[1])
			return hour % 24
		end
		s -= part[1]
	end
	return 12
end

-- Day -> dusk -> night -> dawn -> day, by clock hour.
local function lookAt(hour: number, dayLook: Look): Look
	if hour >= 7.5 and hour < 16.5 then
		return dayLook
	elseif hour >= 16.5 and hour < 18.0 then
		return mix(dayLook, DUSK, smooth((hour - 16.5) / 1.5))
	elseif hour >= 18.0 and hour < 19.2 then
		return mix(DUSK, NIGHT, smooth((hour - 18.0) / 1.2))
	elseif hour >= 5.0 and hour < 6.2 then
		return mix(NIGHT, DUSK, smooth((hour - 5.0) / 1.2))
	elseif hour >= 6.2 and hour < 7.5 then
		return mix(DUSK, dayLook, smooth((hour - 6.2) / 1.3))
	end
	return NIGHT
end

local function apply(hour: number, look: Look)
	Lighting.ClockTime = hour
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = look.ExposureCompensation
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	local atmosphere = find("Atmosphere", Lighting) :: Atmosphere?
	if atmosphere then
		atmosphere.Color = look.AtmosphereColor
		atmosphere.Decay = look.AtmosphereDecay
		atmosphere.Density = look.AtmosphereDensity
		atmosphere.Haze = look.AtmosphereHaze
		atmosphere.Glare = look.AtmosphereGlare
	end
	local colour = find("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect?
	if colour then
		colour.TintColor = look.Tint
		colour.Brightness = look.TintBrightness
	end
	local clouds = find("Clouds", Workspace.Terrain) :: Clouds?
	if clouds then
		clouds.Color = look.CloudColor
	end
	local rays = find("SunRaysEffect", Lighting) :: SunRaysEffect?
	if rays then
		rays.Intensity = look.SunRays
	end
	local bloom = find("BloomEffect", Lighting) :: BloomEffect?
	if bloom then
		bloom.Intensity = look.Bloom
	end
end

-- Stars and a big, friendly moon. No new sky images: the default sky, which Roblox darkens at night.
local function ensureSky()
	local sky = find("Sky", Lighting) :: Sky?
	if not sky then
		local made = Instance.new("Sky")
		made.Name = "Lane3_DayNightSky"
		made.Parent = Lighting
		sky = made
	end
	assert(sky, "Sky")
	sky.StarCount = 3000
	sky.MoonAngularSize = 16
	sky.SunAngularSize = 18
	sky.CelestialBodiesShown = true
end

ensureSky()
trove:Add(task.spawn(function()
	while true do
		if Lighting:GetAttribute(PAUSE_ATTRIBUTE) == nil then
			if not day then
				day = readDay()
			end
			local hour = clockNow()
			apply(hour, lookAt(hour, day :: Look))
		end
		task.wait(STEP)
	end
end))
