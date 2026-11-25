open Engine_run

module Make (T : Engine_rules.GAME_RULES) = struct
  module Failure = Failure.Make (T)

  let reason_to_string : Failure.reason -> string = function
    | Handler cause -> Failure.cause_to_string cause
    | No_handler action -> "no handler for game action \"" ^ action ^ "\""
    | Not_at_declared { declared; observed } ->
        Printf.sprintf "declared after at %s, but the game reads %s"
          (T.Pose.to_string declared)
          (T.Pose.observed_to_string observed)
    | Not_at_end { declared; observed } ->
        Printf.sprintf "declared end at %s, but the game reads %s"
          (T.Pose.to_string declared)
          (match observed with
          | Some o -> T.Pose.observed_to_string o
          | None -> "no position")
    | Unmet_postconditions unmet ->
        "postconditions unmet: "
        ^ String.concat "; "
            (List.map Engine_postcondition.Postcondition.result_to_string unmet)

  let to_string (failure : Failure.t) =
    Printf.sprintf "%s event %d (%s): %s" failure.checkpoint_id
      (failure.event_index + 1) failure.event_id
      (reason_to_string failure.reason)
end
