let timed_out ~label ~seconds ~expected =
  Engine_run.Failure.cause "scene_timeout"
    (Printf.sprintf "%s: Did not finish within %d s (expecting %s)." label
       seconds expected)

let ended_in_control ~label ~hold_ms ~expected =
  Engine_run.Failure.cause "scene_ended_in_control"
    (Printf.sprintf
       "%s: the scene ended in control, the party bar up %d ms with nothing \
        busy (expecting %s)."
       label hold_ms expected)

let never_started ~label ~window_ms ~expected =
  Engine_run.Failure.cause "scene_never_started"
    (Printf.sprintf
       "%s: the scene never started (player not at its trigger?): the HUD up \
        and no text, choice, battle or cutscene for %d ms (expecting %s)."
       label window_ms expected)
