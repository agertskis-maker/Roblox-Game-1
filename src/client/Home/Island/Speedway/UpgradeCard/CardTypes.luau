--!strict
-- UpgradeCard.CardTypes (Lane 3 Round 8, U-01/U-02): the contract between ShopPanel (the one door every upgrade card opens through)
-- and the two card modules, RacewayCard (WS-6a) and ParkingCard (WS-6b). Types only.
--
-- A card module returns a table with these functions (ShopPanel calls them, one card open at a time):
--   Card.open(source: Source, host: Host)     builds and shows the card (replacing a card of its own that is already open)
--   Card.close(instant: boolean?)             fades the card out (instant: destroy at once). Closing never changes any value.
--   Card.isOpen() -> boolean
--   Card.plot() -> Model?                     the plot of the open card (nil when none)
--   Card.refresh()                            the world changed (level or spot count): re-read source.current() and redraw
--   Card.state() -> { [string]: any }         for Studio tests (open, shown, max, state, ...)
-- ShopPanel keeps the public API it always had (ShopPanel.open / close / isOpen / openPlot / refresh / state / cashOf / onMoreSpots /
-- onLineup / openHome / CloseDistance) and forwards to the card of the source's kind.

local CardTypes = {}

export type Kind = "upgrade" | "parking"

export type Source = {
	kind: Kind,
	plot: Model,
	-- the prompt's part: the card closes when the local character is farther than Host.closeDistance from it
	anchor: BasePart,
	-- the level (1..12) or owned spots (2..15) the world shows now
	current: () -> number,
	-- true while the world's reveal for a change is still running
	busy: () -> boolean,
	-- nil = no enabled purchase action (runtime outside the Studio preview and the beta). The argument is the value the card
	-- expects to reach, for the Studio preview only; the live game's remote takes no arguments and the server prices.
	buy: ((target: number) -> ())?,
}

export type Host = {
	-- the server's Cash as a number, or nil when there is no live server (then nothing is compared)
	cashOf: () -> number?,
	-- "Get more spots" on a full parking card (opens the Shop on the Expanded Paddock pass), nil when not wired
	onMoreSpots: (() -> ())?,
	-- the green "+" of a cannot-afford button: opens the Shop's Cash page, nil when not wired
	onCashShop: (() -> ())?,
	-- close the open card when the character is farther than this from source.anchor (studs)
	closeDistance: number,
	-- closes whatever card is open (all cards share one door)
	closeAll: (instant: boolean?) -> (),
}

return CardTypes
