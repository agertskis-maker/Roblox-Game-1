---
name: project-visual-direction
description: Interprets reference images and style notes into one cohesive visual direction for this Roblox project, covering UI system, world composition, lighting, animation, effects, and sound, then proves it on a small representative sample before it spreads. Lane 3 UI is Figma-first: plan, Figma mockup and repository spec, owner approval, then build. Use when a request includes reference images, asks for a look, mood, or style, or adds or changes a screen, panel, HUD element, popup, region, or reward moment.
when_to_use: Also when reviewing whether UI, world, lighting, motion, and audio feel like one game, or when a ChatGPT prompt describes visuals in detail.
argument-hint: "[feature or screen name]"
---

# Visual direction

Goal: a game that looks and feels like one coherent thing, readable by young
players on a phone, with spectacle placed deliberately. This is not a chosen
art style; adapt to the selected concept and the owner's approved references.

Read `claude-context/04_VISUAL_UI_AND_GAME_FEEL.md` for the full standard and
`vault/design/` for any approved direction. If an approved direction exists,
extend it; do not invent a competing one. A TBD placeholder is not an approved
direction. For a long or mixed prompt, run `project-feature-intake` first; this
skill covers its look. A design-only brief still needs a one-line claim on
`vault/tasks/BOARD.md`, added when you start drafting it.

## 1. Observe each reference

For every image, list what is visible: composition, camera angle, palette,
shapes and silhouettes, spacing and density, typography, materials, lighting,
depth, implied motion. Keep a separate list of inferences (hidden menus,
mechanics, animation, asset rights). An image proves only what it shows. Write
"not shown" for properties it cannot show (a flat UI screenshot has no camera
angle or lighting).

## 2. Confirm what must be preserved

"Make it like this" is strong guidance, not a mandate for the whole reference.
List the qualities you plan to preserve and put them to the owner in the same
question batch; qualities not confirmed are inspiration.

Ask only questions whose answer would change the design, and ask all of them
as one batch. Decide reversible details yourself (timings, corner radii, exact
colors inside the named roles) instead of asking. State anything this skill,
`AGENTS.md`, or `CLAUDE.md` already settles (such as not copying assets) as a
constraint, not a question. Keep drafting on labelled assumptions while
questions are open.

Turn subjective words ("cooler", "amazing") into the named properties they
could change. If the readings would change the design, that is a question in
the batch; otherwise pick one and label it.

Label every choice: "from reference" (confirmed to preserve), "inspiration"
(not confirmed), "my proposal", or "constraint" (settled by the project rules).

## 3. Write the direction brief

Use `references/visual-brief-template.md`: intended emotion, silhouette
language, palette roles (primary action, danger, rarity tiers, disabled,
progress), typography roles, UI surfaces, icon vocabulary, lighting, motion
character, sound identity, and where the spectacle lives. "Colorful" is not a
direction; name what each color means. While no concept is selected, write the
concept as "undecided" and keep the brief concept-neutral.

Use the fonts and touch-target sizes approved in `vault/design/visual-direction.md`.
Anything not approved there is TBD, proposed for the owner's approval; never
hard-code an unapproved value.

For roles the reference does not show (danger, reward, rarity, progress),
propose one as "my proposal" where the design needs it, or write TBD; rarity
depends on the undecided economy. Items, prices, and currency that do not exist
yet are placeholders, labelled as placeholders.

## 4. Translate to Roblox

- UI: one shared token module in `src/shared` (colors, fonts, spacing, corner
  radius, stroke), not the Studio Style Editor, whose data lives in the place
  file and not in Git. This is provisional until the concept's visual direction
  is approved.
- UI surfaces: UICorner, UIStroke, UIGradient, consistent spacing, touch
  targets that clear mobile thumb controls and screen insets (size from the
  approved values), no hover-only essentials, never color alone for meaning.
- World: landmarks and paths that pull toward the next goal; collision separate
  from decoration where useful; readable at normal camera distance.
- Lighting and effects: tie every effect to an event; keep threats readable in
  weather; budget particles and Highlight use; provide a reduced-motion route
  (the mechanism is an open item, decided with the visual direction after the
  concept is chosen).
- Motion and sound: anticipation, acknowledgment, authoritative result, reward,
  return to control. Suggested starting timings are in
  `claude-context/04_VISUAL_UI_AND_GAME_FEEL.md`; tune in runtime.
- Devices: phone and desktop are the working baseline until the team decides.

For API detail load the matching third-party skill: roblox-gui, roblox-lighting,
roblox-animation-vfx, roblox-audio, roblox-building, roblox-camera.

