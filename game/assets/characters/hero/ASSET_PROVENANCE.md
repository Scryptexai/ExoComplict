# Hero common model — provenance and integration notes

## Source

- **File:** `HERO-3d-tier_1-common.glb`
- **Source:** user-provided Google Drive asset, selected by the user for the game.
- **GLB metadata:** generator `Tripo`, version `2.0`.
- **File size:** 24,436,604 bytes.
- **SHA-256:** `b20c4c68b5cb5003c9c10b8dd92c0e4007a5b94b66e934195abd071b77a6b0f0`.
- **License:** no license or platform terms were included with the Drive file. The user has designated it as an intended game asset; confirm usage and redistribution rights before public/commercial release.

## Structural audit

- 1 skinned mesh primitive; 253,387 vertices and 482,282 triangles.
- 79 joints; 81 GLTF nodes.
- Animation clips: `idle` (15.33 s), `walk` (2.33 s), and `run` (1.25 s).
- Embedded 2048×2048 normal, base-colour, and metallic/roughness textures.
- Source POSITION bounds are approximately 1.0 unit high. The player scene scales the visual by 1.8 to match its existing 1.8 m gameplay collider; the collider remains separate.

## Runtime limitations

The player controller selects the supplied idle/walk/run clips from horizontal movement speed. No aim, fire, reload, hit, or death clips are present, and no bones or weapon attachment points were invented. The scene still uses a prototype box weapon and unverified muzzle marker. Godot import, runtime playback, Blender deformation/axis inspection, and Android performance were not validated in this sandbox. The 482k-triangle mesh and three 2048 maps need a mobile budget/LOD pass before performance claims.

The rare/epic tier models and the separate gun model were audited from Drive but are not copied into the runtime project. The world scene and environment assets were left unchanged.
