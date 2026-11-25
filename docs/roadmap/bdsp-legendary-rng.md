# C. BDSP legendary RNG

Goal: shiny static legendaries in BDSP through the blink RNG, on GamePilot (the rest of slice S2).

## What is already covered (PRs #1-#4)

| PR | Covers |
|---|---|
| #1 | `docs/design/BDSP-RNG.md`: the starter RNG port (W1-W10), daemon every-frame probes, capture timestamps, `submit` at a time. It names legendaries as "the rest of S2", **not in that plan** |
| #2 | `src/games/bdsp/rng`: Xorshift128, static encounter generation, blink model |
| #3 | blink state solvers, blink extraction, the reidentifier |
| #4 | blink recovery, re-anchoring, the advance clock, hit calibration |

Everything here builds on those; nothing is repeated. The starter (W9) proves the loop first.

## Source plan

Fork PR #782, `docs/design/BDSP-Static-Legendary-RNG.md`, extends the starter RNG to every static:

- **Two workflows.** (A) Recover the state from the player's blinks in a quiet room one step before
  the chamber (Dialga/Palkia, the lake guardians, Giratina), then walk in on a timeline that counts
  the legendary model's blinks. (B) Recover the seed on the Munchlax intro screen at boot (the
  intro seed finder), load the save facing the legendary, reidentify the advance with one player and
  one Pokemon model (`1PK`), press on target (Ramanas Park after inserting a slate, Heatran,
  Regigigas, Darkrai, Arceus, roamers).
- **Why two.** 3D Pokemon models blink on an aperiodic timer; the periodic player-blink solver fails
  while one is on screen.
- **Fixes it found** in the C++ starter code: wrong levels and abilities in the target table,
  summary stat bounds for Lv 5 only, menu and party-slot assumptions, Synchronize not passed to the
  searcher.
- **Out of v1**: Shaymin (Flower Paradise advances the RNG about 279 times a second); roamers
  (Mesprit, Cresselia) need a separate flow because pressing A releases them instead of battling.
- **Stream History** must be off during blink sampling (a frame stall misreads a double blink).

## Steps (after W9 passes)

1. Target table for statics as data, with #782's corrections, checked against PokeFinder's generator.
2. `reidentify_with_pokemon_models` (`1PK`) in `src/games/bdsp/rng`, C++ as oracle once the fork has it.
3. Intro seed finder (Munchlax) as a program on the effects, replayed from recorded blinks.
4. Static press schedule (one confirm), separate from the starter's three-press timeline.
5. Per-target navigation; first target: one Ramanas Park slate (workflow B), then Dialga or Palkia
   (workflow A).

## Prerequisites

Post-game BDSP saves for each target; Ramanas Park slates come from D (Underground). W3-W8 of #1.

## Open questions

- Which targets first, and on which version?
- Does the C++ fork implement #782 first (as the oracle), or does GamePilot go first?
