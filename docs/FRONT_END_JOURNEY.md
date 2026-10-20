# Front-end journey

status: implemented, pending the first full test run. This file describes what
is in the tree and what each stage actually does; where a claim could not be
verified it says so.

Before this work the game booted straight into `scenes/main.tscn`. The journey
below did not exist at any point — no boot screen, no loading screen, no
dashboard, no selection screens — so every stage here is new code rather than a
re-skin.

```
BOOT ──> LOADING ──> CINEMATIC ──> CHAPTER ──> DASHBOARD ──> HERO ──> WEAPON
                         │                         ▲
                         └── (skipped once seen) ───┘
                                                   │
                       GAMEPLAY <── PRELOAD <── WORLD <──┘
```

`scenes/ui/front_end.tscn` is the project's main scene and the only object that
knows the order. A stage finishes by emitting `completed(next_stage, payload)`;
`FrontEnd` decides whether that request is legal and instantiates the target.
Stages are created once and shown/hidden, never freed.

---

## BOOT — `stage_boot.gd`

| | |
| --- | --- |
| Real work | `ProgressionService.load_profile()`, `AegisPreferences.read()` |
| Progress shown | **indeterminate sweep** |
| Advances | automatically, after the work and a 1.2 s minimum hold |

Two `ConfigFile` reads report no fraction — `ConfigFile.load` either returns OK
or it does not — so the bar states no percentage. The 1.2 s hold is a brand
beat for the wordmark, not a loading claim, and the caption reads
`READING PROFILE` rather than implying a quantity.

## LOADING / PRELOAD — `stage_loading.gd`

| | |
| --- | --- |
| Real work | `ResourceLoader.load_threaded_request` over a queue of resource paths |
| Progress shown | **real percentage**, `(completed + current fraction) / total` |
| Advances | when the queue drains |

One implementation serves both stages; the payload decides. `LOADING` fetches
the nine front-end textures and goes to `CINEMATIC`. `PRELOAD` fetches
`res://scenes/main.tscn` and changes scene.

If the queue is empty the stage does not animate a number: it swaps the bar for
the sweep and the caption reads `PREPARING`. A resource that fails to load
raises `push_error` and is recorded, so the failure is visible in the log rather
than hidden behind a completed bar.

The robot walk cycle is played from `loading_robot_sheet.png` (2048×512, four
512 px cells, 8 fps) by moving an `AtlasTexture` region — one import, one draw
call. `reduce_motion` holds frame 0 instead of animating.

## CINEMATIC — `stage_cinematic.gd`

| | |
| --- | --- |
| Real work | a scripted 9.6 s sequence over the loading key art |
| Progress shown | **real playback position** (elapsed / duration) |
| Advances | on completion or on SKIP |

**This is not a video.** Asset F asked for one and none was produced:
`ffmpeg`/`ffprobe` are not installed and the Debian mirrors are unreachable, so
there is no encoder in this environment. What ships instead is composed
in-engine from art the pipeline did produce — a slow push-in on
`loading_keyart.jpg` under four captions — and is skippable from the first
frame.

The captions state the premise the game implements and nothing else: a training
facility, the Neon Frontier, inbound waves, Battle Points. `GAME_CONCEPT.md` is
explicit that this game is not story-driven, so a lore-dump intro would be a
misrepresentation of the product.

Finishing **or skipping** marks `intro_seen` on the profile. Skipping has to
count as seeing it: being dropped straight into the dashboard *is* what the
skip button is offering.

## CHAPTER — `stage_chapter.gd`

A title card: `CHAPTER 01 / FIRST LIGHT`, the objective the run measures, and a
CONTINUE action. It also advances on any tap.

## DASHBOARD — `stage_dashboard.gd`

Every number is read from `ProgressionService`, the single owner of the
persistent profile:

* Battle Points
* Best score
* Runs completed
* The loadout the next launch will use

There is no profile level, no streak, no daily reward and no second currency.
The save file holds five things and the dashboard shows those five things; a
sixth row would be decoration disagreeing with gameplay.

