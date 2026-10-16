# Animation pipeline (free tools only)

How this team makes animation for Roblox without paid tools. Written for the
three of us, including whoever works through ChatGPT or Codex. The concept is
still undecided, so nothing here is game-specific.

Everything marked **tested** was run on 2026-10-15 with Blender 5.2.2 LTS,
Roblox Studio 0.743.0, Rojo 7.7.1 and Mesh2Motion (web app, git b04ee333b). Menu
names can move in newer builds. Everything marked **docs** comes from the
current Roblox Creator docs and was not run here.

## 1. What goes where

| Thing | How to animate it | Why |
|---|---|---|
| UI, damage numbers, popups, buttons, icons | Code: `TweenService` or springs | No rig needed, easy to retune |
| Rigid props: eggs, chests, pickups, simple pets that are one solid piece | Code: tween the part's `Size` or `CFrame` with a spring | Scale is allowed on whole parts, and it is cheap |
| Characters and creatures with a skin (a mesh bent by bones) | Blender keyframes, or a Mesh2Motion rig, exported as FBX | Bones are the only way to bend a mesh |
| Squash and stretch on a skinned creature | Translation-only deform bones (section 5) | Roblox drops bone scale (tested, section 7) |

Rule of thumb: if it is one solid piece, move it in code. If it has to bend, use bones.

## 2. The one fact that shapes everything

**Roblox bones move and rotate. They cannot scale.** A bone's pose is a
`CFrame`, and a `CFrame` has no scale.

- Tested: the real importer read a Blender rig whose bone was scaled to squash a
  blob. Its animation clip stored no scale at all (every rotation axis length was
  exactly 1.000), so the blob did not squash.
- Tested: assigning a scaled matrix to `Bone.Transform` stored the identity
  matrix and the mesh did not change.
- Worse than "no squash": the child bones still moved as if the parent had been
  squashed, so a head sank into the unsquashed body on landing.

So in Blender never animate bone scale. Use translation and rotation only.

## 3. One-time setup (each person, each machine)

You need: Blender 5.2 LTS, `uv`, the MCP server, and the Blender add-on. Do
this in a normal terminal, not inside Studio.

1. **Blender 5.2 LTS** from blender.org (installer). 5.3 was a beta on
   2026-10-15; use the LTS. Open Blender once and close it, so it creates your
   user add-ons folder.
2. **uv** from docs.astral.sh/uv (official installer). Check with `uv --version`.
   It puts `uvx` in `C:\Users\<you>\.local\bin`.
3. **Claude Code** (from the repo folder, so it is registered for this project
   only):
   ```
   claude mcp add blender -e BLENDER_MCP_SAFE_MODE=1 -e DISABLE_TELEMETRY=true -- uvx mcp-for-blender
   ```
   If it shows `spawn uvx ENOENT`, use the full path
   (`C:\Users\<you>\.local\bin\uvx.exe`) or `cmd /c uvx mcp-for-blender`.
   Restart Claude Code, then run `claude mcp list` and look for `blender` with a
   tick.
4. **Codex** (not tested here). Add this to your own `~/.codex/config.toml`,
   not the repo file, because the add-on is installed per machine:
   ```toml
   [mcp_servers.blender]
   command = "uvx"
   args = ["mcp-for-blender"]
   env = { BLENDER_MCP_SAFE_MODE = "1", DISABLE_TELEMETRY = "true" }
   ```
5. **Add-on:** run `uvx mcp-for-blender install-addon`. If it cannot find the
   folder, `uvx mcp-for-blender addon-paths` shows where it looks. In Blender:
   Edit, Preferences, Add-ons, search "MCP for Blender", tick it.
6. **Leave these off:** telemetry, Poly Haven, Sketchfab, Hyper3D, Hunyuan3D.
   They send data to outside services or can use credits.
7. **Check it works:** with Blender open, ask Claude to run `get_addon_status`.
   Expect Blender 5.2, telemetry off, libraries off.

### Safe mode: what it does and what it does not do

`BLENDER_MCP_SAFE_MODE=1` makes the MCP server check every script before it
runs. Do not turn it off. If it blocks a step, stop and ask the owner.

- Allowed (tested): `bpy`, `bmesh`, `mathutils` and plain Python; saving;
  opening a `.blend`; FBX export and import; rendering and `look` previews.
