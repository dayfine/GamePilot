# Sevii Story

Plays the Sevii Islands story after the Cinnabar Gym: Bill's trip to One Island, the Meteorite
errand and Lostelle's rescue, back to Cinnabar Island.

So far it ends when Bill goes home, before the National Pokedex. Your save must have turned Bill
down when he asked after the Cinnabar Gym, so that he still waits in the Center. "What happens"
below lists each checkpoint.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

<!-- generated:needs -->
- the volcano badge
- pidgey in the party (fly)
- blastoise in the party (party_swap)
- the thunder badge (fly)
- super-repel at least x2 (use_item)
- at the start, CeladonCity_DepartmentStore_1F
<!-- /generated -->

Also:

- Save at the Celadon Dept. Store 1F save spot, where Supplies and Team Training end.
- Have turned Bill down when he asked after the Cinnabar Gym, so he still waits in the Pokemon
  Center.
- Bring a strong BLASTOISE: the program moves it to the front before Three Island's Bikers, and it fights
  every trainer battle on its own (see "Known limits").

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.sevii_story --from 01-to-one-island --to 06-back-to-cinnabar --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-to-one-island | Fly to Cinnabar; Bill takes the Seagallop to One Island, Celio gives the Tri-Pass |
| 02-to-two-island | One Island's harbor: the Seagallop to Two Island, to the Joyful Game Corner's door |
| 03-to-three-island | The Joyful Game Corner's owner asks for Lostelle; the Seagallop to Three Island |
| 04-three-island-bikers | Three Island's port turns storage back on; the Bikers and Cue Ball Paxton |
| 05-berry-forest | Bond Bridge's trainers, the Berry Forest and Lostelle's Hypno; home to the Game Corner |
| 06-back-to-cinnabar | The Meteorite for a Moon Stone; Bill's goodbye on One Island and the Seagallop to Cinnabar |

<!-- plans: 20cd4230b56e -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-to-one-island | the volcano badge; pidgey in the party (fly); the thunder badge (fly); at the start, CeladonCity_DepartmentStore_1F |
| 02-to-two-island | tri-pass at least x1 (promised before); at the start, OneIsland_PokemonCenter_1F |
| 03-to-three-island | meteorite at least x1 (promised before); at the start, TwoIsland |
| 04-three-island-bikers | blastoise in the party (party_swap); meteorite at least x1 (promised before); at the start, ThreeIsland_Harbor |
| 05-berry-forest | super-repel at least x2 (use_item); at the start, ThreeIsland |
| 06-back-to-cinnabar | at the start, TwoIsland_JoyfulGameCorner |
<!-- /generated -->

## Known limits

- Once Celio has given you the Tri-Pass, Bill's PC storage stays off until you reach Three Island's
  port. That is the game's own rule, so a program that uses the PC can't run in between.
- It stops on Cinnabar Island's shore once Bill has gone, before the National Pokedex.
- Keep room in the bag's Items pocket for the Moon Stone: with none, Lostelle's father keeps it and
  the run fails its end check.
- Bring two Super Repels: without them a wild battle in Bond Bridge's grass can leave the program
  thinking you stand a tile from where you do, and it walks off its way.
- The Bikers' battles are fought by the party's first Pokemon alone, with its moves in order; if it
  faints, the program stops there. A team weaker than a Lv 60 BLASTOISE against Lv 37 to 39
  Koffing, Grimer, Weezing and Muk may lose. The same holds for Bond Bridge's trainers (Bellsprout,
  Weepinbell, Bulbasaur and Ivysaur, Lv 36 to 37) and Lostelle's Hypno (Lv 30).
