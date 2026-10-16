# Project Overdrive — NEON FRONTIER World Prototype

**Project Overdrive** is a mobile-first, single-player third-person sci-fi action shooter prototype. **NEON FRONTIER** is its connected 3D world—not a static concept image. The current blockout uses reusable Godot components and some licensed KayKit GLTF props; provenance is in [`game/assets/world/kaykit_space_base_bits/`](game/assets/world/kaykit_space_base_bits/) and [`WORLD_BLOCKOUT.md`](WORLD_BLOCKOUT.md). Ten real Kenney Space Kit GLBs have now been sourced and downloaded for visual review; they are deliberately not yet used to replace scene props pending asset/visual selection and Godot import validation.

## Start here

- [`game/scenes/worlds/neon_frontier.tscn`](game/scenes/worlds/neon_frontier.tscn) — complete playable frontier environment.
- [`game/scenes/worlds/components/`](game/scenes/worlds/components/) — reusable 3D components for the reactor, outpost, laboratory, depot, extraction plant, gates, defenses, wrecks, rocks, crystals, and alien flora.
- [`game/assets/world/kenney_space_kit/ASSET_PROVENANCE.md`](game/assets/world/kenney_space_kit/ASSET_PROVENANCE.md) — downloaded Kenney GLB candidates, CC0/source provenance, hashes, and rig inspection; not yet instantiated by gameplay scenes.
- [`WORLD_BLOCKOUT.md`](WORLD_BLOCKOUT.md) — world zones, route layout, modular asset inventory, and implementation notes.
- [`DEVELOPMENT_ROADMAP.md`](DEVELOPMENT_ROADMAP.md) — project phases, scope gates, risks, and next steps.
- [`GAP_ANALYSIS.md`](GAP_ANALYSIS.md) — verified-vs-claimed status, per-system gaps, prioritized backlog, and how to run the new tooling.
- [`PROJECT_DECISIONS.md`](PROJECT_DECISIONS.md) — provisional gameplay and technical decisions.
- [`GAME_CONCEPT.md`](GAME_CONCEPT.md) — source game and technical design concept.
- [`GAME_OVERVIEW.md`](GAME_OVERVIEW.md) — gameplay/visual overview.
- [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md) — Godot/Android/Blender setup and asset workflow.

## Playable 3D world

The Godot project is in [`game/`](game/). Its world spans a connected frontier landscape with a central circular/hexagonal combat arena, a suspended cyan/emerald reactor, a military command center, research lab, equipment depot, generator bank, vehicle landing pad, perimeter gates and defenses, a destroyed sector, alien cliffs, crystal clusters, luminous vegetation, and a dedicated boss platform and docking gate. Broad ground-level routes connect the districts; modular cover and defense structures leave combat lanes readable. Reusable component scenes create distinct 3D meshes, PBR-style materials, colored emissive parts, and gameplay-relevant collision. A selective KayKit Space Base Bits subset is instantiated as real 3D GLTF models for the depot, cargo stacks, service truck, extraction drill, landing-pad surface, and four boundary rocks; the CC0 license travels with the assets. Most of the surrounding world remains editable procedural blockout geometry, not a single image or final authored art.

The player has keyboard and touch controls, a data-driven `WeaponDefinition`/`WeaponController` roster, Pulse Rifle, Nova Launcher, and Arc Shooter. A capped Wave Director runs deterministic Runner/Shooter mixes. The HUD has a live health bar, wave/enemy state, weapon and hold-to-fire controls, an EMP Pulse skill button, run Score/BP/KOs/time, target health/shots, pause/resume, and retry feedback. EMP Pulse damages nearby wave enemies, plays an expanding 3D ring, reports hit feedback, and recharges on a 12-second cooldown. Mobile movement uses a 360° left-side virtual joystick; right-side drag aims. Touch events are routed explicitly to movement, look, fire, weapon, skill, pause, and results-retry controls; pausing or losing window focus clears held touch input. The camera is configured as a closer rear-follow with a right-shoulder offset and downward pitch.

