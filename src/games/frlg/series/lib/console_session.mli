(** The runner's steps on a console without save states (the Switch), around
    each run, as Checkpoints_series.Console_runs decides them: back to the last
    save (Frlg_actions.Soft_reset) and the start check
    (Frlg_checkpoints.Start_check) before; after, the in-game save and the next
    start's frame for a pass (Frlg_actions.Game_save), back to the last save for
    a failure. In the effect context. *)

open Pokemon_checkpoints

val start_party :
  roster:string list -> Postconditions.t option -> Postconditions.party option
(** The party a checkpoint starts with: the one the checkpoint before it
    promised, else the roster given with --party. *)

val before :
  log:(string -> unit) ->
  frame_path:string ->
  start_path:string option ->
  Postconditions.party option ->
  (unit, string) result
(** Back to the last save, then the start check against the party and the frame
    kept under the checkpoint's id (or at its start), keeping the frame read
    where none was kept. *)

val after :
  log:(string -> unit) ->
  next_frame:string option ->
  Checkpoints_series.Console_runs.step list ->
  (unit, string) result
(** Runs the steps; [Error] when the in-game save failed (no step after it
    runs). *)
