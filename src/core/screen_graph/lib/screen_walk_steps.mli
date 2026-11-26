(** Live {!Screen_walk.game_steps} built on {!Effects} and {!Held_screen}. *)

val make :
  log:(string -> unit) -> 'screen Graph.t -> 'screen Screen_walk.game_steps
(** Build {!Screen_walk.game_steps} that reads frames via
    {!Held_screen.wait_for} and submits inputs via {!Effects.submit}. Call
    inside {!Effects.with_probes} for [graph.probes] (or use {!with_graph}). *)

val with_graph :
  log:(string -> unit) ->
  'screen Graph.t ->
  ('screen Screen_walk.game_steps -> 'a) ->
  'a
(** Subscribe to [graph.probes] for the duration of the callback and pass it
    [make ~log graph]. *)
