open Frlg_readers
module M = Menu_input

let read_shown () = Frlg_text.Summary_level.read (Text_data.glyphs ())

let read_page ~log ~slot () =
  Summary_moves.open_summary slot;
  let level = Summary_paging.settled read_shown in
  log
    (Printf.sprintf "Summary: slot %d is %s." slot
       (Option.fold ~none:"at an unread level" ~some:(Printf.sprintf "Lv %d")
          level));
  M.close_to_overworld ~label:"summary" ~log;
  level

let read ~log ~slot =
  Effects.with_probes Summary_screen.probes (read_page ~log ~slot)
