---
name: project-visual-direction
description: Interprets reference images and style notes into one cohesive visual direction for this Roblox project, covering UI system, world composition, lighting, animation, effects, and sound, then proves it on a small representative sample before it spreads. Use when a request includes reference images, asks for a look, mood, or style, or adds a new screen, region, or reward moment.
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
skill covers its look.

## 1. Observe each reference

For every image, list what is visible: composition, camera angle, palette,
shapes and silhouettes, spacing and density, typography, materials, lighting,
depth, implied motion. Keep a separate list of inferences (hidden menus,
mechanics, animation, asset rights). An image proves only what it shows. Write
"not shown" for properties it cannot show (a flat UI screenshot has no camera
angle or lighting).

## 2. Confirm what must be preserved

Ask only questions whose answer would change the design, and ask all of them
as one batch. Decide reversible details yourself (timings, corner radii, exact
colors inside the named roles) instead of asking. State anything this skill,
`AGENTS.md`, or `CLAUDE.md` already settles (such as not copying assets) as a
constraint, not a question. Label each decision "my proposal". Keep drafting on
labelled assumptions while questions are open.

Turn subjective words ("cooler", "amazing") into the named properties they
could change. If the readings would change the design, that is a question in
the batch; otherwise pick one and label it.

Qualities the owner does not mark mandatory are inspiration. Label every later
choice as "from reference" or "my proposal".

## 3. Write the direction brief

Use `references/visual-brief-template.md`: intended emotion, silhouette
language, palette roles (primary action, danger, rarity tiers, disabled,
progress), typography roles, UI surfaces, icon vocabulary, lighting, motion
character, sound identity, and where the spectacle lives. "Colorful" is not a
direction; name what each color means. While no concept is selected, write the
concept as "undecided" and keep the brief concept-neutral.

## 4. Translate to Roblox

- UI: one style system (Studio Style Editor / shared style tokens), UICorner,
  UIStroke, UIGradient, consistent spacing, touch targets that clear mobile
  thumb controls and screen insets, no hover-only essentials, never color alone
  for meaning.
- World: landmarks and paths that pull toward the next goal; collision separate
  from decoration where useful; readable at normal camera distance.
- Lighting and effects: tie every effect to an event; keep threats readable in
  weather; budget particles and Highlight use; provide a reduced-motion route.
- Motion and sound: anticipation, acknowledgment, authoritative result, reward,
  return to control. Suggested starting timings are in
  `claude-context/04_VISUAL_UI_AND_GAME_FEEL.md`; tune in runtime.
- Devices: phone and desktop are the working baseline until the team decides.

For API detail load the matching third-party skill: roblox-gui, roblox-lighting,
roblox-animation-vfx, roblox-audio, roblox-building, roblox-camera.

## 5. Prove it on a sample before spreading it

Mock or build the representative moments the request touches: for example one
panel, one reward moment, and one locked to unlocked (or unaffordable to
affordable) transition, plus a gameplay view only when the feature lives in
gameplay. A mock can be a described layout or sketch; mark it "not captured"
and capture it after an authorized build. Building under `src/` needs the current request to
authorize implementation (`project-feature-delivery`), and a Rojo-synced test
script is visible to teammates in Team Create (`project-studio-verification`).
Capture screenshots (Studio MCP `screen_capture` if available) and review them
together. Only then apply the style widely.

## 6. Record

Offer to save the brief as `vault/design/visual-direction.md`, and save it when
the owner wants it kept. Keep `Status: draft` until the owner approves it, then
set `approved`.
Once an asset is chosen, keep a manifest (source, rights, owner, upload status,
placeholder or final) in `vault/design/assets.md`. Record a non-obvious choice as a decision
note.

## Hard limits

- Do not copy logos, characters, or proprietary assets from reference games.
- Never invent an asset ID. Check that assets load for the actual game owner.
- Content suits a mainly young audience. No FOMO, coercive scarcity, streak
  pressure, or paid-luck tactics; monetization and paid randomness need an
  approved team design and current Roblox policy (`CLAUDE.md`).
- No ambient visual noise without a purpose; readability beats spectacle.

Worked example: `references/example.md`.
