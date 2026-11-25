module H = Home_screen

type resumed = Already_in_game | Resumed | Launched

let tap_hold_ms = 100
let tap_release_ms = 400

(* HOME's zoom out and in each take under a second on console B. *)
let home_hold_ms = 100
let home_settle_ms = 1000
let home_wait_ms = 5000
let launch_wait_ms = 60_000

let press ?(hold_ms = tap_hold_ms) ?(cooldown_ms = tap_release_ms) b =
  Switch_presses.press ~hold_ms ~cooldown_ms b

let screen () =
  match Effects.read () with Some m -> H.read m | None -> H.Elsewhere

let is_home m = match H.read m with H.Home _ -> true | _ -> false

let await_home () =
  match Effects.await ~timeout_ms:home_wait_ms is_home with
  | Holds _ -> Ok ()
  | Timeout -> Error "the HOME menu did not show"

let park_from ~log = function
  | H.Home _ | Home_dimmed ->
      log "[Park] already on HOME";
      Ok ()
  | User_select ->
      log "[Park] the user select: B back to HOME";
      press Wire.B;
      await_home ()
  | Elsewhere -> (
      log "[Park] HOME";
      press ~hold_ms:home_hold_ms ~cooldown_ms:home_settle_ms Wire.Home;
      match await_home () with
      | Ok () -> Ok ()
      | Error _ ->
          log "[Park] no HOME menu: HOME again";
          press ~hold_ms:home_hold_ms ~cooldown_ms:home_settle_ms Wire.Home;
          await_home ())

let park ~log ~picture color =
  Effects.with_probes (H.probes ~picture color) (fun () ->
      let result = park_from ~log (screen ()) in
      (match result with
      | Ok () -> log ("[Park] " ^ H.to_string (screen ()))
      | Error e -> log ("[Park] " ^ e));
      result)

let cursor_on k m =
  match H.read m with H.Home { cursor = Some c; _ } -> c = k | _ -> false

(* The cursor onto tile [k]: Right or Left one tile at a time. *)
let move_cursor ~log ~cursor k =
  let button = if k > cursor then Wire.Right else Wire.Left in
  if k <> cursor then (
    log
      (Printf.sprintf "[Resume] %s %d to the game's tile"
         (Wire.string_of_button button)
         (abs (k - cursor)));
    for _ = 1 to abs (k - cursor) do
      press button
    done);
  match Effects.await ~timeout_ms:home_wait_ms (cursor_on k) with
  | Holds _ -> Ok ()
  | Timeout -> Error "the cursor did not reach the game's tile"

(* After A: the user select gets A (the highlighted user), until a picture
   that is neither HOME, the user select nor black, for [steady_ms]: HOME's
   zoom after A passes such frames before the user select shows (console B,
   2026-11-24, FireRed closed: read as resumed). *)
let in_game m = H.read m = H.Elsewhere && not (H.black m)
let steady_ms = 1500.

(* [in_game] since [steady_ms] ago, the user select (before a launch) at once. *)
let game_or_user_select ~launched =
  let since = ref None in
  fun (m : Effects.measurements) ->
    if in_game m then (
      let start = Option.value !since ~default:m.t_ms in
      since := Some start;
      m.t_ms -. start >= steady_ms)
    else (
      since := None;
      (not launched) && H.read m = H.User_select)

let rec until_game ~log ~launched =
  match
    Effects.await ~timeout_ms:launch_wait_ms (game_or_user_select ~launched)
  with
  | Timeout -> Error "the game did not show after A on HOME"
  | Holds m when in_game m -> Ok (if launched then Launched else Resumed)
  | Holds _ ->
      log "[Resume] the user select: A on the highlighted user";
      press Wire.A;
      until_game ~log ~launched:true

let ( let* ) = Result.bind

(* HOME's row holds up to 12 games, then All Software: 12 presses one way
   pass every tile. *)
let row_tiles = 12
let no_cursor = "the cursor is on no tile of HOME's row (on the buttons below?)"

let row m =
  match H.read m with
  | H.Home { cursor = Some cursor; game_tile } -> Some (cursor, game_tile)
  | Home _ | Home_dimmed | User_select | Elsewhere -> None

(* The tile the cursor is on and the game's, once the row has settled. *)
let read_row () =
  match
    Effects.await ~timeout_ms:home_wait_ms (fun m -> Option.is_some (row m))
  with
  | Holds m -> Option.to_result ~none:no_cursor (row m)
  | Timeout -> Error no_cursor

(* The cursor onto the game's tile: within the tiles in view, or, when none
   shows the game, [sweeps] in turn (Left, then Right) a tile at a time,
   reading the row after each press. *)
let rec find_game ~log ~sweeps ~presses =
  let* cursor, game_tile = read_row () in
  match (game_tile, sweeps) with
  | Some k, _ -> move_cursor ~log ~cursor k
  | None, [] ->
      Error
        (Printf.sprintf
           "no tile on HOME shows the game, after %d Left and %d Right"
           row_tiles row_tiles)
  | None, _ :: rest when presses >= row_tiles ->
      find_game ~log ~sweeps:rest ~presses:0
  | None, button :: _ ->
      log
        (Printf.sprintf
           "[Resume] the game's tile not in view (cursor on %d): %s" cursor
           (Wire.string_of_button button));
      press button;
      find_game ~log ~sweeps ~presses:(presses + 1)

let from_home ~log =
  let* () = find_game ~log ~sweeps:[ Wire.Left; Wire.Right ] ~presses:0 in
  log "[Resume] A on the game's tile";
  press Wire.A;
  until_game ~log ~launched:false

let rec resume_from ~log = function
  | H.Elsewhere -> Ok Already_in_game
  | Home_dimmed ->
      log "[Resume] HOME dimmed: B to light it";
      press Wire.B;
      let* () = await_home () in
      let screen = screen () in
      log ("[Resume] " ^ H.to_string screen);
      resume_from ~log screen
  | User_select ->
      press Wire.A;
      until_game ~log ~launched:true
  | Home _ -> from_home ~log

let resume ~log ~picture color =
  Effects.with_probes (H.probes ~picture color) (fun () ->
      let screen = screen () in
      log ("[Resume] " ^ H.to_string screen);
      resume_from ~log screen)

let resumed_to_string = function
  | Already_in_game -> "already in the game"
  | Resumed -> "resumed the suspended game"
  | Launched -> "launched the game"
