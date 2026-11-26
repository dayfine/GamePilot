module S = Steps
module L = Look
module Failure = Engine_run.Failure

let choice_wait_ms = 3000
let choice_poll_ms = 250
let text_presses = 3

let press steps b =
  S.press steps b ~hold_ms:S.press_hold_ms ~release_ms:S.press_release_ms

(* A choice box whose highlighted row and rows read. *)
let with_rows (l : L.t) = l.choice_box && Option.is_some l.choice_rows

let wait_for_rows steps =
  S.wait_for steps
    (S.rule ~poll_ms:choice_poll_ms ~timeout_ms:choice_wait_ms ())
    with_rows

let no_choice =
  Failure.cause "no_choice"
    (Printf.sprintf "no choice box with rows that read after %d A presses"
       text_presses)

let text_press steps index =
  S.(steps.log)
    (Printf.sprintf "[PLZA] choose_%d: no choice yet: A through the text" index);
  press steps Wire.A

let rec rows_after_text steps index presses =
  match wait_for_rows steps with
  | S.Timed_out when presses < text_presses ->
      text_press steps index;
      rows_after_text steps index (presses + 1)
  | S.Timed_out -> Error no_choice
  | S.Home_menu -> Error S.game_not_running
  | S.Matched { look; _ } -> Ok (Option.value look.choice_rows ~default:(0, 0))

let highlighted (l : L.t) =
  match l.choice_rows with
  | Some (row, _) when l.choice_box -> Some row
  | _ -> None

let not_reached now index ~selected ~moves =
  let row = Option.fold ~none:"none" ~some:string_of_int (highlighted now) in
  Failure.cause "choice_not_reached"
    (Printf.sprintf
       "the highlight is on row %s, not %d, after %d presses from row %d" row
       index (abs moves) selected)

(* After a move, one read: the row highlighted. *)
let check_highlight steps index ~selected ~moves =
  let now = S.(steps.read_screen) () in
  if highlighted now = Some index then Ok ()
  else Error (not_reached now index ~selected ~moves)

let reached steps index ~selected ~moves =
  if moves = 0 then Ok () else check_highlight steps index ~selected ~moves

let take steps index (selected, count) =
  if index >= count then
    Error
      (Failure.cause "no_such_choice"
         (Printf.sprintf "row %d of a choice of %d rows" index count))
  else (
    S.(steps.log)
      (Printf.sprintf "[PLZA] choose_%d: row %d of %d highlighted" index
         selected count);
    let moves = index - selected in
    for _ = 1 to abs moves do
      press steps (if moves > 0 then Wire.Down else Wire.Up)
    done;
    Result.map
      (fun () -> press steps Wire.A)
      (reached steps index ~selected ~moves))

let run steps index =
  Result.bind (rows_after_text steps index 0) (take steps index)
