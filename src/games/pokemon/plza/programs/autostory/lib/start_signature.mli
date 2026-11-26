(** A checkpoint's start and end checks. The start check: the plan's
    [execution.start_signature], as the fork checks it before a chained
    checkpoint and after a reload (the live start check and the reload in
    PokemonLZA_AutoStoryGame.cpp; the start signature and start position reads
    in PokemonLZA_AutoStory.cpp; the start screen read in
    PokemonLZA_AutoStoryScreenEvents.cpp; the start's confirmation in
    PokemonLZA_AutoStoryStarts.cpp).

    A signature names [minimap] (a recorded minimap, {!Plza_readers.Minimap}).
    The screen is read up to 20 times, 500 ms apart, until the same minimap
    (nothing during a fade or a text box) has come 3 times in a row, and must be
    the one named. Nothing is pressed.

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

    Where it differs: the fork's signatures also name the A prompt, the party
    count and the wild zone; no plan here uses those yet.

    Also ours: the end signature. The fork checks no end (it only notes whether
    its autosave showed), and 03.04 passed on Urbain's one line inside the
    Center (console B, 2026-11-25). *)

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
(** The plan's start and end signatures decode (only a recorded minimap):
    checked when the plan loads. *)

val check_end :
  Plza_story.Steps.game_steps ->
  checkpoint_id:string ->
  Json_field.obj ->
  (unit, Engine_run.Failure.cause) result
(** After the last event: the plan's [execution.end_signature], read as the
    start's is, or [end_off_signature] (a retry reloads). No end signature:
    [Ok], nothing read. *)
