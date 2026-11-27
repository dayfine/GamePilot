(** The runner's steps on a console without save states (the Switch), around
    each run, as Checkpoints_series.Console_runs decides them: back to the last
    save (Frlg_actions.Soft_reset) and the start check
    (Frlg_checkpoints.Start_check) before; after, the in-game save and the next
    start's frame for a pass (Frlg_actions.Game_save), back to the last save for
    a failure. In the effect context. *)

open Pokemon_engine

val start_party :
  roster:string list -> Postconditions.t option -> Postconditions.party option
(** The party a checkpoint starts with: the one the checkpoint before it
    promised, else the roster given with --party. *)

val before :
  log:(string -> unit) ->
  picture:Wire.box ->
  home_tile:Switch.Home_screen.tile_color option ->
  frame_path:string option ->
  start_path:string option ->
  steps:Checkpoints_series.Console_runs.step list ->
  Postconditions.party option ->
  (unit, string) result
(** When [steps] includes [Return_to_save] (cold start, retry, or later trial),
    checks the initial screen ({!Switch.Initial_screen.check}, failing fast on a
    black screen and resuming from HOME when [home_tile] is known) and returns
    to the last save; when [steps] is empty (continuing directly from a passing
    checkpoint or round), skips both the initial-screen check and soft reset.
    Always runs the start check against the party and the frame kept under the
    checkpoint's id ([frame_path]) or at its start ([start_path]), keeping the
    frame read where none was kept. With neither (a checkpoint that starts
    anywhere outdoors has no one frame), the party only. *)

val after :
  log:(string -> unit) ->
  next_frame:string option ->
  Checkpoints_series.Console_runs.step list ->
  (unit, string) result
(** Runs the steps; [Error] when the in-game save failed (no step after it
    runs). *)
