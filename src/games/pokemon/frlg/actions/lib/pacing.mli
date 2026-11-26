(** A capture's search for a wild battle: stepping [pace] and back in the patch,
    from where the last battle left the player. Ported from the fork's
    pace_until_battle() and [PaceSpot]/[PatchSteps]
    (Programs/AutoStory/PokemonFRLG_AutoStoryCapture) and find_paced_encounter()
    (_AutoStoryPacing). The game steps come as {!steps}, so the search runs on a
    fake in tests; {!Pacing_steps} is the game's.

    Where it differs:
    - No select_off_bike(): GamePilot has no reader for the Bicycle's sprite,
      and the walks to a patch are on foot.
    - The fork counts every step that a flash or a battle's screen followed as
      walked. Here a battle the step's turn started (its flash sooner than the
      walk could end), or one whose flash was missed (its wipe, or its screen
      after the step), leaves the player on the tile. *)

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

(** What a step's watch saw of a battle's start. *)
type sign =
  | Flash_after of float
      (** the battle's flash, this many ms after the step's first press *)
  | Going_black  (** the screen going black: the battle's wipe *)

(** What a step did. The game looks for a wild battle at the end of a walk and
    at the end of a turn on the spot. *)
type stepped =
  | Walked  (** no battle showed: the step walked *)
  | Battle_on_walk  (** the step walked, and its flash showed after the walk *)
  | Battle_on_turn
      (** the flash showed before the walk could end: the step's turn started
          the battle, and the player faces the step's way on the same tile *)
  | Battle_unflashed
      (** the battle's wipe, its flash missed: a battle started before the step,
          which did not move the player *)

val stepped : walk_ms:float -> sign option -> stepped
(** A step's end from what its watch saw: [walk_ms] is how long after the step's
    first press its own walk ends (a turn tap, then the tile). *)

type steps = {
  step : spot -> stepped;
      (** One step from the spot, {!way}, watched for a battle's start. *)
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

val pace_until_battle :
  steps -> pace:Grid_geometry.Direction.t -> spot ref -> max_steps:int -> bool
(** From the overworld, in the patch, from [spot]: steps until a wild battle
    starts, moving [spot] with each step that walked or turned, so the next
    search starts where this one left the player. A battle whose flash was
    missed is found by its wipe or its screen after the step. A trainer who
    speaks is fought and pacing goes on. False if no battle came. *)
