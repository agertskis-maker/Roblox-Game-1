--!strict
-- Day and night cycle PREVIEW (written for Brian L; lighting is Lane 3's area, so Adam owns the
-- real version). Runs only where Workspace has the attribute Lane2DayCyclePreview = true. Timing
-- follows Minecraft's 20-minute day: 10 min day, 1.5 min sunset, 7 min night, 1.5 min sunrise.
-- The server sets Lighting (it replicates to every client) and blends between three looks: Adam's
-- midday island look, an orange dusk and a calm blue night, never too dark (players are mostly
-- children). Workspace attribute DayCycleSpeed (default 1) speeds it up for testing; the current
-- part of the day is published as the Workspace attribute DayPhase.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

if Workspace:GetAttribute("Lane2DayCyclePreview") ~= true then
	return
end

type Look = {
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	exposure: number,
	atmDensity: number,
	atmOffset: number,
	atmColor: Color3,
	atmDecay: Color3,
	atmGlare: number,
	atmHaze: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	rays: number,
	bloom: number,
	clouds: Color3,
}

-- Adam's island look at midday (read from the place on 2026-11-03).
local DAY: Look = {
	brightness = 3.14,
	ambient = Color3.fromRGB(110, 118, 130),
	outdoor = Color3.fromRGB(150, 160, 175),
	exposure = 0,
	atmDensity = 0.31,
	atmOffset = 0.06,
	atmColor = Color3.fromRGB(196, 220, 240),
	atmDecay = Color3.fromRGB(120, 160, 200),
	atmGlare = 0.15,
	atmHaze = 1.4,
	tint = Color3.fromRGB(255, 255, 255),
	saturation = 0.12,
	contrast = 0.08,
	rays = 0.04,
	bloom = 0,
	clouds = Color3.fromRGB(255, 255, 255),
}

local DUSK: Look = {
	brightness = 2.6,
	ambient = Color3.fromRGB(140, 105, 100),
	outdoor = Color3.fromRGB(190, 140, 115),
	exposure = 0.1,
	atmDensity = 0.34,
	atmOffset = 0.55,
	atmColor = Color3.fromRGB(255, 170, 105),
	atmDecay = Color3.fromRGB(255, 140, 90),
	atmGlare = 0.35,
	atmHaze = 2.4,
	tint = Color3.fromRGB(255, 198, 150),
	saturation = 0.3,
	contrast = 0.12,
	rays = 0.08,
	bloom = 0.15,
	clouds = Color3.fromRGB(255, 200, 170),
}

local NIGHT: Look = {
	brightness = 1.6,
	ambient = Color3.fromRGB(85, 95, 130),
	outdoor = Color3.fromRGB(115, 130, 170),
	exposure = 0.35,
	atmDensity = 0.3,
	atmOffset = 0.1,
	atmColor = Color3.fromRGB(110, 125, 170),
	atmDecay = Color3.fromRGB(60, 75, 120),
	atmGlare = 0,
	atmHaze = 1,
	tint = Color3.fromRGB(205, 215, 255),
	saturation = 0.05,
	contrast = 0.05,
	rays = 0,
	bloom = 0.1,
	clouds = Color3.fromRGB(150, 160, 200),
}

-- One day, in seconds at speed 1: { name, start, length, clock from, clock to, look from, look to }.
type Phase = { name: string, length: number, clockFrom: number, clockTo: number, from: Look, mid: Look?, to: Look }

local PHASES: { Phase } = {
	{ name = "Day", length = 600, clockFrom = 7, clockTo = 17, from = DAY, to = DAY },
	{ name = "Sunset", length = 90, clockFrom = 17, clockTo = 19, from = DAY, mid = DUSK, to = NIGHT },
	{ name = "Night", length = 420, clockFrom = 19, clockTo = 29, from = NIGHT, to = NIGHT },
	{ name = "Sunrise", length = 90, clockFrom = 5, clockTo = 7, from = NIGHT, mid = DUSK, to = DAY },
}

local DAY_LENGTH = 0
for _, phase in PHASES do
	DAY_LENGTH += phase.length
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function blend(a: Look, b: Look, t: number): Look
	return {
		brightness = lerp(a.brightness, b.brightness, t),
		ambient = a.ambient:Lerp(b.ambient, t),
		outdoor = a.outdoor:Lerp(b.outdoor, t),
		exposure = lerp(a.exposure, b.exposure, t),
		atmDensity = lerp(a.atmDensity, b.atmDensity, t),
		atmOffset = lerp(a.atmOffset, b.atmOffset, t),
		atmColor = a.atmColor:Lerp(b.atmColor, t),
		atmDecay = a.atmDecay:Lerp(b.atmDecay, t),
		atmGlare = lerp(a.atmGlare, b.atmGlare, t),
		atmHaze = lerp(a.atmHaze, b.atmHaze, t),
		tint = a.tint:Lerp(b.tint, t),
		saturation = lerp(a.saturation, b.saturation, t),
		contrast = lerp(a.contrast, b.contrast, t),
		rays = lerp(a.rays, b.rays, t),
		bloom = lerp(a.bloom, b.bloom, t),
		clouds = a.clouds:Lerp(b.clouds, t),
	}
end

-- The look and clock time `seconds` into the day.
local function sample(seconds: number): (string, number, Look)
	local s = seconds % DAY_LENGTH
	for _, phase in PHASES do
		if s < phase.length then
			local t = s / phase.length
			local clock = lerp(phase.clockFrom, phase.clockTo, t) % 24
			local mid = phase.mid
			local look = if mid
				then (if t < 0.5 then blend(phase.from, mid, t * 2) else blend(mid, phase.to, (t - 0.5) * 2))
				else blend(phase.from, phase.to, t)
			return phase.name, clock, look
		end
		s -= phase.length
	end
	return PHASES[1].name, PHASES[1].clockFrom, DAY
end

local function find(className: string): Instance?
	return Lighting:FindFirstChildOfClass(className)
end

local function apply(clock: number, look: Look)
	Lighting.ClockTime = clock
	Lighting.Brightness = look.brightness
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	Lighting.ExposureCompensation = look.exposure
	local atm = find("Atmosphere")
	if atm and atm:IsA("Atmosphere") then
		atm.Density = look.atmDensity
		atm.Offset = look.atmOffset
		atm.Color = look.atmColor
		atm.Decay = look.atmDecay
		atm.Glare = look.atmGlare
		atm.Haze = look.atmHaze
	end
	local cc = find("ColorCorrectionEffect")
	if cc and cc:IsA("ColorCorrectionEffect") then
		cc.TintColor = look.tint
		cc.Saturation = look.saturation
		cc.Contrast = look.contrast
	end
	local rays = find("SunRaysEffect")
	if rays and rays:IsA("SunRaysEffect") then
		rays.Intensity = look.rays
	end
	local bloom = find("BloomEffect")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = look.bloom
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Color = look.clouds
	end
end

-- Start partway through the morning so a new server opens in daylight.
local elapsed = 120
local lastPhase = ""
while true do
	local dt = task.wait(0.2)
	local speed = Workspace:GetAttribute("DayCycleSpeed")
	elapsed += dt * (if typeof(speed) == "number" and speed > 0 then speed else 1)
	local name, clock, look = sample(elapsed)
	apply(clock, look)
	if name ~= lastPhase then
		lastPhase = name
		Workspace:SetAttribute("DayPhase", name)
	end
end
