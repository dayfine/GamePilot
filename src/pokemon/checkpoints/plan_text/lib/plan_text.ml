open Checkpoints_plan

let pose = Pose.grid_to_string
let list = String.concat ", "

let declared = function
  | Pose.Grid grid -> pose grid
  | Zone { place; _ } -> "zone " ^ place

let leg (l : Plan.leg) =
  Printf.sprintf "%s %d" (Grid_maps.Direction.name l.direction) l.tiles

let item (i : Plan.item) = Printf.sprintf "%d %s" i.quantity i.item
let fighting fight_wild = if fight_wild then " fighting" else ""

let legs legs fight_wild =
  (if fight_wild then "legs fighting " else "legs ") ^ list (List.map leg legs)

let kind : Plan.kind -> string = function
  | New_game -> "new_game"
  | Options -> "options"
  | Route { target; fight_wild } ->
      "route to " ^ pose target ^ fighting fight_wild
  | Ready target -> "ready at " ^ pose target
  | Legs { legs = l; fight_wild } -> legs l fight_wild
  | Step direction -> "step " ^ Grid_maps.Direction.name direction
  | Talk -> "talk"
  | Answer yes -> if yes then "answer yes" else "answer no"
  | Scene -> "scene"
  | Battle { may_lose } -> if may_lose then "battle (may lose)" else "battle"
  | Train battles -> Printf.sprintf "train %d" battles
  | Heal -> "heal"
  | Shop items -> "shop " ^ list (List.map item items)
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

let event_named (plan : Plan.t) id =
  match
    List.find_opt (fun (e : Plan.event) -> e.id = id) plan.checkpoint.events
  with
  | Some e -> event e
  | None -> "no event " ^ id

let kind_name : Plan.kind -> string = function
  | Game_action _ -> "game_action"
  | Route _ -> "route"
  | other -> List.hd (String.split_on_char ' ' (kind other))

let bump k (k', n) = if k' = k then (k', n + 1) else (k', n)

(* Each kind's count, in first-seen order. *)
let kind_counts events =
  let add counts (e : Plan.event) =
    let k = kind_name e.kind in
    if List.mem_assoc k counts then List.map (bump k) counts
    else counts @ [ (k, 1) ]
  in
  List.fold_left add [] events

let outline (plan : Plan.t) =
  Printf.sprintf "%s %s from %s: %s" plan.game plan.checkpoint.checkpoint_id
    (Option.fold ~none:"(no start)" ~some:declared plan.checkpoint.start)
    (list
       (List.map
          (fun (k, n) -> Printf.sprintf "%d %s" n k)
          (kind_counts plan.checkpoint.events)))

let slot ({ slot; species } : Plan.slot) =
  Printf.sprintf "%s in slot %d" species slot

let party : Plan.party option -> string list = function
  | Some (Party_in_order l) -> [ "party in order " ^ list l ]
  | Some (Party_includes { members; slots }) ->
      ("party includes " ^ list members) :: List.map slot slots
  | None -> []

let bag_count ({ bag_item; count } : Plan.bag_count) =
  Printf.sprintf "item %s %s" bag_item (Engine_promise.Count.text count)

let knows ({ species; moves } : Plan.knows) =
  Printf.sprintf "%s knows %s" species (list moves)

let level ({ species; min } : Plan.level) =
  Printf.sprintf "%s at least Lv %d" species min

let some f = Option.fold ~none:[] ~some:(fun x -> [ f x ])

let lines (p : Plan.postconditions) =
  List.concat
    [
      some (fun g -> "position " ^ pose g) p.position;
      party p.party;
      List.map bag_count p.items;
      some (fun c -> "coins " ^ Engine_promise.Count.text c) p.coins;
      some Engine_promise.Money.text p.money;
      (if p.flags = [] then [] else [ "flags " ^ list p.flags ]);
      List.map knows p.knows;
      List.map level p.levels;
      some (fun m -> "marks " ^ list m) p.marks;
    ]

let postconditions (plan : Plan.t) =
  match lines plan.postconditions with
  | [] -> "none"
  | l -> String.concat "\n" l

let repeat (plan : Plan.t) =
  match plan.repeat with
  | None -> "no repeat"
  | Some { until; max_rounds } ->
      Printf.sprintf "at most %d rounds, until:\n%s" max_rounds
        (postconditions { plan with postconditions = until })
