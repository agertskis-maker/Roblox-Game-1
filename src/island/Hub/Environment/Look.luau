--!strict
-- Island environment look (Lane 3, build-time, private island place only): terrain material
-- colours, water, Lighting, Atmosphere, Clouds and colour effects. Place-wide settings, so the
-- first apply saves every original value as attributes on the environment's state folder,
-- and restore() puts them back and removes only the instances this module made (named
-- "Lane3_Env*"). Two restrained daylight presets for the environment review.

local Lighting = game:GetService("Lighting")

local Palette = require(script.Parent.Parent.Parent.WorldPalette)

local Look = {}

local SAVED = "Saved_"
local rgb = Color3.fromRGB

Look.TerrainColours = {
	[Enum.Material.Grass] = Palette.Grass,
	[Enum.Material.Rock] = rgb(118, 126, 134),
	[Enum.Material.Slate] = rgb(166, 177, 190),
	[Enum.Material.Snow] = rgb(242, 247, 252),
	[Enum.Material.Sand] = rgb(230, 214, 166),
	[Enum.Material.Limestone] = rgb(172, 170, 160),
	[Enum.Material.Ground] = rgb(112, 132, 82),
}

Look.Water = {
	WaterColor = rgb(40, 196, 188),
	WaterTransparency = 0.5,
	WaterReflectance = 0.35,
	WaterWaveSize = 0.06,
	WaterWaveSpeed = 6,
}

local LIGHTING_PROPS = {
	"ClockTime",
	"GeographicLatitude",
	"Brightness",
	"Ambient",
	"OutdoorAmbient",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"GlobalShadows",
	"ShadowSoftness",
}

export type Preset = {
	lighting: { [string]: any },
	atmosphere: { [string]: any },
	clouds: { [string]: any },
	bloom: { [string]: any },
	colour: { [string]: any },
	sunRays: { [string]: any },
}

Look.Presets = {
	-- A: crisp, high sun, light haze that still separates the far range
	ClearAlpine = {
		lighting = {
			ClockTime = 13.6,
			GeographicLatitude = -30, -- sun to the north, behind players who face the range
			Brightness = 2.2,
			Ambient = rgb(110, 118, 130),
			OutdoorAmbient = rgb(150, 160, 175),
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
			ExposureCompensation = -0.15,
			GlobalShadows = true,
			ShadowSoftness = 0.35,
		},
		atmosphere = {
			Density = 0.31,
			Offset = 0.06,
			Color = rgb(196, 220, 240),
			Decay = rgb(120, 160, 200),
			Glare = 0.15,
			Haze = 1.4,
		},
		clouds = { Cover = 0.5, Density = 0.55, Color = rgb(255, 255, 255) },
		bloom = { Intensity = 0.25, Size = 24, Threshold = 1.4 },
		colour = { Saturation = 0.12, Contrast = 0.08, Brightness = 0, TintColor = rgb(255, 255, 255) },
		sunRays = { Intensity = 0.04, Spread = 0.6 },
	} :: Preset,
	-- B: later afternoon, softer warm haze that layers the ranges more strongly
	SoftHaze = {
		lighting = {
			ClockTime = 15.3,
			GeographicLatitude = -30, -- sun to the north, behind players who face the range
			Brightness = 2.3,
			Ambient = rgb(120, 118, 125),
			OutdoorAmbient = rgb(160, 158, 165),
			EnvironmentDiffuseScale = 0.7,
			EnvironmentSpecularScale = 0.4,
			ExposureCompensation = 0,
			GlobalShadows = true,
			ShadowSoftness = 0.5,
		},
		atmosphere = {
			Density = 0.36,
			Offset = 0.3,
			Color = rgb(214, 222, 232),
			Decay = rgb(150, 165, 195),
			Glare = 0.35,
			Haze = 2.0,
		},
		clouds = { Cover = 0.62, Density = 0.5, Color = rgb(255, 252, 248) },
		bloom = { Intensity = 0.35, Size = 28, Threshold = 1.3 },
		colour = { Saturation = 0.05, Contrast = 0.03, Brightness = 0.01, TintColor = rgb(255, 250, 244) },
		sunRays = { Intensity = 0.06, Spread = 0.7 },
	} :: Preset,
}

