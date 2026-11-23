type cause = { code : string; detail : string; repeats : bool }

let cause ?(repeats = false) code detail = { code; detail; repeats }

let cause_to_string { code; detail; _ } =
  if detail = "" then code else code ^ ": " ^ detail

type reason =
  | Handler of cause
  | No_handler of string
  | Not_at_declared of { declared : Pose.grid; observed : Pose.observed }
  | Not_at_end of { declared : Pose.grid; observed : Pose.observed option }

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
  | Not_at_declared _ | Not_at_end _ -> false

let reason_to_string = function
  | Handler cause -> cause_to_string cause
  | No_handler action -> "no handler for game action \"" ^ action ^ "\""
  | Not_at_declared { declared; observed } ->
      Printf.sprintf "declared after at %s, but the game reads %s"
        (Pose.grid_to_string declared)
        (Pose.observed_to_string observed)
  | Not_at_end { declared; observed } ->
      Printf.sprintf "declared end at %s, but the game reads %s"
        (Pose.grid_to_string declared)
        (match observed with
        | Some o -> Pose.observed_to_string o
        | None -> "no position")

let to_string failure =
  Printf.sprintf "%s event %d (%s): %s" failure.checkpoint_id
    (failure.event_index + 1) failure.event_id
    (reason_to_string failure.reason)
