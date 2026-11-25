# Sevii Story

Plays the Sevii Islands story on a save that has beaten the Elite Four. So far it does the first
trip and Bill's errand after it, up to Lostelle's rescue. It flies to Cinnabar Island and answers YES to
Bill in the Pokemon Center, who takes you to One Island on the Seagallop. There Celio gives you the
Tri-Pass, which the Vermilion ferry needs, and Bill gives you a Meteorite for the man who runs Two
Island's Game Corner. The program then sails from One Island's harbor to Two Island and walks into
the Game Corner, where the owner asks you to find his daughter Lostelle and a Biker barges in. It
sails on to Three Island, walks through its port, where PC storage comes back on, and beats the
Bikers who hold the town: three goons and their boss, Cue Ball Paxton, in four trainer battles in a
row. It moves BLASTOISE to the front of the party first, since it leads every one of those
battles. Then it heals in Three Island's Pokemon Center, uses a Super Repel and crosses Bond
Bridge, beating the trainers who see it on the way, uses another in the Berry Forest, and finds
Lostelle; it beats the Hypno that attacks her, and the game takes you both back to the Game
Corner. Your save must have turned Bill down when he asked after the Cinnabar Gym, so that he
still waits in the Center. It starts at the Celadon Dept. Store
1F save spot, where Supplies and Team Training end.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

<!-- generated:needs -->
- 0 free party slots
- at least 8 badges
- the Hall of Fame entered
- pidgey in the party (fly)
- blastoise in the party (party_swap)
- super-repel at least x2 (use_item)
- at the start, CeladonCity_DepartmentStore_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.sevii_story --from 01-to-one-island --to 05-berry-forest --mode verification
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

<!-- plans: e017af48b8b0 -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-to-one-island | at least 8 badges; the Hall of Fame entered; pidgey in the party (fly); at the start, CeladonCity_DepartmentStore_1F |
| 02-to-two-island | tri-pass at least x1 (promised before); at the start, OneIsland_PokemonCenter_1F |
| 03-to-three-island | meteorite at least x1 (promised before); at the start, TwoIsland |
| 04-three-island-bikers | blastoise in the party (party_swap); meteorite at least x1 (promised before); at the start, ThreeIsland_Harbor |
| 05-berry-forest | super-repel at least x2 (use_item); at the start, ThreeIsland |
<!-- /generated -->

## Known limits

- Once Celio has given you the Tri-Pass, Bill's PC storage stays off until you reach Three Island's
  port. That is the game's own rule, so a program that uses the PC can't run in between.
- It stops in the Joyful Game Corner once Lostelle is home, before her father takes the Meteorite.
- Bring two Super Repels: without them a wild battle in Bond Bridge's grass can leave the program
  thinking you stand a tile from where you do, and it walks off its way.
- The Bikers' battles are fought by the party's first Pokemon alone, with its moves in order; if it
  faints, the program stops there. A team weaker than a Lv 60 BLASTOISE against Lv 37 to 39
  Koffing, Grimer, Weezing and Muk may lose. The same holds for Bond Bridge's trainers (Bellsprout,
  Weepinbell, Bulbasaur and Ivysaur, Lv 36 to 37) and Lostelle's Hypno (Lv 30).
