# Static Legendary RNG

Hunts shiny static legendaries in Pokémon Brilliant Diamond and Shining Pearl using eye-blink RNG
manipulation (Workflow B): Munchlax boot-seed recovery, in-chamber 1PK re-identification, timed
encounter triggers, and visual shiny detection.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

- Save inside the Ramanas Park chamber (or Sinnoh static room) directly facing the target
  legendary, with a Synchronize lead in slot 1 if using `--options sync=...`.
- Stock Poké Balls and status or False Swipe support in your party so you can catch the shiny
  once the program stops on the battle screen.
- Provide the open-eye PNG templates via `GAMEPILOT_BDSP_MUNCHLAX_EYE_PNG` and
  `GAMEPILOT_BDSP_PLAYER_EYE_PNG` (or place them under `src/games/pokemon/bdsp/assets/`).
- Start the game on the Switch title/Munchlax intro screen (or at the Switch HOME menu ready to
  boot into the intro).

## Options

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `target` | kyogre \| groudon \| rayquaza \| ho-oh \| lugia \| mewtwo \| regirock \| regice \| registeel \| articuno \| zapdos \| moltres \| raikou \| entei \| suicune \| latios \| latias \| dialga \| palkia \| uxie \| azelf \| giratina \| heatran \| regigigas \| darkrai \| arceus \| rotom | default `kyogre` | Static legendary target species slug from Static_targets.all. |
| `shiny` | any \| star \| square | default `any` | Required shiny class: any, star, or square. |
| `delay_ms` | -5000 to 5000 | default `200` | Calibration offset in ms added to the timed encounter confirm press. |
| `sync` | hardy \| lonely \| brave \| adamant \| naughty \| bold \| docile \| relaxed \| impish \| lax \| timid \| hasty \| serious \| jolly \| naive \| modest \| mild \| quiet \| bashful \| rash \| calm \| gentle \| sassy \| careful \| quirky | optional | Optional Synchronize lead nature (omit if not using Synchronize). |
| `max_attempts` | 1 to 999 | default `20` | Maximum soft-reset attempts before stopping. |
| `munchlax_timeout_s` | 30 to 3600 | default `300` | Maximum seconds to wait for Munchlax boot-seed recovery per attempt. |
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run bdsp.static_rng --from 01-static-rng --to 01-static-rng --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

Example targeting a Modest shiny Kyogre with a calibrated `delay_ms` offset on a Switch console:

```sh
cd src && opam exec -- dune exec -- gamepilot run bdsp.static_rng \
  --watch --console --backend switch --serial /dev/cu.usbmodem... --capture 0 \
  --options target=kyogre --options shiny=any --options sync=modest --options delay_ms=200
```

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-static-rng | Hunt a shiny static legendary with eye-blink RNG |

<!-- plans: ba6da481a9e1 -->
<!-- /generated -->

1. **Boot seed recovery:** Watches Munchlax's eye blinks on the intro screen with
   `Munchlax_seed_finder` while renewing the input lease until the 128-bit `Xorshift128` boot
   seed is uniquely confirmed.
2. **Enter save:** Advances past the title screen into the overworld chamber where the player is
   already standing in front of the legendary.
3. **In-chamber 1PK re-identification:** Tracks player eye blinks via `In_chamber_reidentifier`
   under the 1-player + 1-Pokémon-model timeline to lock the current advance anchor.
4. **Target search and timed trigger:** Searches forward with `Static_rng_trigger` for the
   earliest reachable shiny advance matching `target`, `shiny`, and `sync`, opens the cry dialog,
   and fires the final confirm press at the exact daemon timestamp via `submit_at`.
5. **Visual shiny detection and retry:** Watches battle-dialog timing with
   `Shiny_encounter_detector` (waiting through weather banners such as Drizzle and Drought). On a
   shiny, stops immediately on the battle screen; on a miss, soft-resets via Switch HOME and
   retries.

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

Orchestrates `Bdsp_blink_rng.Munchlax_seed_finder`, `Bdsp_blink_rng.In_chamber_reidentifier`,
`Bdsp_blink_rng.Static_rng_trigger`, and `Bdsp_readers.Shiny_encounter_detector` through
`Bdsp_static_rng.Static_rng_workflow`. See `docs/design/BDSP-Static-Legendary-RNG.md` for the
1PK timeline math and calibration procedure.
