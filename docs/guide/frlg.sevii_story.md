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
- blastoise in the party (party_swap)
- a member knows fly (fly)
- the thunder badge (fly)
- super-repel at least x2 (use_item)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

Also:

- Save anywhere outdoors in Kanto, where Fly works; Supplies and Team Training end so.
- Have turned Bill down when he asked after the Cinnabar Gym, so he still waits in the Pokemon
  Center.
- Bring a strong BLASTOISE: the program moves it to the front before Three Island's Bikers, and it fights
  every trainer battle on its own (see "Known limits").

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.sevii_story --from 01-to-one-island --to 06-back-to-cinnabar --mode verification
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

<!-- plans: 3a99ab15c65c -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-to-one-island | the volcano badge; a member knows fly (fly); the thunder badge (fly); at the start, anywhere outdoors where Fly works |
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

## How it works

The roadmap is `docs/roadmap/frlg-sevii-islands.md`; the scripts named here are pokefirered's.

**The gate.** 01's precondition is the game's own gate for Bill's trip, the Volcano Badge, read off
the Trainer Card: Blaine's win sets it and starts Bill's scene
(`CinnabarIsland_Gym_EventScript_DefeatedBlaine`). Nothing on the trip checks the Hall of Fame but
one line of Celio's scene. Celio asks for the Ruby only once the National Dex is on
(`OneIsland_PokemonCenter_1F_EventScript_Celio`): that is the later stages' gate.

**The end.** The program ends when Cerulean Cave opens: Celio takes the Sapphire and the guard
leaves (`FLAG_HIDE_CERULEAN_CAVE_GUARD`). The roadmap plans the checkpoints after 06, from pret:

