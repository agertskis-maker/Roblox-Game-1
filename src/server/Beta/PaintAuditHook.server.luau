--!strict
-- PaintAuditHook (Round 8, C-04, V-02): lets the Studio MCP run the paint audit. execute_luau cannot require game modules or invoke a
-- BindableFunction here (it lacks the Network capability), but it can set an attribute and read a value, so the hook is state based.
-- From a Server execute_luau during Play (Studio only):
--   game.ServerStorage:SetAttribute("RunPaintAudit", "all")          -- every car, four paints
--   game.ServerStorage:SetAttribute("RunPaintAudit", "Putter,Zip")   -- only these models (full model names, comma separated)
-- then read game.ServerStorage.CarHopPaintAuditResult.Value (the report lines, one per line; "PAINT AUDIT: ... PASS" or "... FAIL"
-- is the last line) and watch the attribute "PaintAuditState" go from "running" to "done". Read-only: it paints clones of the car
-- models and removes them.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local PaintAudit = require(script.Parent.PaintAudit)

local result = Instance.new("StringValue")
result.Name = "CarHopPaintAuditResult"
result.Parent = ServerStorage

local running = false
ServerStorage:GetAttributeChangedSignal("RunPaintAudit"):Connect(function()
	local request = ServerStorage:GetAttribute("RunPaintAudit")
	if typeof(request) ~= "string" or request == "" or running then
		return
	end
	running = true
	ServerStorage:SetAttribute("PaintAuditState", "running")
	local only: { string }? = nil
	if request ~= "all" then
		only = string.split(request, ",")
	end
	local ok, report = pcall(PaintAudit.run, { only = only, verbose = true })
	if ok then
		result.Value = table.concat(report.lines, "\n")
	else
		result.Value = "PAINT AUDIT ERROR: " .. tostring(report)
	end
	ServerStorage:SetAttribute("RunPaintAudit", nil)
	ServerStorage:SetAttribute("PaintAuditState", "done")
	running = false
end)
