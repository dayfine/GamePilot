# FRLG walkthrough coverage (draft, 2026-11-24)

What it would take to play FireRed from a new game to the post-game the way Bulbapedia's walkthrough
does ("Walkthrough:Pokémon FireRed and LeafGreen", Parts 1 to 20), checkpoint by checkpoint, and
which game actions, readers and fragments each checkpoint needs that GamePilot does not have. It is
for deciding what to build next; nothing here runs.

- **Drafts**: 61 checkpoint plans (13 optional) for Parts 2 and 7 to 20, in the plan shape of
  `src/games/frlg/programs/*/plans/` (`gamepilot-checkpoint/1`), with the 66 places they name. They
  are kept out of this note, in a reference PR (branch `docs/frlg-walkthrough-plan-drafts`), for
  future program PRs to start from; the tables below are counted from them.
- **Parts 1 to 8** are mostly drafted already: PokemonSimulation's `data/story/frlg-authored/`
  holds the fork's FRLG AutoStory plans 00.01 to 00.29 (new game to Lavender Town). They are listed
  here with what GamePilot lacks to run them; they are not copied.
- Words as in `docs/design/Programs-As-Goals.md` (program, goal, checkpoint, plan, event, place,
  fragment, checkpoint template).

## How the drafts are written

- Same shape as today's plans: `checkpoint.start`, `events` (`route`, `talk`, `scene`, `answer`,
  `battle`, `heal`, `save`, `game_action`), `metadata`. `metadata.phase` is `"draft"`.
- `metadata.goal_facts`: the end state, as facts a run could check: `badge: rainbow`, `key: tea`,
  `bag: hm03`, `party: lapras`, `flag: FLAG_...` (pret's flag names; GamePilot reads no flags, so a
  flag is checked through what it changes: a badge, a bag item, an npc gone).
- `metadata.needs`: every capability the plan uses that FireRed lacks, with `missing` or
  `partial`. The tables below and the ranking are counted from these. They were counted before #39 and #40, so
  `heal_at` still shows as missing.
- Route targets name a **place** (`"place": "erika_front"`), next to the map, tile and facing.
  Places and the `heal_at` fragment now exist (#39, #40): the expansion is
  `src/pokemon/checkpoints/expand/`, FireRed's data `src/games/frlg/places/places.json` (places and
  towns) and `src/games/frlg/fragments/fragments.json`; a program built from a draft adds its places
  to that table. Tiles are derived, never typed in: an npc's, item's
  or warp's coord in PokemonSimulation's runtime maps (submodule pin) and the open tile beside it.
  Where that is not possible (the map is missing, the spot is a script trigger, the tile is not open)
  the target has a `"todo": "TODO: ..."` instead of tiles: 167 TODO strings in all.
- Not decodable today: the drafts' `"kind": "fragment"` (#40 writes a call as
  `{"id": ..., "fragment": "heal_at", "args": {"town": "lavender"}}`, a town by its key in the
  places table's `towns`; `fight_trainer`, `buy` and
  `e4_room` do not exist yet) and
  game actions that do not exist yet (`teach`, `static_encounter`, `surf`, `push_boulder`, `ferry`,
  ...). `battle` events carry `opponent` and `policy` args the decoder does not read yet.
- Trainers whose lines a walk may cross are named in the event's `why`, from PokemonSimulation's
  npcs (`trainer.sight`).

## Coverage

| Part | Walkthrough | Today | Checkpoints |
|---|---|---|---|
| 1 | Introduction, Pallet Town, Oak's Lab, rival 1 | authored 00.01-00.04b | 6 authored |
| 2 | Route 1, Viridian City, the parcel, Route 22 | authored 00.06-00.07; drafted the gap | 2 authored, 2 drafts (1 opt.) |
| 3 | Viridian Forest, Pewter City, Brock | authored 00.08-00.10 | 3 authored |
| 4 | Route 3, Mt. Moon, Route 4 | authored 00.11-00.14 | 6 authored |
| 5 | Cerulean, Misty, Nugget Bridge, Bill, Route 5 | authored 00.14b-00.21 | 10 authored |
| 6 | Route 6, Vermilion, S.S. Anne, Lt. Surge | authored 00.22-00.26; tt-01, 02-trade-farfetchd touch Route 6 and Vermilion | 5 authored |
| 7 | Route 11, Diglett's Cave, Flash, Route 9, Route 10 | authored 00.27; 03-trade-mr-mime touches Route 2 east | 1 authored, 2 drafts (opt.) |
| 8 | Rock Tunnel, Lavender, Route 8, Route 7 | authored 00.28-00.29; drafted Route 8 to Celadon | 2 authored, 1 draft |
| 9 | Celadon, Erika, Rocket Hideout, Pokémon Tower | 01-celadon-setup, 08-activate-and-verify, su-01, tt-01 run in Celadon; story drafted | 8 drafts |
| 10 | Routes 12-18, Fuchsia, Koga, Safari Zone, Fly | 02-trade-farfetchd, 08-activate-and-verify run on Route 16; story drafted | 6 drafts |
| 11 | Saffron, Silph Co., Sabrina | drafted | 5 drafts (1 opt.) |
| 12 | Routes 19-20, Seafoam Islands | drafted | 3 drafts |
| 13 | Cinnabar, Mansion, Blaine, to the Sevii Islands | drafted | 4 drafts (1 opt.) |
| 14 | One to Three Island | drafted | 6 drafts (1 opt.) |
| 15 | Route 21, Power Plant, Giovanni | drafted | 3 drafts (2 opt.) |
| 16 | Route 22-23, Victory Road | 04-grind-farfetchd to 06-grind-return run at Indigo Plateau and Victory Road 2F; drafted | 3 drafts |
| 17 | Elite Four, Champion | drafted | 5 drafts |
| 18 | Post-game: One, Four, Six Island | drafted | 6 drafts (1 opt.) |
| 19 | Five and Seven Island | drafted | 4 drafts (2 opt.) |
| 20 | Cerulean Cave, the roamer, Elite Four rematch | drafted | 3 drafts (2 opt.) |

**What GamePilot's programs already cover.** None of them advances the story: they run on a late
save (Blastoise Lv 57 with Surf and Strength, every Kanto Fly town) and reuse story places. Their
events carry over to the drafts where they meet.

