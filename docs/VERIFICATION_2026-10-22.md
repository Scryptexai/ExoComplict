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
