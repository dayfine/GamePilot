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

let scan slots =
  List.mapi (fun cursor species -> look Party_panel ~cursor ?species) slots

let case name input expectation : Table_test.case = { name; input; expectation }

let cases =
  [
    case "mGBA pc-01: Mr. Mime then Farfetch'd, and out"
      (presses [ "mr-mime"; "farfetchd" ]
         (to_panel
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "rattata";
               Some "spearow";
               Some "mr-mime";
               Some "farfetchd";
             ]
         @ store "mr-mime" 4
         @ [
             look Party_panel ~cursor:4 ~species:"farfetchd";
             look Party_panel ~cursor:3 ~species:"spearow";
             look Party_panel ~cursor:2 ~species:"rattata";
             look Party_panel ~cursor:1 ~species:"pidgey";
           ]
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "rattata";
               Some "spearow";
               Some "farfetchd";
             ]
         @ [ look Party_panel ~cursor:6 ]
         @ store "farfetchd" 4
         @ [
             look Party_panel ~cursor:4;
             look Yes_no ~cursor:1;
             look Storage_menu ~cursor:1 ~label:"DEPOSIT POKéMON";
             look Pc_list ~cursor:0 ~label:"BILL'S PC";
             look Overworld;
           ]))
      "A wait B A wait B DOWN A wait DOWN DOWN DOWN DOWN DOWN UP A A A UP UP \
       UP UP DOWN DOWN DOWN DOWN DOWN UP A A A B B B B done";
    case "a Pokémon's menu not on STORE: no A"
      (presses [ "eevee" ]
         [ look Overworld; look Mon_menu ~cursor:3 ~label:"RELEASE" ])
      "A fail: the Pokemon's menu is not on STORE";
    case "STORE's row not read: no A"
      (presses [ "eevee" ] [ look Overworld; look Mon_menu ~cursor:0 ])
      "A fail: the Pokemon's menu is not on STORE";
    case "the box is full: B, then RIGHT to the next box, then A"
      (presses [ "eevee" ]
         ([ look Overworld ]
         @ scan [ Some "blastoise"; Some "eevee" ]
         @ [
             look Party_panel ~cursor:6;
             look Party_panel ~cursor:1 ~species:"eevee";
             look Mon_menu ~cursor:0 ~label:"STORE";
             look Box_chooser;
             look Box_chooser ~box_full:true;
             look Box_chooser;
             look Box_chooser;
             look Party_panel ~cursor:1;
           ]))
      "A DOWN DOWN UP A A A B RIGHT A B";
    case
      "viridian-forest run 1 (2026-11-25): Farfetch'd holds Retro Mail, no \
       other copy: scan, step back, dismiss, fail"
      (presses [ "farfetchd" ]
         (to_panel
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "farfetchd";
               Some "spearow";
               Some "oddish";
               Some "rattata";
             ]
         @ [
             look Party_panel ~cursor:4 ~species:"oddish";
             look Party_panel ~cursor:3 ~species:"spearow";
             look Party_panel ~cursor:2 ~species:"farfetchd";
             look Mon_menu ~cursor:0 ~label:"STORE";
             look Party_panel ~cursor:6 ~species:"farfetchd" ~remove_mail:true;
             look Party_panel ~cursor:2 ~species:"farfetchd";
           ]))
      "A wait B A wait B DOWN A wait DOWN DOWN DOWN DOWN DOWN UP UP UP A A B \
       fail: farfetchd holds Mail: the game will not store it (\"Please remove \
       the MAIL.\")";
    case
      "two oddish in party: slot 4 holds Mail, slot 5 has no Mail -> deposits \
       slot 5 directly"
      (presses [ "oddish" ]
         (to_panel
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "rattata";
               Some "spearow";
               Some "oddish";
             ]
         @ store "oddish" 5
         @ [ look Party_panel ~cursor:4 ]))
      "A wait B A wait B DOWN A wait DOWN DOWN DOWN DOWN DOWN A A A B";
    case
      "two oddish in party: slot 5 holds Mail, slot 4 has no Mail -> skip slot \
       5 and store slot 4"
      (presses [ "oddish" ]
         (to_panel
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "rattata";
               Some "spearow";
               Some "oddish";
             ]
         @ [
             look Party_panel ~cursor:5 ~species:"oddish";
             look Mon_menu ~cursor:0 ~label:"STORE";
             look Party_panel ~cursor:6 ~species:"oddish" ~remove_mail:true;
             look Party_panel ~cursor:5 ~species:"oddish";
           ]
         @ store "oddish" 4
         @ [ look Party_panel ~cursor:4 ]))
      "A wait B A wait B DOWN A wait DOWN DOWN DOWN DOWN DOWN A A B UP A A A B";
    case "single oddish holding Mail at last slot: dismiss and fail"
      (presses [ "oddish" ]
         ([ look Overworld ]
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "rattata";
               Some "spearow";
               Some "caterpie";
             ]
         @ [
             look Party_panel ~cursor:5 ~species:"oddish";
             look Mon_menu ~cursor:0 ~label:"STORE";
             look Party_panel ~cursor:6 ~species:"oddish" ~remove_mail:true;
             look Party_panel ~cursor:5 ~species:"oddish";
           ]))
      "A DOWN DOWN DOWN DOWN DOWN A A B fail: oddish holds Mail: the game will \
       not store it (\"Please remove the MAIL.\")";
    case "the member is not in the party: fail at the last slot"
      (presses [ "eevee" ]
         ([ look Overworld ]
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "rattata";
               Some "spearow";
               Some "caterpie";
               Some "oddish";
             ]))
      "A DOWN DOWN DOWN DOWN DOWN fail: no eevee in the party panel";
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
    case
      "switch 8-char box name chooser: confirms deposit with A instead of \
       Box_grid failure"
      (presses [ "eevee" ]
         ([ look Overworld ]
         @ scan
             [
               Some "blastoise";
               Some "pidgey";
               Some "rattata";
               Some "spearow";
               Some "caterpie";
             ]
         @ [
             look Party_panel ~cursor:5 ~species:"eevee";
             look Mon_menu ~cursor:0 ~label:"STORE";
             look Box_chooser;
             look Party_panel ~cursor:5;
           ]))
      "A DOWN DOWN DOWN DOWN DOWN A A A B";
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

