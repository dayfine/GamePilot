(* Postcondition_check: each postcondition the plan states against what the
   game read, passed, failed or not checked, and the log lines. *)

open Story
module C = Postcondition_check

let nothing : Plan.postconditions =
  {
    position = None;
    party = None;
    items = [];
    coins = None;
    money = None;
    flags = [];
    knows = [];
    levels = [];
  }

let read = C.nothing_read
let some = List.map Option.some

let check promised observed =
  String.concat "\n" (List.map C.result_to_string (C.check promised observed))

let case name promised observed expectation : Case_table.case =
  { name; input = (fun () -> check promised observed); expectation }

let mg01_party = [ "blastoise"; "rattata"; "oddish"; "pidgey"; "abra" ]
let in_order = { nothing with party = Some (Party_in_order mg01_party) }
let includes l = { nothing with party = Some (Party_includes l) }
let party members = { read with party = Some members }
let money min max = { nothing with money = Some { min; max } }

let party_cases =
  [
    case "party in order, as read" in_order
      (party (some mg01_party))
      "party: passed: blastoise, rattata, oddish, pidgey, abra";
    case "party in order, the prize missing (mg-01's false pass)" in_order
      (party (some [ "blastoise"; "rattata"; "oddish"; "pidgey" ]))
      "party: failed: expected blastoise, rattata, oddish, pidgey, abra, read \
       blastoise, rattata, oddish, pidgey";
    case "party in order, two members swapped" in_order
      (party (some [ "rattata"; "blastoise"; "oddish"; "pidgey"; "abra" ]))
      "party: failed: expected blastoise, rattata, oddish, pidgey, abra, read \
       rattata, blastoise, oddish, pidgey, abra";
    case "party in order, a member unread and the rest right" in_order
      (party
         [ Some "blastoise"; None; Some "oddish"; Some "pidgey"; Some "abra" ])
      "party: not checked: read blastoise, ?, oddish, pidgey, abra";
    case "party in order, a member unread and another wrong" in_order
      (party [ Some "pidgey"; None; Some "oddish"; Some "pidgey"; Some "abra" ])
      "party: failed: expected blastoise, rattata, oddish, pidgey, abra, read \
       pidgey, ?, oddish, pidgey, abra";
    case "party includes, anywhere" (includes [ "abra" ])
      (party (some mg01_party))
      "party: passed: blastoise, rattata, oddish, pidgey, abra";
    case "party includes a species twice, one there"
      (includes [ "pidgey"; "pidgey" ])
      (party (some mg01_party))
      "party: failed: expected pidgey, pidgey among the members, read \
       blastoise, rattata, oddish, pidgey, abra";
    case "party includes, missing but a member unread" (includes [ "abra" ])
      (party [ Some "blastoise"; None ])
      "party: not checked: read blastoise, ?";
    case "party not read" in_order read
      "party: not checked: the game can't read it";
  ]

let count_cases =
  [
    case "an item count as read"
      { nothing with items = [ { item = "retro-mail"; quantity = 2 } ] }
      { read with items = [ ("retro-mail", 2) ] }
      "item retro-mail: passed: 2";
    case "an item count off"
      { nothing with items = [ { item = "retro-mail"; quantity = 2 } ] }
      { read with items = [ ("retro-mail", 0) ] }
      "item retro-mail: failed: expected 2, read 0";
    case "an item not read"
      { nothing with items = [ { item = "retro-mail"; quantity = 2 } ] }
      read "item retro-mail: not checked: the game can't read it";
    case "coins as read"
      { nothing with coins = Some 20 }
      { read with coins = Some 20 }
      "coins: passed: 20";
    case "coins not spent on the prize"
      { nothing with coins = Some 20 }
      { read with coins = Some 200 }
      "coins: failed: expected 20, read 200";
    case "money exactly" (money 25014 25014)
      { read with money = Some 25014 }
      "money: passed: $25014";
    case "money off" (money 25014 25014)
      { read with money = Some 29114 }
      "money: failed: expected $25014, read $29114";
    case "money in a range, at its top" (money 100 200)
      { read with money = Some 200 }
      "money: passed: $200";
    case "money below a range" (money 100 200)
      { read with money = Some 99 }
      "money: failed: expected $100 to $200, read $99";
    case "a flag no game reads"
      { nothing with flags = [ "got_coin_case" ] }
      read "flag got_coin_case: not checked: the game can't read it";
    case "a flag read clear"
      { nothing with flags = [ "got_coin_case" ] }
      { read with flags = [ ("got_coin_case", false) ] }
      "flag got_coin_case: failed: expected set, read clear";
    case "nothing promised, nothing checked" nothing (party []) "";
  ]

