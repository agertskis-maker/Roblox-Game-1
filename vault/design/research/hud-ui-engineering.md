---
title: HUD UI engineering - Roblox API facts for the prototype
tags: [research, hud, ui-engineering, car-hop, lane-3]
status: research
---

# HUD UI engineering: Roblox API facts for the prototype

This is role 3 research. Everything was checked on **2026-10-22** against the official creator-docs source (`github.com/Roblox/creator-docs`, `main`), which builds `create.roblox.com/docs`. I read it through Context7 `/roblox/creator-docs` and the raw reference YAML. The links go to the published pages.

This note approves nothing. Fonts, sizes, touch targets, scaling and reduced motion stay as recorded in `vault/design/visual-direction.md`. Nothing here was tested in Studio.

## Already in the repo (reuse these)

- **`src/shared/UI/Tokens.luau`**
  - Approved 2026-10-19:
    - Fredoka One through `Tokens.font()`.
    - Text sizes 36 / 24 / 18 / 16, plus Cash 40 and Distance 32.
    - Touch targets 48 / 56.
    - `uiScaleFor` (short side / 390, clamped 1.0 to 1.5).
    - Reduced motion follows the Roblox setting.
  - Pending review: `Color`, `Space`, `Radius`, `Stroke` 2/3/4, `Shadow`, and `Motion` (alarm cap 1.25 Hz).
  - Helpers: `heatColor`, `heatColorSequence`, `greyPalette`.
- **`src/shared/UI/Format.luau`**: Cash formatting. It truncates and uses K/M/B/T from $10,000.
- **`src/client/UI/`**
  - `OutlinedText`: gradient face, outline, shadow, one `setFade`, and the Fredoka glyph metrics.
  - `AlarmClock`: one shared `RenderStepped` connection, which runs only while something subscribes.
  - `IconGeometry`.
  - `CurrencyCounter` + `CashIcon`.
  - `RunHud` + `HeatGauge` + `FlagIcon`. These already use `ScreenInsets = CoreUISafeInsets` and one `UIScale` per widget root, and listen to `GetPropertyChangedSignal("ReducedMotionEnabled")`. HeatGauge already uses one `CanvasGroup`.
  - `Preview/RunHudPreview` (Studio only).

The prototype should extend these and add no second token module, frame loop or scaling path.

## Observations

**1. Safe area: CoreUISafeInsets, and never add the inset again.**
- Docs: [ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets), [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui), [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService).
- What the docs say:
  - `CoreUISafeInsets` = `DeviceSafeInsets` plus the core UI insets. The docs recommend it for "interactive and/or important UI elements".
  - `DeviceSafeInsets` adds no top-bar inset. `None` is for non-interactive backgrounds only. `TopbarSafeInsets` is the dynamic strip beside the Roblox controls, which matches `TopbarInset` (react to it through `GetPropertyChangedSignal`).
  - `IgnoreGuiInset = true` switches CoreUISafeInsets to DeviceSafeInsets.
  - `GetGuiInset()` takes effect only when `IgnoreGuiInset = false`.
- Apply: position from the `UDim2` edges plus a token gap. Never add `GetGuiInset()` or `TopbarInset` inside a CoreUISafeInsets ScreenGui, or the top bar gets counted twice. Full-bleed effects go in a separate ScreenGui set to `None`.
- Limits: **the docs give no top-bar pixel height** for phone or desktop. Read it at runtime and never hard-code it.

**2. SafeAreaCompatibility = None on new ScreenGuis.**
- Doc: [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui).
- What the docs say:
  - The default `FullscreenExtension` stretches the background of any descendant covering the safe area on both axes (strokes included); image and video content stretches too. The docs: "avoid fullscreen extensions for new work".
  - `ClipToDeviceSafeArea` defaults to `true`, and is ignored under `None` insets.
- Apply: set `SafeAreaCompatibility.None` on the HUD and on overlays, so a full-size scrim cannot stretch.
- Limits: RunHud does not set it yet. That is a small, reversible fix to confirm with the owner.

**3. UIStroke: never tween its thickness on text.**
- Docs: [UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke), [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers).
- What the docs say:
  - On text, a stroke outlines the glyphs. `ApplyStrokeMode = Border` moves it to the box, and one Contextual plus one Border stroke can coexist.
  - `LineJoinMode` is Round, Bevel or Miter.
  - Newer properties (`StrokeSizingMode.ScaledSize`, relative to font size on text; `BorderStrokePosition`; `BorderOffset`; `ZIndex`) "may require enabling the Improved UIStrokes beta". Sibling strokes with the same ZIndex draw in an undefined order.
  - Tweening `Thickness` on text "renders and stores many glyph sizes each frame", which causes performance cost and flicker.
- Apply: keep Round joins and animate size with a parent `UIScale`, as CurrencyCounter does. Give stacked strokes distinct ZIndex values.
- Limits: verify any beta property in a live client before relying on it.

