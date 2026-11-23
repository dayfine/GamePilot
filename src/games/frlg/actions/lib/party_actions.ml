open Frlg_readers
module M = Menu_input
module C = Menu_cursor

let pokemon_row = 1
let mail_editor_wait_ms = 2500

(* An Easy Chat press, as the fork waits after each. *)
let easy_chat_press_ms = 800

let open_party () =
  C.open_start_menu_row pokemon_row;
  ignore (M.await_screen ~code:"no_party" "the party" Party_menu.party_menu)

let choose_slot slot =
  C.move_to ~code:"no_party" C.party slot;
  M.press Wire.A

let member_menu m = Option.is_some (Member_menu.cursor_row m)

let on_member_menu slot body =
  Effects.with_probes Member_menu.probes (fun () ->
      C.choose ~code:"no_member_menu" C.party slot ~taken:member_menu;
      body ())

let choose_member_row row ~taken =
  C.choose ~code:"no_member_menu" C.member_menu row ~taken

(* SWITCH taken: the member's menu gone, the party back to pick the other. *)
let switching m = not (member_menu m)

let swap ~log a b =
  log (Printf.sprintf "Party: swap slot %d with slot %d." a b);
  open_party ();
  on_member_menu a (fun () ->
      let rows =
        M.await_screen ~code:"no_member_menu" "the member's menu" member_menu
        |> Member_menu.rows |> Option.get
      in
      choose_member_row (Member_menu.switch_row ~rows) ~taken:switching;
      choose_slot b);
  ignore
    (M.await_screen ~code:"no_party" "the party after the switch"
       Party_menu.party_menu);
  M.close "the party" Party_menu.party_menu;
  M.settle_back ~label:"party swap" ~log

(* The item's own menu (USE or CHECK, GIVE, TOSS, CANCEL) hides the arrows. *)
let item_menu m = Bag_screen.bag_open m && Bag_screen.pocket m = None

let item_menu_row row item =
  Bag_items.open_pocket_top (Bag_items.pocket_of_item item);
  Bag_items.select item;
  M.press Wire.A;
  ignore (M.await_screen ~code:"no_item_menu" ("the menu of " ^ item) item_menu);
  M.taps Wire.Down row;
  M.press Wire.A

let bag_or_party m = Bag_screen.bag_open m || Party_menu.party_menu m
let is_mail item = String.ends_with ~suffix:"-mail" item

let write_one_word () =
  Effects.submit [ Wire.Wait { wait_ms = mail_editor_wait_ms } ] |> ignore;
  List.iter
    (fun _ -> M.press Wire.A ~cooldown_ms:easy_chat_press_ms)
    [ 1; 2; 3 ];
  M.press Wire.Start;
  M.answer_yes ~code:"mail_no_confirm" "the mail's Okay?"

let switch_question_ms = 1500

let give ~log ~item ~slot =
  if String.ends_with ~suffix:"-berry" item then
    M.fail ~repeats:true "not_implemented" "giving a berry (the Berry Pouch)";
  log (Printf.sprintf "Bag: give %s to slot %d." item slot);
  item_menu_row 1 item;
  ignore
    (M.await_screen ~code:"no_party" "the party to give to"
       Party_menu.party_menu);
  choose_slot slot;
  if M.answer_yes_if_asked ~timeout_ms:switch_question_ms then
    log "Bag: the member held an item; switched it.";
  if is_mail item then write_one_word ();
  M.close "the bag" bag_or_party;
  M.settle_back ~label:("give " ^ item) ~log

let warps item = item = "escape-rope"

let use ~log ~item ~slot =
  log ("Bag: use " ^ item ^ ".");
  item_menu_row 0 item;
  match slot with
  | Some slot ->
      ignore
        (M.await_screen ~code:"no_party" "the party to use it on"
           Party_menu.party_menu);
      choose_slot slot;
      M.close "the bag" bag_or_party;
      M.settle_back ~label:("use " ^ item) ~log
  | None when not (warps item) ->
      M.close "the bag" bag_or_party;
      M.settle_back ~label:("use " ^ item) ~log
  | None -> (
      match
        Scene_looks.settle After_warp ~label:("use " ^ item) ~battle_ends:false
          ~log
      with
      | Ok () -> ()
      | Error cause -> raise (M.Action_failed cause))
