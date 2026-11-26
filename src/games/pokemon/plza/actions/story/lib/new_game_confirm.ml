module S = Steps
module Failure = Engine_run.Failure

let poll_ms = 100
let presses_max = 6
let ready_row = 2
let ready_release_ms = 2000
let down_release_ms = 500
let down_read_ms = 1000
let first_read_ms = 2000

(* The highlighted row, read within [window_ms]. *)
let read_row steps window_ms =
  match
    S.wait_for steps (S.rule ~poll_ms ~timeout_ms:window_ms ()) (fun l ->
        Option.is_some l.confirm_row)
  with
  | Matched { look; _ } -> look.confirm_row
  | Timed_out | Home_menu -> None

let not_on_screen =
  Failure.cause ~repeats:true "not_on_confirm_choices"
    "01.00b starts on the new game's \"Confirm Choices\" screen, after the \
     language, look and name (made by hand). It is not on screen; nothing was \
     pressed."

let log_row steps r =
  S.(steps.log)
    (Printf.sprintf "[PLZA] Confirm Choices: the highlight is on row %d." r)

(* As the C++ loop: at most [presses_max] reads, the last DOWN's read
   included, so "Ready!" read only after the sixth DOWN fails too. *)
let rec to_ready steps row press =
  match row with
  | Some r when press < presses_max && r = ready_row ->
      S.(steps.log) "[PLZA] Confirm Choices: A on \"Ready!\".";
      S.press steps Wire.A ~hold_ms:S.press_hold_ms ~release_ms:ready_release_ms;
      Ok ()
  | Some _ when press < presses_max ->
      S.(steps.log) "[PLZA] Confirm Choices: DOWN.";
      S.press steps Wire.Down ~hold_ms:S.press_hold_ms
        ~release_ms:down_release_ms;
      let row = read_row steps down_read_ms in
      Option.iter (log_row steps) row;
      to_ready steps row (press + 1)
  | _ ->
      Error
        (Failure.cause "confirm_not_ready"
           "the Confirm Choices highlight was not read on \"Ready!\".")

let run steps =
  match read_row steps first_read_ms with
  | None -> Error not_on_screen
  | Some r ->
      S.(steps.log)
        (Printf.sprintf "[PLZA] Confirm Choices on screen, row %d highlighted."
           r);
      to_ready steps (Some r) 0
