type precondition = { free_slots : int }

type rules = {
  party_size : int;
  used : string list;
  field_moves : string list;
  needed_moves : string list;
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

let knows move (m : member) =
  Option.fold ~none:false ~some:(List.mem move) m.moves

(* A needed move no other member of the party knows. *)
let only_knower rules party (m : member) =
  List.find_opt
    (fun move ->
      knows move m
      && not
           (List.exists
              (fun (o : member) -> o.slot <> m.slot && knows move o)
              party))
    rules.needed_moves

let keeps rules party (m : member) =
  if List.mem m.species rules.used then Some "the plans use it"
  else if rules.lead_stays && m.slot = 1 then Some "it leads"
  else
    match (m.moves, only_knower rules party m) with
    | None, _ -> Some "its moves did not read"
    | _, Some move -> Some ("only it knows " ^ move)
    | Some moves, None ->
        Option.map (fun f -> "it knows " ^ f) (field_move rules moves)

let level_order (a : member) (b : member) =
  compare
    (Option.value a.level ~default:max_int, a.slot)
    (Option.value b.level ~default:max_int, b.slot)

let kept_text rules party =
  List.filter_map
    (fun (m : member) ->
      Option.map (fun why -> m.species ^ ": " ^ why) (keeps rules party m))
    party

(* One member at a time, the lowest level that may go from what is left: the
   second of two members knowing a needed move stays. *)
let rec pick rules party short chosen =
  if short = 0 then Some chosen
  else
    match
      List.sort level_order
        (List.filter (fun m -> keeps rules party m = None) party)
    with
    | [] -> None
    | m :: _ ->
        pick rules
          (List.filter (fun (o : member) -> o.slot <> m.slot) party)
          (short - 1) (m :: chosen)

let to_deposit (m : member) = { slot = m.slot; species = m.species }

let choose rules (p : precondition) members =
  let short = p.free_slots - free_slots rules (List.length members) in
  let may_go = List.filter (fun m -> keeps rules members m = None) members in
  if short <= 0 then Ok []
  else
    match pick rules members short [] with
    | Some chosen ->
        Ok
          (List.sort
             (fun (a : deposit) (b : deposit) -> compare a.slot b.slot)
             (List.map to_deposit chosen))
    | None ->
        Error
          (Printf.sprintf "%d to deposit, %d may go; kept: %s" short
             (List.length may_go)
             (String.concat "; " (kept_text rules members)))

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