| Stage | Planned checkpoints | First missing feature |
|---|---|---|
| National Dex and the Ruby | 07-national-dex, 08-celio-ruby-request, 09-kindle-road, 10-ruby-path, 11-rainbow-pass | 60 caught, Surf, Strength |
| Icefall Cave (it moves Ruin Valley's scientist) | 12-icefall-hm07, 13-icefall-lorelei | ice floors, Waterfall |
| The Sapphire | 14-dotted-hole, 15-rocket-warehouse, 16-celio-sapphire | Cut from the party menu, holes, spinners |
| Proof | 17-cerulean-cave | Surf |

**01, the first trip.** Bill offers it when you leave Cinnabar Gym with the seventh badge; a player
who said no finds him in the Cinnabar Pokemon Center, even after the Hall of Fame
(`CinnabarIsland_EventScript_DeclineSailToOneIsland`). Vermilion's sailor sails only once that trip
is done (`VermilionCity_EventScript_FerrySailor`), and the Tri-Pass comes from Celio at its end. The
walkthrough drafts (#41) started at Vermilion and assumed the Tri-Pass; 01 replaces their sb-01.

**The YES.** It runs one script to its end: one `answer` event, then a `scene` that ends below Bill
in One Island's Center. On FireRed an `answer` event starts its own talk: a `talk` event's settle
presses B, and B answers NO.

**Standard Centers.** 17 of FireRed's 19 Centers share one layout: `Frlg_overworld.Standard_center`
codes that room as the fork's story does (`PokemonFRLG_CodedRooms`), with each Center's people
(`Frlg_overworld.Center_people`, from pret) as obstacles. The world loader uses it for every
standard Center, even where PokemonSimulation has a map, so Cinnabar's needs none. Only the Indigo
Plateau's and One Island's Centers, with layouts of their own, come from their map files.

**The fade-in.** A room entered by its door comes up dim and holds still for about 600ms before it
fades in; the walk waits for that (`Warp_fade_in`) before its first step, so no step is lost.
Celio's scene also turns off Bill's PC storage (`FLAG_SYS_PC_STORAGE_DISABLED`) until Three
Island's port turns it back on (`ThreeIsland_Port_OnTransition`).

**02, the Seagallop.** The `ferry` action (`Seagallop`) talks to a harbor's sailor, reads his list
(`Script_menu.seagallop_islands`), moves the cursor to the island and settles the crossing, which
lands at (8, 5) of the island's harbor, facing south. Until Bill's trip home the list is the two
other islands of One, Two and Three, then EXIT (`EventScript_ChooseDestFromOneIsland`); the lists
with Vermilion and the Rainbow Pass's pages are other windows, not read yet.

**02's end.** It stops below the Game Corner's door facing east, not north: a press toward a door
walks in whichever way the player faces (`TryDoorWarp`).

**03, the owner's scene.** On the Joyful Game Corner's mat the scene runs at once
(`TwoIsland_JoyfulGameCorner_EventScript_HelpFindLostelleScene`): Lostelle's father comes down,
the player steps a tile west, and a Biker comes in on the door tile. 03 settles it as a `scene`
and declares where it leaves the player, (4, 8) facing east. It sets `VAR_MAP_SCENE_THREE_ISLAND`
to 2, which no screen we read shows. 03 then sails to Three Island (the list's second row).

**Scene-only people.** The room's map has that Biker on the door tile (5, 8), with his hide flag,
which the game sets at the new game and no script clears: the scene shows him with `addobject` and
takes him away. `Frlg_overworld.Scene_only_people` lists such people, and the runner's world treats
them as not there, so the walk out goes over the door. Other hidden people still count.

**04, the Bikers' rows.** Two rows of coord events cross the street: row 27 runs the boss's intro
once the scene var is 2, row 26 the battles once the intro has set it to 3. Their text shows the
moment the player lands, so each row is reached with a `step` event, which holds one tile and
watches nothing; a walk would take the text for a message on its way, press B and answer NO.

**04, the battles.** The intro is a `scene`. On (8, 26) a Biker asks "You wanna make something of
it or what?": an `answer` YES, whose settle stops at the battle it starts. One `train` event with 4
battles fights the three goons and Cue Ball Paxton (`Frlg_actions.Trainer_battles`): it presses the
lines between battles, the lead attacks with its moves in slot order, and the last lines are
settled to a quiet overworld. A fainted lead fails the event as `battle_lost`.

**04, the lead.** A `party_swap` puts BLASTOISE (Lv 60, Surf) first. On mGBA, with MIMIEN (Lv 33)
in slot 1, every battle opened on it, since Gen 3 puts the party back in order after a battle, and
it fainted in the second. Surf takes most of the Lv 37 to 39 Pokemon in one hit, so there is no
heal first (no free control between the battles anyway). Under Shift, "Will ... change POKéMON?"
is read (`Switch_offer`) and answered NO.

**04's money.** It ends on (8, 26) facing north with $3,196 more: 740, 760, 760 and 936 (4 x the
last Pokemon's level x the class's base, Biker 5, Cue Ball 6).

**05, the repels.** It heals at Three Island's Center, since 04 does not. The Bikers' scene removed
them for good, so `Frlg_overworld.Scene_removed_people` leaves them off the maps. Two Super Repels
keep wild Pokemon away: without them a wild battle on an open leg in the bridge's grass left the
walk reckoned a tile ahead, and it went on into grass off the way.

**05, the repels' steps.** A Super Repel lasts 200 steps and the game refuses another while one
works. The first, used at the Center, has some 30 steps left at the forest's mat; the walk paces
row 39 by the mat wall to wall four times (57 steps) and uses the second there, for the 190 or so
steps to Lostelle. Each wears off on a leg held to a wall, which walks on after the message.

**Bond Bridge's trainers.** `ThreeIsland_BondBridge` has seven, and two cannot both be walked
around: Aroma Lady Violet at (68, 10) looks west two tiles over the only way from the east half,
and Aroma Lady Nikki wanders a 3 by 3 box round (27, 10) looking five tiles every way. The planner
keeps off a standing trainer's line where it can (the twins' double battle is walked around).

**Fighting them.** On a route event with `"fight_trainers": true` (05's `over_bond_bridge`; off by
default), a leg onto a tile an unbeaten trainer may see is walked in pieces
(`Frlg_overworld.Trainer_crossing`). Each piece ends on such a tile, then the walk waits as long as
the fork's `trainer_full_watch()`: 1.5 s, a walking tile for each tile of sight, then 1 s.

**After a sighting.** A text is the trainer's: the battle is a `train` battle, the trainer is
beaten for the rest of the walk, and the walk is planned again round where the trainer may now
stand. The fork instead holds the whole leg and finds the player from the stop's timing; a
wanderer may see the player from more than one tile, so here the tile is fixed first.

**05, Lostelle.** The walk goes from the Berry Forest's south mat to (4, 9), below her. Her script
(`ThreeIsland_BerryForest_EventScript_Lostelle`) starts a wild battle with a Hypno Lv 30 and does
not check its outcome. The `talk` stops at the battle, and a `battle` event
(`Frlg_actions.Scene_battle`) fights it with the lead's moves in slot order.

**05's end.** A `scene`: Lostelle gives an Iapapa Berry, sets `FLAG_RESCUED_LOSTELLE`, and the game
warps the player to the Joyful Game Corner (6, 6), turned north, where her father's thanks run at
once (`TwoIsland_JoyfulGameCorner_EventScript_FoundLostelleScene`).

**06, the Moon Stone.** It talks to Lostelle's father at (5, 5)
(`TwoIsland_JoyfulGameCorner_EventScript_LostellesDaddy`): he takes the Meteorite, sets Celio's VAR
to 2 and gives a Moon Stone if the bag has room. Then it sails to One Island (the list's first row)
and walks into its Center.

**06, the goodbye.** Column 12 of One Island's Center, rows 6 to 9, holds four coord events while
Celio's VAR is 2 (`OneIsland_PokemonCenter_1F_EventScript_LeaveOneIslandScene`): the walk stops at
(11, 7) and a `step` goes on. The script sails the player with Bill to Cinnabar, (21, 7)
(`src/seagallop.c`), and Bill's last line runs (`CinnabarIsland_EventScript_ReturnFromSeviiIslands`).

**After 06.** One `scene` settles that; 06 ends at (21, 7) facing south. Cinnabar's VAR is now 4,
so every Sevii harbor's list starts with VERMILION (`EventScript_ChooseDestFromOneIslandVermilionAllowed`),
a window of four rows that `Seagallop` does not read yet. The two islanders by Three Island's
street hide once Lostelle is home (`ThreeIsland_EventScript_HideAntiBikers`).
