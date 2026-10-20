# EXOCOMFLICT: Stellar Horizon — mobile UI/UX delivery report

**Date** 2026-10-20 · **Branch** `arena/e8e7ed65-cyber-strike` · **Base** `224ec13`
**Engine** Godot 4.7.2.stable (pinned, `.godot-version`) · **Suite** 24/24 tests pass

Every number below was measured. Nothing is inferred from an inspector, from a
scene that loaded, or from a green test suite. Where a thing could not be
measured it is marked **NOT TESTED** or **BLOCKED**, never PASS.

| Status | Means |
| --- | --- |
| **PASS** | measured, and the measurement is in this report or in a doc it links to |
| **FAIL** | measured, and the measurement is wrong |
| **NOT TESTED** | not measured — no device, no encoder, no way to drive the input |
| **BLOCKED** | cannot be measured or built in this environment at all |

---

## 1. Audit — what the project actually contained

66 files added, 11 modified against `224ec13`. The audit came first: nothing was
redesigned until BUG 1 and BUG 2 were understood (Gate 0), and no system was
rewritten without a technical reason.

| Area | As found | Now |
| --- | --- | --- |
| Entry point | `project.godot` ran `scenes/main.tscn` — straight into gameplay, no front end at all | a 10-stage front-end journey is the main scene; gameplay is reached through it |
| Combat HUD | exists: `hud_encounter_ui.gd`, `touch_controls.gd`, `hud_layout.gd`, `aegis_tokens.gd`, `hud_combat_feedback_ui.gd` | kept. Retuned in physical pixels; safe-area reserve added; no rewrite |
| Safe area | **no code consulted it anywhere** | `HudLayout.measure_safe_insets()` is one function used by the HUD *and* the menus |
| Progression | `progression_service.gd` existed (BP, best score, runs, weapon unlocks) | kept and extended with `intro_seen` + the last loadout; still the only owner of the profile |
| Avatar / weapon | `character_visual.gd`, `weapon_controller.gd`, a 79-bone rig | kept. One real defect fixed in the outline pass (§2) |
| Art | no pipeline; `assets/ui/` held no shipping key art | `tools/art/build_ui_art.py` + nine shipping textures (5.3 MB) |
| Tests | 19 smoke tests | 24 — five new: `front_end_journey_smoke`, `hero_visibility_smoke`, `hud_safe_margin_smoke`, `menu_layout_smoke`, `ui_art_smoke` |
| Audio | `procedural_sfx.gd`, 14 synthesised sounds | unchanged |

---

## 2. BUG 1 — "hero not rendered in gameplay while the weapon is visible"

**Verdict: NOT REPRODUCED on the current build.** Full evidence:
[`docs/asset-inspections/HERO_VISIBILITY_QA_2026-10-20.md`](asset-inspections/HERO_VISIBILITY_QA_2026-10-20.md).

This is deliberately not written as "fixed": nothing in the path that draws the
hero was broken, so nothing there was changed. The gate that used to block the
claim — the headless runner has no rasteriser — was opened by driving the
committed `web/` payload in a pinned headless Chromium and scoring motion across
frames.

### What was checked (all measured, `hero_visibility_smoke.gd`, 54 assertions, PASS)

| Check | Result |
| --- | --- |
| model instance in the tree, all ancestors visible | `CharacterModel` under `ModelPivot / VisualRoot / Player / Main` |
| layers vs camera cull mask | layer 1 AND 1048575 ≠ 0 |
| skeleton + skinning | 79 bones, `skin=true`, bones move while a clip plays |
| **posed** silhouette (Σ wᵢ · pose · inverse(rest) · v over 23 310 vertices) | **1.79 m tall, 0.66 m wide**, feet on the floor, determinant +5.64 |
| near plane / frustum / occlusion | nearest corner 6.60 m vs 0.08 m near; in frustum; raycast clear |
| on screen at 5 aspects | inside the frame, **21 % of screen height** at 1280×720, 390×844, 375×667, 844×390, 667×375 |
| surface winding vs normals | 0 % disagreeing (calibrated against a `BoxMesh`) |
| material | opaque, alpha 1.00, albedo `hero_HERO_3d_model_basecolor.jpg` loaded |
| weapon relationship | socket 88 mm from `R_Hand`, muzzle 0.42 m ahead of the grip, both in frustum |
| placeholder | capsule exists and is **hidden** |
| states | re-measured in idle / ADS / hip fire / reload / defeated: 1.79 m every time |

