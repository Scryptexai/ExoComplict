#!/usr/bin/env python3
"""Author the small feathered muzzle-glint mask used by Godot's billboard.

The soft core and three forward-biased rays are deliberately asymmetric. In a
390px real-shot WebGL screenshot a solid conical mesh became a cyan shield over
the hero; shrinking that mesh alone made the discharge vanish. This alpha mask
keeps a visible hot centre without a hard-edged slab or a crosshair-like cross.
"""

from math import exp, hypot
from pathlib import Path

from PIL import Image

SIZE = 128
OUT = Path(__file__).resolve().parents[1] / "game/assets/vfx/muzzle_glint.png"


def ray(x: float, y: float, direction: tuple[float, float], width: float, length: float) -> float:
    forward = x * direction[0] + y * direction[1]
    sideways = -x * direction[1] + y * direction[0]
    if forward < -5 or forward > length:
        return 0.0
    return exp(-0.5 * (sideways / width) ** 2) * exp(-0.5 * (forward / length) ** 2)


def main() -> None:
    mask = Image.new("RGBA", (SIZE, SIZE))
    pixels = mask.load()
    for y in range(SIZE):
        for x in range(SIZE):
            u, v = x - 64.0, y - 64.0
            core = 0.95 * exp(-0.5 * (hypot(u, v) / 9.0) ** 2)
            glow = 0.20 * exp(-0.5 * (hypot(u, v) / 26.0) ** 2)
            lead = 0.66 * ray(u, v, (0.73, -0.68), 4.1, 49.0)
            upper = 0.40 * ray(u, v, (0.92, -0.39), 3.0, 30.0)
            lower = 0.26 * ray(u, v, (0.32, -0.95), 2.8, 24.0)
            alpha = int(255 * min(1.0, core + glow + lead + upper + lower))
            pixels[x, y] = (255, 255, 255, alpha if alpha > 2 else 0)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    mask.save(OUT, optimize=True)
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
