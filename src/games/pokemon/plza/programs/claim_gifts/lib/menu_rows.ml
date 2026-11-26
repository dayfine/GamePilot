module T = Switch_home.Timed_press
module R = Plza_readers.Main_menu_row

let open_x : T.t = { button = X; hold_ms = 100; cooldown_ms = 1500 }
let down : T.t = { button = Down; hold_ms = 80; cooldown_ms = 300 }
let up : T.t = { button = Up; hold_ms = 80; cooldown_ms = 300 }
let read_ms = 1500

let read_row () =
  match
    Effects.await ~timeout_ms:read_ms (fun m -> R.highlighted m <> None)
  with
  | Holds m -> R.highlighted m
  | Timeout -> None

let not_open = "the main menu does not show"

let open_menu ~log =
  let shown_before = read_row () in
  if shown_before = None then T.press open_x;
  match if shown_before = None then read_row () else shown_before with
  | Some row ->
      log (Printf.sprintf "Main menu open on row %d." row);
      Ok row
  | None -> Error not_open

(* The script's shorter way: Down when the target is 3 rows down or fewer. *)
let half = R.rows / 2

let moves ~from target =
  let diff = (target - from + R.rows) mod R.rows in
  if diff <= half then T.times diff down else T.times (R.rows - diff) up

let on_row target =
  match
    Effects.await ~timeout_ms:read_ms (fun m -> R.highlighted m = Some target)
  with
  | Holds _ -> Ok ()
  | Timeout ->
      Error
        (Printf.sprintf "the main menu is on row %s, not %d"
           (Option.fold ~none:"none" ~some:string_of_int (read_row ()))
           target)

let goto ~log target =
  match read_row () with
  | None -> Error not_open
  | Some from ->
      T.press_all (moves ~from target);
      Result.map
        (fun () -> log (Printf.sprintf "Main menu on row %d." target))
        (on_row target)
