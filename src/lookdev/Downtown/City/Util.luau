--!strict
-- Small shared helpers for the Downtown B city preview (Lane 3).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = {}

-- Roblox's Reduce Motion setting, plus the preview-only override attribute (never saved), as
-- approved for Lane 3 (AGENTS.md "Reduced motion").
function Util.reducedMotion(): boolean
	local player = Players.LocalPlayer
	if player and player:GetAttribute("Lane3ReducedMotionOverride") == true then
		return true
	end
	return GuiService.ReducedMotionEnabled
end

-- Signals that change reducedMotion(), for live updates.
function Util.reducedMotionSignals(): { RBXScriptSignal }
	local list = { GuiService:GetPropertyChangedSignal("ReducedMotionEnabled") }
	local player = Players.LocalPlayer
	if player then
		table.insert(list, player:GetAttributeChangedSignal("Lane3ReducedMotionOverride"))
	end
	return list
end

-- Where an on-screen review label can live: the player's PlayerGui in Play, CoreGui in edit
-- mode (the command bar may write there), else nil (labels are then skipped).
function Util.guiParent(): Instance?
	if RunService:IsRunning() then
		local player = Players.LocalPlayer
		return player and player:FindFirstChildOfClass("PlayerGui")
	end
	local ok, core = pcall(function()
		local service = game:GetService("CoreGui")
		local _ = service.Name -- touching it throws without plugin security
		return service
	end)
	return if ok then core else nil
end

function Util.round(x: number, places: number?): number
	local m = 10 ^ (places or 1)
	return math.floor(x * m + 0.5) / m
end

-- 1234567 -> "1,234,567" (whole studs for readouts).
function Util.commas(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s
	while true do
		local replaced, k = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		out = replaced
		if k == 0 then
			break
		end
	end
	return out
end

-- Frame-time summary of a list of deltas (seconds).
export type Sample = {
	mode: string,
	seconds: number,
	frames: number,
	meanMs: number,
	p95Ms: number,
	maxMs: number,
	over33ms: number,
	meanFps: number,
	note: string,
}

function Util.summarise(times: { number }, seconds: number): Sample
	local n = #times
	local sum, max, over = 0, 0, 0
	for _, dt in times do
		sum += dt
		max = math.max(max, dt)
		if dt > 1 / 30 then
			over += 1
		end
	end
	local sorted = table.clone(times)
	table.sort(sorted)
	local p95 = if n > 0 then sorted[math.clamp(math.ceil(n * 0.95), 1, n)] else 0
	local mean = if n > 0 then sum / n else 0
	local play = RunService:IsRunning() and RunService:IsClient()
	local function ms(x: number): number
		return math.floor(x * 100000 + 0.5) / 100
	end
	return {
		mode = if play then "play-client (RenderStepped deltas)" else "studio-edit (Heartbeat deltas)",
		seconds = seconds,
		frames = n,
		meanMs = ms(mean),
		p95Ms = ms(p95),
		maxMs = ms(max),
		over33ms = over,
		meanFps = if mean > 0 then math.floor(10 / mean + 0.5) / 10 else 0,
		note = if play
			then "Play client frame times on this machine (not a phone)"
			else "Studio edit-mode timing on this machine; not a Play or device measurement",
	}
end

return Util
