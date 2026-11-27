(** Isolated single-step test modes for [bdsp.underground], allowing each stage
    of the Grand Underground farming loop to be verified independently on live
    hardware before chaining them in [mode=farm]. *)

open Bdsp_underground

(** Outcome of dispatching a single-step mode. *)
type outcome =
  | Not_step_mode  (** [mode] is not a single-step mode (e.g. ["farm"]). *)
  | Completed of string  (** The single-step mode succeeded with a summary. *)
  | Failed of string  (** The single-step mode failed with an error reason. *)

val run :
  mode:string ->
  door:string ->
  log:(string -> unit) ->
  picture:Wire.box ->
  goal:Mining_goal.goal ->
  outcome
(** Dispatch [check-bag], [check-map], [step-refresh], [step-read-map],
    [step-route-one], or [step-dig-one]. Returns {!Not_step_mode} otherwise. *)
