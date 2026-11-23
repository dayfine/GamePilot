(* A decoded plan as text, to compare with what the plan file says. *)

open Story

let pose = Pose.grid_to_string

let declared = function
  | Pose.Grid grid -> pose grid
  | Zone { place; _ } -> "zone " ^ place

let kind : Plan.kind -> string = function
  | New_game -> "new_game"
  | Options -> "options"
  | Route { target; fight_wild } ->
      Printf.sprintf "route to %s%s" (pose target)
        (if fight_wild then " fighting" else "")
  | Ready target -> "ready at " ^ pose target
  | Legs { legs; fight_wild } ->
      (if fight_wild then "legs fighting " else "legs ")
      ^ String.concat ", "
          (List.map
             (fun (leg : Plan.leg) ->
               Printf.sprintf "%s %d"
                 (Grid_maps.Direction.name leg.direction)
                 leg.tiles)
             legs)
  | Step direction -> "step " ^ Grid_maps.Direction.name direction
  | Talk -> "talk"
  | Answer yes -> if yes then "answer yes" else "answer no"
  | Scene -> "scene"
  | Battle { may_lose } -> if may_lose then "battle (may lose)" else "battle"
  | Train battles -> Printf.sprintf "train %d" battles
  | Heal -> "heal"
  | Shop items ->
      "shop "
      ^ String.concat ", "
          (List.map
             (fun (i : Plan.item) -> Printf.sprintf "%d %s" i.quantity i.item)
             items)
  | Save -> "save"
  | Game_action args -> "game_action " ^ Yojson.Safe.to_string (`Assoc args)

let event (e : Plan.event) =
  let action = Option.fold ~none:"" ~some:(fun a -> "[" ^ a ^ "] ") e.action in
  let after =
    Option.fold ~none:"" ~some:(fun p -> " => " ^ declared p) e.declared_after
  in
  let skip =
    if e.skip_if = [] then "" else " skip_if " ^ String.concat "," e.skip_if
  in
  let once = if e.once_per_save then " once_per_save" else "" in
  Printf.sprintf "%s: %s%s%s%s%s" e.id action (kind e.kind) after skip once

let kind_name : Plan.kind -> string = function
  | Game_action _ -> "game_action"
  | Route _ -> "route"
  | other -> List.hd (String.split_on_char ' ' (kind other))
