# Arena 01 — Relay Yard (Greybox)

**Status:** layout prototype only. The setting, geometry, colors, and measurements are provisional; this is not an art lock or final world.

## Design intent

A compact, readable sci-fi industrial relay yard for third-person survival combat. The arena stays enclosed and approximately 30 × 30 Godot units; it is deliberately not an open world. The current pass should make the play space easier to read without hiding that its assets are still placeholders.

## Current blockout

- **Perimeter:** flat arena floor and four boundary walls; default wall height 3.6 units.
- **Landmark:** a central relay pylon and a floor ring mark the middle, while the center firing lane remains clear of collision.
- **Combat lanes:** four asymmetric cover blocks of different heights create left/right routes and local sightline breaks without closing the middle.
- **Elevation:** a low service deck in the southeast is connected by a shallow ramp from the west. It is intended to be walkable without a jump action.
- **Spawn read:** eight perimeter spawn markers have flat emissive beacon discs. The discs are visual-only; the Wave Director remains responsible for collision, edge, player-distance, and camera-front checks.
- **Lighting/background:** one unshadowed directional key light, controlled cool ambient/background colors, teal relay marks, and amber spawn/deck accents.

All meshes remain primitive, mostly procedural boxes and cylinders. Teal/amber coloration is a greybox language for gameplay readability, not final palette or world lore.

## Landmark and gameplay coordinates

Positions below are provisional Godot world units; the scene root is the origin.

| Element | Position / shape | Gameplay purpose |
|---|---|---|
| Player start | `(0, 0, 8)` | South entry, initially looking into the arena |
| Training target | `(0, 0, -8)` | Keeps a clear centerline for aim/projectile smoke tests |
| Relay pylon | `(-1.8, 1.2, 0)`, `1.2 × 2.4 × 1.2` | Landmark and one off-axis sightline break |
| West/east covers | `(-4, .8, 0)` and `(4, .8, -3)` | Medium cover; leaves the central firing lane open |
| North/south cover clusters | Around `x = ±6`, `z = ±6` | Asymmetric flank routes with mixed low/tall silhouettes |
| Service deck | `(11.3, .25, 5.5)`, top at `y = .5`; shallow ramp approaches from west | A low no-jump elevation test on the southeast edge, moved off common spawn-to-player approach lines while preserving a flank route beside the east wall |
| Spawn ring | Corners near `x/z = ±11`; cardinal points near `±12` | Perimeter entry choices, filtered at runtime for safety |

## Layout constraints

1. Keep the player-to-training-target centerline open while the target dummy remains in the scene.
2. Preserve at least two routes around the center relay and cover blocks; avoid making one cover into a full-width choke.
3. Keep the service deck low and ramp-accessible because the current player has no jump action.
4. Keep spawn gates near the edge, out of the direct camera-front cone when alternatives are available, and far enough from the player. Never add a spawn marker inside collision geometry.
5. Validate both projectile occlusion and Runner traversal before replacing any blockout with final meshes.

## Validation still required

The headless smoke tests check spawn clearance, arena bounds, spawn spacing, active caps, wave progression, and failure when no spawn location is usable. `arena_blockout_smoke.gd` also checks the key landmarks and beacons, walks the player up the service ramp, and verifies that a Runner closes more than eight units of distance over six simulated seconds on the east-to-south approach route. This does **not** prove that every Runner approach avoids getting stuck around every cover, that the ramp feels comfortable, or that the layout feels good on a phone. Those still need interactive/device playtesting before final environment assets, art polish, or a level-size decision.
