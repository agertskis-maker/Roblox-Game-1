--!strict
-- Trails.Textures (Round 8, T-12): one place that turns a trail art name ("flare", "beam_fire", "whoosh") into the texture string,
-- the flipbook layout and the frame count an emitter, beam or sound needs. The art is registered in
-- src/shared/Style/AssetIds/Trails.luau (ParticleFX Studio free sheets, own gap fillers, own loops). Until the lead has uploaded a
-- file, AssetIds.image(key) gives the local test path in Studio (or "" in a live game); then this module hands back Roblox's own
-- built-in particle texture instead, with no flipbook, so a trail always draws something.
--
--   Textures.get("smoke_puff") -> Sheet     { texture, layout, frames, uploaded }
--   Textures.sound("whoosh") -> string      "rbxassetid://..." once uploaded, else a built-in Roblox sound
--   Textures.uri(name) -> string            "" when there is no art yet (beam and ribbon textures: plain colour instead)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)

local Textures = {}

export type Sheet = {
	texture: string,
	layout: Enum.ParticleFlipbookLayout,
	frames: number,
	uploaded: boolean, -- true when the real art is in use (local test path or uploaded id)
}

local P = "rbxasset://textures/particles/"
local SPARKLES = P .. "sparkles_main.dds"
local SMOKE = P .. "smoke_main.dds"
local FIRE = P .. "fire_main.dds"
local SOFT = P .. "forcefield_glow_main.dds"
local SQUARE = P .. "SquareParticle.png"

-- what to use before the art is uploaded (Roblox built-in; "" means no texture at all)
local FALLBACK: { [string]: string } = {
	smoke_puff = SMOKE,
	mist = SMOKE,
	backfire = FIRE,
	stars = SPARKLES,
	flare = SOFT,
	coin = SPARKLES,
	ice = SPARKLES,
	snow = SPARKLES,
	slime = SOFT,
	galaxy = SMOKE,
	bolt = SPARKLES,
	chain = SPARKLES,
	crown = SPARKLES,
	flutter = SQUARE,
	bill = SQUARE,
	petal = SQUARE,
	bubble = SOFT,
	glow = SOFT,
	grid = "",
	aurora = "",
	beam_fire = "",
	beam_lightning = "",
	beam_arc = "",
	beam_energy = "",
	beam_strands = "",
}

local LAYOUT: { [number]: Enum.ParticleFlipbookLayout } = {
	[4] = Enum.ParticleFlipbookLayout.Grid2x2,
	[16] = Enum.ParticleFlipbookLayout.Grid4x4,
	[64] = Enum.ParticleFlipbookLayout.Grid8x8,
}

local function key(name: string): string
	return "r8_trail_fx_" .. name
end

function Textures.get(name: string): Sheet
	local k = key(name)
	local uri = AssetIds.image(k)
	if uri ~= "" then
		local entry = AssetIds.entry(k)
		local frames = if entry and entry.frames then entry.frames else 1
		return {
			texture = uri,
			layout = LAYOUT[frames] or Enum.ParticleFlipbookLayout.None,
			frames = frames,
			uploaded = true,
		}
	end
	return {
		texture = FALLBACK[name] or SOFT,
		layout = Enum.ParticleFlipbookLayout.None,
		frames = 1,
		uploaded = false,
	}
end

function Textures.uri(name: string): string
	return Textures.get(name).texture
end

-- Soft loops (Epic and up). Only an uploaded id is used; the local-art path is for images. Before the upload Roblox's own free-fall
-- wind loop (rbxasset://sounds/action_falling.ogg, ships with the engine) stands in, very quiet.
local BUILTIN_SOUND = "rbxasset://sounds/action_falling.ogg"

function Textures.sound(name: string): string
	local soundKey = "r8_trail_snd_" .. name
	local entry = AssetIds.entry(soundKey)
	if entry and entry.id then
		return "rbxassetid://" .. tostring(entry.id)
	end
	-- a local Studio test place (ReplicatedStorage.Lane3_LocalArt) plays the file straight from the content folder
	if RunService:IsStudio() and ReplicatedStorage:FindFirstChild("Lane3_LocalArt") ~= nil then
		return "rbxasset://carhop/r8/" .. soundKey .. ".ogg"
	end
	return BUILTIN_SOUND
end

return Textures
