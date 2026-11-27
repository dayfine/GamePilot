(** Live-clock countdown, [LStick] keep-awake, and optional final zero-drift
    [1PK] re-anchor before firing {!Bdsp_blink_rng.Static_rng_trigger.run}.

    GamePilot's own helper module for {!Static_rng}. Keeping a lightweight probe
    subscribed keeps {!Effects.now} advancing at 30 fps during long waits, while
    a final [1PK] re-anchor when > 180 advances remain eliminates multi-minute
    clock drift before the timed [submit_at] press. *)

val run :
  picture:Wire.box ->
  log:(string -> unit) ->
  prepare_for_trigger:(unit -> unit) ->
  reidentify_with_bounds:
    (search_min:int ->
    search_max:int ->
    (Bdsp_blink_rng.In_chamber_reidentifier.anchor, string) result) ->
  Bdsp_blink_rng.Static_rng_trigger.config ->
  Bdsp_blink_rng.In_chamber_reidentifier.anchor ->
  (Bdsp_blink_rng.Static_rng_trigger.outcome, string) result
(** Plans the next shiny advance, optionally waits and runs a final [1PK]
    re-anchor when far away, calls [prepare_for_trigger], and fires
    {!Bdsp_blink_rng.Static_rng_trigger.run}. *)
