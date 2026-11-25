open Engine_run

module Make
    (T : Engine_rules.GAME_RULES)
    (X : Rules_text.TEXT with module T = T) =
struct
  module Failure_text = Failure_text.Make (T) (X)
  module Repeat_until = Repeat_until.Make (T) (Engine_plan_format.Raw_json)

  let part : Log_line.Make(T).part -> string = function
    | Text text -> text
    | Pose pose -> X.pose pose
    | Reason reason -> Failure_text.reason_to_string reason
    | Failure failure -> Failure_text.to_string failure

  let line parts = String.concat "" (List.map part parts)

  let chore_name : Repeat_until.chore -> string = function
    | Goal_check -> "goal check"
    | Between_rounds -> "heal"
    | Save -> "save"
    | Reload -> "reload"

  let count n noun = Printf.sprintf "%d %s%s" n noun (if n = 1 then "" else "s")

  let stop : Repeat_until.stop -> string = function
    | Round_failed { round; attempts; failure } ->
        Printf.sprintf "round %d failed after %s: %s" round
          (count attempts "attempt")
          (Failure_text.to_string failure)
    | Chore_failed { round; chore; cause } ->
        Printf.sprintf "%s failed in round %d: %s" (chore_name chore) round
          (Failure.cause_to_string cause)
    | Limit_reached { rounds } -> "goal not met after " ^ count rounds "round"
end
