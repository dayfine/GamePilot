module H = Home_screen

type screen =
  | Black
  | Home of { cursor : int option; game_tile : int option }
  | Home_dimmed
  | User_select
  | In_game
  | No_frame

type expectation =
  | In_game_read_only
  | In_game_or_resume of H.tile_color option
  | In_game_or_home

let read_timeout_ms = 2000

(* A valid [min <= max] RGB range used when the caller does not need to match a
   specific game tile on HOME; the daemon rejects probes with [min > max]. *)
let no_tile : H.tile_color = { min = (0, 0, 0); max = (0, 0, 0) }

let classify m =
  match H.read m with
  | H.Home { cursor; game_tile } -> Home { cursor; game_tile }
  | H.Home_dimmed -> Home_dimmed
  | H.User_select -> User_select
  | H.Elsewhere -> if H.black m || Black_screen.shown m then Black else In_game

let probes ~picture tile =
  H.probes ~picture (Option.value tile ~default:no_tile)
  @ Black_screen.probes ~picture

let read ~picture ?tile () =
  Effects.with_probes (probes ~picture tile) (fun () ->
      match Effects.await ~timeout_ms:read_timeout_ms (fun _ -> true) with
      | Holds m -> classify m
      | Timeout -> No_frame)

let screen_to_string = function
  | Black -> "black / asleep screen"
  | Home { cursor; game_tile } -> H.to_string (H.Home { cursor; game_tile })
  | Home_dimmed -> H.to_string H.Home_dimmed
  | User_select -> H.to_string H.User_select
  | In_game -> "in game (not HOME)"
  | No_frame -> "no frame"

let unexpected_screen = function
  | Home _ ->
      "console is on the Switch HOME menu (expected the game; open the game or \
       run 'gamepilot console resume' first)"
  | Home_dimmed ->
      "console is on the dimmed Switch HOME menu (expected the game; wake the \
       console and open the game first)"
  | User_select ->
      "console is on the Switch user select screen (expected the game; select \
       a user to open the game first)"
  | Black -> "console appears asleep or capture shows a black screen"
  | No_frame -> "no frame received from the capture card"
  | In_game -> "unexpected in-game screen"

let resume_from_home ~log ~picture tile =
  match Console_park.resume ~log ~picture tile with
  | Ok r ->
      log ("[Screen] " ^ Console_park.resumed_to_string r);
      Ok ()
  | Error e -> Error ("could not resume the game from HOME: " ^ e)

let verify_via_home ~log ~picture tile =
  match Console_park.park ~log ~picture tile with
  | Error e -> Error ("could not reach HOME to verify the game: " ^ e)
  | Ok () -> resume_from_home ~log ~picture tile

let tile_of = function
  | In_game_or_resume tile -> tile
  | In_game_read_only | In_game_or_home -> None

let check ~log ~picture expectation =
  let screen = read ~picture ?tile:(tile_of expectation) () in
  log ("[Screen] " ^ screen_to_string screen);
  match (screen, expectation) with
  | (Black | No_frame), _ -> Error (unexpected_screen screen)
  | In_game, In_game_or_resume (Some tile) -> verify_via_home ~log ~picture tile
  | In_game, _ -> Ok ()
  | (Home _ | Home_dimmed | User_select), In_game_or_home -> Ok ()
  | (Home _ | Home_dimmed | User_select), In_game_or_resume (Some tile) ->
      resume_from_home ~log ~picture tile
  | ( (Home _ | Home_dimmed | User_select),
      (In_game_read_only | In_game_or_resume None) ) ->
      Error (unexpected_screen screen)

let check_unless_chained ~already_at_start ~log ~picture expectation =
  if already_at_start then (
    log
      "[Console] continuing from previous pass (skipping initial-screen check)";
    Ok ())
  else check ~log ~picture expectation
