module T = Switch_home.Timed_press
module R = Plza_readers.Main_menu_row

let ( let* ) = Result.bind
let boxes_row = 0
let sixth = 5
let fifth = 4
let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 250 }

(* A (2.5 s) into the Boxes; A (1.5 s) past the first-time card, when it
   shows. *)
let open_boxes : T.t = { button = A; hold_ms = 100; cooldown_ms = 2500 }
let past_card : T.t = { button = A; hold_ms = 100; cooldown_ms = 1500 }
let party_rights = 5
let box_lefts = 4

let move =
  (dpad Up :: T.times party_rights (dpad Right))
  @ [ T.{ button = Y; hold_ms = 100; cooldown_ms = 400 }; dpad Down ]
  @ T.times box_lefts (dpad Left)
  @ [ T.{ button = Y; hold_ms = 100; cooldown_ms = 600 } ]

let leave_boxes : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let open_save : T.t = { button = R; hold_ms = 100; cooldown_ms = 1500 }

let confirm_save : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 3500 };
    { button = A; hold_ms = 100; cooldown_ms = 1500 };
  ]

(* B out of the dialog, then the script's B out of the menu. *)
let cancel : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let close_menu : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let read_ms = 1500

let shares m =
  String.concat " " (List.map (Printf.sprintf "%.2f") (R.green_shares m))

let cards_hold ~what check =
  match Effects.await ~timeout_ms:read_ms check with
  | Holds _ -> Ok ()
  | Timeout ->
      let read = Option.fold ~none:"no frame" ~some:shares (Effects.read ()) in
      Error (Printf.sprintf "%s (party HP bars green: %s)" what read)

let gift_in_party m = R.highlighted m <> None && R.card_green m sixth

let gift_moved m =
  R.highlighted m <> None && R.card_empty m sixth && R.card_green m fifth

(* [check] held 1 s within [timeout_ms], no press; the last frame. *)
let hold_ms = 1000.

let held ~timeout_ms check =
  let last = ref None in
  let watch m =
    last := Some m;
    if check m then Some () else None
  in
  match
    Switch_home.Held_screen.wait_for ~timeout_ms
      (Switch_home.Held_screen.held hold_ms watch)
  with
  | Some () -> !last
  | None -> None

let boxes_ms = 2000
let card_boxes_ms = 5000
let dialog_ms = 3000
let menu_ms = 5000
let boxes_shown ~timeout_ms = held ~timeout_ms Plza_readers.Boxes_screen.shown

let await_boxes () =
  Option.fold ~none:(Error "no Boxes screen")
    ~some:(fun _ -> Ok ())
    (boxes_shown ~timeout_ms:boxes_ms)

let into_boxes ~log =
  T.press open_boxes;
  match boxes_shown ~timeout_ms:boxes_ms with
  | Some _ -> Ok (log "Boxes.")
  | None -> (
      T.press past_card;
      match boxes_shown ~timeout_ms:card_boxes_ms with
      | Some _ -> Ok (log "Boxes, past the first-time card.")
      | None -> Error "no Boxes screen after A, A; nothing moved")

let to_boxes ~log =
  let* () = Menu_rows.goto ~log boxes_row in
  let* () =
    cards_hold ~what:"no Pokémon in party slot 6; nothing moved" gift_in_party
  in
  into_boxes ~log

let move_gift ~log =
  T.press_all move;
  T.press leave_boxes;
  let* () =
    cards_hold ~what:"party slot 6 not emptied; nothing saved" gift_moved
  in
  log "Party slot 6 moved to Box 1 slot 2.";
  Ok ()

module D = Plza_readers.Save_dialog

let last_saved ~what =
  Option.to_result ~none:what
    (Option.bind (held ~timeout_ms:dialog_ms D.shown) D.last_saved)

let await_dialog () = Result.map ignore (last_saved ~what:"no SAVE dialog")

let open_save_prompt ~log =
  T.press open_save;
  let* () = await_dialog () in
  log "Save Progress.";
  Ok ()

let menu_back () =
  Option.fold ~none:(Error "no main menu after saving")
    ~some:(fun _ -> Ok ())
    (held ~timeout_ms:menu_ms (fun m -> R.highlighted m <> None))

let saved ~log before after =
  T.press_all [ cancel; close_menu ];
  if D.same_time before after then
    Error
      "Last Saved did not change: not saved, or saved within the minute of the \
       last save; the game left open"
  else Ok (log "Saved: Last Saved changed.")

let save ~log =
  let* before = last_saved ~what:"no SAVE dialog; nothing saved" in
  T.press_all confirm_save;
  let* () = menu_back () in
  T.press open_save;
  let* after = last_saved ~what:"no SAVE dialog after saving" in
  saved ~log before after
