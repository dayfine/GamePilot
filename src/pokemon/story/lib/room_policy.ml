type precondition = { free_slots : int }

type rules = {
  party_size : int;
  used : string list;
  field_moves : string list;
  lead_stays : bool;
}

type member = {
  slot : int;
  species : string;
  level : int option;
  moves : string list option;
}

type deposit = { slot : int; species : string }
type plan = deposit list

let free_slots rules members = rules.party_size - members

let holds rules (p : precondition) members =
  free_slots rules members >= p.free_slots

let field_move rules moves =
  List.find_opt (fun f -> List.mem f moves) rules.field_moves

let keeps rules (m : member) =
  if List.mem m.species rules.used then Some "the plans use it"
  else if rules.lead_stays && m.slot = 1 then Some "it leads"
  else
    match m.moves with
    | None -> Some "its moves did not read"
    | Some moves ->
        Option.map (fun f -> "it knows " ^ f) (field_move rules moves)

let level_order (a : member) (b : member) =
  compare
    (Option.value a.level ~default:max_int, a.slot)
    (Option.value b.level ~default:max_int, b.slot)

let choose rules (p : precondition) members =
  let short = p.free_slots - free_slots rules (List.length members) in
  let may_go = List.filter (fun m -> keeps rules m = None) members in
  let kept =
    List.filter_map
      (fun (m : member) ->
        Option.map (fun why -> m.species ^ ": " ^ why) (keeps rules m))
      members
  in
  if short <= 0 then Ok []
  else if List.length may_go < short then
    Error
      (Printf.sprintf "%d to deposit, %d may go; kept: %s" short
         (List.length may_go) (String.concat "; " kept))
  else
    let chosen =
      List.filteri (fun i _ -> i < short) (List.sort level_order may_go)
    in
    Ok
      (List.sort
         (fun (a : deposit) (b : deposit) -> compare a.slot b.slot)
         (List.map
            (fun (m : member) -> { slot = m.slot; species = m.species })
            chosen))

let plan_to_string = function
  | [] -> "nothing to deposit"
  | plan ->
      "deposit "
      ^ String.concat ", "
          (List.map
             (fun (d : deposit) ->
               Printf.sprintf "%s (slot %d)" d.species d.slot)
             plan)

let member_to_string (m : member) =
  let level =
    Option.fold ~none:"?" ~some:(fun l -> "Lv " ^ string_of_int l) m.level
  in
  let moves = Option.fold ~none:"?" ~some:(String.concat ", ") m.moves in
  Printf.sprintf "%s %s (%s)" m.species level moves
