# Project Overdrive

**Project Overdrive** (working title; repository name: Cyber-Strike) is a mobile-first, single-player third-person sci-fi arena survival shooter. This repository now includes a Godot combat greybox prototype; it is an early vertical slice, not the complete MVP.

## Start here

- [`GAME_CONCEPT.md`](GAME_CONCEPT.md) — game and technical design concept.
- [`GAME_OVERVIEW.md`](GAME_OVERVIEW.md) — gameplay/visual overview.
- [`IAP_CONCEPT.md`](IAP_CONCEPT.md) — economy and staged monetization concept.
- [`DEVELOPMENT_ROADMAP.md`](DEVELOPMENT_ROADMAP.md) — phases, scope gates, risks, and next steps.
- [`PROJECT_DECISIONS.md`](PROJECT_DECISIONS.md) — provisional defaults used to start implementation.
- [`WORLD_BLOCKOUT.md`](WORLD_BLOCKOUT.md) — current Relay Yard greybox intent and validation constraints.
- [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md) — Godot/Android/Blender setup and asset workflow.

## Current prototype

The Godot project is in [`game/`](game/). It currently contains a compact sci-fi Relay Yard greybox (boundary walls, asymmetric cover, central landmark, a low ramped service deck, and visible spawn beacons), a third-person player/camera, keyboard and touch controls, a Pulse Rifle projectile, a damageable training target, and a capped Wave Director with a Runner-only intro followed by deterministic Runner/Shooter mixes. The prototype Shooter holds a standoff range and fires a telegraphed, cover-blocked attack that can be dodged. Player health, hit/damage feedback, defeat, pause, retry, run-only Score/BP rewards, survival time, and a results/retry overlay are wired into the loop. Runner/Shooter and wave rewards are still provisional; earned BP is not yet a persistent wallet. The environment, enemy balance, and wave pacing remain provisional; see [`WORLD_BLOCKOUT.md`](WORLD_BLOCKOUT.md). It does **not** yet contain modular weapons beyond the Pulse Rifle, persistent progression/unlocks/save, final art/audio, Android exports, ads, IAP, or multiplayer.

Install the pinned Godot CLI Editor build and matching export templates listed in [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md). Import and test without a GUI:

```bash
godot --headless --editor --path game --quit
godot --headless --path game --script res://tests/combat_feedback_smoke.gd
godot --headless --path game --script res://tests/wave_director_smoke.gd
godot --headless --path game --script res://tests/arena_blockout_smoke.gd
godot --headless --path game --script res://tests/reward_loop_smoke.gd
godot --headless --path game --script res://tests/shooter_enemy_smoke.gd
```

PC fallback controls: WASD to move, hold right mouse and drag to aim, hold left mouse or FIRE to shoot, Escape to pause, and R to reset the current run. Mobile input uses drag-left for movement, drag-right for aim, FIRE, and PAUSE; after defeat the Results overlay presents a RETRY button.

## Toolchain check

Run this read-only preflight after installing local tools:

```bash
./scripts/check_toolchain.sh
```

It reports missing tools but does not install software or modify project settings. Optional static lint: create `.venv`, install `requirements-dev.txt`, then run `./scripts/lint_gdscript.sh`. A Godot 4.7.2 headless runtime built from source passes main-scene startup plus combat-feedback/results-retry, Wave Director/mixed composition, arena-blockout, reward-loop/results, and Shooter attack smoke tests in this sandbox. A full headless Editor CLI build, Android export, and physical-device testing remain outstanding. No GUI is required for the CLI workflow. Check the toolchain notes for details.
