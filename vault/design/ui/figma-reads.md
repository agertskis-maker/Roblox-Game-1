---
title: Figma read count
tags:
  - design
  - ui
---

# Figma read count

Lane 3 UI is Figma-first ([[0012-figma-ui-workflow]]). Adam's Figma account is on the free Starter plan, which allows **up to 6 read tool calls per month**; writes are exempt during the beta.

Rules:
- Report this month's count to Adam **before** any read, and read only after Adam says he edited a mockup by hand.
- Add one row per read call, immediately after it runs. A failed call that reached Figma still counts.
- Treat any tool that returns file content as a read (list in [[0012-figma-ui-workflow]]).

| Month | Reads used | Limit |
|---|---|---|
| 2026-10 | 4 | 6 |

## Read log

| Date | Tool | Screen / file | Why (Adam's hand edit) | Running count |
|---|---|---|---|---|
| 2026-10-21 | `whoami` | none (account and plan lookup) | Not a hand edit: Adam asked for the "Car Hop UI" file to be created for the island signs, and creating a file needs the plan key, which only `whoami` returns. Counted as a read per [[0012-figma-ui-workflow]] | 1 |
| 2026-10-21 | `use_figma` with `node.screenshot()` (one call, screenshots of several frames) | "Car Hop UI", page "Island signs" ([[island-signs]]) | Not a hand edit: one visual check of the newly drawn header pictures and a signpost board before sending the link to Adam, allowed by the session's 2-read budget. The four header pictures and "Signpost board – DUSTY HIGHWAY" came back; the stand front frames did not appear in the result and were not visually checked | 2 |
| 2026-10-22 | `get_screenshot` (node `9:410`, maxDimension 5440, scale 1) | "Car Hop UI", page "Island signs", frame "Export sheet" with a temporary review area ([[island-signs]], [[portal-sign]], [[plot-track-signs]]) | Not a hand edit: Adam's Task 3 brief allowed up to 2 more reads this session. One screenshot serves both the image export (stand headers, track banners, owner banner, nameplate and kiosk backgrounds at 100 px per stud) and the first visual check of the four stand front frames and the new mocks | 3 |
| 2026-10-22 | `get_screenshot` (node `9:410`, maxDimension 4160, scale 1) | "Car Hop UI", page "Island signs", frame "Export sheet" with a refreshed review area | Not a hand edit: second and last read allowed by the Task 3 brief. Verifies the fixes made after read 3 (stand fronts, banner clipping, PREVIEW tags) and is the final image export the PNG crops are cut from. No reads remain this month | 4 |
