open Frlg_readers
module M = Menu_input
module Text = Frlg_text

let moves_page = 3
let known_rows = 4
let offered_row = 4

let read_row i =
  let moves = Text_data.move_names () in
  match
    Text.Line_reading.read (Text_data.glyphs ())
      (Text.Text_lines.summary_move i)
      (List.map snd moves)
  with
  | Read { text; _ } ->
      Option.map fst (List.find_opt (fun (_, name) -> name = text) moves)
  | No_match _ -> None

let read_offered () = read_row offered_row
let menu_settle_ms = 500
let summary_timeout_ms = 5000
let page_turn_ms = 700
let on_page p m = Summary_screen.page m = Some p
let member_menu m = not (Party_menu.party_menu m)

let open_moves_page slot =
  let m = Party_actions.open_party () in
  Party_actions.choose_slot m slot;
  ignore (M.await_screen ~code:"no_member_menu" "the member's menu" member_menu);
  (* The menu slides in: an A before it settles is lost. *)
  ignore
    (Effects.submit [ Wire.Wait { wait_ms = menu_settle_ms } ]
      : Wire.batch_done);
  M.press Wire.A;
  ignore
    (M.await_screen ~timeout_ms:summary_timeout_ms ~code:"no_summary"
       "the summary" (on_page 1));
  (* Each page slides in; RIGHT again until the moves page reads. *)
  M.press_until ~max_presses:(2 * moves_page) ~code:"no_summary"
    "the moves page" Wire.Right ~cooldown_ms:page_turn_ms (on_page moves_page)

let read_page ~log ~slot () =
  open_moves_page slot;
  let known = List.filter_map read_row (List.init known_rows Fun.id) in
  log
    (Printf.sprintf "Summary: slot %d knows %s." slot (String.concat ", " known));
  M.close "the summary" (fun m -> Summary_screen.page m <> None);
  M.close "the party" Party_menu.party_menu;
  M.settle_back ~label:"summary" ~log;
  known

let read_known ~log ~slot =
  Effects.with_probes Summary_screen.probes (read_page ~log ~slot)
