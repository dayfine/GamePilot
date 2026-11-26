module Failure = Engine_run.Failure
module Choices = New_game_choices
open New_game_screen

type game_steps = {
  read_screen : unit -> New_game_screen.t;
  submit : Wire.command list -> unit;
  launch : unit -> (unit, string) result;
  now : unit -> float;
  log : string -> unit;
}

let ( let* ) = Result.bind
let with_hint message = message ^ " " ^ Choices.by_hand_hint

let refused message =
  Failure.cause ~repeats:true "new_game_refused" (with_hint message)

let failed message =
  Failure.cause "new_game_failed" (with_hint ("AutoStory intro: " ^ message))

let wait steps ms = steps.submit [ Wire.Wait { wait_ms = ms } ]
let poll_ms = 250
let press_hold_ms = 80

let press steps button release_ms =
  steps.submit
    [ Wire.press ~hold_ms:press_hold_ms ~cooldown_ms:release_ms [ button ] ]

(* wait_for_frame: reads until [check] holds, [poll_ms] apart, up to
   [timeout_ms]. *)
let wait_for steps ~timeout_ms check =
  let deadline = steps.now () +. float_of_int timeout_ms in
  let rec go () =
    if check (steps.read_screen ()) then true
    else if steps.now () >= deadline then false
    else (
      wait steps poll_ms;
      go ())
  in
  go ()

(* require_new_game_home. *)
let home_wait_ms = 2000
let wake_release_ms = 1000
let on_home s = s.home

let not_on_home =
  refused
    "AutoStory: 00.00-new-game starts a new game (no save) from the Switch \
     HOME. It is not on screen; pressed B once to wake the screen, nothing \
     else was pressed."

(* HomeMenuDetector misses a dimmed HOME; B wakes it and does nothing else
   there. *)
let wake_home steps =
  steps.log
    "AutoStory intro: HOME not detected; pressing B once to wake a dimmed \
     screen.";
  press steps Wire.B wake_release_ms;
  if wait_for steps ~timeout_ms:home_wait_ms on_home then Ok ()
  else Error not_on_home

let require_home steps =
  if wait_for steps ~timeout_ms:home_wait_ms on_home then Ok ()
  else wake_home steps

let launch steps =
  let* () = require_home steps in
  steps.log "AutoStory intro: starting on the Switch HOME.";
  Result.map_error
    (fun e -> failed ("the launch from HOME failed: " ^ e))
    (steps.launch ())

(* The logos before the language list take about 15 s, with no press. *)
let launch_limit_ms = 60_000
let ms_per_s = 1000
let language_list s = Option.is_some s.language_entry

let language_list_missing =
  Printf.sprintf "the language list did not show within %d s of the launch."
    (launch_limit_ms / ms_per_s)

let wait_for_language_list steps =
  if wait_for steps ~timeout_ms:launch_limit_ms language_list then (
    steps.log "AutoStory intro: the language list shows.";
    Ok ())
  else Error (failed language_list_missing)

