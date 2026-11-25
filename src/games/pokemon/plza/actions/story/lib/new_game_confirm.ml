module S = Story_steps
module Failure = Engine_run.Failure

let poll_ms = 100
let presses_max = 6
let ready_row = 2

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

let rec to_ready steps row press =
  match row with
  | Some r when r = ready_row ->
      S.(steps.log) "[PLZA] Confirm Choices: A on \"Ready!\".";
      S.press steps Wire.A ~hold_ms:160 ~release_ms:2000;
      Ok ()
  | Some _ when press < presses_max ->
      S.(steps.log) "[PLZA] Confirm Choices: DOWN.";
      S.press steps Wire.Down ~hold_ms:160 ~release_ms:500;
      let row = read_row steps 1000 in
      Option.iter
        (fun r ->
          S.(steps.log)
            (Printf.sprintf
               "[PLZA] Confirm Choices: the highlight is on row %d." r))
        row;
      to_ready steps row (press + 1)
  | _ ->
      Error
        (Failure.cause "confirm_not_ready"
           "the Confirm Choices highlight was not read on \"Ready!\".")

let run steps =
  match read_row steps 2000 with
  | None -> Error not_on_screen
  | Some r ->
      S.(steps.log)
        (Printf.sprintf "[PLZA] Confirm Choices on screen, row %d highlighted."
           r);
      to_ready steps (Some r) 0