- Blocked: `open`, `eval`/`exec`, `os`/`subprocess`/network, handlers, timers,
  drivers, registering classes or properties, and loading datablocks from other
  files. Also refused before running (tested): `yield` generators, `lambda`,
  and `:=`. Write plain `def` functions and loops.
- Because file writing is blocked, to dump data to a file run Blender from a
  terminal: `blender -b file.blend --python script.py -- args`. That is your own
  command, not the MCP.
- **Limit:** safe mode is enforced by the MCP server, not by the add-on. The
  add-on listens on `127.0.0.1:9876`, so any program on your computer that
  connects there skips safe mode. Stop the server when you are not using it:
  in Blender press N, open the "MCP for Blender" tab, click **Disconnect**.
  The add-on starts the server by itself when Blender opens (setting
  "Auto-Start Server"); turn that off if you prefer.

## 4. Making an animation in Blender

Keep working files in a scratch folder outside the repo (we use
`%USERPROFILE%\BlenderScratch`). Do not commit `.blend`, `.fbx` or `.rbxl`
files until the team decides where source art lives (open item, section 11).

Rig rules (docs, and all of them held in our tests):

- Bone names are unique, and no bone has the same name as the mesh.
- The mesh has location 0, rotation 0, scale 1 before skinning (apply
  transforms).
- Root at the origin. **No vertex weight on the root bone**: put a static,
  empty `root` above the first bone that moves (we used `root` then `base`).
- At most **4 bones influence any vertex**.
- Our test rigs point every bone up with roll 0, which keeps the axes easy to
  reason about. Expect Blender's +X to become Roblox's -X after import.
- 30 fps, and for a loop the last frame equals the first frame.
- Use smooth (Bezier, auto-clamped) keys, never linear.
- Do not animate bone scale (section 2).

### Squash and stretch with translation bones (tested recipe)

A blob 2.5 wide and 3.2 tall, 11 bones:

- `root` (static), `base` (carries the hop), four side bones around a low ring
  (`belly_R/L/F/B`), four around a high ring (`upper_R/L/F/B`), and `head`.
- Weights: blend linearly by height between the ground, the low ring, the high
  ring and the head. Split sideways between the two nearest side bones.
- To squash: move the side bones out and the whole body down. To stretch: move
  them in and up. Starting values: sideways move = 1.36 x radius x (width
  factor - 1); vertical move at a ring = (height factor - 1) x that ring's
  height; the head moves (height factor - 1) x full height.
- Tested result against true scale squash: at the worst frame (landing) the
  typical (RMS) error was 1.6% of the height and the top height was exact; the
  widest point was about 6% too wide. A cheaper layout (one ring plus a top
  bone) showed a visible ledge on landing, so use two rings.
- Eyes and other small parts: skin each one rigidly (same weights on all its
  vertices) so they do not stretch.
- Cost: 3 bones became 10, and keys grew from about 50 to about 170. Runtime
  cost in Roblox was **not measured**. It is probably small for one creature
  and worth measuring before many are on screen at once (MicroProfiler).

### Cartoony motion rules

- **Squash and stretch:** squash on landing, stretch on takeoff and in fast
  falls. Keep the volume roughly the same (wider when shorter).
- **Anticipation:** a small opposite move before a big one (crouch before a jump).
- **Overshoot and settle:** go slightly past the end pose, then ease back.
- **Follow-through:** heads, tails and ears arrive a few frames after the body.
- **Easing:** ease in and out. No linear keys.
- **Readable at small size:** exaggerate. This audience is mostly children and
  many will see it on a phone.
- **Keep clips short:** 0.5 to 2 seconds for loops; one-shots under 3 seconds.

## 5. Exporting the FBX

Blender: File, Export, FBX (.fbx). Select the mesh and armature, tick
"Selected Objects". Settings that matter (tested; the first group are the ones
the Blender defaults get wrong for Roblox):

| Setting | Value |
|---|---|
| Path Mode | Copy, and tick "Embed Textures" |
| Apply Scalings | FBX Units Scale |
| Add Leaf Bones | off |
| Bake Animation | on |
| NLA Strips | off |
| All Actions | off (default is on; only the active action is wanted) |
| Simplify | 0.0 (default is 1.0) |
| Force Start/End Keying | on |
| Object types | Armature and Mesh only |
| Forward / Up | defaults: -Z forward, Y up |
| Apply Transform | off |

