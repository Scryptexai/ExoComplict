# Verification — 2026-10-22: phase 2 repaired, the browser QA made honest

Recorded against `arena/c08beb55-cyber-strike` at `91a871f` (payload refreshed by
CI after `fbe71c9`). Every number below was produced by a command in this
document. Nothing here is inferred from a green check.

| Status | Means |
| --- | --- |
| **PASS** | measured, with the measurement here or in the doc it links to |
| **FAIL** | measured, and it was wrong |
| **NOT TESTED** | not measured — no engine, no device, no way to drive it |
| **BLOCKED** | cannot be measured in this environment at all |

---

## 1. The previous commit shipped a world that could not load

`0884658` ("Finish phase 2") ended with a note that it had not been run against
the engine. It was run, by CI, and it failed: **23/26 smoke tests**, with
`arena_blockout_smoke` failing five assertions about a missing reactor, ramp,
deck and spawn beacon.

Root cause, one keyword:

```
SCRIPT ERROR: Parse Error: Cannot call non-static function
"build_central_arena()" on the class "NeonFrontierArena" directly.
Make an instance instead.
    at: GDScript::reload (res://scripts/worlds/neon_frontier_world.gd:43)
```

`zones/arena.gd` lost `static` on `build_central_arena`,
`add_arena_hazard_markings` and `add_arena_spawn_gates`. Godot refused to load
the world script, so nothing the composition root builds existed.

**Why no static check saw it.** `gdlint`, `gdformat`, `project_doctor` and
`module_map.py` all pass on that line: the call is legal syntax, the method
exists, and the file is referenced. The only thing wrong is the *static-ness*
of the callee, and that is declared in a different file. So the fix is one
keyword, and the durable fix is a check that reads both sides:

`tools/check_static_calls.py`, step 4 of `scripts/dev_check.sh`, with 10
self-tests whose first case is this exact regression.

**PASS**, measured by reverting the keywords in a copy of the tree:

```
scripts/worlds/neon_frontier_world.gd:43: Cannot call non-static function
    "build_central_arena()" on the class "NeonFrontierArena" directly
    call: NeonFrontierArena.build_central_arena()  declared in
          scripts/worlds/neon_frontier/zones/arena.gd
    fix:  make build_central_arena() `static` in .../zones/arena.gd
FAIL: 80 script(s) scanned, 1 static-call violation(s)   (exit 1)
```

---

## 2. CI, on the fix

Run `39690307014` on `638e505`, three jobs, all green:

| Job | Result |
| --- | --- |
| Static checks (gdtoolkit + project doctor) | **PASS** |
| Headless smoke tests, Godot 4.7.2.stable | **PASS — 26 passed, 0 failed (of 26, import ok)** |
| Web preview build + Chromium QA | **PASS — 4/4 page/viewport combinations** (`/` and `/web/index.html` at 1280x720 and 390x844) |

`arena_blockout_smoke`, the test that named the defect, passes again.

---

## 3. The browser QA was passing on the wrong scene, twice

Both defects are the §12.3 family in `docs/AUDIT_2026-10-21.md`: a check that
reports on *something rendering* rather than on the thing it claims.

### 3.1 `--play` without `--tour` never entered gameplay

`advanceToGameplay()` ran only for `--tour` and `--encounter`, so a play pass
clicked the centre of a menu stage and then failed "weapon shot played in the
browser" on a check that could not pass. Measured at 1280x720 and 390x844,
before the fix: `FAIL weapon shot played in the browser`, audio log
`first voice played (session_clear)` — the first voice of a session is a menu
sound, never a shot.

Two separate faults, both now closed:

* the journey is walked whenever a play pass is requested;
* `audio_director.gd` logs the first **weapon** voice separately
  (`Audio: first weapon voice played (shot_pulse_rifle)`), because the old
  check required the session's first voice to be a weapon voice. That check was
  reporting a failure while the magazine was visibly `24/24 → 23/24`.

### 3.2 `--tour` never engaged the review camera, and said it had

Measured on the first exported payload: eight tour frames, "8 distinct of 8",
reported as a pass — while the game was live. Two causes:

1. The play pass ran *after* the tour, and the rig pauses the simulation
   (`get_tree().paused = value`), so the play pass fired into a paused game and
   the report blamed the audio pipeline.
