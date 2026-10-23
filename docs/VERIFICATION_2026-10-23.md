# Verification — 2026-10-23: opening replaced, robot cut, wordmark keyed, type scaled

Recorded against `arena/c08beb55-cyber-strike`. Every number below was produced
by a command in this document or by looking at a frame that is cited. Where
something has not been measured yet, it says so.

| Status | Means |
| --- | --- |
| **PASS** | measured, with the measurement here or in the doc it links to |
| **FAIL** | measured, and it was wrong |
| **NOT TESTED** | not measured — no engine, no device, no way to drive it |
| **BLOCKED** | cannot be measured in this environment at all |

---

## 1. The reference measurements the type scale was set from

The complaint was not "make it a bit bigger", it was that the components were
*illegible*. So the scale was set against frames, not against taste. Four
references were pulled and **looked at**, and measured in pixels on the frame
they arrived in; each is then re-based on 720 px of height, which is this
project's canvas (`project.godot` viewport 1280×720).

| Reference | Frame | Body text | Panel/heading | Primary CTA | Card |
| --- | --- | --- | --- | --- | --- |
| Call of Duty Mobile lobby | 1568×882 | ~22 px | 30–40 px | STORE 340×72 | mode cards 290×118 (18.5 % of width) |
| Apex Legends lobby | 1568×879 | ~26 px | tab 30 px | READY 296×70 | menu rows 296×45 |
| Free Fire (Garena) lobby | 1200×675 | ~15–17 px | START ~34 px | START ~13 % of height | weapon rack 300×340 (right edge) |
| Valorant main menu | 1568×882 | ~20 px | tab 30 px | — | left rail 320 px (20 % of width) |

The Apex frame is archived at `docs/asset-inspections/ui-references/apex-legends-lobby.jpg`
so the numbers can be re-checked; the other three were measured in this session
and their URLs are recorded in that directory's README.

Re-based on 720 px of height the references agree on a band: **body 18–26 px,
headings 30–40 px, one primary control 60–72 px tall, a rail or card set at
18–20 % of the width**. The shipped front end, measured from the same kind of
frame, was body 14 px, labels 11 px, headings 28 px, buttons 56–62 px.

What the references do that this front end did not, besides size:

* the primary action is the largest object on the screen and sits alone;
* body copy is set against a scrim at a weight that survives the art behind it;
* every list is edge-docked and full-height, never a floating box in the middle.

**PASS** — the measurements above are from the four frames; the numbers behind
the mapping are in `game/scripts/ui/aegis_tokens.gd` under `TYPE`.

---

## 2. The scale that shipped

`AegisTokens.TYPE` (logical units on the 1280×720 canvas):

| Role | Was | Now | Role | Was | Now |
| --- | --- | --- | --- | --- | --- |
| `display_xl` | 40 | **52** | `body` | 14 | **18** |
| `display_l` | 28 | **38** | `body_s` | 12 | **15** |
| `display_m` | *(missing)* | **30** | `caption` | 11 | **14** |
| `heading` | 18 | **24** | `label` | 11 | **15** |
| `heading_s` | 14 | **19** | `label_s` | 10 | **13** |
| `title` | 15 | **21** | `mono_m` | 13 | **17** |

`display_m` did not exist, and HERO and WEAPON both asked for it: their headings
were rendering at `body`'s size, which is why "SELECT OPERATIVE" sat at 14 px
under a 56 px BACK button in the pre-change frame. That is a one-line bug fixed
by adding the role, not by re-tuning the screens.

Also raised, in `AegisTokens`: `MIN_TOUCH_PX` 56 → **64**,
`MIN_PHYSICAL_FONT_PX` 13 → **16**, `TOUCH_GAP_PX` 12 → **14**. Components that
are authored in physical pixels were re-authored with them: cards 168 → 208 px
tall, landscape card width 340 → 400, hero/weapon chips 84–88 → 104–116,
rail width 300 → 360, safe margin 28 → 36, primary action 62 → 78 px,
dashboard plates 96×128 → 128×170.

The wordmark was 240–360 px wide depending on the screen; it is now 300 px in
portrait and 440–540 px on a desktop (`_size_both` in BOOT, LOADING
and DASHBOARD). It cannot be one large number: a 390 px wide phone with a 36 px
margin has 318 px to put it in, and a 540 px mark there hangs off both edges.