Through the MCP the same export is `bpy.ops.export_scene.fbx(...)` with
`use_selection=True`, `object_types={'ARMATURE','MESH'}`,
`apply_scale_options='FBX_SCALE_UNITS'`, `add_leaf_bones=False`,
`bake_anim=True`, `bake_anim_use_nla_strips=False`,
`bake_anim_use_all_actions=False`, `bake_anim_simplify_factor=0.0`,
`path_mode='COPY'`, `embed_textures=True`.

Before importing, check the file by re-importing it in a separate Blender: bone
names, no leaf bones, scale 1.0, no varying scale channels, last key equals the
first.

## 6. Importing into Studio

Do this in a **local test place, not the Team Create place**. A Rojo build is
enough: a project file with a `Baseplate` part, then
`rojo build file.project.json --output BounceTest.rbxl` outside the repo.

Tested click path (Studio 0.743.0):

1. **Home** tab, then **Import** (the icon with a cube, just right of the green
   **Script** icon). Careful: **Script** sits next to it, and the **Import**
   inside the Terrain Editor panel is for terrain.
2. Pick the `.fbx` in the "Open 3D File" window.
3. In the **Import Preview** window, under **File General**, **untick "Upload to
   Roblox"**. It is ON by default and turns itself back on for every import. On
   means a real asset is created in your account and sent to moderation.
4. Rig Type is chosen automatically; it said **Custom** for our blob.
5. Click **Import**.

What you get (tested): a `Model` with one `MeshPart`, the bones nested under it
with their Blender names and hierarchy, an `AnimationController`, an
`InitialPoses` folder and an `AnimSaves` value. The animation is already there:
select the model, then **Avatar** tab, **Clip Editor**, and the clip shows in
the editor. The clips are saved as `KeyframeSequence` objects in
`ServerStorage.RBX_ANIMSAVES.<model>.<clip>`. A Blender export arrives as one
clip called `Scene`; a Mesh2Motion file arrives as one clip per animation.

What the importer did to our files (tested):

- Size: 1 Blender unit became 1 stud (a 3.2 tall blob is 3.2 studs).
- Facing: with the default export axes the model faces -Z, which is Roblox's
  front. Blender front is -Y.
- Side names: a bone you called `R` on Blender's +X ends up on Roblox's -X.
  Name bones by the creature's own left and right, not by world side.
- Colors: Blender material colors are not imported (the blob is gray). Only
  textures come through.
- Zero-influence bones: bones that influence nothing are dropped by default,
  but a bone that is the parent of weighted bones stays.
- All clips are flagged looping, including one-shots such as a jump.

Playing a clip in code, for a local test (docs, and worked here):

```lua
local KFSP = game:GetService("KeyframeSequenceProvider")
local clip = game.ServerStorage.RBX_ANIMSAVES.MyRig.Scene
local animation = Instance.new("Animation")
animation.AnimationId = KFSP:RegisterKeyframeSequence(clip) -- local only
local animator = rig.AnimationController:FindFirstChildOfClass("Animator")
local track = animator:LoadAnimation(animation)
track.Looped = false -- the importer sets looping on every clip
track:Play()
```

In edit mode, `animator:StepAnimations(dt)` with `dt` above zero advances it
(used only for tests; a zero step does nothing). Setting `track.TimePosition`
first lets you jump to a frame.

## 7. Verification ledger (2026-10-15)

| Claim | Level | How |
|---|---|---|
| FBX files import with the right bones, unit scale and hierarchy | tested, real importer | Studio read back through the MCP |
| Bone scale does not survive | tested, real importer + runtime | clip data; scaled matrix stored as identity |
| Translation bones bend the mesh and keep the timing | tested, real importer + runtime | clip values matched authored to 2 decimals; rendered frames |
| Two-ring squash looks right | Blender preview and Roblox render, by me | `look` and `screen_capture` frames |
| Feels good in motion at 30 fps | **not checked by a person** | needs a human look at the loop |
| Runtime cost of extra bones | **not measured** | needs MicroProfiler with many copies |
| Publishing, animation IDs, ownership | **not run** | docs only (section 9) |
| Codex MCP setup | **not run** | config shown from the Codex format |

## 8. Mesh2Motion (rigs and a free animation library)

