open Engine_plan

module Make (T : Engine_rules.GAME_RULES) (Raw : Plan.RAW) = struct
  type outcome = (unit, Failure.cause) result
  type game_action = Plan.Make(T)(Raw).event -> Raw.t -> outcome

  type t = {
    run_own : Plan.Make(T)(Raw).event -> T.Action.t -> outcome;
    run_builtin : Plan.Make(T)(Raw).event -> outcome;
    game_actions : (string * game_action) list;
    flag_holds : string -> bool;
    position : unit -> T.Pose.observed option;
    between_rounds : unit -> outcome;
    save : unit -> outcome;
    reload : unit -> outcome;
    log : string -> unit;
  }
end
