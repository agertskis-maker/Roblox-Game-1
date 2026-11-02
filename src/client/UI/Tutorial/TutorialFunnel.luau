--!strict
-- TutorialFunnel: a LOCAL SPY that records the onboarding funnel events the tutorial INTENDS to send (BRIEF M11-10 and
-- M11-10a/b). It sends nothing, anywhere. There is no server code in this round.
--
-- What the official API allows (read from the Roblox documentation named in the brief, not re-checked here):
--   AnalyticsService:LogOnboardingFunnelStepEvent(player: Player, step: number, stepName: string, customFields: Dictionary)
--   "Events can only be sent from the server and in published games." A client cannot send it, a Studio play session
--   cannot deliver it, and this spy therefore proves only WHICH calls would be made and that duplicates are suppressed.
--   It cannot prove delivery to live analytics. Do not publish just to test this.
-- Proposal for Brian L (who owns real purchase and server analytics):
--   * One funnel STEP per completed tutorial step: funnel step = tutorial index + 1 (1 to 12), name = the step key.
--   * Skip is NEVER logged as completion of the remaining steps. Started and Skipped are separate custom events
--     ("TutorialStarted", "TutorialSkipped", "TutorialStepUnavailable"), also only intended.
--   * Replay sessions carry session = "replay" and are kept out of first-time funnel claims.
--   * The tutorial reports to a server relay (a RemoteEvent that does not exist yet) which calls the API above; the client
--     never sends an amount, a price or a result.
--
-- API
--   Funnel.new(player: Player?) -> Funnel
--   funnel:setSession("first" | "replay")
--   funnel:started(stepIndex, stepKey)            intended custom event "TutorialStepStarted" (deduplicated per session)
--   funnel:completed(stepIndex, stepKey, fields?) intended LogOnboardingFunnelStepEvent (deduplicated per session)
--   funnel:skipped(stepIndex, stepKey)            intended custom event "TutorialSkipped" (once per session)
--   funnel:unavailable(stepIndex, stepKey, why)   intended custom event: the step could not run (never counted as completed)
--   funnel:getLog() -> { Entry }  funnel:count(api) -> number  funnel:getDebugState()  funnel:reset()

local Players = game:GetService("Players")

local Funnel = {}
Funnel.__index = Funnel

export type Entry = {
	order: number,
	api: string, -- "LogOnboardingFunnelStepEvent" (official) or the proposed custom event name
	official: boolean,
	step: number?, -- funnel step 1 to 12 (official calls only)
	stepName: string?,
	session: string, -- "first" | "replay"
	fields: { [string]: any },
	at: number, -- os.clock()
}

export type Funnel = typeof(setmetatable(
	{} :: {
		_player: Player?,
		_log: { Entry },
		_seen: { [string]: boolean },
		_session: string,
		_suppressed: number,
	},
	Funnel
))

function Funnel.new(player: Player?): Funnel
	return setmetatable({
		_player = player or Players.LocalPlayer,
		_log = {},
		_seen = {},
		_session = "first",
		_suppressed = 0,
	}, Funnel)
end

function Funnel.setSession(self: Funnel, session: string)
	if session ~= self._session then
		self._session = session
		self._seen = {} -- a new session may log each step again; the replay flag keeps it out of first-time claims
	end
end

local function once(self: Funnel, key: string): boolean
	local full = self._session .. ":" .. key
	if self._seen[full] then
		self._suppressed += 1
		return false
	end
	self._seen[full] = true
	return true
end

local function record(
	self: Funnel,
	api: string,
	official: boolean,
	step: number?,
	stepName: string?,
	fields: { [string]: any }?
)
	local f: { [string]: any } = if fields then table.clone(fields) else {}
	f.session = self._session
	table.insert(self._log, {
		order = #self._log + 1,
		api = api,
		official = official,
		step = step,
		stepName = stepName,
		session = self._session,
		fields = f,
		at = os.clock(),
	})
end

function Funnel.started(self: Funnel, stepIndex: number, stepKey: string)
	if once(self, "started:" .. stepIndex) then
		record(self, "TutorialStepStarted", false, stepIndex + 1, stepKey, nil)
	end
end

function Funnel.completed(self: Funnel, stepIndex: number, stepKey: string, fields: { [string]: any }?)
	if once(self, "completed:" .. stepIndex) then
		record(self, "LogOnboardingFunnelStepEvent", true, stepIndex + 1, stepKey, fields)
	end
end

function Funnel.skipped(self: Funnel, stepIndex: number, stepKey: string)
	if once(self, "skipped") then
		record(self, "TutorialSkipped", false, stepIndex + 1, stepKey, nil)
	end
end

function Funnel.unavailable(self: Funnel, stepIndex: number, stepKey: string, why: string)
	if once(self, "unavailable:" .. stepIndex) then
		record(self, "TutorialStepUnavailable", false, stepIndex + 1, stepKey, { reason = why })
	end
end

function Funnel.getLog(self: Funnel): { Entry }
	return table.clone(self._log)
end

function Funnel.count(self: Funnel, api: string): number
	local n = 0
	for _, e in self._log do
		if e.api == api then
			n += 1
		end
	end
	return n
end

function Funnel.reset(self: Funnel)
	table.clear(self._log)
	self._seen = {}
	self._suppressed = 0
end

function Funnel.getDebugState(self: Funnel): { [string]: any }
	local official: { number } = {}
	for _, e in self._log do
		if e.official and e.step then
			table.insert(official, e.step)
		end
	end
	return {
		NOTE = "intended calls only; nothing is sent (server-only, published-game-only API)",
		session = self._session,
		entries = #self._log,
		completedFunnelSteps = official,
		duplicatesSuppressed = self._suppressed,
		started = Funnel.count(self, "TutorialStepStarted"),
		skipped = Funnel.count(self, "TutorialSkipped"),
		unavailable = Funnel.count(self, "TutorialStepUnavailable"),
	}
end

return Funnel
