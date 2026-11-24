(* Pc_deposit_steps: what the PC deposit presses on each look, from the
   overworld facing the PC to the overworld again (the looks of mGBA run
   pc-01 testing 3, 2026-11-23, and the cases the fork's dialog refuses). *)

open Frlg_actions
module S = Frlg_readers.Pc_screen
module P = Pc_deposit_steps

let look ?cursor ?label ?species ?(box_full = false) screen : P.look =
  { view = { screen; cursor }; label; species; box_full }

(* Feeds the looks in order; the presses, one per look. *)
let presses targets looks () =
  let _, out =
    List.fold_left
      (fun (t, out) l ->
        let t, p = P.next t l in
        (t, P.press_to_string p :: out))
      (P.start targets, [])
      looks
  in
  String.concat " " (List.rev out)

let to_panel =
  [
    look Overworld;
    look Text;
    look Pc_list ~cursor:0 ~label:"BILL'S PC";
    look Text;
    look Storage_menu ~cursor:0 ~label:"WITHDRAW POKéMON";
    look Storage_menu ~cursor:1 ~label:"DEPOSIT POKéMON";
    look Other;
  ]

let store species cursor =
  [
    look Party_panel ~cursor ~species;
    look Mon_menu ~cursor:0 ~label:"STORE";
    look Box_chooser;
  ]

let case name input expectation : Case_table.case = { name; input; expectation }

let cases =
  [
    case "mGBA pc-01: Mr. Mime then Farfetch'd, and out"
      (presses [ "mr-mime"; "farfetchd" ]
         (to_panel
         @ [ look Party_panel ~cursor:0 ~species:"blastoise" ]
         @ store "mr-mime" 4 @ store "farfetchd" 4
         @ [
             look Party_panel ~cursor:4;
             look Yes_no ~cursor:1;
             look Storage_menu ~cursor:1 ~label:"DEPOSIT POKéMON";
             look Pc_list ~cursor:0 ~label:"BILL'S PC";
             look Overworld;
           ]))
      "A B A B DOWN A wait DOWN A A A A A A B B B B done";
    case "a Pokémon's menu not on STORE: no A"
      (presses [ "eevee" ]
         [ look Overworld; look Mon_menu ~cursor:3 ~label:"RELEASE" ])
      "A fail: the Pokemon's menu is not on STORE";
    case "STORE's row not read: no A"
      (presses [ "eevee" ] [ look Overworld; look Mon_menu ~cursor:0 ])
      "A fail: the Pokemon's menu is not on STORE";
    case "the box is full: B, then RIGHT to the next box, then A"
      (presses [ "eevee" ]
         [
           look Overworld;
           look Party_panel ~cursor:1 ~species:"eevee";
           look Mon_menu ~cursor:0 ~label:"STORE";
           look Box_chooser;
           look Box_chooser ~box_full:true;
           look Box_chooser;
           look Box_chooser;
           look Party_panel ~cursor:1;
         ])
      "A A A A B RIGHT A B";
    case "the member is not in the party: fail at the last slot"
      (presses [ "eevee" ]
         [
           look Overworld;
           look Party_panel ~cursor:4 ~species:"pidgey";
           look Party_panel ~cursor:5 ~species:"oddish";
         ])
      "A DOWN fail: no eevee in the party panel";
    case "the PC list's top not read: no A"
      (presses [ "eevee" ] [ look Overworld; look Pc_list ~cursor:0 ])
      "A fail: the PC list's top row did not read as a storage PC";
    case "the storage menu's row 2 is not DEPOSIT: no A"
      (presses [ "eevee" ]
         [ look Overworld; look Storage_menu ~cursor:1 ~label:"MOVE ITEMS" ])
      "A fail: the storage menu's row 2 did not read as DEPOSIT";
    case "a fade that never ends"
      (presses [ "eevee" ] (List.init P.max_others (fun _ -> look Other)))
      "wait wait wait wait wait wait wait wait wait fail: no PC screen settled \
       in 10 looks";
  ]

let () = Case_table.run "pc deposit steps" cases
