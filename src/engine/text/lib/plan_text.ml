module Make (T : Engine_rules.GAME_RULES) = struct
  module Plan = Engine_plan.Plan.Make (T) (Engine_plan_format.Raw_json)

  let pose = T.Pose.to_string

  let kind : Plan.kind -> string = function
    | Talk -> Engine_rules.Story_action.to_string Talk
    | Answer yes -> Engine_rules.Story_action.to_string (Answer yes)
    | Scene -> Engine_rules.Story_action.to_string Scene
    | Save -> Engine_rules.Story_action.to_string Save
    | Named_action args -> "game_action " ^ Yojson.Safe.to_string (`Assoc args)
    | Game action -> T.Action.to_string action

  let event (e : Plan.event) =
    let way = Option.fold ~none:"" ~some:(fun a -> "[" ^ a ^ "] ") e.way in
    let after =
      Option.fold ~none:"" ~some:(fun p -> " => " ^ pose p) e.declared_after
    in
    let skip =
      if e.skip_if = [] then "" else " skip_if " ^ String.concat "," e.skip_if
    in
    let once = if e.once_per_save then " once_per_save" else "" in
    Printf.sprintf "%s: %s%s%s%s%s" e.id way (kind e.kind) after skip once

  let event_named (plan : Plan.t) id =
    match
      List.find_opt (fun (e : Plan.event) -> e.id = id) plan.checkpoint.events
    with
    | Some e -> event e
    | None -> "no event " ^ id

  let kind_name : Plan.kind -> string = function
    | Named_action _ -> "game_action"
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
      (Option.fold ~none:"(no start)" ~some:pose plan.checkpoint.start)
      (String.concat ", "
         (List.map
            (fun (k, n) -> Printf.sprintf "%d %s" n k)
            (kind_counts plan.checkpoint.events)))

  let lines_text = function [] -> "none" | lines -> String.concat "\n" lines
  let promises_text promises = lines_text (T.Postconditions.to_lines promises)

  let postconditions (plan : Plan.t) =
    lines_text
      (Option.fold ~none:[] ~some:T.Postconditions.to_lines plan.postconditions)

  let repeat (plan : Plan.t) =
    match plan.repeat with
    | None -> "no repeat"
    | Some { until; max_rounds } ->
        Printf.sprintf "at most %d rounds, until:\n%s" max_rounds
          (promises_text until)
end
