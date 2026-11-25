open Engine_postcondition

type start = {
  start_money : int option;
  start_coins : int option;
  start_caught : int option;
  start_items : (string * int) list;
}

let nothing_at_start =
  {
    start_money = None;
    start_coins = None;
    start_caught = None;
    start_items = [];
  }

type observed = {
  party : string option list option;
  items : (string * int) list;
  coins : int option;
  caught : int option;
  money : int option;
  start : start;
  flags : (string * bool) list;
  knows : (string * string list) list;
  levels : (string * int) list;
  marks : string list option;
}

let nothing_read =
  {
    party = None;
    items = [];
    coins = None;
    caught = None;
    money = None;
    start = nothing_at_start;
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

type verdict = Postcondition.verdict = Passed | Failed | Not_checked

type result = Postcondition.result = {
  what : string;
  verdict : verdict;
  detail : string;
}

let not_read = Postcondition.not_read
let member_text = Option.value ~default:"?"
let party_text members = String.concat ", " (List.map member_text members)

(* Members read as one of the species: [Some s] equal to it. *)
let count_of species members =
  List.length (List.filter (( = ) (Some species)) members)

let unread members = List.length (List.filter Option.is_none members)

let in_order expected members =
  let what = "party" and read = party_text members in
  let differs e m = match m with Some s -> s <> e | None -> false in
  if
    List.compare_lengths expected members <> 0
    || List.exists2 differs expected members
  then
    Postcondition.judge what ~expected:(String.concat ", " expected) ~read false
  else if unread members > 0 then
    Postcondition.not_checked what ~why:("read " ^ read)
  else Postcondition.judge what ~expected:"" ~read true

(* Each species needs as many members as the list names it. *)
let missing_members expected members =
  List.filter
    (fun s -> count_of s members < count_of s (List.map Option.some expected))
    (List.sort_uniq compare expected)

let wrong_slots slots members =
  List.filter
    (fun ({ slot; species } : Postconditions.slot) ->
      List.nth_opt members (slot - 1) <> Some (Some species))
    slots

let slot_text ({ slot; species } : Postconditions.slot) =
  Printf.sprintf "%s in slot %d" species slot

let includes_text expected slots =
  String.concat ", "
    ((if expected = [] then []
      else [ String.concat ", " expected ^ " among the members" ])
    @ List.map slot_text slots)

let includes expected slots members =
  let what = "party" and read = party_text members in
  let expected_text = includes_text expected slots in
  match (missing_members expected members, wrong_slots slots members) with
  | [], [] -> Postcondition.judge what ~expected:expected_text ~read true
  | _ when unread members > 0 ->
      Postcondition.not_checked what ~why:("read " ^ read)
  | _ -> Postcondition.judge what ~expected:expected_text ~read false

let check_party (expected : Postconditions.party option) observed =
  match (expected, observed.party) with
  | None, _ -> []
  | Some _, None -> [ not_read "party" ]
  | Some (Party_in_order list), Some members -> [ in_order list members ]
  | Some (Party_includes { members = list; slots }), Some members ->
      [ includes list slots members ]

let check_count what count ~start read =
  Postcondition.count what count ~start ~read

let check_item observed ({ bag_item; count } : Postconditions.bag_count) =
  let what = "item " ^ bag_item in
  match List.assoc_opt bag_item observed.items with
  | None -> not_read what
  | Some read ->
      check_count what count
        ~start:(List.assoc_opt bag_item observed.start.start_items)
        read

let check_coins expected observed =
  match (expected, observed.coins) with
  | None, _ -> []
  | Some _, None -> [ not_read "coins" ]
  | Some count, Some read ->
      [ check_count "coins" count ~start:observed.start.start_coins read ]

let check_caught expected observed =
  match (expected, observed.caught) with
  | None, _ -> []
  | Some _, None -> [ not_read "caught" ]
  | Some count, Some read ->
      [ check_count "caught" count ~start:observed.start.start_caught read ]

let check_money expected observed =
  match (expected, observed.money) with
  | None, _ -> []
  | Some _, None -> [ not_read "money" ]
  | Some money, Some read ->
      [ Postcondition.money money ~start:observed.start.start_money ~read ]

let check_flag observed flag =
  let what = "flag " ^ flag in
  match List.assoc_opt flag observed.flags with
  | None -> not_read what
  | Some set ->
      Postcondition.judge what ~expected:"set"
        ~read:(if set then "set" else "clear")
        set

let check_knows observed ({ species; moves } : Postconditions.knows) =
  let what = "knows " ^ species in
  match List.assoc_opt species observed.knows with
  | None -> not_read what
  | Some read ->
      Postcondition.judge what ~expected:(String.concat ", " moves)
        ~read:(String.concat ", " read)
        (List.for_all (fun m -> List.mem m read) moves)

let check_level observed ({ species; min } : Postconditions.level) =
  let what = "level " ^ species in
  match List.assoc_opt species observed.levels with
  | None -> not_read what
  | Some read ->
      Postcondition.judge what
        ~expected:(Printf.sprintf "at least Lv %d" min)
        ~read:(Printf.sprintf "Lv %d" read)
        (read >= min)

(* The promised slots only: a party with more members than promised marks
   is checked on the slots named. *)
let check_marks expected observed =
  match (expected, observed.marks) with
  | None, _ -> []
  | Some _, None -> [ not_read "marks" ]
  | Some marks, Some read ->
      let shown = List.filteri (fun i _ -> i < List.length marks) read in
      [
        Postcondition.judge "marks" ~expected:(String.concat ", " marks)
          ~read:(String.concat ", " shown) (shown = marks);
      ]

let check (expected : Postconditions.t) observed =
  List.concat
    [
      check_party expected.party observed;
      List.map (check_item observed) expected.items;
      check_coins expected.coins observed;
      check_caught expected.caught observed;
      check_money expected.money observed;
      List.map (check_flag observed) expected.flags;
      List.map (check_knows observed) expected.knows;
      List.map (check_level observed) expected.levels;
      check_marks expected.marks observed;
    ]

let unmet = Postcondition.unmet
let result_to_string = Postcondition.result_to_string
let log_lines = Postcondition.log_lines ~tag:"Postcondition"
