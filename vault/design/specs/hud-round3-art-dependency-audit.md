---
title: Round 3 external art-folder dependency audit (proposal only)
tags: [design, spec, audit, lane3, assets]
status: proposal only, nothing moved
date: 2026-10-26
---
# Round 3: external art-folder dependency audit (R3-F7)

Ledger row R3-F7 in [[hud-round3]]. Worker D1, read-only. **PROPOSAL ONLY: nothing was moved, uploaded, deleted, renamed or
reorganised, in the repository, in `Car-Hop-Art`, or in Google Drive. This file is the only file created.**

Scan basis: commit `0e90a9d` on `feature/lane3-hud-downtown-lookdev` (448 tracked files, 296 outside the two skill packs),
2026-10-26. Line numbers are at that commit. Round 3 workers are editing `Music.luau`, `Sounds.luau`, `CarCard.luau` and other
HUD files in the working tree while this audit was written, so lines in those files can shift; `src/lookdev/` and the playground
Rojo projects were unmodified. The grep patterns and counts in Appendix A reproduce every number here.

Evidence words: **read** = I read it in the cited file; **counted** = tool output (grep, find, ls, du, node JSON read);
**inferred** = reasoned from read code, not run; **not verified** = see the last section.

## How the art folder was resolved

The playground Rojo projects use `../../Car-Hop-Art/...` (for example `playground/hud.project.json:21`). Rojo resolves a `$path`
relative to the folder holding the project file, so from `playground/` that is the folder next to the clone folder. The clone is
`C:\Users\agert\Documents\Roblox-Game-1-hud`, so the folder is `C:\Users\agert\Documents\Car-Hop-Art`. It exists (counted:
2,500 files, 940,097,942 B, about 0.9 GB, Appendix B). Abbreviations used below:

- `ART` = `C:\Users\agert\Documents\Car-Hop-Art` (outside Git, one Windows disk).
- `HUDP` = `playground/hud.project.json`; `DTP` = `playground/downtown.project.json`.
- `CAT` = `src/lookdev/Downtown/City/Catalog.luau`; `ASM` = `.../City/Assembler.luau`; `SEQ` = `.../City/Sequencer.luau`;
  `KM` = `src/lookdev/Downtown/KitMesh.luau`; `BLD` = `src/lookdev/Downtown/Builder.luau`.
- `DRIVE` = the team's shared Google Drive folder (identity unverified, see section 4).
- `PLANDATA` = proposed Git-tracked folder for small text kit data (name is a proposal, for example `assets/downtown/data/`).
- `MANIFEST` = proposed asset manifest `vault/design/assets.md` (decision 0012 item 7 already names it; the file does not exist)
  plus a Luau id module (precedent: `src/island/Hub/Environment/AssetIds.luau` on the island branch, read from the sibling worktree).

## Dependency table (35 rows)

Columns: id, dependent file or tool (path:line), external path or id, role, class, who needs it, current failure mode if absent,
proposed durable location or reference, migration owner. "Shipped client: no" means no code path reaches a published game today.

### Runtime (12)

