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
let summary_timeout_ms = 5000
let page_turn_ms = 700
let on_page p m = Summary_screen.page m = Some p

(* The menu goes as the summary starts fading in, which takes a while. *)
let summary_opening m =
  Option.is_some (Summary_screen.page m) || not (Party_actions.member_menu m)

let open_summary slot =
  Party_actions.open_party ();
  Party_actions.on_member_menu slot (fun () ->
      Party_actions.choose_member_row Member_menu.summary_row
        ~taken:summary_opening);
  ignore
    (M.await_screen ~timeout_ms:summary_timeout_ms ~code:"no_summary"
       "the summary" (on_page 1))

let open_moves_page slot =
  open_summary slot;
  (* Each page slides in; RIGHT again until the moves page reads. *)
  M.press_until ~max_presses:(2 * moves_page) ~code:"no_summary"
    "the moves page" Wire.Right ~cooldown_ms:page_turn_ms (on_page moves_page)

let reread_ms = 150
let max_reads = 12

(* The page's mark turns before its rows are drawn (blank boxes, then the
   names): the rows count once the first shows a move (every member knows
   one) and a second read a moment later agrees. *)
let rec settled_rows previous reads =
  let rows = List.init known_rows read_row in
  if List.hd rows <> None && Some rows = previous then rows
  else if reads >= max_reads then
    M.fail "no_summary" "the moves page's rows did not settle"
  else (
    ignore
      (Effects.submit [ Wire.Wait { wait_ms = reread_ms } ] : Wire.batch_done);
    settled_rows (Some rows) (reads + 1))

let settled_rows () = List.filter_map Fun.id (settled_rows None 1)

let read_page ~log ~slot () =
  open_moves_page slot;
  let known = settled_rows () in
  log
    (Printf.sprintf "Summary: slot %d knows %s." slot (String.concat ", " known));
  M.close "the summary" (fun m -> Summary_screen.page m <> None);
  M.close "the party" Party_menu.party_menu;
  M.settle_back ~label:"summary" ~log;
  known

let read_known ~log ~slot =
  Effects.with_probes Summary_screen.probes (read_page ~log ~slot)
