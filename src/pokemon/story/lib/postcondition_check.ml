type observed = {
  party : string option list option;
  items : (string * int) list;
  coins : int option;
  money : int option;
  flags : (string * bool) list;
}

let nothing_read =
  { party = None; items = []; coins = None; money = None; flags = [] }

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
let includes expected members =
  let what = "party" and read = party_text members in
  let missing =
    List.filter
      (fun s -> count_of s members < count_of s (List.map Option.some expected))
      (List.sort_uniq compare expected)
  in
  let expected_text = String.concat ", " expected ^ " among the members" in
  match missing with
  | [] -> expected_read what ~expected:expected_text ~read true
  | _ when unread members > 0 ->
      { what; verdict = Not_checked; detail = "read " ^ read }
  | _ -> expected_read what ~expected:expected_text ~read false

let check_party (expected : Plan.party option) observed =
  match (expected, observed.party) with
  | None, _ -> []
  | Some _, None -> [ not_read "party" ]
  | Some (Party_in_order list), Some members -> [ in_order list members ]
  | Some (Party_includes list), Some members -> [ includes list members ]

let check_item observed ({ item; quantity } : Plan.item) =
  let what = "item " ^ item in
  match List.assoc_opt item observed.items with
  | None -> not_read what
  | Some count ->
      expected_read what ~expected:(string_of_int quantity)
        ~read:(string_of_int count) (count = quantity)

let check_coins expected observed =
  match (expected, observed.coins) with
  | None, _ -> []
  | Some _, None -> [ not_read "coins" ]
  | Some coins, Some read ->
      [
        expected_read "coins" ~expected:(string_of_int coins)
          ~read:(string_of_int read) (read = coins);
      ]

let money_text money = Printf.sprintf "$%d" money

let range_text ({ min; max } : Plan.money) =
  if min = max then money_text min
  else Printf.sprintf "%s to %s" (money_text min) (money_text max)

let check_money (expected : Plan.money option) observed =
  match (expected, observed.money) with
  | None, _ -> []
  | Some _, None -> [ not_read "money" ]
  | Some range, Some read ->
      [
        expected_read "money" ~expected:(range_text range)
          ~read:(money_text read)
          (range.min <= read && read <= range.max);
      ]

let check_flag observed flag =
  let what = "flag " ^ flag in
  match List.assoc_opt flag observed.flags with
  | None -> not_read what
  | Some set ->
      expected_read what ~expected:"set"
        ~read:(if set then "set" else "clear")
        set

let check (expected : Plan.postconditions) observed =
  List.concat
    [
      check_party expected.party observed;
      List.map (check_item observed) expected.items;
      check_coins expected.coins observed;
      check_money expected.money observed;
      List.map (check_flag observed) expected.flags;
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
