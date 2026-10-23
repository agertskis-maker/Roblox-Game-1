--!strict
-- Hop state precedence (Lane 3 preview, Round 2, R2-P1). Pure: the single answer to "what does the Hop look
-- like right now", so the button, the target ring, the arc, the reticle and the tests agree.
--
-- Precedence, highest first (an unavailable or empty state must never advertise best timing):
--   OutOfStamina  the Stamina demo is on and the meter is empty
--   Cooldown      the supplied cooldown has not finished
--   NoTarget      the supplied hop state is Unavailable (no target, or one that cannot be used)
--   BestTiming    the supplied hop state is Timing (the best-timing window)
--   Ready
--
--   HopState.resolve(run) -> Display
--   HopState.worldMode(display) -> "Hidden" | "Grey" | "Ready" | "Best"   -- what the target cues show

local Store = require(script.Parent.Parent.Store)

local HopState = {}

export type Display = "Ready" | "BestTiming" | "Cooldown" | "NoTarget" | "OutOfStamina"
export type WorldMode = "Hidden" | "Grey" | "Ready" | "Best"

HopState.Order = table.freeze({ "OutOfStamina", "Cooldown", "NoTarget", "BestTiming", "Ready" })

function HopState.resolve(run: Store.RunState?): Display
	if run == nil then
		return "NoTarget"
	end
	local stamina = run.stamina
	if stamina ~= nil and stamina.value <= 0 then
		return "OutOfStamina"
	end
	if run.hopCooldown01 > 0.001 then
		return "Cooldown"
	end
	if run.hop == "Unavailable" then
		return "NoTarget"
	end
	if run.hop == "Timing" then
		return "BestTiming"
	end
	return "Ready"
end

-- With no usable hop the target cues step back: a grey ring while the target still exists (cooldown, empty
-- Stamina), nothing at all without one. They never show the ready or best look in those states.
function HopState.worldMode(display: Display): WorldMode
	if display == "BestTiming" then
		return "Best"
	elseif display == "Ready" then
		return "Ready"
	elseif display == "Cooldown" or display == "OutOfStamina" then
		return "Grey"
	end
	return "Hidden"
end

return HopState
