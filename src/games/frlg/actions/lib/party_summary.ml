open Frlg_readers
module M = Menu_input

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

(* A page's mark shows before its text is drawn: a read counts once two reads
   a moment apart agree on one. *)
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

let read_pages ~log slot () =
  Summary_moves.open_summary slot;
  let species = settled Party_species.read_shown in
  let level = settled Member_level.read_shown in
  M.press_until
    ~max_presses:(2 * Summary_moves.moves_page)
    ~code:"no_summary" "the moves page" Wire.Right
    ~cooldown_ms:Summary_moves.page_turn_ms
    (Summary_moves.on_page Summary_moves.moves_page);
  let moves = Summary_moves.settled_rows () in
  M.close "the summary" (fun m -> Summary_screen.page m <> None);
  M.close "the party" Party_menu.party_menu;
  M.settle_back ~label:"summary" ~log;
  let member : Story.Room_policy.member =
    {
      slot;
      species = Option.value species ~default:"?";
      level;
      moves = (if moves = [] then None else Some moves);
    }
  in
  log
    (Printf.sprintf "Party: slot %d is %s." slot
       (Story.Room_policy.member_to_string member));
  member

let read_member ~log slot =
  Effects.with_probes Summary_screen.probes (read_pages ~log slot)

let count () =
  Party_actions.open_party ();
  let shown =
    M.await_screen ~code:"no_party" "the party" Party_menu.party_menu
  in
  M.close "the party" Party_menu.party_menu;
  Party_menu.members shown

let read_all ~log () =
  let n = count () in
  List.init n (fun i -> read_member ~log (i + 1))
