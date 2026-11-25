(* Parking on HOME and resuming the game, on a scripted console B
   (Scripted_home) whose screens are captures read by Home_screen. *)

open Switch_home
module S = Scripted_home

(* HOME zooms out of the game; A on FireRed's tile resumes it when it was
   played last (it still runs), or opens the user select when it was not; A
   there boots it: black, then the intro. Any press wakes a dimmed HOME, and
   does nothing else. [home_ignored] HOME presses do
   nothing. *)
let console ?(home_ignored = 0) ?(a_ignored = false) ?(closed = false) () =
  let homes = ref 0 in
  fun t b screen ->
    let show after s = S.show t ~after s in
    match (b, screen) with
    | Wire.Home, S.Game ->
        incr homes;
        if !homes > home_ignored then show 600 S.Home_fire_red_last
    | Wire.B, S.User_select -> show 300 S.Home_bdsp_last
    | _, S.Home_dimmed -> show 300 S.Home_fire_red_last
    | Wire.Right, S.Home_bdsp_last -> show 200 S.Home_on_fire_red
    | Wire.A, S.Home_fire_red_last when closed ->
        (* HOME's zoom passes a frame that is neither HOME nor black. *)
        show 300 S.Game;
        show 1200 S.User_select
    | Wire.A, S.Home_fire_red_last when not a_ignored -> show 800 S.Game
    | Wire.A, (S.Home_on_fire_red | S.Home_scrolled_on_fire_red) ->
        show 800 S.User_select
    | Wire.A, S.User_select ->
        show 300 S.Black;
        show 4000 S.Intro
    | _ -> ()

(* A scrolled row: the [n]th Left (or Right) brings FireRed into view with the
   cursor on it, the ones before show other tiles; with [None], that way is
   the row's end and the press does nothing. Other presses as [console]. *)
let scrolled ?left_to_fire_red ?right_to_fire_red () =
  let base = console () and lefts = ref 0 and rights = ref 0 in
  fun t b screen ->
    let step count far on n =
      incr count;
      S.show t ~after:200 (if !count >= n then on else far)
    in
    match b with
    | Wire.Left ->
        Option.iter
          (step lefts S.Home_row_start S.Home_scrolled_on_fire_red)
          left_to_fire_red
    | Wire.Right ->
        Option.iter
          (step rights S.Home_scrolled_fire_red_out S.Home_on_fire_red)
          right_to_fire_red
    | _ -> base t b screen

let times n b = List.init n (fun _ -> b)
let log = ignore

let run start react body =
  let t = S.create ~start react in
  let outcome = S.run t body in
  Printf.sprintf "%s; %s; ends on %s" outcome (S.presses_text t)
    (S.screen_name (S.screen_at t t.S.clock_ms))

let park start react () =
  run start react (fun () ->
      match Console_park.park ~log Fire_red.tile with
      | Ok () -> "ok"
      | Error e -> "error: " ^ e)

let resume start react () =
  run start react (fun () ->
      match Console_park.resume ~log Fire_red.tile with
      | Ok r -> "ok, " ^ Console_park.resumed_to_string r
      | Error e -> "error: " ^ e)

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "console_park"
    [
      case "park: HOME from the game"
        (park S.Game (console ()))
        "ok; Home; ends on HOME (FireRed last)";
      case "park: a HOME press not taken is pressed again"
        (park S.Game (console ~home_ignored:1 ()))
        "ok; Home, Home; ends on HOME (FireRed last)";
      case "park: already on HOME, nothing (HOME there would resume)"
        (park S.Home_bdsp_last (console ()))
        "ok; no press; ends on HOME (BDSP last)";
      case "park: HOME dimmed, nothing"
        (park S.Home_dimmed (console ()))
        "ok; no press; ends on HOME (dimmed)";
      case "park: the user select, B back to HOME"
        (park S.User_select (console ()))
        "ok; B; ends on HOME (BDSP last)";
      case "resume: FireRed suspended, A resumes it"
        (resume S.Home_fire_red_last (console ()))
        "ok, resumed the suspended game; A; ends on game";
      case
        "resume: FireRed closed (BDSP last), Right to its tile, A, A on the \
         user select, black, the intro"
        (resume S.Home_bdsp_last (console ()))
        "ok, launched the game; Right, A, A; ends on intro";
      case
        "resume: FireRed closed on its tile, a passing frame before the user \
         select is not the game (console B, 2026-11-24)"
        (resume S.Home_fire_red_last (console ~closed:true ()))
        "ok, launched the game; A, A; ends on intro";
      case "resume: the cursor already on FireRed's tile, no Right"
        (resume S.Home_on_fire_red (console ()))
        "ok, launched the game; A, A; ends on intro";
      case "resume: HOME dimmed, B wakes it, A resumes FireRed"
        (resume S.Home_dimmed (console ()))
        "ok, resumed the suspended game; B, A; ends on game";
      case "resume: HOME scrolled, the cursor on FireRed, A at once"
        (resume S.Home_scrolled_on_fire_red (scrolled ()))
        "ok, launched the game; A, A; ends on intro";
      case
        "resume: FireRed out of view to the left, Left until it shows with the \
         cursor on it (console B, 2026-11-25)"
        (resume S.Home_scrolled_fire_red_out (scrolled ~left_to_fire_red:3 ()))
        "ok, launched the game; Left, Left, Left, A, A; ends on intro";
      case
        "resume: FireRed out of view to the right, 12 Left at the row's start, \
         then Right until it shows"
        (resume S.Home_row_start (scrolled ~right_to_fire_red:2 ()))
        (Printf.sprintf
           "ok, launched the game; %s, Right, Right, A, A; ends on intro"
           (String.concat ", " (times 12 "Left")));
      case "resume: no tile shows FireRed, 12 Left and 12 Right, then an error"
        (resume S.Home_scrolled_fire_red_out (scrolled ()))
        (Printf.sprintf
           "error: no tile on HOME shows the game, after 12 Left and 12 Right; \
            %s, %s; ends on HOME (scrolled, FireRed out of view)"
           (String.concat ", " (times 12 "Left"))
           (String.concat ", " (times 12 "Right")));
      case "resume: the cursor on the buttons below the row, nothing pressed"
        (resume S.Home_on_buttons (scrolled ()))
        "error: the cursor is on no tile of HOME's row (on the buttons \
         below?); no press; ends on HOME (cursor on the buttons)";
      case "resume: already in the game, nothing"
        (resume S.Game (console ()))
        "ok, already in the game; no press; ends on game";
      case "resume: A on HOME shows nothing"
        (resume S.Home_fire_red_last (console ~a_ignored:true ()))
        "error: the game did not show after A on HOME; A; ends on HOME \
         (FireRed last)";
    ]
