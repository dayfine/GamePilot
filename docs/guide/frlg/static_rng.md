# Static RNG

Catches a shiny static overworld Pokémon (such as Zapdos, Articuno, Moltres, Mewtwo, Electrode, or
Snorlax) by timing the game's random numbers. On each attempt, it resets the game, presses A on the
title screen to land on a known initial seed, holds the Start menu open for the remaining in-game
wait so overworld boulders do not add extra RNG advances, closes the menu, and talks to the static
Pokémon.

It checks the battle intro visually to reset immediately on a non-shiny miss, catches the shiny
using the Phase 1 catch policy, confirms the shiny star on Summary, and saves the game.

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## Before you start

Save standing directly facing the static overworld Pokémon, with at least one free party slot and
your game options set to **Mono** sound and **Help** button mode.

Stock the Poké Ball you want to throw (default `luxury-ball`, up to 99 per attempt) and a Phase 1
catching party (status setter, False Swipe / chip support, and wall).

Give your trainer ID (TID) and secret ID (SID) via `--options tid=N --options sid=N`, or set
`GAMEPILOT_FRLG_TID` and `GAMEPILOT_FRLG_SID`, or store `{"tid": N, "sid": N}` in
`trainer_ids.json` under the local FRLG config directory (`GAMEPILOT_FRLG_CONFIG`, defaulting to
`~/.local/share/gamepilot/frlg`). `--options` overrides the environment variables, which override
`trainer_ids.json`.

<!-- generated:needs -->
- 1 free party slot (joining: zapdos in 01-static-rng)
- luxury-ball at least x99 (static_rng)
<!-- /generated -->

## Running it

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `ball` | poke-ball \| great-ball \| ultra-ball \| luxury-ball | default `luxury-ball` | the ball to throw when catching the shiny static encounter |
| `balls` | 1 to 999 | default `99` | max balls to throw per catch attempt |
| `tid` | 0 to 65535 | optional | your trainer ID (overrides GAMEPILOT_FRLG_TID and trainer_ids.json) |
| `sid` | 0 to 65535 | optional | your secret ID (overrides GAMEPILOT_FRLG_SID and trainer_ids.json) |
<!-- /generated -->

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.static_rng --from 01-static-rng --to 01-static-rng --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh frlg.static_rng --from 01-static-rng --to 01-static-rng --preflight-only
sh run/run_checkpoints_on_switch.sh frlg.static_rng --from 01-static-rng --to 01-static-rng
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-static-rng | In front of a static overworld Pokemon: hard reset timed for a shiny Method 1 encounter, visual shiny check, catch, summary star check, saved |

<!-- plans: 375ccb778356 -->
<!-- /generated -->

1. **Target search:** Reads the seed table (`rng_seeds_mgba_sevii_save.json`), applies any
   persisted Switch per-console calibration when running on the Switch, and finds the earliest
   shiny Method 1 advance between 900 and 4000 for your TID and SID.
2. **Timed reset and encounter:** Hard-resets, presses A on the title screen at the target seed
   delay, loads the save, opens the Start menu to freeze overworld RNG while waiting out the
   in-game delay, closes the menu, and presses A to trigger the encounter.
3. **Visual shiny check and catch:** Watches the battle-intro timing with
   `Shiny_encounter_detector`. On a visual miss, resets immediately without throwing balls (up to
   25 attempts). On a shiny, runs the Phase 1 catch policy, confirms the shiny star on the
   caught Pokémon's Summary screen, and saves the game.

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-static-rng | luxury-ball at least x99 (static_rng) |
<!-- /generated -->

- **Shiny caught and saved:** Succeeds once the catch is confirmed shiny on Summary and saved.
- **Attempts exhausted or catch paused:** Fails before saving (`static_rng_not_shiny_intro`,
  `static_rng_not_shiny`, or `static_rng_catch_paused`), leaving your original save intact.

## Known limits

- Detection during battle is visual-only (intro timing without audio), so a false positive is
  caught by the Summary shiny-star check before saving.
- On Switch, console boot and in-game timing offsets depend on your console's calibration entry;
  run calibration if attempts consistently miss the target seed or advance.
- Plan-level parameters (`species`, `attempts`, `catch_mode`, `boot_offset_ms`, `ingame_offset`,
  `visual_shiny_check`) are configured in `01-static-rng.plan.json`; `--options` currently
  overrides `ball`, `balls`, `tid`, and `sid`.

## How it works

Uses the `static_rng` game action (`src/games/pokemon/frlg/actions/lib/static_rng.ml`), ported from
PA/CC's `PokemonFRLG_StaticRng` and `PokemonFRLG_BlindNavigation`, followed by `save_game`.
