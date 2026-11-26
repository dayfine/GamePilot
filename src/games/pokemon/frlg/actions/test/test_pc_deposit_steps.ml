(* Pc_deposit_steps: what the PC deposit presses on each look, from the
   overworld facing the PC to the overworld again (the looks of mGBA run
   pc-01 testing 3, 2026-11-23, and the cases the fork's dialog refuses), and
   a fake PC as far as the party panel. *)

open Frlg_actions
module S = Frlg_readers.Pc_screen
module P = Pc_deposit_steps

let look ?cursor ?label ?species ?(box_full = false) ?(remove_mail = false)
    screen : P.look =
  { view = { screen; cursor }; label; species; box_full; remove_mail }

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

(* A message that waits for a button reads at two looks in a row: B at the
   second. *)
let to_panel =
  [
    look Overworld;
    look Text;
    look Text;
    look Pc_list ~cursor:0 ~label:"BILL'S PC";
    look Text;
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

let case name input expectation : Table_test.case = { name; input; expectation }

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
      "A wait B A wait B DOWN A wait DOWN A A A A A A B B B B done";
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
    case
      "viridian-forest run 1 (2026-11-25): Farfetch'd holds Retro Mail, the \
       game refuses: fail, not STORE again"
      (presses [ "farfetchd" ]
         (to_panel
         @ [
             look Party_panel ~cursor:2 ~species:"farfetchd";
             look Mon_menu ~cursor:0 ~label:"STORE";
             look Party_panel ~cursor:6 ~species:"farfetchd" ~remove_mail:true;
           ]))
      "A wait B A wait B DOWN A wait A A fail: farfetchd holds Mail: the game \
       will not store it (\"Please remove the MAIL.\")";
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
    case
      "the PC list opens behind \"Which PC should be accessed?\" still \
       printing: no B, the list's top row chosen"
      (presses [ "eevee" ]
         [
           look Overworld;
           look Text;
           look Text;
           look Text;
           look Pc_list ~cursor:0 ~label:"BILL'S PC";
         ])
      "A wait B wait A";
    case "a fade between two looks at one message: B at the second"
      (presses [ "eevee" ] [ look Overworld; look Text; look Other; look Text ])
      "A wait wait B";
    case "a message, then another screen, then a message: a wait again"
      (presses [ "eevee" ]
         [
           look Overworld;
           look Text;
           look Pc_list ~cursor:1 ~label:"MY PC";
           look Text;
         ])
      "A wait UP wait";
    case "a fade that never ends"
      (presses [ "eevee" ] (List.init P.max_others (fun _ -> look Other)))
      "wait wait wait wait wait wait wait wait wait fail: no PC screen settled \
       in 10 looks";
  ]

(* A fake PC from the overworld to DEPOSIT's party panel: A at the PC boots
   it ("booted up the PC.", a message that waits for a button), B on that the
   PC list, A on its top row "Accessed BILL's PC." (a message too), B on that
   the storage menu, DOWN to DEPOSIT, A the party panel. [late_list] puts
   "Which PC should be accessed?" between the boot message and the list, as
   pokefirered pc.inc does: a message still printing, the list behind it at
   the next press, which a B lands on and cancels, turning the PC off
   (Pc_box's walk on console B, 2026-11-25). *)
type fake = {
  mutable screen : S.screen;
  mutable cursor : int;
  mutable after_b : S.screen;  (** Where B on the message leads. *)
  mutable which_pc : bool;  (** "Which PC should be accessed?" printing. *)
  late_list : bool;
  mutable presses : string list;
}

let fake_look g =
  match g.screen with
  | Pc_list -> look Pc_list ~cursor:g.cursor ~label:"BILL'S PC"
  | Storage_menu ->
      look Storage_menu ~cursor:g.cursor
        ~label:(if g.cursor = 1 then "DEPOSIT POKéMON" else "WITHDRAW POKéMON")
  | Party_panel -> look Party_panel ~cursor:0 ~species:"pidgey"
  | screen -> look screen

let go g screen =
  g.screen <- screen;
  g.cursor <- 0

let message g after_b =
  go g Text;
  g.after_b <- after_b

let fake_press g (p : P.press) =
  g.presses <- P.press_to_string p :: g.presses;
  if g.which_pc then (
    g.which_pc <- false;
    go g (if p = B then Overworld else Pc_list))
  else
    match (g.screen, p) with
    | Overworld, A -> message g Pc_list
    | Text, B when g.after_b = Pc_list && g.late_list -> g.which_pc <- true
    | Text, B -> go g g.after_b
    | Pc_list, A -> message g Storage_menu
    | Storage_menu, Down -> g.cursor <- g.cursor + 1
    | Storage_menu, A when g.cursor = 1 -> go g Party_panel
    | _ -> ()

let max_fake_looks = 30

let rec walk g t n =
  match (g.screen, P.next t (fake_look g)) with
  | Party_panel, _ -> "party panel"
  | _, (_, Fail why) -> "fail: " ^ why
  | _ when n = 0 -> "no end"
  | _, (t, p) ->
      fake_press g p;
      walk g t (n - 1)

let to_party_panel late_list () =
  let g =
    {
      screen = Overworld;
      cursor = 0;
      after_b = Overworld;
      which_pc = false;
      late_list;
      presses = [];
    }
  in
  let reached = walk g (P.start [ "pidgey" ]) max_fake_looks in
  Printf.sprintf "%s after [%s]" reached
    (String.concat " " (List.rev g.presses))

let fake_cases =
  [
    case "fake PC: to the party panel" (to_party_panel false)
      "party panel after [A wait B A wait B DOWN A]";
    case "fake PC: the list behind a printing message gets a wait, not B"
      (to_party_panel true) "party panel after [A wait B wait A wait B DOWN A]";
  ]

let () = Table_test.run "pc deposit steps" (cases @ fake_cases)
