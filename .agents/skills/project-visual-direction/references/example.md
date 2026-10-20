# Worked example (validation case)

Illustration only; no art style has been approved.

## Input

Owner attaches a screenshot of a popular garden game's shop and writes: "Make our
shop look like this but cooler, and make buying feel amazing." The shop opens
from a HUD button during play.

## Expected output (abridged)

Observed (visible): bottom-centered panel about 60% of screen width; chunky
rounded corners; thick dark outline on every panel and button; vertical
gradient lighter at top; large bold rounded font with an outline; item cards in
a 3-column grid with a price chip under each; bright green primary button,
grey disabled button; soft drop shadow; saturated pastel palette. Not shown:
camera angle, lighting, motion, sound.

Inferred, not proven by the image: how restock timers work, what happens on
purchase, animation timing, whether the font is custom, asset ownership.

Qualities I plan to preserve (confirm in the same batch): the chunky outlined
rounded style, the 3-column card grid with price chips, green for the primary
action and grey for disabled. Everything not confirmed is inspiration.

Questions (one batch; only the ones whose answer changes the design):
1. Must we keep the bottom-centered layout, or only the chunky outlined style?
2. Does "buying feel amazing" mean a big celebration on every purchase, or only
   on rare items? (Changes timing budget and audio stacking.)

Decided by me (my proposal, reversible): corner radius, stroke weight,
"cooler" read as an accent color plus one signature shape motif, timings,
sound, reduced-motion route. Fonts and touch-target size stay TBD until the
concept is chosen and the owner approves; no values are hard-coded.

Brief highlights: palette roles (green = affordable primary action, grey with a
lock icon = unaffordable, gold edge = rare tier), outlined rounded panels as the
single surface style, one celebration tier for common buys (about 0.3 s pop and
a soft chime) and a bigger reveal only for rare items.

Roblox translation: UICorner + UIStroke + UIGradient on one shared style token
module in `src/shared` (provisional; not the Studio Style Editor); price chips
never rely on color alone (lock icon + text); purchase button shows a pending
state until the server confirms; reduced-motion skips the pop scale.

Sample before spreading: the shop panel as an overlay on a placeholder
gameplay view (it opens during play), one purchase reward, one locked item,
captured on phone and desktop sizes. The repository owner (or the area owner,
once assigned) approves it, and the approval is recorded in
`vault/design/visual-direction.md`. A one-line board claim covers the
design-only brief.

Not copied: the reference game's logo, item art, mascot, icons, unlicensed
fonts, names, or a near-identical recreation of its screen. Imitating the
outline, rounded-panel, palette-mood, and grid-layout traits is allowed.

## Pass criteria

Visible and inferred properties are separated; every question asked is one
whose answer would change the design, and all are in one batch with no fixed
cap; reversible details are decided and labelled "my proposal", not asked;
nothing already settled by the project rules is asked; the qualities to
preserve are listed for confirmation in the same batch; fonts and touch-target
size are left TBD rather than hard-coded; every choice is labelled reference vs
proposal; a sample is planned before full rollout, reviewed as an overlay on
the gameplay view because the shop opens during play, with who approves it and
where it is recorded; style traits are imitated and no protected assets are
reused; purchase feedback waits for the server.
