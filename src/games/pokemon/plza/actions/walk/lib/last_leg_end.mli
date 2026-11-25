(** What ends a walk's last leg, judged on the screen read after each slice, and
    its failure when nothing did. Ported from [PokemonLZA_AutoStoryWalks.cpp].
*)

(** What one screen read says of the walk. *)
type verdict =
  | Walk_on  (** Nothing ends it: hold the next slice. *)
  | Ended  (** The walk is done. *)
  | Failed of Engine_run.Failure.cause  (** The walk failed. *)

val check_end_event :
  log:(string -> unit) ->
  log_detail:(string -> unit) ->
  prompt_steady:(unit -> bool) ->
  string ->
  Plza_rules.Walk_args.end_event ->
  earliest_end_ms:int ->
  Screen.t ->
  held_ms:int ->
  verdict
(** [check_end_event ~log ~log_detail walk event ~earliest_end_ms screen
     ~held_ms]: {!Ended} on [event] once the leg has been held [earliest_end_ms]
    (before that it was passed on the way: {!Walk_on}; an A prompt must also be
    [prompt_steady], else it went again), or on a black fade (a scene takes
    over); else {!Walk_on}. *)

val check_scene :
  (string -> unit) -> string -> Screen.t -> held_ms:int -> verdict
(** [check_scene log walk]: a check over the screen reads that ends the walk
    ({!Ended}) on the second busy read in a row (text, a box or a fade). Each
    call makes a fresh check. *)

val timed_out :
  string ->
  Plza_rules.Walk_args.until ->
  elapsed_ms:int ->
  Engine_run.Failure.cause
(** [timed_out walk until ~elapsed_ms]: the failure once the last leg's budget
    is spent with nothing ending it: [walk_no_scene] for
    {!Plza_rules.Walk_args.Scene}, [walk_no_end] for an event. *)
