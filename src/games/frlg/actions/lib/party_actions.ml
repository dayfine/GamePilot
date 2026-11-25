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
  M.close_through_fades "the party" Party_menu.party_menu;
  M.settle_back ~label:"party swap" ~log

let bag_or_party m = Bag_screen.bag_open m || Party_menu.party_menu m
let is_mail item = String.ends_with ~suffix:"-mail" item
let editor_yes m = Mail_editor.confirm_arrow m = Some true
let mail_confirm_ms = 4000

(* The C++ ItemDuplication's exit from the editor after its PLUS: the
   editor's own Yes/No arrow on YES, then A. *)
let confirm_mail () =
  Effects.with_probes Mail_editor.probes (fun () ->
      ignore
        (M.await_screen ~timeout_ms:mail_confirm_ms ~code:"mail_no_confirm"
           "the mail's Okay?" editor_yes));
  M.press Wire.A

let write_one_word () =
  Effects.submit [ Wire.Wait { wait_ms = mail_editor_wait_ms } ] |> ignore;
  List.iter
    (fun _ -> M.press Wire.A ~cooldown_ms:easy_chat_press_ms)
    [ 1; 2; 3 ];
  M.press Wire.Start;
  confirm_mail ()

let switch_question_ms = 1500
let message_or_question m = Dialog.advance_arrow m || Dialog.selection_dialog m

(* "<member> is already holding <item>. Would you like to switch the two
   items?" has a page before its question, which the C++ ItemDuplication
   presses A through (its [item_description] wait); a "was given ... to hold"
   message has no question after its page. *)
let answer_switch () =
  match Effects.await ~timeout_ms:switch_question_ms message_or_question with
  | Timeout -> false
  | Holds m when Dialog.selection_dialog m ->
      M.answer_yes_if_asked ~timeout_ms:switch_question_ms
  | Holds _ ->
      M.press Wire.A;
      M.answer_yes_if_asked ~timeout_ms:switch_question_ms

(* After a berry is given the pouch shows again, over the bag. *)
let bag_pouch_or_party m = bag_or_party m || Berry_pouch.shows_pouch m

(* GIVE's row in the item's menu: USE, GIVE, TOSS on the Items pocket, but
   GIVE, TOSS on the Poke Balls pocket, which has no USE (pokefirered
   src/item_menu.c). *)
let give_row item =
  match Bag_items.pocket_of_item item with
  | Frlg_readers.Bag_screen.Poke_balls -> 0
  | Items | Key_items -> 1

(* The fork's wait after the party shows, before its presses: an A that comes
   sooner is dropped (mGBA, mg-06 testing run 2: slot 1, already selected,
   needs no tap before the A). *)
let party_input_ms = 400

let give_to slot =
  ignore
    (M.await_screen ~code:"no_party" "the party to give to"
       Party_menu.party_menu);
  ignore (Effects.submit [ Wire.Wait { wait_ms = party_input_ms } ]);
  choose_slot slot

let give ~log ~item ~slot =
  log (Printf.sprintf "Bag: give %s to slot %d." item slot);
  if Berry_pouch.is_berry item then Berry_pouch.choose_give item
  else Bag_items.item_action item (give_row item);
  give_to slot;
  if answer_switch () then log "Bag: the member held an item; switched it.";
  if is_mail item then write_one_word ();
  Effects.with_probes Berry_pouch.probes (fun () ->
      M.close_through_fades "the bag" bag_pouch_or_party);
  M.settle_back ~label:("give " ^ item) ~log

let warps item = item = "escape-rope"

(* The overworld before the bag opens: the scene the warp leaves. *)
let departure () =
  match
    Effects.await ~timeout_ms:M.screen_timeout_ms (fun m ->
        Option.is_some (Scene_signature.read m))
  with
  | Holds m -> Scene_signature.read m
  | Timeout -> None

(* The settle from the item's USE on, its frames watched from that press: the
   warp may be over before a look (mg-04a testing run 1 on console B). Another
   scene than the departure's on the overworld proves it as a fade does. *)
let settle_warp ~log ~item before =
  let use_a = Bag_items.item_action_press item 0 in
  let arrived =
    Option.map (fun before -> Scene_signature.left ~before) before
  in
  match
    Scene_looks.settle After_warp ?arrived ~start:[ use_a ]
      ~label:("use " ^ item) ~battle_ends:false ~log
  with
  | Ok () -> ()
  | Error cause -> raise (M.Action_failed cause)

let use_warp ~log ~item =
  Effects.with_probes Scene_signature.probes (fun () ->
      settle_warp ~log ~item (departure ()))

let use_on ~log ~item ~slot =
  Bag_items.item_action item 0;
  match slot with
  | Some slot ->
      ignore
        (M.await_screen ~code:"no_party" "the party to use it on"
           Party_menu.party_menu);
      choose_slot slot;
      M.close_through_fades "the bag" bag_or_party;
      M.settle_back ~label:("use " ^ item) ~log
  | None ->
      M.close_through_fades "the bag" bag_or_party;
      M.settle_back ~label:("use " ^ item) ~log

let use ~log ~item ~slot =
  log ("Bag: use " ^ item ^ ".");
  if warps item && Option.is_none slot then use_warp ~log ~item
  else use_on ~log ~item ~slot

let party_settle_ms = 800

let verified_line who slot =
  Printf.sprintf
    "MailGlitch: verified! %s (slot %d) holds the recycled Berry (Mail Glitch \
     active)."
    who slot

let not_active who slot mark =
  Printf.sprintf "%s (slot %d) shows %s, not a held item icon, after Recycle"
    who slot
    (Party_menu.mark_name mark)

let verified ~log ~who ~slot (mark : Party_menu.mark) =
  match mark with
  | Held_item -> log (verified_line who slot)
  | other -> M.fail "mail_glitch_not_active" (not_active who slot other)

let verify_mail_glitch ~log ~who ~slot =
  open_party ();
  Effects.submit [ Wire.Wait { wait_ms = party_settle_ms } ] |> ignore;
  let m = M.await_screen ~code:"no_party" "the party" Party_menu.party_menu in
  let mark = Party_menu.mark m slot in
  M.close_through_fades "the party" Party_menu.party_menu;
  M.settle_back ~label:"verify mail glitch" ~log;
  verified ~log ~who ~slot mark
