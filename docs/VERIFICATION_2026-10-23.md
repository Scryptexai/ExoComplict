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
portrait and 440–540 px on a desktop (`_size_both` in BOOT, LOADING, CINEMATIC
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

## 5. The opening is the committed film

`branding_studio_present.mp4` (768×768, 24 fps, 10.14 s, AAC audio) →
`cinematic_opening.ogv` (Theora q7, Vorbis q4, 768×768, 24 fps, 10.14 s, 1.77 MB,
audio present). The build asserts frame size, length and audio against the
source and fails if any of them moved.

The stage changed in three ways:

1. **Contain, not cover.** `_layout_video` scaled by `max(size/frame)`; a square
   film on a 16:9 stage therefore rendered 1280×1280 and lost 280 px off the top
   and bottom of the mark. It now scales by `min` and centres: 720×720 on the
   canvas, black either side.
2. **Black stage, no poster.** The key-art plate and the scrim are hidden while
   the ident plays, so the film is not framed by a rectangle of game art.
3. **Nothing on top.** No captions, no wordmark, no progress bar — SKIP only,
   bottom centre, from the first frame.

The composed fallback (push-in on the key art, four captions) is untouched and
runs when the video is missing or stalled; it is the path that carries the
product's premise, and it is still UI text rather than baked pixels.

Palette: 31.6 % of a sampled frame classifies as off-palette because the ident's
lime is hue 75–90 and this palette's windows are amber 15–70 and green 95–175.
Recorded in `video_manifest.json` as `palette_exemption` with that reason. The
film is a supplied brand asset; no rule in this repo may re-grade it.

**PASS** for the artefact (manifest carries source, size, duration, audio and
the exemption). **NOT TESTED** for playback in the browser until the frame in §6
and the CI `video_asset_smoke` run.

---

## 6. Frames

The browser QA photographs the real journey at both viewports
(`node tools/qa_flow_shots.mjs`). The pre-change set is
`exports/flow/ui_before/`; the post-change set is `exports/flow/ui_after/` and
must be regenerated after CI refreshes the committed payload — a local run
before that would photograph the previous build, which is the mistake this tool
exists to prevent (it checks for `FrontEnd: stage <name>` in the engine log
before it writes a file).

Pre-change, at 1280×720, for the record:

| Stage | What the frame showed |
| --- | --- |
| BOOT | wordmark 360×90 with its navy plate visible, bar 240×6, status 11 px |
| LOADING | `LOADING` 28 px, `READY` 11 px, a 160 px robot, a 6 px bar |
| CINEMATIC | key art + `AEGIS TRAINING FACILITY` at 18 px, SKIP 160×56 |
| CHAPTER | card with `FIRST LIGHT` 28 px, body 12–14 px, CONTINUE 220×56 |
| DASHBOARD | operative block, theatre block, DEPLOY 62 px, stats 10 px |
| HERO / WEAPON / WORLD | headings 14 px, chips 84–88 px, cards 168 px, rails 300 px |

**NOT TESTED** until the post-change capture: the after table, with the same
stage list, is the acceptance evidence for §2 and §4.

---

## 7. What is still not true

* CI has not run on this change at the time of writing. `menu_layout_smoke`
  (physical-pixel fit), `video_asset_smoke` (the new manifest, the deleted
  robot) and `ui_art_smoke` (the alpha assertions) are the three that can fail,
  and two of them are new assertions that have never been executed.
* No one has watched the ident play in a browser yet. The stage logs
  `MenuCinematic: playing the encoded opening` and the capture in §6 is a still.
* The HUD shares `AegisTokens.TYPE`, so the combat HUD is now set at the same
  larger sizes. That was not re-photographed in this pass and is the likeliest
  place for a layout regression outside the menus.
* Layout is verified at four synthetic viewports; nothing here is measured on a
  real phone, where font hinting and the browser's own scaling are in the loop.