let mimien_recycle =
  { nothing with knows = [ { species = "mr-mime"; moves = [ "recycle" ] } ] }

let knows_cases =
  [
    case "MIMIEN knows Recycle (mg-04's goal)" mimien_recycle
      {
        read with
        knows = [ ("mr-mime", [ "recycle"; "barrier"; "confusion"; "-" ]) ];
      }
      "knows mr-mime: passed: recycle, barrier, confusion, -";
    case "MIMIEN without Recycle" mimien_recycle
      { read with knows = [ ("mr-mime", [ "barrier"; "confusion" ]) ] }
      "knows mr-mime: failed: expected recycle, read barrier, confusion";
    case "MIMIEN's moves not read" mimien_recycle read
      "knows mr-mime: not checked: the game can't read it";
  ]

let mimien_33 = { nothing with levels = [ { species = "mr-mime"; min = 33 } ] }

let level_cases =
  [
    case "MIMIEN at Lv 33 (mg-04's goal)" mimien_33
      { read with levels = [ ("mr-mime", 33) ] }
      "level mr-mime: passed: Lv 33";
    case "MIMIEN above it" mimien_33
      { read with levels = [ ("mr-mime", 34) ] }
      "level mr-mime: passed: Lv 34";
    case "MIMIEN below it" mimien_33
      { read with levels = [ ("mr-mime", 32) ] }
      "level mr-mime: failed: expected at least Lv 33, read Lv 32";
    case "MIMIEN's level not read" mimien_33 read
      "level mr-mime: not checked: the game can't read it";
  ]

let log name promised observed : Case_table.case =
  {
    name;
    input =
      (fun () ->
        String.concat "\n" (C.log_lines "mg-01" (C.check promised observed)));
    expectation = "";
  }

let log_cases : Case_table.case list =
  [
    {
      (log "the log: one line each and a failed summary"
         { in_order with coins = Some 20; money = Some { min = 1; max = 1 } }
         { (party (some mg01_party)) with coins = Some 200 })
      with
      expectation =
        "[Postcondition] mg-01 party: passed: blastoise, rattata, oddish, \
         pidgey, abra\n\
         [Postcondition] mg-01 coins: failed: expected 20, read 200\n\
         [Postcondition] mg-01 money: not checked: the game can't read it\n\
         [Postcondition] mg-01: 1 passed, 1 failed, 1 not checked: failed";
    };
    {
      (log "the log: incomplete when none failed and one was not read"
         { nothing with coins = Some 20; money = Some { min = 1; max = 1 } }
         { read with coins = Some 20 })
      with
      expectation =
        "[Postcondition] mg-01 coins: passed: 20\n\
         [Postcondition] mg-01 money: not checked: the game can't read it\n\
         [Postcondition] mg-01: 1 passed, 0 failed, 1 not checked: incomplete";
    };
    {
      (log "the log: nothing to check" nothing read) with
      expectation =
        "[Postcondition] mg-01: 0 passed, 0 failed, 0 not checked: nothing to \
         check";
    };
  ]

let () =
  Case_table.run "postcondition_check"
    (party_cases @ count_cases @ knows_cases @ level_cases @ log_cases)
