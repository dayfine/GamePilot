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
- 0 free party slots
- pidgey in the party (fly)
- mr-mime in the party (party_swap)
- blastoise in the party (party_swap)
- pidgeot in the party (fly)
- a member knows cut (cut_tree)
- money at least ¥16000 (all the purchases)
- rare-candy at least x4 (give_bag_item)
- retro-mail at least x83 (duplicate_item)
- ultra-ball at least x4 (capture)
- at the start, Route10_PokemonCenter_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.dex_collection --from 01-ultra-balls --to 18-fuchsia-routes --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-ultra-balls | From Route 10's Pokemon Center: Ultra Balls at Indigo Plateau, then back |
| 02-route10-new-species | Route 10's north grass: catch two species the Pokedex has not caught, back to the nurse |
| 03-copy-candies-and-balls | Route 10's nurse: copy 40 Rare Candies and 40 Ultra Balls with the Mail Glitch |
| 04-candy-evolutions | Route 10's nurse: Rare Candies evolve Pidgey twice, Rattata and Oddish; Blastoise leads again |
| 05-victory-road-first | From Route 10's nurse: fly to Indigo Plateau, catch three new species in Victory Road 2F, back to Indigo's nurse |
| 06-retro-mail | From Indigo Plateau's nurse: fly to Celadon, 80 Retro Mail at the Dept. Store's 4F, fly back to Indigo's nurse |
| 07-copy-more-balls | Indigo Plateau's nurse: the Mail Glitch copies 80 more Ultra Balls |
| 08-victory-road-rest | Indigo Plateau's nurse: Victory Road 2F until its nine species are caught (repeats, at most 4 rounds) |
| 09-viridian-forest | From Indigo Plateau's nurse: fly to Pewter, catch Viridian Forest's five new species, back to Pewter's nurse |
| 10-route3-east-grass | From Pewter's nurse: fly to Route 4, catch Route 3's new species in its east grass, back to Route 4's nurse |
| 11-route8-grass | From Route 4's nurse: fly to Lavender, cut into Route 8's grass, catch Meowth and Growlithe, back to Lavender's nurse |
| 12-power-plant | From Lavender's nurse: fly to Route 10, surf down to the Power Plant, catch its new species, back to Route 10's nurse |
| 13-mansion | From Route 10's nurse: fly to Cinnabar, catch the Pokemon Mansion's new species on 1F, fly back to Route 10's nurse |
| 14-route10-river | Route 10's nurse: surf on the river east of the Center, catch a Tentacool, back to the nurse |
| 15-vermilion-routes | From Route 10's nurse: fly to Vermilion, Drowzee in Route 11's grass, Psyduck on Route 6's pond, back to Vermilion's nurse |
| 16-magikarp-salesman | From Vermilion's nurse: fly to Route 4, buy the salesman's Magikarp, Route 4's nurse |
| 17-eevee | From Route 4's nurse: fly to Celadon, take the Eevee on the Condominiums' roof, fly to Route 10's nurse |
| 18-fuchsia-routes | From Route 10's nurse: fly to Fuchsia, Venonat and Ditto in Route 15's grass, Doduo and Fearow in Route 18's, fly to Route 10's nurse |

<!-- plans: 7c73e017954e -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-ultra-balls | pidgey in the party (fly); money at least ¥12000 (mart); at the start, Route10_PokemonCenter_1F |
| 02-route10-new-species | ultra-ball at least x1 (capture); at the start, Route10_PokemonCenter_1F |
| 03-copy-candies-and-balls | mr-mime in the party (party_swap); rare-candy at least x1 (give_bag_item); ultra-ball at least x1 (give_bag_item); retro-mail at least x82 (duplicate_item); at the start, Route10_PokemonCenter_1F |
| 04-candy-evolutions | party includes mr-mime in slot 1; blastoise in the party (party_swap); rare-candy at least x40 (promised before); ultra-ball at least x40 (promised before); rare-candy at least x3 (candy_level); at the start, Route10_PokemonCenter_1F |
| 05-victory-road-first | party includes blastoise in slot 1, mr-mime in slot 2, pidgeot in slot 4, raticate in slot 5, gloom in slot 6; pidgeot in the party (fly); ultra-ball at least x1 (capture); at the start, Route10_PokemonCenter_1F |
| 06-retro-mail | pidgeot in the party (fly); money at least ¥4000 (mart); at the start, IndigoPlateau_PokemonCenter_1F |
| 07-copy-more-balls | mr-mime in the party (party_swap); blastoise in the party (party_swap); retro-mail at least x81 (duplicate_item); at the start, IndigoPlateau_PokemonCenter_1F |
| 08-victory-road-rest | party includes blastoise in slot 1, mr-mime in slot 2; ultra-ball at least x1 (capture); at the start, IndigoPlateau_PokemonCenter_1F |
| 09-viridian-forest | pidgeot in the party (fly); ultra-ball at least x1 (capture); at the start, IndigoPlateau_PokemonCenter_1F |
| 10-route3-east-grass | pidgeot in the party (fly); ultra-ball at least x1 (capture); at the start, PewterCity_PokemonCenter_1F |
| 11-route8-grass | pidgeot in the party (fly); a member knows cut (cut_tree); ultra-ball at least x1 (capture); at the start, Route4_PokemonCenter_1F |
| 12-power-plant | pidgeot in the party (fly); ultra-ball at least x1 (capture); at the start, LavenderTown_PokemonCenter_1F |
| 13-mansion | pidgeot in the party (fly); ultra-ball at least x1 (capture); at the start, Route10_PokemonCenter_1F |
| 14-route10-river | ultra-ball at least x1 (capture); at the start, Route10_PokemonCenter_1F |
| 15-vermilion-routes | pidgeot in the party (fly); ultra-ball at least x2 (capture); at the start, Route10_PokemonCenter_1F |
| 16-magikarp-salesman | pidgeot in the party (fly); at the start, VermilionCity_PokemonCenter_1F |
| 17-eevee | pidgeot in the party (fly); at the start, Route4_PokemonCenter_1F |
| 18-fuchsia-routes | pidgeot in the party (fly); ultra-ball at least x2 (capture); at the start, Route10_PokemonCenter_1F |
<!-- /generated -->

## Known limits

- One patch so far: once Voltorb, Spearow and Ekans are all caught, the catch checkpoint finds nothing
  new and stops out of encounters. Other routes come next.
- It never weakens a Pokemon before throwing: Ultra Balls catch these three often enough at full HP.
- With six in the party, catches go to Bill's PC; it never gives a nickname.
