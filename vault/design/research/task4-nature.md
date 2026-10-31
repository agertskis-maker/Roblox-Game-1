---
title: Task 4 nature research (waterfall, cliffs, rainbow, river, flower beds)
status: research
date: 2026-10-22
lane: 3
images: C:\Users\agert\Documents\Car-Hop-Art\references\island-task4\nature\
---

# Task 4 nature research

Research only, not approved. **(inference)** marks my proposals for a 5-stud
avatar (Roblox defaults WalkSpeed 16, JumpHeight 7.2, MaxSlopeAngle 89°), not
source values. All sources accessed 2026-10-22. Downloaded images are study
only; never import them.

## Sources (images viewed in the folder above)

- **S1** Roblox, Create waterfalls: https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/create-waterfalls (viewed `roblox-waterfall-Falls-Components.png`, `-Falls-NoComponents.png`, `-Rainbow-4D.png`)
- **S2** A Short Hike press kit: https://ashorthike.com/press/ (viewed `ashorthike-screen3.png` waterfall/pool/bridge, `screen1`, `screen4`)
- **S3** 80.lv, Zehra Khan valley breakdown: https://80.lv/articles/breakdown-stylized-fantasy-valley-where-elves-live/ (text only)
- **S4** HyperPhysics, Rainbow in Waterfall: https://hyperphysics.gsu.edu/hbase/atmos/watfal.html (viewed `hyperphysics-athabasca-rainbow.jpg`)
- **S5** Mississippi State Extension: https://extension.msstate.edu/lawn-and-garden/flower-gardens/designing-perennial-plantings; support from https://www.burpee.com/blogs/garden-care/designing-beds-using-layers-in-the-garden_article10604 and https://daviddomoney.com/how-do-you-plant-in-drifts; Wikimedia Commons photos viewed: `commons-kew-circular-bed.jpg`, `commons-dunbar-circular-bed.jpg`, `commons-villandry-fountain.jpg`
- **S6** Roblox reference, Humanoid and Terrain: https://create.roblox.com/docs/reference/engine/classes/Humanoid, https://create.roblox.com/docs/reference/engine/classes/Terrain

## Observations

### 1. Waterfall as five layers (S1)
- **Observed:** Annotated photo labels white water (lip), cascades (curtain), splashes, foam (impact) and mist (base).
- **Application:** One `Waterfall` model with separately named lip, curtain Beams, splash, foam and mist emitters, so each can be tuned or disabled alone.
- **Limitation:** Real, dark photo; only the structure transfers.

### 2. Curtain Beams fade at both ends (S1)
- **Observed:** Drop Beams: Width0 5 → Width1 10–20, TextureSpeed 1.0–1.3, transparency 1 → 0 over the first 11%, 0 until 84%, then back to 1. Outflow Beam 60 → 20, speed 0.4.
- **Inference:** One strong curtain = 3–5 overlapping Beams at two speeds, not many thin ones.
- **Application:** 12–16 stud curtain from the second ledge: 3–5 Beams tapering 4–6 → 6–10 studs, ~10% fade each end.
- **Limitation:** Tutorial textures are Roblox assets; confirm permission before reuse.

### 3. Teal center, hard white edges (S2)
- **Observed:** Flat teal-cyan sheet with darker streaks; thick hard-edged white bands at lip and impact; thin bright-cyan line where water meets rock; no soft gradients.
- **Application (inference):** Center Beams ~RGB 90,200,200 at Transparency 0.25–0.45; edge and lip Beams ~230,250,255 at 0–0.15, 1.5–3 studs wide; white lip band 2–4 studs tall.
- **Limitation:** Top-down pixel camera; our lower camera sees the curtain face-on and needs more center texture.

### 4. Impact, foam and mist sizes (S1)
- **Observed:** Splash Rate 30, Lifetime 0.25–0.35, Size 1.8 → 5.75. Foam ripples Rate 5, Size 5 → 20, flat on water. Base mist Size 8–10; rising mist Size 20–25, Lifetime 4, Rate 3; mist never below Transparency 0.8.
- **Application (inference):** Pool 2.5–3× curtain width (30–45 studs) so the 20-stud foam ring stays inside; mist Transparency ≥ 0.8.
- **Limitation:** Particles cost phone frame time; profile before a second fall.

