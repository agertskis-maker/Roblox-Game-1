--!strict
-- Haptics (Lane 3 preview, Round 2, R2-V2). One short confirmation cue, BEST EFFORT and OFF BY DEFAULT: it plays only
-- when the local setting store.settings.haptics is true, through a HapticEffect (UINotification) created under pcall, so a
-- platform without support does nothing and raises nothing. No documented API reports whether a device really vibrated
-- (HapticService is deprecated and answers only for gamepad motors), so the result here is "requested", never
-- "felt". It is UNTESTED ON HARDWARE: an emulator or desktop run is not tactile evidence. One cue per call; the caller
-- plays it once per confirmed claim, with no repeated or escalating vibration.
--
--   Haptics.confirm(enabled: boolean) -> "off" | "requested" | "unsupported"
--   Haptics.counts() -> { requested: number, off: number, unsupported: number }

local Workspace = game:GetService("Workspace")

local Haptics = {}

local counts = { requested = 0, off = 0, unsupported = 0 }

function Haptics.confirm(enabled: boolean): string
	if not enabled then
		counts.off += 1
		return "off"
	end
	local ok = pcall(function()
		local effect = Instance.new("HapticEffect")
		effect.Type = Enum.HapticEffectType.UINotification
		effect.Looped = false
		effect.Parent = Workspace
		effect:Play()
		task.delay(1.5, function()
			effect:Destroy()
		end)
	end)
	if ok then
		counts.requested += 1
		return "requested"
	end
	counts.unsupported += 1
	return "unsupported"
end

function Haptics.counts(): { requested: number, off: number, unsupported: number }
	return table.clone(counts)
end

return Haptics
