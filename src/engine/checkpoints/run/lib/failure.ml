type cause = { code : string; detail : string; repeats : bool }

let cause ?(repeats = false) code detail = { code; detail; repeats }

let cause_to_string { code; detail; _ } =
  if detail = "" then code else code ^ ": " ^ detail

module Make (T : Engine_terms.TERMS) = struct
  type nonrec cause = cause = { code : string; detail : string; repeats : bool }

  let cause = cause
  let cause_to_string = cause_to_string

  type reason =
    | Handler of cause
    | No_handler of string
    | Not_at_declared of { declared : T.Pose.t; observed : T.Pose.observed }
    | Not_at_end of { declared : T.Pose.t; observed : T.Pose.observed option }
    | Unmet_postconditions of Engine_promise.Promise.result list

  type t = {
    checkpoint_id : string;
    event_index : int;
    event_id : string;
    reason : reason;
  }

  let repeats failure =
    match failure.reason with
    | Handler cause -> cause.repeats
    | No_handler _ -> true
    | Not_at_declared _ | Not_at_end _ | Unmet_postconditions _ -> false
end
