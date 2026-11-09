--!strict
-- PaintAuditHook (Round 8, C-04, V-02): lets the Studio MCP run the paint audit without require (execute_luau cannot require game
-- modules here). From a Server execute_luau during Play:
--   local r = game.ServerStorage.CarHopPaintAudit:Invoke({ verbose = true })   -- or { only = { "Putter" }, paints = { "magenta" } }
--   return table.concat(r.lines, "\n")
-- Beta places only (src/server/Beta is synced by beta.project.json). Read-only: it paints clones of the car models and removes them.

local ServerStorage = game:GetService("ServerStorage")

local PaintAudit = require(script.Parent.PaintAudit)

local hook = Instance.new("BindableFunction")
hook.Name = "CarHopPaintAudit"
hook.OnInvoke = function(options: any)
	return PaintAudit.run(options)
end
hook.Parent = ServerStorage
