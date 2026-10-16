# Decision register and update procedure

Snapshot date: 2026-10-15, revised the same day for vault decisions 0003, 0004 and 0005. The live vault is authoritative after the team makes decisions.

| Topic | Current status | Next action |
|---|---|---|
| AI workflow | Confirmed: ChatGPT/Codex drafts detailed prompts; Claude Desktop reviews/builds | Use explicit task modes |
| Repository | Confirmed: shared three-person GitHub project. Branch policy decided (0004): `main` for docs, vault, skills, and tooling; from the first game-code task, each person uses a feature branch and merges by pull request after the GitHub check passes. Branch protection is not enforced yet | Check branch/commit per task |
| Script workflow | Confirmed: Luau/Rojo/Wally/Rokit | Follow live AGENTS.md |
| Saving | Confirmed: vendored ProfileStore. The lifecycle module is a foundation that may start before the concept is chosen, but it touches saved data, so it needs the plan posted and an explicit go-ahead (0004) | One lifecycle owner; minimal template; mock tests |
| Local check exit codes | Confirmed (0003): `check.ps1` exit 0 means every check ran and passed; 1 means a check failed or a tool is missing; 2 means the OS blocked a tool so its check did not run, which is not a pass. CI treats a blocked tool as a failure | Report exit 2 as incomplete and confirm in the GitHub run |
| Approvals and planning | Confirmed (0004): "owner" is the repository owner until area owners are assigned; a one-line "Approved: ..." counts when it clearly refers to a specific request, spec, or ledger, and one reply may grant both a propose-first approval and a go-ahead; delivery posts a plan first and waits for an explicit go-ahead when saved data, the economy, monetization, or shared contracts are touched; a bare "Build X" gets a short intake, then the plan; when a precondition fails, post the questions plus a conditional plan and implement nothing until it is met | Follow AGENTS.md "Approvals and planning" |
| Work written by another session | Confirmed (0004): read board and log entries another session already wrote for the same work first, merge rather than duplicate, never rewrite their text, and say you built on them | Apply in every handoff |
| Propose-first items | Confirmed (0004): a new currency or any currency or economy field (including a last-claim timestamp for a currency reward), trading, PvP, breeding, permanent loss or theft, paid items or luck, cross-server systems, destructive prestige, a different art style, or changes to the creative premise need player benefit, cost, risk, and a test presented, then explicit owner approval, recorded as a decision note | Present before building |
| Questions rule | Confirmed (0004): ask every question whose answer would change the result, in one batch, no fixed cap; decide reversible details yourself and label them | Apply in every intake |
| Animation pipeline | Confirmed (0005): free tools only (Blender for keyframes, Mesh2Motion for rigs and a CC0 animation library); rigid props and UI are animated in code, skinned creatures with keyframed bones; Roblox drops bone scale, so squash and stretch on skinned creatures uses translation bones; Blender MCP always runs in safe mode; test imports use a local place with "Upload to Roblox" off; publishing an animation needs owner approval and the animation must be owned by the account or group that owns the experience. Not yet verified: runtime cost, a person's judgment of loop feel, publishing | Follow `docs/ANIMATION_PIPELINE.md`; decide where source art lives |
| Creative freedom | Confirmed within approved direction | Propose material changes separately |
| Concept | Undecided; three candidates. A concept counts as selected only when `vault/design/GDD.md` has `status: selected` and `concept:` naming it, plus a decision note; an "Approved:" on a feature never selects one (0004) | Team discussion planned Oct 18; record per the procedure below |
| Intended audience | Mostly children | Keep content appropriate; verify access separately |
| Release eligibility | Account-specific, not inspected | Verify Creator Hub before launch |
| Device scope | Unconfirmed | Phone/desktop review is provisional |
| Human roles and skills | Unconfirmed. Until area owners are assigned, "owner" means the repository owner (0004) | Assign area owners on the board at the concept meeting, before parallel feature work |
| Asset budget | Unconfirmed | No paid procurement assumed |
| Launch date | Unconfirmed | Choose after scope and capacity discussion |
| Art direction | Unconfirmed | Select references after concept choice |
| Visual references | Confirmed (0004): imitating style traits (shape language, outlines, rounded panels, palette mood, layout patterns) is allowed; copying logos, characters, item art, icons, unlicensed fonts, names, or a near-identical recreation of a distinctive screen is not. "Make it like this" is strong guidance, with the qualities to preserve confirmed by the owner in the same question batch | Apply in every visual direction |
| Representative sample | Confirmed (0004): approved by the repository owner, or the area owner once assigned, and recorded in `vault/design/visual-direction.md`; a shop or panel opened during play is reviewed as an overlay on the gameplay view | Plan the sample before spreading a style |
| UI style tokens | Provisional (0004): one shared module in `src/shared` (colors, fonts, spacing, corner radius, stroke), not the Studio Style Editor, because that data lives in the place file and not in Git | Revisit when the concept's visual direction is approved |
| Fonts and touch-target size | Undecided (0004) | Propose after the concept is chosen and the owner approves; do not hard-code |
| Reduced-motion mechanism | Open (0004) | Decide with the visual direction after the concept is chosen |
| Monetization | Interest in passes/luck, no approved design. Paid items and paid luck are propose-first and need an approved team design and current Roblox policy | Decide fairness and policy-compatible scope |
| Studio scene source | Not established in this pack | Agree how maps/assets are shared and backed up |
| Tool capabilities | User reports folder/Studio connection | Confirm in each implementation environment |

## After the concept meeting

Record the chosen concept and one-sentence pitch in vault/design/GDD.md, and set its frontmatter to `status: selected` with `concept:` naming it; a concept counts as selected only with that and a decision note. Record its core loop, first playable slice, signature moment, initial platform scope, deferred features, and task owners (area owners are assigned on the board). Add a decision note explaining the choice and the key tradeoff. Do not erase the other concepts from history, but mark them as unselected so they stop functioning as implied requirements.

Update files 02 and 05 to reflect the choice and update this register. Re-upload changed context files in each teammate's project and remove obsolete versions. The current plan should not depend on a teammate having seen the same conversation.

## Decision record format

Decision; date; owner; status; alternatives considered; reason; affected systems; required follow-up; what evidence would justify revisiting it.

## Assumption record format

Assumption; why it is needed now; reversible or consequential; affected work; validation method; owner; resolved status.

An assumption is not a team decision until confirmed or intentionally delegated. A research observation is not a design requirement until selected. A generated implementation is not verified until exercised with suitable evidence.
