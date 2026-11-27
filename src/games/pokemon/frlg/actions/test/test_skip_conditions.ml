(* Skip_conditions.remembered: each condition read at most once, its first
   answer kept, as read_once does for a checkpoint run. *)

let case name input expectation = { Table_test.name; input; expectation }

(* Asks [read] through [remembered] for each condition in [asks]; the answers
   and how many reads happened. *)
let asked answer asks () =
  let reads = ref 0 in
  let read condition =
    incr reads;
    answer condition !reads
  in
  let ask = Frlg_actions.Skip_conditions.remembered read in
  let answers = List.map (fun c -> string_of_bool (ask c)) asks in
  Printf.sprintf "%s; %d read(s)" (String.concat " " answers) !reads

let seen_from_read n _ reads = reads >= n

let syntax_result c () =
  match Frlg_actions.Skip_conditions.check_syntax c with
  | Ok () -> "ok"
  | Error e -> "error: " ^ e

let mail_result slot marks () =
  let what, holds = Frlg_actions.Skip_conditions.mail_answer ~slot marks in
  Printf.sprintf "%s (%b)" what holds

let species_result species members () =
  let what, holds =
    Frlg_actions.Skip_conditions.species_answer ~species members
  in
  Printf.sprintf "%s (%b)" what holds

let bag_result min_qty count () =
  let what, holds = Frlg_actions.Skip_conditions.bag_answer ~min_qty count in
  Printf.sprintf "%s (%b)" what holds

let coins_result min count () =
  let what, holds = Frlg_actions.Skip_conditions.coins_answer ~min count in
  Printf.sprintf "%s (%b)" what holds

let check_species_result c () =
  let species = [ ("abra", "ABRA"); ("spearow", "SPEAROW") ] in
  match Frlg_actions.Skip_conditions.check species c with
  | Ok () -> "ok"
  | Error e -> "error: " ^ e

let sample_marks = Ok Frlg_readers.Party_menu.[ Held_item; Mail; No_mark; Mail ]
let sample_party = Ok [ Some "blastoise"; Some "abra"; None ]

let cases =
  [
    case "one condition asked three times is read once"
      (asked
         (fun _ _ -> true)
         [
           "pokedex_seen:magikarp";
           "pokedex_seen:magikarp";
           "pokedex_seen:magikarp";
         ])
      "true true true; 1 read(s)";
    case "the first answer is kept though the game's changes"
      (asked (seen_from_read 2)
         [ "pokedex_seen:magikarp"; "pokedex_seen:magikarp" ])
      "false false; 1 read(s)";
    case "each condition is read once"
      (asked
         (fun c _ -> c = "pokedex_seen:eevee")
         [
           "pokedex_seen:magikarp";
           "pokedex_seen:eevee";
           "pokedex_seen:magikarp";
         ])
      "false true false; 2 read(s)";
    case "party_slot_holds_mail:2 syntax ok"
      (syntax_result "party_slot_holds_mail:2")
      "ok";
    case "party_slot_holds_mail:0 rejected"
      (syntax_result "party_slot_holds_mail:0")
      "error: skip_if party_slot_holds_mail:0: 0 is not a party slot (1..6)";
    case "party_slot_holds_mail:7 rejected"
      (syntax_result "party_slot_holds_mail:7")
      "error: skip_if party_slot_holds_mail:7: 7 is not a party slot (1..6)";
    case "party_slot_holds_mail:two rejected"
      (syntax_result "party_slot_holds_mail:two")
      "error: skip_if party_slot_holds_mail:two: two is not a party slot (1..6)";
    case "party_has_species:abra syntax ok"
      (syntax_result "party_has_species:abra")
      "ok";
    case "party_has_species: empty slug rejected"
      (syntax_result "party_has_species:")
      "error: skip_if party_has_species:: species slug is empty";
    case "party_has_species known species passes check"
      (check_species_result "party_has_species:abra")
      "ok";
    case "party_has_species unknown species rejected by check"
      (check_species_result "party_has_species:missingno")
      "error: skip_if party_has_species:missingno: missingno is no FireRed \
       species";
    case "bag_has_item:coin-case:1 syntax ok"
      (syntax_result "bag_has_item:coin-case:1")
      "ok";
    case "bag_has_item:leppa-berry:0 rejected"
      (syntax_result "bag_has_item:leppa-berry:0")
      "error: skip_if bag_has_item:leppa-berry:0: expected \
       <item-slug>:<min_qty>=1";
    case "bag_has_item:missing-qty rejected"
      (syntax_result "bag_has_item:coin-case")
      "error: skip_if bag_has_item:coin-case: expected <item-slug>:<min_qty>=1";
    case "bag_has_item::1 empty slug rejected"
      (syntax_result "bag_has_item::1")
      "error: skip_if bag_has_item::1: expected <item-slug>:<min_qty>=1";
    case "coins_at_least:200 syntax ok"
      (syntax_result "coins_at_least:200")
      "ok";
    case "coins_at_least:0 rejected"
      (syntax_result "coins_at_least:0")
      "error: skip_if coins_at_least:0: 0 is not a positive coin count";
    case "coins_at_least:abc rejected"
      (syntax_result "coins_at_least:abc")
      "error: skip_if coins_at_least:abc: abc is not a positive coin count";
    case "unknown condition passes syntax check"
      (syntax_result "other_flag")
      "ok";
    case "mail_answer on Mail slot" (mail_result 2 sample_marks) "mail (true)";
    case "mail_answer on Held_item slot"
      (mail_result 1 sample_marks)
      "held (false)";
    case "mail_answer on No_mark slot"
      (mail_result 3 sample_marks)
      "none (false)";
    case "mail_answer beyond party size"
      (mail_result 5 sample_marks)
      "empty (false)";
    case "mail_answer on read error"
      (mail_result 2
         (Error (Pokemon_engine.Failure.cause "no_party" "party did not open")))
      "not read (no_party: party did not open), so not skipped (false)";
    case "species_answer when present"
      (species_result "abra" sample_party)
      "in party (true)";
    case "species_answer when absent"
      (species_result "spearow" sample_party)
      "not in party (false)";
    case "species_answer on read error"
      (species_result "abra"
         (Error (Pokemon_engine.Failure.cause "no_party" "party did not open")))
      "not read (no_party: party did not open), so not skipped (false)";
    case "bag_answer when at least min_qty"
      (bag_result 1 (Ok (Some 1)))
      "1 (need 1) (true)";
    case "bag_answer when below min_qty"
      (bag_result 2 (Ok (Some 1)))
      "1 (need 2) (false)";
    case "bag_answer when unread" (bag_result 1 (Ok None))
      "not read, so not skipped (false)";
    case "bag_answer on read error"
      (bag_result 1
         (Error (Pokemon_engine.Failure.cause "no_bag" "bag did not open")))
      "not read (no_bag: bag did not open), so not skipped (false)";
    case "coins_answer when at least min"
      (coins_result 200 (Ok (Some 250)))
      "250 coins (need 200) (true)";
    case "coins_answer when below min"
      (coins_result 200 (Ok (Some 50)))
      "50 coins (need 200) (false)";
    case "coins_answer when unread"
      (coins_result 200 (Ok None))
      "not read, so not skipped (false)";
    case "coins_answer on read error"
      (coins_result 200
         (Error (Pokemon_engine.Failure.cause "no_bag" "bag did not open")))
      "not read (no_bag: bag did not open), so not skipped (false)";
  ]

let () = Table_test.run "skip_conditions" cases
