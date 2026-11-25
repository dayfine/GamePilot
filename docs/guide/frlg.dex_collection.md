# Dex Collection

Catches wild Pokemon your Pokedex has not caught yet, toward the 60 Professor Oak asks for before
he gives you the National Pokedex.

So far it works one patch of grass: Route 10's, just north of its Pokemon Center, where Voltorb,
Spearow and Ekans live. It reads your Pokedex count off the Trainer Card before and after.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

- Save anywhere outdoors in Kanto: 01 flies to Indigo Plateau, then to Route 10's Pokemon Center,
  where 02 starts and ends at its nurse.
- Bring ¥12,000 for 10 Ultra Balls at the Indigo Plateau's Pokemon Center.

<!-- generated:needs -->
- a member knows fly (fly)
- the thunder badge (fly)
- money at least ¥12000 (all the purchases)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.dex_collection --from 01-ultra-balls --to 02-route10-new-species --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-ultra-balls | From anywhere outdoors: Ultra Balls at Indigo Plateau, then to Route 10's Pokemon Center |
| 02-route10-new-species | Route 10's north grass: catch two species the Pokedex has not caught, back to the nurse |

<!-- plans: a6dda378aabe -->
<!-- /generated -->

In the grass it runs from every Pokemon you have caught already and catches the ones you have not.
It tells them apart by the little Poke Ball the game draws next to a wild Pokemon's HP bar when its
kind is already caught.

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-ultra-balls | a member knows fly (fly); the thunder badge (fly); money at least ¥12000 (mart); at the start, anywhere outdoors where Fly works |
| 02-route10-new-species | ultra-ball at least x1 (capture); at the start, Route10_PokemonCenter_1F |
<!-- /generated -->

## Known limits

- One patch so far: once Voltorb, Spearow and Ekans are all caught, the catch checkpoint finds nothing
  new and stops out of encounters. Other routes come next.
- It never weakens a Pokemon before throwing: Ultra Balls catch these three often enough at full HP.
- With six in the party, catches go to Bill's PC; it never gives a nickname.

## How it works

The first usable slice of the collector in `docs/roadmap/frlg-dex-exclusives.md` (issue #15, step
5): wild catches, not shiny, toward the 60 caught the National Pokedex needs (Sevii checkpoint 07,
`docs/roadmap/frlg-sevii-islands.md`). Both checkpoints start and end at Route 10's nurse.

**A new species.** FireRed draws a Poke Ball on a wild foe's HP box when its species is caught
(`Frlg_readers.Caught_mark`), so the catch checkpoint never opens the Pokedex. It reads the count of
species caught off the Trainer Card (`read_caught`) before and after. On the Mail Glitch save (10
caught, Spearow among them), 02 catches Voltorb and Ekans: 12 caught.

**Next.**

- More routes, one checkpoint each from a Center with its map in PokemonSimulation: Routes 24 and
  25 from Cerulean (Weedle, Caterpie, Kakuna, Metapod; Cerulean's two wandering NPCs need a route
  around them), Route 8 from Lavender (Meowth, Growlithe, Ekans; behind Cut trees), Routes 12 to 15
  (Venonat, Gloom, Ditto, Pidgeotto). Celadon's Center has no map yet.
- A `caught` postcondition and precondition (the Trainer Card's count), so Sevii 07 can require 60,
  and a repeat round that runs until it holds.
- The Pokedex list reader and navigation, the catalog and the planner of the roadmap's collector.
