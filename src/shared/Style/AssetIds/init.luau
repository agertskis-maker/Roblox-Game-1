--!strict
-- AssetIds (Lane 3 Round 8, R8-S08; contract frozen by the lead): one registry for every image, mesh and sound this round adds.
-- Each workstream owns one sub-module (UpgradeCards, HopButton, Wheels, Trails, Clover, Hubs, Plots, Misc) so no two builders
-- edit the same file. The list of record with owners and sources is vault/design/assets.md.
--
--   AssetIds.image(key) -> string      "rbxassetid://<id>" once uploaded; before that, in Studio only and only in a local test
--                                      place with ReplicatedStorage.Lane3_LocalArt, "rbxasset://carhop/r8/<key>.png" (installed
--                                      by Car-Hop-Art/upload-round8/install-local-art.ps1); otherwise "" (the caller shows its
--                                      code-drawn fallback, so a live game never asks for a laptop-only file)
--   AssetIds.entry(key) -> Entry?      AssetIds.has(key) -> boolean (uploaded)    AssetIds.uploaded() -> boolean (all keys)
--   AssetIds.UseUploaded               the one switch from the code-drawn fallback to the uploaded art (U-05)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Types)

export type Entry = Types.Entry

local AssetIds = {}

AssetIds.UseUploaded = true

local all: { [string]: Entry } = {}
for _, name in { "UpgradeCards", "HopButton", "Wheels", "Trails", "Clover", "Hubs", "Plots", "Misc" } do
	local part = require(script:FindFirstChild(name) :: ModuleScript) :: { [string]: Entry }
	for key, entry in part do
		assert(all[key] == nil, "AssetIds: duplicate key " .. key)
		all[key] = entry
	end
end

local function localArt(): boolean
	return RunService:IsStudio() and ReplicatedStorage:FindFirstChild("Lane3_LocalArt") ~= nil
end

function AssetIds.entry(key: string): Entry?
	return all[key]
end

function AssetIds.has(key: string): boolean
	local e = all[key]
	return e ~= nil and e.id ~= nil
end

function AssetIds.image(key: string): string
	local e = all[key]
	if e == nil then
		return ""
	end
	if AssetIds.UseUploaded and e.id then
		return "rbxassetid://" .. tostring(e.id)
	end
	if localArt() then
		return "rbxasset://carhop/r8/" .. key .. ".png"
	end
	return ""
end

function AssetIds.uploaded(): boolean
	for _, e in all do
		if e.id == nil then
			return false
		end
	end
	return true
end

return AssetIds