2. `page.keyboard.press('F10')` does nothing at all: **F10 is a reserved key and
   Chromium consumes it before the page sees it.** The frames differed because
   the player and enemies kept moving, not because the camera moved.

Fix: the tour runs last; `world_tour.gd` binds **P** alongside F10 (also the
right key on laptops where F10 is a volume key) and prints
`World tour: review camera engaged|released`; the harness clicks the canvas
first (a Godot window takes keyboard focus from a gesture) and asserts the
`engaged` line instead of trusting that eight PNG files exist.

---

## 4. Browser run after the fix

`node tools/web_qa.mjs --page /web/index.html --viewport 1280x720 --tour
--play 15` against the refreshed `web/` payload, **PASS (268.7 s)**, every
check below green:

```
ok   engine booted (console banner)          ok   world tour captured frames
ok   no Godot script/parse errors            ok   world tour frames differ (8 distinct of 8)
ok   no page errors                          ok   world tour engaged the review camera in gameplay
ok   no failed requests                      ok   scripted play captured frames
ok   no HTTP 4xx/5xx for page assets         ok   audio pipeline reported itself
ok   a canvas exists                         ok   weapon shot played in the browser
ok   canvas is not the 300x150 default       ok   the mute control reaches the audio pipeline
ok   canvas accepts pointer input            ok   front-end journey reached the gameplay scene
ok   WebGL context alive                     ok   no failure card shown
```

Audio, from the same console: `14 sounds synthesised in 357 ms`,
`first voice played (session_clear) 13947 ms after synthesis`,
`first weapon voice played (shot_pulse_rifle)`, `muted`, `unmuted`.

An earlier run of the same command, before the P binding existed, failed one
check and proved the point: `world tour captured frames` **ok**,
`world tour frames differ (8 distinct of 8)` **ok**, and
`world tour engaged the review camera in gameplay` **FAIL** — eight different
pictures of a live game that had never entered the review camera.

Payload check: `python3 tools/check_payload.py web/index.pck` → 720 files,
`0` test entries, `ok: nothing that should not ship is in the payload`.

Frames kept in `qa-evidence/world-tour-2026-10-22/`:

| File | What it is |
| --- | --- |
| `01-arena-vantage.png` | Vantage 1, the review camera's arena view, from the shipped payload |
| `02-boss-vantage.png` | Vantage 5, the arena and perimeter from above |
| `03-portrait-explore-fired.png` | 390x844, Explore, one round spent (`23/24`), touch HUD |

These are the first browser frames this project has of the *review camera*
rather than of live gameplay relabelled as a tour.

---

## 5. What looked wrong when the frames were actually read

Not defects yet — observations from looking at the images, recorded so the next
session does not have to rediscover them. No fix has been attempted.

* **Vantage 1 (arena) was framed through geometry.** *(Fixed, measured.)* At
  `(-27, 14, 27)` a pale perimeter slab crossed the bottom third of the frame
  and the hazard disc filled the centre. The vantage is now `(-44, 30, 44)` at
  55 deg FOV: the whole 42 m deck, its spawn structures, the reactor behind it
  and the neighbouring districts are in frame, and nothing occludes the deck.
  `qa-evidence/world-tour-2026-10-22/01-arena-vantage.png` is the frame after
  the change, exported by CI and captured from the shipped payload.
* **Two palettes are still in the tree.** `qa-evidence/scifi-bay/01-gameplay.png`
  and `qa-evidence/world-kit/01-arena.png` are the older pale-blue/cream build;
  the current payload is dark navy with orange accent bands and cyan emissives.
  Any review quoting the older frames as "the current look" is quoting history.
* **The arena floor reads as graph paper** from above: a full grid of identical
  tiles with a sparse orange centre disc and no lane markings that survive the
  camera height. Combat readability from the tour height is worse than from the
  player camera.

---

## 6. Bounds of this document

* **No local engine run.** `release-assets.githubusercontent.com` and
  `objects.githubusercontent.com` are blocked from this sandbox (SSL error on
  connect), so `install_godot.sh` cannot fetch the editor and there is no local
  copy. Engine verification is CI's, and the smoke-test numbers above are CI's
  numbers.
* **No local web export.** `engine/web_templates/*.zip` are 4 B pointers here,
  so `scripts/export_web_preview.sh` cannot unpack a template. The browser runs
  above use the payload CI exported from this branch and committed.
