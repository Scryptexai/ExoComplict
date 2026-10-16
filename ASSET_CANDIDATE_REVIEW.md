# Realistic / higher-detail 3D asset research

**Review date:** 2026-10-16  
**Status:** research only — no candidate in this review is integrated into a gameplay scene. The Kenney low-poly candidates remain unreferenced. PNGs linked below are source previews only; the in-game candidates are 3D model files, not static images.

The current world direction is stylized-realistic sci-fi and must remain a component-based 3D world. This review prioritizes actual `.glb` files, identifiable provenance, license evidence, and mobile suitability. Candidate GLBs were downloaded into the ignored local `.cache/asset-research/` folder for structural/visual inspection only; they were not added to `game/` or the Android resource graph.

## Candidate A — NASA 3D Resources (free, real hardware)

Source: [NASA-3D-Resources](https://github.com/nasa/NASA-3D-Resources), pinned to commit [`11ebb4ee043715aefbba6aeec8a61746fad67fa7`](https://github.com/nasa/NASA-3D-Resources/tree/11ebb4ee043715aefbba6aeec8a61746fad67fa7). The repository README describes the assets as “free and without copyright”; this is a repository-level statement, not a per-file CC0 license. Follow the repository's linked usage guidance and do not imply NASA endorsement. Several previews/models visibly carry NASA insignia and the U.S. flag.

| Asset | Source GLB size | Structural inspection | Visual / game-fit assessment |
|---|---:|---|---|
| [Habitat Demonstration Unit, part 1](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Habitat%20Demonstration%20Unit/Habitat%20Demonstration%20Unit%20%28part%201%29.glb) + [part 2](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Habitat%20Demonstration%20Unit/Habitat%20Demonstration%20Unit%20%28part%202%29.glb) | 516,748 + 710,988 bytes | 2,264 + 4,320 triangles; static; two embedded images per file | Most practical free architecture candidate for a research/outpost area. Moderate/simple geometry rather than a high-detail art pack; NASA-branded. [Part 1 preview](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Habitat%20Demonstration%20Unit/Habitat%20Demonstration%20Unit%20%28part%201%29.png) · [Part 2 preview](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Habitat%20Demonstration%20Unit/Habitat%20Demonstration%20Unit%20%28part%202%29.png) |
| [Mars 2020 Perseverance Rover](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Mars%202020%20Perseverance%20Rover/Mars%202020%20Perseverance%20Rover.glb) | 4,987,176 bytes | ~199,521 triangles; 47 materials; 44 embedded images; 1 skin and 23 animation clips in the file | The strongest detailed vehicle candidate. Could work as a single static/animated set-dressing prop, but needs a deliberate mobile LOD/texture budget before use. Not a replacement for modular world architecture. [Preview](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Mars%202020%20Perseverance%20Rover/Mars%202020%20Perseverance%20Rover.png) |
| [RASSOR robot](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Regolith%20Advanced%20Surface%20Systems%20Operations%20Robot%20%28RASSOR%29/Regolith%20Advanced%20Surface%20Systems%20Operations%20Robot%20%28RASSOR%29.glb) | 6,283,464 bytes | ~2,029,759 triangles | Reject for mobile use as-is; would require substantial optimization. [Preview](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Regolith%20Advanced%20Surface%20Systems%20Operations%20Robot%20%28RASSOR%29/Regolith%20Advanced%20Surface%20Systems%20Operations%20Robot%20%28RASSOR%29.png) |
| [Vehicle Assembly Building](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Vehicle%20Assembly%20Building%20%28VAB%29/Vehicle%20Assembly%20Building%20%28VAB%29.glb) | 6,505,624 bytes | ~6,458 triangles; 9 materials; 4 embedded images | Large, simple industrial building silhouette; the preview includes NASA/U.S. branding. [Preview](https://github.com/nasa/NASA-3D-Resources/blob/11ebb4ee043715aefbba6aeec8a61746fad67fa7/3D%20Models/Vehicle%20Assembly%20Building%20%28VAB%29/Vehicle%20Assembly%20Building%20%28VAB%29.png) |

The compact ISS model identified earlier is only 39,708 bytes and reads as a simplified distant prop. NASA also hosts much larger ISS/Gateway files (about 95.9 MB and 66.2 MB respectively); those are not sensible mobile foreground assets without a separate optimization/LOD pass. NASA's collection is a source library, not a cohesive, game-ready modular kit.

**Assessment:** legitimate source and useful individual props, but NASA hardware/markings do not yet read as a coherent fictional Cyber-Strike pack. The Habitat pair is the lowest-risk technical sample; the Rover is the most detailed but needs optimization. Do not integrate either without approval and a Godot import/render check.

## Candidate B — Asset Smash “Space Base” (paid, best stated art-direction match)

The [Fab listing](https://www.fab.com/listings/bb4dd09d-8811-4a08-adf6-a480f8ded44e) describes a high-detail sci-fi outpost kit with 25 models, 11 4K PBR materials, and about 560k polygons; GLB/glTF are listed formats. It is a premium marketplace asset, not a free GitHub pack. This is the closest researched match for a cohesive, authored sci-fi environment, but it cannot be downloaded here unless the pack is acquired. Confirm the marketplace license and mobile redistribution terms before use.

## Candidate C — OpenGameArt “Sci-fi environment pack” (free listing, not yet verified locally)

The [OpenGameArt page](https://opengameart.org/content/sci-fi-environment-pack) lists a 185 MB ZIP, PBR sci-fi environment assets, and CC0. It is not listed as a ready-to-use GLB pack. The ZIP was not downloaded in this environment, so file formats, per-file contents, import quality, and practical license/provenance details still need an audit before it can be recommended or shipped.

## Screened out

- **Polygonal Mind “aero-system”**: a real CC0 GitHub GLB collection with a station, airship, doors, paths, and pads. Preview inspection shows a chunky, strongly stylized/neon look; it does not meet the requested more-realistic direction, so it is not proposed for integration.
- **Khronos “DamagedHelmet” sample**: visually detailed, but its model license documents both CC-BY-4.0 and CC-BY-NC-4.0 provenance for the original asset. Avoid it for this game unless the rights holder clarifies commercial rights.

## Decision needed before scene integration

1. **Free NASA props:** approve only the Habitat pair (or Rover after an optimization plan), accepting the NASA-specific visual identity.
2. **Paid cohesive environment:** acquire the Asset Smash Space Base pack and provide the archive; then verify its license, GLB imports, scale, collision needs, and Android cost before integration.
3. **Continue free-only research:** keep the world blockout unchanged and search for another downloadable CC0/CC-BY modular sci-fi kit; no NASA or Kenney candidate is integrated.

No gameplay scenes or world components were changed during this research. Godot import/render and Android performance remain untested in this sandbox.