The naive silhouette sum (dropping the inverse rest transform) reports a 2.6 m
hero from a 1.78 m model — recorded so nobody measures it that way again.

### The one real defect found on the way — and fixed

| | |
| --- | --- |
| **Root cause** | `ModelFitter.apply_overlay_material()` was called with `VisualRoot` as its root. `VisualRoot` already contains `WeaponSocket/MuzzleFlash/*`, so the near-black grow outline that gives the avatar a readable silhouette was also applied to five additive VFX meshes. An opaque `CULL_FRONT` shell around a muzzle flash paints a dark blob over the shot. |
| **File** | `game/scripts/player/character_visual.gd` |
| **Fix** | outline the fitted model and the fallback capsule only; the weapon model is spawned afterwards and never carried the outline |
| **Re-measured** | hero mesh keeps the outline; the five flash meshes report `overlay=null` |

Scale was not changed, the model was not swapped and no new character was
created before the cause was established, per the brief.

### Known measurement discrepancy (not a defect)

The hand projection in §2 of the QA doc (34 % of frame height, from one
`?qa_camera` sample in a live browser run) and the runtime measurement (21 %,
same value at all five aspects) are two different camera instants — the headless
test's camera sits 6.60 m from the hero, the sampled browser camera ~4.8 m. Both
are inside the readable band (10 %–85 %) and neither changes the verdict, but the
two numbers are not comparable and have not been reconciled to one instant.

---

## 3. BUG 2 — touch controls crowded the right and bottom edges

**Status: FIXED, measured in a real WebGL browser build.** Full evidence:
[`docs/asset-inspections/TOUCH_SAFE_MARGIN_QA_2026-10-20.md`](asset-inspections/TOUCH_SAFE_MARGIN_QA_2026-10-20.md).

### Root cause

Two things stacked, and there was no single wrong line:

1. **Nothing consulted the display safe area.** Every bottom-docked control was
   anchored to the raw display rectangle. On a phone with gesture navigation the
   bottom ~28 px belongs to the system, which eats the touch before the game sees
   it.
2. **The authored margins were themselves tiny** — FIRE started 8 px from the
   right and 14 px from the bottom on a short phone, inside the thumb's natural
   overshoot even with no safe area reported.

### Fix and files

| File | Change |
| --- | --- |
| `scripts/ui/aegis_tokens.gd` | `SAFE_BOTTOM_PX = 28`, `SAFE_SIDE_PX = 8`, `SAFE_INSET_NOISE_PX = 4` |
| `scripts/ui/hud_layout.gd` | `resolve_safe_insets()` merges `get_display_safe_area()` with `get_display_cutouts()`, ignores sub-noise insets, floors each edge in touch mode; `_place_button()` / `_place_weapon_dock()` measure from the usable edge; weapon + magazine stack vertically; the joystick pocket keeps its whole 72 px capture circle clear of FIRE |
| `scripts/ui/widgets/hud_combat_feedback_ui.gd` | the status toast yields to real controls |
| `scripts/ui/touch_controls.gd`, `hud_encounter_ui.gd` | wire the reserve in, report it from `?qa_touch` |