* **Software rendering.** SwiftShader, so frame rate and GPU-bound behaviour
  are not represented; a 268.7 s run is wall-clock under software WebGL, not a
  performance measurement.
* **No device.** Android touch, safe areas, thermals and frame rate remain
  **NOT TESTED**.

---

## 7. Verification of the redesign pass (checkpoints A–E)

Measured the same way as everything above: `./scripts/dev_check.sh`, CI's
headless suite, and `tools/qa_flow_shots.mjs` against the payload CI exported
from this branch. Frame statistics come from `tools/image_stats.py`.

### 7.1 The gate

| Check | Result |
| --- | --- |
| GDScript parse / gdlint / gdformat (80 files) | pass |
| Project doctor (13 groups) | 0 FAIL, 30 WARN |
| Static-call scan (80 scripts) | 0 violations |
| Layer and module boundaries | pass |
| Smoke tests, headless, Godot 4.7.2 | **27 / 27 pass** |
| Web preview build (WebAssembly) | pass |

Two of the 27 tests are new in this pass: `world_palette_smoke.gd` (the world's
palette is recomputed from `AegisTokens`, no wall is painted hazard amber) and
two new assertions inside `video_asset_smoke.gd` / `menu_layout_smoke.gd`
(the loading screen does not reuse the cinematic's key art; no card draws text
outside itself, and DEPLOY sits above the secondary row at four sizes).

### 7.2 What the frames say

| Frame | Before (mean / lit) | After | What changed |
| --- | --- | --- | --- |
| gameplay 390x844 | 69.6 / 0.967 | 39.7 / 0.667 | arena albedo from tokens: the deck went 0.58/0.65/0.70 → luma 0.122 |
| tour-2 390x844 | 66.4 / 0.998 | 39.7 / 0.667 | interior bays now read as structure, not white slabs |
| dashboard 390x844 | 45.8 (same frame as cinematic) | 36.2 / 0.838 | hero, theatre, DEPLOY first; numbers under it |
| loading 390x844 | **was a photograph of CINEMATIC** | 31.6 / — | its own composition: dark plate, wordmark, 100 %, READY |
| weapon 390x844 | 35.1 | 34.0 | every card line bounded to one line; nothing drawn outside a card |

The dashboard, hero, weapon and world frames were re-captured at both
viewports after the last change; each was reached, non-blank and measured
(`exports/flow/after-select/`, `after-loading/`, `after-world/`).

### 7.3 Defects this pass introduced and fixed

Recorded because the pattern matters more than the list: every one was caught
by a gate that already existed, and three of them were only *seen* in a frame.

1. Wall policy still painted every wall's "Orange" band hazard amber — the
   audit's defect with a narrower brush. Caught by `world_palette_smoke`.
2. The key light was made cool while the node is named `FrontierDaylightSun`
   and the test asserts a warm key over cool fill. Caught by
   `neon_frontier_world_smoke`.
3. Secondary actions were 52 px and 44 px against a 56 px touch floor, and the
   dashboard hard-coded the portrait path and a roster name. Caught by
   `menu_layout_smoke` and `data_source_smoke`.
4. The dashboard overflowed at 360x640 (754 px of content in 640 px) and then
   at 844x390. Caught by `menu_layout_smoke` at both sizes.
5. Each stat printed its caption twice, and the theatre brief was five lines of
   upper case. **No test could see this** — it fitted, and the strings were the
   ones the tests assert. Found in the screenshot.
6. Weapon cards drew their last line outside the card, and locked cards lost
   "unlock in the armory" to an ellipsis. Found in the screenshot, then guarded
   by the new containment assertion.
7. `_limit_lines` was called as `limit_lines`, and `Array[String]` was returned
   from an untyped literal: both are runtime/parse errors that gdlint, gdformat
   and the static-call scan cannot see. Caught by the smoke suite, twice.

### 7.4 Still not verified

* **No local engine.** The editor cannot be downloaded here; every GDScript
  result above is CI's.
* **No device.** Touch, safe areas, thermals and frame rate on Android are
  **NOT TESTED**; the safe margins are asserted headlessly, not felt.
* **No frame-rate claim.** SwiftShader is software rendering.

