(** The game's {!Pacing.steps}, as the fork's ConsolePatchSteps and
    ConsoleCaptureActions::find_encounter()
    (Programs/AutoStory/PokemonFRLG_AutoStoryCaptureConsole) press and read: a
    step is step_once() (Programs/AutoStory/PokemonFRLG_AutoStoryActions), a
    turn tap first when the player faces another way, then a walking step tap,
    watched for a battle's flash ({!Frlg_overworld.Battle_flash}).

    Where it differs:
    - The turn is one tap, not turn_to()'s tap-and-read until the sprite faces
      the way: GamePilot has no facing reader. An unknown facing is turned, as
      turn_to() taps when its read says another way.
    - A trainer who speaks during pacing fails the search ([pace_trainer]): the
      trainer's battle is not ported. Route 16's patch has none in sight.
    - No debug image of a screen that is neither the overworld nor a battle. *)

val overworld_shows : unit -> bool
(** The fork's overworld_shows(): START opens the Start menu only on the
    overworld, and B closes it again. *)

val find_encounter :
  log:(string -> unit) -> pace:Grid_maps.Direction.t -> Pacing.spot ref -> bool
(** From the overworld, in the patch, from [spot] (which each step updates, so
    the next search starts where this one left the player): steps until a wild
    battle starts, {!Pacing.max_steps} at most; {!overworld_shows} tells a
    battle that ended from one still showing. *)
