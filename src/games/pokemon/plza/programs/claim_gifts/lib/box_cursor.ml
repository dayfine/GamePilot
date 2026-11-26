module T = Switch_home.Timed_press

type cell = Filled | Empty | Not_read of string
type t = { mutable row : int; mutable col : int }

let party_row = 0
let box_rows = 5
let columns = 6
let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 250 }
let pick_up : T.t = { button = Y; hold_ms = 100; cooldown_ms = 400 }
let drop : T.t = { button = Y; hold_ms = 100; cooldown_ms = 600 }
let hold_ms = 1000.
let cell_ms = 2000
let of_slot slot = (((slot - 1) / columns) + 1, (slot - 1) mod columns)
let opened () = { row = 1; col = 0 }

let steps n ~less ~more =
  if n < 0 then T.times (-n) (dpad less) else T.times n (dpad more)

let go t ~row ~col =
  T.press_all
    (steps (row - t.row) ~less:Up ~more:Down
    @ steps (col - t.col) ~less:Left ~more:Right);
  t.row <- row;
  t.col <- col

let on_boxes m =
  if Plza_readers.Boxes_screen.shown m then
    Some (Plza_readers.Box_cell.holds_pokemon m)
  else None

(* The cell under the cursor, on the Boxes. *)
let under () =
  match
    Switch_home.Held_screen.wait_for ~timeout_ms:cell_ms
      (Switch_home.Held_screen.held hold_ms on_boxes)
  with
  | Some true -> Filled
  | Some false -> Empty
  | None -> Not_read "no steady Boxes screen"

let read t ~row ~col =
  go t ~row ~col;
  under ()

let name (row, col) = Printf.sprintf "row %d column %d" row (col + 1)

let target_text = function
  | Filled -> "holds a Pokémon"
  | Empty | Not_read _ -> "not read"

(* Holding a Pokémon taken from [from]: back on [from], read empty first. *)
let put_back t ~from ~onto target =
  let row, col = from in
  match read t ~row ~col with
  | Empty ->
      T.press drop;
      Ok
        (Not_read
           (Printf.sprintf "%s %s: put back" (name onto) (target_text target)))
  | Filled | Not_read _ ->
      Error
        (Printf.sprintf "%s %s and %s not read empty: a Pokémon still held"
           (name onto) (target_text target) (name from))

(* Holding a Pokémon taken from [from]: dropped on [onto] when it is empty,
   else back on [from]. *)
let put t ~from ~onto =
  let row, col = onto in
  match read t ~row ~col with
  | Empty ->
      T.press drop;
      Ok (under ())
  | (Filled | Not_read _) as target -> put_back t ~from ~onto target

let carry t ~from ~onto =
  let row, col = from in
  match read t ~row ~col with
  | Filled ->
      T.press pick_up;
      put t ~from ~onto
  | Empty -> Ok (Not_read (name from ^ " is empty"))
  | Not_read why -> Ok (Not_read why)