## 8. Verification of the 3D showcase pass (HERO and WEAPON)

The brief asked for the character and weapon selection screens to show the 3D
asset rather than key art, and for nothing on screen that the project cannot
back with data. Both screens were rebuilt; WORLD was deliberately left on 2D
plates (8.5.1).

### 8.1 The gate

| Check | Result |
| --- | --- |
| GDScript parse / gdlint / gdformat (81 files) | pass |
| Project doctor (13 groups) | 0 FAIL, 30 WARN |
| Static-call scan (81 scripts) | 0 violations |
| Layer and module boundaries | pass |
| Tooling self-tests | 35 pass |
| Smoke tests, headless, Godot 4.7.2 | **28 / 28 pass** |
| Module map in sync with the tree | pass |
| Web preview build (WebAssembly) | pass |

The 28th test is new: `showcase_smoke.gd`. It asserts, against the payload the
game actually ships, that

* every `HeroDefinition`/`WeaponDefinition` `model_scene` resolves to the same
  `res://` file gameplay instantiates (`player.tscn`'s `VisualRoot.model_scene`
  and `weapon_scene`);
* each model carries a `Skeleton3D` and an `AnimationPlayer`, and every clip a
  definition declares is present in the GLB;
* the live HERO stage mounts a sized `SubViewport` with its own `Camera3D`, at
  least two lights and a clip actually playing, and that driving that showcase
  does not change the avatar's clip or touch the avatar's `AnimationPlayer`;
* the live WEAPON stage shows the selected weapon's own mesh and reports zero
  clips for a mesh that has none.

It also prints how many weapon definitions resolve to how many distinct mesh
files. Today that is **3 definitions → 1 mesh**, which is why the weapon screen
says what it says (8.5.2).

### 8.2 What the frames say

Captured with `tools/qa_flow_shots.mjs --stages HERO,WEAPON,WORLD` against the
payload CI exported from `c66cab6`; statistics from `tools/image_stats.py`.
All six frames reached their stage, rendered, and are in
`exports/flow/showcase/`.

| Frame | Viewport | Mean | SD | Columns | Verdict |
| --- | --- | --- | --- | --- | --- |
| HERO | 390x844 | 32.4 | 50.8 | 1186 | render |
| WEAPON | 390x844 | 33.0 | 53.2 | 1107 | render |
| WORLD | 390x844 | 31.1 | 32.6 | 1459 | render |
| HERO | 1280x720 | 24.2 | 40.1 | 1023 | render |
| WEAPON | 1280x720 | 25.2 | 44.7 | 972 | render |
| WORLD | 1280x720 | 30.3 | 24.4 | 1694 | render |

Read as images rather than numbers, the two screens now do what the plates
could not: HERO shows `hero.glb` facing the camera with its 79-joint skeleton
and idle clip running, and WEAPON shows `rifle.glb` (12 176 tris) at a
three-quarter profile with its real statistics beside it.

### 8.3 Acceptance, item by item

| Requirement | Result | Evidence |
| --- | --- | --- |
| The hero shown is the model gameplay instantiates | **PASS** | `showcase_smoke` compares both `res://` paths; frame shows the operative |
| The weapon shown is the model gameplay instantiates | **PASS** | same test, `weapon_scene` vs `WeaponDefinition.model_scene` |
| The model animates on the selection screen | **PASS** (hero) / **N/A** (weapon) | hero cycles `idle`/`aim`/`fire`; `rifle.glb` has 0 clips, verified from the GLB and asserted by the test — it is shown still, and the widget is never left waiting for a clip |
| Menu animation cannot move the gameplay avatar | **PASS** | separate instantiation; test asserts distinct `AnimationPlayer`s and an unchanged avatar clip |
| No statistics the project does not model | **PASS** | hero shows no health/shield/skill block (nothing models them); weapon lines are parsed back out of the definitions in `data_source_smoke` |
| No fake roster | **PASS** | one operative; the two empty chips are disabled and the caption reads "2 OPERATIVE SLOTS IN DEVELOPMENT" |
| No fake weapon silhouettes | **PASS with a caveat** | 3 definitions share 1 mesh; the screen shows the selected weapon's mesh and never claims three images |
| Locked content is disabled, not merely labelled | **PASS** | `front_end_journey_smoke` counts disabled buttons on all three stages |
| No upgrade button | **PASS** | there is no upgrade system; the screen has CONTINUE only |
| Landscape and portrait both usable | **PASS at 390x844 and 1280x720**; phone landscape 844x390 also captured and read | `_apply_orientation()` reconciles both arrangements |
| Touch targets keep the 56 px floor | **PASS** | `physical_min_size` on every button; `menu_layout_smoke` |
| WORLD shows a chapter/objective line | **PASS** | one constant per theatre, drawn from copy the world scene owns, not a second copy of the wave plan |

