module T = Switch_home.Timed_press
module R = Plza_readers.Main_menu_row
module C = Plza_gift_catalog.Gift_catalog
module Cur = Box_cursor

let ( let* ) = Result.bind

type slot_read = Cur.cell = Filled | Empty | Not_read of string
type arranged = { reads : (C.box_slot * slot_read) list; moved : int }

let boxes_row = 0
let sixth = 5
let boxes_a : T.t = { button = A; hold_ms = 100; cooldown_ms = 2500 }
let past_card : T.t = { button = A; hold_ms = 100; cooldown_ms = 1500 }
let leave_boxes : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let read_ms = 1500
let boxes_ms = 2000
let card_boxes_ms = 5000
let hold_ms = 1000.

let held_on ~timeout_ms shown =
  Switch_home.Held_screen.wait_for ~timeout_ms
    (Switch_home.Held_screen.held hold_ms (fun m ->
         if shown m then Some () else None))

let boxes_shown = held_on Plza_readers.Boxes_screen.shown

(* A past the first-time card, read first. *)
let past_first_card ~log =
  match held_on ~timeout_ms:boxes_ms Plza_readers.Tutorial_card.shown with
  | None -> Error "no Boxes screen nor first-time card after A"
  | Some () -> (
      T.press past_card;
      match boxes_shown ~timeout_ms:card_boxes_ms with
      | Some () -> Ok (log "Boxes, past the first-time card.")
      | None -> Error "no Boxes screen after A past the first-time card")

let into_boxes ~log =
  T.press boxes_a;
  match boxes_shown ~timeout_ms:boxes_ms with
  | Some () -> Ok (log "Boxes.")
  | None -> past_first_card ~log

let shares m =
  String.concat " " (List.map (Printf.sprintf "%.2f") (R.green_shares m))

let cards_hold ~what check =
  match Effects.await ~timeout_ms:read_ms check with
  | Holds _ -> Ok ()
  | Timeout ->
      let read = Option.fold ~none:"no frame" ~some:shares (Effects.read ()) in
      Error (Printf.sprintf "%s (party HP bars green: %s)" what read)

(* Party slot 6 holds a Pokémon, on the main menu. *)
let sixth_filled () =
  let menu m = R.highlighted m <> None in
  match
    Effects.await ~timeout_ms:read_ms (fun m ->
        menu m && (R.card_green m sixth || R.card_empty m sixth))
  with
  | Holds m -> Ok (R.card_green m sixth)
  | Timeout ->
      let read = Option.fold ~none:"no frame" ~some:shares (Effects.read ()) in
      Error ("party slot 6 not read (party HP bars green: " ^ read ^ ")")

let in_box_one (s : C.box_slot) =
  s.box = 1 && s.slot >= 1 && s.slot <= Cur.box_rows * Cur.columns

let read_slot cur (s : C.box_slot) =
  if not (in_box_one s) then (s, Not_read "only Box 1 is arranged")
  else
    let row, col = Cur.of_slot s.slot in
    (s, Cur.read cur ~row ~col)

let leave ~log ~moved reads =
  T.press leave_boxes;
  let* () =
    cards_hold ~what:"no main menu after the Boxes" (fun m ->
        R.highlighted m <> None)
  in
  log (Printf.sprintf "%d Pokémon moved into the gifts' slots." moved);
  Ok { reads; moved }

let arrange ~log slots =
  let* () = Menu_rows.goto ~log boxes_row in
  let* in_party = sixth_filled () in
  let* () = into_boxes ~log in
  let cur = Cur.opened () in
  Cur.go cur ~row:Gift_moves.title_row ~col:0;
  let* paging = Box_paging.to_box_one ~log in
  let missing =
    List.filter_map
      (fun s -> match read_slot cur s with s, Empty -> Some s | _ -> None)
      slots
  in
  let* moved = Gift_moves.fill ~log cur paging ~in_party missing in
  leave ~log ~moved (List.map (read_slot cur) slots)