**NOT TESTED** until CI: `menu_layout_smoke` is the gate that proves no control
was pushed off a 390×844, 360×640, 844×390 or 1280×720 screen by these numbers.
It asserts in physical pixels that nothing outside a scroll container leaves the
viewport and that every button is still 63 px tall. The compact-arrangement
threshold in `stage_dashboard.gd` was moved from 700 to 900 px of height for
exactly this reason: at the new sizes the full portrait stack measures ~915 px
and a 390×844 phone cannot hold it.

---

## 3. The loading robot is gone

Deleted: `game/assets/ui/loading_robot.ogv`, `loading_robot_sheet.png`, the six
`generated/robot_walk_*.png` sources, the sprite-sheet job in
`tools/art/build_ui_art.py`, the video job in `tools/art/build_ui_video.py`, the
`ROBOT_*` constants and the `_robot` / `_robot_atlas` / `_robot_video` /
`_use_video_robot` block in `stage_loading.gd`, the sheet's entry in
`stage_boot.gd`'s `FRONT_END_ART`, and both manifest entries.

Why it was wrong, in the review's terms and in the frame's: it was a 160 px
sprite in the optical centre of a screen whose job is to state the product and
the progress, and it competed with the wordmark for the only focal point a
loading screen has. It was also the one asset on the screen that said nothing
about the game.

`tests/video_asset_smoke.gd` now asserts the absence rather than assuming it:
the loading stage must not have `_use_video_robot` and must not reference the
sheet. A test that only checks what exists cannot notice a deleted asset that
a stage still asks for.

**PASS** for the deletion (the files are in `git rm`, and
`grep -rn "loading_robot\|robot_walk" game/ tools/ tests/` returns the two
assertions above and nothing else). **NOT TESTED** for the look until the frames
in §6.

---

## 4. The wordmark has no plate behind it

The shipped `logo_wordmark.png` was **RGB, 1024×256**, with the generator's
backdrop painted in: sampling it, the most common colour was `(0, 1, 19)` —
a near-black navy field over 90 % of the source canvas. Against the menus' `#05080c`
void it read as a black box with a logo in it.

The build now keys it (`tools/art/build_ui_art.py::key_to_alpha`):

* the plate's luma is **measured** from the source's most common colour, not
  guessed: 1.3, against a glyph body at 50–220;
* every pixel's alpha is `(luma − plate − 2) / 16`, clamped — a ramp, not a
  threshold. A hard key at luma 24 was tried first and left the letters'
  shaded interiors transparent (their inner faces are 10–20 luma);
* the key is applied before the content crop, so the crop is measured on the
  art and not on the glow the key leaves behind.

Result: **RGBA 1024×256**, palette share unchanged within 0.4 %
(0.76 % off-palette), and the frame itself was checked composited over three
backgrounds — the menu void `#05080c`, a mid steel `#283440`, and a light
`#e6e6e6`. On all three the glyphs are solid, the glow is soft, and the
backdrop is absent. `tests/ui_art_smoke.gd` asserts the alpha channel exists and
that all three corners are transparent, so a build that lost the key fails the
suite instead of shipping the box again.

**PASS** — measured (`art_manifest.json: key_threshold {low: 2.0, span: 16.0}`,
`alpha: luma key…`, corners at alpha 0) and looked at.

---

## 5. The studio ident — corrected

`branding_studio_present.mp4` (768×768, 24 fps, 10.14 s, AAC audio) →
`studio_ident.ogv` (Theora q7, Vorbis q4, 768×768, 24 fps, 10.14 s, 1.77 MB,
audio present). The build asserts frame size, length and audio against the
source and fails if any of them moved.

### What this file is, and what the first attempt got wrong

It is a **studio's brand film**: a company ident, the beat a Garena or Moonton
card is. It is somebody else's mark. The first version of this work treated it
as *this game's opening cinematic*, and that misreading produced five concrete
mistakes, all now reversed:

| The wrong treatment | What it should be |
| --- | --- |
| A stage in the middle of the journey (`BOOT -> LOADING -> CINEMATIC -> CHAPTER`) | **first**, before the game's own wordmark: a publisher card opens the application |
| Gated on the profile and played once | played on **every launch**; it is not onboarding |
| Replayable from the dashboard (`REPLAY INTRO`) | not reachable from any menu; a studio mark is not content to rewatch |
| A composed fallback that played *this project's* key art under four captions when the film was absent | **nothing substituted**: log it and move on |
| A SKIP button in product chrome, plus a progress bar, a caption and the wordmark | **nothing of ours on the mark**; any input dismisses it, and dismissal draws nothing |

