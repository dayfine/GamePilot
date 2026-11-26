# Underground PoC

Farms the Grand Underground in *Pokémon Brilliant Diamond* / *Shining Pearl* by anchoring at a
Pokémon Hideaway doorway, bouncing in and out to instantly respawn sparkling wall dig spots,
sweeping adjacent walls, and playing the 13×10 mining minigame with a live vision-driven solver
targeting Mysterious Shards for Ramanas Park slates.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

<!-- needs: bdsp.underground_poc has no checkpoints -->

- Load a post-game BDSP save with the National Pokédex and enter the Grand Underground offline
  (`Play Alone`, row 2 of the Explorer Kit mode menu).
- Stand outside a Pokémon Hideaway doorway adjacent to an L-shaped corridor (for example, the
  South-East corridor of the central Hideaway).

## Options

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `mode` | farm \| check-bag | default `farm` | farm: run the Grand Underground shard loop; check-bag: open Bag pockets to inspect shard and slate counts. |
| `cycles` | 1 to 999 | default `15` | Number of Hideaway doorway-refresh cycles to run in farm mode. |
| `slates` | 1 to 99 | default `14` | Ramanas Park slate budget (1 Shard L or 3 Shard S per slate); stops once reached. |
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
cd src && opam exec -- dune exec -- gamepilot run bdsp.underground_poc
```
<!-- /generated -->

To run with the live Watch Page on a Switch console:

```sh
cd src && opam exec -- dune exec -- gamepilot run bdsp.underground_poc \
  --watch --console --backend switch --serial /dev/cu.usbmodem... --capture 0
```

## What happens

<!-- checkpoints: bdsp.underground_poc has no checkpoints -->

Each cycle:

1. Bounces through the Hideaway doorway (`West` → `East`, with a perpendicular 1-tile auto-centering
   nudge if off-center) to refresh all nearby dig spots without triggering wild Pokémon encounters.
2. Hugs the North wall and sweeps East toward the corner, then hugs the East wall and sweeps North,
   checking for sparkling walls (and escaping any unexpected wild battle via `Battle_detector`).
3. When a dig prompt appears, waits for the 13×10 wall to load, reads all 130 cells via
   `Bdsp_readers.Mining_grid` (masking the cursor sprite), and runs `Mining_solver.decide`:
   coarse 3-tile-spaced Hammer scan, Pickaxe excavation when a pink Mysterious Shard appears, and
   fast-bail wall collapse when no shards are found.
4. Returns along the South and West walls to the Hideaway doorway for the next cycle.

## When it stops

<!-- preflight: bdsp.underground_poc has no checkpoints -->

Stops after completing its configured number of cycles (`total_cycles = 3` in the PoC) and prints
the cycle, dig, and bail counts.

## Known limits

- Does not yet OCR the end-of-dig item summary screen to count exact Mysterious Shard S/L totals
  against the 14-slate Ramanas Park goal (the `Mining_goal` tally model is ready for it).
- Assumes the player is already positioned outside a West-facing Hideaway doorway at an L-shaped
  corridor.
