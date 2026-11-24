(* Parking on HOME and resuming the game, on a scripted console B
   (Scripted_home) whose screens are captures read by Home_screen. *)

open Switch_home
module S = Scripted_home

(* HOME zooms out of the game; A on FireRed's tile resumes it when it was
   played last (it still runs), or opens the user select when it was not; A
   there boots it: black, then the intro. [home_ignored] HOME presses do
   nothing. *)
let console ?(home_ignored = 0) ?(a_ignored = false) () =
  let homes = ref 0 in
  fun t b screen ->
    let show after s = S.show t ~after s in
    match (b, screen) with
    | Wire.Home, S.Game ->
        incr homes;
        if !homes > home_ignored then show 600 S.Home_fire_red_last
    | Wire.B, S.User_select -> show 300 S.Home_bdsp_last
    | Wire.Right, S.Home_bdsp_last -> show 200 S.Home_on_fire_red
    | Wire.A, S.Home_fire_red_last when not a_ignored -> show 800 S.Game
    | Wire.A, S.Home_on_fire_red -> show 800 S.User_select
    | Wire.A, S.User_select ->
        show 300 S.Black;
        show 4000 S.Intro
    | _ -> ()

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
      case "resume: the cursor already on FireRed's tile, no Right"
        (resume S.Home_on_fire_red (console ()))
        "ok, launched the game; A, A; ends on intro";
      case "resume: already in the game, nothing"
        (resume S.Game (console ()))
        "ok, already in the game; no press; ends on game";
      case "resume: A on HOME shows nothing"
        (resume S.Home_fire_red_last (console ~a_ignored:true ()))
        "error: the game did not show after A on HOME; A; ends on HOME \
         (FireRed last)";
    ]