### 5. Cliffs: few large masses, reused (S3, S2)
- **Observed:** S3 built all cliffs from 4 unique meshes, repeated, with small rocks pushed in for variety. S2 cliffs are broad faces with flat bands and few cracks.
- **Inference:** Per cliff group, 1 large : 2–3 medium : 4–6 small; silhouette from large and medium only.
- **Application:** 3–4 unique faceted cliff MeshParts of 30–60 studs, ledge blocks 10–20, rocks 2–6. Add a ledge only if it is ≥ 6 studs deep (standable) or visibly splits the fall.
- **Limitation:** S3 blends in Unreal shaders; Roblox needs modeled color facets.

### 6. Grass on tops, wet dark rock by water (S3, S2)
- **Observed:** S3 tints up-facing faces green and darkens rocks by world height near water. S2 grass sits only on flat tops; rock beside the falls is darker.
- **Application (inference):** Grass caps only on faces within ~30° of flat. Wet band 4–8 studs either side of the curtain and 1–2 studs above the pool line; moss strips 1–3 studs wide inside that band.
- **Limitation:** No shader masks on MeshParts; keep bands as few separate facets.

### 7. Rainbow geometry (S4)
- **Observed:** Primary bow, an arc about 40–42° around the antisolar point; the sun must be behind the viewer; red outside, blue inside. The Athabasca photo shows only a short arc where spray exists.
- **Application:** Place on the mist side facing the main viewpoint, with the sun set behind that viewpoint; partial arc over the mist only.
- **Limitation:** A changing ClockTime breaks the geometry; fix the time or accept it.

### 8. Soft rainbow particle (S1)
- **Observed:** One emitter: Size 25, Rate 0.25, Lifetime 2–4, Speed 0, LightEmission 1, LightInfluence 0, Rotation -20; transparency 1 → ~0.36 → 1.
- **Application (inference):** Size 1.5–2× curtain width; lowest transparency 0.35–0.55; slow fade, no flashing. Static Beam arc as fallback.
- **Limitation:** Texture permission in our place unverified.

### 9. River width, banks, bridges (S6, S2)
- **Observed:** JumpHeight 7.2 at WalkSpeed 16 gives ~0.54 s airtime, about 8–9 studs of horizontal travel (my calculation). MaxSlopeAngle 89°, so bank slope never blocks walking. Terrain water has one global WaterColor (default dark teal), Transparency 0.3, Reflectance 1. S2 shows a bright edge line and a straight plank bridge over a narrow stream.
- **Application (inference):** Constant width 14–20 studs (wider than a jump, so bridges matter); banks 1:3–1:4 (~14–18°) over 4–6 studs; depth 2–3 studs; bend radius ≥ 2× width; build half the loop and mirror it; bridges 8–12 studs wide, 2–3 studs above water, low rails.
- **Limitation:** Gentle banks are visual only. Water tint is global, so pool and river match.

### 10. Round junction and fountain beds (S5, Kew, Villandry)
- **Observed:** MSU: tallest plants in the center of island beds; planting width about 2× the tallest plant; broad edging of flat brick or flagstone. Kew: concentric solid color rings around a central urn, a few spaced tall plants, a curb edge. Villandry: stone basin in gravel inside symmetric hedges.
- **Application (inference):** Junction beds 14–20 studs across; center 4–5 studs tall, middle ring 2–3, edge 0.8–1.5; stone border 1–1.5 wide, 0.5–1 tall; fountain beds keep a 1–2 stud gravel ring inside the planting.
- **Limitation:** Heights are scaled for reading, not botany; edge plants stay below avatar eye level (~4.5 studs).

### 11. Curved avenue beds: broad drifts (S5, Dunbar)
- **Observed:** Odd groups (3, 5, 7) in curving, repeated drifts (Domoney); two complementary colors plus white (Burpee). Dunbar: tall red dahlias at the back, wide white and yellow snapdragon patches in the middle, pink and white begonias at the edge, each a solid patch.
- **Application (inference):** Avenue beds 6–10 studs deep; each drift 6–12 studs long from 3, 5 or 7 clusters; 3–4 colors per bed; repeat the order on the mirrored side.
- **Limitation:** Faceted flowers are clumps; count clusters and watch part count.

## Gaps
- No S3 cliff images could be identified; cliff visuals rely on S2.
- No source gives river-loop dimensions; observation 9 is mostly inference.
- No Zelda, Sea of Thieves or Fortnite screenshots were viewed.
