---
title: Round 3 — checkpoint (read this first after a context change)
tags: [design, spec, checkpoint, lane3]
status: live
date: 2026-10-26
---
# Checkpoint

Ledger [[hud-round3]]; history [[hud-round2]], [[hud-round2-checkpoint]]. Branch `feature/lane3-hud-downtown-lookdev`, worktree `Roblox-Game-1-hud`, draft PR #2 only.
Lead (this session) owns Studio, Blender, Git, `Store`-adjacent shared files, `HudPlayground`, `Scenarios`, `DebugPanel`, `Arcade`, `PreviewTokens`.

## Environment
- Studio lock `Car-Hop-Art\STUDIO_LOCK.txt` taken 2026-10-26 10:24 with Adam's yes (previous lock was 45 h old). Delete it at the end. Only Studio window connected to MCP: `CarHop-HUD-Playground.rbxl` (id `735312d5-...`, user peskaface 2393473976, place id 0).
- The playground is a DERIVED file: close Studio, `rojo build playground/hud.project.json -o Car-Hop-Art\CarHop-HUD-Playground.rbxl`, reopen (helper scripts `grabwin.ps1`, `click.ps1`, `front.ps1` are in the session scratchpad and can be rebuilt; PrintWindow works for non-minimized windows without focus; the Studio window was minimized by the end of the setup).
- Harness is driven from `execute_luau` (Client datamodel): `PlayerGui.Lane3HudPlayground.Lane3HudControl:Invoke(cmd, ...)` (`play`, `setProfile`, `debug`, ...).
- Synthetic mouse into Studio fights Adam's live use of the machine: the importer step needs Adam present.
- Free memory 6.3 GB at start (floor 4 GB).

## Workers (all Sonnet, started 2026-10-26; briefs in the session scratchpad `r3-*.md`)
W1 run top (RouteLine/RideChip/RunLayout) · W2a Keys ring · W2b run-id dedup + haptics + Store · W3a Stamina · W3b Cash/Hop icons · W4 Garage cards · W5 Heat ·
W6 hop trail (DONE) · W7 audio · W8 overlay restyle · D1 dependency audit · P1 Dusty plan · P2 Summit plan.
- W6 done: files `World/ArcTelegraph.luau`, `Run/HopCue.luau`, `scenarios/Hop.luau`. Targeting facts: `src/client/Run` and `src/shared/Run` do NOT exist on any branch; the only selection is the playground fixture `api.setHopTarget(index)`; design intent is in `car-hop-outline-v2.md` "The Hop" (nearest car in Hop range in the steering direction). Seven questions for Brian R are in W6's report (forward/left/right definition, neutral dead-zone, eligibility, ties, hysteresis, Foot Dash, output/rate).

## Facts found by the lead
- OBJ package (`Car-Hop-Art\downtown-kit-b2\downtown-kit-b2.obj`): 180 objects, 56,751 triangles, 57,325 vertices, 1,615 UVs, 3,774 normals, no `mtllib/usemtl`; palette PNGs are 256x256 with a 16x16 cell grid, five of them. Assembler already accepts `meshIds` and `textureId` (see `Assembler.luau` lines ~155, 531, 699).
- Current claim times (design values, not in code): Common 3 s, Uncommon 3.5 s (proposed in `cars/rarity-style.md`), Rare 4 s, Epic 5 s, Legendary 6 s (`car-hop-outline-v2.md` lines 337-340; Heat capacity rule: even a Legendary claim leaves at least 3 s of Heat). At 0.75-0.80x: Common 2.25-2.4, Uncommon 2.6-2.8, Rare 3.0-3.2, Epic 3.75-4.0, Legendary 4.5-4.8 s.
- Figma: signed in as handle `agertskis`, View seat, Starter plan; no "Car Hop UI" file link anywhere in the repo.

## Progress log (lead, 2026-10-26)
- All 13 workers reported; `./scripts/check.ps1` passes; nine local commits (not pushed until verified). Playground rebuilt and reopened (`reopen.ps1` pattern: close only the HUD Studio, `rojo build playground/hud.project.json -o Car-Hop-Art\CarHop-HUD-Playground.rbxl`, start Studio on it). Studio Play load: 0 component failures.
- Studio Play scenario results so far: Icons 6 scenarios PASS; Stamina 11 scenarios no FAIL; Heat 4 scenarios PASS (36 + 39 + 8 + 5 checks), real HEATROW table (centre offset 0.00 on every frame, phones at scale 1.0 overlap the protected road 39-49% incl. title tab; see `hud-round3-heat-coverage.md`); RunTop 16 scenarios PASS; Route 5 PASS; Identity 5 scenarios PASS (32 checks). Keys: the ring path works (the Round 2 scenario shows the fill smoothly through pending to confirmed); three new Keys scenarios failed because their helper started a capture by event and only set the meter state 0.3 s later (a store tick ended it quietly): helper fixed in `scenarios/Keys.luau`, needs a rebuild to re-run.
- Fixed by lead: `CaptureRibbon` fanfare once per (run, capture); `KeysLock` quiet `KeysPending` note; `Specimen` uses `KeysLock.drawRing`; `HudPlayground` `setRideModel`, `scenarioList/scenarioBusy` helpers; `Capture.luau` foil count 4 -> 2.
- Provenance of the 21 audio ids read from `MarketplaceService:GetProductInfo` in Studio (all Audio, not for sale): Roblox (verified) UI sounds, APMOfficial music, ProSoundEffects SFX.
- The island Studio window (pid 44788) had already exited at 10:22 (its log's last write) before my first Studio call; I only closed the HUD window.

## Next (lead)
1. Collect worker reports; run `selene`/`stylua` and `./scripts/check.ps1`; mount lines in `HudPlayground`; register new scenario files in `Scenarios.luau`.
2. Rebuild the playground, Play, run every new scenario, capture per-change frames on six profiles.
3. B2 import with Adam present; palette images; manifest; replace preview references.
4. Sound asset checks (Studio search) for W7's chime/fanfare requests.
5. Reviewer, review page, drafts for Brian R / Brian L, board/log/decision, commit, push, PR #2.
