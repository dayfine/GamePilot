# C. BDSP legendary RNG

GamePilot will build shiny static legendary RNG as the rest of slice S2, tracked in
[issue #18](https://github.com/dayfine/GamePilot/issues/18). The
[fork design](../design/BDSP-Static-Legendary-RNG.md) is the reference for encounter mechanics and
save setup. GamePilot goes first, following the closure of
[dayfine/Arduino-Source#782](https://github.com/dayfine/Arduino-Source/pull/782).

## Current foundation

The [starter RNG design](../design/BDSP-RNG.md) defines the shared Switch capture, replay, and
timing work (W1–W10). Main has the pure OCaml [BDSP RNG library](../../src/games/pokemon/bdsp/rng)
and its C++ golden fixtures. The starter attempt loop and a registered BDSP program are still ahead.

| Landed | Reuse for statics |
|---|---|
| [#2](https://github.com/dayfine/GamePilot/pull/2) | Xorshift128, the blink model, and static generation and search. The generator and search already accept Synchronize. |
| [#3](https://github.com/dayfine/GamePilot/pull/3) | Blink extraction, the periodic player/NPC and aperiodic Pokémon blink solvers, and the reidentifier for periodic NPC blinks. Mixed player and Pokémon-model reidentification (`1PK`) is new work. |
| [#4](https://github.com/dayfine/GamePilot/pull/4) | Pure blink recovery, re-anchoring, the advance clock, and hit calibration. The stat calculation accepts a level and base stats. Hit identification currently generates with Synchronize off. |

The [Switch backend](../switch-bring-up.md) buffers captured frames and timestamps them after
each read. The protocol exposes their sequence numbers and
[ring gap counters](../../protocol/v1/README.md#methods).
Use those for capture health and replay. The BDSP timing measurements, eye template probe,
absolute-time input, and capture-gap handling still follow W3–W8 and W10 of the starter design.
The fork's Stream History diagnosis describes a C++ capture failure. On GamePilot, carry frame gaps
to blink extraction and replay so a missing dip can leave the blink type unknown.

## Encounter workflows

- **Quiet room (A).** Recover the state from player blinks before entering the chamber, then track
  the legendary model's aperiodic blinks on the room-entry timeline. This is the first approach for
  Dialga or Palkia and also applies to Uxie, Azelf, and Giratina. Rotom can use a direct trigger.
- **In-chamber save (B).** Recover the boot state from the Munchlax intro, load the save, and
  reidentify the advance with one player and one Pokémon model (`1PK`). This lets Ramanas Park
  start after the slate fixes the encounter species. Heatran, Regigigas, Darkrai, and Arceus can
  follow once their scenes and trigger timings are measured.

V1 covers static battles. Shaymin's Flower Paradise particle effects consume about 279 advances per
second, and Mesprit and Cresselia need a separate release flow. V1 excludes those three encounters.

## Steps after the starter (W9) passes

1. Add verified encounter data for the first targets. Check levels, ability roll counts,
   guaranteed IVs, and Synchronize against PokeFinder and the existing C++ vectors where they
   overlap. Treat blind delays in the fork design as starting values for console calibration.
2. Build the Munchlax capture and seed recovery flow on the game effects using the existing
   Pokémon blink solver. Replay recorded intro blinks before running it live.
3. Add mixed-model timeline simulation and `1PK` reidentification to the RNG library. Use
   deterministic simulated traces for unique, ambiguous, and missing matches, then check against
   recorded in-chamber blinks.
4. Add the static trigger scheduler and encounter readers. Pass the lead's Synchronize setting
   through search and hit identification, and verify summary reads at the encounter's level when
   catch calibration is enabled. Catch calibration defaults off and uses standard balls when
   enabled. A Master Ball is opt-in.
5. Validate one post-slate Ramanas Park encounter on the Switch with autosave off, then one
   Dialga or Palkia encounter to cover workflow A. Replay each workflow end to end and measure the
   hit offset before expanding the target list.

## Prerequisites

A passing starter loop (W9), a post-game BDSP save, and a matching slate for the first Ramanas Park
test. [Underground mining](bdsp-underground-mining.md) can supply slates for later runs.

## Open question

Which Ramanas Park encounter and game version should provide the first post-slate test save?