| Button | Action |
| --- | --- |
| DEPLOY | starts HERO → WEAPON → WORLD → PRELOAD |
| ARMORY | `HudArmoryUi`, the in-game shop widget, spending real BP for real unlocks |
| SETTINGS | `AegisSettingsMenu`, writing `user://aegis.cfg` |
| REPLAY INTRO | clears `intro_seen` so the cinematic can be seen again without wiping anything |

## HERO SELECTION — `stage_hero_select.gd`

**One operative exists.** The rig in `assets/characters/hero/` is the only
skinned hero in the project, so one card is selectable and two slots are
disabled and labelled `IN DEVELOPMENT`.

The card deliberately carries no numeric stats. There is no hero data model —
no per-hero health, speed or damage — so any number printed here would be
decoration. The portrait is concept art, not the playable model
(`docs/ART_DIRECTION.md` §4).

## WEAPON SELECTION — `stage_weapon_select.gd`

All three weapons are real: the stats are read off the `WeaponDefinition`
resource at runtime, so the screen cannot drift from the weapon the player
fires.

| | Damage | Rate | Mag | Reload | Range | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Pulse Rifle | 18 | 5.0/s | 24 | 1.35 s | 45 m | starter |
| Nova Launcher | 34 | 0.8/s | 6 | 2.2 s | 32 m | splash 24 / 4 m |
| Arc Shooter | 20 | 2.0/s | 12 | 1.7 s | 30 m | chain 2 |

Locked weapons are **disabled** and priced from `ProgressionService.COSTS`
(pulse 0, nova 120, arc 250). Unlocking happens in the Armory, which is the one
place that spends Battle Points, so there is exactly one purchase path.

## WORLD SELECTION — `stage_world_select.gd`

**One theatre exists**: `scenes/worlds/neon_frontier.tscn`, the arena the game
loads. Two slots are disabled placeholders. LAUNCH hands PRELOAD
`{"scene": "res://scenes/main.tscn", ...}` plus the chosen weapon and world.

## PRELOAD — `stage_preload.gd` (same script as LOADING)

Fetches `main.tscn` with real progress, then `change_scene_to_packed`. This is
the only stage allowed to change scene.

---

## Persistence

`user://progression.cfg`, section `profile`. New keys, all validated on read:

| Key | Meaning | Fallback if edited to garbage |
| --- | --- | --- |
| `intro_seen` | cinematic played (or skipped) | `false` |
| `selected_hero` | last chosen hero | `exo_operative` |
| `selected_weapon` | last chosen weapon | `pulse_rifle` |
| `selected_world` | last chosen world | `neon_frontier` |

Ids are checked against `HERO_IDS` / `WEAPON_IDS` / `WORLD_IDS`, which list
only content that exists. A hand-edited save cannot make the front end offer a
hero, weapon or world the game cannot load, and a selected weapon that is not
unlocked falls back to the starter.

`Main._apply_saved_weapon()` applies the saved weapon **once, on boot**. It is
deliberately not on `profile_changed`, so a mid-run swap in the armory is not
overwritten by the saved choice.

## Safe area

Menu screens call `MenuStage.apply_safe_margins()`, which uses
`HudLayout.measure_safe_insets()` — the same function the combat HUD uses. The
pure form was extracted from `resolve_safe_insets()` so the two cannot drift,
which is the failure BUG 2 was about. Back navigation is wired to `ui_cancel`
with a per-stage `BACK_TARGET`, plus an on-screen BACK button on each selection
screen for devices with no Escape key.

## Verification

`game/tests/front_end_journey_smoke.gd` instantiates the real `front_end.tscn`
and walks the journey, asserting at each stop that the stage is the one the
journey asked for, that no enabled button is inert, that no control crosses the
reserved edge, that absent content is disabled, and that `intro_seen` round-trips
through a real `ConfigFile`.

Results are recorded in `docs/asset-inspections/` once the suite has been run.
