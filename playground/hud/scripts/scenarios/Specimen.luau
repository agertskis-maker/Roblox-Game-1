--!strict
-- PLAYGROUND ONLY (Lane 3 preview, worker HA). Specimen sheet scenarios: they call methods on the
-- mounted component host.api.components.specimen (the lead mounts it hidden, Overlay layer) and
-- never create one themselves, so a cancelled scenario leaves nothing behind. The Home and Run
-- HUD pieces are hidden while the sheet shows; the next scenario's applyMode restores them.
-- Hide the sheet again with the component's setVisible(false) (or "Specimen: off").

local HOME_AND_RUN = {
	"stats",
	"timers",
	"menu",
	"tutorial",
	"route",
	"run",
	"ride",
	"strip",
	"heat",
	"tray",
	"keys",
	"hop",
	"dash",
	"nameplates",
}

local function specimen(host: any): any?
	local c = host.api.components.specimen
	if not c then
		host.log('Specimen not mounted: add mount("specimen", { "Specimen" }, "Overlay")')
	end
	return c
end

local function showAlone(host: any, s: any, mode: string)
	for _, key in HOME_AND_RUN do
		local c = host.api.components[key]
		if c and c.setVisible then
			c:setVisible(false)
		end
	end
	s:setMode(mode)
	s:setVisible(true)
	local state = s:getDebugState()
	host.log(
		"Specimen "
			.. mode
			.. ": "
			.. tostring(state.frames)
			.. " frames, icons "
			.. table.concat(state.iconsDrawn, ", ")
			.. (if #state.iconFallbacks > 0 then "; FALLBACKS " .. table.concat(state.iconFallbacks, ", ") else "")
			.. (if #state.overBudget > 0 then "; OVER BUDGET " .. table.concat(state.overBudget, ", ") else "")
	)
end

return {
	["Specimen: composed"] = function(host: any)
		local s = specimen(host)
		if s then
			showAlone(host, s, "Composed")
		end
	end,
	["Specimen: gallery"] = function(host: any)
		local s = specimen(host)
		if s then
			showAlone(host, s, "Gallery")
		end
	end,
	["Specimen: off"] = function(host: any)
		local s = specimen(host)
		if s then
			s:setVisible(false)
			host.api.applyMode()
		end
	end,
}
