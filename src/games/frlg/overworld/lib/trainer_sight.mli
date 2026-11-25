(** Where a walk crosses the sight of the trainers on the maps, and how long a
    trainer who saw the player takes to walk up and speak. Ported from the
    fork's Overworld/PokemonFRLG_OverworldMap ([trainer_may_see()]: a trainer
    who wanders may look from any tile of their box, each way they look) and
    PokemonFRLG_OverworldTrainerCrossing ([trainer_crossing()],
    [trainer_full_watch()]).

    The game checks a trainer's sight as the player finishes each step
    (pokefirered [CheckForTrainersWantingBattle]); a trainer who sees the player
    freezes them on that tile, shows a "!", walks up and speaks, and the battle
    leaves the player facing the way they stepped (trainer_see.c,
    [TrainerSeeFunc_PrepareToEngage]). *)

open Grid_maps
open Grid_geometry

type trainer = { map : int; at : Tile_pos.t }
(** A trainer, by their map and the tile the map puts them on (the fork's
    [trainer_id()]). *)

val seeing :
  Frlg_steps.world ->
  beaten:trainer list ->
  Connected_maps.place ->
  trainer list
(** The trainers on the place's map, shown and not in [beaten], who may see its
    tile: from any tile they may stand on, along each way they look, up to their
    sight and stopping at a wall. *)

val sight_onto :
  Frlg_steps.world -> beaten:trainer list -> Connected_maps.place -> int
(** The farthest sight of {!seeing}'s trainers: how far one may walk up. 0 when
    none may see the tile. *)

val walked_up :
  Frlg_steps.world ->
  trainer ->
  Connected_maps.place ->
  Connected_maps.place list
(** Where the trainer may stand once walked up to the player on the place: the
    tile beside the player toward each tile they may have looked from (the
    fork's [add_trainer_stops()], Overworld/PokemonFRLG_OverworldReanchor). *)

val notice_ms : int
(** 1500: from the step a trainer saw to the start of their walk up, the "!"
    (the fork's [TRAINER_NOTICE]; not measured on the console). *)

val speaks_ms : int
(** 1000: from the walk up's end to the trainer's text (the fork's
    [TRAINER_SPEAKS]). *)

val full_watch_ms : approach_tiles:int -> int
(** The fork's [trainer_full_watch()]: {!notice_ms}, a walking tile for each of
    [approach_tiles], then {!speaks_ms}. *)
