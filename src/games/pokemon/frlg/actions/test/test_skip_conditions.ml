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

let sample_marks = Ok Frlg_readers.Party_menu.[ Held_item; Mail; No_mark; Mail ]

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
  ]

let () = Table_test.run "skip_conditions" cases
