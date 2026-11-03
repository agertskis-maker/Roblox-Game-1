--!strict
-- The group-join seam for the group reward pop-up (big round M16). It holds three things:
--
--   1. The GATEWAY the pop-up talks to. realGateway() wraps the two supported calls (verified against the Roblox docs in
--      BRIEF M16-02a): GroupService:PromptJoinAsync(groupId) -> Enum.GroupMembershipStatus and
--      Player:IsInGroupAsync(groupId) -> boolean, plus GroupService:GetGroupInfoAsync for the displayed name (a read).
--      fakeGateway(script) answers from a script and counts its calls, so an automated test can drive every outcome and
--      nobody joins for real. The pop-up calls the gateway ONLY on a deliberate JOIN press, inside pcall.
--   2. The SESSION GATE: when the optional pop-up may appear (BRIEF M16-03a). It is a per-session cap only: the real
--      once-per-day gate across rejoins needs persistent state or a server policy (Brian L) and is NOT claimed here.
--   3. The named test presets.
--
-- Client prompt success is not authority to grant anything: the claim is server-verified and economy-related, so the real
-- grant, the once-only entitlement and the daily gate are Brian L's. Nothing here grants, buys or promises a reward. The
-- release-policy question for a cosmetic join reward is UNVERIFIED (BRIEF M16-02c); this is a preview, not an approval.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")

local GroupFixtures = {}

GroupFixtures.GroupId = 74306252
GroupFixtures.GroupName = "LEGION STUDI0S" -- as the brief spells it (a zero); the pop-up shows the confirmed name

export type Calls = { prompt: number, isInGroup: number, name: number }

export type Gateway = {
	isFake: boolean,
	calls: Calls,
	-- the group's displayed name, or nil when it cannot be confirmed (a read; never prompts)
	groupName: (groupId: number) -> string?,
	-- GroupService:PromptJoinAsync: the GroupMembershipStatus NAME ("Joined", "AlreadyMember", "JoinRequestPending",
	-- "None"). It may yield and may throw (the pop-up wraps it in pcall).
	promptJoin: (groupId: number) -> string,
	-- Player:IsInGroupAsync for the local player
	isInGroup: (groupId: number) -> boolean,
}

-- The real calls. Only a deliberate JOIN press reaches promptJoin; build this only for the beta, never for a test.
function GroupFixtures.realGateway(): Gateway
	local calls: Calls = { prompt = 0, isInGroup = 0, name = 0 }
	local service = GroupService :: any
	return {
		isFake = false,
		calls = calls,
		groupName = function(groupId: number): string?
			calls.name += 1
			local info = service:GetGroupInfoAsync(groupId)
			return if info and type(info.Name) == "string" then info.Name else nil
		end,
		promptJoin = function(groupId: number): string
			calls.prompt += 1
			local status = service:PromptJoinAsync(groupId)
			return (status :: any).Name
		end,
		isInGroup = function(groupId: number): boolean
			calls.isInGroup += 1
			local player = Players.LocalPlayer :: any
			return player:IsInGroupAsync(groupId) == true
		end,
	}
end

export type FakeScript = {
	name: string?, -- the displayed name the fake reports (default GroupFixtures.GroupName)
	nameUnavailable: boolean?, -- the name cannot be confirmed
	outcomes: { string }?, -- promptJoin answers in order; the last one repeats. "Error" makes the call throw.
	member: boolean?, -- isInGroup before any join (default false)
	isInGroupError: boolean?,
	delay: number?, -- seconds a prompt takes to answer (default 0.4: the Roblox prompt is not instant)
}

