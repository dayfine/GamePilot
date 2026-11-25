module Make
    (T : Engine_rules.GAME_RULES)
    (C : Engine_plan_codec.Plan_codec.PLAN_CODEC with module T = T)
    (X : Engine_text.Rules_text.TEXT with module T = T)
    (S : Engine_saved.Event_states.SAVED) =
struct
  module Raw = Engine_plan_codec.Raw_json
  module Run_text = Engine_text.Run_text.Make (T) (X)
  module Plan = Engine_plan.Plan.Make (T) (Raw)
  module Plan_decode = Engine_plan_codec.Plan_decode.Make (T) (C)
  module Plan_text = Engine_text.Plan_text.Make (T) (X)

  module Failure = struct
    include Engine_run.Failure.Make (T)
    include Engine_text.Failure_text.Make (T) (X)
  end

  module Game = Engine_run.Game.Make (T) (Raw)

  (* Every line the runner says goes to the game's log, printed. *)
  let say (game : Game.t) line = game.log (Run_text.line line)

  module Runner = struct
    module Run = Engine_run.Runner.Make (T) (Raw)

    let run ?end_at ?end_state ?on_event ?events (game : Game.t) checkpoint =
      let on_event =
        Option.map
          (fun hear index progress ->
            hear index (Engine_run.Event_progress.map Run_text.line progress))
          on_event
      in
      Run.run ?end_at ?end_state ?on_event ?events ~say:(say game) game
        checkpoint
  end

  module Event_states = struct
    include Engine_saved.Event_states
    include Engine_saved.Event_states.Make (S)
  end

  module Repeat_until = struct
    include Engine_run.Repeat_until.Make (T) (Raw)

    let run limits ~goal (game : Game.t) checkpoint =
      run limits ~goal ~say:(say game) game checkpoint

    let stop_to_string = Run_text.stop
  end
end
