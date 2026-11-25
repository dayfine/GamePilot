open Checkpoints_plan

let of_last_event (event : Plan.event) =
  match (event.declared_after, event.kind) with
  | Some (Grid pose), _ -> Some pose
  | _, (Route { target; _ } | Ready target) -> Some target
  | _ -> None

let declared ~(next : Plan.checkpoint option) (checkpoint : Plan.checkpoint) =
  match next with
  | Some { start = Some (Grid pose); _ } -> Some pose
  | _ -> Option.bind (List.nth_opt (List.rev checkpoint.events) 0) of_last_event
