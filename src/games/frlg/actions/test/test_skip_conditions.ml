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
  ]

let () = Table_test.run "skip_conditions" cases
