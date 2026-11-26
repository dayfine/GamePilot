module T = Switch_home.Timed_press
module R = Plza_readers.Main_menu_row
module C = Plza_gift_catalog.Gift_catalog

let ( let* ) = Result.bind

type slot_read = Filled | Empty | Not_read of string

let boxes_row = 0
let sixth = 5
let fifth = 4
let columns = 6
let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 250 }
let boxes_a : T.t = { button = A; hold_ms = 100; cooldown_ms = 2500 }
let past_card : T.t = { button = A; hold_ms = 100; cooldown_ms = 1500 }
let pick_up : T.t = { button = Y; hold_ms = 100; cooldown_ms = 400 }
let drop : T.t = { button = Y; hold_ms = 100; cooldown_ms = 600 }
let leave_boxes : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let read_ms = 1500
let hold_ms = 1000.
let boxes_ms = 2000
let card_boxes_ms = 5000
let cell_ms = 2000

let held ~timeout_ms read =
  Switch_home.Held_screen.wait_for ~timeout_ms
    (Switch_home.Held_screen.held hold_ms read)

let boxes_shown ~timeout_ms =
  held ~timeout_ms (fun m ->
      if Plza_readers.Boxes_screen.shown m then Some () else None)

let into_boxes ~log =
  T.press boxes_a;
  match boxes_shown ~timeout_ms:boxes_ms with
  | Some () -> Ok (log "Boxes.")
  | None -> (
      T.press past_card;
      match boxes_shown ~timeout_ms:card_boxes_ms with
      | Some () -> Ok (log "Boxes, past the first-time card.")
      | None -> Error "no Boxes screen after A, A")

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

(* The cell under the cursor, on the Boxes. *)
let cell () =
  match
    held ~timeout_ms:cell_ms (fun m ->
        if Plza_readers.Boxes_screen.shown m then
          Some (Plza_readers.Box_cell.holds_pokemon m)
        else None)
  with
  | Some true -> Filled
  | Some false -> Empty
  | None -> Not_read "no steady Boxes screen"

let row_col (s : C.box_slot) = ((s.slot - 1) / columns, (s.slot - 1) mod columns)

(* Box 1's slot read from slot 1 and the cursor brought back. *)
let read_slot (s : C.box_slot) =
  if s.box <> 1 then Not_read "only Box 1 is read"
  else
    let row, col = row_col s in
    T.press_all (T.times col (dpad Right) @ T.times row (dpad Down));
    let read = cell () in
    T.press_all (T.times row (dpad Up) @ T.times col (dpad Left));
    read

let move (s : C.box_slot) =
  let _, col = row_col s in
  (dpad Up :: T.times sixth (dpad Right))
  @ [ pick_up; dpad Down ]
  @ T.times (sixth - col) (dpad Left)
  @ [ drop ]

let move_party_gift ~log (s : C.box_slot) =
  if s.box <> 1 || fst (row_col s) <> 0 then
    Not_read "a party gift is moved only to Box 1's first row"
  else
    match read_slot s with
    | Empty ->
        T.press_all (move s);
        log (Printf.sprintf "Party slot 6 moved to Box 1 slot %d." s.slot);
        cell ()
    | Filled -> Not_read "its slot already holds a Pokémon; not moved"
    | Not_read e -> Not_read e

let party_ready = function
  | None -> Ok ()
  | Some _ -> cards_hold ~what:"no Pokémon in party slot 6" gift_in_party

(* The main menu after B, and the party gift gone from slot 6 when moved. *)
let menu_back = function
  | [ (_, (Filled | Empty)) ] ->
      cards_hold ~what:"party slot 6 not emptied" gift_moved
  | _ ->
      cards_hold ~what:"no main menu after the Boxes" (fun m ->
          R.highlighted m <> None)

let check ~log ~party_gift ~in_box =
  let* () = Menu_rows.goto ~log boxes_row in
  let* () = party_ready party_gift in
  let* () = into_boxes ~log in
  let boxed = List.map (fun s -> (s, read_slot s)) in_box in
  let moved =
    List.map (fun s -> (s, move_party_gift ~log s)) (Option.to_list party_gift)
  in
  T.press leave_boxes;
  let* () = menu_back moved in
  Ok (boxed @ moved)
