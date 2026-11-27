# Dex Collection

Catches wild Pokemon your Pokedex has not caught yet, toward the 60 Professor Oak asks for before
he gives you the National Pokedex, and every catch is shiny: each one is timed with the wild RNG
of [Wild RNG](frlg.wild_rng.md), so the Pokemon Sweet Scent brings out is a shiny one chosen in
advance.

So far: a shiny Voltorb and a shiny Ekans in Route 10's grass, and a shiny Drowzee in Route 11's.
Each catch flies to its route, saves in the grass, restarts the game at the timed moment, catches
the shiny with Ultra Balls, saves it, stores it in the Pokemon Center's PC and heals at the nurse.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

- Save anywhere outdoors in Kanto: 01 flies to Indigo Plateau for Ultra Balls and ends outside its
  Center; each catch starts and ends outdoors.
- Bring ¥24,000 for 20 Ultra Balls at the Indigo Plateau's Pokemon Center.
- The party's last Pokemon must know Sweet Scent, the game's sound must be Mono and its button
  mode Help, as [Wild RNG](frlg.wild_rng.md) says. Supply your trainer ID and secret ID via
  `--options tid=N --options sid=N`, `GAMEPILOT_FRLG_TID` / `GAMEPILOT_FRLG_SID`, or
  `trainer_ids.json` in your local FRLG config directory.
- 02 starts with a full party and stores one member to make room; from then on each catch joins
  as the sixth member, is checked for the shiny star and goes to the PC.

<!-- generated:needs -->
- a member holds no Mail (pc_deposit)
- a member knows fly (fly)
- the thunder badge (fly)
- money at least ¥24000 (all the purchases)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

## Running it

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `ball` | poke-ball \| great-ball \| ultra-ball \| luxury-ball | optional | the ball to throw (overrides each catch plan's default) |
| `balls` | 1 to 999 | optional | max balls to throw per catch attempt (overrides plan default) |
| `target` | everything \| missing-on-dex \| version-exclusive \| version-exclusive-uncaught \| specific-list | default `everything` | which species to catch (everything and missing-on-dex skip species recorded in local dex_progress.json) |
| `species` | text | optional | comma-separated species slugs for target=specific-list (e.g. ekans,voltorb) |
| `tid` | 0 to 65535 | optional | your trainer ID (overrides GAMEPILOT_FRLG_TID and trainer_ids.json) |
| `sid` | 0 to 65535 | optional | your secret ID (overrides GAMEPILOT_FRLG_SID and trainer_ids.json) |
<!-- /generated -->

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.dex_collection --from 01-ultra-balls --to 04-shiny-ekans --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-ultra-balls | From anywhere outdoors: Ultra Balls at Indigo Plateau, healed, outdoors |
| 02-shiny-voltorb | From anywhere outdoors: a shiny Voltorb in Route 10's grass by the wild RNG, stored in the PC, back to the nurse |
| 03-shiny-drowzee | From anywhere outdoors: a shiny Drowzee in Route 11's grass by the wild RNG, stored in the PC, back to the nurse |
| 04-shiny-ekans | From anywhere outdoors: a shiny Ekans in Route 10's grass by the wild RNG, stored in the PC, back to the nurse |

<!-- plans: b4a62405fce3 -->
<!-- /generated -->


## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-ultra-balls | a member knows fly (fly); the thunder badge (fly); money at least ¥24000 (mart); at the start, anywhere outdoors where Fly works |
| 02-shiny-voltorb | a member holds no Mail (pc_deposit); a member knows fly (fly); the thunder badge (fly); ultra-ball at least x1 (wild_rng); at the start, anywhere outdoors where Fly works |
| 03-shiny-drowzee | a member knows fly (fly); the thunder badge (fly); ultra-ball at least x1 (wild_rng); at the start, anywhere outdoors where Fly works |
| 04-shiny-ekans | a member knows fly (fly); the thunder badge (fly); ultra-ball at least x1 (wild_rng); at the start, anywhere outdoors where Fly works |
<!-- /generated -->

## Known limits

- mGBA only, and only from the save this program was measured on (the end of the Sevii story).
  On mGBA a save boots a few timer counts sooner or later depending on how many times the game
  has been saved, so each catch's plan holds a `seed_shift` measured for its own grass save in
  this chain. Started from another save, a catch misses: the checkpoint fails before saving
  (`wild_rng_not_shiny`).
- Three species so far, in grass only. Fishing, surfing, static encounters and gifts come later.
- A catch started where its Fly lands (outside that route's Center) fails at once: Fly to the town
  the player stands in lands where it took off, which the fly action takes for no landing. The
  order of the checkpoints never flies twice in a row to one town.
- A catch already recorded in local progress (`dex_progress.json` under `GAMEPILOT_FRLG_CONFIG`,
  defaulting to `~/.local/share/gamepilot/frlg`) is skipped under `target=everything`,
  `target=missing-on-dex`, and `target=version-exclusive-uncaught`. Use `target=version-exclusive`
  or `target=specific-list --options species=...` to target specific species regardless of local
  progress.
- Ball choice (`--options ball=...` and `--options balls=...`) overrides the ball thrown during
  catches; `01-ultra-balls` still buys Ultra Balls at Indigo Plateau (start from `02-shiny-voltorb`
  if you bring your own Poké Balls or Great Balls).
- It never weakens a Pokemon before throwing: Ultra Balls catch these three often enough at full HP.

## How it works

The first slice of the collector in `docs/roadmap/frlg-dex-exclusives.md` (issue #15, step 5),
every catch shiny (issue #14), toward the 60 caught the National Pokedex needs (Sevii checkpoint 07,
`docs/roadmap/frlg-sevii-islands.md`).

Each catch is the `wild_rng` action ([Wild RNG](frlg.wild_rng.md)) on the seed table
`src/games/pokemon/frlg/assets/rng_seeds_mgba_sevii_save.json`, measured on mGBA from the Sevii story's
end save, plus the plan's `seed_shift`. On mGBA the seed a title-screen press gives depends a
little on the save the game boots from: by where the last save left the flash sectors (the save
count modulo 14), the boot ends 0, 4, 8 or 12 timer counts later, and every seed moves with it.

Each catch saves twice (in the grass, then the catch), so in this chain the grass saves are the
save file's 139th, 141st and 143rd, which add 8, 4 and 4. Each offset was measured from the
checkpoint's own state before the reset: the seed a press 1801 frames after the reset gives,
against the table's.

The waits can still land a few advances off the target: the overworld's RNG does not advance
exactly once a frame (Route 11's walkers draw on it too). So a plan also holds the fork's
`ingame_offset` calibration, found by replaying its presses on the grass save with an RNG trace in
the lab: -1 for Voltorb, -3 for Drowzee, +1 for Ekans.

The plain catches of the first version of this program (catch whatever the Pokedex lacks, run
from the rest) are gone: every catch toward the 60 is to be shiny.

**Next.**

- More grass routes, one checkpoint each from a Center with its map in PokemonSimulation: Route 22
  (Mankey), Routes 24 and 25 (Weedle, Caterpie), Route 8 (Meowth, Growlithe; behind a Cut tree),
  Routes 12 to 15 (Venonat, Ditto). Each needs its `seed_shift` and `ingame_offset` measured.
- A seed calibration from a miss, as the fork calibrates, so a plan needs no measured offsets.
- A `caught` precondition (the Trainer Card's count), so Sevii 07 can require 60.
