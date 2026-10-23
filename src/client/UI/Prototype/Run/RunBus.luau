--!strict
-- Local coordination between the run HUD components (Lane 3 preview, HUD rebuild worker HR,
-- 2026-10-22). Not a component and not a game event system: a per-screen registry so siblings
-- that do not see each other can hand over (the capture ribbon flies a car icon into the claim
-- tray) and share the screen-slot arbiter with owner-counted suppression.
--
--   RunBus.priority(ctx) -> Arbiter          -- ctx.priority, else one shared fallback per screen
--   RunBus.register(ctx, key, object)        -- e.g. ClaimTray registers "tray"; cleared on destroy
--   RunBus.unregister(ctx, key, object)
--   RunBus.get(ctx, key) -> any?
--   RunBus.suppress(ctx, slot, level, owner) -- several owners may suppress one slot; the
--   RunBus.unsuppress(ctx, slot, owner)      -- arbiter floor is the highest live owner level,
--                                               cleared only when the last owner releases
--   RunBus.flags(ctx) -> { warning: boolean, ended: boolean }  -- per-run presentation flags
--                                               (RunEnd writes them; reset on a new run)
--
-- Registered keys (HR components): "tray" (ClaimTray), "banner" (DistrictBanner), "ribbon"
-- (CaptureRibbon), "runEnd" (RunEnd).

local Priority = require(script.Parent.Parent.Priority)

local RunBus = {}

type Bus = {
	objects: { [string]: any },
	suppress: { [string]: { [string]: string } }, -- slot -> owner -> level
	fallback: any?,
	flags: { warning: boolean, ended: boolean },
}

local buses: { [any]: Bus } = setmetatable({}, { __mode = "k" }) :: any

local function bus(ctx: any): Bus
	local key = ctx.screen
	local b = buses[key]
	if not b then
		b = { objects = {}, suppress = {}, fallback = nil, flags = { warning = false, ended = false } }
		buses[key] = b
	end
	return b :: Bus
end

function RunBus.priority(ctx: any): Priority.Arbiter
	if ctx.priority then
		return ctx.priority
	end
	local b = bus(ctx)
	if not b.fallback then
		b.fallback = Priority.new()
	end
	return b.fallback
end

function RunBus.register(ctx: any, key: string, object: any)
	bus(ctx).objects[key] = object
end

function RunBus.unregister(ctx: any, key: string, object: any)
	local b = bus(ctx)
	if b.objects[key] == object then
		b.objects[key] = nil
	end
end

function RunBus.get(ctx: any, key: string): any?
	return bus(ctx).objects[key]
end

function RunBus.flags(ctx: any): { warning: boolean, ended: boolean }
	return bus(ctx).flags
end

local function apply(ctx: any, slot: string)
	local b = bus(ctx)
	local owners = b.suppress[slot]
	local arb = RunBus.priority(ctx)
	local best: string? = nil
	if owners then
		for _, level in owners do
			if best == nil or Priority.Rank[level] > Priority.Rank[best :: string] then
				best = level
			end
		end
	end
	if best then
		arb:suppress(slot :: any, best :: any, "run")
	else
		arb:unsuppress(slot :: any, "run")
	end
end

function RunBus.suppress(ctx: any, slot: string, level: string, owner: string)
	local b = bus(ctx)
	local owners = b.suppress[slot]
	if not owners then
		owners = {}
		b.suppress[slot] = owners
	end
	(owners :: any)[owner] = level
	apply(ctx, slot)
end

function RunBus.unsuppress(ctx: any, slot: string, owner: string)
	local b = bus(ctx)
	local owners = b.suppress[slot]
	if not owners or owners[owner] == nil then
		return
	end
	owners[owner] = nil
	apply(ctx, slot)
end

function RunBus.suppressors(ctx: any): { [string]: { [string]: string } }
	local out = {}
	for slot, owners in bus(ctx).suppress do
		out[slot] = table.clone(owners)
	end
	return out
end

return RunBus
