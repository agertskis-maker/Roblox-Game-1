# Worked example (validation case)

Illustration only; no art style has been approved.

## Input

Owner attaches a screenshot of a popular garden game's shop and writes: "Make our
shop look like this but cooler, and make buying feel amazing."

## Expected output (abridged)

Observed (visible): bottom-centered panel about 60% of screen width; chunky
rounded corners; thick dark outline on every panel and button; vertical
gradient lighter at top; large bold rounded font with an outline; item cards in
a 3-column grid with a price chip under each; bright green primary button,
grey disabled button; soft drop shadow; saturated pastel palette.

Inferred, not proven by the image: how restock timers work, what happens on
purchase, animation timing, whether the font is custom, asset ownership.

Questions (one batch; only the ones whose answer changes the design):
1. Must we keep the bottom-centered layout, or only the chunky outlined style?
2. Does "buying feel amazing" mean a big celebration on every purchase, or only
   on rare items? (Changes timing budget and audio stacking.)

Brief highlights: palette roles (green = affordable primary action, grey with a
lock icon = unaffordable, gold edge = rare tier), outlined rounded panels as the
single surface style, one celebration tier for common buys (about 0.3 s pop and
a soft chime) and a bigger reveal only for rare items.

Roblox translation: UICorner + UIStroke + UIGradient on a shared style; price
chips never rely on color alone (lock icon + text); purchase button shows a
pending state until the server confirms; reduced-motion skips the pop scale.

Sample before spreading: the shop panel, one purchase reward, one locked item,
captured on phone and desktop sizes.

Not copied: the reference game's logo, item art, mascot, or fonts it may own.

## Pass criteria

Visible and inferred properties are separated; every question asked is one
whose answer would change the design, and all are in one batch; reversible
details (timings, radii, exact colors inside the named roles) are decided and
labelled "my proposal", not asked; nothing already settled by the project
rules (such as not copying assets) is asked; every choice is labelled reference vs
proposal; a sample is planned before full rollout; no protected assets reused;
purchase feedback waits for the server.
