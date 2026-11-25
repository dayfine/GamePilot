open Engine_plan

module Make (T : Engine_terms.GAME_TERMS) = struct
  type outcome = (unit, Failure.cause) result
  type game_action = Plan.Make(T).event -> Json_field.obj -> outcome

  type t = {
    run_own : Plan.Make(T).event -> T.own_kind -> outcome;
    run_builtin : Plan.Make(T).event -> outcome;
    game_actions : (string * game_action) list;
    flag_holds : string -> bool;
    position : unit -> T.observed option;
    between_rounds : unit -> outcome;
    save : unit -> outcome;
    reload : unit -> outcome;
    log : string -> unit;
  }
end