| ID | Dependent (path:line) | External path or id | Role | Class | Who needs it | Failure mode if absent (current) | Proposed durable home | Owner |
|---|---|---|---|---|---|---|---|---|
| R-01 | Mapped at `HUDP:19-22`, `DTP:38-41`. Read at `CAT:673-678`, `CAT:923-1006`, `ASM:465-484`, `ASM:628-740`, `KM:28-85`, `City/Merge.luau:23,85`. Passed in at `playground/hud/scripts/HudPlayground.client.luau:268` | `ART\downtown-kit-b2\meshes\*.json`: 180 files, 1,874,555 B, names `B2_*` | Geometry (`p`, `t`), `bounds` and `meta` (width, depth, height, facing, sockets, pivot_offset). Feeds the EditableMesh preview and the planner's lot and landmark sizes | runtime (Studio Edit and Play only) | Adam; Brian R when checking plan numbers; any teammate running a playground. Shipped client: no | Rojo skips the missing optional path with no error (Rojo docs, not run); `Lane3_DowntownKitB2` is absent; `Catalog.load` returns the built-in catalogue (placeholder lots, a different plan); every mesh becomes a proxy (labelled in Edit, unlabelled in Play); nothing throws | Plan data (name, triangles, bounds, meta: 138,571 B counted) in `PLANDATA`, mapped as a required path. Geometry JSON: commit it (text, 1.87 MB) or keep on `DRIVE` and rebuild with `kit_b2_build.py`. Shipped path is R-09 | Adam decides; Lead implements |
| R-02 | `HUDP:44-47`, `DTP:63-66`. Read at `CAT:939-960` | `ART\downtown-kit-b2\manifest.json`: 169,613 B, 180 entries | Adds mesh names and bounds to the catalogue even when a mesh file is missing (a third, "partial kit" state) | runtime | Adam; Brian R | No manifest: fewer names, `manifestCount` 0. No error | `PLANDATA` | Lead |
| R-03 | `HUDP:49-52`, `DTP:68-71`. Read at `ASM:428-455`, `ASM:525-528` | `ART\downtown-kit-b2\swatches.json`: 78,601 B | Swatch colours for per-face vertex colours in the preview | runtime | Adam | `loadSwatches` returns "none (no swatches in kit data)"; preview meshes have no colour (inferred from `KM:28-70`: colours are added only when swatches are given) | `PLANDATA` | Lead |
| R-04 | `HUDP:24-27`, `DTP:43-46`. Read at `CAT:682-688`, `CAT:823-920`, `City/init.luau:128-140`, `ASM:671` | `ART\downtown-kit-worlds\meshes\*.json`: 109 files (DH 53, SP 56), 609,733 B | World lot, landmark, prop, mass and hazard meshes. Supply facing, sockets, height, depth (capped at 24) and landmark width, depth, height | runtime | Adam; Brian R | World keeps the sizes from `City/Worlds/*.luau`; meshes become proxies; plans differ per kit state | As R-01 (plan data 73,369 B counted) | Adam decides; Lead implements |
| R-05 | `HUDP:36-39`, `DTP:55-58`. Read at `ASM:428-455` | `ART\downtown-kit-worlds\swatches.json`: 14,026 B (columns DH and SU) | Vertex colours for World meshes | runtime | Adam | No colour | `PLANDATA` | Lead |
| R-06 | `HUDP:31-34`, `DTP:50-53`. **No reader found**: `Catalog.forWorld` never reads kitData, and `"manifest"` is read only in `Catalog.load` (`CAT:939`, B2 only) | `ART\downtown-kit-worlds\manifest.json`: 97,219 B, 109 entries | Mapped but unused by current code (inferred from grep) | runtime (dead mapping) | Nobody | None | Do not migrate as a dependency; keep on `DRIVE` as a record or drop the mapping | Lead |
| R-07 | `DTP:77-80`. Read at `BLD:44`, `BLD:169-190`, `BLD:239`, `BLD:690-692`. No script in the repo calls `Builder.build` (grep), so command bar only | `ART\downtown-kit\meshes\*.json`: 215 files, 1,293,050 B | Round 1 studies A, B, C. Direction B is selected (`assets/downtown/kit-b/README.md:3`) and B2 supersedes them | runtime (Studio Edit only) | Adam only | Builder warns "no Lane3_DowntownKit folder; every mesh will be a grey box" (`BLD:692`) | Archive on `DRIVE`; drop from `DTP` when Adam retires the studies | Adam |
| R-08 | `DTP:82-108`. Read at `BLD:45`, `BLD:332`, palette lookup `BLD:160-215` | `ART\downtown-kit\layout-A.json`, `layout-B.json`, `layout-C.json` (96,115 + 105,086 + 112,259 B), `swatches.json` (32,005 B), `manifest.json` (78,323 B) | Study layouts and palettes | runtime (Studio Edit only) | Adam | `layoutFound` false, Builder falls back to fixtures; unknown palette warns "meshes will be untextured" (`BLD:213`) | As R-07 | Adam |
| R-09 | Options `meshIds`, `textureId` at `ASM:155-157`, `ASM:529-549`, `ASM:696-718`; `BLD:57`, `BLD:283-315`; `City/init.luau:63-65`, `:158-160` | **Uploaded mesh and texture ids: none exist.** `uploaded-ids.json` has 0 hits in the repo. The import plan (`ART\downtown-kit-b2\IMPORT-README.md`, read) would write it inside `ART` | The only path that can reach a shipped client: uploaded MeshParts plus a palette texture. The Assembler still needs the mesh JSON (bounds, meta) for an uploaded mesh (`ASM:715`) | runtime | Shipped client; Adam (uploader); Brian R | `meshIds` is empty, so only EditableMesh previews exist. They are session-only and Studio-only (`KM:73-74`, `ASM:500`, `City/init.luau:106`): a shipped client would show no Downtown or World scenery. The upload is blocked (R2-E2, `hud-round2.md:78`) | `MANIFEST` in Git: id, kind, uploader account, privacy, date, SHA-256 of the imported OBJ, source path on `DRIVE`. Ids are never stored in `ART` | Adam (approval, importer clicks); Lead (records) |
| R-10 | `ASM:529-531`, `ASM:706`. Made by `kit_b2_build.py:63`, `kit_world_build.py:60`, `build_kit.py:49` | `ART\downtown-kit-b2\palette-B2-{MainStreet,CityHall,HarborBridge,Midtown,SkylinePark}.png` (2,319-2,322 B each), `ART\downtown-kit-worlds\palette-DH.png`, `palette-SU.png` (1,378 and 1,370 B), `ART\downtown-kit\palette-{A,B,C}.png` | Palette images. A shipped MeshPart needs an uploaded image as TextureID; the recipe regenerates them (`kit_b2_palette.py:300`) | runtime (after upload); source is the recipe | Shipped client; Adam | `textureId` is "" today. An uploaded mesh has no colour in a MeshPart until palettes are uploaded (IMPORT-README, "Waiting for Adam"). Preview uses vertex colours (R-03) | Recipe stays the source in Git; upload ids recorded in `MANIFEST`. Original images need Adam's separate yes | Adam; Lead |
| R-11 | `src/client/UI/Prototype/Music.luau:49-104` (8 ids), `Sounds.luau:65-95` (16 ids); header notes at `Music.luau:5-8`, `Sounds.luau:5-8` | 24 unique `rbxassetid://` audio ids (counted). Roblox-hosted Creator Store assets from the Roblox, ProSoundEffects and APMOfficial accounts. Not on any local disk | Run music and UI sounds | runtime | Shipped client, if the HUD ships; Adam (auditions) | A private, moderated or removed id gives a Sound that never loads: silence (inferred; the only `IsLoaded` read is debug output, `Music.luau:479`). Music is off by default (`Music.luau:9`) | Ids already live in Git. Add provenance, licence, privacy and verified-date columns to `MANIFEST`; re-verify before release. Candidates are metadata-screened only (`Music.luau:5-8`) | Lead (W7); Adam |
| R-12 | `default.project.json:15` maps `assets/cars` to `ReplicatedStorage.Cars`. Read at `Cards/CarCard.luau:963`, `Run/RunKit.luau:69` | Car `.rbxmx` models (none yet: only `assets/cars/README.md` is tracked). They will reference mesh ids uploaded under Brian L's account (0015 item 3, 5) | Real car models in HUD cards and thumbnails | runtime (future) | Brian L; shipped client | No external dependency today: every fixture uses the code-built "Proxy" car (`Fixtures.luau:43`, `Screens/PortalCardMock.luau:94`). A missing model shows "Unavailable" (`CarCard.luau:971`) or no thumbnail (`RunKit.luau:75-77`). Open: whether an Open Use mesh from Brian L's account loads in a place owned by Adam (0015, "Not established yet") | Already in Git (Rojo-synced). Record each car's ids and the `DRIVE` source hash in `MANIFEST` | Brian L |

### Build (11)