The stage is therefore `STUDIO` / `stage_studio_ident.gd`, the asset is
`studio_ident.ogv` (the delivered encoding, renamed — no re-encode, no crop, no
re-time, no re-score), and the fallback sequence, the captions, the progress bar
and the SKIP control are deleted rather than hidden.

### What the frames found before the correction

The first three captures showed the ident playing on top of the key-art plate,
with the scrim, the progress sliver and a caption still drawn — a state the code
says cannot exist. Two captures were spent guessing. What settled it was a
print, not a theory:

```
MenuCinematic: overlay video=true plate=true scrim=true caption=true
```

All four true at once means the helper had been *called with the wrong
argument*: `_show_ident_overlay(not _video.visible)` passes `false` while the
film is playing, and `false` is "hide nothing". One `not` inverted the decision.
The deeper problem was the design that produced the question: there should never
have been an overlay to hide.

### What is now asserted

* `video_asset_smoke.gd` — the engine measures 768×768 and 10.14 s against the
  manifest, playback advances, and **the ident scene holds no texture of ours,
  no button and no caption**.
* `front_end_journey_smoke.gd` — the journey starts at `STUDIO`; the ident has
  no button, no label and no texture; a tap advances it; `intro_seen` is now
  written when the CHAPTER 01 card is cleared, and the card — not the ident — is
  what a second launch skips.

Palette: 31.6 % of a sampled frame classifies as off-palette because the ident's
lime is hue 75–90 and this palette's windows are amber 15–70 and green 95–175.
Recorded in `video_manifest.json` as `palette_exemption`. The film is supplied;
no rule in this repo may re-grade it.

**PASS** for the artefact and for the stage's restraint, in the headless suite.
**NOT TESTED** until the frames below: the ident on a 1280×720 and a 390×844
screen, on the CI-built payload.

---

## 6. Frames

The browser QA photographs the real journey (`node tools/qa_flow_shots.mjs`). It
refuses to write a file unless the engine log says `FrontEnd: stage <name>`, so a
frame that looks wrong is the build being wrong, not the camera.

Final set, on the pushed head, after the payload bot refreshed `web/`:

| Set | Viewport | Stages |
| --- | --- | --- |
| `exports/flow/ui_final/` | 1280×720 | all eight |
| `exports/flow/ui_final_phone/` | 390×844 | DASHBOARD, HERO, WEAPON, WORLD |
| `exports/flow/ui_final_small/` | 360×640 | DASHBOARD, HERO, WEAPON |
| `exports/flow/ui_final_land/` | 844×390 | DASHBOARD, HERO, WEAPON |
| `exports/flow/ui_before/` | 1280×720 | the pre-change set |

Pre-change, at 1280×720, for the record:

| Stage | What the frame showed |
| --- | --- |
| BOOT | wordmark 360×90 with its navy plate visible, bar 240×6, status 11 px |
| LOADING | `LOADING` 28 px, `READY` 11 px, a 160 px robot, a 6 px bar |
| CINEMATIC | key art + `AEGIS TRAINING FACILITY` at 18 px, SKIP 160×56 |
| CHAPTER | card with `FIRST LIGHT` 28 px, body 12–14 px, CONTINUE 220×56 |
| DASHBOARD | operative block, theatre block, DEPLOY 62 px, stats 10 px |
| HERO / WEAPON / WORLD | headings 14 px, chips 84–88 px, cards 168 px, rails 300 px |

After, measured in the same tool at the same viewport:

| Stage | What the frame shows now |
| --- | --- |
| BOOT | wordmark 640×160 with no plate, status 21 px |
| LOADING | wordmark centred on black, `LOADING` 34 px, `READY` 21 px, a 6 px track across the full width, `100%` right-aligned. No robot: the asset is deleted, not hidden |
| STUDIO | the studio's mark, pillarboxed on black at 720×720, with nothing of ours on it |
| CHAPTER | `FIRST LIGHT` 38 px, body 18 px, CONTINUE 64 px |
| DASHBOARD | DEPLOY 78 px, stats 18 px in three columns, ARMORY/SETTINGS 64 px, a drawn card behind each block |
| HERO | `SELECT OPERATIVE` 30 px, 104 px chips, an 84 px information card with the operative's name as its heading, EQUIPPED + CONTINUE 64 px in one row |
| WEAPON | 200×130 plates, `PULSE RIFLE` 21 px, stats 17 px, CONTINUE 64 px |
| WORLD | 480×220 theatre cards with 2 px corners, `STATUS OPEN` 15 px, LAUNCH 64 px |