Authored margins were **reduced** where the reserve now supplies the same
clearance (the weapon dock's 12 px became 4 px + the 8 px reserve), so the net
position on a display that reports nothing is unchanged.

### Measured — `?qa_touch=1`, 390×844, `SAFE=8,42,8,28`

| control | rect | bottom clearance | side clearance |
| --- | --- | --- | --- |
| FIRE | 162,574 202×202 | **68 px** | 26 px (right) |
| ADS | 240,438 124×124 | 282 px | 26 px (right) |
| EMP | 240,302 124×124 | 418 px | 26 px (right) |
| JOY | 14,666 144×144 | **34 px** | 14 px (left) |

Also measured at 375×667 and 844×390 (`hud_safe_margin_smoke.gd`, 246 assertions,
PASS). Every button stays 56 px or larger and remains in the thumb arc; nothing
was moved arbitrarily.

### Follow-on: the menus had the same class of bug

The same audit pass found the front-end screens overflowing on a phone. Fixed and
measured in [`docs/asset-inspections/MENU_LAYOUT_QA_2026-10-20.md`](asset-inspections/MENU_LAYOUT_QA_2026-10-20.md):

| Defect | Before | After |
| --- | --- | --- |
| HERO 390×844: three 240 px cards in a row grew the container to 752 px | every label on the screen **753 px** wide | labels 174 px, one card per row |
| WEAPON 390×844: card 132 px tall, four text lines | text ended ~100 px **past its own card** | card 216 px, all lines inside |
| WORLD 390×844: 240 px plate | blurb column **64 px**, wrapping to 64×284 | blurb 184×83 |
| DASHBOARD 844×390: a ~500 px column on a 390 px screen | `DEPLOY=36,444,772x60` — **54 px below the bottom** | `DEPLOY=427,278,381x60`, 52 px clear |

`menu_layout_smoke.gd` (new) mounts the real `front_end.tscn` in `SubViewport`s of
390×844, 844×390, 360×640 and 1280×720 — 16 stage/size combinations, all PASS.

---

## 4. The journey — BOOT → … → GAMEPLAY

```
BOOT ──> LOADING ──> CINEMATIC ──> CHAPTER ──> DASHBOARD ──> HERO ──> WEAPON
                         │                         ▲
                         └── (skipped once seen) ───┘
                                                   │
                       GAMEPLAY <── PRELOAD <── WORLD <──┘
```

`scenes/ui/front_end.tscn` is the project's main scene and the only object that
knows the order; a stage asks for the next one and `FrontEnd` decides whether
that is legal. `front_end_journey_smoke.gd` (85 assertions, PASS) walks the whole
path on the real scene, including:

* `intro_seen` round-trips through a real `ConfigFile`, so the cinematic plays
  once and REPLAY INTRO is the only way to see it again without wiping a profile;
* every enabled button does something — no enabled button is inert;
* absent content is disabled (2 hero slots, 2 world slots, 2 locked weapons);
* the loadout the front end saves **reaches gameplay**: the test saves
  `arc_shooter`, boots `main.tscn`, and asserts
  `Player.weapon_controller.get_current_definition().weapon_id == "arc_shooter"`.

### No fake data — the rules the code enforces

| Rule | How it is enforced |
| --- | --- |
| No invented stats | weapon numbers are read off the `WeaponDefinition` resource at runtime; the hero card carries **no** stats because there is no hero data model |
| No fake heroes / weapons / worlds | slots are `LOCKED` / `IN DEVELOPMENT` and `disabled`; ids are validated against `HERO_IDS` / `WEAPON_IDS` / `WORLD_IDS` |
| No fake loading | BOOT shows an **indeterminate sweep** because two `ConfigFile` reads report no fraction; LOADING and PRELOAD show a real percentage because `ResourceLoader` reports one |
| One source of truth | `ProgressionService` owns BP, best score, runs, unlocks and the loadout; the dashboard shows exactly those five things |
| No mock-up passed as implementation | every measurement in this report comes from the shipped scenes, not from a mock |

---

## 5. Asset inventory

Nine shipping textures produced by `tools/art/build_ui_art.py` from generator
output in `game/assets/ui/generated/`. Resolution and format are what the engine
reports at runtime (`ui_art_smoke.gd`, 48 assertions, PASS), not what a tool
claimed. **Tool:** images generated with the session's image generator, then
processed (content-box crop, union crop across animation frames, resize,
spritesheet, palette audit) by `tools/art/build_ui_art.py` using Pillow.

| Key | File | Res | Format | Off-palette | Integration |
| --- | --- | --- | --- | --- | --- |
| Asset B — wordmark | `game/assets/ui/logo_wordmark.png` | 1024×256 | PNG | 1.2 % | BOOT, CINEMATIC, CHAPTER, DASHBOARD |
| Asset A — loading key art | `game/assets/ui/loading_keyart.jpg` | 1920×1080 | JPEG q90 | 0.0 % | LOADING, PRELOAD, CINEMATIC |
| Asset D — dashboard art | `game/assets/ui/dashboard_bg.jpg` | 1920×1080 | JPEG q90 | 0.2 % | DASHBOARD, HERO, WEAPON |
| Asset E — hero portrait | `game/assets/ui/portrait_hero.png` | 768×1024 | PNG | 0.2 % | HERO card |
| World plate | `game/assets/ui/world_neon_frontier.jpg` | 1600×900 | JPEG q90 | 0.0 % | CHAPTER, WORLD card |
| Asset E — weapon plate | `game/assets/ui/weapon_pulse_rifle.png` | 768×512 | PNG | 0.0 % | WEAPON card |
| Asset E — weapon plate | `game/assets/ui/weapon_nova_launcher.png` | 768×512 | PNG | 1.3 % | WEAPON card |
| Asset E — weapon plate | `game/assets/ui/weapon_arc_shooter.png` | 768×512 | PNG | 0.1 % | WEAPON card |
| Asset C — loading robot | `game/assets/ui/loading_robot_sheet.png` | 2048×512 | PNG (4×512 px cells, 8 fps) | 0.0 % | LOADING, PRELOAD |

Total **5.3 MB** on disk. Every texture is loaded through
`MenuStage.try_texture()`, which returns `null` for a missing file, so a lost
plate is a visual regression rather than a boot failure. Palette audit: 9/9
within palette; the audit is HSV-only and says nothing about composition or
quality, and nobody has *looked* at these images — there is no image display in
this environment.

### Not delivered

| Asset | Status | Blocker |
| --- | --- | --- |
| Asset C as a **video** | **NOT DELIVERED** — a 4-frame sprite sheet ships instead | No video encoder: `ffmpeg` / `ffprobe` absent, Debian mirrors unreachable |
| Asset F — cinematic opening video | **BLOCKED** | Same. The opening cinematic is composed in-engine (a push-in on the key art under four captions, skippable from frame 1) and is integrated — but it is **not** a video, and no video file exists on disk |

Nothing in this report or in `docs/ART_DIRECTION.md` claims a video exists.

---

## 6. UI/UX changes

| Screen / system | Change |
| --- | --- |
| Combat HUD | sizes in physical pixels; safe-area reserve; weapon + magazine stacked; toast yields to controls; mirrored left-hand layout honours the reserve |
| BOOT | indeterminate bar; reads the real profile and preferences |
| LOADING / PRELOAD | real percentage from `ResourceLoader`; robot sprite sheet animates (8 fps, frame 0 held under `reduce_motion`) |
| CINEMATIC | in-engine push-in over the key art, four captions, skippable, plays once |
| CHAPTER | title card, advances on tap |
| DASHBOARD | five real numbers, four working actions, bottom-anchored DEPLOY, two-column in landscape |
| HERO | one selectable card + two disabled slots, no invented stats, portrait labelled as concept art |
| WEAPON | real stats off the resource, locked weapons priced and disabled, unlocking only in the Armory |
| WORLD | one real theatre, two disabled slots |
| Settings | `AegisSettingsMenu`, writes `user://aegis.cfg` |
| Typography | every font rendered at ≥ `MIN_PHYSICAL_FONT_PX` on the real screen |
| Palette | `docs/ART_DIRECTION.md`; 9/9 textures on palette |

---

## 7. QA table

`GODOT_BIN=/usr/local/bin/godot SKIP_VERSION_CHECK=1 ./scripts/run_smoke_tests.sh --no-import`
→ **24 passed, 0 failed** (`exports/test-logs/summary.txt`).

| Test | Assertions | Status | What it proves |
| --- | --- | --- | --- |
| `front_end_journey_smoke` | 85 | **PASS** | the whole journey, incl. the saved weapon reaching gameplay |
| `hero_visibility_smoke` | 54 | **PASS** | BUG 1: the hero is skinned, in frustum, unoccluded, on screen |
| `hud_safe_margin_smoke` | 246 | **PASS** | BUG 2: every docked control clears the reserved edge at 3 viewports |
| `menu_layout_smoke` | 16 | **PASS** | nothing outside the viewport, no button under 56 px, at 4 sizes |
| `ui_art_smoke` | 48 | **PASS** | all nine textures load in-engine at the documented size |
| `hero_rig_smoke`, `weapon_system_smoke`, `arc_weapon_smoke`, `wave_director_smoke`, `shooter_enemy_smoke`, `runner_standoff_smoke`, `enemy_visual_smoke`, `effects_smoke`, `combat_feedback_smoke`, `exploration_flow_smoke`, `progression_smoke`, `reward_loop_smoke`, `playability_hud_smoke`, `pause_gesture_smoke`, `hud_editor_smoke`, `ui_settings_smoke`, `neon_frontier_world_smoke`, `arena_blockout_smoke`, `audio_smoke` | (single summary line each) | **PASS** | no regression from this session's work |

Browser measurements (headless Chromium + SwiftShader WebGL 2, via
`tools/qa_avatar_shot.mjs`) back BUG 1, BUG 2 and the menu layout numbers above.

---

## 8. Remaining issues

| # | Issue | Status |
| --- | --- | --- |
| 1 | **Android / any real GPU.** No device, no JDK, no Android SDK, and the sandbox has no GL/EGL/Vulkan library. Every render claim goes through SwiftShader in headless Chromium. | **NOT TESTED** |
| 2 | **A full `web/` re-export could not be run here.** `engine/web_templates/*.zip` are 133-byte LFS pointers, so the export template cannot be unpacked. Verification uses `--export-pack` (no template needed) against the committed `index.wasm` / `index.js`. CI refreshes the committed `web/index.pck` on push, so the payload in the tree can lag this branch by one CI run. | **NOT TESTED** (full re-export) |
| 3 | **Rotation while a screen is open.** The layout probe mounts a fresh viewport per size and the browser build is fixed at one viewport per launch, so no run has driven `resized` from portrait to landscape on a live screen. | **NOT TESTED** |
| 4 | **Touch-drag scrolling** of the landscape card row. The rects prove the row is laid out and scrollable, not that a thumb moves it. | **NOT TESTED** |
| 5 | **Assets C and F as video.** No encoder exists in this environment. | **BLOCKED** |
| 6 | **Real device safe areas.** Insets come from `HudLayout`'s synthetic model (8/8/28 in touch mode); a real notch or gesture bar may report more. | **NOT TESTED** |
| 7 | **Frame rate, shader compilation on real drivers, thermals.** | **NOT TESTED** |
| 8 | The 34 % vs 21 % hero-height discrepancy (§2) — two camera instants, not reconciled. | open, not a defect |
| 9 | `ObjectDB` / `CanvasItem` RID leak warnings at exit in the menu tests (18 RIDs, 36 instances) — reported by Godot after `quit`, stages are freed by the harness. Not investigated. | open, cosmetic |
