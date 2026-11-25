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

- Save anywhere outdoors in Kanto: 01 flies to Indigo Plateau for Ultra Balls, then to Route 10's
  Pokemon Center; each catch starts and ends outdoors.
- Bring ¥12,000 for 10 Ultra Balls at the Indigo Plateau's Pokemon Center.
- The party's last Pokemon must know Sweet Scent, the game's sound must be Mono and its button
  mode Help, as [Wild RNG](frlg.wild_rng.md) says. Its plans hold your trainer ID and secret ID.
- 02 starts with a full party and stores one member to make room; from then on each catch joins
  as the sixth member, is checked for the shiny star and goes to the PC.

<!-- generated:needs -->
- 3 free party slots (joining: voltorb in 02-shiny-voltorb, ekans in 03-shiny-ekans, drowzee in 04-shiny-drowzee)
- rattata in the party (pc_deposit)
- rattata holds no Mail (pc_deposit)
- a member knows fly (fly)
- the thunder badge (fly)
- money at least ¥12000 (all the purchases)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.dex_collection --from 01-ultra-balls --to 04-shiny-drowzee --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-ultra-balls | From anywhere outdoors: Ultra Balls at Indigo Plateau, then out of Route 10's Pokemon Center |
| 02-shiny-voltorb | From anywhere outdoors: a shiny Voltorb in Route 10's grass by the wild RNG, stored in the PC, back to the nurse |
| 03-shiny-ekans | From anywhere outdoors: a shiny Ekans in Route 10's grass by the wild RNG, stored in the PC, back to the nurse |
| 04-shiny-drowzee | From anywhere outdoors: a shiny Drowzee in Route 11's grass by the wild RNG, stored in the PC, back to the nurse |

<!-- plans: 1ce8a54de339 -->
<!-- /generated -->


## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-ultra-balls | a member knows fly (fly); the thunder badge (fly); money at least ¥12000 (mart); at the start, anywhere outdoors where Fly works |
| 02-shiny-voltorb | rattata in the party (pc_deposit); rattata holds no Mail (pc_deposit); a member knows fly (fly); the thunder badge (fly); ultra-ball at least x1 (wild_rng); at the start, anywhere outdoors where Fly works |
| 03-shiny-ekans | a member knows fly (fly); the thunder badge (fly); ultra-ball at least x1 (wild_rng); at the start, anywhere outdoors where Fly works |
| 04-shiny-drowzee | a member knows fly (fly); the thunder badge (fly); ultra-ball at least x1 (wild_rng); at the start, anywhere outdoors where Fly works |
<!-- /generated -->

## Known limits

- mGBA only, and only from the save this program was measured on (the end of the Sevii story).
  On mGBA a save boots a few timer counts sooner or later depending on how many times the game
  has been saved, so each catch's plan holds a `seed_offset` measured for its own grass save in
  this chain. Started from another save, a catch misses: the checkpoint fails before saving
  (`wild_rng_not_shiny`).
- Three species so far, in grass only. Fishing, surfing, static encounters and gifts come later.
- A catch already in the Pokedex is not skipped yet: it is caught again, shiny.
- It never weakens a Pokemon before throwing: Ultra Balls catch these three often enough at full HP.

## How it works

Each catch is the `wild_rng` action ([Wild RNG](frlg.wild_rng.md)) on the seed table
`src/games/frlg/assets/rng_seeds_mgba_sevii_save.json`, measured on mGBA from the Sevii story's
end save, plus the plan's `seed_offset`. On mGBA the seed a title-screen press gives depends a
little on the save the game boots from: by where the last save left the flash sectors (the save
count modulo 14), the boot ends 0, 4, 8 or 12 timer counts later, and every seed moves with it.

Each catch saves twice (in the grass, then the catch), so in this chain the grass saves are the
save file's 139th, 141st and 143rd, which add 8, 4 and 4. Each offset was measured from the
checkpoint's own state before the reset: the seed a press 1801 frames after the reset gives,
against the table's.

The plain catches of the first version of this program (catch whatever the Pokedex lacks, run
from the rest) are gone: every catch toward the 60 is to be shiny (issue #14).
