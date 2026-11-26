(** Where a walk crosses the sight of the trainers on the maps, and how long a
    trainer who saw the player takes to walk up and speak. Ported from the
    fork's Overworld/PokemonFRLG_OverworldMap (a trainer who wanders may look
    from any tile of their box, each way they look) and
    Overworld/PokemonFRLG_OverworldTrainerCrossing.

    The game checks a trainer's sight as the player finishes each step; a
    trainer who sees the player freezes them on that tile, shows a "!", walks up
    and speaks, and the battle leaves the player facing the way they stepped
    (pokefirered src/trainer_see.c). *)

open Grid_maps
open Grid_geometry

type trainer = { map : int; at : Tile_pos.t }
(** A trainer, by their map and the tile the map puts them on, as the fork tells
    trainers apart. *)

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
    tile beside the player toward each tile they may have looked from, as the
    fork's Overworld/PokemonFRLG_OverworldReanchor puts them. *)

val notice_ms : int
(** 1500: from the step a trainer saw to the start of their walk up, the "!"
    (the fork's Overworld/PokemonFRLG_OverworldTrainerCrossing; not measured on
    the console). *)

val speaks_ms : int
(** 1000: from the walk up's end to the trainer's text (the fork's, same file).
*)

val full_watch_ms : approach_tiles:int -> int
(** How long the fork watches after a seen step: {!notice_ms}, a walking tile
    for each of [approach_tiles], then {!speaks_ms}. *)
