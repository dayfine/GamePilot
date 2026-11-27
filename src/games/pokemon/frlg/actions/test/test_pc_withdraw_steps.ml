(* Pc_withdraw_steps: what the PC withdraw presses on each look, from the
   overworld facing the PC to the overworld again, and the species it took. *)

open Frlg_actions
module P = Pc_withdraw_steps

let look ?cursor ?label ?species ?panel_empty ?holds_item screen : P.look =
  { view = { screen; cursor }; label; species; panel_empty; holds_item }

let empty_slot = look Box_grid ~panel_empty:true

let occupied species =
  look Overworld ~species ~panel_empty:false ~holds_item:false

let holding species =
  look Overworld ~species ~panel_empty:false ~holds_item:true

(* Feeds the looks in order; the presses, one per look, and the species
   withdrawn. *)
let presses looks () =
  let t, out =
    List.fold_left
      (fun (t, out) l ->
        let t, p = P.next t l in
        (t, Pc_deposit_steps.press_to_string p :: out))
      (P.start, []) looks
  in
  String.concat " " (List.rev out)
  ^ Option.fold ~none:"" ~some:(fun s -> " | " ^ s) (P.withdrawn t)

let to_box =
  [
    look Overworld;
    look Text;
    look Pc_list ~cursor:0 ~label:"BILL'S PC";
    look Text;
    look Storage_menu ~cursor:0 ~label:"WITHDRAW POKéMON";
    look Storage_menu ~cursor:0 ~label:"WITHDRAW POKéMON";
    look Other;
  ]

let take species =
  [
    occupied species;
    look Mon_menu ~cursor:0 ~label:"WITHDRAW";
    occupied species;
    look Party_panel ~cursor:0;
    empty_slot;
  ]

let out =
  [
    look Yes_no ~cursor:0;
    look Other;
    look Storage_menu ~cursor:0 ~label:"WITHDRAW POKéMON";
    look Pc_list ~cursor:0 ~label:"BILL'S PC";
    look Overworld;
    look Overworld;
  ]

let case name input expectation : Table_test.case = { name; input; expectation }

let cases =
  [
    case "the first slot holds a Pokémon: withdrawn, and out"
      (presses (to_box @ take "magikarp" @ out))
      "A wait A wait A wait wait A A wait wait B B wait B B wait done | \
       magikarp";
    case "empty slots: RIGHT along the first row, DOWN, LEFT along the second"
      (presses
         (to_box @ List.init 7 (fun _ -> empty_slot) @ take "oddish" @ out))
      "A wait A wait A wait wait RIGHT RIGHT RIGHT RIGHT RIGHT DOWN LEFT A A \
       wait wait B B wait B B wait done | oddish";
    case "a panel with no species: looked at twice, then passed"
      (presses
         (to_box
         @ [
             look Overworld ~panel_empty:false;
             look Overworld ~panel_empty:false;
           ]
         @ take "pidgey" @ out))
      "A wait A wait A wait wait wait RIGHT A A wait wait B B wait B B wait \
       done | pidgey";
    case "an empty box: fail at the last slot"
      (presses (to_box @ List.init P.box_slots (fun _ -> empty_slot)))
      ("A wait A wait A wait wait "
      ^ String.concat " "
          (List.concat
             (List.init 5 (fun row ->
                  List.init 5 (fun _ ->
                      if row mod 2 = 0 then "RIGHT" else "LEFT")
                  @ if row < 4 then [ "DOWN" ] else [])))
      ^ " fail: no Pokemon holding nothing in the box the PC opened on");
    case "the party is full: the message fails it"
      (presses
         (to_box
         @ [
             occupied "magikarp";
             look Mon_menu ~cursor:0 ~label:"WITHDRAW";
             look Text;
           ]))
      "A wait A wait A wait wait A A fail: a message after WITHDRAW (the party \
       is full?)";
    case "a Pokémon's menu not on WITHDRAW: no A"
      (presses
         (to_box
         @ [ occupied "magikarp"; look Mon_menu ~cursor:3 ~label:"RELEASE" ]))
      "A wait A wait A wait wait A fail: the Pokemon's menu is not on WITHDRAW";
    case "mGBA mk-seen (2026-11-25): the menu's first frame unread, waited for"
      (presses
         (to_box
         @ [
             occupied "magikarp";
             look Mon_menu;
             look Mon_menu ~cursor:0 ~label:"WITHDRAW";
             occupied "magikarp";
             empty_slot;
           ]
         @ out))
      "A wait A wait A wait wait A wait A wait B B wait B B wait done | \
       magikarp";
    case "a menu that never reads: fail after three looks"
      (presses
         (to_box
         @ [ occupied "magikarp"; look Mon_menu; look Mon_menu; look Mon_menu ]
         ))
      "A wait A wait A wait wait A wait wait fail: the Pokemon's menu is not \
       on WITHDRAW";
    case "MIMIEN holding an Antidote first: passed, the next one taken"
      (presses (to_box @ [ holding "mr-mime" ] @ take "magikarp" @ out))
      "A wait A wait A wait wait RIGHT A A wait wait B B wait B B wait done | \
       magikarp";
    case "the item line unread: looked at twice, then passed"
      (presses
         (to_box
         @ [
             look Overworld ~species:"magikarp" ~panel_empty:false;
             look Overworld ~species:"magikarp" ~panel_empty:false;
           ]
         @ take "pidgey" @ out))
      "A wait A wait A wait wait wait RIGHT A A wait wait B B wait B B wait \
       done | pidgey";
    case "a message while opening: wait at the first look, B at the second"
      (presses [ look Overworld; look Text; look Text; look Text ])
      "A wait B wait";
    case "a fade between two message looks: still the second look, B"
      (presses [ look Overworld; look Text; look Other; look Text ])
      "A wait wait B";
    case "the PC list between two messages: the second message waits too"
      (presses
         [
           look Overworld;
           look Text;
           look Pc_list ~cursor:0 ~label:"BILL'S PC";
           look Text;
         ])
      "A wait A wait";
    case "the storage menu's row 1 not read as WITHDRAW: no A"
      (presses [ look Overworld; look Storage_menu ~cursor:0 ~label:"SEE YA!" ])
      "A fail: the storage menu's row 1 did not read as WITHDRAW";
    case "the storage menu's cursor lower: UP"
      (presses [ look Overworld; look Storage_menu ~cursor:2 ])
      "A UP";
    case "the overworld after A: the PC did not boot"
      (presses (List.init 5 (fun _ -> look Overworld)))
      "A wait wait wait fail: the overworld came back before the withdraw";
    case "one overworld look while leaving: looked at again"
      (presses
         (to_box @ take "magikarp"
         @ [
             look Overworld;
             look Pc_list ~cursor:0;
             look Overworld;
             look Overworld;
           ]))
      "A wait A wait A wait wait A A wait wait B wait B wait done | magikarp";
    case "a fade that never ends"
      (presses (List.init Pc_deposit_steps.max_others (fun _ -> look Other)))
      "wait wait wait wait wait wait wait wait wait fail: no PC screen settled \
       in 10 looks";
  ]

let () = Table_test.run "pc withdraw steps" cases
