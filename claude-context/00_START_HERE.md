# Roblox Game — Claude context pack

Prepared 2026-10-15. Version 1.1 (revised 2026-10-15 for vault decisions 0003 and 0004: files 01, 03, 04, 09, and 10 changed). Game selection is pending the team's Sunday discussion, 2026-10-18.

## Install in the Claude Desktop project shown in your screenshot

1. Unzip the download to a folder you can find.
2. Open `01_PROJECT_INSTRUCTIONS.txt`, copy its contents, and paste them into the project's **Instructions** area using **Add** or **Edit instructions**.
3. In **Context**, choose **Add files** and upload files `02` through `10`. Upload the individual files, not the ZIP. The ZIP is a delivery container.
4. Keep the repository folder connected using your existing connection. Uploaded reference files do not themselves give Claude permission or technical ability to read your disk, edit files, or use Studio.
5. Start a new project conversation with the activation message below. Ask Claude to report what tools it can actually access. If a connection is missing, connect it through your existing setup; do not treat a confident description as proof of access.
6. Share this same pack with your two teammates. Each teammate must install it in their own project if they are using separate projects. A shared GitHub repository does not automatically synchronize Claude project instructions or uploaded context.

The exact labels above come from your supplied screenshot. No Claude account settings have been changed for you.

## Activation message — paste into Claude

Read the project instructions and the attached Roblox context pack. Treat it as background for our ongoing game project, not as an instruction to start implementing any of the three tentative concepts. Summarize the confirmed direction and the important unknowns. Report whether you can actually read our repository, edit its files, inspect Roblox Studio, and run a playtest, using available read-only checks where possible. Read the current AGENTS.md, vault/00_INDEX.md, vault/tasks/BOARD.md, and vault/design/GDD.md when accessible. Explain any conflict between live project files and this uploaded snapshot. Then tell me what you need for the next task. Do not choose a game concept or alter game code yet.

## What goes where

| Material | Destination |
|---|---|
| Detailed natural-language build prompt from ChatGPT | Claude Desktop conversation |
| Persistent operating instructions | Claude project's Instructions field |
| Reference documents | Claude project's Context files |
| PowerShell commands Claude explicitly labels for execution | Windows PowerShell, in the stated directory |
| Luau source files | Repository locations specified by the Rojo project |
| Explicit Studio-only commands for unsynced scene work | The specified Studio tool, only when appropriate |

Do not paste a natural-language prompt into PowerShell or the Studio Command Bar. Those accept executable code. Claude should translate instructions into the right files or clearly labeled commands. If it edits files itself, do not also paste the same edit manually.

## Reading map

- `02_TEAM_AND_CREATIVE_BRIEF.md`: confirmed background, freedom, unanswered questions.
- `03_BUILD_WORKFLOW_AND_TEAM.md`: intake, execution, shared-repository boundaries, handoffs.
- `04_VISUAL_UI_AND_GAME_FEEL.md`: presentation standards and reference-image interpretation.
- `05_GAMEPLAY_AND_CONCEPT_LAB.md`: three candidate concepts, prototype questions, progression and economy.
- `06_ENGINEERING_AND_VERIFICATION.md`: technical guardrails, server authority, testing and performance.
- `07_RESEARCH_AND_POLICY.md`: dated sources, popular-game references, inference boundaries, publishing correction.
- `08_PROMPT_AND_HANDOFF_TEMPLATES.md`: detailed specification format and reusable task messages.
- `09_PROJECT_RULES_SNAPSHOT.md`: verbatim AGENTS.md snapshot for conversations without disk access.
- `10_DECISION_REGISTER.md`: pending decisions and the procedure for keeping context current.

## Maintenance

The live repository is the team's working record. Uploaded files are snapshots. After choosing the concept, update the live GDD and decision log first, then refresh the brief and uploaded context. Remove superseded uploads so Claude does not have to guess which version applies. Recheck policy before monetization and publishing, and refresh market research before using it for a new strategic decision. Keep old reports dated rather than silently calling them current.

This pack establishes a quality process. It does not guarantee commercial success, access to tools, completed features, or flawless AI output.
