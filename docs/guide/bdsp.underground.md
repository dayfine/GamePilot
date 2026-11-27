# Grand Underground

Farms Mysterious Shards in the Grand Underground in *Pokémon Brilliant Diamond* / *Shining Pearl*
for Ramanas Park slates. Starts from anywhere outdoors (or already inside the Underground), dives
into the Central Grassland Cave corridor, bounces through a Pokémon Hideaway doorway to respawn
sparkling dig spots, locks onto walls with radar blob-diffing, plays the 13×10 mining minigame
with a live vision-driven solver, auto-saves progress, and leaves the Underground when finished.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

<!-- needs: bdsp.underground has no checkpoints -->

- Load a post-game BDSP save with the National Pokédex and Fly unlocked.
- Register the **Explorer Kit** on **Down** of the `+` shortcut wheel (used when starting
  outdoors).
- Stand anywhere outdoors (the program will fly to Oreburgh City, dive offline via `Play Alone`,
  and home to the South Hideaway doorway), or already inside the Grand Underground outside the
  Central Grassland Cave Hideaway doorway.

## Options

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `mode` | farm \| check-bag \| check-map \| step-refresh \| step-read-map \| step-route-one \| step-dig-one | default `farm` | farm: full Grand Underground shard loop; check-bag: inspect Treasures pocket; check-map: capture full-sized map (Y -> A); step-refresh / step-read-map / step-route-one / step-dig-one: isolated single-step verification modes. |
| `door` | south \| north | default `south` | Starting Hideaway doorway for step-route-one (south or north). |
| `cycles` | 1 to 999 | default `15` | Number of Hideaway doorway-refresh cycles to run in farm mode. |
| `slates` | 1 to 99 | default `14` | Ramanas Park slate budget (1 Shard L or 3 Shard S per slate); stops once reached. |
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
cd src && opam exec -- dune exec -- gamepilot run bdsp.underground
```
<!-- /generated -->

To run with the live Watch Page (including the live **Counters** card) on a Switch console:

```sh
cd src && opam exec -- dune exec -- gamepilot run bdsp.underground \
  --watch --console --backend switch --serial /dev/cu.usbmodem... --capture 0
```

## What happens

<!-- checkpoints: bdsp.underground has no checkpoints -->

1. **Startup transit:** Checks `Underground_screen.in_underground` (the Diglett `XX/40` HUD). If
   outdoors, flies to Oreburgh City (`Bdsp_actions.Fly`), dives offline via the Explorer Kit on
   `+ -> Down`, and homes (`N -> E -> S -> W`) to the South Hideaway doorway.
2. **Doorway refresh:** Bounces through the Hideaway doorway (`West` → `East`, with automatic
   re-homing if drifted) to respawn all nearby dig spots without triggering wild encounters.
3. **Map routing & wall-lock:** Opens the full map (`Y -> A`) to plan stops around the ring
   corridor, walks to each stop, pulses `[R]` radar, and locks onto the sparkling wall via
   `Wall_sparkle` blob-diffing and `Wall_lock` servo steps (escaping any wild battle via
   `Battle_detector`).
4. **Vision-driven mining:** Reads the 13×10 wall through `Bdsp_readers.Mining_grid` and runs
   `Mining_solver.decide`: Hammer coverage scan with full-wall greedy fallback, Pickaxe excavation
   once a pink Mysterious Shard appears, and fast bail when no shards are found.
5. **Yield accounting & auto-save:** Classifies spotlight items with `Dig_result_reader`
   (distinguishing Shard S, Shard L, spheres, stones, fossils, and boxes), updates live
   `watch.counters`, and saves via `Bdsp_actions.Save_game` every 3 cycles and after any shard.

## When it stops

<!-- preflight: bdsp.underground has no checkpoints -->

Stops as soon as either the configured `slates` budget (`shard_L + shard_S / 3 >= slates`) or the
`cycles` limit is reached, performs a final save, exits the Grand Underground back outdoors
(`Y -> Down -> A -> A`), and prints the final counter summary.

## Known limits

- Starting outdoors expects the Explorer Kit on **Down** of the `+` shortcut wheel and assumes the
  Town Map cursor can be clamped to top-left without an open tutorial/overlay.
- Yield counting classifies end-of-dig spotlight icons by calibrated color/area thresholds rather
  than text OCR, so it tallies Mysterious Shard S, Mysterious Shard L, spheres, stones, fossils,
  and boxes accurately without reading individual item names.