Three things only the frames could show, all fixed in this pass:

* HERO's information card was **not drawn at all**. `AegisPanel` was a bare
  `PanelContainer` with no `"panel"` stylebox, so the theme's default drew
  almost nothing and the type floated over the 3D scene. The widget now paints
  its own surface (and lets a stage shrink its inset on a small screen).
* The name and the roster caption were children of the **carousel**, so the card
  started under them and its top edge cut through "2 OPERATIVE SLOTS IN
  DEVELOPMENT". A `ScrollContainer` also defaults to `EXPAND_FILL` vertically,
  so the carousel ate the rail's spare height and pushed the card 90 px down
  with a hole above it.
* WEAPON's plates were 116×86 inside a 96 px carousel, so every caption under a
  plate was clipped out of existence and the plates looked cut off at the
  bottom. They are 200×130 with the carousel sized for plate plus caption.

---

## 7. The CI runs, and what each one caught

`menu_layout_smoke` runs the four stages at 844×390, 1280×720, 390×844 and
360×640 and asserts that every control is inside the viewport, that every
button clears the touch floor, and that a label stays inside its card. It found
six failures on the first push, then one per run for four runs. All of them were
real, and none of them were visible in a 1280×720 screenshot.

| Run | Failure | Cause, and what fixed it |
| --- | --- | --- |
| `39876344284` | WEAPON portrait: `@Label@158` at 409 px inside a 390 px screen | `clip_text` bounds the drawing but not the minimum size; the panel's 60-character brief set the column's width. Every one-line label became shrinkable (`_single_line`: autowrap + one ellipsis line) |
| `39877616958` | DASHBOARD landscape REPLAY INTRO at y=330+64 in 390; HERO EQUIPPED/CONTINUE at y=356+64; HERO `SLOT 02`/`SLOT 03` outside 64 px cards; WEAPON CONTINUE at y=342+64 | the safe-area top inset was always 28 px, and the compact chips were narrower than their own label. `apply_safe_margins` took an `extra_top`; the chips keep 84 px and the copy gives way instead |
| `39878859388` | HERO + DASHBOARD + WEAPON at 360×640, six assertions | the roster caption with autowrap off was the column's minimum width (334 px of a 336 px column), and two headers were 208/252 px wide beside BACK. Copy wraps, headings step down a role on a narrow screen, and the dashboard got a `cramped` pass |
| `39899366125` | WEAPON landscape CONTINUE at y=328+64; DASHBOARD small portrait DEPLOY, SETTINGS, REPLAY INTRO | the newly drawn card surface added its 12 px inset to every panel. `AegisPanel.set_surface_pad()` now lets a screen that measures a budget ask for 4–6 px |
| `39899689972` | DASHBOARD small portrait REPLAY INTRO at y=590+64 in 640 | the last 14 px came out of the two portrait plates (110 px and 84 px), which are the only blocks left in that stack that are picture rather than type |
| `364f32e` | **none** — `39899986254` and `39899981458` both success | — |

The lesson worth keeping: a containment test at four sizes caught six layout
regressions that four rounds of looking at 1280×720 screenshots had not.

**PASS** on the pushed head. CI is green on `364f32e` and its payload refresh.

## 8. What is still not true

* LOADING measures as BLANK in a whole-journey capture: it is a frame or two of
  a 10-second run, and the tool shoots it the moment it announces itself. Shot
  on its own it renders fully (`exports/flow/ui_final/loading-1280x720.png` is
  the pass-through frame; the earlier `ui_probe` capture is the in-flight one).
  This is a capture-timing fact, not a rendering bug.
* The ident has been captured mid-play (`MenuCinematic: stream at 2.00 s of
  10.14 s`) but nobody has watched it run end to end, and the capture is a
  still. What it does prove is the state: only SKIP is drawn over the film.
* The HUD shares `AegisTokens.TYPE`, so the combat HUD is now set at the same
  larger sizes. That was not re-photographed in this pass and is the likeliest
  place for a layout regression outside the menus.
* Layout is verified at four synthetic viewports; nothing here is measured on a
  real phone, where font hinting and the browser's own scaling are in the loop.
