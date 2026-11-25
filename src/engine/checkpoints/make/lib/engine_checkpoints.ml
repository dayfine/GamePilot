module Make (T : Engine_terms.GAME_TERMS) = struct
  module Plan = Engine_plan.Plan.Make (T)
  module Plan_decode = Engine_plan.Plan_decode.Make (T)
  module Plan_text = Engine_plan.Plan_text.Make (T)
  module Failure = Engine_run.Failure.Make (T)
  module Game = Engine_run.Game.Make (T)
  module Runner = Engine_run.Runner.Make (T)
  module Event_states = Engine_run.Event_states
  module Repeat_until = Engine_run.Repeat_until.Make (T)
end
