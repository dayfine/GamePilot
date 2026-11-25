# Sevii Story (FRLG)

Registry id `frlg.sevii_story`, group FRLG / Story (`src/program_registry`). It plays the Sevii
Islands story from a save that has beaten Blaine (roadmap `docs/roadmap/frlg-sevii-islands.md`). Its
first checkpoint declares the game's own gate for Bill's trip, the Volcano Badge, as its precondition,
read off the Trainer Card: Blaine's win sets it and starts Bill's scene (pokefirered
`CinnabarIsland_Gym_EventScript_DefeatedBlaine`), and nothing on the trip checks the Hall of Fame
but one line of Celio's scene. Celio asks for the Ruby only once the National Dex is on
(`OneIsland_PokemonCenter_1F_EventScript_Celio`): that is the later stages' gate. It runs on mGBA.

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
| 05-berry-forest | Healed at Three Island's Center; west over Bond Bridge past its trainers, the Berry Forest to Lostelle, her Hypno, and home to the Joyful Game Corner |
| 06-back-to-cinnabar | Lostelle's father takes the Meteorite for a Moon Stone; the Seagallop to One Island, Bill's goodbye in the Center, and the Seagallop home to Cinnabar |

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

05 heals at Three Island's Center first, since 04 does not, then walks west out of town. The
Bikers stood in the street north of the scene's rows; their scene removed them for good, and no
walk reaches their tiles before it, so `Frlg_overworld.Scene_removed_people` leaves them off the
maps, as `Scene_only_people` does the Game Corner's Biker. Two Super Repels from the bag keep the
wild Pokemon away: BLASTOISE (Lv 60) leads, above them all. Without them a wild battle on an open
leg in the bridge's grass left the walk reckoned a tile ahead of the player, who went on into a
pocket of grass off the way. A Super Repel lasts 200 steps and the game refuses another while one
works. The first, used at the Center, carries the walk over the bridge and has some 30 steps
left at the forest's mat; the walk paces row 39 by the mat, clear of the grass, wall to wall four
times (57 steps), and uses the second there, for the 190 or so steps to Lostelle. Each wears off
on a leg held to a wall, which walks on after the message.

Bond Bridge (`ThreeIsland_BondBridge`) has seven trainers, and two cannot both be walked around
(a reachability pass over the map and their sight): Aroma Lady Violet at (68, 10) looks west two
tiles over the only way from the east half, and Aroma Lady Nikki wanders a 3 by 3 box round
(27, 10) looking every way five tiles. The planner keeps off a standing trainer's line where it
can (the twins Joy and Meg's double battle is walked around) and treats the rest as open. On a
route event with `"fight_trainers": true` (05's `over_bond_bridge`; off by default, for saves that
have beaten the maps' trainers), a leg that steps onto a tile a trainer not beaten may see is
walked a piece at a time
(`Frlg_overworld.Trainer_crossing`): each piece ends on such a tile, then the walk waits for the
trainer's "!", walk up and text, as long as the fork's `trainer_full_watch()` (1.5 s, a walking tile
for each tile of sight, 1 s). A text is the trainer's: its battle is fought as a `train` battle
(`Trainer_battles`), the trainer is beaten for the rest of the walk, and the walk is planned again
from that tile round where the trainer may now stand (the tile beside the player toward each
tile they may have looked from). The fork instead holds the whole leg and finds the player again
from the stop's timing; a wanderer may see the player from more than one tile, so here the tile is
fixed before anyone speaks.

In the Berry Forest (`ThreeIsland_BerryForest`) the walk goes from the south mat round the
forest to (4, 9), below Lostelle. Her script (pokefirered
`ThreeIsland_BerryForest_EventScript_Lostelle`) speaks, looks round and starts a wild battle with
a Hypno Lv 30 (`setwildbattle`, `dowildbattle`), whose outcome it does not check. The `talk`
stops at the battle, and a `battle` event (`Frlg_actions.Scene_battle`) fights it with the lead's
moves in slot order. Then a `scene`: Lostelle gives an Iapapa Berry, sets `FLAG_RESCUED_LOSTELLE`,
and the game warps the player to the Joyful Game Corner (6, 6), turned north, where her father's
thanks run at once (`TwoIsland_JoyfulGameCorner_EventScript_FoundLostelleScene`). 05 ends there.

06 walks a tile west, below Lostelle's father (5, 5), and talks to him (pokefirered
`TwoIsland_JoyfulGameCorner_EventScript_LostellesDaddy`): with the room's scene var at 3 he takes
the Meteorite, sets Celio's VAR to 2 and gives a Moon Stone, if the bag has room for it. Then it
sails from Two Island's harbor to One Island (ONE ISLAND, the first row of the same two-island list
as before) and walks into One Island's Center. Column 12 of that room, rows 6 to 9, holds four
coord events while Celio's VAR is 2 (`OneIsland_PokemonCenter_1F_EventScript_LeaveOneIslandScene`):
like 04's rows, the walk stops a tile west of them, at (11, 7), and a `step` goes on. Bill and
Celio say goodbye and the script itself walks the player out with Bill and sails to Cinnabar,
which lands at (21, 7) (pokefirered `src/seagallop.c`). Cinnabar's frame script
(`CinnabarIsland_EventScript_ReturnFromSeviiIslands`) runs at once: Bill's last line, and he walks
off south. One `scene` event settles it all. 06 ends there, at (21, 7) facing south. Cinnabar's VAR
is now 4, so from here on every Sevii harbor's list starts with VERMILION
(`EventScript_ChooseDestFromOneIslandVermilionAllowed`, MULTICHOICE_SEAGALLOP_V23 and V13), a
window of four rows that `Seagallop` does not read yet. The two islanders by Three Island's street
hide once Lostelle is home (`ThreeIsland_EventScript_HideAntiBikers`).

After that come Celio's Ruby and Sapphire errands, from the roadmap.
