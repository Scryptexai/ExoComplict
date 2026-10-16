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

The player has keyboard and touch controls, a data-driven `WeaponDefinition`/`WeaponController` roster, Pulse Rifle, Nova Launcher, and Arc Shooter. A capped Wave Director runs deterministic Runner/Shooter mixes. The HUD now has a live health bar, wave/enemy state, current-weapon button, hold-to-fire button, run Score/BP/KOs/time, target health/shots, pause/resume, and retry feedback. Touch events are routed explicitly to the joystick, aim, fire, weapon, pause, and results-retry controls; pausing or losing window focus clears held touch input. The camera is configured as a closer rear-follow with a right-shoulder offset and downward pitch.

**VERIFIED (headless):** the main scene starts cleanly, and nine world/combat/playability smoke tests pass, including touch movement, camera look, touch fire/projectile spawn, weapon switching, pause-clears-fire, retry, HUD updates, and the existing combat/world regression tests. The world test confirms central-to-boss and landing-pad traversal; the boss ramp ends at z=-64.08 (y=0.29), and the landing ramp reaches x=39.10 (y=0.17). Only the expected invalid-spawn warning appears in the Wave Director negative case. **Not visually/device verified:** rendered desktop appearance, Android touch behavior, mobile performance, Android export, or physical-device behavior.

**Known visual-asset blocker:** the player, Runner, and Shooter scenes still use capsule placeholder visuals; the weapon visual is a box placeholder. The only usable local character candidate, `Hero_02.glb`, is a static single-mesh humanoid with no skeleton or clips (and is not included in the branch); `HERO_01.glb` is only 2 bytes, and no weapon GLB was found. It has not been imported or tested in Godot. See [`ANIMATION_ASSET_INSPECTION.md`](ANIMATION_ASSET_INSPECTION.md). Rigging/animation and model attachment are intentionally not claimed until the actual assets can be inspected and a valid rig/weapon source is available. Persistent BP progression, final production assets/audio, ads, IAP, and multiplayer remain unimplemented.

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
godot --headless --path game --script res://tests/playability_hud_smoke.gd
```

PC fallback controls: WASD to move, hold right mouse and drag to aim, hold left mouse or FIRE to shoot, tap the weapon button or press E to cycle weapons, Escape to pause, and R to reset the current run. Mobile input uses a left-side drag to move, right-side drag to aim, hold FIRE, tap the weapon button to cycle, and PAUSE/RESUME; after defeat the Results overlay presents a touch-operated RETRY button.

## Toolchain check

Run this read-only preflight after installing local tools:

```bash
./scripts/check_toolchain.sh
```

It reports missing tools but does not install software or modify project settings. Optional static lint: create `.venv`, install `requirements-dev.txt`, then run `./scripts/lint_gdscript.sh`. A full headless Editor CLI build, Android export, interactive touch validation, and physical-device testing are still required before release. No GUI is required for the CLI workflow; see the toolchain notes.
