# NEON FRONTIER — Playable 3D World

**Purpose:** a continuous, explorable third-person shooter level assembled from real 3D scene components. This is a playable production blockout, not a static concept image, final art lock, or release-ready world. All measurements are provisional Godot units.

## Godot entry points

- Main game: `game/project.godot` → `res://scenes/main.tscn`.
- Standalone environment: `game/scenes/worlds/neon_frontier.tscn`.
- World assembly: `game/scripts/worlds/neon_frontier_world.gd`.
- Reusable component builder: `game/scripts/worlds/neon_frontier_asset.gd`.
- Packed 3D component scenes: `game/scenes/worlds/components/*.tscn`.
- Automated environment checks: `game/tests/neon_frontier_world_smoke.gd` and `game/tests/arena_blockout_smoke.gd`.

Each packed component scene has a `Node3D` root and creates named `MeshInstance3D` parts, material instances, and gameplay-relevant `StaticBody3D`/`CollisionShape3D` components. The world script instances those packed scenes into a single level. Primitive meshes are used deliberately for this buildable blockout; they are actual 3D geometry, not planes baked into an image. The player, enemies, world, lights, and collision all share the same Godot scene.

## Scale and spatial plan

The base terrain is approximately **192 × 180 units** and is centered slightly north of the combat arena. The central combat platform is about 42 units across; the perimeter, side districts, and boss platform extend several dozen units beyond it. A full-width terrain collision plane keeps exploration continuous while layered rock formations and reinforced boundary structures frame the frontier.

```text
                               NORTH / BOSS FRONT
                        perimeter gate and sensor tower
                                      │
                          ┌───────────┴───────────┐
                          │ circular boss platform│
                          │     colossal gate     │
                          └───────────┬───────────┘
                              broad energy causeway
                                      │
 WEST MILITARY OUTPOST ─── CENTRAL REACTOR ARENA ─── EAST LANDING PAD
 command / lab / depot       wave gates + cover       vehicle apron
        │                             │                      │
        └──── wrecked sector ─── south access ───── extraction plant
                                 alien terrain / resources
```

This diagram is a location guide only; the delivered level itself is a fully spatial 3D scene. Outpost, central arena, landing apron, generator yard, ruined sector, perimeter gates, causeway, and boss zone are joined by walkable ground plates and open routes. No zone is a separate image or disconnected floating island.

## 3D component inventory

| Packed scene | Constructed 3D pieces and gameplay role |
|---|---|
| `reactor_core.tscn` | Separated structural footings, four load-bearing pylons, transparent containment cylinder, emerald/turquoise core, segmented energy halos, overhead service arms, orange conduits; the lower center stays open to preserve the combat lane. |
| `command_center.tscn` | Armored foundation and hull, raised command bridge, visor windows, door, roof vents, antenna mast and dish, corner armor, and fasteners. |
| `research_lab.tscn` | Ceramic laboratory shell, glass sampling vessel, colored sample core, service wings, roof vents, equipment pods, and a maintenance arm. |
| `equipment_depot.tscn` | Two storage modules, ribbed shutter, yellow hoist canopy, lifting rail, repair arm, and equipment crates. |
| `generator_bank.tscn` | Three contained generator towers, glass sleeves, luminous energy columns, repeated pressure bands, feed/return pipes, and service walk. |
| `boss_gate.tscn` | Tall reinforced docking frame, supports, shutter leaves and slats, cyan seam lights, power conduits, bolts, and warning hardware. |
| `defense_turret.tscn` | Mount plate, yaw bearing, armored housing, twin barrels, optical sensor, and base collision. |
| `sensor_tower.tscn` | Structural shaft, observation deck/cabin, radar plates, masts, dishes, and collision shaft. |
| `landing_pad.tscn` | Raised plate foundation, metallic deck panels, high-contrast landing symbol, safety edges, and beacon lights. |
| `wrecked_transport.tscn` | Damaged hull, glazed cockpit, separated/broken wings, engines, hot impact damage, and scattered wreck plates. |
| `alien_drone_wreck.tscn` | Chassis, luminous sensor core, articulated broken arms, joints, claw plates, and a damaged cable. |
| `crystal_cluster.tscn` | Individually tapered, differently colored cyan/emerald/turquoise mineral shards on geological roots. |
| `alien_flora.tscn` | Stems, luminous buds, varied leaves, and arching fronds. |
| `rock_cluster.tscn` | Irregularly scaled rock masses with warm sandstone/rose variation and selected collision. |
| `enemy_spawn_gate.tscn` | Open arch frame, visible warning panels, cyan guide strips, beacons, and clear passage through the middle. |
| `cover_module.tscn` | Segmented waist-high armored cover with yellow top marking, edge guards, signal panels, bolts, and collision. |

## Districts and traversal

### Central combat arena

The central 42-unit platform has layered metal trim, alternating panel plates, seams/fasteners, cyan and turquoise energy channels, copper conduits, yellow/orange warning edges, four open entry arches, and asymmetric cover. The tall reactor is the central visual anchor, supported above the open lower combat lane. The existing southeast service deck and shallow ramp remain as an explicit no-jump traversal test. Spawn beacons correspond to the actual Wave Director markers.