### 8.4 Defects this pass introduced and fixed

Recorded because the pattern repeated: three of these compiled, linted and
passed every static gate, and were only found by CI's smoke run or by looking at
a frame.

1. `Camera3D.KEEP_ASPECT_HEIGHT` does not exist (it is `KEEP_HEIGHT`). gdtoolkit
   parsed it; the engine did not, which failed four smoke tests at once.
2. `String.to_capitalized()` does not exist either (it is `capitalize()`), with
   the same symptom: a parse error that took the whole HERO stage down.
3. `_apply_orientation()` returned early when the orientation had not changed,
   so on a portrait-first boot nothing it parented was ever parented and the
   density pass never ran: the weapon panel sat in a column beside the model and
   the hero heading stayed at its build-time text.
4. The hero faced away from the camera: the rig's forward is +Z, so the yaw that
   `ModelFitter` defaults to for the outward-facing kit models showed its back.
5. The rifle rendered as a 20 px sliver at every yaw. Two causes: the model's
   long axis is Z, so a near-frontal angle foreshortened it, and the camera
   distance was solved while the container was still 2 x 2 px. Framing is now
   measured from the model that is on the pivot against the rendered viewport's
   own aspect (`frame_to_fill`), and re-solved whenever that viewport changes.
6. A locked hero chip 68 px square cannot hold "IN DEVELOPMENT" without drawing
   outside itself; the chip keeps a slot number and the status moved to a
   caption under the carousel.
7. An action row built but never parented: it only existed inside a function
   that the early return skipped. Found in a frame, not by a test.
8. `var clips := showcase.clip_names()` cannot infer from an untyped `Array`.

### 8.5 Deliberate scope decisions

**8.5.1 WORLD stays 2D.** There is one arena. A 3D showcase would show the same
mesh four times behind four different captions — the exact "three silhouettes"
problem the weapon screen avoids — so the theatre keeps its artwork and gained
the chapter line instead.

**8.5.2 Three weapons, one mesh.** The definitions are honest about it in the
code comment and the test prints the ratio, but no screen can invent three
models. When the other meshes land, the screen needs no change: it reads
`model_scene`.

**8.5.3 No stat block for the hero.** `HeroDefinition` carries name, role, status
and model; nothing in the game models health, shields, mobility or skills. A
stat panel would have to be invented, so there is none, and the panel says what
the definition does say.

**8.5.4 Showcase fill is calibrated, not derived.** `frame_to_fill` solves for
the distance analytically, but on the web build the box composites its 3D
texture at a smaller effective scale than the projection reports. Both screens'
`SHOWCASE_FILL` values were read off captured frames at 390x844, 844x390 and
1280x720. Recorded here as a calibration, not as a law.

### 8.6 Still not verified

* **No local engine.** No editor can be downloaded here; every GDScript result
  above is CI's or the exported payload's.
* **No device.** Touch, safe areas, thermals and frame rate on Android are
  **NOT TESTED**. The carousel's thumb-drag is asserted headlessly
  (`menu_layout_smoke` measures scroll travel), not felt.
* **No frame-rate claim.** SwiftShader is software rendering; a showcase
  `SubViewport` adds a second 3D view to a menu that had none, and its cost on
  real hardware is unmeasured.
* **No audio or haptics check** for the new screen.

## 9. Verification of the lighting and character-legibility pass

Two reports: the game is too dark and that darkness follows the hero, and the
hero has a black line along every edge. Both were real. Measurements below are
from the frames in `exports/flow/{dark,light,light3,ab,final}/`, using the same
`tools/qa_flow_shots.mjs` payload CI exports from this branch.

### 9.1 What the numbers were

