(* Room_policy: who goes to the PC when a chain needs free party slots. *)

open Checkpoints_run
module R = Room_policy

let frlg_field_moves = [ "cut"; "fly"; "surf"; "strength" ]

(* The Mail Glitch chain's members (mg-01..mg-06). *)
let rules : R.rules =
  {
    party_size = 6;
    used = [ "blastoise"; "oddish"; "pidgey"; "rattata" ];
    field_moves = frlg_field_moves;
    needed_moves = [ "cut" ];
    lead_stays = true;
  }

let two_free : R.precondition = { free_slots = 2 }

let party l : R.member list =
  List.mapi
    (fun i (species, level, moves) -> { R.slot = i + 1; species; level; moves })
    l

(* Console B's save on 2026-11-23 (Pallet Town, after the Hall of Fame):
   species and levels as read; the moves are what a plain run would have them
   know. *)
let console_b =
  party
    [
      ("blastoise", Some 59, Some [ "surf"; "strength"; "blizzard"; "bite" ]);
      ("eevee", Some 25, Some [ "tackle"; "tail-whip"; "bite"; "quick-attack" ]);
      ("pidgey", Some 24, Some [ "fly"; "gust"; "quick-attack"; "sand-attack" ]);
      ("oddish", Some 12, Some [ "cut"; "absorb"; "poison-powder"; "acid" ]);
      ("lapras", Some 25, Some [ "surf"; "sing"; "mist"; "body-slam" ]);
      ("magikarp", Some 5, Some [ "splash" ]);
    ]

(* The mGBA save at mg-04's start (Lavender Center, after mg-03's trade). *)
let mgba_mg04 =
  party
    [
      ("blastoise", Some 36, Some [ "surf"; "bite"; "water-gun"; "withdraw" ]);
      ("rattata", Some 15, Some [ "tackle"; "tail-whip"; "quick-attack" ]);
      ("oddish", Some 15, Some [ "cut"; "absorb"; "poison-powder" ]);
      ("pidgey", Some 16, Some [ "fly"; "gust"; "sand-attack" ]);
      ("mr-mime", Some 9, Some [ "confusion"; "barrier" ]);
      ( "farfetchd",
        Some 6,
        Some [ "peck"; "sand-attack"; "leer"; "fury-attack" ] );
    ]

let choose ?(rules = rules) ?(need = two_free) members () =
  match R.choose rules need members with
  | Ok plan -> R.plan_to_string plan
  | Error e -> "stop: " ^ e

let case name input expectation : Table_test.case = { name; input; expectation }
let first n l = List.filteri (fun i _ -> i < n) l

let cases =
  [
    case "console B: Magikarp (Lv 5), then Eevee (Lv 25, before Lapras)"
      (choose console_b) "deposit eevee (slot 2), magikarp (slot 6)";
    case "console B, one slot: Magikarp"
      (choose ~need:{ free_slots = 1 } console_b)
      "deposit magikarp (slot 6)";
    case "console B, four members: room enough"
      (choose (first 4 console_b))
      "nothing to deposit";
    case "mGBA mg-04 start: the two lowest that nobody uses" (choose mgba_mg04)
      "deposit mr-mime (slot 5), farfetchd (slot 6)";
    case "the lead stays though no plan names it"
      (choose ~rules:{ rules with used = [] } ~need:{ free_slots = 6 } console_b)
      "stop: 6 to deposit, 2 may go; kept: blastoise: it leads; pidgey: it \
       knows fly; oddish: only it knows cut; lapras: it knows surf";
    case "lead_stays off: the lead may go"
      (choose
         ~rules:{ rules with lead_stays = false }
         ~need:{ free_slots = 1 }
         (party
            (("magikarp", Some 5, Some [ "splash" ])
            :: List.map
                 (fun s -> (s, Some 30, Some [ "tackle" ]))
                 [ "blastoise"; "oddish"; "pidgey"; "rattata"; "pidgey" ])))
      "deposit magikarp (slot 1)";
    case "a needed move outside the game's list: the only knower stays"
      (choose
         ~rules:{ rules with field_moves = []; needed_moves = [ "cut" ] }
         ~need:{ free_slots = 2 } console_b)
      "deposit eevee (slot 2), magikarp (slot 6)";
    case "two members know Cut: one may go, the other then stays"
      (choose
         ~rules:
           { rules with used = []; field_moves = []; needed_moves = [ "cut" ] }
         ~need:{ free_slots = 4 }
         (party
            [
              ("blastoise", Some 59, Some [ "surf" ]);
              ("oddish", Some 12, Some [ "cut" ]);
              ("paras", Some 10, Some [ "cut" ]);
              ("magikarp", Some 5, Some [ "splash" ]);
              ("eevee", Some 25, Some [ "tackle" ]);
              ("lapras", Some 25, Some [ "sing" ]);
            ]))
      "deposit paras (slot 3), magikarp (slot 4), eevee (slot 5), lapras (slot \
       6)";
    case "moves not read: the member stays"
      (choose
         (List.map (fun (m : R.member) -> { m with moves = None }) console_b))
      "stop: 2 to deposit, 0 may go; kept: blastoise: the plans use it; eevee: \
       its moves did not read; pidgey: the plans use it; oddish: the plans use \
       it; lapras: its moves did not read; magikarp: its moves did not read";
    case "a level not read goes last"
      (choose
         (party
            [
              ("blastoise", Some 59, Some [ "surf" ]);
              ("eevee", None, Some [ "tackle" ]);
              ("lapras", Some 50, Some [ "sing" ]);
              ("magikarp", Some 5, Some [ "splash" ]);
              ("pidgey", Some 24, Some [ "fly" ]);
              ("oddish", Some 12, Some [ "cut" ]);
            ]))
      "deposit lapras (slot 3), magikarp (slot 4)";
    case "the precondition: 4 members, 2 free"
      (fun () -> string_of_bool (R.holds rules two_free 4))
      "true";
    case "the precondition: 5 members, 1 free"
      (fun () -> string_of_bool (R.holds rules two_free 5))
      "false";
    case "a member, as logged"
      (fun () -> R.member_to_string (List.nth console_b 5))
      "magikarp Lv 5 (splash)";
  ]

let () = Table_test.run "room policy" cases