### Military outpost

The western district contains the command center, laboratory, equipment depot, observation/signal towers, supplies, and damaged perimeter sections. The access apron connects to the central arena; its buildings have volume and selected collision, while service details remain visual-only. A damaged security checkpoint marks the ruined edge.

### Extraction plant and landing zone

The east/northeast route reaches a full vehicle landing pad and the generator bank. Five large pipe runs, supports, maintenance walkways, and colored cores visually lead back toward the reactor. Energy conduits are placed above the terrain with supports rather than floating without attachment.

### Destroyed frontier sector

The south/west side route contains a crashed human transport, broken alien drone, disabled turret/checkpoint, fractured floor plates, scrap, scarred walls, controlled orange damage accents, and a sealed deeper-facility gate. Debris is kept off the main approach lane.

### Perimeter and alien terrain

Segmented blue-and-silver defense walls leave actual openings at the north, south, east, and west gates. Six turret emplacements, sensor towers, radar arrays, and a communication mast establish the outpost defense ring. Beyond the traversable industrial plateau, warm layered rock shelves, larger cliff clusters, mineral shards, and varied alien flora frame the boundary. Small resource canisters occupy side alcoves away from the main firing lanes.

### Boss encounter

A broad northbound causeway and open perimeter gate lead from the central arena to a large circular, reinforced platform. The monumental docking gate and energy supports form a high-contrast landmark behind the boss floor. The arena center is intentionally open; its warning ring and radial energy markings keep its edge readable.

## Materials, lighting, and readability

The environment uses `StandardMaterial3D` materials with explicit albedo, metallic, roughness, transparency, and restrained emissive settings. Pearl ceramic and silver carry most human structures; royal blue identifies military armor; cyan/turquoise mark energy and routes; emerald highlights selected cores/crystals; yellow indicates safety; orange/red signal damage and hazards; warm sandstone, rose rock, teal foliage, and lime bioluminescence provide a contrasting planetary palette. The main combat area is lit by a warm directional daylight source and bright ambient sky. Small local cyan/green lights mark only major energy landmarks, while fog/glow are deliberately subtle.

Combat readability takes priority over prop density: cover is waist-high and asymmetric, principal routes are wide, the arena center is open, and defensive structures sit on the edge of the play space. Decoration and repeated props do not replace collision or the enemy/player combat systems.

## Validation and known limits

**VERIFIED (Godot 4.7.2 headless):** the main scene starts cleanly for 120 iterations, and the NEON FRONTIER smoke test loads the world with 2,545 individual `MeshInstance3D`s and 138 `StaticBody3D`s. It checks named 3D districts/components, the continuous floor collider, route pieces, central-to-boss traversal (z=-49.08), the raised boss platform via its ramp (z=-64.08, y=0.29), and the landing-pad ramp (x=39.10, y=0.17). The seven weapon/combat/Shooter/Wave Director/arena/reward regression tests pass sequentially as well; the Wave Director's expected invalid-spawn warning is the only warning. `gdformat`, GDScript lint, and `git diff --check` pass. This verifies headless scene composition and selected traversal/collision behavior, not visual quality or device performance.

This is still a generated-geometry blockout: primitive geometry and procedural materials are not equivalent to final hand-authored high-resolution production assets. Lighting/material response, mobile draw-call cost, the player’s long-range movement feel, enemy navigation through all routes, collectible behavior, boss AI, touch controls, and Android/device performance require editor playtesting. No release-art, Android-export, or physical-device claim is made by a headless scene test.

## Environment production stages and approval gates

Follow these stages in order. Do not start final asset production until Stage 1 has been interactively reviewed and approved.

1. **Blockout — current stage; headless checks pass, interactive approval pending.** Confirm the arena footprint, combat lanes, route widths, collision, spawn/object placement, and continuous traversal. The current 192 × 180-unit blockout passes the headless world/combat regression suite, including central-to-boss, boss-platform, and landing-pad traversal. This does not verify sightlines, feel, or touch navigation on a device; keep primitives until those are reviewed.
2. **Asset production — after Stage 1 approval.** Replace only high-visibility or gameplay-critical primitives that need greater quality with actual modular 3D assets made in Blender or Tripo AI. Preserve each asset’s real 3D geometry, scale/origin, relevant collider, and component-scene integration; retain editable/source files and record provenance/licensing. A flat photo or image plane is not a world asset.
3. **Materials and textures — after asset silhouettes and scale are accepted.** Apply PBR material properties, texture maps, surface detail, and the bright NEON FRONTIER palette. Check UVs, transparency, texture memory, and readability on the intended mobile renderer; existing procedural colors/emission are placeholders, not a completed texture pass.
4. **Lighting and VFX — after material readability.** Tune key/fill/environment lighting and add restrained energy, particle, impact, and environmental effects. Protect combat visibility and establish per-effect limits for lights, particles, transparency, and overdraw.
5. **Optimization — on a selected Android baseline.** Profile a real Android build for frame time, draw calls, shader/material cost, texture and mesh memory, physics load, particles/overdraw, load time, heat, and stability. Optimize measured bottlenecks, then repeat gameplay/traversal checks. A headless scene test or successful export alone is not a device-performance pass.
