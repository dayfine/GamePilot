module T = Switch_home.Timed_press
module R = Plza_readers.Main_menu_row

let ( let* ) = Result.bind
let boxes_row = 0
let sixth = 5
let fifth = 4
let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 250 }

(* A (2.5 s) into the Boxes; A (1.5 s) past the first-time card, when it
   shows. *)
let boxes_a : T.t = { button = A; hold_ms = 100; cooldown_ms = 2500 }
let past_card : T.t = { button = A; hold_ms = 100; cooldown_ms = 1500 }

(* The party's row over Box 1's first row: slot 6 over column 5. *)
let party_rights = 5
let pick_up : T.t = { button = Y; hold_ms = 100; cooldown_ms = 400 }
let drop : T.t = { button = Y; hold_ms = 100; cooldown_ms = 600 }

type gift = Code_gift | Internet_gift

let slot = function Code_gift -> 0 | Internet_gift -> 1

let gift_name = function
  | Code_gift -> "the code's gift"
  | Internet_gift -> "the Internet gift"

let move gift =
  (dpad Up :: T.times party_rights (dpad Right))
  @ [ pick_up; dpad Down ]
  @ T.times (party_rights - slot gift) (dpad Left)
  @ [ drop ]

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
  T.press boxes_a;
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

let open_boxes ~log =
  let* () = Menu_rows.goto ~log boxes_row in
  into_boxes ~log

(* The cursor's cell, on the Boxes, held 1 s within 2 s. *)
let cell_ms = 2000

let cell_reads ~full k =
  let check m =
    Plza_readers.Boxes_screen.shown m
    && Plza_readers.Box_cell.holds_pokemon m = full
  in
  match held ~timeout_ms:cell_ms check with
  | Some _ -> Ok ()
  | None ->
      Error
        (Printf.sprintf "Box 1 slot %d is %s; nothing moved, nothing saved"
           (k + 1)
           (if full then "empty" else "not empty"))

(* Slot 1 is under the cursor when the Boxes open; slot 2 is read one Right
   from it, and the cursor brought back. *)
let slot_reads ~full k =
  if k = 0 then cell_reads ~full k
  else (
    T.press (dpad Right);
    let* () = cell_reads ~full k in
    T.press (dpad Left);
    Ok ())

let menu_read = "no main menu after the Boxes; nothing saved"

let move_gift ~log gift =
  let* () = slot_reads ~full:false (slot gift) in
  T.press_all (move gift);
  T.press leave_boxes;
  let* () =
    cards_hold ~what:"party slot 6 not emptied; nothing saved" gift_moved
  in
  log
    (Printf.sprintf "Party slot 6 (%s) moved to Box 1 slot %d." (gift_name gift)
       (slot gift + 1));
  Ok ()

let slot_2_to_1 = [ dpad Right; pick_up; dpad Left; drop ]

let move_slot_2_to_1 ~log =
  let* () = slot_reads ~full:false 0 in
  let* () = slot_reads ~full:true 1 in
  T.press_all slot_2_to_1;
  let* () =
    Result.map_error
      (fun _ -> "no Pokémon dropped in Box 1 slot 1; nothing saved")
      (cell_reads ~full:true 0)
  in
  T.press leave_boxes;
  let* () = cards_hold ~what:menu_read (fun m -> R.highlighted m <> None) in
  log "Box 1 slot 2 moved to slot 1.";
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