**4. UIGradient: set it once, animate Offset or Rotation.**
- Doc: [UIGradient](https://create.roblox.com/docs/reference/engine/classes/UIGradient).
- What the docs say:
  - It works on Frame, Text/Image Label/Button, Path2D and ViewportFrame, but not on ScrollingFrame or TextBox, and it does not cascade to children.
  - `Type` is linear, radial, elliptical or conical.
  - The docs advise: 6 colour stops or fewer; no gradient on objects using `TextStrokeColor3`; do not rewrite `Color` or `Transparency` often (the sequence is rebuilt each time) and animate `Offset` or `Rotation` instead.
- Apply: the Heat sequence has 7 stops. It is built once, so keep it static and reveal it with the mask or `Offset`. Put `UIStroke`, never `TextStrokeColor3`, under gradient text.
- Limits: the docs give no cost per stop.

**5. Sizing.**
- Docs: [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers), [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel), [UIFlexItem](https://create.roblox.com/docs/reference/engine/classes/UIFlexItem).
- What the docs say:
  - UIScale scales the children "including … UIStroke or UICorner".
  - With AutomaticSize, `Size` becomes the minimum.
  - `TextScaled` ignores TextSize and forces wrapping. The docs: "avoid usage of TextScaled", use AutomaticSize instead, and never both together.
  - UIFlexItem overrides its UIListLayout's flex behaviour for one child.
- Apply: one UIScale per widget root, with no manual multiplying. Use fixed token sizes with AutomaticSize for labels and pills, and UIListLayout + UIFlexItem for button rows.

**6. CanvasGroup: small and static only.**
- Doc: [CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup).
- What the docs say:
  - It always clips its children.
  - It flattens only under `ZIndexBehavior.Sibling`.
  - It "consumes extra texture memory", capped by the client's `QualityLevel`. Beyond the cap it "will render as a blank texture".
  - It should keep a static size, because a resize makes a new texture.
- Apply: use it for small fixed masks such as the Heat fill. Never wrap the whole HUD or a full-screen panel just to fade it; fade per layer, `setFade`-style.
- Limits: no numeric cap is documented, and the cap depends on the device. Check at low quality on a real phone.

**7. ViewportFrame.**
- Docs: [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), [Viewport frames](https://create.roblox.com/docs/ui/viewport-frames), [WorldModel](https://create.roblox.com/docs/reference/engine/classes/WorldModel).
- What the docs say:
  - No shadows or post-processing. Neon and Glass render at the lowest quality, and nested GuiObjects are not supported.
  - Environment lighting acts as 0 unless a `Sky` child is present.
  - Lighting defaults: `Ambient` 200,200,200; `LightColor` 140,140,140; `LightDirection` (-1,-1,-1).
  - A WorldModel allows animation and raycasts, but parts are not simulated. Create it only while shown and delete it when unused.
- Apply: one ViewportFrame with its own Camera for a car portrait. Tune Ambient and LightDirection to the cream palette. Add a WorldModel only if the car animates, and destroy it through Trove.
- Limits: no safe ViewportFrame count is documented. Measure on the entry-level device.

**8. 9-slice.**
- Docs: [9-slice](https://create.roblox.com/docs/ui/9-slice), [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).
- What the docs say:
  - With `ScaleType.Slice`, `SliceCenter` splits the image: corners do not scale, edges scale along one axis, and the centre scales along both.
  - `SliceScale` (default 1) scales the edges as if the texture were upscaled.
- Apply: the HUD is built from frames today. If a textured panel is approved, use one sliced image and set `SliceScale` to the UIScale tier.
- Limits: image uploads need approval.

**9. Accessibility settings.**
- Docs: [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService), [Accessibility](https://create.roblox.com/docs/production/publishing/accessibility).
- What the docs say:
  - `ReducedMotionEnabled` maps to Reduce Motion. The suggested handling is tween time 0, or a fade instead of movement.
  - **No change signal is documented for it**, whereas `PreferredTextSize`, `PreferredTransparency`, `TopbarInset` and `ViewportDisplaySize` explicitly name `GetPropertyChangedSignal`.
  - `PreferredTextSize` is Medium, Large, Larger or Largest. TextScaled text ignores it, `UITextSizeConstraint` caps it, and AutomaticSize grows with it.
  - Multiply `BackgroundTransparency` by `PreferredTransparency`.
- Apply: confirm in a live client that RunHud's listener fires when the setting is toggled. Leave AutomaticSize room for larger text.
- Limits: supporting text size or transparency is propose-first under AGENTS.md.

**10. Prompts and input.**
- Docs: [ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt), [Proximity prompts](https://create.roblox.com/docs/ui/proximity-prompts), [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService), [PreferredInput](https://create.roblox.com/docs/reference/engine/enums/PreferredInput).
- What the docs say:
  - With `Style = Custom` the engine draws no UI. Build and tear down your own on `PromptShown` and `PromptHidden` (client side; PromptShown passes `inputType`), and drive the hold ring from `PromptButtonHoldBegan` and `PromptButtonHoldEnded` against `HoldDuration`.
  - A custom tap button calls `InputHoldBegin()` and `InputHoldEnd()`. `ClickablePrompt = false` still allows taps on mobile.
  - `KeyboardKeyCode` and `GamepadKeyCode` are separate properties.
  - `MaxIndicatorDistance` (default 0, off) shows a lightweight indicator beyond activation range.
  - `PreferredInput` (KeyboardAndMouse, Gamepad, Touch, MicroGamepad) is preferred over `GetLastInputType()` on mixed-input devices.
- Apply: choose glyphs from `PreferredInput`, make touch prompts 56 px primary buttons, and snap the hold ring under reduced motion.
- Limits: a change signal for `PreferredInput` is not explicit in the YAML. Verify it.

**11. Tweens and gamepad focus.**
- Docs: [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService), [TweenBase](https://create.roblox.com/docs/reference/engine/classes/TweenBase), [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService).
- What the docs say:
  - A second tween on the same property cancels the first.
  - `Cancel()` leaves the properties where they are. `Completed` fires on finish and on Cancel, passing a `PlaybackState`; `Pause()` does not fire it.
  - Tween on the client, not the server.
  - `SelectedObject` "may reset to nil if the object is off screen". `GuiService:Select(parent)` picks a visible, selectable descendant.
- Apply: keep tweens in Trove, cancel before replacing, and check `PlaybackState.Completed` before follow-up logic. On menu open, save the old `SelectedObject` and call `Select(menu)`. On close, restore it only if it is still visible.
- Limits: there is no built-in focus-return API.

**12. Fonts.**
- Docs: [Font](https://create.roblox.com/docs/reference/engine/datatypes/Font), [Enum.Font](https://create.roblox.com/docs/reference/engine/enums/Font).
- What the docs say:
  - `Font.fromName("FredokaOne")` maps to `rbxasset://fonts/families/FredokaOne.json`. `Font.new(family, weight, style)` defaults to Regular.
  - Listed families include Fredoka One, Builder Sans (the enum also has Medium, Bold and ExtraBold), Montserrat, Nunito and Luckiest Guy.
  - **Gotham and its variants "have been removed"** and map to Montserrat. There is no GothamSSm.
  - RichText supports `<stroke color thickness transparency joins>`.
- Apply: keep Fredoka One. If a readable second face is proposed, Builder Sans Bold or Nunito are candidates. Name Montserrat, never Gotham.
- Limits: the available weights appear **only in images**. Check `Enum.FontWeight.Heavy` in Studio; Fredoka One is likely a single weight. A second face needs owner approval.

**13. Audio, frame loops, billboards.**
- Docs: [SoundGroup](https://create.roblox.com/docs/reference/engine/classes/SoundGroup), [SoundService](https://create.roblox.com/docs/reference/engine/classes/SoundService), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve), [BillboardGui](https://create.roblox.com/docs/reference/engine/classes/BillboardGui).
- What the docs say:
  - SoundGroup `Volume` multiplies each sound's volume (0.5 × 0.5 = 0.25). A sound joins a group through `Sound.SoundGroup`, not by parenting. `PlayLocalSound` is heard only by the calling client.
  - Do not run expensive work on frame events without limiting how often it runs.
  - BillboardGui `MaxDistance` defaults to no limit. `AlwaysOnTop` gives ScreenGui colours and treats LightInfluence as 0.
- Apply:
  - Use a `UI` SoundGroup and `PlayLocalSound`. Volume is a session value only, with no save field.
  - Keep the one AlarmClock loop, write properties only when a value changes, and run nothing per frame while idle.
  - Give every BillboardGui a finite MaxDistance.

## Device emulator: what it proves

- Doc: [Device Simulator](https://create.roblox.com/docs/studio/device-simulator). It is a beta: turn on "New Device Simulator" under Beta Features.
- What it simulates: screen dimensions, pixel density, the on-screen keyboard, the reported platform, rotation, and Physical size mode (accurate only after calibration). It pairs with Controller Emulator. Phones are grouped Flagship, Mid-range and Entry level.
- What it proves: layout, anchoring, overflow, safe-area placement, touch-target size and the look of each UIScale tier.
- What it does not prove:
  - Phone CPU and GPU frame time, thermal throttling, the real CanvasGroup memory cap, or quality at a low QualityLevel. No hardware emulation is documented, and Studio renders on the PC's GPU.
  - Notch insets on custom profiles. Custom profiles have no inset field (only name, platform, dimensions, DPI and keyboard height).
- Label results "emulator only" until they are tested on at least one real entry-level phone.
