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
| 2026-10 | 2 | 6 |

## Read log

| Date | Tool | Screen / file | Why (Adam's hand edit) | Running count |
|---|---|---|---|---|
| 2026-10-21 | `whoami` | none (account and plan lookup) | Not a hand edit: Adam asked for the "Car Hop UI" file to be created for the island signs, and creating a file needs the plan key, which only `whoami` returns. Counted as a read per [[0012-figma-ui-workflow]] | 1 |
| 2026-10-21 | `use_figma` with `node.screenshot()` (one call, screenshots of several frames) | "Car Hop UI", page "Island signs" ([[island-signs]]) | Not a hand edit: one visual check of the newly drawn header pictures and a signpost board before sending the link to Adam, allowed by the session's 2-read budget. The four header pictures and "Signpost board – DUSTY HIGHWAY" came back; the stand front frames did not appear in the result and were not visually checked | 2 |
