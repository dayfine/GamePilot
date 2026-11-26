(** Isolated single-step test modes for [bdsp.underground_poc], allowing each
    stage of the Grand Underground farming loop to be verified independently on
    live hardware before chaining them in [mode=farm]. *)

open Bdsp_underground

val run :
  mode:string ->
  door:string ->
  log:(string -> unit) ->
  picture:Wire.box ->
  goal:Mining_goal.goal ->
  (string, string) result option
(** Dispatch [step-refresh], [step-read-map], [step-route-one], or
    [step-dig-one]. Returns [None] if [mode] is not a single-step mode. *)
