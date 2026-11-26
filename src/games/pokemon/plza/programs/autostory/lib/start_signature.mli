(** A checkpoint's start and end checks. The start check: the plan's
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
    - the plan's [execution.end_signature] read instead: passed, as at its end
      (a reload past the checkpoint's own autosave lands there, and its events
      skip there by [skip_if]);
    - anything else, or no read agreed on: [chain_off_start], which repeats from
      the same screen; the series reloads once on it ({!Run_attempts}), where
      the fork's chain stops its run (PokemonLZA_AutoStoryGame.cpp);
    - a signature with another field, an unrecorded minimap, or nothing:
      [start_signature_unread], which repeats.

    Where it differs: [near_rocks] is ours: the fork's 21-fourth-species checks
    only the zone and the party, and a run left at the 100 spot
    ({!Plza_walk.Wild_zone_one.spot_100}) passed it (console B, 2026-11-25), to
    fail in the catch's own rocks check. The end signature is ours too: the fork
    checks no end (it only notes whether its autosave showed), and
    18-pokemon-center passed on Urbain's one line inside the Center (console B,
    2026-11-25). The party count takes two frames here
    ({!Plza_readers.Party_slots}). *)

val check :
  Plza_story.Steps.game_steps ->
  checkpoint_id:string ->
  Json_field.obj ->
  (unit, Engine_run.Failure.cause) result
(** [check steps ~checkpoint_id execution]: the start signature read on the
    screen, as above. *)

val decode :
  checkpoint_id:string ->
  Json_field.obj ->
  (unit, Engine_run.Failure.cause) result
(** The plan's start and end signatures decode (no field but the four, a
    recorded minimap, not empty): checked when the plan loads. *)

val check_end :
  Plza_story.Steps.game_steps ->
  checkpoint_id:string ->
  Json_field.obj ->
  (unit, Engine_run.Failure.cause) result
(** After the last event: the plan's [execution.end_signature], read as the
    start's is, or [end_off_signature] (a retry reloads). No end signature:
    [Ok], nothing read. *)
