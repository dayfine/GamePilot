type round = Round_passed of { goal_met : bool } | Round_failed of string

type decision =
  | Next_round of int
  | Goal_met of { rounds : int }
  | Capped of { rounds : int }
  | Stopped of string

let count n noun = Printf.sprintf "%d %s%s" n noun (if n = 1 then "" else "s")

let decide ~max_rounds ~capped rounds =
  let n = List.length rounds in
  match List.rev rounds with
  | Round_failed why :: _ ->
      Stopped (Printf.sprintf "round %d failed: %s" n why)
  | Round_passed { goal_met = true } :: _ -> Goal_met { rounds = n }
  | _ when n < max_rounds -> Next_round (n + 1)
  | _ when capped -> Capped { rounds = n }
  | _ -> Stopped ("goal not met after " ^ count n "round")

let decision_to_string = function
  | Next_round n -> Printf.sprintf "round %d" n
  | Goal_met { rounds } -> "goal met after " ^ count rounds "round"
  | Capped { rounds } -> "capped after " ^ count rounds "round"
  | Stopped why -> "stopped: " ^ why
