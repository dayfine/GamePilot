let tag = "[Route] "

type end_basis = Walked | Assumed | Unknown

let basis_name = function
  | Walked -> "walked"
  | Assumed -> "assumed"
  | Unknown -> "unknown"

let describe = Route_tile.describe

(* "<leg> to <tiles>", as the plan and the leg lines both write a leg. *)
let planned_text (planned : Route_leg.planned) =
  Printf.sprintf "%s to %s"
    (Route_leg.to_string planned.leg)
    (describe planned.after)

let plan_line ~label ~from legs =
  let head = Printf.sprintf "%s: plan from %s:" label (describe from) in
  match legs with
  | [] -> head
  | legs -> head ^ " " ^ String.concat "; " (List.map planned_text legs)

let leg_line ~number ~count planned =
  Printf.sprintf "Leg %d/%d: %s" number count (planned_text planned)

let leg_end_line ~label ?why leg ~at basis =
  let how =
    match why with
    | None -> basis_name basis
    | Some why -> Printf.sprintf "%s: %s" (basis_name basis) why
  in
  Printf.sprintf "%s: %s: ended at %s (%s)." label (Route_leg.to_string leg)
    (describe at) how

let replan_line ~label leg ~what ~at =
  Printf.sprintf "%s: %s: %s, at %s; planning again." label
    (Route_leg.to_string leg) what (describe at)

let found_line ~label ~at ~holds =
  Printf.sprintf "%s: found again at %s, after %d hold(s)." label (describe at)
    holds

let trainer_line ~label ~who ~at =
  Printf.sprintf "%s: %s stopped us about %s." label who (describe at)

let arrived_line ~label ~at =
  Printf.sprintf "%s: arrived at %s." label (describe at)