(* A fake DEPOSIT party panel that tracks each member's original slot id and
   whether it holds Mail, to verify which exact slot is stored when duplicate
   species are present at any party size (2..6). *)
type slot_mon = { slot : int; species : string; mail : bool }

type panel_sim = {
  mutable screen : S.screen;
  mutable cursor : int;
  mutable mail_dialog : bool;
  mutable party : slot_mon list;
  mutable stored : slot_mon list;
  skip_empty : bool;
}

let sim_species sim =
  match List.nth_opt sim.party sim.cursor with
  | Some m -> Some m.species
  | None -> None

let sim_look sim =
  match sim.screen with
  | Party_panel when sim.mail_dialog ->
      look Party_panel ~cursor:6 ?species:(sim_species sim) ~remove_mail:true
  | Party_panel ->
      look Party_panel ~cursor:sim.cursor ?species:(sim_species sim)
  | Mon_menu -> look Mon_menu ~cursor:0 ~label:"STORE"
  | Box_chooser -> look Box_chooser
  | screen -> look screen

let sim_down sim =
  let n = List.length sim.party in
  if sim.cursor >= 6 then 0
  else if sim.skip_empty && sim.cursor + 1 >= n then 6
  else sim.cursor + 1

let sim_up sim =
  let n = List.length sim.party in
  if sim.cursor = 6 then if sim.skip_empty then n - 1 else 5
  else if sim.cursor > 0 then sim.cursor - 1
  else 6

let sim_press sim (p : P.press) =
  match (sim.screen, p) with
  | Party_panel, B when sim.mail_dialog -> sim.mail_dialog <- false
  | Party_panel, Down -> sim.cursor <- sim_down sim
  | Party_panel, Up -> sim.cursor <- sim_up sim
  | Party_panel, A when sim.cursor < List.length sim.party ->
      sim.screen <- Mon_menu
  | Party_panel, B -> sim.screen <- Overworld
  | Mon_menu, A -> (
      match List.nth_opt sim.party sim.cursor with
      | Some m when m.mail ->
          sim.screen <- Party_panel;
          sim.mail_dialog <- true
      | Some _ -> sim.screen <- Box_chooser
      | None -> ())
  | Box_chooser, A ->
      let removed = List.nth sim.party sim.cursor in
      sim.stored <- removed :: sim.stored;
      sim.party <- List.filteri (fun i _ -> i <> sim.cursor) sim.party;
      if sim.cursor >= List.length sim.party then
        sim.cursor <- max 0 (List.length sim.party - 1);
      sim.screen <- Party_panel
  | _ -> ()

