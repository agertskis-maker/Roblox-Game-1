# Decision register and update procedure

Snapshot date: 2026-10-15. The live vault is authoritative after the team makes decisions.

| Topic | Current status | Next action |
|---|---|---|
| AI workflow | Confirmed: ChatGPT/Codex drafts detailed prompts; Claude Desktop reviews/builds | Use explicit task modes |
| Repository | Confirmed: shared three-person GitHub project | Check branch/commit per task |
| Script workflow | Confirmed: Luau/Rojo/Wally/Rokit | Follow live AGENTS.md |
| Saving | Confirmed: vendored ProfileStore | One lifecycle owner; mock tests |
| Creative freedom | Confirmed within approved direction | Propose material changes separately |
| Concept | Undecided; three candidates | Team discussion planned Oct 18 |
| Intended audience | Mostly children | Keep content appropriate; verify access separately |
| Release eligibility | Account-specific, not inspected | Verify Creator Hub before launch |
| Device scope | Unconfirmed | Phone/desktop review is provisional |
| Human roles and skills | Unconfirmed | Assign ownership before parallel feature work |
| Asset budget | Unconfirmed | No paid procurement assumed |
| Launch date | Unconfirmed | Choose after scope and capacity discussion |
| Art direction | Unconfirmed | Select references after concept choice |
| Monetization | Interest in passes/luck, no approved design | Decide fairness and policy-compatible scope |
| Studio scene source | Not established in this pack | Agree how maps/assets are shared and backed up |
| Tool capabilities | User reports folder/Studio connection | Confirm in each implementation environment |

## After the concept meeting

Record the chosen concept and one-sentence pitch in vault/design/GDD.md. Record its core loop, first playable slice, signature moment, initial platform scope, deferred features, and task owners. Add a decision note explaining the choice and the key tradeoff. Do not erase the other concepts from history, but mark them as unselected so they stop functioning as implied requirements.

Update files 02 and 05 to reflect the choice and update this register. Re-upload changed context files in each teammate's project and remove obsolete versions. The current plan should not depend on a teammate having seen the same conversation.

## Decision record format

Decision; date; owner; status; alternatives considered; reason; affected systems; required follow-up; what evidence would justify revisiting it.

## Assumption record format

Assumption; why it is needed now; reversible or consequential; affected work; validation method; owner; resolved status.

An assumption is not a team decision until confirmed or intentionally delegated. A research observation is not a design requirement until selected. A generated implementation is not verified until exercised with suitable evidence.