A free web tool (app.mesh2motion.org) with about 170 animations for humans and
creatures (fox, bird, dragon, kaiju, spider, snake, fish, horse). It can also
auto-rig a model you upload, though we only tested the sample fox.

- **License (docs):** animations and sample assets are CC0, free for personal
  and commercial use; some human animations are by Quaternius; the tool's code is
  MIT. No account needed.
- **Workflow (tested):** open the app, pick a model (Fox), tick the animations
  you want (we took Idle, Walk, Run, Jump), open the small arrow beside
  **Download**, choose **FBX 7.4**, preset **Unity**, contents **Default**, then
  **Download**. A thank-you box appears; close it.
- **Preset matters (tested):** the **Unreal** preset arrives lying on its tail
  (its long side along Y). **Unity** arrives upright with its length along Z.
  Use Unity.
- **What the file is (tested):** 49 bones, unique names, a `root` bone, at most
  2 influences per vertex, no scale animation, 24 fps. In Studio: 39 bones kept
  (zero-influence ones dropped), 3.6 studs long and 1.7 tall, clips Idle 1.33 s,
  Walk 1.0 s, Run 0.47 s, Jump 2.2 s, texture came through.
- **Direction (tested):** the fox's head points **+Z**, which is the back in
  Roblox. Turn it 180 degrees about Y in code or in Blender.
- **Blender note (tested):** Blender 5.2's older FBX reader returned nothing
  from this file; the native reader (`wm.fbx_import`) worked. If File, Import,
  FBX shows an empty scene, use the other FBX entry.
- **Squash:** these rigs have no squash bones. Add the same side and top bones
  if we want squash on them, or squash the whole creature in code.
- **Not tested:** uploading our own mesh to auto-rig, and the retarget page
  ("Use Your Rigged Model").

## 9. Publishing and who owns an animation (docs, not run)

- An animation only plays in the live game if the account or group that owns the
  experience owns the animation. Create it under the same owner.
- Publishing is a separate upload from importing. In the clip editor's menu
  look for "Publish to Roblox", name it, save, and copy the ID.
- **Do not publish without the owner's approval.** Local testing with
  `RegisterKeyframeSequence` needs no upload.
- Check the **Creator** box in the import window before any upload that is
  approved; it said "Me" for a personal account.

## 10. Known problems and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Squash is missing, head sinks into the body | Bone scale was animated | Translation bones (section 4) |
| Blob looks lumpy or has a ledge on landing | Only one ring of side bones | Two rings, linear height blend |
| Model lies on its side or stands on its tail | Export axes or Mesh2Motion Unreal preset | Default axes; Unity preset |
| Creature faces backwards | Head toward +Z | Rotate 180 degrees about Y |
| Everything is gray | Blender material colors are not imported | Texture, or set `Color` in code |
| Studio viewport is black | Window minimized, or a script tab covers the 3D view | Restore the window, click the place tab |
| Import made a real asset | "Upload to Roblox" was left on | Untick it each time (section 6) |
| `Animator is not a valid member` | Animator is created when the clip editor opens | Create one in code if missing |
| Safe mode rejects a script | `yield`, `lambda`, `:=` or `open` | Plain loops and functions; terminal for files |
| Jump loops forever | Importer flags every clip as looping | `track.Looped = false` |

## 11. Open items

- Where source `.blend` and exported `.fbx` files live (repo folder, LFS, or
  shared drive) and who approves new ones.
- Which account or group owns animations once the concept is chosen.
- Measure the runtime cost of 10-bone creatures with many on screen.
- A person should watch the loop and judge feel; no human has yet.
- Confirm the Codex setup on a machine that uses Codex.

## 12. Sources

- Roblox Creator docs: Importer (`studio/importer`), Blender and Maya export
  requirements (`art/modeling/export-requirements`), modeling specifications
  (`art/modeling/specifications`), `Bone`, `Animator`,
  `KeyframeSequenceProvider`, `EditableMesh`.
- MCP for Blender: github.com/ahujasid/mcp-for-blender, PyPI `mcp-for-blender`
  (2.1.9 on 2026-10-15), add-on v1.8.
- Mesh2Motion: mesh2motion.org, github.com/scottpetrovic/mesh2motion-app (MIT
  code), github.com/Mesh2Motion/mesh2motion-assets (CC0).
- Blender manual, FBX export and import.
- Decision note: `vault/decisions/0005-animation-pipeline.md`.
