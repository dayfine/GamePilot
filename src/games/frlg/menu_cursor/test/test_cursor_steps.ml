(* Cursor_steps on a scripted screen whose party cursor moves a slot per tap
   once the list has shown [input_delay_ms] (Scripted_screen): the steps the
   cursor took and the presses. *)

open Frlg_overworld_fixtures
module S = Scripted_screen
module C = Frlg_menu_cursor.Cursor_steps

let outcome = function
  | C.Reached -> "reached"
  | Unread -> "unread"
  | Stuck at -> Printf.sprintf "stuck on %d" at

let tap b =
  ignore
    (Effects.submit
       [ Wire.Press { buttons = [ b ]; hold_ms = 80; cooldown_ms = 240 } ]
      : Wire.batch_done)

let unread_at_ms = 330

(* After each tap, a frame the reader cannot read (a capture glitch, a fade)
   and then the screen as it was, before the tap's move shows. *)
let unread_frame_after_tap screen (p : S.press) =
  let before = S.screen_at screen p.at_ms in
  S.show screen ~at_ms:(p.at_ms + unread_at_ms) S.Black;
  S.show screen ~at_ms:(p.at_ms + unread_at_ms + 2) before

let party_to ?(input_delay_ms = 0) ?capture_latencies_ms ?react ~from slot () =
  let screen = S.create ~input_delay_ms ?capture_latencies_ms ?react () in
  S.show screen ~at_ms:0 (S.Party from);
  let result =
    S.run screen (fun () ->
        C.step_to ~tap Frlg_readers.Party_menu.selected_slot slot)
  in
  Printf.sprintf "%s; %s" (outcome result) (S.presses_text screen)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "cursor_steps"
    [
      case "already there: nothing pressed" (party_to ~from:2 2) "reached; ";
      case "down from the remembered slot" (party_to ~from:2 5)
        "reached; down x3";
      case "up from the remembered slot" (party_to ~from:6 1) "reached; up x5";
      case "a tap the list drops while it slides in is tapped again"
        (party_to ~input_delay_ms:300 ~from:5 6)
        "reached; down x2";
      case
        "console B's capture shows a move 160 or 335 ms after its tap: one tap \
         per row (2026-11-23)"
        (party_to ~capture_latencies_ms:[ 160; 335 ] ~from:2 5)
        "reached; down x3";
      case
        "an unread frame between a tap and its move is not a move: one tap per \
         row"
        (party_to ~capture_latencies_ms:[ 400 ] ~react:unread_frame_after_tap
           ~from:2 5)
        "reached; down x3";
      case "no party: unread, nothing pressed"
        (fun () ->
          let screen = S.create () in
          outcome
            (S.run screen (fun () ->
                 C.step_to ~timeout_ms:100 ~tap
                   Frlg_readers.Party_menu.selected_slot 1)))
        "unread";
    ]