| Region | Before | After |
| --- | --- | --- |
| gameplay hero, 1280x720 (mean / p10 / p50) | 46.7 / **0.0** / 11.0 | 106.6 / 2.7 / 69.3 |
| gameplay whole frame | 23.2 / 0.0 / 7.6 | 41.7 / 0.3 / 26.4 |
| gameplay deck strip, 1280x720 | 18.6 / 0.1 / 9.2 | 44.4 / 10.3 / 31.8 |
| gameplay 390x844, frame mean | 39.7 | 53.5 |

A tenth-percentile of **0.0** on the avatar is the diagnosis: not "dark", but a
large part of the silhouette clamped to black, which is where the missing panel
detail went.

### 9.2 What actually fixed it

1. **The world was lit for a palette it no longer has.** The key was capped
   below 1.0 back when the albedo was pale; after the palette was darkened, the
   frame rested on an ambient fill of about 0.16 effective with contrast 1.09
   crushing what was left. Key 0.9 → 1.05 (the smoke test's ceiling is 1.1),
   ambient colour and energy up, exposure 1.01 → 1.18, contrast 1.09 → 1.04,
   fog 0.019 → 0.014.
2. **The avatar has its own fill light.** One unshadowed omni, range 2.6 m,
   carried by `VisualRoot`. It moves the operative's median luma 39 → 70 while
   the frame's median moves 25.4 → 26.4, which is the evidence that it is local
   rather than another scene-wide lift. `hero_visibility_smoke` now asserts it
   exists, casts no shadow, and stays within 3 m.
3. **The silhouette rim was heavy.** A near-black shell grown 0.012 from every
   surface is a black band around each limb at this model's scale, and on a
   390 px phone it closed up into a dark blob. Now a narrow navy edge.

### 9.3 A wrong diagnosis, corrected

The first attempt claimed `hero.glb` and `rifle.glb` ship no
`pbrMetallicRoughness` block and are therefore metallic 1.0 by glTF default with
no diffuse response. **That was false.** Both files carry three textures each,
including a real metallicRoughness map; sampling it gives metallic ≈0.25 and
roughness ≈0.26. Reading `metallicFactor: None` off the JSON and stopping there
is what produced the error.

Rather than ship a plausible explanation, both versions were built and captured
with the fill light on:

| Build | Hero mean | Hero p50 |
| --- | --- | --- |
| material tweak off | 106.5 | 69.3 |
| material tweak on | 109.6 | 71.3 |

Three luma points is noise, so `ModelFitter.fix_metallic_default()` and its
three call sites were removed, and the comment at the outline records the
measurement instead of the mechanism that does not apply.

### 9.4 What is still only partly fixed

* **The rim is still visible on the dark deck.** In the final 1280x720 frame the
  navy line reads against the operative's white plates, most on the legs and
  under the arms. It is much less than before. Removing it entirely would be a
  different decision — the overlay exists so the avatar separates from a busy
  floor — and that is the user's call, not a bug fix.
* **The torso is still the darkest part of the operative.** Its albedo is dark
  navy and the metal is rough; a fill light reveals the form but cannot
  brighten a surface the texture paints dark. That is art, not exposure.
* **The gameplay frame is still a night scene.** Mean 41.7 of 255. If it should
  read as daylight, that is an art-direction change to the sky and fog, not a
  correction — so it was not made here.

## 10. WORLD 02 — Vanguard Station, Dock 07

### 10.1 What this section replaces

An earlier pass on this branch composed a Vanguard district **on top of** Neon
Frontier: a gate at z +74, a wall line at z +62, a yard, conduit runs and a
spire, all built from procedural GDScript boxes. It was captured, and the
captures showed three things the tests had not: the district was laid out across
the existing perimeter props, its gate faced away from the player, and its
surfaces had no detail beyond what a box can carry. `a671efd` removes it. Neon
Frontier is byte-identical to its state before that pass.

The world in this section is a **separate theatre**, built from the imported kit.

### 10.2 The assets, and why this is not procedural geometry

`3DScifiStarterKitFree.zip` is a 259 MB Git LFS object that this sandbox cannot
download, but its converted output is already committed: **125 GLB modules** in
`game/assets/world/scifi_starter_kit/models`, produced by
`tools/convert_fbx_pack.py` on a CI runner. They are the room kit: 6 x 6 m deck
plates, 2 x 4 x 6 m wall modules, door frames, roof plates, consoles, pipe runs,
light strips, signs, word decals, portholes, stairs and catwalks.

Every visible piece of this world is one of those modules. Where the world needs
a wall it is a wall module; where it needs a landmark it is the pack's turbine
face between two of its own fin columns; the dock number over the doorway is two
of the pack's numeral modules. There is **no procedural stand-in geometry in
World 02**.

Sizes and origins are measured, not estimated. `tools/kit_measure.py` reads each
GLB's POSITION accessors and writes `measurements.json`; the composer centres a
module on that footprint and builds its collider from the same box. This matters
because the pack authors most modules off-origin: `Wall_Console_01_Half` starts
1.76 m to its own left and 0.74 m up, `Fence_Long_01` starts 2.5 m to its right.
`tools/kit_measure.py --check` fails if the JSON and the models disagree, and it
runs in `dev_check.sh`.

### 10.3 The facility

| Room | Extent | What is in it |
| --- | --- | --- |
| Hangar | 36 x 36 m, x -19..19, z -19..19 | deck plates, four wall runs with four door frames, two catwalks with rails and stepped landings, cover crates, console bank, bench, roof ring open above the middle |
| Reactor hall | 24 x 18 m, z -37..-19 | turbine face between fin columns, pipe rises and floor runs, two console banks, work bench, sign and warning decal, roofed with a skylight |
| Cargo bay | 18 x 12 m, x -37..-19 | crate stacks two high, pipe run, manifest console, caution sign and zone decal |
| Corridor | 24 x 6 m, x 19..43 | ceiling light runs, ribs, intercom, console, exit decal, one porthole wall in place of plating |

The hangar is the size it is because the wave spawn markers in `main.tscn` sit at
+-11 and +-12 m: a smaller room would spawn waves inside its walls.

### 10.4 Status, in the brief's vocabulary

| Claim | Status | Basis |
| --- | --- | --- |
| Two worlds exist, separately | **VERIFIED** | `main.tscn` instances both; each builds only when its id is selected; `Neon Frontier does not build while Vanguard Station is selected` is asserted |
| Every visible piece is an imported kit module | **VERIFIED** | every node carries `uploaded_fbx_visual`, asserted per node |
| Modules are placed by measured footprints | **VERIFIED** | `tools/kit_measure.py --check` runs in the static group; sizes come from the JSON |
| The facility is walkable end to end | **VERIFIED** | capsule sweeps along four legs (spawn->gate, hangar->reactor, hangar->cargo, hangar->corridor), plus a deck ray at the spawn |
| All four rooms contain their furniture | **VERIFIED** | per-room module counts and named-node assertions (cover crates, gate, numerals) |
| The card, the launcher and the scene agree | **VERIFIED** | `data_source_smoke` checks every definition's scene is instanceable inside `main.tscn` |
| It reads as a sci-fi facility | **LIKELY** | captured at 1280x720 against `7fe2f88`; see 10.6 for what is still thin |
| Performance on device | **UNKNOWN** | SwiftShader only; no hardware measurement |
| Mobile renderer parity | **UNKNOWN** | web build is Compatibility; not exercised on Android |

### 10.5 Defects this pass introduced, and what caught each

Nine of the eleven were invisible to `gdlint`, `gdformat` and `dev_check` — they
are Godot parse errors or runtime behaviour, and the headless smoke job is the
only thing in this repo that runs a parser:

1. **`const` table of `Vector3` arrays** — the library failed to compile; every
   world test fell over behind it. Replaced with measured JSON.
2. **A duplicate `static var`** left by an edit — same symptom, different cause.
3. **`Engine.get_singleton("ProgressionService")`** — returns null for an
   autoload-style node, and both worlds defaulted to "build it", so the station's
   walls landed through the frontier's gate.
4. **`self` inside a static function** — parse error.
5. **`ProgressionService` readied after the worlds** — siblings ready in order,
   so the worlds built with the default selection while the profile said
   otherwise. The launcher loaded the wrong theatre.
6. **A door frame given one solid collider** — every doorway in the facility was
   sealed by the thing that was meant to open it.
7. **Door frames turned 90 degrees in walls that run along X** — the gate and the
   reactor door sealed themselves and faced the wrong way.
8. **`Roof_Glass_01_6x6` used as a roof plate** — it is a 6 m vertical pane, so
   it hung a cyan slab through the reactor hall.
9. **Word decals placed at numeric scales** — `Word_Zone` is 21.9 m long; at 0.62
   it was a 14 m flat panel. Signs are now sized to a width in metres.
10. **The spawn apron dressed on the wrong side** — everything added for "the
    first frame" was behind the player, who faces the reactor door.
11. **The theatre had no Environment at all** — it was lit by the engine's
    default sky, which the roof ring then blocked from everything but the
    skylight. That is the whole explanation for a room that photographed as flat
    grey however many omnis were hung in it: there was no key light and no fill.
    It owns a sky, a sun and an ambient now, and the first attempt at that
    overshot into a white deck before the key came down.
12. **An edit deleted the hangar apron wholesale** — removing the amber plate
    under the player's feet took the whole function with it, so two commits moved
    furniture inside a function that no longer existed and the captures agreed,
    because there was nothing left to move. The smoke test's crate assertion
    caught it before the next capture did.
13. **`?qa_world=` dropped on the gameplay URL** — a capture run reported the
    station and photographed the frontier, and the numbers agreed with it.

### 10.6 The second pass: what the captures found that the tests could not

Every defect below was found by looking at a rendered frame, and each one is a
placement or asset-truth error that `gdlint`, `gdformat`, `dev_check.sh` and even
the headless smoke suite all called clean:

* **No Environment.** The theatre had no sky, sun or ambient of its own and was
  lit by the engine default, which the roof ring then blocked. Everything else
  here was tuned against a broken exposure for several passes.
* **The pack's artwork was painted over.** `Sign_Caution_01`, the word decals and
  the numerals ship with a base-colour texture; the palette overrode every surface
  with a flat colour, so every sign was a blank coloured rectangle. Textured
  surfaces on artwork modules are now left alone, and the smoke test asserts one.
* **Decals were rotated onto the wrong axis.** These modules are zero-thickness
  planes with their normal on +-X, so a sign on an X-running wall needs yaw 90,
  not 0. Nearly every sign stood out of its wall or faced backwards.
* **`floor_tech` is not a floor.** `Floor_Pipes_01` is a 0.47 m raised pipe run;
  used as a deck channel it laid loose pipes down the hall and across the walkway.
* **Corridor ribs were walls in the walkway.** Four 4.4 m beams on the centre
  line, with no colliders, so the route sweep walked through them.
* **The turbine was inside the back wall.** The wall's inner face is near
  z = -34.8 and every reactor part was placed at -36.
* **The omnis were two stops too hot.** 9.0 energy two metres above the catwalk
  decks clipped steel to white, which is what made the walkways read as floating
  cyan slabs.
* **Two tour vantages photographed the wrong thing** — the corridor's from behind
  a wall's width of doorway, the catwalk's from above the roof plates.
* **An edit deleted a function wholesale** and two commits then rearranged its
  contents; the crate assertion in the smoke test caught it.

### 10.7 What is honestly still weak

* **The kit is a corridor kit, and the hangar is 36 m.** At that span the wall
  modules read as flat grey planes; the detail that makes the pack sing at 6 m
  spacing is lost. The next pass should either shrink the arena or break the long
  walls with buttresses, plant rooms and mezzanines.
* **No props from the Kenney space kit** are used. The ten low-poly craft, turrets
  and hangar shells are committed and unused; mixing them with the starter kit's
  detail level would need a deliberate art decision, not a drop-in.
* **The two catwalks step rather than ramp**, because the pack's stair module is
  authored around its own origin and reads wrong when turned. Functional, not
  elegant.
* **No LOD, no occlusion, no instancing.** Module counts are ~250 per room; the
  next pass should instance the repeated deck and wall modules and measure.
* **Nothing is verified on a device or on the mobile renderer.**
* **The card plate is a crop of a review frame**, not commissioned key art.
* **The reactor hall is the weakest room.** Three gear faces at 1.15 scale now
  span 16 m of its back wall and read as a bank rather than a machine; the room
  wants a plinth, a rail and an operator deck under it, which is the next pass.
* **The kit exposes no inventory or turret modules**, so a hangar full of the ten
  Kenney craft still needs an art decision about mixing two different detail
  levels, not a drop-in.
