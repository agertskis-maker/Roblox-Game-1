--!strict
-- PREVIEW content for the "What's new" panel (Round 2 N11-02). The panel takes its list as DATA; this is the sample list the
-- playground shows. It is NOT a release note: the team writes the real list from what actually works in the beta, and marks a
-- planned idea PREVIEW instead of mixing it in with the shipped notes (N11-02a). Nothing here claims a date.

local UpdateFixtures = {}

UpdateFixtures.Source = "PREVIEW sample list: replace it with what really works in the beta"

export type Entry = {
	icon: string, -- a painter name ("Moon", "Shop", "Garage", "Medal", "Missions" ...)
	title: string,
	text: string?,
	preview: boolean?, -- a planned example, shown with a PREVIEW tag
}

export type Content = {
	version: string?, -- an explicit content version; nil derives one from the entries
	preview: boolean?, -- the whole list is a sample: the panel shows its PREVIEW stamp
	header: string?,
	entries: { Entry },
	details: { string }?, -- optional "More details" paragraphs, behind a scroll
}

-- Four shipped-style notes (sample) and a short details section.
function UpdateFixtures.sample(): Content
	return {
		preview = true,
		header = "WHAT'S NEW",
		entries = {
			{ icon = "Moon", title = "Welcome back card", text = "See what your cars earned while you were away." },
			{ icon = "Shop", title = "A livelier Shop", text = "Bright moving backgrounds and new icons." },
			{ icon = "Medal", title = "Stunt Circuit screens", text = "Pre-race, results and top times." },
			{
				icon = "PaintBucket",
				title = "Paint, decals and wheels",
				text = "Try them on a turntable car.",
				preview = true,
			},
		},
		details = {
			"This is a PREVIEW sample list. The real notes are written from what works in the beta.",
			"Prices and progress in these screens are made up for review. Nothing is charged or saved.",
		},
	}
end

-- A second list with a different set of notes (so the once-per-version rule can be seen to change with the content).
function UpdateFixtures.next(): Content
	return {
		preview = true,
		header = "WHAT'S NEW",
		entries = {
			{ icon = "Garage", title = "Garage index", text = "Worlds, silhouettes and a completion bar." },
			{ icon = "Info", title = "Coach Roxy", text = "Friendly help cards for locked roads." },
		},
	}
end

return UpdateFixtures
