(** A plan's run on the watch page ({!Watch_report}), for any game family: its
    checkpoint's events as the steps, moved by the runner's progress
    ({!Engine_run.Event_progress}), and the run itself ([watch.run]). *)

(** Over the plan's types of one family. *)
module Make (T : Engine_rules.GAME_RULES) (Raw : Engine_plan.Plan.RAW) : sig
  val create : Engine_plan.Plan.Make(T)(Raw).checkpoint -> Watch_report.t
  (** The checkpoint's events, all pending; shows the plan. *)

  val on_event :
    Watch_report.t -> int -> string Engine_run.Event_progress.t -> unit
  (** The runner's progress of event [i], shown: started is current, a skip
      shows its flag, a failure its reason. *)

  val run :
    mode:string ->
    Watch_report.t ->
    (on_event:(int -> string Engine_run.Event_progress.t -> unit) ->
    ('a, 'e) result) ->
    ('a, 'e) result
  (** [run ~mode report f]: the run in [mode] (["testing"], ["single"]) is
      current, [f] runs the checkpoint with [on_event] moving the steps, then
      the run is passed or failed by [f]'s result. A caller that catches an
      effects-boundary exception from [f] ends the run itself
      ({!Watch_report.end_run}). *)
end
