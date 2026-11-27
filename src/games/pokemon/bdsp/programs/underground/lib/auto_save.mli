(** Periodic Grand Underground auto-save ([X -> R -> A]) so collected Mysterious
    Shards are persisted to the Switch save during long unattended runs. *)

val maybe_save :
  log:(string -> unit) ->
  picture:Wire.box ->
  cycle_idx:int ->
  prev_shards:int ->
  Bdsp_underground.Mining_counters.t ->
  unit
(** Save the game if new Mysterious Shards were collected on this cycle, or
    every 3 completed cycles with at least one dig. *)
