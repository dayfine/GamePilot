open Frlg_readers
module M = Menu_input
module Text = Frlg_text

let wait_ms = 4000
let min_mail = 2
let mail = "retro-mail"
let hold_ms = 200
let release_ms = 100
let after_slot_ms = 300
let editor_load_ms = 500
let after_confirm_ms = 300

type plan = { item : string; rounds : int; word : string }

let press ?(cooldown_ms = release_ms) button =
  ignore (Effects.submit [ M.hold ~hold_ms ~cooldown_ms button ])

let pause ms = ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ])

let wait code what reader =
  ignore (M.await_screen ~timeout_ms:wait_ms ~code what reader)

let editor_verdict ~word (reading : Text.Line_reading.reading) =
  match reading with
  | Read { text; _ } when text = word -> None
  | Read { text; _ } when text = Text.Mail_fields.blank ->
      Some "the mail editor's field 1 is blank: the glitched record is gone"
  | Read { text; _ } when text = Text.Mail_fields.unknown_word ->
      Some "the mail editor's field 1 reads ???: the mail index is 0xFF"
  | Read { text; _ } -> Some ("the mail editor's field 1 reads " ^ text)
  | No_match _ -> Some ("no mail editor reading " ^ word)

let counted plan ~before ~after =
  if after = before + plan.rounds then None
  else
    Some
      (Printf.sprintf "%s: %d before, %d after %d round(s)" plan.item before
         after plan.rounds)

let check_editor ~frame ~word =
  let reading =
    Text.Mail_fields.await_read (Text_data.glyphs ())
      [ word; Text.Mail_fields.unknown_word; Text.Mail_fields.blank ]
      ~timeout_ms:wait_ms
  in
  Effects.save_run_frame frame;
  Option.iter (M.fail "mail_glitch_not_active") (editor_verdict ~word reading)

let mail_on_top m = Bag_screen.cursor_row m = Some 0

(* The mark only where the party shows: the bag's pixels there are no mark. *)
let slot_one_holds m =
  Party_menu.party_menu m && Party_menu.mark m 1 = Party_menu.Held_item

let yes m = Dialog.yes_no_cursor m = Some true
let editor_yes m = Mail_editor.confirm_arrow m = Some true

let round ~frame ~word =
  wait "no_mail_arrow" "the selection arrow on Retro Mail" mail_on_top;
  press Wire.A;
  press Wire.Down;
  press Wire.A;
  wait "no_held_item" "slot 1's held item" slot_one_holds;
  pause Party_actions.party_input_ms;
  press ~cooldown_ms:after_slot_ms Wire.A;
  wait "no_item_message" "the held item's message" Dialog.advance_arrow;
  press Wire.A;
  Effects.with_probes Dialog.yes_no_probes (fun () ->
      wait "no_switch_question" "the switch question" yes);
  press Wire.A;
  pause editor_load_ms;
  check_editor ~frame ~word;
  press Wire.Start;
  Effects.with_probes Mail_editor.probes (fun () ->
      wait "no_mail_confirmation" "the mail's Yes/No" editor_yes);
  press Wire.A;
  pause after_confirm_ms

(* The item's count in its own pocket, from the Items pocket and back to it:
   an Ultra Ball is counted on the Poke Balls pocket. *)
let count_of item =
  let pocket = Bag_items.pocket_of_item item in
  let away = pocket <> Frlg_readers.Bag_screen.Items in
  if away then Bag_items.pocket_top pocket;
  let n = Bag_items.count_in_pocket item in
  if away then Bag_items.pocket_top Items;
  match n with
  | Some n -> n
  | None -> M.fail "count_not_read" (item ^ "'s count did not read")

(* The bag back after the editor: a fade passes first, black on the frame
   (round 2 read black there), and the list takes no A for a moment after it
   shows (round 2's A was dropped, so DOWN, A chose the next row; mGBA, tt-01
   testing runs 2 and 3), so the party's input wait comes after it. *)
let await_bag () =
  ignore
    (M.await_screen ~timeout_ms:wait_ms ~code:"no_bag" "the bag" (fun m ->
         Bag_screen.pocket m = Some Items));
  pause Party_actions.party_input_ms

let mail_left () =
  await_bag ();
  match Bag_items.count_on_row 0 with
  | Some n when n >= min_mail -> ()
  | n ->
      M.fail "retro_mail_low"
        (Printf.sprintf "Retro Mail on the top row: %s, a round needs %d"
           (Option.fold ~none:"not read" ~some:string_of_int n)
           min_mail)

let rounds ~log plan =
  for i = 1 to plan.rounds do
    mail_left ();
    round ~frame:(Printf.sprintf "proof-a-round%d.png" i) ~word:plan.word;
    log (Printf.sprintf "Duplication: round %d of %d done." i plan.rounds)
  done

let run ~log plan =
  log (Printf.sprintf "Duplication: %s, %d round(s)." plan.item plan.rounds);
  Bag_items.open_pocket_top Items;
  if Bag_items.list_row mail <> Some 0 then
    M.fail "retro_mail_not_on_top" "Retro Mail is not the Items pocket's first";
  let before = count_of plan.item in
  Bag_items.to_top ();
  rounds ~log plan;
  await_bag ();
  Bag_items.to_top ();
  let after = count_of plan.item in
  Effects.save_run_frame "proof-b.png";
  M.close_through_fades "the bag" Bag_screen.bag_open;
  M.settle_back ~label:"duplication" ~log;
  log (Printf.sprintf "Duplication: %s %d -> %d." plan.item before after);
  Option.iter (M.fail "duplication_failed") (counted plan ~before ~after)