| ID | Dependent (path:line) | External path or id | Role | Class | Who needs it | Failure mode if absent (current) | Proposed durable home | Owner |
|---|---|---|---|---|---|---|---|---|
| B-01 | All 18 `optional` mappings (`HUDP` 6, `DTP` 12), `$path` form `../../Car-Hop-Art/...` | A folder named exactly `Car-Hop-Art` next to the clone folder. `AGENTS.md` never mentions it (0 hits) | Where the playground Rojo projects look for kit data | build | Every teammate who builds a playground. CI: no | Silent skip (Rojo docs via Context7; not run here): the build is green, the city is proxies, the plan differs (see "What reads the kit") | `PLANDATA` mapped as required paths; `ART` only for optional geometry; document the convention in `AGENTS.md` Setup | Lead |
| B-02 | Recipe command lines: `assets/downtown/kit-b/README.md:19-20,31-32,36,133`; `kit-b/MANIFEST.md:12`; `kit/build_kit.py:3,11`; `kit_b2_build.py:5,21`; `kit_b2_render.py:5-7`; `kit_world_build.py:5,16`; `kit_world_render.py:5-6`; `layout.py:4`; `render.py:4-5`; `vault/design/cars/first-car-record.md:65-66` | Absolute `C:\Users\agert\Documents\Car-Hop-Art\...` output paths. The scripts themselves take `--out` or `--kit` ("--out is required", `kit_b2_build.py:52`) | Where recipe output is written and read | build | Adam (only Blender operator); anyone rebuilding the kit | Copy-paste commands fail on another machine. The scripts work with any `--out` | Replace with an `<ART>` placeholder and a documented root. Recipes stay in Git | Lead |
| B-03 | `assets/downtown/kit/run_direction.ps1:8-9,17-18,23,35-36`; `compare.ps1:6-7` | Defaults `C:\Users\agert\Documents\Car-Hop-Art\downtown-kit` and `...\review\hud-downtown\downtown\blender`; `$env:LOCALAPPDATA\Microsoft\WinGet\Packages` for ffmpeg | PowerShell wrappers for the Round 1 renders | build | Adam | Missing default folder: `Out-File` to `<Kit>\memory-log.txt` fails under `$ErrorActionPreference = "Stop"` (inferred, `run_direction.ps1:14`); no ffmpeg found gives an empty command | Mandatory `-ArtRoot` parameter or env var; find ffmpeg and Blender on PATH | Lead |
| B-04 | `run_direction.ps1:17-18`; header comments `build_kit.py:2`, `kit_b2_build.py:4`, `kit_b2_render.py:4`, `kit_world_build.py:4`, `kit_world_render.py:3`, `layout.py:3`, `render.py:3` | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` and its bundled `python.exe` | Blender 5.2 headless is the only kit builder | build | Adam; any kit rebuilder | Script stops. Other Blender versions untested | Pin "Blender 5.2" in a README; resolve by `BLENDER_EXE` or PATH. Installers stay per machine | Lead |
| B-05 | `kit-b/README.md:36`; `first-car-record.md:119`; `hud-rebuild-checkpoint.md:13,17`; `hud-round2-checkpoint.md:14-15`; Claude memory note "Studio lock rule" | `ART\STUDIO_LOCK.txt` (present now, taken 2026-10-26 10:24 by Round 3) and `ART\BLENDER_LOCK.txt` (absent now) | Serialise concurrent agent sessions on one PC (one Studio, one Blender) | build (process) | Adam's sessions | A teammate on another machine has no such folder; harmless, the lock protects one machine only | Keep machine-local; state in `AGENTS.md` that locks live in the local art root, not in Git | Lead |
| B-06 | `hud-rebuild-checkpoint.md:61` (`rojo build playground/hud.project.json -o Car-Hop-Art/CarHop-HUD-Playground.rbxl`, downtown equivalent); `vault/log/2026-10-22.md:24-25` | `ART\CarHop-HUD-Playground.rbxl` (1,877,414 B), `CarHop-Downtown-LookDev.rbxl` (1,712,697 B), `CarHop-Lane3-Test.rbxl`, four `CarHop-Island-Test*.rbxl`, two `.rbxl.lock` | Local test places. The two playground places are regenerable from Git plus kit data. The Lane3 place also holds the imported test car (log 2026-10-21:81) | build output | Adam | Rebuild with `rojo build`; without kit data the rebuilt place has proxies | Never commit (`.gitignore` blocks `*.rbxl`). Keep local; whether to keep Island and Lane3 places is Adam's call | Adam |
| B-07 | Not in Git. Described at `vault/log/2026-10-21.md:18-21` and `AGENTS.md` "Studio MCP" | `ART\island-preview.project.json` (+3 `.bak-*` copies), `ART\open-island-test.ps1`. They hold Adam's private place and universe ids (identifiers, not credentials) and point at the sibling worktree `..\Roblox-Game-1-island` | Adam's personal Rojo auto-reconnect and Studio launcher for the island test place | build (personal) | Adam only | Adam re-creates them from the log note; nobody else is affected | Stay outside Git on purpose (`AGENTS.md`: place ids live in the person's own file) | Adam |
| B-08 | `.codex/config.toml:5`; `.claude/skills/project-studio-verification/SKILL.md:38,45,47`; `project-team-handoff/SKILL.md:92-93`; `references/handoff-template.md:54`; `AGENTS.md:108` | `%LOCALAPPDATA%\Roblox\mcp.bat` (Studio MCP launcher) and `%LOCALAPPDATA%\Roblox\Plugins` (Rojo plugin) | Per-machine Studio MCP and Rojo plugin install | build (tooling) | Adam; any Studio, Claude or Codex user | `mcp.bat` missing: MCP not connected. Documented as a per-machine step | Nothing to migrate; keep documented | Lead |
| B-09 | `.codex/config.toml:8-10`; `docs/ANIMATION_PIPELINE.md:60-62` | `uvx mcp-for-blender`, fetched from the Python package index at run time | Blender MCP server | build (tooling) | Adam | Offline, or a changed upstream version, changes behaviour (inferred: no version pin in the config) | Pin a version in the docs | Lead |
| B-10 | `default.project.json:9`; `HUDP` and `DTP` `../Packages`; `wally.lock` (tracked) | `Packages/` (git-ignored, present here), generated by `wally install` | Trove, Signal, Promise | build | Every teammate; CI | `rojo build default.project.json` fails on the required path if `wally install` was not run (documented in `AGENTS.md` Setup) | Already reproducible from `wally.lock`. Cleared | none |
| B-11 | `.github/workflows/checks.yml` (whole file); `scripts/check.ps1:87-92` (lints `src/` only) and `:116-122` (builds `default.project.json` only) | None: CI reads no art folder | Lint, format, Rojo build of the shipped project | build | CI | No failure today. CI never builds the playground projects or lints `playground/` Luau, so a missing kit cannot turn CI red | Keep CI free of `ART`. Add a playground build step only after R-01 to R-05 are in Git | Lead |

### Source art (7)

| ID | Dependent (path:line) | External path or id | Role | Class | Who needs it | Failure mode if absent (current) | Proposed durable home | Owner |
|---|---|---|---|---|---|---|---|---|
| S-01 | `kit-b/MANIFEST.md:12`, `kit-b/README.md:19`; export code `kit_b2_build.py:185-199` | `ART\downtown-kit-b2\downtown-kit-b2.obj` (4,883,967 B, 180 groups, 56,751 triangles), `downtown-kit-b2.fbx` (1,643,804 B, **x100 scale: do not import**), `downtown-kit-b2.fbm\palette-B2-MainStreet.png` (embedded copy) | Importer inputs for the B2 upload, derived from recipes in Git | source-art | Adam (importer click); Lead | Regenerate with `kit_b2_build.py` (about 10 s per `kit-b/README.md:36-37`; byte-identical output not verified) | `DRIVE` `downtown-kit-b2/`; SHA-256 of the exact OBJ uploaded goes in `MANIFEST` | Adam |
| S-02 | `kit_world_build.py:172-186` | `ART\downtown-kit-worlds\worlds-DustyHighway.obj` (679,039 B) and `.fbx` (372,252 B), `worlds-SummitPass.obj` (900,851 B) and `.fbx` (462,796 B) | Importer inputs for the two World kits. Upload not authorised (decision 0020 item 9) | source-art | Adam | Regenerate with `kit_world_build.py` | `DRIVE` `downtown-kit-worlds/` | Adam |
| S-03 | `build_kit.py:103-104` | `ART\downtown-kit\downtown-kit-{A,B,C}.obj`, `-road-street-hazard-skyline.obj`, `-street-A.obj` (5 files, 367,982 to 1,384,009 B) | Round 1 study packages, superseded by B2 | source-art | Adam | Regenerate with `build_kit.py` | `DRIVE` `downtown-kit/` (archive) | Adam |
| S-04 | Not referenced from this branch. Referenced by the island branch (`src/island/Hub/Environment/AssetIds.luau:4,262`) and by B-07 | `ART\island-kit\` (218 files, 22 MB: `kit.blend`, `kit.blend1`, FBX, 3 OBJ, 151 mesh JSON) and `ART\island-kit-task4\{all,garage,gates,park4,stunt}\` (232 files, 12 MB: 5 `kit.blend` + `.blend1`, FBX and OBJ per family) | Island art sources for another branch | source-art | Adam | Possibly the only copy of hand-edited `.blend` state (not checked whether they are fully derived from `assets/island/kit/build_kit.py`) | `DRIVE` `island-kit/` and `island-kit-task4/`. Island asset ids are recorded on that branch | Adam |
| S-05 | `vault/design/cars/README.md:69-71`; `vault/log/2026-10-21.md:75-81`; decision 0015 items 4 and "Builds on" | `ART\vehicles\` (71 files, 76 MB): `downtown-starter\downtown-starter.blend` + `.blend1` + `.fbx`, `studies\studies.blend` + `.blend1`, 64 PNG renders, `stats.json`, `studies.json` | Car source art. Decided home: `DRIVE` (0015 item 4). The 14 test meshes uploaded from these are listed at `first-car-record.md:135-150` | source-art | Brian L; Adam | No repo copy by design. The recipe lives on `feature/lane3-first-car-downtown`, not on this branch (counted by file name in the sibling worktree). Whether the "Adam will move them" step (`README.md:71`) happened is unverified | `DRIVE` `vehicles/` | Adam copies; Brian L confirms |
| S-06 | `vault/design/references/README.md:10-12`; `research/hud-ref-*.md`; `research/runner-progress-failure.md:15-16`; `cars/rarity-style.md:99` | `ART\references\` (87 files, 46 MB): HUD screenshot PNG originals, dino-game frames, web study images, island, garage, hub, nature and portal studies | Reference material, third-party or Adam's screenshots, "not for use in the game". JPG copies of the key ones are in Git (23 files, 5,057,439 B in `vault/design/references/`) | source-art (reference) | Adam; reviewers | Hash-prefix citations of the originals cannot be re-checked | `DRIVE` `references/`, private. Keep the JPG copies in Git. Note provenance and licence per file | Adam |
| S-07 | `docs/ANIMATION_PIPELINE.md:96-98,328-331` | `C:\Users\agert\BlenderScratch\` (outside `ART`; 17 files, 2.9 MB: 2 `.blend` + `.blend1`, 4 FBX, 2 `.rbxl`, `mesh2motion\`, `rbxtest\`) | Animation test scratch, "outside the repo until the team decides where source art lives" | source-art (scratch) | Adam | Loss costs only the Bounce test | Home is still an open item (`ANIMATION_PIPELINE.md` section 11): `DRIVE` `animation-scratch/` once decided | Adam |

### Review-only (5)

| ID | Dependent (path:line) | External path or id | Role | Class | Who needs it | Failure mode if absent (current) | Proposed durable home | Owner |
|---|---|---|---|---|---|---|---|---|
| V-01 | 108 lines in 37 tracked files cite `Car-Hop-Art` (for example `hud-round2.md:81`, `hud-round2-checkpoint.md:55`, `vault/tasks/BOARD.md:28-29`, `vault/log/2026-10-23.md:73`, `vault/design/downtown-plan.md:14`) | `ART\review\` (1,141 files, 717 MB: 560 PNG, 465 JPG, 54 MP4, 30 MD, 7 HTML, 10 JSON, 5 PY, 2 RBXL; hud-downtown 263 MB, task4 154, hud-rebuild 145, hud-round2 132, task3 26, hud-round3 empty `before\`) | Review pages, videos, stills, Blender renders: the evidence the specs cite | review-only | Adam. Brian R and Brian L cannot open it | Links in specs and logs are dead for teammates; evidence is unverifiable off Adam's PC | `DRIVE` `review/<round>/`, or private Artifact pages for the index pages. Cite by logical identifier. Do not rewrite dated logs; add a mapping note in the handoff | Lead; Adam |
| V-02 | `hud-round2-checkpoint.md:19`; the Round 3 `before\` folder | `ART\baselines\` (150 files, 4.1 MB: `round2-start\` 2 `.rbxl`; `round2-kit-b2-before-blvd\` mesh JSON, manifest, swatches, catalogue, 5 palettes) and `ART\review\hud-rebuild\place-backups\` (2 `.rbxl`) | "Before" states for comparison. The B2 baseline is also a distinct kit state that changes plans | review-only | Adam; Lead for before and after | Comparisons cannot be repeated | `DRIVE` `baselines/` with SHA-256 and a kit-state id | Lead |
| V-03 | `kit_b2_render.py:79` | `C:\Windows\Fonts\ariblk.ttf` (Arial Black, a Microsoft font) | Sign labels in Blender review renders | review-only | Adam | Script raises on a machine without the font (inferred: loading a missing font file) | Use a Blender-bundled or repo-licensed font. Never shipped | Lead |
| V-04 | `hud-round2-checkpoint.md:15-18` | `reopen.ps1`, `grab.ps1`, `seq.ps1`, `rec.ps1`, `keepfront.ps1`, `memlog.ps1`, found **by file name only** in `C:\Users\agert\AppData\Local\Temp\claude\C--Users-agert-Documents-Roblox-Game-1-hud\0370054e-fde5-46f3-8ae8-f8153f8acc45\scratchpad\` (contents not read) | Studio capture, recording and memory helpers behind the Round 2 evidence | review-only (tooling) | Adam; Lead | Temp folders can be cleaned; the capture method is then not reproducible and the files are in no Git history | Review them, then commit the ones worth keeping to `scripts/` with Adam's approval | Lead |
| V-05 | `run_direction.ps1:23`; kit build logs | `ART\downtown-kit-b2\blender-*.out.txt` and `.err.txt` (40 files), `memory-log.txt`; `ART\downtown-kit\run-{A,B,C}.log`, `stats-{A,B,C}.json`, `memory-log.txt`; `ART\review\hud-round2\memory-log.txt` | Build and memory logs | review-only | Adam | Lost build history only | `DRIVE` with the kit folder; do not commit | Adam |

## What reads the kit, and what happens when it is absent

This answers the Round 2 review finding "Plans depend on art folders outside Git" (`hud-round2.md:115`, ledger R2-W1 at line 69).
The files you named, in the order the data flows:

| File:line | What it does with kit data | When the folder or assets are absent |
|---|---|---|
| `HudPlayground.client.luau:268-269` | `FindFirstChild("Lane3_DowntownKitB2")` and `...B2Data` | nil. `City.new` runs inside `pcall`; the return string still says "city built" (`:324`) |
| `City/init.luau:128-140` | World path: `Catalog.worldFolders()` then `Catalog.forWorld`; Downtown path: `Catalog.load` | Both fall back to catalogue data; a World keeps `City/Worlds/*.luau` sizes |
| `Catalog.luau:673-688` | `defaultFolders` and `worldFolders` search ServerStorage then ReplicatedStorage (reversed in Play) | Return nil |
| `Catalog.luau:695-776` (`mergeLot`) | Lot width, depth (capped 24), height, heightClass, orientation, districts, sockets, facing from `meta` or `bounds` | Not called; built-in lots stay |
| `Catalog.luau:778-816` (`mergeLandmark`) | Landmark width, depth, height from `meta` | Not called; built-in landmark sizes stay |
| `Catalog.luau:823-920` (`forWorld`) | World lots take facing, sockets, height from bounds, depth from meta; landmarks take width, depth, height from meta | Data sizes stay; `kitCount` 0; `cat.source` has no "+ kit" |
| `Catalog.luau:923-1006` (`load`) | Merges the B2 manifest and mesh meta into the built-in catalogue. When any kit lot exists the built-in placeholder lots are **removed** (`:981-996`) | `builtIn()` with placeholder lots. `cat.source` records only counts (`:998-1002`) |
| `Sequencer.luau:262` | `opts.catalog or Catalog.load()`. The Sequencer reads no instances. It consumes `lot.width` (`:1013-1057`, `:1169-1186`), `lot.heightClass` (`:887-889`), `lm.width` (`:784`, `:1532`) | Plans from the built-in catalogue: a different plan for the same seed. `plan.catalogSource = catalog.source` (`:1591`) is a count string, not a content hash; `Sequencer.VERSION = "city-b2-1"` (`:31`) versions the code only |
| `Assembler.luau:500` | `assert(RunService:IsStudio())`. Also `City/init.luau:106` | Not applicable in a shipped client: it errors |
| `Assembler.luau:428-455`, `:465-484`, `:628-740` | `loadSwatches`, `loadMesh`, `prepare`: EditableMesh via `KitMesh.previewPart` or uploaded `meshIds` | `loadMesh` returns "not in kit"; every template is `missing`; every item is a proxy. Root attribute `Kit` is set to "none (proxies only)" (`:622`) and `getStats` repeats it (`:1618`). No error, no warning |
| `KitMesh.luau:28-85` | Builds an EditableMesh from the JSON; `:73-74` states it is "in this Studio session only" | Not reached |
| `City/Merge.luau:23,85` | Merges kit JSON into one EditableMesh per live segment in Play (8 EditableMeshes per client, `ASM:53-55`) | Not reached |
| `Builder.luau:44-45,239,690-692` | Round 1 studies: `Lane3_DowntownKit`, `Lane3_DowntownLayouts` (edit mode, command bar) | `warn(...)` and grey boxes |
| `Parts.luau`, `Proxies.luau`, `Route.luau`, `Worlds/*.luau` | No external read (`Parts.luau:7` reads `Shared.UI.Tokens` only; the others are code and comments) | Not applicable |

Three consequences, all read from the code above:

1. **A fresh clone gets a green build and a different city.** Rojo skips missing optional paths without error (Rojo docs via Context7;
   not run here). `Lane3_DowntownKitB2Data` and `Lane3_DowntownKitWorldsData` still exist as empty Folders (their parent has
   `$className: Folder`; inferred).
2. **`Worlds: combined run` can pass on proxies.** Its PASS condition needs `asm.liveItems > 0` (`playground/hud/scripts/scenarios/Worlds.luau:107`),
   and `liveItems` counts proxy items and ground tiles (`ASM:1510-1531`). It does not require `liveMeshInstances > 0`.
3. **"Same seed, same plan" holds per kit state, and the kit state has no identifier.** `City/README.md` ("Seed, determinism and
   checks") says so in words: "the plan with and without the kit differs". Three states exist today: no kit, manifest only
   (names merged, meshes missing), full kit. A regenerated or older kit (for example `ART\baselines\round2-kit-b2-before-blvd`)
   is a fourth, and nothing in the plan records which one was used.

## 1. Summary counts and top 5 risks

**Counts by class (35 rows):** runtime 12, build 11, source-art 7, review-only 5.

**Counts by proposed action:** move text data into Git 5 (R-01 to R-05); record ids in the manifest 4 (R-09 to R-12); retire a
mapping 3 (R-06 to R-08); copy to Drive 10 (S-01 to S-07, V-01, V-02, V-05); fix tooling paths 6 (B-01 to B-04, V-03, V-04); keep
local or already fine 7 (B-05 to B-11).

**Size at stake (counted):** `ART` is 2,500 files, about 0.9 GB. The B2 and World kit data the playground code reads is 2.5 MB of
mesh JSON (3.8 MB with the Round 1 studies) plus 0.26 MB of B2 manifest and swatches and World swatches. The part that decides plan
sizes (plan data) is only 0.47 MB. `review\` is 717 MB and `references\` 46 MB. The eight `.blend` files (plus `.blend1` backups)
sit in `island-kit*` and `vehicles\`.

**Top 5 risks** (tag: C = teammate cloning on a fresh machine, S = shipped Roblox client):

1. **[C] The playground builds silently without the kit.** 18 optional mappings need a folder named `Car-Hop-Art` next to the clone,
   `AGENTS.md` never says so, Rojo skips it without error, the Assembler degrades to proxies, and `Worlds: combined run` can still
   pass. A teammate gets a green build, a different plan, and no signal (B-01, R-01 to R-05, section above).
2. **[S] Nothing the game needs from the kit is uploaded, and the only preview path cannot ship.** There are zero B2, World or palette
   ids; the city asserts Studio; EditableMesh content is session-only. The planned `uploaded-ids.json` would live inside `ART`, which
   breaks the principle below. Ids would sit under Adam's personal account, Restricted (`hud-round2.md:78`); whether the experience
   owner can load them is untested (R-09, R-10).
3. **[C][S] Plans depend on an unversioned kit state.** Lot and landmark sizes come from kit files; kit lots replace built-in lots;
   `catalogSource` records counts only. Regenerating the kit or switching baselines changes plans without any record (R-01, R-02).
4. **[C] Originals and evidence sit on one disk.** All 8 `.blend` files, every OBJ and FBX export, 46 MB of references, 717 MB of
   review media and the local places are only on Adam's PC. The car sources are still "Adam will move" (`cars/README.md:71`), the
   Drive link and access are "not recorded yet" (0015, "Not established yet"), and the location for non-car source art is still an
   open item (`AGENTS.md:99`, `ANIMATION_PIPELINE.md` section 11). 108 lines in 37 tracked files mention `Car-Hop-Art` (specs, logs,
   recipes, project files) and 38 lines in 23 files contain `C:\Users` paths (S-01 to S-07, V-01, V-02).
5. **[C] The build and evidence tooling is machine-bound.** `run_direction.ps1` and `compare.ps1` default to `C:\Users\agert\...`,
   Blender 5.2 is hard-coded, `kit_b2_render.py` needs `C:\Windows\Fonts\ariblk.ttf`, the FBX export has a known x100 scale defect,
   and the Round 2 capture helpers exist only in a temp scratchpad (B-02 to B-04, V-03, V-04, S-01).

## 2. The principle

**Anything the Roblox game needs at runtime must be packaged and referenced through the approved repository and uploaded-asset
workflow, not through Adam's local Windows disk.** That means one of two things:

- uploaded Roblox asset ids recorded in a repository manifest, under the uploader's account (with privacy setting, date, source
  hash), or
- files that Rojo syncs from Git.

**Source art** (`.blend`, `.fbx`, `.obj`, palette sources, review media) belongs in the team's shared Google Drive folder
"Car Hop source art", following the car convention in `vault/decisions/0015-car-modeling-to-brian-l.md` (item 4: car `.blend` and
`.fbx` live in the Drive folder, never in the repo). A shipped Roblox client cannot read a Google Drive folder. So the three kinds of
thing stay separate: **source-of-truth art** (Drive), **exported and uploaded runtime assets** (Roblox, referenced by id), and
**repository-held manifests and configuration** (Git). Reproducible build instructions, stable references, access requirements
and licence and owner provenance travel with them.

Applied to this audit:

| Rule | Where it bites | Rows |
|---|---|---|
| Runtime meshes and textures: uploaded ids in a Git manifest | No ids exist; the id file was planned inside `ART` | R-09, R-10 |
| Runtime text data the code reads: Rojo-synced from Git | Planner sizes, manifests, swatches read from `ART` | R-01 to R-05 |
| Source art: Drive, copied and hash-verified before any local deletion | OBJ/FBX packages, `.blend` files, references | S-01 to S-07 |
| Review media: Drive or private pages, cited by logical identifier | 717 MB of evidence cited by local path | V-01, V-02, V-05 |
| Reproducible builds: no machine paths in scripts or docs | Blender, ffmpeg, font and art-root paths | B-01 to B-04, V-03, V-04 |
| Stable references and provenance: one manifest, one row per id | Audio ids have none; cars and kits need them | R-11, R-12 |
| Access requirements: write down who needs Drive and which Roblox account owns each id | Drive link and access unrecorded; Restricted ids under a personal account | section 4, R-09 |
| Preserve originals and owner provenance: copy, never move first | Single copies of `.blend` files | S-04, S-05 |

Two limits to state plainly. First, decision 0015 settled the Drive convention **for cars only**; extending it to world-kit
packages, references and review media is a new decision for Adam to record. Second, `EditableMesh` content is session-only
(`KitMesh.luau:73-74`), is capped per device, and "published games need the Mesh / Image API setting" (`City/README.md`, "Limits
and risks"), so the EditableMesh path is not a fallback for shipping.

## 3. Migration steps (PROPOSAL ONLY, nothing moved)

Ordered so that teammates are unblocked first, cheapest and least risky steps before uploads and deletions. Each step names an owner role.

1. **Decide (Adam, repository owner).** (a) Confirm the Drive folder's name, owner and who has access, and record it in a decision
   note that extends 0015 from cars to all source art and review media. (b) Choose between committing the kit mesh JSON (2.5 MB for B2 and Worlds, text) and
   keeping it on Drive and regenerating it; recommended: commit only the small plan data now. (c) Approve the manifest location
   (`vault/design/assets.md` plus a Luau id module).
2. **Make the missing kit loud (Lead, no art moved).** Document the `Car-Hop-Art` sibling convention (or an env var) in `AGENTS.md`
   Setup. Surface the existing `Kit = "none (proxies only)"` attribute (`ASM:622`) in the playground harness. Make
   `Worlds: combined run` report or require `liveMeshInstances > 0`, so a kit-less machine cannot show a clean PASS.
3. **Put plan data in Git (Lead implements, Adam approves).** Generate from `ART` without Blender: per kit the `name, triangles,
   bounds, meta` records (B2 138,571 B, Worlds 73,369 B), plus the B2 manifest (169,613 B) and the B2 and Worlds swatches (78,601 B
   and 14,026 B), about 0.47 MB. Map them as required Rojo paths. This needs a small Catalog change so that plans read the slim
   files (a meta-only module cannot satisfy `loadMesh`, which needs `p` and `t`). Prove it with a before-and-after plan digest for seeds
   2207, 11, 77, 101, 314 on all three Worlds. Drop the unread Worlds manifest mapping (R-06).
4. **Create the asset manifest (Lead drafts, Adam approves, Brian L for cars).** Write `vault/design/assets.md`, which decision 0012
   already promises, with columns: name, kind, Roblox id, uploader account, privacy, upload date, source file on Drive, SHA-256,
   licence or provenance, verified date. Fill it first with what already exists: the 24 audio ids (provenance from
   `vault/design/research/run-music-candidates.md` and `sound-candidates.md`) and the 14 test car meshes (`first-car-record.md:135-150`,
   labelled test). Add the Luau id module following the island branch's `AssetIds.luau`.
5. **Add a kit-state identifier (Lead).** A version or content hash in the plan data, printed in `plan.checks` and the plan digest, so
   "same seed, same plan" names its kit state.
6. **Copy source art to Drive (Adam; Brian L for vehicles), hash-verified.** Order: `vehicles\` (a teammate needs it, and the move is
   already decided), then `island-kit*\`, then `downtown-kit*\` packages, `references\`, `BlenderScratch`. Copy, do not move. Compare
   SHA-256 on both sides, record the list in the manifest, and leave the local originals in place until Adam says delete. Suggested
   layout: `Car Hop source art/{vehicles, downtown-kit-b2, downtown-kit-worlds, downtown-kit, island-kit, island-kit-task4,
   references, animation-scratch, baselines, review}`.
7. **Upload B2 (Adam's approval and importer clicks; currently blocked).** Decide the Roblox creator account **before** uploading
   (ownership of an uploaded asset follows the uploader; transfer is not verified here). Import the OBJ, not the FBX. Record each id in
   the manifest, not in `ART`, plus the importer settings and the OBJ's SHA-256. Verify with `AssetService:CreateMeshPartAsync` and compare
   sizes with the plan data. Palette images need a separate yes. Dusty Highway and Summit Pass stay not authorised.
8. **Copy review media (Lead and Adam).** Put `review\<round>\` on Drive (or keep private Artifact pages for the index pages). Cite
   by logical identifier, never an invented link. Do not rewrite dated logs; add a mapping note in the handoff.
9. **Parametrise tooling (Lead).** One art-root parameter (name is a proposal: `CARHOP_ART`), Blender by `BLENDER_EXE` or PATH,
   ffmpeg on PATH, a non-Windows font, `<ART>` placeholders in docs. Review the six Round 2 helper scripts and commit the ones worth
   keeping to `scripts/`.
10. **Cars and audio checks (Brian L; Lead).** Run the Open Use load test from Brian L's account into Adam's place (open since 0015).
    Re-verify the audio ids and their licence status before any release.
11. **Fresh-clone drill (Brian R or Brian L as tester; Lead supports).** Clone into an empty folder on another machine or account,
    run `rokit install`, `wally install`, `./scripts/check.ps1`, build `playground/hud.project.json`, and compare the plan digest.
    Add a CI playground build only if it passes without `ART`.

## 4. Unresolved mapping

I have no Google Drive tool in this session. **The shared folder's identity is unverified; no folder id, link or share URL is
written here.** The name "Car Hop source art" comes from the lead's brief. The repository calls it only "the team's shared Google
Drive folder" (`AGENTS.md:99`, `vault/decisions/0015-car-modeling-to-brian-l.md` item 4), and 0015 says "The shared Drive folder's
link and who has access are not recorded yet." Not known: whether the folder exists under that name, its owner, who can open it,
what it holds, and whether any vehicle source has been copied there (`vault/design/cars/README.md:71` says Adam "will move" them).
`vault/design/assets.md`, which the brief asked me to read if present, does not exist.

## 5. Scan evidence (Appendix A)

Commands, run from the worktree root against the commit, so they are reproducible even while the working tree changes:

```
git grep -I -n -F -e "<pattern>" HEAD -- . ':!.claude' ':!.agents'   # first-party lines
git grep -I -l -F -e "<pattern>" HEAD -- . ':!.claude' ':!.agents'   # first-party files
git grep -I -n -F -e "<pattern>" HEAD                                # all tracked lines (adds the two skill packs)
```

`-E` instead of `-F` for the regex rows. `HEAD` is `0e90a9d`. Counts are lines/files.

| Pattern | First-party | All tracked | Note |
|---|---|---|---|
| `Car-Hop-Art` | 108/37 | 108/37 | The skill packs have 0 |
| `Car-Hop-Art/` | 47/15 | 47/15 | |
| `Documents/` | 2/1 | 2/1 | `first-car-record.md:65-66` |
| `C:\Users` | 38/23 | 38/23 | |
| `C:/Users` | 2/1 | 2/1 | |
| `%USERPROFILE%`, `USERPROFILE` | 1/1 | 1/1 | `docs/ANIMATION_PIPELINE.md:97` |
| `%LOCALAPPDATA%` | 15/11 | 29/19 | Rest is skill packs (Studio MCP launcher) |
| `LOCALAPPDATA` | 17/13 | 31/21 | |
| `AppData` | 0/0 | 0/0 | |
| `Program Files` | 11/9 | 11/9 | Blender 5.2 |
| `Windows\Fonts` | 1/1 | 1/1 | `kit_b2_render.py:79` |
| `../../` | 19/3 | 19/3 | The 18 mappings (`HUDP` 6, `DTP` 12) plus one Markdown link (`assets/cars/README.md:3`) |
| `../Roblox-Game-1` | 1/1 | 1/1 | `vault/log/2026-10-21.md:45` |
| `STUDIO_LOCK` | 5/4 | 5/4 | |
| `BLENDER_LOCK` | 2/2 | 2/2 | |
| `Google Drive` | 7/6 | 7/6 | None carries a link |
| `peskaface` | 8/6 | 8/6 | Uploader account name only |
| `.rbxl` | 34/16 | 44/20 | |
| `\.rbxlx?([^A-Za-z0-9_]\|$)` (regex) | 34/16 | 44/20 | |
| `\.fbx([^A-Za-z0-9_]\|$)` (regex) | 29/15 | 29/15 | |
| `\.obj([^A-Za-z0-9_]\|$)` (regex) | 10/7 | 10/7 | The plain `.obj` literal over-counts (`.object`) |
| `\.blend1?([^A-Za-z0-9_]\|$)` (regex) | 22/10 | 22/10 | |
| `\.png([^A-Za-z0-9_]\|$)` (regex) | 75/22 | 75/22 | |
| `palette-` | 30/13 | 32/15 | |
| `downtown-kit` | 48/18 | 48/18 | |
| `island-kit` | 0/0 | 0/0 | Island art is not referenced from this branch |
| `uploaded-ids`, `uploaded-ids.json` | 0/0 | 0/0 | The id file exists only in the plan in `ART` |
| `kit_[a-z0-9_]+\.py` (regex) | 24/12 | 24/12 | Recipes |
| `Lane3_Downtown(Kit\|Layouts)` (regex) | 27/7 | 27/7 | |
| `rbxassetid://` | 30/6 | 48/12 | |
| `rbxassetid://[0-9]+` (regex) | 25/3 | 31/7 | `Music.luau` 8, `Sounds.luau` 16, `Builder.luau:54` is an example in a comment |
| `rbxasset://` | 9/8 | 9/8 | Engine-bundled fonts and smoke texture |
| `rbxthumb://` | 0/0 | 0/0 | |
| `CreateMeshPartAsync\|CreateEditableMesh` (regex) | 13/6 | 15/8 | |
| `Content\.fromUri\|Content\.fromObject` (regex) | 4/4 | 8/6 | |
| `ContentProvider\|PreloadAsync` (regex) | 0/0 | 12/8 | None in first-party code, so no preload gate exists |
| `io\.open\|os\.getenv\|os\.path\|sys\.argv` (regex) | 74/10 | 76/12 | Recipes only; no hard-coded home paths in Python |

Non-grep scans (all read-only):

- `git status --short --ignored` at start: clean, with ignored `Packages/` and `assets/downtown/kit/__pycache__/` only. Later
  untracked files (`hud-round3.md`, `world-plan-summit-pass.md`, `world-plans-assets/`) are the lead's and were not touched.
  `grep -r -a -F Car-Hop-Art` over the two ignored folders: 0 matches.
- Files read in full: `default.project.json`, `playground/*.project.json`, `playground/*/Lane3Playground.model.json`, `.gitignore`,
  `.gitattributes`, `.codex/config.toml`, `.vscode/*.json`, `.github/workflows/checks.yml`, `scripts/check.ps1`, `assets/downtown/kit-b/MANIFEST.md`
  and `README.md`, `run_direction.ps1`, `compare.ps1`, `src/lookdev/Downtown/City/README.md`, decisions 0012, 0015, 0018, 0020,
  `ART\downtown-kit-b2\IMPORT-README.md`, `ART\island-preview.project.json`, `ART\open-island-test.ps1`, `ART\STUDIO_LOCK.txt`.
- `find`, `ls -l`, `du -sh` over `ART`, `BlenderScratch` and the Claude temp folder (names and sizes only).
- `node` JSON reads of the three kit `manifest.json` and `swatches.json` files and all 504 mesh JSON files (counts, byte sizes and
  meta-only sizes; nothing written).
- Context7 (Rojo docs and its `optional` build test) for the missing-optional-path behaviour and JSON-as-ModuleScript mapping.

## Appendix B: `ART` inventory snapshot (counted, 2026-10-26)

| Folder | Files | Size | Class (rows) |
|---|---|---|---|
| `downtown-kit-b2\` | 233 | 8.9 MB | runtime R-01 to R-03, source S-01, logs V-05 |
| `downtown-kit-worlds\` | 118 | 3.3 MB | runtime R-04 to R-06, source S-02 |
| `downtown-kit\` | 235 | 7.0 MB | runtime R-07, R-08, source S-03, logs V-05 |
| `island-kit\` | 218 | 22 MB | source S-04 |
| `island-kit-task4\` | 232 | 12 MB | source S-04 |
| `vehicles\` | 71 | 76 MB | source S-05 |
| `references\` | 87 | 46 MB | source S-06 |
| `review\` | 1,141 | 717 MB | review V-01 |
| `baselines\` | 150 | 4.1 MB | review V-02 |
| Top-level files | 15 | 9.8 MB | 7 `.rbxl` and 2 `.rbxl.lock` (B-06), `STUDIO_LOCK.txt` (B-05), `island-preview.project.json` + 3 `.bak`, `open-island-test.ps1` (B-07) |
| **Total** | **2,500** | **940,097,942 B** | |

## Checked and cleared (no external dependency found)

- **Fonts and engine textures:** `Font.fromName("FredokaOne")` (`src/shared/UI/Tokens.luau:139`, `ChaseCamera.luau:141`),
  `rbxasset://fonts/families/Nunito.json` and `BuilderSans.json` (`PreviewTokens.luau:210,216`), and
  `rbxasset://textures/particles/smoke_main.dds` (5 uses) are Roblox-provided.
- **Player headshot:** `Players:GetUserThumbnailAsync` inside `pcall` (`RunKit.luau:286`); absent, the glyph stays.
- **Icons and HUD art:** drawn in code; the only `ImageLabel.Image` write is the headshot. No image ids anywhere in `src/` or `playground/`.
- **Island decoder:** `KitMesh.luau:1-5` is a copy kept "so the Downtown look-dev place does not depend on the island branch".
- **The 14 test car meshes:** ids are documentation in `first-car-record.md`; no `rbxassetid` for them in code.
- **`playground/*/Lane3Playground.model.json`:** marker attributes only. **`claude-context/`, `context/`, `.vscode/`:** no art paths.
- **`.claude/` and `.agents/` skill packs:** no `Car-Hop-Art`; Windows-path hits are the Studio MCP launcher (B-08).

## Not verified

- **Google Drive**: identity, name, owner, access, contents, whether vehicle sources were copied. No Drive tool was used.
- **Nothing was executed**: no Studio, Blender, Rojo build, git write or `check.ps1`. The absent-folder behaviour is read from code and
  from Rojo docs; I did not build a playground without `ART` to watch it.
- **Determinism**: I did not rebuild the kit or recompute any plan digest, so "regeneration gives identical files" is unproven.
- **Roblox ownership and permissions**: whether Restricted or Open Use ids load for another account's place, and whether the 24 audio
  ids load or are licensed for a shipped game today. No network call was made; repository notes only.
- **File hashes**: no SHA-256 was computed for any art file. Sizes are byte counts from `ls` and `node`; folder sizes are `du` figures.
- **Helper scripts and review content**: V-04 files were found by name only; `review\` was inspected by type counts only.
- **Other branches**: counted `Car-Hop-Art` mentions by file name in the three sibling worktrees (main worktree: 9 files, island: 27
  files including `AssetIds.luau`, tooling: 6) and read only the header of `AssetIds.luau`. They were not audited.
- **Whether `.blend` files are fully derived from recipes** (island, vehicles). Island recipes are on another branch and were not compared.