let run_panel_sim ~skip_empty party targets () =
  let sim =
    {
      screen = Party_panel;
      cursor = 0;
      mail_dialog = false;
      party =
        List.mapi (fun slot (species, mail) -> { slot; species; mail }) party;
      stored = [];
      skip_empty;
    }
  in
  let rec loop t left =
    if left = 0 then "timeout"
    else
      let t, p = P.next t (sim_look sim) in
      match p with
      | Done ->
          let fmt ms =
            String.concat ", "
              (List.map (fun m -> Printf.sprintf "%d:%s" m.slot m.species) ms)
          in
          Printf.sprintf "stored [%s]; kept [%s]"
            (fmt (List.rev sim.stored))
            (fmt sim.party)
      | Fail why -> "fail: " ^ why
      | p ->
          sim_press sim p;
          loop t (left - 1)
  in
  loop (P.start targets) 60

let duplicate_cases =
  [
    case
      "6-member party, duplicate oddish with no Mail on either -> deposits \
       slot 5 (last), leaves slot 4 untouched"
      (run_panel_sim ~skip_empty:true
         [
           ("blastoise", false);
           ("pidgey", false);
           ("rattata", false);
           ("spearow", false);
           ("oddish", false);
           ("oddish", false);
         ]
         [ "oddish" ])
      "stored [5:oddish]; kept [0:blastoise, 1:pidgey, 2:rattata, 3:spearow, \
       4:oddish]";
    case
      "3-member party, duplicate oddish with no Mail on either (empty slots \
       skipped) -> deposits slot 2 (last), leaves slot 1 untouched"
      (run_panel_sim ~skip_empty:true
         [ ("blastoise", false); ("oddish", false); ("oddish", false) ]
         [ "oddish" ])
      "stored [2:oddish]; kept [0:blastoise, 1:oddish]";
    case
      "3-member party, duplicate oddish with no Mail on either (empty slots \
       visited) -> deposits slot 2 (last), leaves slot 1 untouched"
      (run_panel_sim ~skip_empty:false
         [ ("blastoise", false); ("oddish", false); ("oddish", false) ]
         [ "oddish" ])
      "stored [2:oddish]; kept [0:blastoise, 1:oddish]";
    case
      "6-member party, duplicate oddish: slot 4 holds Mail, slot 5 has no Mail \
       -> deposits slot 5"
      (run_panel_sim ~skip_empty:true
         [
           ("blastoise", false);
           ("pidgey", false);
           ("rattata", false);
           ("spearow", false);
           ("oddish", true);
           ("oddish", false);
         ]
         [ "oddish" ])
      "stored [5:oddish]; kept [0:blastoise, 1:pidgey, 2:rattata, 3:spearow, \
       4:oddish]";
    case
      "6-member party, duplicate oddish: slot 5 holds Mail, slot 4 has no Mail \
       -> skips slot 5 and deposits slot 4"
      (run_panel_sim ~skip_empty:true
         [
           ("blastoise", false);
           ("pidgey", false);
           ("rattata", false);
           ("spearow", false);
           ("oddish", false);
           ("oddish", true);
         ]
         [ "oddish" ])
      "stored [4:oddish]; kept [0:blastoise, 1:pidgey, 2:rattata, 3:spearow, \
       5:oddish]";
    case "3-member party, both oddish hold Mail -> fails with holds_mail"
      (run_panel_sim ~skip_empty:true
         [ ("blastoise", false); ("oddish", true); ("oddish", true) ]
         [ "oddish" ])
      "fail: oddish holds Mail: the game will not store it (\"Please remove \
       the MAIL.\")";
  ]

let () = Table_test.run "pc deposit steps" (cases @ fake_cases @ duplicate_cases)