local function save(state: Instance, key: string, value: any)
	if state:GetAttribute(SAVED .. key) == nil and value ~= nil then
		state:SetAttribute(SAVED .. key, value)
	end
end

-- Saves every original value once (later calls keep the first capture).
function Look.capture(state: Instance)
	if state:GetAttribute(SAVED .. "Captured") then
		return
	end
	local terrain = workspace.Terrain
	for material in Look.TerrainColours do
		save(state, "Material_" .. material.Name, terrain:GetMaterialColor(material))
	end
	for key in Look.Water do
		save(state, "Terrain_" .. key, (terrain :: any)[key])
	end
	for _, key in LIGHTING_PROPS do
		save(state, "Lighting_" .. key, (Lighting :: any)[key])
	end
	-- existing effects we change in place (Bloom, ColorGrading); their absence is recorded too
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	state:SetAttribute(SAVED .. "HadBloom", bloom ~= nil)
	if bloom then
		save(state, "Bloom_Enabled", bloom.Enabled)
		save(state, "Bloom_Intensity", bloom.Intensity)
		save(state, "Bloom_Size", bloom.Size)
		save(state, "Bloom_Threshold", bloom.Threshold)
	end
	state:SetAttribute(SAVED .. "Captured", true)
end

local function ensure(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function assign(inst: Instance, props: { [string]: any })
	for key, value in props do
		(inst :: any)[key] = value
	end
end

function Look.applyTerrain()
	local terrain = workspace.Terrain
	for material, colour in Look.TerrainColours do
		terrain:SetMaterialColor(material, colour)
	end
	assign(terrain, Look.Water)
end

function Look.applyPreset(state: Instance, name: string)
	local preset = (Look.Presets :: any)[name] :: Preset
	assert(preset, "no preset " .. name)
	assert(state:GetAttribute(SAVED .. "Captured"), "capture the original look first")
	assign(Lighting, preset.lighting)
	-- the place has no Atmosphere, Clouds, ColorCorrection or SunRays of its own; ours are named
	assign(ensure(Lighting, "Atmosphere", "Lane3_EnvAtmosphere"), preset.atmosphere)
	assign(ensure(workspace.Terrain, "Clouds", "Lane3_EnvClouds"), preset.clouds)
	assign(ensure(Lighting, "ColorCorrectionEffect", "Lane3_EnvColour"), preset.colour)
	assign(ensure(Lighting, "SunRaysEffect", "Lane3_EnvSunRays"), preset.sunRays)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = true
		assign(bloom, preset.bloom)
	end
	state:SetAttribute("Preset", name)
end

function Look.restore(state: Instance)
	if not state:GetAttribute(SAVED .. "Captured") then
		return
	end
	local terrain = workspace.Terrain
	for name, value in state:GetAttributes() do
		if string.sub(name, 1, #SAVED) == SAVED then
			local key = string.sub(name, #SAVED + 1)
			local material = string.match(key, "^Material_(.+)$")
			local terrainKey = string.match(key, "^Terrain_(.+)$")
			local lightingKey = string.match(key, "^Lighting_(.+)$")
			local bloomKey = string.match(key, "^Bloom_(.+)$")
			if material then
				terrain:SetMaterialColor((Enum.Material :: any)[material], value)
			elseif terrainKey then
				(terrain :: any)[terrainKey] = value
			elseif lightingKey then
				(Lighting :: any)[lightingKey] = value
			elseif bloomKey then
				local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
				if bloom then
					(bloom :: any)[bloomKey] = value
				end
			end
		end
	end
	for _, parent in { Lighting, workspace.Terrain } do
		for _, child in (parent :: Instance):GetChildren() do
			if string.sub(child.Name, 1, 8) == "Lane3_En" then
				child:Destroy()
			end
		end
	end
	state:SetAttribute("Preset", nil)
end

return Look
