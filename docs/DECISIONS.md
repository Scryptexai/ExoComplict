# Decisions

The rules this project has paid for, and the reasoning that keeps them. One
file, because the alternative — nine dated audit and verification reports, four
of which contradicted each other by the end — is how a rule gets re-litigated
six months later by someone reading a stale one.

Everything here was measured against a real build (a headless Godot run, a
captured frame, or a reference lobby at a stated resolution). Anything that was
only an opinion is not here.

## 1. Architecture

1. **`FrontEnd` is the only place that knows the journey.** Stages ask for the
   next one by name; `FrontEnd` decides whether that is legal. Journey:
   `STUDIO → BOOT → LOADING → CHAPTER → DASHBOARD → HERO → WORLD → PRELOAD →
   gameplay`.
2. **There is no WEAPON stage.** It was three weapon chips around a 3D rifle:
   a section of a loadout, not a page. The rail lives on `HERO`, next to the
   operative who carries it.
3. **Data comes from the registries.** `HeroDefinition`, `WeaponDefinition` and
   `WorldDefinition` own names, prices, models and stats. A screen that prints a
   literal where a definition exists is a screen that will lie the first time
   the definition is tuned — `tests/data_source_smoke.gd` walks the rendered
   text and compares it with the resource.
4. **Content the project does not ship is disabled, not faked.** Placeholder
   slots say `IN DEVELOPMENT`, are never selectable, and never hand an id to a
   loader.
5. **A stage owns its layout and nothing else.** Saved state belongs to
   `ProgressionService`; a stage reads it on entry and on `profile_changed`.

## 2. Layout rules, in physical pixels

6. **`Control.PRESET_BOTTOM_WIDE` pins the control's *top* to the bottom edge.**
   A dock authored with it drew entirely off-screen. Place a box with
   `BoxContainer.ALIGNMENT_END` inside a full-rect host instead.
7. **A container inside a plain `Control` keeps whatever rect it was last
   given.** Manual placement re-read a stale minimum even with a deferred
   re-run; container hosts the engine lays out itself are the reliable fix.
8. **A `Label`'s minimum width is its text width unless it wraps.** One such
   label stretches its whole row and pushes every sibling past the viewport —
   the 360 px top bar measured 706 px wide because of it.
9. **An ellipsised `AUTOWRAP_WORD_SMART` label collapses to its longest word**
   when the row is tight: a wallet chip drew as an empty 40 px box. Keep figures
   on one unwrapped line and put the width in `physical_min_size`.
10. **`SIZE_SHRINK_CENTER` on a panel inside a `VBox` collapses it to a sliver.**
    Use `SIZE_EXPAND_FILL`.
11. **Everything is authored in physical pixels** (`MenuStage.px()`,
    `physical_min_size()`, `physical_separation()`) and re-authored on resize,
    because the canvas is letterboxed and a phone is not a small desktop.
12. **Portrait is a first-class layout, not a squeezed landscape.** Both are
    built, both are photographed, both are asserted.
13. **The primary action is the bottom row** — nearest the thumb — which is the
    order Apex's READY bar and Free Fire's start tile use. Tabs sit above it.

## 3. Art and type

14. **Chakra Petch for display, Rajdhani for the interface.** Both are squared,
    condensed, and built for uppercase rows; mixing a geometric face with a
    humanist one is what made the old menus read as a form.
15. **Minimum 16 physical pixels for supporting text, 64 for a touch target.**
    Measured against CoD Mobile (body 22 px at 1568×882), Apex (26 px), Free
    Fire (tabs 15 px, START ≈ 13 % of screen height).
16. **Never pure black or pure white**; the palette lives in `AegisTokens` and
    nothing hard-codes a colour.
17. **The character is the subject.** A lobby gives the operative the centre and
    a band that is a share of the screen (a phone 24–42 %, a desktop ~42 %), not
    the space the cards left over.

## 4. QA

18. **Every visual claim is a captured frame.** `tools/qa_flow_shots.mjs` walks
    the real stages from the committed payload and writes image statistics per
    frame, so a blank capture is visible instead of being a file that exists.
19. **A screenshot without the stage log is not a screenshot of that stage.**
    The tool refuses to file one that way.
20. **The smoke suite runs at four sizes** — 1280×720, 390×844, 360×640,
    844×390 — and asserts that every control is inside the viewport, that copy
    stays inside its own card, and that the journey's order holds.
21. **Renaming a field the tests read by name fails as a *layout* failure.**
    Grep `tests/` for `get("_…")` before renaming anything on a stage.
22. **`data_source_smoke.gd` scans screen *sources* for registry strings**, so a
    registry name inside a comment fails the build.
