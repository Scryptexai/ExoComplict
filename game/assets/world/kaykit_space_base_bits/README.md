# KayKit Space Base Bits — selected world assets

- Upstream pack: https://github.com/KayKit-Game-Assets/KayKit-Space-Base-Bits-1.0
- License: CC0 (Creative Commons Zero); the original `LICENSE.txt` is included beside these files. The license states that optional credit to Kay Lousberg is appreciated but not required.
- Source snapshot: downloaded from the upstream `main` branch on 2026-10-16. The archive was not pinned or verified against an immutable commit, so do not infer a commit hash from this copy.

Included GLTF models and companion BIN files:

- `cargo_A_stacked`
- `cargo_B_stacked`
- `cargodepot_A`
- `drill_structure`
- `landingpad_large`
- `rocks_B`
- `spacetruck_large`

`gltf/spacebits_texture.png` is the shared texture atlas referenced by the GLTF files. The assets are loaded as 3D geometry by `game/scripts/worlds/gltf_asset_library.gd` and placed in the modular world; none is flattened into a background image or billboard.