## 5. Lane 3 UI: Figma first

Every new or changed Lane 3 screen, panel, HUD element, or popup follows this
order (`vault/decisions/0012-figma-ui-workflow.md`). Lane 1 and Lane 2 work does
not need Figma.

1. **Plan the screen**: purpose, entry and exit, every state (loading, empty,
   locked, can't afford, pending, success, error) and every button's behavior,
   to the interface standard in `claude-context/04_VISUAL_UI_AND_GAME_FEEL.md`.
2. **Mock it** in the one shared Figma file "Car Hop UI", one page per screen,
   with frames for phone portrait, phone landscape, and 1080p desktop. A panel
   opened during play is drawn as an overlay on a gameplay view. Colors,
   spacing, corner radius, and stroke are Figma variables named and valued as in
   `src/shared/UI/Tokens.luau`; draw nothing outside the module's values without
   listing it as a proposal. Frame sizes (my proposal, reversible): design
   pixels at UIScale 1.0, so phone portrait 390 x 844, phone landscape 844 x
   390, and desktop 1280 x 720, which is 1920 x 1080 at the module's 1.5 scale.
   Before drawing, load Figma's `figma-use` skill (and `figma-generate-design`
   for a screen, `figma-generate-library` for variables), as Figma requires.
3. **Spec it at the same time** in `vault/design/ui/<screen-name>.md` from
   `references/ui-spec-template.md`: every size, position, color token, font,
   state, button behavior, and animation timing, plus the Figma link. The build
   reads this file, so building never spends Figma reads.
4. **Review**: give the owner the Figma link and a short summary, and wait for
   approval. Record it in `vault/design/visual-direction.md` and in the spec.
5. **Figma reads are rationed** (free plan: up to 6 read tool calls a month;
   writes are exempt during the beta). Do not read to check your own writes,
   and do not call `get_screenshot`: the owner checks the mockup in Figma.
   Read only when the owner says they edited the mockup by hand; first report
   this month's count from `vault/design/ui/figma-reads.md`, then log the read
   there.
6. **Never paste Figma's generated code** into the game; it targets websites
   and iPhone apps. The Luau is written by hand from the spec
   (`project-feature-delivery`).
7. **Images drawn in Figma** that the game needs are exported, listed in
   `vault/design/assets.md`, and uploaded only with the owner's approval. Never
   invent an asset ID.

Fonts and touch-target sizes never come from a Figma default: use only values
the live record (`vault/design/visual-direction.md`, `AGENTS.md`) treats as
approved, and write TBD for anything it leaves undecided.

## 6. Prove it on a sample before spreading it

Mock or build the representative moments the request touches: for example one
panel, one reward moment, and one locked to unlocked (or unaffordable to
affordable) transition, plus the gameplay view when the feature lives in or
opens during gameplay. A shop or panel opened during play is reviewed as an
overlay on that view. For Lane 3 UI the mock is the Figma mockup and spec from
section 5. Otherwise a mock can be a described layout or sketch; mark it "not
captured" and capture it after an authorized build.

Building under `src/` needs the current request to authorize implementation
(`project-feature-delivery`); a request for a look or a brief is not that
authorization. A Rojo-synced test script is visible to
teammates in Team Create (`project-studio-verification`). Capture screenshots
(Studio MCP `screen_capture` if available) and review them together.

The repository owner, or the area owner once the board assigns one, approves
the sample. Record the approval in `vault/design/visual-direction.md`. Only
then apply the style widely.

## 7. Record

Offer to save the brief as `vault/design/visual-direction.md`, and save it when
the owner wants it kept. Keep `Status: draft` until the owner approves it, then
set `approved`. Once an asset is chosen, keep a manifest (source, rights, owner,
upload status, placeholder or final) in `vault/design/assets.md`. Record a
non-obvious choice as a decision note.

## Hard limits

- Allowed: imitating style traits (shape language, outlines, rounded panels,
  palette mood, layout patterns). Not allowed: copying logos, characters, item
  art, icons, unlicensed fonts, names, or a near-identical recreation of a
  distinctive screen.
- Never invent an asset ID. Check that assets load for the actual game owner.
- Never paste Figma's generated code into the game, never read Figma without
  the owner's hand-edit trigger and a reported count, and never buy or upgrade a
  Figma plan.
- Content suits a mainly young audience. No FOMO, coercive scarcity, streak
  pressure, or paid-luck tactics; monetization and paid randomness need an
  approved team design and current Roblox policy (`CLAUDE.md`).
- No ambient visual noise without a purpose; readability beats spectacle.

Worked example: `references/example.md`.
