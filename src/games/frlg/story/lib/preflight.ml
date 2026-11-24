module P = Story.Plan

type need = Plan_needs.need =
  | Party_in_order of string list
  | Party_includes of { members : string list; slots : P.slot list }
  | Member of { species : string; for_ : string }
  | Knows_move of { move : string; for_ : string }
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string

(* The args naming a member the action uses, and those naming one it brings. *)
let needs = Plan_needs.needs

type read = {
  observed : Story.Postcondition_check.observed;
  place : Frlg_readers.Start_frame.difference option;
  members : Story.Room_policy.member list option;
}

type verdict = Ok | Mismatch | Not_read
type row = { need : string; read : string; verdict : verdict }

let of_bool b = if b then Ok else Mismatch
let species_list l = String.concat ", " l

let party_text = function
  | None -> "not read"
  | Some members -> species_list (List.map (Option.value ~default:"?") members)

let with_party (read : read) need test =
  match read.observed.party with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some members ->
      {
        need;
        read = party_text (Some members);
        verdict = of_bool (test members);
      }

let has members species = List.mem (Some species) members

let in_slot members ({ slot; species } : P.slot) =
  List.nth_opt members (slot - 1) = Some (Some species)

let slot_text ({ slot; species } : P.slot) =
  Printf.sprintf "%s in slot %d" species slot

let includes_text members slots =
  "party includes " ^ species_list (members @ List.map slot_text slots)

(* Its moves as read; a member not in the party read is a mismatch. *)
let knows (move : string) (m : Story.Room_policy.member) =
  Option.fold ~none:false ~some:(List.mem move) m.moves

let unread_moves (m : Story.Room_policy.member) = m.moves = None

let knows_row (read : read) move for_ =
  let need = Printf.sprintf "a member knows %s (%s)" move for_ in
  match read.members with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some members -> (
      match List.find_opt (knows move) members with
      | Some m -> { need; read = m.species ^ " knows " ^ move; verdict = Ok }
      | None when List.exists unread_moves members ->
          { need; read = "moves not read"; verdict = Not_read }
      | None -> { need; read = "no member knows " ^ move; verdict = Mismatch })

let with_money (read : read) need test =
  match read.observed.money with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some m ->
      { need; read = Printf.sprintf "¥%d" m; verdict = of_bool (test m) }

let with_item (read : read) item need test =
  match List.assoc_opt item read.observed.items with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some n ->
      {
        need;
        read = Printf.sprintf "%s x%d" item n;
        verdict = of_bool (test n);
      }

let place_row read map =
  let need = "at the start, " ^ map in
  match read.place with
  | None ->
      { need; read = "no kept start frame to compare"; verdict = Not_read }
  | Some d ->
      let module F = Frlg_readers.Start_frame in
      {
        need;
        read = F.difference_to_string d;
        verdict = of_bool (F.same_place d);
      }

let row read = function
  | Party_in_order l ->
      with_party read
        ("party " ^ species_list l)
        (fun m -> m = List.map Option.some l)
  | Party_includes { members; slots } ->
      with_party read (includes_text members slots) (fun m ->
          List.for_all (has m) members && List.for_all (in_slot m) slots)
  | Member { species; for_ } ->
      with_party read (Printf.sprintf "%s in the party (%s)" species for_)
        (fun m -> has m species)
  | Money_at_least { amount; for_ } ->
      with_money read (Printf.sprintf "money at least ¥%d (%s)" amount for_)
        (fun m -> m >= amount)
  | Money_between { min; max } ->
      with_money read (Printf.sprintf "money ¥%d..¥%d" min max) (fun m ->
          m >= min && m <= max)
  | Item_at_least { item; count; for_ } ->
      with_item read item
        (Printf.sprintf "%s at least x%d (%s)" item count for_) (fun n ->
          n >= count)
  | Item_exactly { item; count } ->
      with_item read item (Printf.sprintf "%s x%d" item count) (fun n ->
          n = count)
  | Knows_move { move; for_ } -> knows_row read move for_
  | Place map -> place_row read map

let compare needs read = List.map (row read) needs

let room need read =
  let need_text, read_text, ok =
    Party_room.report need ~members:read.members read.observed.party
  in
  let verdict =
    match ok with Some true -> Ok | Some false -> Mismatch | None -> Not_read
  in
  { need = need_text; read = read_text; verdict }

let passed rows = List.for_all (fun r -> r.verdict = Ok) rows

let verdict_text = function
  | Ok -> "ok"
  | Mismatch -> "MISMATCH"
  | Not_read -> "NOT READ"

let table rows =
  let width f =
    List.fold_left (fun w r -> max w (String.length (f r))) 4 rows
  in
  let wn = width (fun r -> r.need) and wr = width (fun r -> r.read) in
  let line a b c = Printf.sprintf "%-*s  %-*s  %s" wn a wr b c in
  String.concat "\n"
    (line "NEED" "READ" "VERDICT"
    :: List.map (fun r -> line r.need r.read (verdict_text r.verdict)) rows)

let to_read needs : P.postconditions =
  let party =
    List.exists
      (function
        | Party_in_order _ | Party_includes _ | Member _ | Knows_move _ -> true
        | _ -> false)
      needs
  and money =
    List.exists
      (function Money_at_least _ | Money_between _ -> true | _ -> false)
      needs
  in
  let items =
    List.sort_uniq Stdlib.compare
      (List.filter_map
         (function
           | Item_at_least { item; _ } | Item_exactly { item; _ } -> Some item
           | _ -> None)
         needs)
  in
  {
    position = None;
    party =
      (if party then Some (P.Party_includes { members = []; slots = [] })
       else None);
    items =
      List.map (fun bag_item -> { P.bag_item; count = P.Count_exactly 0 }) items;
    coins = None;
    money = (if money then Some (P.Money_range { min = 0; max = 0 }) else None);
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }
