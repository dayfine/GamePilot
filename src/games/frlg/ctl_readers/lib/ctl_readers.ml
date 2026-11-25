(* The FRLG readers [gamepilot ctl read NAME] runs once on the current frame:
   the screen readers (games/frlg/readers) and the text readers the actions
   use (Start_menu_names, Party_species, Summary_moves), each subscribed for
   one frame and printed as [field: value] lines. Nothing here presses a
   button. *)

module R = Frlg_readers
module A = Frlg_actions

type reader = Ctl_script.reader = {
  name : string;
  doc : string;
  read : unit -> (string * string) list;
}

let latest () =
  match Effects.read () with
  | Some m -> m
  | None -> failwith "no frame from the daemon"

(* The reader's probes for one frame, then [f] on it. *)
let on_frame probes f = Effects.with_probes probes (fun () -> f (latest ()))
let yes_no = function true -> "yes" | false -> "no"
let opt f = function Some v -> f v | None -> "none"
let names rows = String.concat " | " (List.map (Option.value ~default:"-") rows)

let start_menu () =
  let shown, row =
    on_frame R.Start_menu.probes (fun m ->
        (R.Start_menu.start_menu_open m, R.Start_menu.cursor_row m))
  in
  [ ("open", yes_no shown); ("cursor_row", opt string_of_int row) ]
  @ if shown then [ ("rows", names (A.Start_menu_names.read_rows ())) ] else []

let yes_no_cursor = opt (function true -> "YES" | false -> "NO")

(* A reader made of fields, each a function of one frame. *)
let fields probes table () =
  on_frame probes (fun m -> List.map (fun (field, f) -> (field, f m)) table)

let flag f m = yes_no (f m)

let dialog =
  fields
    (R.Dialog.probes @ R.Dialog.yes_no_probes)
    [
      ("text_box", flag R.Dialog.dialog_up);
      ("advance_arrow", flag R.Dialog.advance_arrow);
      ("yes_no_box", flag R.Dialog.selection_dialog);
      ("yes_no_cursor", fun m -> yes_no_cursor (R.Dialog.yes_no_cursor m));
    ]

let layout_name = function
  | R.Party_menu.Single -> "single"
  | R.Party_menu.Double -> "double"

let marks m =
  let mark i = R.Party_menu.mark_name (R.Party_menu.mark m (i + 1)) in
  String.concat " " (List.init (R.Party_menu.members m) mark)

let party_menu =
  fields R.Party_menu.probes
    [
      ("open", flag R.Party_menu.party_menu);
      ("layout", fun m -> opt layout_name (R.Party_menu.layout m));
      ("members", fun m -> string_of_int (R.Party_menu.members m));
      ( "selected_slot",
        fun m -> opt string_of_int (R.Party_menu.selected_slot m) );
      ("marks", marks);
    ]

let info_page = 1

let summary () =
  let page = on_frame R.Summary_screen.probes R.Summary_screen.page in
  let text =
    match page with
    | Some p when p = info_page ->
        [ ("species", opt Fun.id (A.Party_species.read_shown ())) ]
    | Some p when p = A.Summary_moves.moves_page ->
        [ ("moves", names (List.init 4 A.Summary_moves.read_row)) ]
    | _ -> []
  in
  ("page", opt string_of_int page) :: text

let battle =
  fields R.Battle_screen.probes
    [
      ("battle", flag R.Battle_screen.battle_shows);
      ("battle_menu", flag R.Battle_screen.battle_menu);
      ("move_menu", flag R.Battle_screen.move_menu);
      ("text_box", flag R.Battle_screen.battle_text_box);
      ("player_box", flag R.Battle_screen.player_box);
      ("foe_box", flag R.Battle_screen.foe_box);
      ("level_up_box", flag R.Battle_screen.level_up_box);
    ]

let yes_no_reader =
  fields
    (R.Battle_yes_no.probes @ R.Dialog.yes_no_probes)
    [
      ("battle_yes_no_box", flag R.Battle_yes_no.yes_no_box);
      ("move_learn", flag R.Battle_yes_no.move_learn);
      ("cursor", fun m -> yes_no_cursor (R.Dialog.yes_no_arrow m));
    ]

let load_menu =
  fields R.Load_menu.probes [ ("open", flag R.Load_menu.load_menu_open) ]

let bag =
  fields R.Bag_screen.probes
    [
      ("open", flag R.Bag_screen.bag_open);
      ("item_menu", flag R.Bag_screen.item_menu);
      ("pocket", fun m -> opt R.Bag_screen.pocket_name (R.Bag_screen.pocket m));
      ("cursor_row", fun m -> opt string_of_int (R.Bag_screen.cursor_row m));
    ]

let trainer_card =
  let module C = R.Trainer_card_front in
  fields C.probes
    [
      ("front", flag C.front_shown);
      ("read", fun m -> opt C.to_string (C.read m));
    ]

let all =
  [
    {
      name = "start_menu";
      doc = "open, cursor row, the rows' names";
      read = start_menu;
    };
    {
      name = "dialog";
      doc = "white text box, its arrow, Yes/No box and cursor";
      read = dialog;
    };
    {
      name = "party_menu";
      doc = "open, layout, members, selected slot, marks";
      read = party_menu;
    };
    {
      name = "summary";
      doc = "page; species on the info page, moves on the moves page";
      read = summary;
    };
    { name = "battle"; doc = "battle screen boxes and menus"; read = battle };
    {
      name = "yes_no";
      doc = "battle Yes/No box, move learn, cursor";
      read = yes_no_reader;
    };
    { name = "load_menu"; doc = "the title's load menu"; read = load_menu };
    { name = "bag"; doc = "open, item menu, pocket, cursor row"; read = bag };
    {
      name = "trainer_card";
      doc = "the card's front shown, its badges and stars";
      read = trainer_card;
    };
  ]