-- A scripted gateway: no network, no prompt, no join. Counts every call so a test can prove "one prompt per JOIN".
function GroupFixtures.fakeGateway(config: FakeScript?): Gateway
	local cfg: FakeScript = config or {}
	local calls: Calls = { prompt = 0, isInGroup = 0, name = 0 }
	local member = cfg.member == true
	local outcomes = cfg.outcomes or { "Joined" }
	return {
		isFake = true,
		calls = calls,
		groupName = function(_groupId: number): string?
			calls.name += 1
			if cfg.nameUnavailable then
				return nil
			end
			return cfg.name or GroupFixtures.GroupName
		end,
		promptJoin = function(_groupId: number): string
			calls.prompt += 1
			task.wait(cfg.delay or 0.4)
			local outcome = outcomes[math.min(calls.prompt, #outcomes)]
			if outcome == "Error" then
				error("fake PromptJoinAsync failure")
			end
			if outcome == "Joined" or outcome == "AlreadyMember" then
				member = true
			end
			return outcome
		end,
		isInGroup = function(_groupId: number): boolean
			calls.isInGroup += 1
			if cfg.isInGroupError then
				error("fake IsInGroupAsync failure")
			end
			return member
		end,
	}
end

-- THE SESSION GATE ---------------------------------------------------------------------------

export type GateInputs = {
	isRunning: () -> boolean, -- a run is in progress (never offer during one)
	isTutorialActive: () -> boolean, -- the tutorial has not finished
	isCardOpen: () -> boolean, -- a welcome, results, shop or other modal is open
	isMember: (() -> boolean?)?, -- nil = unknown; true = already in the group
}

export type Gate = {
	check: (self: Gate) -> (boolean, string),
	recordShown: (self: Gate) -> (),
	recordDismissed: (self: Gate) -> (),
	reset: (self: Gate) -> (),
	state: (self: Gate) -> { shown: boolean, dismissed: boolean },
}

-- May the optional pop-up appear now? Only after the tutorial and any welcome or results card have closed, never during a
-- run, never to a member, and at most once for the rest of this SESSION: a dismissal (or any showing) uses the one offer up.
-- `reset` starts a new session for a test. This is not a daily cap and does not pretend to be one.
function GroupFixtures.newGate(inputs: GateInputs): Gate
	local shown = false
	local dismissed = false
	local gate: Gate
	gate = {
		check = function(_self: Gate): (boolean, string)
			if dismissed then
				return false, "DismissedThisSession"
			elseif shown then
				return false, "ShownThisSession"
			elseif inputs.isRunning() then
				return false, "Running"
			elseif inputs.isTutorialActive() then
				return false, "Tutorial"
			elseif inputs.isCardOpen() then
				return false, "CardOpen"
			end
			local member = if inputs.isMember then inputs.isMember() else nil
			if member == true then
				return false, "AlreadyMember"
			end
			return true, "Ok"
		end,
		recordShown = function(_self: Gate)
			shown = true
		end,
		recordDismissed = function(_self: Gate)
			dismissed = true
		end,
		reset = function(_self: Gate)
			shown = false
			dismissed = false
		end,
		state = function(_self: Gate): { shown: boolean, dismissed: boolean }
			return { shown = shown, dismissed = dismissed }
		end,
	}
	return gate
end

-- PRESETS ------------------------------------------------------------------------------------

export type View =
	"Checking"
	| "Unavailable"
	| "Offer"
	| "Prompting"
	| "Joined"
	| "Member"
	| "Pending"
	| "TryLater"
	| "Error"
	| "Claimed"

export type Preset = { view: View?, config: FakeScript? }

-- `view` forces the pop-up into that view directly; `config` scripts the fake gateway so a real JOIN press leads there.
-- Claimed is ONLY ever reached by selecting this preset: a join (real or fake) never shows CLAIMED.
GroupFixtures.Presets = table.freeze({
	Offer = { view = "Offer", config = { outcomes = { "Joined" } } },
	Offer_Joined = { view = "Offer", config = { outcomes = { "Joined" } } },
	Offer_AlreadyMember = { view = "Offer", config = { outcomes = { "AlreadyMember" } } },
	Offer_Pending = { view = "Offer", config = { outcomes = { "JoinRequestPending" } } },
	Offer_Cancelled = { view = "Offer", config = { outcomes = { "None" } } },
	Offer_ApiFailure = { view = "Offer", config = { outcomes = { "Error" } } },
	Offer_FailThenJoin = { view = "Offer", config = { outcomes = { "Error", "Joined" } } },
	Offer_NameUnavailable = { view = nil, config = { nameUnavailable = true } },
	Offer_Slow = { view = "Offer", config = { outcomes = { "Joined" }, delay = 2.5 } },
	Member = { view = "Member", config = { member = true } },
	Joined = { view = "Joined" },
	Pending = { view = "Pending" },
	TryLater = { view = "TryLater" },
	Error = { view = "Error" },
	Unavailable = { view = "Unavailable" },
	Claimed = { view = "Claimed" },
} :: { [string]: Preset })

GroupFixtures.PresetNames = table.freeze({
	"Offer",
	"Offer_Joined",
	"Offer_AlreadyMember",
	"Offer_Pending",
	"Offer_Cancelled",
	"Offer_ApiFailure",
	"Offer_FailThenJoin",
	"Offer_NameUnavailable",
	"Offer_Slow",
	"Member",
	"Joined",
	"Pending",
	"TryLater",
	"Error",
	"Unavailable",
	"Claimed",
})

-- The message of each outcome view (BRIEF M16-02b). Joined, AlreadyMember and an existing member all say "You're in!".
GroupFixtures.Messages = table.freeze({
	Checking = "Checking the group...",
	Unavailable = "Group details are unavailable right now.",
	Prompting = "Opening the group...",
	Joined = "You're in!",
	Member = "You're in!",
	Pending = "Request sent",
	TryLater = "You can try again later",
	Error = "Could not open the group. Try again.",
	Claimed = "CLAIMED",
})

-- Whether a displayed group name is the expected community (spacing and case ignored).
function GroupFixtures.nameMatches(name: string?): boolean
	if name == nil then
		return false
	end
	local function clean(s: string): string
		return (string.lower(s):gsub("%s+", ""))
	end
	return clean(name) == clean(GroupFixtures.GroupName)
end

return GroupFixtures
