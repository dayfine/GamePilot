type observed = {
  party : string option list option;
  items : (string * int) list;
  coins : int option;
  money : int option;
  start_money : int option;
  start_coins : int option;
  start_items : (string * int) list;
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
    money = None;
    start_money = None;
    start_coins = None;
    start_items = [];
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

type verdict = Passed | Failed | Not_checked
type result = { what : string; verdict : verdict; detail : string }

let verdict_name = function
  | Passed -> "passed"
  | Failed -> "failed"
  | Not_checked -> "not checked"

let not_read what =
  { what; verdict = Not_checked; detail = "the game can't read it" }

let expected_read what ~expected ~read holds =
  if holds then { what; verdict = Passed; detail = read }
  else
    {
      what;
      verdict = Failed;
      detail = Printf.sprintf "expected %s, read %s" expected read;
    }

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
  then expected_read what ~expected:(String.concat ", " expected) ~read false
  else if unread members > 0 then
    { what; verdict = Not_checked; detail = "read " ^ read }
  else expected_read what ~expected:"" ~read true

(* Each species needs as many members as the list names it. *)
let missing_members expected members =
  List.filter
    (fun s -> count_of s members < count_of s (List.map Option.some expected))
    (List.sort_uniq compare expected)

let wrong_slots slots members =
  List.filter
    (fun ({ slot; species } : Plan.slot) ->
      List.nth_opt members (slot - 1) <> Some (Some species))
    slots

let slot_text ({ slot; species } : Plan.slot) =
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
  | [], [] -> expected_read what ~expected:expected_text ~read true
  | _ when unread members > 0 ->
      { what; verdict = Not_checked; detail = "read " ^ read }
  | _ -> expected_read what ~expected:expected_text ~read false

let check_party (expected : Plan.party option) observed =
  match (expected, observed.party) with
  | None, _ -> []
  | Some _, None -> [ not_read "party" ]
  | Some (Party_in_order list), Some members -> [ in_order list members ]
  | Some (Party_includes { members = list; slots }), Some members ->
      [ includes list slots members ]

let delta_text n =
  if n < 0 then Printf.sprintf "used %d" (-n) else Printf.sprintf "gained %d" n

(* Passed: "gained 1 (4 to 5)"; failed: "expected gained 1, read gained 3 (2
   to 5)". *)
let check_gained what n ~start read =
  let from_to = Printf.sprintf "(%d to %d)" start read in
  expected_read what ~expected:(delta_text n)
    ~read:(delta_text (read - start) ^ " " ^ from_to)
    (read - start = n)

let start_not_read what =
  {
    what;
    verdict = Not_checked;
    detail = "the count at the start was not read";
  }

let check_count what (count : Plan.count) ~start read =
  match (count, start) with
  | Count_exactly n, _ ->
      expected_read what ~expected:(string_of_int n) ~read:(string_of_int read)
        (read = n)
  | Count_at_least n, _ ->
      expected_read what
        ~expected:(Printf.sprintf "at least %d" n)
        ~read:(string_of_int read) (read >= n)
  | Count_gained _, None -> start_not_read what
  | Count_gained n, Some start -> check_gained what n ~start read

let check_item observed ({ bag_item; count } : Plan.bag_count) =
  let what = "item " ^ bag_item in
  match List.assoc_opt bag_item observed.items with
  | None -> not_read what
  | Some read ->
      check_count what count
        ~start:(List.assoc_opt bag_item observed.start_items)
        read

let check_coins expected observed =
  match (expected, observed.coins) with
  | None, _ -> []
  | Some _, None -> [ not_read "coins" ]
  | Some count, Some read ->
      [ check_count "coins" count ~start:observed.start_coins read ]

let money_text money = Printf.sprintf "$%d" money

let range_text min max =
  if min = max then money_text min
  else Printf.sprintf "%s to %s" (money_text min) (money_text max)

let check_range ~min ~max read =
  expected_read "money" ~expected:(range_text min max) ~read:(money_text read)
    (min <= read && read <= max)

(* Passed: "spent $4100 ($29202 to $25102)"; failed: "expected spent $4100,
   read spent $4188 ($29202 to $25014)". *)
let check_spent amount ~start read =
  let spent = start - read in
  let from_to = Printf.sprintf "(%s to %s)" (money_text start) (money_text read)
  and spent_text n = "spent " ^ money_text n in
  if spent = amount then
    {
      what = "money";
      verdict = Passed;
      detail = spent_text spent ^ " " ^ from_to;
    }
  else
    expected_read "money" ~expected:(spent_text amount)
      ~read:(spent_text spent ^ " " ^ from_to)
      false

let check_money (expected : Plan.money option) observed =
  match (expected, observed.money, observed.start_money) with
  | None, _, _ -> []
  | Some _, None, _ -> [ not_read "money" ]
  | Some (Money_range { min; max }), Some read, _ ->
      [ check_range ~min ~max read ]
  | Some (Money_spent _), Some _, None ->
      [
        {
          what = "money";
          verdict = Not_checked;
          detail = "the money at the start was not read";
        };
      ]
  | Some (Money_spent amount), Some read, Some start ->
      [ check_spent amount ~start read ]

let check_flag observed flag =
  let what = "flag " ^ flag in
  match List.assoc_opt flag observed.flags with
  | None -> not_read what
  | Some set ->
      expected_read what ~expected:"set"
        ~read:(if set then "set" else "clear")
        set

let check_knows observed ({ species; moves } : Plan.knows) =
  let what = "knows " ^ species in
  match List.assoc_opt species observed.knows with
  | None -> not_read what
  | Some read ->
      expected_read what ~expected:(String.concat ", " moves)
        ~read:(String.concat ", " read)
        (List.for_all (fun m -> List.mem m read) moves)

let check_level observed ({ species; min } : Plan.level) =
  let what = "level " ^ species in
  match List.assoc_opt species observed.levels with
  | None -> not_read what
  | Some read ->
      expected_read what
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
        expected_read "marks" ~expected:(String.concat ", " marks)
          ~read:(String.concat ", " shown) (shown = marks);
      ]

let check (expected : Plan.postconditions) observed =
  List.concat
    [
      check_party expected.party observed;
      List.map (check_item observed) expected.items;
      check_coins expected.coins observed;
      check_money expected.money observed;
      List.map (check_flag observed) expected.flags;
      List.map (check_knows observed) expected.knows;
      List.map (check_level observed) expected.levels;
      check_marks expected.marks observed;
    ]

let unmet = List.filter (fun r -> r.verdict <> Passed)

let result_to_string r =
  Printf.sprintf "%s: %s: %s" r.what (verdict_name r.verdict) r.detail

let count verdict results =
  List.length (List.filter (fun r -> r.verdict = verdict) results)

let summary results =
  if results = [] then "nothing to check"
  else if count Failed results > 0 then "failed"
  else if count Not_checked results > 0 then "incomplete"
  else "passed"

let log_lines checkpoint results =
  List.map
    (fun r ->
      Printf.sprintf "[Postcondition] %s %s" checkpoint (result_to_string r))
    results
  @ [
      Printf.sprintf
        "[Postcondition] %s: %d passed, %d failed, %d not checked: %s"
        checkpoint (count Passed results) (count Failed results)
        (count Not_checked results)
        (summary results);
    ]