(* grid_moves' first step: column first, then row. *)
let first_move ~from:(c0, r0) ~to_:(c1, r1) =
  if c1 > c0 then Some Wire.Right
  else if c1 < c0 then Some Wire.Left
  else if r1 > r0 then Some Wire.Down
  else if r1 < r0 then Some Wire.Up
  else None

let list_rows = 5
let list_cell entry = (entry / list_rows, entry mod list_rows)
let language_tries = 20
let language_tap_release_ms = 600
let choice_release_ms = 500

let language_not_reached (info : Choices.language_info) =
  Error
    (failed
       (Printf.sprintf "the language list's highlight did not reach %s."
          info.tag))

let language_picked steps (info : Choices.language_info) =
  steps.log
    (Printf.sprintf "AutoStory intro: language %s (entry %d): A." info.tag
       info.list_entry);
  press steps Wire.A choice_release_ms

(* One read of the list: [Some outcome] when picking ends, [None] to read
   again. *)
let language_step steps (info : Choices.language_info) = function
  | None ->
      wait steps poll_ms;
      None
  | Some entry when entry = info.list_entry ->
      language_picked steps info;
      Some (Ok ())
  | Some entry -> (
      match
        first_move ~from:(list_cell entry) ~to_:(list_cell info.list_entry)
      with
      | None -> Some (language_not_reached info)
      | Some b ->
          press steps b language_tap_release_ms;
          None)

let rec pick_language steps (info : Choices.language_info) attempt =
  if attempt >= language_tries then language_not_reached info
  else
    match language_step steps info (steps.read_screen ()).language_entry with
    | Some outcome -> outcome
    | None -> pick_language steps info (attempt + 1)

let look_columns = 4
let look_cell look = ((look - 1) mod look_columns, (look - 1) / look_columns)
let tilt_hold_ms = 150
let tilt_release_ms = 500

let stick = function
  | Wire.Up -> Wire.stick 0. 1.
  | Wire.Down -> Wire.stick 0. (-1.)
  | Wire.Left -> Wire.stick (-1.) 0.
  | _ -> Wire.stick 1. 0.

let tilt_command s =
  Wire.press ~left_stick:s ~hold_ms:tilt_hold_ms ~cooldown_ms:tilt_release_ms []

(* One portrait per tilt. *)
let tilt steps direction =
  match stick direction with
  | Ok s -> steps.submit [ tilt_command s ]
  | Error _ -> ()

(* read_settled_look: two reads in a row agree. *)
let settled_reads = 14
let settled_gap_ms = 150

let read_settled_look steps =
  let rec go previous n =
    if n >= settled_reads then None
    else
      let look = (steps.read_screen ()).look in
      if look <> None && look = previous then look
      else (
        wait steps settled_gap_ms;
        go look (n + 1))
  in
  go None 0

let picker_wait_ms = 20_000
let look_tries = 24
let max_unread = 6

let look_not_read look =
  Error
    (failed
       (Printf.sprintf "the look picker's highlight was not read on look %d."
          look))

let look_picked steps look =
  steps.log (Printf.sprintf "AutoStory intro: look %d: A." look);
  press steps Wire.A choice_release_ms

(* One tilt toward [look] from [from]; false when there is no move. *)
let tilt_toward steps ~from look =
  match first_move ~from:(look_cell from) ~to_:(look_cell look) with
  | None -> false
  | Some d ->
      tilt steps d;
      true

let rec tilt_to_look steps look ~unread attempt =
  if attempt >= look_tries || unread > max_unread then look_not_read look
  else
    match read_settled_look steps with
    | None ->
        tilt steps Wire.Left;
        tilt_to_look steps look ~unread:(unread + 1) (attempt + 1)
    | Some l when l = look ->
        look_picked steps look;
        Ok ()
    | Some l ->
        if tilt_toward steps ~from:l look then
          tilt_to_look steps look ~unread (attempt + 1)
        else look_not_read look

let pick_look steps look =
  if not (wait_for steps ~timeout_ms:picker_wait_ms (fun s -> s.look_picker))
  then
    Error
      (failed "the look picker did not show within 20 s of the language's A.")
  else tilt_to_look steps look ~unread:0 0

(* Presses while the keyboard slides in are dropped. *)
let keyboard_wait_ms = 20_000
let keyboard_settle_ms = 1000

let wait_for_keyboard steps =
  if wait_for steps ~timeout_ms:keyboard_wait_ms (fun s -> s.name_keyboard) then (
    wait steps keyboard_settle_ms;
    Ok ())
  else
    Error (failed "the name keyboard did not show within 20 s of the look's A.")

let typing_steps steps : Switch_home.Keyboard_typing.game_steps =
  {
    read_cursor = (fun () -> (steps.read_screen ()).keyboard_cursor);
    read_text_pixels = (fun () -> (steps.read_screen ()).text_pixels);
    submit = steps.submit;
    log = steps.log;
  }

(* One + submits the name; Chinese keyboards first take one to accept it. *)
let submit_presses = 3
let submit_wait_ms = 5000
let confirm_wait_ms = 15_000
let on_confirm s = s.confirm_choices

(* One +; whether Confirm Choices then read within 5 s. *)
let plus steps pressed =
  steps.log
    (Printf.sprintf "AutoStory intro: keyboard: + (%d of at most %d)." pressed
       submit_presses);
  press steps Wire.Start choice_release_ms;
  wait_for steps ~timeout_ms:submit_wait_ms on_confirm

let rec submit_name steps pressed =
  if pressed > submit_presses then confirm_at_last steps
  else if plus steps pressed then (
    steps.log "AutoStory intro: Confirm Choices shows.";
    Ok ())
  else if not (steps.read_screen ()).name_keyboard then confirm_at_last steps
  else (
    steps.log "AutoStory intro: keyboard: still open after +.";
    submit_name steps (pressed + 1))

and confirm_at_last steps =
  if wait_for steps ~timeout_ms:confirm_wait_ms on_confirm then Ok ()
  else Error (failed "Confirm Choices did not show after the name's +.")

let type_name steps (c : Choices.t) =
  let* () = wait_for_keyboard steps in
  steps.log
    (Printf.sprintf
       "AutoStory intro: keyboard: its 0/N counter is not read; the language's \
        limit (%d) holds."
       (Choices.info c.language).name_limit);
  let* () =
    if c.language = Choices.Chinese_simplified then
      Result.map_error failed (Letters_mode.switch (typing_steps steps))
    else Ok ()
  in
  steps.log (Printf.sprintf "AutoStory intro: typing \"%s\"." c.name);
  let* () =
    Result.map_error
      (fun e -> failed e)
      (Switch_home.Keyboard_typing.type_text (typing_steps steps) c.name)
  in
  submit_name steps 1

let run steps (c : Choices.t) =
  match Choices.problem c with
  | Some p -> Error (refused p)
  | None ->
      let* () = launch steps in
      let* () = wait_for_language_list steps in
      let* () = pick_language steps (Choices.info c.language) 0 in
      let* () = pick_look steps c.look in
      type_name steps c
