# UI build spec template (Lane 3, Figma-first)

Save as `vault/design/ui/<screen-name>.md`. This file, not Figma, is what the
build reads (`vault/decisions/0012-figma-ui-workflow.md`). Write it in the same
session that draws the Figma mockup, and keep the two in step.

```markdown
---
title: <Screen name>
tags: [design, ui]
status: draft | approved
---

# <Screen name>

- Figma: <link to the "Car Hop UI" file, page "<Screen name>">
- Frames: phone portrait <node id>, phone landscape <node id>, desktop <node id>
- Approval: pending | "Approved: ..." (Adam, <date>; also recorded in visual-direction.md)
- Hand edits in Figma since the spec was written: none | <what Adam changed, date>
- Figma reads used for this screen: 0 (monthly count: vault/design/ui/figma-reads.md)

## Purpose
Player goal, entry points, dismissal (close, back, tap outside), relationship
to the gameplay camera, and what the player can still do while it is open.

## Data and actions
| Control | Shows (source of the value) | Request it sends | Server owner (lane) |
|---|---|---|---|

## States
One row per state: loading, populated, empty, locked (with the missing
requirement), can't afford, pending, success, error/rejection, retry where safe,
plus long names, large values and narrow screens.

| State | What changes on screen | Text | Exit |
|---|---|---|---|

## Layout
Design pixels at UIScale 1.0 (the build scales once per widget root with
`Tokens.uiScaleFor`). Anchor, position and size per element, per frame.

| Element | Phone portrait | Phone landscape | Desktop | Token(s) |
|---|---|---|---|---|

Safe area and Roblox top-bar inset, thumb zones kept clear, and the minimum
touch target are taken from `Tokens.luau` and the live record in
`vault/design/visual-direction.md`; anything still marked undecided there is
written TBD here.

## Tokens used
Names exactly as in `src/shared/UI/Tokens.luau` (colour, text size, space,
radius, stroke, shadow). A value not in the module is a proposal for the module,
listed here and approved with the screen.

## Buttons
| Button | Enabled when | On press (acknowledgment) | On server result | Disabled reason shown |
|---|---|---|---|---|

## Motion
| Event | Property | From → to | Duration | Easing | Reduced motion |
|---|---|---|---|---|---|

## Assets
| Image | Drawn in Figma (node) | Exported file | Manifest row | Upload approved | Asset ID |
|---|---|---|---|---|---|
Asset IDs are filled in only after an approved upload; never invented.

## Open questions
```
