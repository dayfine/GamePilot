# D. BDSP Underground mining

Goal: a program that digs in the Grand Underground until the save holds the items a legendary unlock
needs, then stops. No prior plan exists on the fork; this page is a first outline.

## What is known

- Fork PR #782 (C) needs Ramanas Park slates for most of its RNG targets, and Regigigas needs the
  three Regis in the party.
- That the Ramanas Park slates are traded for Mysterious Shards dug in the Grand Underground, and
  which shard each slate costs, is from memory of the game: **verify it** (Bulbapedia's Ramanas Park
  and Grand Underground pages) before writing any plan data.
- Upstream PA/CC has no Underground program for BDSP.

## Shape

A one-shot program `bdsp.underground_dig` in `src/games/bdsp/programs/`, Switch backend only:

1. **Enter**: from a known spot, open the Explorer Kit and go underground (menu and fade readers).
2. **Find a dig spot**: simplest first version is one cavern, a short fixed route, and a reader
   for the spot to dig at and the dig prompt.
3. **Dig**: the Gen 4 minigame is a grid of rock over buried items with a wall that cracks (check
   BDSP's version on the console). Read the grid,
   choose pickaxe or hammer per hit, stop before the wall collapses. A greedy policy on the read
   grid is enough to start; it can be simulated offline from recorded frames.
4. **Count**: read what was dug (result screen), keep a tally against the goal, leave and re-enter to
   respawn spots, save every N digs.
5. **Stop** when the goal (e.g. N of a shard) is met.

## Prerequisites

- A BDSP save with the Explorer Kit (story).
- BDSP readers shared with C (dialog, menus); the daemon Switch backend.

## Open questions

- The exact goal: which slates and how many shards, or also evolution stones and plates?
- Do spots respawn by leaving the Underground, by time, or by something else? Measure on the console.
- Is a dig grid reader feasible from the frames (item outlines under rock), or do we dig blind with
  a fixed pattern and accept the yield?
