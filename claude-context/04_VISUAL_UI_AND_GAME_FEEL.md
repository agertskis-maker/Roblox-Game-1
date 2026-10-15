# Visual direction, UI, and game feel

These are production standards and design recommendations, not a chosen art style. Adapt them to the selected concept and approved references.

## Establish an art direction before multiplying screens

Define the intended emotion, silhouette language, material treatment, palette roles, typography roles, lighting, UI surfaces, icon vocabulary, animation character, and sound identity. Specify a dominant treatment and limited accents. “Colorful” is not sufficient: identify which color communicates primary action, danger, rarity, disabled state, and progression.

Create a small representative sample before spreading the direction everywhere: the moments the feature touches, for example one inventory or collection panel, one reward moment, and one locked-to-unlocked (or unaffordable-to-affordable) transition, plus the gameplay view when the feature lives in or opens during gameplay; a shop or panel opened during play is reviewed as an overlay on that view. A mock can be a described layout or sketch. Review them together. The repository owner, or the area owner once the board assigns one, approves the sample, and the approval is recorded in `vault/design/visual-direction.md`. Keep an intentional relationship between the world and interface; do not combine an ornate fantasy inventory with unrelated flat corporate controls unless deliberately requested.

Choose where the spectacle lives. A landmark, transformation, storm wall, creature reveal, or scale transition can be the visual centerpiece. Quiet surrounding elements make it legible. Do not give every object a glow, bouncing label, animated gradient, and particle trail.

## Interpret reference images precisely

For every image, identify observable composition, camera angle, palette, shape, spacing, density, typography, materials, lighting, depth, and motion cues if available. Separate these observations from inferred behavior. Ask what must be preserved when the answer changes the design. A screenshot cannot prove its hidden menu flow, server architecture, animation, or asset rights.

Translate reference qualities into Roblox constraints. A cinematic scene may need a simplified gameplay version with clear navigation. A desktop menu may need a rearranged phone layout. Match the intended mood without copying another creator's logos, distinctive characters, or proprietary assets. Keep a traceable list of which choices came from the reference and which are new proposals.

## Interface specification for every important screen

Describe purpose, entry points, hierarchy, primary action, secondary actions, dismissal, relationship to the gameplay camera, and what the player can still do while it is open. Specify the data each control displays and which server action it requests.

Include the states that players actually encounter:

- Loading, populated, empty, and unavailable data.
- Locked content with a clear explanation of the missing requirement.
- Affordable and unaffordable actions without relying only on color.
- Pending request, success, rejection, and retry where retry is safe.
- Full inventory, missing selection, duplicate tap, and stale selection.
- Long names, large values, localized text expansion, and narrow screens.
- Touch, mouse, keyboard, and controller focus for supported devices.

Every visible actionable control must have a real behavior or a clearly explained unavailable state. Avoid fake badges, fake player counts, and impressive-looking dashboards disconnected from gameplay.

Use consistent spacing, readable contrast, predictable close/back behavior, and touch targets that remain comfortable on the actual device. Respect screen insets and Roblox's own controls. Reserve space for mobile movement and jump controls. Essential actions must not depend on hover. Test scrolling and scrolling-versus-tapping conflicts. Preserve a clear focus path if controller support is selected.

## Gameplay HUD

Keep the current objective, immediately relevant resource, and urgent state readable at a glance. Move collection management, detailed odds, settings, and secondary systems into deliberate panels. Avoid permanently covering the world with shop buttons. Newly unlocked features should be introduced when relevant, not dumped on the player at spawn.

Explain costs before an action, show the resulting change after it, and keep displayed values synchronized with authoritative state. Use number formatting that remains understandable as values grow. Cosmetic count-up animations must end on the server-provided value rather than become a second economy calculation.

## Feedback as a coherent sequence

For a meaningful interaction, specify anticipation, input acknowledgment, authoritative result, reward presentation, and return to control. Local feedback may acknowledge an input immediately, but it must not falsely confirm ownership or a purchase before the server accepts it.

Coordinate motion, scale, lighting, sound, and UI around the same event. Small frequent rewards should resolve quickly; major milestones can support a more elaborate reveal. Provide a reduced-motion route for strong shake or repeated flashes. Avoid audio stacking when many players or rewards trigger at once.

Suggested timing ranges for a first prototype, not universal rules: button acknowledgment around 80–150 ms; small panel transitions around 150–250 ms; meaningful milestone celebrations around 0.6–1.2 seconds before normal interaction resumes. Tune in runtime. Network latency is separate from animation timing and must be handled explicitly.

## Visible progression and social display

Show achievement through distinct silhouettes, meaningful size tiers, habitats, trophies, aura restraint, world reactions, or an evolving home area. Make it readable from a normal camera distance. Let players understand another player's accomplishment without needing to open a stats page.

Status should not make the game unusable for newcomers. Large characters must not permanently obscure paths or the camera. Powerful effects must not blind nearby players. Public displays should communicate what was earned; avoid implying a purchased cosmetic proves gameplay skill.

## World composition

Use landmarks, framing, color transitions, and paths to guide movement. Put the next desirable destination somewhere players can notice it. Test routes with the smallest and largest supported player forms. Separate decorative geometry from collision geometry when appropriate. Consider spawn safety, return routes, crowding, interaction reach, and line of sight before adding detail.

For weather, preserve navigation and threat cues in low visibility. Presentation can be local; outcomes must remain authoritative. A storm should change a decision or communicate a challenge, not merely make the screen harder to read.

## Asset and quality review

Keep an asset manifest with source, rights, creator/owner, intended use, upload status, and replacement status for temporary art. Never invent a usable asset ID. Test asset availability under the actual experience owner; personal access is not proof that a group-owned game can load it.

Capture the same representative scenes across revisions. Review target phone and desktop layouts if those remain the working baseline. Check clipped text, overlapping controls, unreadable backgrounds, inconsistent icons, broken focus, excessive visual density, repeated animation, and crowded multiplayer scenes. Explain what was visually inspected and what remains hypothetical.

The desired result is a memorable game with an understandable visual language. Treat “mind-blowing” as a demand for thoughtful composition and excellent moments, not permission to sacrifice clarity or performance.
