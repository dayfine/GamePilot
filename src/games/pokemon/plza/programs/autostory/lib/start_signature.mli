(** A checkpoint's start and end checks by the minimap. The start check: the
    plan's [execution.start_signature], as the fork checks it before a chained
    checkpoint and after a reload ([check_live_start] and [reload_into] in
    PokemonLZA_AutoStoryGame.cpp, [read_start_signature] in
    PokemonLZA_AutoStory.cpp, [plza/lean]): the screen read up to 20 times, 500
    ms apart, until the same minimap ({!Plza_readers.Minimap}) has read 3 times
    in a row; it must be the one the signature names. Nothing is pressed.

    - no signature: logged as START UNCHECKED, and the run goes on, as the
      fork's;
    - the minimap of the plan's [execution.end_signature] instead: passed, as at
      its end (a reload past the checkpoint's own autosave lands there, and its
      events skip there by [skip_if]);
    - another minimap read, or no minimap agreed on: [chain_off_start], which
      repeats;
    - a signature naming anything but one recorded minimap ([talk_prompt],
      [party], [wild_zone], or a name with no recording):
      [start_signature_unread], which repeats. The fork reads those too; no plan
      here names one yet.

    Where it differs: the fork's read agrees on the whole signature (the A
    prompt, the party count and the minimap); this reads the minimap only. The
    end signature is ours: the fork checks no end (it only notes whether its
    autosave showed), and 03.04 passed on Urbain's one line inside the Center
    (console B, 2026-11-25). *)

val check :
  Plza_story.Story_steps.game_steps ->
  checkpoint_id:string ->
  Json_field.obj ->
  (unit, Engine_run.Failure.cause) result

val check_end :
  Plza_story.Story_steps.game_steps ->
  checkpoint_id:string ->
  Json_field.obj ->
  (unit, Engine_run.Failure.cause) result
(** After the last event: the minimap the plan's [execution.end_signature]
    names, read as the start's is, or [end_off_signature] (a retry reloads). No
    end signature: [Ok], nothing read. *)
