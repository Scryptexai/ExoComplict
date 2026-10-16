# Project Overdrive — NEON FRONTIER World Prototype

**Project Overdrive** is a mobile-first, single-player third-person sci-fi action shooter prototype. **NEON FRONTIER** is its connected playable world. The world deliverable is a runnable Godot 3D scene—not a static concept image—and is built from reusable component scenes containing actual `MeshInstance3D` geometry, materials, supports, and selected physics colliders.

## Start here

- [`game/scenes/worlds/neon_frontier.tscn`](game/scenes/worlds/neon_frontier.tscn) — complete playable frontier environment.
- [`game/scenes/worlds/components/`](game/scenes/worlds/components/) — reusable 3D assets for the reactor, outpost, laboratory, depot, extraction plant, gates, defenses, wrecks, rocks, crystals, and alien flora.
- [`WORLD_BLOCKOUT.md`](WORLD_BLOCKOUT.md) — world zones, route layout, modular asset inventory, and implementation notes.
- [`DEVELOPMENT_ROADMAP.md`](DEVELOPMENT_ROADMAP.md) — project phases, scope gates, risks, and next steps.
- [`PROJECT_DECISIONS.md`](PROJECT_DECISIONS.md) — provisional gameplay and technical decisions.
- [`GAME_CONCEPT.md`](GAME_CONCEPT.md) — source game and technical design concept.
- [`GAME_OVERVIEW.md`](GAME_OVERVIEW.md) — gameplay/visual overview.
- [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md) — Godot/Android/Blender setup and asset workflow.

## Playable 3D world

The Godot project is in [`game/`](game/). Its world spans a connected frontier landscape with a central circular/hexagonal combat arena, a suspended cyan/emerald reactor, a military command center, research lab, equipment depot, generator bank, vehicle landing pad, perimeter gates and defenses, a destroyed sector, alien cliffs, crystal clusters, luminous vegetation, and a dedicated boss platform and docking gate. Broad ground-level routes connect the districts; modular cover and defense structures leave combat lanes readable. Reusable component scenes create distinct 3D meshes, PBR-style materials, colored emissive parts, and gameplay-relevant collision. **VERIFIED:** the headless Godot runtime instantiates 2,545 `MeshInstance3D`s and 138 `StaticBody3D`s for this world. It is a procedural geometry blockout, not a single image or final authored art.

The player has keyboard and touch controls, a data-driven `WeaponDefinition`/`WeaponController` roster, Pulse Rifle, Nova Launcher, and Arc Shooter. A capped Wave Director runs deterministic Runner/Shooter mixes. Player health, defeat, pause/retry, hit feedback, run-only Score/BP rewards, survival time, and the results overlay are wired into the loop. **VERIFIED (headless):** the main scene starts cleanly, and all eight world/combat regression smoke tests pass. The world test confirms central-to-boss and landing-pad traversal; the boss ramp ends at z=-64.08 (y=0.29), and the landing ramp reaches x=39.10 (y=0.17). Only the expected invalid-spawn warning appears in the Wave Director negative case. Asset detail, enemy balance, and pacing remain provisional; visual rendering, mobile performance, physical touch/device behavior, persistent BP progression, Android export, final production assets/audio, ads, IAP, and multiplayer are not verified or implemented.

Open `game/project.godot` in Godot 4.7.2 and run the main scene to explore the world. Import and test without a GUI:

```bash
godot --headless --editor --path game --quit
godot --headless --path game --script res://tests/neon_frontier_world_smoke.gd
godot --headless --path game --script res://tests/arena_blockout_smoke.gd
godot --headless --path game --script res://tests/weapon_system_smoke.gd
godot --headless --path game --script res://tests/arc_weapon_smoke.gd
godot --headless --path game --script res://tests/combat_feedback_smoke.gd
godot --headless --path game --script res://tests/wave_director_smoke.gd
godot --headless --path game --script res://tests/reward_loop_smoke.gd
godot --headless --path game --script res://tests/shooter_enemy_smoke.gd
```

PC fallback controls: WASD to move, hold right mouse and drag to aim, hold left mouse or FIRE to shoot, Escape to pause, and R to reset the current run. Mobile input uses drag-left for movement, drag-right for aim, FIRE, and PAUSE; after defeat the Results overlay presents a RETRY button.

## Toolchain check

Run this read-only preflight after installing local tools:

```bash
./scripts/check_toolchain.sh
```

It reports missing tools but does not install software or modify project settings. Optional static lint: create `.venv`, install `requirements-dev.txt`, then run `./scripts/lint_gdscript.sh`. A full headless Editor CLI build, Android export, interactive touch validation, and physical-device testing are still required before release. No GUI is required for the CLI workflow; see the toolchain notes.