| Program | Places and actions | Walkthrough part |
|---|---|---|
| 01-celadon-setup | Fly to Celadon; Coin Case (restaurant); Dept. Store lift and 4F mart; Game Corner coins; prize Abra | 9 (side content; wt-09a's Coin Case) |
| 02-trade-farfetchd | Route 16 capture; Route 6 hidden Sitrus Berry; Vermilion trade (Ch'Ding) | 6, 10 |
| 03-trade-mr-mime | Route 2 east (Cut), the Mr. Mime trade; Lavender Mart; Lavender Center | 7, 8 |
| 04-grind-farfetchd to 06-grind-return | Escape Rope; Fly to Indigo Plateau; its nurse; Victory Road 2F grind | 16 |
| 07-glitch-prep | Route 16's cut tree (41, 11), Route 8's hidden Leppa Berry | 10 |
| 08-activate-and-verify | Route 16: Lea & Jed's double battle; Route 16 to Celadon Dept. Store | 9, 10 |
| su-01 | Celadon 4F, Lavender Mart | 8, 9 |
| tt-01 | Route 6's hidden Rare Candy | 6 |

Exists today in FireRed and used across the drafts: route walks planned on PokemonSimulation's maps
(ledges, doors, ladders, step-on warps, cut trees, trainer lines avoided), `talk`, `scene`, `heal`,
`save`, `ready`, `fly` (13 Kanto towns), `lift_floor` (Celadon), `mart` (11 Kanto marts),
`cut_tree`, `pick_up_item`, `use_item`, `give_bag_item`, `party_swap`, `capture` (wild grass),
`grind`, `pc_deposit`, `ingame_trade`, `candy_level`, fleeing wild battles on a walk, scripted
battles (`Scripted_battle`), soft reset, make room in the party, `step` (one tile onto a scene's
trigger, nothing watched) and `train` (trainer battles in a row, `Trainer_battles`: the lead attacks
in slot order, a fainted lead loses; Sevii 04's Bikers).

## Parts 1 to 8: the authored chain

The fork's AutoStory plans, in PokemonSimulation. GamePilot decodes their format (its old name is
an alias) but FireRed's builtin events run only `route`, `ready`, `step`, `train`, `talk`, `answer`,
`scene`, `heal` and `save`: every other kind returns `not_implemented`. The table predates `step`
and `train`; a `battle` event with an `opponent` and a `policy` is still missing. What each needs:

| Plan | Title | Missing in GamePilot |
|---|---|---|
| 00.01 | new game to the bedroom | `new_game`, `options` |
| 00.01b | after SID Helper: close the Trainer Card, save in the bedroom | `close_trainer_card`, `options` |
| 00.02 | bedroom to Pallet Town | nothing |
| 00.03 | Oak stops the player and walks them to the lab | `step` |
| 00.04 | to Squirtle's ball, south of the table | nothing |
| 00.04b | Squirtle, then the rival's battle | `answer`, `step`, `battle` |
| 00.06 | Oak's Parcel to the Pokedex | nothing |
| 00.07 | Viridian shopping, then into Viridian Forest | `shop`, `step` |
| 00.08 | Viridian Forest to Pewter Center | `legs` |
| 00.09 | Pewter Gym: Camper Liam, then Brock | `step`, `battle` |
| 00.10 | Pewter: the Running Shoes from Oak's aide | `step` |
| 00.11 | Pewter Center, then Route 3's trainers | `legs`, `step`, `battle` |
| 00.12 | Route 3 and 4 to the Magikarp salesman | nothing |
| 00.12b | after Gift RNG: save with the Magikarp | `leave_gift_summary` |
| 00.12c | Route 4 Center: the Magikarp into BOX 1 | `pc` |
| 00.13 | Mt. Moon: a Moon Stone, a Rocket, Miguel and the Helix Fossil | `legs`, `step`, `battle`, `fossil` |
| 00.14 | Route 4: Mega Kick from its tutor, then east to Cerulean's Pokemon Center | `teach`, `step`, `legs` |
| 00.14b | Cerulean: Potions, a GRIND to Lv23, then into the Gym, saved below Misty's platform | grind (fork args), `legs` |
| 00.14c | Cerulean Gym: Misty, then Water Pulse | `battle`, `legs`, `teach` |
| 00.15 | Cerulean: Water Pulse, Potions, a GRIND until the rival is winnable, then saved below his trigger | `teach`, grind (fork args) |
| 00.15b | Cerulean: Water Pulse if not known, then the rival north of the city | `teach`, `step`, `battle` |
| 00.16 | Nugget Bridge: the nurse, five trainers and the Rocket | `step`, `battle`, `legs` |
| 00.17 | Route 24 and 25 to Bill's Sea Cottage: Franklin, Kelsey, Nob and Haley | `step`, `battle`, `legs` |
| 00.18 | Bill's Sea Cottage: the Cell Separator and the S.S. Ticket | `answer`, `legs` |
| 00.19 | Route 25's south path back to Cerulean's Pokemon Center | `step` |
| 00.20 | Route 24's grass: an Oddish for Cut, then the Center | nothing |
| 00.21 | The Cerulean Rocket, Route 5, the Underground Path and Route 6 to Vermilion's Pokemon Center: Jeff | `step`, `battle`, `legs` |
| 00.22 | The S.S. Anne: the rival, HM01 Cut from the Captain, back to Vermilion's Pokemon Center | `step`, `legs`, `battle` |
| 00.23 | Vermilion Gym: Cut and Dig, the tree, Dwayne, Baily and Tucker, the trash cans | `teach`, `legs`, `step`, `battle`, `trash_cans` |
| 00.24 | Route 6's grass until Lt. Surge is winnable, then through the open beams to him | `grind_check`, `legs`, grind (fork args) |
| 00.25 | Vermilion Gym: Lt. Surge, the THUNDERBADGE, then the Center | `battle` |
| 00.26 | The BIKE VOUCHER from the Fan Club, back north to Cerulean, the BICYCLE, Repels and Escape Ropes | `answer`, `legs` |
| 00.27 | East over Route 9 to Route 10's Pokemon Center: the two trees, Alicia, Jeremy and Conner | `step`, `battle`, `legs` |
| 00.28 | Through Rock Tunnel: Ashton, Winston, Martha, Allen, Lenny, Sofia, Dudley, Cooper and Dana | `step`, `legs`, `battle` |
| 00.29 | Route 10 south to Lavender Town's Pokemon Center | `legs`, `step` |

Porting them is the cheapest large step: `battle`, `step`/`trainer_line`/`trainer_wait` and `legs`
alone make 19 of the 35 runnable (5 need nothing new), and the fork's C++ is there to port transparently. Their tiles were
checked on the console by the fork.

### Part 2: Route 1, Viridian City, Oak's Lab, Route 22

00.04b ends in Oak's Lab and 00.06 starts in the Viridian Mart: wt-02a is the walk between. Rival 2
on Route 22 is an optional detour (wt-02b).

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-02a** Oak's Lab to the Viridian Mart: the parcel errand | PalletTown_ProfessorOaksLab | map: ViridianCity_Mart | route walk, save |  |
| **wt-02b** (opt.) Route 22: rival battle 2 (optional detour) | ViridianCity_PokemonCenter_1F | rival 2 beaten (VAR_MAP_SCENE_ROUTE22); money +$144 | route walk, talk / scene, heal (nurse), save | battle, battle_policy, heal_at |

### Part 7: Route 11, Diglett's Cave, Route 2 east, Route 9, Route 10

Only Route 9 is on the story path (00.27). Flash, the Itemfinder and the Old Amber are optional:
00.28 crosses Rock Tunnel without Flash.

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-07a** (opt.) Diglett's Cave to Route 2 east: HM05 Flash, the Mr. Mime trade house (optional) | VermilionCity_PokemonCenter_1F | key: hm05 (FLAG_GOT_HM05); precondition: Pokedex caught >= 10 | route walk, cut_tree, talk / scene, save | dex_count_reader, trainer_interrupt, map DiglettsCave_SouthEntrance, map DiglettsCave_NorthEntrance, map DiglettsCave_B1F |
| **wt-07b** (opt.) Pewter Museum: the Old Amber (optional) | PewterCity_PokemonCenter_1F | key: old-amber (FLAG_GOT_OLD_AMBER) | cut_tree, route walk, talk / scene, save |  |

### Part 8: Rock Tunnel, Lavender Town, Route 8, the Underground Path, Route 7

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-08a** Lavender to Celadon: Route 8, the Underground Path, Route 7 | LavenderTown_PokemonCenter_1F | map: CeladonCity_PokemonCenter_1F | route walk, heal (nurse), save | trainer_interrupt, map CeladonCity_PokemonCenter_1F |

## Parts 9 to 20: drafted

### Part 9: Celadon City, Celadon Gym, Rocket Hideout, Pokémon Tower

The Game Corner's hidden stairs, the Hideout's spinners and lift, and the Tower's script triggers
(rival 5, Marowak, the healing zone) are the new kinds of terrain.

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-09a** Celadon: the Tea (Mansion 1F) and the Coin Case (restaurant) | CeladonCity_PokemonCenter_1F | key: tea (FLAG_GOT_TEA); key: coin-case (FLAG_GOT_COIN_CASE) | route walk, talk / scene, heal (nurse), save | heal_at, map CeladonCity_PokemonCenter_1F |
| **wt-09b** Celadon Gym: Erika, the Rainbow Badge | CeladonCity_PokemonCenter_1F | badge: rainbow (FLAG_BADGE04_GET); flag: FLAG_DEFEATED_ERIKA; bag: tm19 (FLAG_GOT_TM19_FROM_ERIKA) | route walk, cut_tree, talk / scene, heal (nurse), save | battle, battle_policy, heal_at, trainer_interrupt, map CeladonCity_PokemonCenter_1F |
| **wt-09c** Game Corner: the Rocket at the poster, the switch, into the Hideout | CeladonCity_PokemonCenter_1F | map: RocketHideout_B1F | route walk, talk / scene, save | battle, check_object, story_gates, map CeladonCity_PokemonCenter_1F |
| **wt-09d** Rocket Hideout B1F to B4F: the spinner mazes, the Lift Key | RocketHideout_B1F | key: lift-key (FLAG_HIDE_LIFT_KEY set) | route walk, talk / scene, pick_up_item, save | fight_trainer, battle, spin_tiles, trainer_interrupt |
| **wt-09e** Hideout B4F by the lift: two Grunts, Giovanni, the Silph Scope | RocketHideout_B4F | key: silph-scope; flag: FLAG_HIDE_HIDEOUT_GIOVANNI | route walk, talk / scene, pick_up_item, heal (nurse), save | elevator, battle, battle_policy, heal_at, spin_tiles, map RocketHideout_Elevator |
| **wt-09f** The Tea for Saffron's guard; through Saffron to Lavender | CeladonCity_PokemonCenter_1F | story: Saffron's gates open (the Tea given; VAR in pret's gate scripts) | route walk, talk / scene, heal (nurse), save | trainer_interrupt, map CeladonCity_PokemonCenter_1F |
| **wt-09g** Pokemon Tower 1F to 5F: rival 5, the Channelers, the healing zone | LavenderTown_PokemonCenter_1F | flag: rival 5 beaten; party full HP (the zone) | route walk, talk / scene, save | battle, battle_policy, trainer_interrupt, fight_wild_on_walk |
| **wt-09h** Pokemon Tower 6F and 7F: Marowak, the Rockets, Mr. Fuji, the Poke Flute | PokemonTower_5F | key: poke-flute (FLAG_GOT_POKE_FLUTE); flag: FLAG_RESCUED_MR_FUJI | route walk, talk / scene, heal (nurse), save | static_encounter, battle, fight_trainer, heal_at, trainer_interrupt, battle_policy |

### Part 10: Routes 12 to 18, Fuchsia City, Koga, the Safari Zone, Fly

The first static encounters (two Snorlax), the Safari Zone's step budget and battle menu, the
Bicycle on Cycling Road, and three HMs to teach.

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-10a** Route 12: wake the Snorlax with the Poke Flute | LavenderTown_PokemonCenter_1F | flag: FLAG_HIDE_ROUTE_12_SNORLAX | route walk, talk / scene, save | answer, static_encounter, battle, trainer_interrupt |
| **wt-10b** Routes 12 to 15 to Fuchsia City | Route12 | map: FuchsiaCity_PokemonCenter_1F | route walk, heal (nurse), save | trainer_interrupt, map FuchsiaCity_PokemonCenter_1F |
| **wt-10c** Fuchsia Gym: the invisible walls, Koga, the Soul Badge | FuchsiaCity_PokemonCenter_1F | badge: soul (FLAG_BADGE05_GET); flag: FLAG_DEFEATED_KOGA; bag: tm06 | route walk, talk / scene, heal (nurse), save | battle, battle_policy, heal_at, trainer_interrupt, map FuchsiaCity_PokemonCenter_1F |
| **wt-10d** Safari Zone: the Gold Teeth and HM03 Surf inside 600 steps | FuchsiaCity_PokemonCenter_1F | bag: hm03 (FLAG_GOT_HM03); bag: gold-teeth; money -$500 | route walk, talk / scene, pick_up_item, save | answer, safari, step_budget, map FuchsiaCity_PokemonCenter_1F |
| **wt-10e** The Warden's HM04 Strength; teach Surf and Strength | FuchsiaCity_SafariZone_Entrance | bag: hm04 (FLAG_GOT_HM04); party: a member knows surf; party: a member knows strength | route walk, talk / scene, heal (nurse), save | teach, heal_at |
| **wt-10f** Route 18 and Cycling Road north to Route 16: Snorlax, HM02 Fly | FuchsiaCity_PokemonCenter_1F | bag: hm02 (FLAG_GOT_HM02); flag: FLAG_HIDE_ROUTE_16_SNORLAX; party: a member knows fly | route walk, talk / scene, cut_tree, fly (Kanto), heal (nurse), save | use_key_item, answer, static_encounter, battle, teach, heal_at, bike, trainer_interrupt, map FuchsiaCity_PokemonCenter_1F, map Route17 |

### Part 11: Saffron City, Silph Co., Sabrina

Silph Co. is warp pads, Card Key doors (PokemonSimulation has the 20 doors as gates) and the
elevator. The Lapras is the first gift Pokémon on the path.

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-11a** Silph Co. 1F to 5F: the warp panels, the Card Key | CeladonCity_PokemonCenter_1F | key: card-key (FLAG_HIDE_SILPH_CO_5F_CARD_KEY set) | route walk, pick_up_item, save | warp_pads, trainer_interrupt, elevator, map CeladonCity_PokemonCenter_1F, map SilphCo_Elevator |
| **wt-11b** Silph Co.: Card Key doors to 7F: rival 6 and the Lapras | SilphCo_5F | party: lapras (FLAG_GOT_LAPRAS_FROM_SILPH); flag: rival 6 beaten | route walk, talk / scene, save | card_key_door, battle, battle_policy, gift_pokemon, story_gates, warp_pads |
| **wt-11c** Silph Co. 11F: Giovanni, the Master Ball | SilphCo_7F | bag: master-ball (FLAG_GOT_MASTER_BALL_FROM_SILPH) | route walk, talk / scene, use_item, heal (nurse), save | fight_trainer, battle, card_key_door, battle_policy, heal_at, story_gates, warp_pads |
| **wt-11d** Saffron Gym: the warp panels, Sabrina, the Marsh Badge | SaffronCity_PokemonCenter_1F | badge: marsh (FLAG_BADGE06_GET); flag: FLAG_DEFEATED_SABRINA | route walk, talk / scene, heal (nurse), save | battle, battle_policy, heal_at, warp_pads, trainer_interrupt, map SaffronCity_PokemonCenter_1F |
| **wt-11e** (opt.) Fighting Dojo: Hitmonlee or Hitmonchan (optional) | SaffronCity_PokemonCenter_1F | party: hitmonlee or hitmonchan (FLAG_GOT_HITMON_FROM_DOJO) | route walk, talk / scene, save | battle, battle_policy, gift_pokemon, map SaffronCity_PokemonCenter_1F, map SaffronCity_Dojo |

### Part 12: Routes 19 and 20, the Seafoam Islands

Surf and Strength together. Route 21 from Pallet reaches Cinnabar without Seafoam (wt-15a,
reversed) if Seafoam's boulders come late.

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-12a** Fuchsia south by Surf: Routes 19 and 20 to the Seafoam Islands | FuchsiaCity_PokemonCenter_1F | map: SeafoamIslands_1F | route walk, save | surf, trainer_interrupt, map FuchsiaCity_PokemonCenter_1F |
| **wt-12b** Seafoam Islands: drop the boulders, Articuno | SeafoamIslands_1F | flag: FLAG_HIDE_ARTICUNO (caught or fainted) | route walk, save, talk / scene | strength, static_encounter, battle, fall_holes, surf, soft_reset_retry |
| **wt-12c** Seafoam's west mouth, Route 20 west to Cinnabar Island | SeafoamIslands_B4F | map: CinnabarIsland_PokemonCenter_1F | route walk, heal (nurse), save | surf, trainer_interrupt, map CinnabarIsland_PokemonCenter_1F |

### Part 13: Cinnabar Island, the Mansion, Blaine

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-13a** Pokemon Mansion: the statue switches, the Secret Key | CinnabarIsland_PokemonCenter_1F | key: secret-key (FLAG_HIDE_POKEMON_MANSION_B1F_SECRET_KEY set) | route walk, pick_up_item, use_item, heal (nurse), save | mansion_switch, heal_at, story_gates, trainer_interrupt, ledge_drop, map CinnabarIsland_PokemonCenter_1F |
| **wt-13b** Cinnabar Gym: the quiz doors, Blaine, the Volcano Badge | CinnabarIsland_PokemonCenter_1F | badge: volcano (FLAG_BADGE07_GET); flag: FLAG_DEFEATED_BLAINE | route walk, talk / scene, save | gym_quiz, battle, battle_policy, answer, story_gates, map CinnabarIsland_PokemonCenter_1F |
| **wt-13c** Bill outside the Gym: the Seagallop to One Island | CinnabarIsland_Gym | map: OneIsland_Harbor | route walk, talk / scene, save | answer, ferry |
| **wt-13d** (opt.) Cinnabar Lab: revive a fossil (optional) | CinnabarIsland_PokemonCenter_1F | party: omanyte, kabuto or aerodactyl | route walk, talk / scene, save | gift_pokemon, map CinnabarIsland_PokemonCenter_1F, map CinnabarIsland_PokemonLab_ExperimentRoom, map CinnabarIsland_PokemonLab_Entrance |

### Part 14: One, Two and Three Island

The Seagallop ferry, a Center whose nurse stands elsewhere (One Island's nurse is at (5, 2), stand
(5, 4)), four battles in a row,
and scenes that move the player between islands.

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-14a** One Island: Celio, the Tri-Pass and the Meteorite | OneIsland_Harbor | key: tri-pass; key: meteorite | talk / scene, route walk, heal (nurse), save |  |
| **wt-14b** Kindle Road to the Ember Spa: HM06 Rock Smash | OneIsland_PokemonCenter_1F | bag: hm06 (FLAG_GOT_HM06) | route walk, talk / scene, save | teach, trainer_interrupt |
| **wt-14c** (opt.) Mt. Ember: the boulders and Moltres (optional) | OneIsland_KindleRoad_EmberSpa | flag: FLAG_HIDE_MOLTRES | route walk, save, talk / scene | strength, static_encounter, battle, rock_smash, soft_reset_retry |
| **wt-14d** The ferry to Three Island: four Bikers in a row | OneIsland_PokemonCenter_1F | flag: FLAG_HIDE_THREE_ISLAND_BIKERS | route walk, talk / scene, heal (nurse), save | ferry, answer, consecutive_battles, battle, heal_at, map ThreeIsland_PokemonCenter_1F |
| **wt-14e** Bond Bridge to Berry Forest: Lostelle and the Hypno | ThreeIsland_PokemonCenter_1F | flag: FLAG_RESCUED_LOSTELLE | route walk, talk / scene, save | static_encounter, battle, surf, trainer_interrupt, map ThreeIsland_PokemonCenter_1F |
| **wt-14f** Two Island: the Meteorite delivered; Bill's ferry back to Cinnabar | TwoIsland_JoyfulGameCorner | flag: FLAG_SEVII_DETOUR_FINISHED; bag: moon-stone | talk / scene, route walk, save | ferry, map TwoIsland_JoyfulGameCorner |

### Part 15: Route 21, the Power Plant, Viridian Gym

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-15a** (opt.) Route 21 by Surf: Cinnabar to Pallet Town (optional) | CinnabarIsland_PokemonCenter_1F | map: PalletTown | route walk, save | surf, trainer_interrupt, map CinnabarIsland_PokemonCenter_1F |
| **wt-15b** (opt.) Power Plant: Zapdos (optional) | Route10_PokemonCenter_1F | flag: FLAG_HIDE_ZAPDOS | fly (Kanto), route walk, save, talk / scene | surf, static_encounter, battle, soft_reset_retry |
| **wt-15c** Viridian Gym: Giovanni, the Earth Badge | ViridianCity_PokemonCenter_1F | badge: earth (FLAG_BADGE08_GET); flag: FLAG_DEFEATED_LEADER_GIOVANNI | fly (Kanto), route walk, talk / scene, heal (nurse), save | fight_trainer, battle, battle_policy, heal_at, spin_tiles |

### Part 16: Route 22, Route 23, Victory Road

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-16a** Route 22: rival 7; Route 23's badge guards to Victory Road | ViridianCity_PokemonCenter_1F | map: VictoryRoad_1F | route walk, talk / scene, save | battle, battle_policy, surf |
| **wt-16b** Victory Road: the boulders on the switches, to Indigo Plateau | VictoryRoad_1F | map: IndigoPlateau_PokemonCenter_1F | route walk, heal (nurse), save | strength, story_gates, trainer_interrupt |
| **wt-16c** Indigo Plateau: stock up for the Elite Four | IndigoPlateau_PokemonCenter_1F | bag: full-restore >= N; bag: revive >= N | save | buy |

### Part 17: the Elite Four and the Champion

Five battles with no nurse: the bag heals between them. Each room is a checkpoint (the game lets
the player save in the rooms), which makes `e4_room(member)` a template for the rematch.

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-17a** Elite Four 1: Lorelei | IndigoPlateau_PokemonCenter_1F | flag: FLAG_DEFEATED_LORELEI | route walk, talk / scene, save | battle, battle_policy, item_heal |
| **wt-17b** Elite Four 2: Bruno | PokemonLeague_BrunosRoom | flag: FLAG_DEFEATED_BRUNO | route walk, talk / scene, save | battle, battle_policy, item_heal |
| **wt-17c** Elite Four 3: Agatha | PokemonLeague_AgathasRoom | flag: FLAG_DEFEATED_AGATHA | route walk, talk / scene, save | battle, battle_policy, item_heal |
| **wt-17d** Elite Four 4: Lance | PokemonLeague_LancesRoom | flag: FLAG_DEFEATED_LANCE | route walk, talk / scene, save | battle, battle_policy, item_heal |
| **wt-17e** Champion: Blue; the Hall of Fame | PokemonLeague_ChampionsRoom | flag: FLAG_DEFEATED_CHAMP; flag: FLAG_SYS_GAME_CLEAR | route walk, talk / scene | battle, battle_policy, long_scene |

### Part 18: post-game, One, Four and Six Island

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-18a** (opt.) Pallet Town: Oak's National Pokedex (optional: 60 caught) | PalletTown_PlayersHouse_1F | flag: FLAG_SYS_NATIONAL_DEX; precondition: Pokedex caught >= 60 | route walk, talk / scene, save | dex_count_reader |
| **wt-18b** One Island: Celio's request; Mt. Ember's two Rockets (the passwords) | PalletTown | story: both Rocket Warehouse passwords heard (VARs/flags in pret) | route walk, talk / scene, save | fly_sevii, battle |
| **wt-18c** Ruby Path: Rock Smash, boulders, the Ruby | MtEmber_Exterior | key: ruby (FLAG_GOT_RUBY) | route walk, talk / scene, use_item, save | rock_smash, strength |
| **wt-18d** Celio's Rainbow Pass; the ferry to Four Island | MtEmber_Exterior | key: rainbow-pass; flag: FLAG_SYS_SEVII_MAP_4567 | route walk, talk / scene, save | fly_sevii, ferry |
| **wt-18e** Icefall Cave: the ice floors, HM07 Waterfall, Lorelei and the Rockets | FourIsland | bag: hm07; story: Icefall's Rockets beaten | route walk, pick_up_item, talk / scene, save | surf, teach, battle, ice_floor, fall_holes, waterfall, battle_policy |
| **wt-18f** Six Island: Ruin Valley, the Dotted Hole, the Sapphire stolen | FourIsland_PokemonCenter_1F | story: the Sapphire stolen (FLAG_HIDE_SAPPHIRE) | route walk, talk / scene, save | ferry, field_move_menu, fall_holes, map FourIsland_PokemonCenter_1F, map SixIsland_DottedHole_SapphireRoom, map SixIsland_DottedHole_1F, map SixIsland_DottedHole_B1F, map SixIsland_DottedHole_B4F |

### Part 19: Five and Seven Island

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-19a** Five Island: the Rocket Warehouse, its Admins, Gideon, the Sapphire | SixIsland_DottedHole_SapphireRoom | flag: FLAG_DEFEATED_ROCKETS_IN_WAREHOUSE; flag: FLAG_RECOVERED_SAPPHIRE | route walk, talk / scene, save | ferry, fight_trainer, battle, battle_policy, spin_tiles, map SixIsland_DottedHole_SapphireRoom |
| **wt-19b** One Island: the Sapphire to Celio | FiveIsland_RocketWarehouse | flag: FLAG_SYS_CAN_LINK_WITH_RS | route walk, talk / scene, save | fly_sevii |
| **wt-19c** (opt.) Five Island's side quests: Lemonade at Memorial Pillar, Lost Cave's Selphy, the Togepi Egg (optional) | FiveIsland | bag: tm42 (FLAG_GOT_TM42_AT_MEMORIAL_PILLAR); party: togepi egg (FLAG_GOT_TOGEPI_EGG) | route walk, talk / scene, save | battle, surf, map FiveIsland_MemorialPillar, map FiveIsland_LostCave_Entrance |
| **wt-19d** (opt.) Seven Island: Sevault Canyon, the Tanoby Key's boulders (optional) | SevenIsland | flag: FLAG_SYS_UNLOCKED_TANOBY_RUINS | route walk, save | strength, rock_smash, map SevenIsland_SevaultCanyon_TanobyKey |

### Part 20: Cerulean Cave, the roaming beast, the rematch

| Checkpoint | Start | Goal facts | Exists | Missing |
|---|---|---|---|---|
| **wt-20a** Cerulean Cave: Mewtwo | CeruleanCity_PokemonCenter_1F | flag: FLAG_HIDE_MEWTWO; party or box: mewtwo | route walk, save, talk / scene | surf, static_encounter, battle, rock_smash, soft_reset_retry |
| **wt-20b** (opt.) The roaming beast (optional) | anywhere | party or box: the beast | save | roamer |
| **wt-20c** (opt.) Elite Four rematch: Lorelei, Bruno, Agatha, Lance, rival 9 | IndigoPlateau_PokemonCenter_1F | flag: rematch beaten |  | e4_room, battle, battle_policy, item_heal |

## What to build next

Counted over the drafts' `needs` (all, and in brackets the required ones) and over the authored
plans 00.01 to 00.29 that use the capability. Size: S a day or two, M a few PRs, L a design note
first.

| # | Capability | Drafts (required) | Authored 00.xx (of 35) | Total | First part | Size | Note |
|---|---|---|---|---|---|---|---|
| 1 | `battle`: a trainer battle to its end | 33 (27) | 14 | 47 | 1-8 (authored), 2 | M | plan kind exists; FireRed runs only scripted battles (grind, Mail Glitch). Needs a default policy: lead's best move, switch on faint, lose = fail |
| 2 | `battle_policy`: battle policy per opponent (type matchups, switching, status cures) | 21 (18) | 0 | 21 | 2 | L | gyms, rivals, bosses, Elite Four |
| 3 | `trainer_interrupt`: fight a trainer who stops a walk, then resume | 20 (18) | 0 | 20 | 7 | M | Walk_interrupts raises Trainer_battle and the walk ends; routes with unavoidable lines need it |
| 4 | `step`, `trainer_line`, `trainer_wait` | 0 (0) | 18 | 18 | 1-8 (authored) | S | plan kind exists; the fork's trainer approach steps |
| 5 | `legs` (walk legs as written) | 0 (0) | 17 | 17 | 1-8 (authored) | S | plan kind exists |
| 6 | `heal_at(town)` fragment | 13 (12) | 0 | 13 | 2 | S | exists in #40 (open); counted as the plans that would call it |
| 7 | `surf`: Surf: start on water, walk water in the planner | 10 (7) | 0 | 10 | 12 | L | Water is a wall in Frlg_steps |
| 8 | `answer` (yes/no) | 6 (6) | 3 | 9 | 1-8 (authored), 10 | S | plan kind exists; FireRed's builtin returns not_implemented |
| 9 | `teach` (TM/HM) | 4 (4) | 5 | 9 | 1-8 (authored), 10 | M | the fork has it (authored 00.14, 00.23) |
| 10 | `static_encounter`: static encounter: talk-started battle to catch or defeat | 8 (6) | 0 | 8 | 9 | M | Snorlax, the birds, Mewtwo, Marowak, Hypno; `capture` covers wild grass only |
| 11 | `story_gates`: story gates in FireRed's planner (Card Key doors, Mansion switch, Victory Road, hidden stairs) | 6 (6) | 0 | 6 | 9 | M | Gate_state and the gates tables exist; Frlg_steps treats G as a wall except cut trees |
| 12 | `ferry`: Seagallop to an island | 6 (6) | 0 | 6 | 13 | M | talk to the sailor, pick from a list; Bill's scenes |
| 13 | `fight_trainer`: `fight_trainer(map, trainer)` fragment: step into the line from PokemonSimulation's npcs, battle | 5 (5) | 0 | 5 | 9 | M | the fork's trainer_line / trainer_wait steps, made data-driven |
| 14 | `strength`: Strength: push boulders, boulder positions as walk state | 5 (3) | 0 | 5 | 12 | L | boulders are npcs in PokemonSimulation; the fork has AutoStoryBoulders |
| 15 | `item_heal`: `heal_party_items`: Full Restore / Revive between battles | 5 (4) | 0 | 5 | 17 | M | reads HP and faints; use_item on a member exists |
| 16 | `spin_tiles`: spinner floors in the planner | 4 (4) | 0 | 4 | 9 | M | glyphs u d l r o are in the maps; Frlg_steps refuses them |
| 17 | `warp_pads`: warp pads (Silph Co., Saffron Gym) | 4 (4) | 0 | 4 | 11 | S | step_on warps are planned already; check the pads route |
| 18 | `soft_reset_retry`: save before, soft reset and retry a one-chance battle | 4 (2) | 0 | 4 | 12 | S | Soft_reset exists as a module, not as a checkpoint policy |
| 19 | `rock_smash`: Rock Smash | 4 (2) | 0 | 4 | 14 | S | like cut_tree; a wild battle may start |
| 20 | `story_grind`: the fork's story `grind` / `grind_check` args | 0 (0) | 3 | 3 | 1-8 (authored) | M | GamePilot's grind takes grind_strategies.json spots |
| 21 | `gift_pokemon`: receive, decline the nickname, room in the party | 3 (1) | 0 | 3 | 11 | S | Make_room exists |
| 22 | `fall_holes`: holes and drops in the planner | 3 (3) | 0 | 3 | 12 | S | H glyphs and drop warps are in the maps |
| 23 | `fly_sevii`: Fly to the Sevii Islands | 3 (3) | 0 | 3 | 18 | S | the Fly map's second page; island landings |
| 24 | `gift_screens`: `close_trainer_card`, `leave_gift_summary` | 0 (0) | 2 | 2 | 1-8 (authored) | S | RNG side steps |
| 25 | `new_game` / `options` | 0 (0) | 2 | 2 | 1-8 (authored) | S | Part 1 only |
| 26 | `dex_count_reader`: Pokedex caught count (Trainer Card) | 2 (0) | 0 | 2 | 7 | S | gates Flash, Exp. Share, National Dex |
| 27 | `elevator`: elevators other than Celadon's (Rocket Hideout, Silph Co.) | 2 (2) | 0 | 2 | 9 | S | lift_floor generalised; elevator maps not in PokemonSimulation |
| 28 | `card_key_door` | 2 (2) | 0 | 2 | 11 | S | face the door, A; sets the gate open |
| 29 | `fossil` (Mt. Moon's choice) | 0 (0) | 1 | 1 | 1-8 (authored) | S |  |
| 30 | `trash_cans` (Vermilion Gym) | 0 (0) | 1 | 1 | 1-8 (authored) | M | the switch pair search |
| 31 | `pc` (withdraw / deposit by slot and box) | 0 (0) | 1 | 1 | 1-8 (authored) | S | pc_deposit exists |
| 32 | `shop` kind (authored marts) | 0 (0) | 1 | 1 | 1-8 (authored) | S | `mart` exists with other args |
| 33 | `fight_wild_on_walk`: fight wild battles on a walk (`fight_wild`) | 1 (1) | 0 | 1 | 9 | S | route arg exists; the fork fights, GamePilot flees |
| 34 | `check_object`: A on a sign, poster or switch | 1 (1) | 0 | 1 | 9 | S | talk covers it if the reader accepts no-dialog outcomes |
| 35 | `safari`: Safari Zone: entry, the Safari battle menu (Run), the step count | 1 (1) | 0 | 1 | 10 | M |  |
| 36 | `bike`: the Bicycle: get on, ride, Cycling Road's slope | 1 (1) | 0 | 1 | 10 | M | Move_mechanics has no FireRed bike gait |
| 37 | `use_key_item` (Bicycle) | 1 (1) | 0 | 1 | 10 | S | register or use from the bag |
| 38 | `step_budget`: a walk's step count against a budget | 1 (1) | 0 | 1 | 10 | S | Safari's 600 steps |
| 39 | `mansion_switch` (statue: yes) | 1 (1) | 0 | 1 | 13 | S | flips the Mansion switch state |
| 40 | `ledge_drop`: balcony drops (Mansion) | 1 (1) | 0 | 1 | 13 | S | ledges are planned; check the balcony is one |
| 41 | `gym_quiz` (Cinnabar) | 1 (1) | 0 | 1 | 13 | S | answer per machine from pret's scripts |
| 42 | `consecutive_battles`: `train` kind: battles back to back | 1 (1) | 0 | 1 | 14 | S | plan kind exists; over `battle` |
| 43 | `buy`: `buy(items, mart)` fragment | 1 (1) | 0 | 1 | 16 | S | over `mart` |
| 44 | `long_scene`: long scenes (Hall of Fame, credits) and Continue | 1 (1) | 0 | 1 | 17 | S |  |
| 45 | `ice_floor`: ice and cracked floors | 1 (1) | 0 | 1 | 18 | M | Icefall Cave |
| 46 | `waterfall`: Waterfall | 1 (1) | 0 | 1 | 18 | S |  |
| 47 | `field_move_menu`: field move from the party menu (Cut on the Braille door) | 1 (1) | 0 | 1 | 18 | S |  |
| 48 | `roamer`: roamer hunt | 1 (0) | 0 | 1 | 20 | M |  |
| 49 | `e4_room`: `e4_room(member)` checkpoint template | 1 (0) | 0 | 1 | 20 | S | made from wt-17 |

**The next program** after the structure work is the Sevii Islands story with the three
legendary birds (Moltres on Mt. Ember, Articuno in Seafoam, Zapdos in the Power Plant), from a
post-Elite Four save: Parts 18 and 19 of this note, with the birds of Parts 12, 14 and 15. Its preconditions are read off the
Trainer Card (badges), and its first checkpoint flies to Vermilion for the Seagallop. Its drafts
(`sb-01` to `sb-10`) are the most complete in the drafts PR. It needs, from the list below:
`static_encounter` with the soft-reset retry, `ferry`, Surf, Strength, Rock Smash, holes, spinners,
`battle` with a policy, and a Trainer Card reader.

**Top ten**, in the order that unblocks the most:

1. `battle` with a default policy (47): the authored chain's 14 battle checkpoints and 33 drafts.
   `Scripted_battle` is the engine; the missing part is the story event and a default script.
2. `step` / `trainer_line` / `trainer_wait` and `legs` (18 and 17 authored): small ports that,
   with `battle`, run most of Parts 1 to 8.
3. Per-opponent battle policy (21): gyms, rivals, Giovanni, the Elite Four. A design note first
   (type data from pret, when to switch, when to heal).
4. Trainers met on a walk (20): fight the battle `Walk_interrupts.Trainer_battle` stops for, then
   re-plan from where it left the player. Routes 8, 12 to 15, 18 and every cave need it.
5. Places and `heal_at` (13 drafts, and the 20 `heal` events of the authored chain): built in #39
   and #40 (Programs-As-Goals step 4). What is left is data: a place per Center from Celadon on
   (their maps are missing too) and per draft target; 62 route targets already name one.
6. Surf (10): water in FireRed's step model, the "Want to Surf?" prompt, landing. From Part 12 on,
   most checkpoints cross water.
7. `teach` and `answer` (9 each): small, and the fork has both.
8. Static encounters (8): Snorlax twice, the birds, Marowak, Hypno, Mewtwo; with the soft-reset
   retry (4) for the one-chance ones.
9. Story gates in FireRed's planner (6) and `card_key_door` / `mansion_switch` / `gym_quiz`:
   PokemonSimulation already models the gates and the Mansion's switch.
10. The Seagallop `ferry` and Fly's Sevii page (6 and 3): nothing after Part 13 runs without them.

**Cross-cutting gaps**

- **Trainer and gym battles with a policy.** The largest gap. FireRed runs only scripted battles
  today; the story needs a battle event that ends in a win, a loss (fail the checkpoint), or a
  fainted lead (send the next). Gyms and the Elite Four need type matchups and healing.
- **Strength and boulders** (Seafoam, Victory Road, Mt. Ember, Ruby Path, Tanoby Key). Boulders are
  npcs in PokemonSimulation; their positions become walk state, as cut trees are now
  (`Frlg_steps.cut`). The fork's AutoStoryBoulders is the source.
- **Surf movement.** Water is a wall in `Frlg_steps`; Surf needs the prompt, water steps, landing,
  and swimmers' trainer lines.
- **Special floors.** Spinners (Rocket Hideout, Viridian Gym, Rocket Warehouse), holes (Seafoam,
  Dotted Hole), ice (Icefall Cave). The glyphs are in the maps; `Frlg_steps` refuses them.
- **Cutscenes and script triggers.** Rival 5, Marowak, Blue on Route 22, the badge guards, Bill,
  Lostelle and Selphy walking the player elsewhere. `scene` clears dialog; a trigger tile is a
  pret coord event that PokemonSimulation does not carry yet, so those targets are TODO.
- **Safari Zone.** Its own battle menu (Ball, Bait, Rock, Run), 600 steps, the PA's time-up warp.
- **Silph Co.** Pads (step-on warps, likely planned already), Card Key doors (gates), the elevator
  (map missing).
- **Sevii.** The ferry, Fly's second page, Centers whose nurse stands elsewhere (each Center's stand
  tile is its own place: Lavender (7, 4), Indigo Plateau (13, 12), One Island (5, 4)), Sevii marts missing
  from `kanto_mart_stocks.json`.
- **Item healing.** The Elite Four and the long caves need Full Restores and Revives used on
  members by HP, not the nurse.
- **Readers.** The Trainer Card's caught count (Flash, Exp. Share, National Dex). Its badges and
  its Hall of Fame star are read (`Trainer_card_badges`, a plan's `badges` and `hall_of_fame`
  preconditions).

**Maps missing from PokemonSimulation** (first part in brackets). Every Center from Celadon on is
missing, so `heal_at` there has no map to walk:

`DiglettsCave_B1F` (7), `DiglettsCave_NorthEntrance` (7), `DiglettsCave_SouthEntrance` (7), `CeladonCity_PokemonCenter_1F` (8), `RocketHideout_Elevator` (9), `FuchsiaCity_PokemonCenter_1F` (10), `Route17` (10), `SaffronCity_Dojo` (11), `SaffronCity_PokemonCenter_1F` (11), `SilphCo_Elevator` (11), `CinnabarIsland_PokemonCenter_1F` (12), `CinnabarIsland_PokemonLab_Entrance` (13), `CinnabarIsland_PokemonLab_ExperimentRoom` (13), `ThreeIsland_PokemonCenter_1F` (14), `TwoIsland_JoyfulGameCorner` (14), `FourIsland_PokemonCenter_1F` (18), `SixIsland_DottedHole_1F` (18), `SixIsland_DottedHole_B1F` (18), `SixIsland_DottedHole_B4F` (18), `SixIsland_DottedHole_SapphireRoom` (18), `FiveIsland_LostCave_Entrance` (19), `FiveIsland_MemorialPillar` (19), `SevenIsland_SevaultCanyon_TanobyKey` (19)

**Fragments and templates that recur.** Counted in the drafts (checkpoints in brackets):

| Fragment / template | Uses | Note |
|---|---|---|
| route to a place (`{"place": ...}` target) | 62 (43) | exists (#39, #40); of 142 route events, the rest are TODO targets |
| `heal_at(town)` | 13 (13), plus 6 `heal` | exists (#40); and 20 `heal` events in the authored chain |
| `fight_trainer(map, trainer)` | 9 (5) | blocking trainers; the authored chain's 50 `step` events are the same idea |
| `fly` then a walk (`fly_and_walk`) | 5 (5) | of 6 Flys; grows once Fly is taught in wt-10f |
| `ferry(island)` | 6 (6) | Sevii |
| `e4_room(member)` | 5 (1) | the rematch from wt-17's plans |
| `buy(items, mart)` | 1 (1) | Indigo Plateau; Supplies' generator covers the rest |
| `pick_up_item` on a key item | 6 (6) | Lift Key, Silph Scope, Card Key, Gold Teeth, Secret Key, HM07 |
