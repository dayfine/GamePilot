# Static Legendary RNG

Hunts shiny static legendaries in Pokémon Brilliant Diamond and Shining Pearl using eye-blink RNG
manipulation (Workflow A): quiet-room `0PK` pedestal player-blink seed recovery, slate insertion,
in-chamber `1PK` re-identification, timed encounter triggers, and visual shiny detection.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

- Save in front of the **empty Ramanas Park pedestal** (before inserting the slate), facing South
  toward the camera, with the required slate in your Bag and a **Bike** registered on the `+`
  wheel's Right slot (used to pop up Rowan's dialog and freeze idle head fidgets).
- Stock Poké Balls and status or False Swipe support in your party so you can catch the shiny
  once the program stops on the battle screen.
- Provide the player open-eye PNG template via `GAMEPILOT_BDSP_PLAYER_EYE_PNG` (or place it at
  `src/games/pokemon/bdsp/assets/player_eye.png`).
- Start with the game already loaded at the saved empty pedestal.

## Options

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `target` | kyogre \| groudon \| rayquaza \| ho-oh \| lugia \| mewtwo \| regirock \| regice \| registeel \| articuno \| zapdos \| moltres \| raikou \| entei \| suicune \| latios \| latias \| dialga \| palkia \| uxie \| azelf \| giratina \| heatran \| regigigas \| darkrai \| arceus \| rotom | default `kyogre` | Static legendary target species slug from Static_targets.all. |
| `shiny` | any \| star \| square \| include_non_shiny | default `any` | Required shiny class: any, star, square, or include_non_shiny (accept non-shiny for calibration). |
| `delay_ms` | -5000 to 5000 | default `200` | Calibration offset in ms added to the timed encounter confirm press. |
| `max_attempts` | 1 to 999 | default `20` | Maximum soft-reset attempts before stopping. |
| `seed_timeout_s` | 60 to 3600 | default `600` | Maximum seconds to wait for 0PK pedestal seed recovery per attempt. |
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run bdsp.static_rng --from 01-static-rng --to 01-static-rng --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

Example targeting a shiny Groudon with a calibrated `delay_ms` offset on a Switch console:

```sh
cd src && opam exec -- dune exec -- gamepilot run bdsp.static_rng \
  --watch --console --backend switch --serial /dev/cu.usbmodem... --capture 0 \
  --options target=groudon --options shiny=any --options delay_ms=200
```

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-static-rng | Hunt a shiny static legendary with eye-blink RNG |

<!-- plans: 0cab37d3f7ce -->
<!-- /generated -->

1. **Pedestal seed recovery (`0PK`):** Opens the Bike dialog (`+` → `Right`) to freeze idle head
   fidgets and watches player eye blinks with `Pedestal_seed_finder` (`Blink_recovery`, `npcs = 1`)
   until the 128-bit `Xorshift128` seed is uniquely confirmed (~4 minutes / ~45 blinks).
2. **Insert slate and enter chamber:** Dismisses the dialog, turns North, inserts the slate, enters
   the Mystery Space, walks up to the legendary, turns South, and re-freezes with the Bike dialog.
3. **In-chamber `1PK` re-identification:** Tracks player eye blinks via `In_chamber_reidentifier`
   under the 1-player + 1-Pokémon-model timeline to lock the exact advance anchor (~60–90 seconds).
4. **Target search and timed trigger:** Dismisses the dialog, turns North to face the legendary,
   searches forward with `Static_rng_trigger` for the earliest reachable shiny advance matching
   `target` and `shiny`, opens the cry dialog, and fires the final confirm press at the
   exact daemon timestamp via `submit_at`.
5. **Visual shiny detection and retry:** Watches battle-dialog timing with
   `Shiny_encounter_detector` (waiting through weather banners such as Drizzle and Drought). On a
   shiny, stops immediately on the battle screen; on a miss, soft-resets via Switch HOME back to
   the saved empty pedestal and retries.

## When it stops

- **Shiny found:** Stops as soon as the battle menu appears with a shiny wild-animation timing
  verdict, leaving the Switch on the battle screen ready for you to catch the Pokémon.
- **Exhausted:** Stops after `max_attempts` soft-reset cycles without a confirmed shiny (or if a
  Switch HOME soft-reset fails), printing the last miss reason.

## Known limits

- Detection is visual-only (battle-dialog timing without audio), so it confirms shininess without
  distinguishing star vs. square sparkles on screen; use `--options shiny=star` or `square` to
  filter the RNG search itself.
- Live `delay_ms` calibration varies slightly by capture card and console latency; tune
  `--options delay_ms=<ms>` if encounters consistently land a few advances early or late.

## How it works

Orchestrates `Bdsp_static_rng.Pedestal_seed_finder`, `Bdsp_blink_rng.In_chamber_reidentifier`,
`Bdsp_blink_rng.Static_rng_trigger`, and `Bdsp_readers.Shiny_encounter_detector` through
`Bdsp_static_rng.Static_rng_workflow`. See `docs/design/BDSP-Static-Legendary-RNG.md` for the
`0PK -> 1PK` timeline math and calibration procedure.