**Previously verified (headless, before the current GLTF/skill integration):** an earlier checkout passed nine world/combat/playability smoke tests, including the original touch/HUD checks and central-to-boss/landing-pad traversal. That historical result does not validate the newly added asset loading, EMP skill, or expanded joystick-direction tests. **Current worktree (re-checked 16 Oct 2026):** static GDScript parse, `gdlint`, and `gdformat --check` pass for all 28 scripts (gdtoolkit 4.5.0 via `./scripts/dev_check.sh`), and the new static project doctor reports 0 failures / 8 warnings across scene references, node paths, script-to-node types, input actions, signals, groups, weapon contracts, glTF integrity, and documentation drift. The current nine smoke tests now **pass headlessly on real Godot 4.7.2-stable in CI** (`Godot CI` run #1: install → headless import → all nine tests → uploaded logs); the same run also executes the static job. That verifies gameplay logic only — the checks still cannot see rendering, frame time, or device input, and the pinned engine binary cannot be downloaded inside the current coding sandbox (GitHub release-asset host unreachable), so CI is the runtime environment. **Not visually/device verified:** rendered desktop appearance, Android touch behavior, mobile performance, Android export, or physical-device behavior.

**Known visual-asset blocker:** the player, Runner, and Shooter scenes still use capsule placeholder visuals; the weapon visual is a box placeholder. The only usable local character candidate, `Hero_02.glb`, is a static single-mesh humanoid with no skeleton or clips (and is not included in the branch); `HERO_01.glb` is only 2 bytes, and no weapon GLB was found. It has not been imported or tested in Godot. See [`ANIMATION_ASSET_INSPECTION.md`](ANIMATION_ASSET_INSPECTION.md). Rigging/animation and model attachment are intentionally not claimed until the actual assets can be inspected and a valid rig/weapon source is available. Persistent BP progression, final production assets/audio, ads, IAP, and multiplayer remain unimplemented.

Open `game/project.godot` in Godot 4.7.2 and run the main scene to explore the world. Install the pinned engine build and run everything without a GUI:

```bash
# 1. Static checks that need no engine (syntax, lint, format, references, contracts)
./scripts/dev_check.sh

# 2. Install the pinned Godot 4.7.2 editor (+ export templates) outside the repo
./scripts/install_godot.sh --with-templates

# 3. Import the project and run all nine smoke tests with per-test logs
./scripts/run_smoke_tests.sh
./scripts/run_smoke_tests.sh --list                 # available tests
./scripts/run_smoke_tests.sh wave_director_smoke    # a single test
```

`scripts/run_smoke_tests.sh` performs the headless Editor import and then every smoke test with `--headless --path game --script res://tests/<name>`, writing logs to the git-ignored `exports/test-logs/`. The nine tests are `neon_frontier_world_smoke.gd`, `arena_blockout_smoke.gd`, `weapon_system_smoke.gd`, `arc_weapon_smoke.gd`, `combat_feedback_smoke.gd`, `wave_director_smoke.gd`, `reward_loop_smoke.gd`, `shooter_enemy_smoke.gd`, and `playability_hud_smoke.gd`. The equivalent manual commands are:

```bash
godot --headless --editor --path game --quit
godot --headless --path game --script res://tests/neon_frontier_world_smoke.gd
godot --headless --path game --script res://tests/weapon_system_smoke.gd
```

`.github/workflows/godot-ci.yml` runs the static job plus a headless Godot job (install → import → all smoke tests → uploaded logs) on every pull request.

PC fallback controls: WASD to move, hold right mouse and drag to aim, hold left mouse or FIRE to shoot, tap the weapon button or press E to cycle weapons, click the EMP skill when ready, Escape to pause, and R to reset the current run. Mobile input uses the 360° left-side joystick to move, right-side drag to aim, hold FIRE, tap the weapon button or EMP skill, and PAUSE/RESUME; after defeat the Results overlay presents a touch-operated RETRY button.

## Android import/export workflow

The project structure is prepared for Android packaging: runtime KayKit GLTFs are explicitly preloaded as imported `PackedScene` resources so Godot can trace their BIN/texture dependencies. A local Godot Android export preset is still required. Create it in the Editor (`Project > Export > Add... > Android`), set the team's package ID and debug options, and configure matching SDK/JDK/export templates. `game/export_presets.cfg` is intentionally git-ignored because it may contain machine-local paths and signing settings.

After installing the pinned toolchain and creating a local preset named `Android`, run:

```bash
./scripts/check_toolchain.sh
./scripts/export_android_debug.sh
```

The export script imports in headless Editor mode, runs all `game/tests/*_smoke.gd` scripts, exports `exports/project-overdrive-debug.apk`, and checks the APK archive when `unzip` is installed. Override the preset/output with `ANDROID_EXPORT_PRESET` and `ANDROID_APK_PATH`; set `GODOT_BIN` if the executable is not named `godot` or `godot4`. It does not install SDK packages, create release signing keys, or deploy to a device. **This workflow is prepared, not executed here:** Godot, JDK, Android SDK/ADB and Gradle are unavailable in the current environment, so no APK or Android runtime result is claimed. Use [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md) for setup details.

## Toolchain check

Run this read-only preflight after installing local tools:

```bash
./scripts/check_toolchain.sh
```

It reports missing tools but does not install software or modify project settings. Optional static lint: create `.venv`, install `requirements-dev.txt`, then run `./scripts/lint_gdscript.sh`. Headless Editor import, Android export, interactive touch validation, and physical-device testing remain required; no GUI is needed for the CLI workflow.
