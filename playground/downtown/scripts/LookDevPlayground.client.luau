--!strict
-- PLAYGROUND BOOTSTRAP (Lane 3 Downtown look development, overnight preview 2026-10-22). Runs
-- only in the dedicated Downtown look-dev place: it needs Studio AND
-- ReplicatedStorage.Lane3Playground with attribute Kind == "downtown", which exists only in
-- playground/downtown.project.json. The game's default.project.json maps neither this script
-- nor src/lookdev nor that marker, so real players and ordinary game Play sessions never load it.
--
-- In Play it starts the ambient accents (client-local) and listens for look-dev commands, so a
-- server-side MCP call can drive the client camera without remotes: set the marker attribute
--   ReplicatedStorage.Lane3Playground:SetAttribute("LookDevCommand", "<unique id> <verb> <arg>")
-- verbs: pass | sample <seconds> | frame <s> | ped <1|2> | restore | ambient <on|off> |
--        reduced <on|off> (the preview-only Lane3ReducedMotionOverride; never saved) | stats
-- Results are printed as "[Lane3LookDev] <verb> <json>" for get_console_output.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local marker = ReplicatedStorage:FindFirstChild("Lane3Playground")
if not (RunService:IsStudio() and marker and marker:GetAttribute("Kind") == "downtown") then
	return
end

local Downtown = ReplicatedStorage:WaitForChild("LookDev"):WaitForChild("Downtown")
local Ambient = require(Downtown:WaitForChild("Ambient"))
local ChaseCamera = require(Downtown:WaitForChild("ChaseCamera"))

local function report(verb: string, value: any)
	local ok, json = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	print("[Lane3LookDev] " .. verb .. " " .. (if ok then json else tostring(value)))
end

local function run(command: string)
	local words = string.split(command, " ")
	local verb, arg = words[2], words[3]
	if verb == "pass" then
		if not ChaseCamera.isRunning() then
			ChaseCamera.pass({ async = true })
		end
		report("pass", "started")
	elseif verb == "sample" then
		if ChaseCamera.isRunning() then
			report("sample", "busy")
			return
		end
		task.spawn(function()
			report("sample", ChaseCamera.sample(tonumber(arg) or 7.2))
		end)
	elseif verb == "frame" then
		local frame = ChaseCamera.frame(tonumber(arg) or 30)
		report("frame", { s = frame.s, label = frame.label })
	elseif verb == "ped" then
		local frame = ChaseCamera.pedestrian(tonumber(arg) or 1)
		report("ped", { s = frame.s, label = frame.label })
	elseif verb == "restore" then
		ChaseCamera.stop()
		ChaseCamera.restore()
		report("restore", "ok")
	elseif verb == "ambient" then
		if arg == "off" then
			Ambient.stop()
			report("ambient", "off")
		else
			report("ambient", Ambient.start())
		end
	elseif verb == "reduced" then
		Players.LocalPlayer:SetAttribute("Lane3ReducedMotionOverride", if arg == "on" then true else nil)
		report("reduced", arg == "on")
	elseif verb == "stats" then
		report("stats", Ambient.stats())
	else
		report("unknown", command)
	end
end

marker:GetAttributeChangedSignal("LookDevCommand"):Connect(function()
	local command = marker:GetAttribute("LookDevCommand")
	if type(command) == "string" and command ~= "" then
		local ok, err = pcall(run, command)
		if not ok then
			report("error", tostring(err))
		end
	end
end)

report("ambient", Ambient.start())
