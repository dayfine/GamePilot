# Dex Collection

Catches wild Pokemon your Pokedex has not caught yet, to raise its count toward the 60 that
Professor Oak asks for before he gives you the National Pokedex. So far it works one patch of grass:
Route 10's, just north of its Pokemon Center, where Voltorb, Spearow and Ekans live. It first buys 10
Ultra Balls at the Indigo Plateau's Pokemon Center (¥12,000), then walks into the grass, runs from
every Pokemon you have caught already and catches the ones you have not. It tells them apart by the
little Poke Ball the game draws next to a wild Pokemon's HP bar when its kind is already caught. It
reads your Pokedex count off the Trainer Card before and after. Both checkpoints start and end at
Route 10's Pokemon Center nurse, so fly there first.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

<!-- generated:needs -->
- pidgey in the party (fly)
- the thunder badge (fly)
- money at least ¥12000 (all the purchases)
- at the start, Route10_PokemonCenter_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.dex_collection --from 01-ultra-balls --to 02-route10-new-species --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-ultra-balls | From Route 10's Pokemon Center: Ultra Balls at Indigo Plateau, then back |
| 02-route10-new-species | Route 10's north grass: catch two species the Pokedex has not caught, back to the nurse |

<!-- plans: 3607e220ccc3 -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-ultra-balls | pidgey in the party (fly); the thunder badge (fly); money at least ¥12000 (mart); at the start, Route10_PokemonCenter_1F |
| 02-route10-new-species | ultra-ball at least x1 (capture); at the start, Route10_PokemonCenter_1F |
<!-- /generated -->

## Known limits

- One patch so far: once Voltorb, Spearow and Ekans are all caught, the catch checkpoint finds nothing
  new and stops out of encounters. Other routes come next.
- It never weakens a Pokemon before throwing: Ultra Balls catch these three often enough at full HP.
- With six in the party, catches go to Bill's PC; it never gives a nickname.
