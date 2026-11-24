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
  ignore
    (Effects.submit [ Wire.Press { buttons = [ b ]; hold_ms; cooldown_ms } ]
      : Wire.batch_done)

let screen () =
  match Effects.read () with Some m -> H.read m | None -> H.Elsewhere

let is_home m = match H.read m with H.Home _ -> true | _ -> false

let await_home () =
  match Effects.await ~timeout_ms:home_wait_ms is_home with
  | Holds _ -> Ok ()
  | Timeout -> Error "the HOME menu did not show"

let park_from ~log = function
  | H.Home _ ->
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

let park ~log color =
  Effects.with_probes (H.probes color) (fun () ->
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
   that is neither HOME, the user select nor black. *)
let in_game m = H.read m = H.Elsewhere && not (H.black m)

let rec until_game ~log ~launched =
  match
    Effects.await ~timeout_ms:launch_wait_ms (fun m ->
        in_game m || ((not launched) && H.read m = H.User_select))
  with
  | Timeout -> Error "the game did not show after A on HOME"
  | Holds m when in_game m -> Ok (if launched then Launched else Resumed)
  | Holds _ ->
      log "[Resume] the user select: A on the highlighted user";
      press Wire.A;
      until_game ~log ~launched:true

let ( let* ) = Result.bind

let from_home ~log ~cursor ~game_tile =
  match (cursor, game_tile) with
  | _, None -> Error "no tile on HOME shows the game"
  | None, Some _ -> Error "the cursor is on no tile"
  | Some cursor, Some k ->
      let* () = move_cursor ~log ~cursor k in
      log "[Resume] A on the game's tile";
      press Wire.A;
      until_game ~log ~launched:false

let resume_from ~log = function
  | H.Elsewhere -> Ok Already_in_game
  | User_select ->
      press Wire.A;
      until_game ~log ~launched:true
  | Home { cursor; game_tile } -> from_home ~log ~cursor ~game_tile

let resume ~log color =
  Effects.with_probes (H.probes color) (fun () ->
      let screen = screen () in
      log ("[Resume] " ^ H.to_string screen);
      resume_from ~log screen)

let resumed_to_string = function
  | Already_in_game -> "already in the game"
  | Resumed -> "resumed the suspended game"
  | Launched -> "launched the game"
