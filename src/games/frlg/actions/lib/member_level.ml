open Frlg_readers
module M = Menu_input

let read_shown () = Frlg_text.Summary_level.read (Text_data.glyphs ())

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

(* The page's mark shows before its text is drawn: a level counts once two
   reads a moment apart agree on one. *)
let rec settled previous reads =
  let read = read_shown () in
  if read <> None && read = previous then read
  else if reads >= Summary_moves.max_reads then None
  else (
    wait Summary_moves.reread_ms;
    settled read (reads + 1))

let read_page ~log ~slot () =
  Summary_moves.open_summary slot;
  let level = settled None 1 in
  log
    (Printf.sprintf "Summary: slot %d is %s." slot
       (Option.fold ~none:"at an unread level" ~some:(Printf.sprintf "Lv %d")
          level));
  M.close_to_overworld ~label:"summary" ~log;
  level

let read ~log ~slot =
  Effects.with_probes Summary_screen.probes (read_page ~log ~slot)
