module Make (T : Engine_terms.GAME_TERMS) = struct
  module Plan = Plan.Make (T)

  let pose = T.Pose.text

  let kind : Plan.kind -> string = function
    | Talk -> "talk"
    | Answer yes -> if yes then "answer yes" else "answer no"
    | Scene -> "scene"
    | Save -> "save"
    | Game_action args -> "game_action " ^ Yojson.Safe.to_string (`Assoc args)
    | Own own -> T.Kind.text own

  let event (e : Plan.event) =
    let action =
      Option.fold ~none:"" ~some:(fun a -> "[" ^ a ^ "] ") e.action
    in
    let after =
      Option.fold ~none:"" ~some:(fun p -> " => " ^ pose p) e.declared_after
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
  let promises_text promises = lines_text (T.Promises.text promises)

  let postconditions (plan : Plan.t) =
    lines_text (Option.fold ~none:[] ~some:T.Promises.text plan.postconditions)

  let repeat (plan : Plan.t) =
    match plan.repeat with
    | None -> "no repeat"
    | Some { until; max_rounds } ->
        Printf.sprintf "at most %d rounds, until:\n%s" max_rounds
          (promises_text until)
end
