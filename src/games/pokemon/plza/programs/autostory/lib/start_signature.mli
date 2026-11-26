(** A checkpoint's start check and its end place. The start check: the plan's
    [execution.start_signature], as the fork checks it before a chained
    checkpoint and after a reload (the live start check and the reload in
    PokemonLZA_AutoStoryGame.cpp; the start signature and start position reads
    in PokemonLZA_AutoStory.cpp; the start screen read in
    PokemonLZA_AutoStoryScreenEvents.cpp; the start's confirmation in
    PokemonLZA_AutoStoryStarts.cpp).

    A signature names any of [talk_prompt] (an A prompt shows), [wild_zone] (the
    map's pin is in Wild Zone 1), [near_rocks] (the map's pin is on Taunie's
    rocks, {!Plza_walk.Wild_zone_one.near_rocks}), [party] (the party bar's
    filled slots) and [minimap] (a recorded minimap). The screen is read up to
    20 times, 500 ms apart, until the same read (the A prompt, the party count
    and the minimap; nothing during a fade or a text box) has come 3 times in a
    row. With [wild_zone] or [near_rocks] named, the map is then opened for the
    pin ({!Plza_walk.Map_walk.read_pin}). Every field the signature names must
    read the same. Nothing is pressed but the map's buttons.

    - no signature: logged as START UNCHECKED, and the run goes on, as the
      fork's;
    - its end place read instead ([~at_end], {!promised_end}): passed, as at its
      end (a reload past the checkpoint's own autosave lands there, and the
      runner runs no event there: {!Engine_run.Runner});
    - anything else, or no read agreed on: [chain_off_start], which repeats from
      the same screen; the series reloads once on it
      (Plza_checkpoint_series.Run_attempts), where the fork's chain stops its
      run (PokemonLZA_AutoStoryGame.cpp);
    - a signature with another field, an unrecorded minimap, or nothing:
      [start_signature_unread], which repeats.

    Where it differs: [near_rocks] is ours: the fork's 03.08 checks only the
    zone and the party, and a run left at the 100 spot
    ({!Plza_walk.Wild_zone_one.spot_100}) passed it (console B, 2026-11-25), to
    fail in the catch's own rocks check. The end place is ours too: the fork
    checks no end (it only notes whether its autosave showed), and 03.07 passed
    on Urbain's one line inside the Center (console B, 2026-11-25). The party
    count takes two frames here ({!Plza_readers.Party_slots}). *)

val check :
  Plza_story.Steps.game_steps ->
  checkpoint_id:string ->
  at_end:Plza_rules.Screen_signature.t option ->
  Json_field.obj ->
  (unit, Engine_run.Failure.cause) result
(** [check steps ~checkpoint_id ~at_end execution]: the start signature read on
    the screen, as above; [at_end] is the checkpoint's end place. *)

val decode :
  checkpoint_id:string ->
  Plza_engine.Plan.t ->
  (unit, Engine_run.Failure.cause) result
(** The plan's start signature decodes (no field but the five, a recorded
    minimap, not empty) and its postconditions' [place] names a recorded
    minimap: checked when the plan loads. *)

val promised_end :
  next:Plza_engine.Plan.t option ->
  Plza_engine.Plan.t ->
  (Plza_rules.Postconditions.t, Engine_run.Failure.cause) result
(** Where the checkpoint ends: its postconditions' [place], or else the next
    checkpoint's start signature (as a Pokémon checkpoint's end is the next
    one's start, [Checkpoint_end]); no place when neither names one. The runner
    checks it after the last event, and passes the checkpoint before the first
    when it already holds. *)

val read_place :
  Plza_story.Steps.game_steps ->
  checkpoint_id:string ->
  Plza_rules.Screen_signature.t ->
  Plza_rules.Screen_signature.t
(** What the screen shows of an end place's fields, read as the start's is
    (agreed frames, the map's pin when the place names it), logged as
    ["[Checkpoint] <id>: END PLACE READ: ..."]: the runner's reads of the place.
*)
