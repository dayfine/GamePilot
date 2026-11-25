open Frlg_readers
module M = Menu_input

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

let settled read =
  let rec go previous reads =
    let r = read () in
    if r <> None && r = previous then r
    else if reads >= Summary_moves.max_reads then None
    else (
      wait Summary_moves.reread_ms;
      go r (reads + 1))
  in
  go None 1

let info_page = 1
let summary_timeout_ms = 5000

(* The menu goes as the summary starts fading in, which takes a while. *)
let summary_opening m =
  Option.is_some (Summary_screen.page m) || not (Party_actions.member_menu m)

let current_page () =
  Option.bind (Effects.read ()) (fun m -> Summary_screen.page m)

let to_page page =
  let button =
    match current_page () with
    | Some p when p > page -> Wire.Left
    | _ -> Wire.Right
  in
  M.press_until
    ~max_presses:(2 * Summary_moves.moves_page)
    ~code:"no_summary"
    (Printf.sprintf "summary page %d" page)
    button ~cooldown_ms:Summary_moves.page_turn_ms
    (Summary_moves.on_page page)

let member_switch_ms = 500

let next_member () =
  M.press ~cooldown_ms:member_switch_ms Wire.Down;
  ignore
    (M.await_screen ~code:"no_summary" "the next member's info page"
       (Summary_moves.on_page info_page))

let read_party read () =
  Party_actions.open_party ();
  let shown =
    M.await_screen ~code:"no_party" "the party" Party_menu.party_menu
  in
  Party_actions.on_member_menu 1 (fun () ->
      Party_actions.choose_member_row Member_menu.summary_row
        ~taken:summary_opening);
  ignore
    (M.await_screen ~timeout_ms:summary_timeout_ms ~code:"no_summary"
       "the summary"
       (Summary_moves.on_page info_page));
  let rec go slot n acc =
    if slot > n then List.rev acc
    else (
      if slot > 1 then next_member ();
      let r = read slot in
      go (slot + 1) n (r :: acc))
  in
  go 1 (Party_menu.members shown) []

let each_member ~label ~log read =
  Effects.with_probes Summary_screen.probes (fun () ->
      let members = read_party read () in
      M.close_to_overworld ~label ~log;
      members)
