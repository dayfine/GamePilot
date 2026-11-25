module T = Switch_home.Timed_press
module R = Plza_readers.Main_menu_row

let ( let* ) = Result.bind
let boxes_row = 0
let sixth = 5
let fifth = 4
let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 250 }

let open_boxes : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 2500 };
    { button = A; hold_ms = 100; cooldown_ms = 1500 };
  ]

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
    { button = B; hold_ms = 100; cooldown_ms = 1500 };
  ]

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

let to_boxes ~log =
  let* () = Menu_rows.goto ~log boxes_row in
  let* () =
    cards_hold ~what:"no Pokémon in party slot 6; nothing moved" gift_in_party
  in
  T.press_all open_boxes;
  log "Boxes.";
  Ok ()

let move_gift ~log =
  T.press_all move;
  T.press leave_boxes;
  let* () =
    cards_hold ~what:"party slot 6 not emptied; nothing saved" gift_moved
  in
  log "Party slot 6 moved to Box 1 slot 2.";
  Ok ()

let open_save_prompt ~log =
  T.press open_save;
  log "Save Progress.";
  Ok ()

let save ~log =
  T.press_all confirm_save;
  log "Saved.";
  Ok ()
