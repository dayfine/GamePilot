(** A capture's search for a wild battle: stepping [pace] and back in the patch,
    from where the last battle left the player. Ported from the fork's
    pace_until_battle() and [PaceSpot]/[PatchSteps]
    (Programs/AutoStory/PokemonFRLG_AutoStoryCapture) and find_paced_encounter()
    (_AutoStoryPacing). The game steps come as {!steps}, so the search runs on a
    fake in tests; {!Pacing_steps} is the game's.

    Where it differs: no select_off_bike(): GamePilot has no reader for the
    Bicycle's sprite, and the walks to a patch are on foot. *)

type spot = {
  displaced : bool;
      (** One tile [pace] from the patch's tile, as the last step left it. *)
  facing : Grid_geometry.Direction.t option;
      (** The way the player faces after its last step, if known. *)
}

val on_patch : Grid_geometry.Direction.t option -> spot
(** On the patch's tile, facing that way. *)

val way : pace:Grid_geometry.Direction.t -> spot -> Grid_geometry.Direction.t
(** The next step's way: [pace], or back once displaced. *)

val after_step : pace:Grid_geometry.Direction.t -> spot -> spot
(** Where that step leaves the player. *)

val stands_on :
  pace:Grid_geometry.Direction.t ->
  spot ->
  Grid_geometry.Tile_pos.t ->
  Grid_geometry.Tile_pos.t
(** The tile the player stands on, from the patch's tile. *)

val spot_at :
  pace:Grid_geometry.Direction.t ->
  patch:Grid_geometry.Tile_pos.t ->
  Grid_geometry.Tile_pos.t ->
  Grid_geometry.Direction.t option ->
  spot option
(** The spot of a player reckoned on this tile, facing that way: on the patch,
    one tile [pace] from it, or [None] (somewhere else: pacing would walk off).
    The inverse of {!stands_on}. *)

type steps = {
  step : unit -> bool;
      (** One step, {!way}: whether a battle's flash showed. *)
  battle_shows : unit -> bool;
  overworld_shows : unit -> bool;  (** No text or menu open. *)
  message_shows : unit -> bool;
      (** A message on the overworld: a trainer who saw the player. *)
  fight_trainer : unit -> string;
      (** From that message: the trainer's battle, then the player back on the
          patch's tile. Returns who was fought. *)
  log : string -> unit;
}

val max_steps : int
(** 200 (PACE_MAX_STEPS): about 10 % of steps in grass start a battle. *)

val pace_until_battle : steps -> max_steps:int -> bool
(** From the overworld, in the patch: steps until a wild battle starts. A battle
    whose flash was missed is found by its screen after the step; a trainer who
    speaks is fought and pacing goes on. False if no battle came. *)
