# Sevii Story (FRLG)

Registry id `frlg.sevii_story`, group FRLG / Story (`src/program_registry`). It plays the Sevii
Islands story from a save past the Hall of Fame (roadmap `docs/roadmap/frlg-sevii-islands.md`). Its
first checkpoint declares the save's eight badges and the Hall of Fame as preconditions, read off the
Trainer Card. It runs on mGBA.

The program ends when Cerulean Cave opens: Celio takes the Sapphire and the guard leaves
(`FLAG_HIDE_CERULEAN_CAVE_GUARD`). The roadmap plans the checkpoints after 03, read from pret:

| Stage | Planned checkpoints | First missing feature |
|---|---|---|
| Lostelle and Bill's way home | 04-three-island-bikers, 05-berry-forest, 06-back-to-cinnabar | trainer battles |
| National Dex and the Ruby | 07-national-dex, 08-celio-ruby-request, 09-kindle-road, 10-ruby-path, 11-rainbow-pass | 60 caught, Surf, Strength |
| Icefall Cave (it moves Ruin Valley's scientist) | 12-icefall-hm07, 13-icefall-lorelei | ice floors, Waterfall |
| The Sapphire | 14-dotted-hole, 15-rocket-warehouse, 16-celio-sapphire | Cut from the party menu, holes, spinners |
| Proof | 17-cerulean-cave | Surf |

| Checkpoint | Content |
|---|---|
| 01-to-one-island | Fly to Cinnabar, YES to Bill in the Pokemon Center: out with him, the Seagallop, One Island, Celio's Tri-Pass |
| 02-to-two-island | Bill's Meteorite errand: One Island's harbor, the Seagallop to Two Island, outside the Joyful Game Corner |
| 03-to-three-island | The Joyful Game Corner's owner asks the player to find Lostelle; the Seagallop to Three Island's harbor |
| 04-three-island-bikers | North through Three Island's port (storage back on); the Bikers' scene and its four trainer battles |

The game decides the first trip. Bill offers it when you leave Cinnabar Gym with the seventh badge;
a player who said no finds him waiting in the Cinnabar Pokemon Center, even after the Hall of Fame
(pokefirered `CinnabarIsland_EventScript_DeclineSailToOneIsland`). The Vermilion harbor's sailor
sails only once that trip is done (`VermilionCity_EventScript_FerrySailor`), and the Tri-Pass comes
from Celio at its end. The walkthrough drafts (#41) started at Vermilion and assumed the Tri-Pass;
this checkpoint replaces their sb-01.

The YES runs one script to its end: one `answer` event, then a `scene` that ends below Bill in
One Island's Center. On FireRed an `answer` event starts its own talk: a `talk` event's settle
presses B, and B answers NO.

The Cinnabar Pokemon Center has no map in PokemonSimulation, and needs none: 17 of FireRed's 19
Centers share one layout, and `Frlg_overworld.Standard_center` codes that room as the fork's story
does (`PokemonFRLG_CodedRooms`), with each Center's people (`Frlg_overworld.Center_people`, from
pret) as obstacles. The world loader uses it for every standard Center, so the `cinnabar_center_bill`
place and the route reach it. Where PokemonSimulation also has a map of a standard Center, the
coded room wins and the map file is not read: `heal_at` and `make_room` walk the same room in every
standard Center. Only the Indigo Plateau's and One Island's Centers, with layouts of their own, come
from their map files.

The walk goes from the Center's door mat straight to Bill. A room entered by its door comes up dim
and holds still for about 600ms before it fades in; the walk waits for that fade-in to finish
(`Warp_fade_in`) before its first step, so no step is lost.

Celio's scene also turns off Bill's PC storage (`FLAG_SYS_PC_STORAGE_DISABLED`) until the player
reaches Three Island's port.

The scene ends with Bill's favor: take the Meteorite to the man who runs Two Island's Game Corner.
The `ferry` game action (`Seagallop`) talks to a harbor's sailor, reads his list of islands
(`Script_menu.seagallop_islands`), moves its cursor to the island and settles the crossing, which
lands the player at (8, 5) of the island's harbor, facing south. Until Bill's trip back to Cinnabar
the list is the two other islands of One, Two and Three, then EXIT (pokefirered
`EventScript_ChooseDestFromOneIsland`); the lists with Vermilion and the Rainbow Pass's pages are
other windows, not read yet. 02 ends below the Game Corner's door facing east, not north: a press
toward a door walks in whichever way the player faces (pokefirered `TryDoorWarp`).

On the Joyful Game Corner's mat (`TwoIsland_JoyfulGameCorner`) the owner's scene runs at once
(pokefirered `TwoIsland_JoyfulGameCorner_EventScript_HelpFindLostelleScene`): Lostelle's father
comes down to the player, who steps a tile west, and a Biker comes in on the door tile asking for
Three Island. 03 settles it as a `scene` event and declares where it leaves the player, (4, 8)
facing east. The scene sets `VAR_MAP_SCENE_THREE_ISLAND` to 2, which no screen we read shows; the
Meteorite stays in the bag until Lostelle is home.

The room's map has the Biker standing on the door tile (5, 8), with his hide flag. The game sets
that flag at the new game and no script clears it: the scene shows him with `addobject` and takes
him away again. `Frlg_overworld.Scene_only_people` lists such people, and the checkpoint runner's
world treats them as not there, so the walk out goes over the door tile. The other hidden people in
the maps still count as standing where the map puts them.

03 sails from Two Island's harbor to Three Island (the second row of the sailor's list, below ONE
ISLAND) and ends at Three Island's harbor (8, 5), facing south. North of the harbor is Three
Island's port, which turns PC storage back on (`ThreeIsland_Port_OnTransition`), and the town
with the Bikers.

04 walks through the port into town and stops below the Bikers at (8, 28). Two rows of coord events
cross the street: row 27 runs the boss's intro once 03's scene has set `VAR_MAP_SCENE_THREE_ISLAND`
to 2, row 26 the battles once the intro has set it to 3. Their text shows the moment the player
lands, so each row is reached with a `step` event, which holds one tile and watches nothing; a walk
would take the text for a message on its way and press B, and B answers the Biker's question NO.
The intro is a `scene`. On (8, 26) a Biker comes down and asks "You wanna make something of it or
what?": an `answer` YES, whose settle now stops at the battle it starts, as a `talk`'s does. Then
one `train` event with 4 battles fights the three Biker goons and Cue Ball Paxton
(`Frlg_actions.Trainer_battles`): it presses the lines between battles through, each battle's lead
attacks with its moves in slot order, and the lines after the last battle are settled to a quiet
overworld. A fainted lead fails the event as `battle_lost`.

The party leads with BLASTOISE (Lv 60, Surf) for this: a `party_swap` first. On mGBA, with MIMIEN
(Lv 33) in slot 1, every battle opened on it, since Gen 3 puts the party back in order after a
battle, and it fainted in the second one. The Bikers' Pokemon are Lv 37 to 39 Koffing, Grimer,
Weezing and Muk, and Surf takes most of them in one hit, so the party is not healed before the
scene: there is no free control between its battles anyway. The save plays with the Set battle
style; under Shift, a trainer's "Will ... change POKéMON?" is read by its text (`Switch_offer`)
and answered NO. 04 ends on (8, 26) facing north with the Bikers gone and $3,196 more: 740, 760,
760 and 936 (pokefirered: 4 x the last Pokemon's level x the class's base, Biker 5, Cue Ball 6).

After that come Lostelle on Three Island's Bond Bridge side, Celio's Ruby and Sapphire errands and
the legendary birds, from the walkthrough drafts.
