# A2. Sevii Islands story

Goal: from a post-game save, play the Sevii Islands story on mGBA until Cerulean Cave is open, and
prove it by walking into `CeruleanCave_1F` (a screenshot at its mat). The program is
`frlg.sevii_story` (`docs/programs/frlg-sevii-story.md`); 01 to 03 exist, 03 ending on Three
Island's harbor after the Joyful Game Corner's scene.

Everything below is read from pret/pokefirered at the pinned commit `ce6406d8`
(`data/maps/<Map>/scripts.inc`, `map.json`, `src/field_specials.c`) and checked against the
PokemonSimulation maps with a reachability pass (walk, Surf, Strength pushes, trainer sight lines).
The fork's earlier symbolic rows (`AutoStory-FRLG-FutureEvents.md`, fork PR #130) and the
walkthrough drafts (#41, `sevii-birds/sb-*` and `wt-14`..`wt-20`) agree on the order; where they
differ, pret wins and the difference is noted.

## What opens Cerulean Cave

The guard in front of the cave (`CeruleanCity` (1, 13)) is hidden by `FLAG_HIDE_CERULEAN_CAVE_GUARD`.
Only one script sets it: Celio taking the Sapphire,
`OneIsland_PokemonCenter_1F_EventScript_GiveCelioSapphire`, which also sets
`FLAG_SYS_CAN_LINK_WITH_RS`, `FLAG_HIDE_LORELEI_IN_HER_HOUSE`, runs `SetPostgameFlags` and
`InitRoamer`, and moves `VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F` (below, *Celio's VAR*) to 6.
The Hall of Fame is needed on the way, through the National Dex. Celio's VAR drives the chain:

| Beat | Script (pret) | Sets |
|---|---|---|
| Joyful Game Corner, owner's plea (03) | `TwoIsland_JoyfulGameCorner_EventScript_HelpFindLostelleScene` | `VAR_MAP_SCENE_THREE_ISLAND` 2 |
| Three Island's port (any entry) | `ThreeIsland_Port_OnTransition` | clears `FLAG_SYS_PC_STORAGE_DISABLED`, sets `FLAG_SEVII_DETOUR_FINISHED` |
| Biker boss's arrival (coord y 27, x 7..11) | `ThreeIsland_EventScript_BikerBossIntroTrigger` | `VAR_MAP_SCENE_THREE_ISLAND` 3 |
| Bikers (coord y 26): YES, then Biker 1, 2, 3 and Cue Ball Paxton | `ThreeIsland_EventScript_BattleBikersScene` | `VAR_MAP_SCENE_THREE_ISLAND` 4 |
| Lostelle in Berry Forest (4, 8): Hypno Lv 30, a wild battle | `ThreeIsland_BerryForest_EventScript_Lostelle` | `FLAG_RESCUED_LOSTELLE`; warps to the Game Corner (6, 6) |
| Back in the Game Corner | `..._FoundLostelleScene` | Game Corner VAR 3 |
| Owner takes the Meteorite, gives a Moon Stone | `..._GiveDaddyMeteorite` | Celio's VAR 2 |
| Into One Island's Center: Bill's goodbye, the Seagallop to Cinnabar | `OneIsland_PokemonCenter_1F_EventScript_LeaveOneIslandScene` (coord) | Celio's VAR 3, `VAR_MAP_SCENE_CINNABAR_ISLAND` 3 |
| Cinnabar: Bill leaves | `CinnabarIsland_EventScript_ReturnFromSeviiIslands` | Cinnabar VAR 4 (the island harbors' lists add VERMILION, `EventScript_ChooseDestFromOneIsland`) |
| Oak's lab: National Dex (60 caught, One Island visited, game clear) | `PalletTown_ProfessorOaksLab_EventScript_TryStartNationalDexScene` | `EnableNationalPokedex` |
| Celio asks for the Ruby | `..._CelioRequestRuby` | Celio's VAR 4 (opens Mt. Ember's cave), `VAR_MAP_SCENE_MT_EMBER_EXTERIOR` 1 |
| Mt. Ember: two Grunts by the cave | `MtEmber_Exterior_EventScript_BattleGrunt1`, `..Grunt2` | both gone once both lose |
| Ruby Path B5F (7, 7) | `MtEmber_RubyPath_B5F_EventScript_Ruby` | `FLAG_GOT_RUBY` |
| Celio takes the Ruby, YES to his favor | `..._GiveCelioRuby`, `..._GiveRainbowPass` | Celio's VAR 5, Rainbow Pass, `FLAG_SYS_SEVII_MAP_4567` |
| Icefall Cave's back: Lorelei and the Rockets, one Grunt | `FourIsland_IcefallCave_Back_EventScript_LoreleiRocketsScene` (coord y 18) | `FLAG_HIDE_RUIN_VALLEY_SCIENTIST` |
| Ruin Valley (24, 25) facing north: Cut from the party menu | `CutMoveRuinValleyCheck`, `CutMoveOpenDottedHoleDoor` (`src/field_specials.c`) | `FLAG_USED_CUT_ON_RUIN_VALLEY_BRAILLE` |
| Dotted Hole: the Sapphire, taken by the thief | `SixIsland_DottedHole_SapphireRoom_EventScript_Sapphire` | `FLAG_LEARNED_YES_NAH_CHANSEY` |
| Rocket Warehouse door (Five Island Meadow (12, 21)) | `FiveIsland_Meadow_EventScript_WarehouseDoor` | `FLAG_UNLOCKED_ROCKET_WAREHOUSE` |
| Warehouse: the Admins, then Gideon | `..._DefeatedAdmin2`, `..._DefeatedGideon` | `FLAG_DEFEATED_ROCKETS_IN_WAREHOUSE`, `FLAG_RECOVERED_SAPPHIRE`, the Sapphire |
| Celio takes the Sapphire | `..._GiveCelioSapphire` | `FLAG_HIDE_CERULEAN_CAVE_GUARD` |

Three things the drafts missed:

- **Icefall Cave is not optional.** The Ruin Valley scientist stands on (24, 25), the one tile Cut
  opens the Dotted Hole from, until Lorelei's scene hides him. So HM07 Waterfall and the Lorelei
  scene come before the Sapphire.
- **Rock Smash is not needed** on this route: Kindle Road is crossed by Surf, and the Ruby Path's
  rocks are off the way once its boulders are pushed (the Ember Spa's HM06 stays optional).
- **The Mt. Ember password scene is not a gate.** The warehouse door checks only
  `FLAG_LEARNED_YES_NAH_CHANSEY`, set by the thief in the Sapphire room; the Grunts' "Goldeen"
  scene (coord (37..39, 43)) is on the path to the cave and only needs settling.

## Checkpoints

From 03's end on, one line each: `NN-slug`: what it does, and what it needs that GamePilot lacks.
Every map below is in PokemonSimulation except the Dotted Hole's six, added in
dayfine/PokemonSimulation#125.

| # | Checkpoint | What, needs |
|---|---|---|
| 03 | `03-to-three-island` | (in #99) Game Corner scene, the Seagallop to Three Island's harbor |
| 04 | `04-three-island-bikers` | Harbor, port (PC storage back on), north into town: the boss's scene, YES, four trainer battles (Bikers Lv 37-38, Paxton's Weezing and Muk Lv 39); heal at Three Island's Center (14, 27). Needs **trainer battles** |
| 05 | `05-berry-forest` | West over Bond Bridge (at least one trainer cannot be walked around), Berry Forest to Lostelle (4, 8), talk, Hypno Lv 30 (beat or run), warp to the Game Corner, Lostelle's scene. Needs trainer battles, a **wild battle after a talk** |
| 06 | `06-back-to-cinnabar` | Talk to the owner (Meteorite for a Moon Stone; bag room), Two Island's harbor, ferry to One Island, into the Center: Bill's goodbye scene, the Seagallop to Cinnabar, Bill leaves. Needs nothing new |
| 07 | `07-national-dex` | Precondition 60 species caught. Fly to Pallet, Oak in his lab: rating, then the National Dex scene. Needs a **caught-count reader**, and, if the save is short, a catching program first |
| 08 | `08-celio-ruby-request` | Fly to Vermilion, the Seagallop to One Island (Vermilion's sailor's Tri-Pass list), Celio's request. Needs the **Vermilion ferry list** |
| 09 | `09-kindle-road` | One Island east to Kindle Road, Surf north to Mt. Ember, the password scene, both Grunts (Lv 35-37), into Ruby Path 1F. Needs **Surf**, trainer battles |
| 10 | `10-ruby-path` | 1F (1, 1) down, B2F's 4 Strength pushes, B3F's 11, B4F, B5F's Ruby; an Escape Rope out. Needs **Strength** with pushes as walk state, an Escape Rope from the bag |
| 11 | `11-rainbow-pass` | Back to One Island (Surf down Kindle Road, or Fly), Celio: YES, the Rainbow Pass. Needs Surf, or **Fly to a Sevii town** |
| 12 | `12-icefall-hm07` | Ferry to Four Island (the Rainbow Pass's paged list), rival's scene, Surf to Icefall Cave, 1F's thin ice dropped on purpose, B1F's sliding ice to the ladder at (15, 16), HM07 at 1F (12, 16); teach Waterfall to Blastoise. Needs **ferry pages**, **ice floors**, holes, **teach** |
| 13 | `13-icefall-lorelei` | Entrance: Surf and Waterfall north to (9, 7), 1F's north part to the back (3, 6), Lorelei's scene with one Grunt (Zubat, Zubat, Golbat Lv 38). Needs **Waterfall**, a trainer battle inside a scene |
| 14 | `14-dotted-hole` | Ferry to Six Island, Water Path (one trainer in the way), Ruin Valley (24, 25) north, Cut from the party menu; the Dotted Hole's holes: 1F (6, 5), B1F north (6, 1), B2F west (1, 5), B3F east (11, 5), B4F south (6, 9); the Sapphire and the thief's scene. Needs the **party-menu field move**, **holes** in the walker |
| 15 | `15-rocket-warehouse` | Ferry to Five Island, the Meadow (a Grunt in the way), the door, the spinner maze, Grunts (Lv 48-49), the Admins (Lv 52-55), Gideon (five Electric types, Lv 46): the Sapphire. Needs **spinners**, trainer battles at that level |
| 16 | `16-celio-sapphire` | Ferry to One Island, Celio takes the Sapphire: the network is linked and the guard is gone. Needs nothing new |
| 17 | `17-cerulean-cave` | Fly to Cerulean, north onto Route 24, Surf west and south down Cerulean's river to the cave's ledge (1, 13), into `CeruleanCave_1F`; the screenshot. Needs Surf |

Optional on the way, not planned: the Ember Spa's HM06, Moltres at the summit, Lorelei's house,
the Rocket Warehouse's items, the other Sevii trainers.

### Field moves and the team

The save's party (01's runs): MIMIEN (Mr. Mime, Lv 33 or more), Blastoise (Lv 57 in the mg-03
snapshot, Surf, Bite, Blizzard, Strength), CH'DING (Farfetch'd), Pidgey (Fly), Rattata, Oddish
(Cut). So:

| Move | Where | Who |
|---|---|---|
| Surf | Kindle Road (09, 11), Four Island to Icefall Cave and its entrance (12, 13), Route 24 to the cave (17) | Blastoise |
| Strength | Ruby Path B2F and B3F (10) | Blastoise |
| Waterfall | Icefall Cave Entrance's falls (13) | Blastoise, taught from HM07 in 12 (over Bite) |
| Cut | Ruin Valley's door (14), from the party menu | Oddish |
| Fly | Pallet, Vermilion, Cerulean; Sevii towns if added | Pidgey |
| Rock Smash, Flash | not needed | |

Blastoise alone outclasses everything up to Mt. Ember. The Warehouse is the hard stretch: the Admins'
Houndoom and Weezing (Lv 55, 54) and Gideon's Electrode, Magneton and Voltorb against a Water
type. The save has 98 Rare Candies from tt-01; spending some on Blastoise (and on Mr. Mime as a
second battler) before 15 is the cheap fix.

## Missing features, in build order

Size: S a few days of one PR, M one feature PR with readers, L several PRs or a new walker mode.

1. **Trainer battles** (M-L), for 04 and every checkpoint after. The plan kinds `battle` and
   `train` decode (`Pokemon_action.Battle`, `Train of int`) but FireRed runs neither. Needed: a
   battle policy over `Scripted_battle` (lead and moves per foe type, switch on faint, a fallback
   move), the trainer's intro and defeat text settled, a whiteout seen as a failure, and a walk
   that resumes after `Walk_interrupts.Trainer_battle` (today it stops the walk). Battles in a
   scene (04's Bikers, 13's Grunt) are `scene` + `battle` events in turn.
2. **Wild battle after a talk** (S), for 05's Hypno: `Wild_flee` exists for walks; the event form,
   flee or fight, is missing.
3. **Ferry lists** (S-M), for 08 and 12 on: Vermilion's own list and the Rainbow Pass's paged
   lists in `Seagallop` (other `Script_menu` windows; the island lists with VERMILION are not on
   this route).
4. **Surf** (L), for 09 on: water in `Frlg_steps`, the "Want to SURF?" YES, water steps (wild
   battles on water), landing. The drafts rate it the second most used missing feature.
5. **Caught count** (S) and, if short, **a catching campaign** (L), for 07. The Trainer Card's
   front shows the Pokedex count; `capture` exists. The roadmap's old note was "the post-game save
   had a small Pokedex": likely far below 60, which makes this the biggest single item (A6's
   land-wild collector, pulled forward).
6. **Strength** (M), for 10: "Use STRENGTH?" YES, pushes as walk legs (the `legs` kind, decoded but
   not run on FireRed), boulders as walk state for the planner or pushes written into the plan.
   PokemonSimulation keeps boulders as people, not movable objects.
7. **Escape Rope from the bag** (S), for 10; or **Fly to a Sevii town** (S-M, the fly map's Sevii
   page), which also shortens 11 and 16.
8. **Teach an HM** (S-M), for 12: the bag's TM Case, the member, the move to forget.
9. **Ice and holes** (M), for 12 and 14: thin ice (`I`, cracks then drops), sliding ice (`i`),
   one-way holes (`H`) in `Frlg_steps`, which refuses all three today.
10. **Waterfall** (S), for 13: the prompt on a falls tile. The maps draw falls as plain water `w`, so
    the plan says where.
11. **Field move from the party menu** (S), for 14: Cut with no tree, from (24, 25) facing north.
12. **Spinners** (M), for 15: `u d l r o` in `Frlg_steps`, the slide as one move.

Trainer battles first: 04 is blocked on nothing else, and 05, 09, 13 and 15 reuse them. Then the
ferry lists and the caught count (both small, and the count decides whether 07 needs a campaign),
then Surf.

## Risks

- **60 caught.** Celio asks for the Ruby only with the National Dex. If the save is far short, a
  catching campaign is the longest item on this list. Read the count first.
- **Gideon and the Admins.** A lone Water-type Lv 57 against Lv 46-55 Electric and Fire teams may
  lose; level up with Rare Candies, or bring a second battler.
- **Landing points read as doors.** The generator marks a warp event on a plain floor tile, with
  no warp behavior, as `walk_into`. In the Dotted Hole each floor's landing (6, 7) is one; the
  player walks over 1F's on the way in, and a planner taking `walk_into` as a door would expect a
  warp there. The same pattern is in the Mansion and Seafoam; GamePilot's walker should treat a
  `walk_into` warp on a floor tile as an arrival only.
- **Waterfall tiles are water.** The map format has no falls glyph; 13's plan names the falls.
- **Icefall's ice.** B1F's sliding floor and 1F's thin ice are the only route to HM07; a wrong
  step drops the player back a floor. Plan it as fixed legs and check every leg on mGBA.

## Maps

PokemonSimulation has every map the route walks except Six Island's Dotted Hole (1F, B1F to B4F,
the Sapphire room), which the scope had excluded; #125 adds them as generated candidates. The
Pokemon Centers the route heals in (Three, Four, Five, Six Island, Cinnabar, Cerulean) are coded
rooms (`Frlg_overworld.Standard_center`).
