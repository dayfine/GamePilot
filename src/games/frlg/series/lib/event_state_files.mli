(** The save states an mGBA run keeps at each event's start, on disk
    (Pokemon_checkpoints.Event_states): saved through the daemon, one per event
    (the newest run's), and found again for a partial run (--from-event). *)

val keep :
  states:string ->
  checkpoint:string ->
  log:(string -> unit) ->
  Frlg_checkpoints.Checkpoint_run.keep_event_state
(** Saves the state at an event's start, with what the run read at the
    checkpoint's start, and prunes that event's older states; a save the daemon
    refuses is logged, not fatal. *)

val partial :
  states:string ->
  checkpoint:string ->
  Pokemon_checkpoints.Plan.checkpoint ->
  string * string option ->
  (string * Frlg_checkpoints.Checkpoint_run.from_event, string) result
(** [(from_event, to_event)]'s first event's kept state and the partial run from
    it. *)
