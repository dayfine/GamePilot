module T = Switch_home.Timed_press
module D = Plza_readers.Save_dialog
module R = Plza_readers.Main_menu_row

let ( let* ) = Result.bind
let open_save : T.t = { button = R; hold_ms = 100; cooldown_ms = 1500 }

let confirm_save : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 3500 };
    { button = A; hold_ms = 100; cooldown_ms = 1500 };
  ]

(* B out of the dialog, then B out of the menu. *)
let close : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let hold_ms = 1000.
let dialog_ms = 3000
let menu_ms = 5000

let held ~timeout_ms read =
  Switch_home.Held_screen.wait_for ~timeout_ms
    (Switch_home.Held_screen.held hold_ms read)

(* The dialog held 1 s with its "Last Saved" read, and the last frame's
   reading: the hold is on the reading being there, not on its shares, which
   differ a little on every frame. *)
let last_saved ~what =
  T.press open_save;
  let reading = ref None in
  let read m =
    reading := if D.shown m then D.last_saved m else None;
    Option.map ignore !reading
  in
  let held_read = held ~timeout_ms:dialog_ms read in
  match (held_read, !reading) with
  | Some (), Some shares -> Ok shares
  | _ -> Error what

let menu_back () =
  Option.to_result ~none:"no main menu after saving"
    (held ~timeout_ms:menu_ms (fun m ->
         if R.highlighted m <> None then Some () else None))

let save ~log =
  let* before = last_saved ~what:"no SAVE dialog; nothing saved" in
  T.press_all confirm_save;
  let* () = menu_back () in
  let* after = last_saved ~what:"no SAVE dialog after saving" in
  T.press_all [ close; close ];
  if D.same_time before after then
    Error "Last Saved did not change: not saved, or saved within its minute"
  else Ok (log "Saved: Last Saved changed.")
