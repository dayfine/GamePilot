(* Initial_screen checks on a scripted console B (Scripted_home), covering
   black/asleep screens, HOME (lit and dimmed), user select, in-game screens,
   and missing frames across all three expectations (read-only, resume, and
   HOME-allowed). *)

open Switch
module S = Scripted_home

let console () =
 fun t b screen ->
  let show after s = S.show t ~after s in
  match (b, screen) with
  | _, S.Home_dimmed -> show 300 S.Home_fire_red_last
  | Wire.Right, S.Home_bdsp_last -> show 200 S.Home_on_fire_red
  | Wire.A, S.Home_fire_red_last -> show 800 S.Game
  | Wire.A, S.Home_on_fire_red -> show 800 S.User_select
  | Wire.A, S.User_select ->
      show 300 S.Black;
      show 4000 S.Intro
  | _ -> ()

let log = ignore

let check_screen expectation start () =
  S.play ~start (console ()) (fun () ->
      match
        Initial_screen.check ~log ~picture:Fire_red.nso_gba_picture expectation
      with
      | Ok () -> "ok"
      | Error e -> "error: " ^ e)

(* A fake effect handler that never delivers a frame: Await always times out. *)
let check_no_frame expectation () =
  let open Effect.Deep in
  let body () =
    match
      Initial_screen.check ~log ~picture:Fire_red.nso_gba_picture expectation
    with
    | Ok () -> "ok"
    | Error e -> "error: " ^ e
  in
  try_with body ()
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          let answer (v : unit -> a) =
            Some (fun (k : (a, _) continuation) -> continue k (v ()))
          in
          match eff with
          | Effects.Await _ -> answer (fun () -> Effects.Timeout)
          | Effects.Subscribe probes ->
              answer (fun () ->
                  List.map (fun (p : Wire.probe_spec) -> p.id) probes)
          | Effects.Unsubscribe ids -> answer (fun () -> ids)
          | _ -> None);
    }

let read_only = Initial_screen.In_game_read_only
let resume_fr = Initial_screen.In_game_or_resume (Some Fire_red.tile)
let resume_none = Initial_screen.In_game_or_resume None
let allow_home = Initial_screen.In_game_or_home
let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "initial_screen"
    [
      case "read-only: in game passes with no presses"
        (check_screen read_only S.Game)
        "ok; no press; ends on game";
      case "read-only: black / asleep fails fast with no presses"
        (check_screen read_only S.Black)
        "error: console appears asleep or capture shows a black screen; no \
         press; ends on black";
      case "read-only: HOME fails fast with no presses"
        (check_screen read_only S.Home_fire_red_last)
        "error: console is on the Switch HOME menu (expected the game; open \
         the game or run 'gamepilot console resume' first); no press; ends on \
         HOME (FireRed last)";
      case "read-only: dimmed HOME fails fast with no presses"
        (check_screen read_only S.Home_dimmed)
        "error: console is on the dimmed Switch HOME menu (expected the game; \
         wake the console and open the game first); no press; ends on HOME \
         (dimmed)";
      case "read-only: user select fails fast with no presses"
        (check_screen read_only S.User_select)
        "error: console is on the Switch user select screen (expected the \
         game; select a user to open the game first); no press; ends on user \
         select";
      case "read-only: no frame fails fast" (check_no_frame read_only)
        "error: no frame received from the capture card";
      case "resume: in game passes with no presses"
        (check_screen resume_fr S.Game)
        "ok; no press; ends on game";
      case "resume: black / asleep fails fast with no presses"
        (check_screen resume_fr S.Black)
        "error: console appears asleep or capture shows a black screen; no \
         press; ends on black";
      case "resume: suspended FireRed on HOME resumes it"
        (check_screen resume_fr S.Home_fire_red_last)
        "ok; A; ends on game";
      case "resume: dimmed HOME wakes and resumes FireRed"
        (check_screen resume_fr S.Home_dimmed)
        "ok; B, A; ends on game";
      case "resume: closed FireRed on HOME moves cursor and launches it"
        (check_screen resume_fr S.Home_bdsp_last)
        "ok; Right, A, A; ends on intro";
      case "resume: user select presses A and launches"
        (check_screen resume_fr S.User_select)
        "ok; A; ends on intro";
      case "resume without tile: HOME fails fast with no presses"
        (check_screen resume_none S.Home_fire_red_last)
        "error: console is on the Switch HOME menu (expected the game; open \
         the game or run 'gamepilot console resume' first); no press; ends on \
         HOME (FireRed last)";
      case "allow-home: in game passes with no presses"
        (check_screen allow_home S.Game)
        "ok; no press; ends on game";
      case "allow-home: HOME passes with no presses"
        (check_screen allow_home S.Home_fire_red_last)
        "ok; no press; ends on HOME (FireRed last)";
      case "allow-home: dimmed HOME passes with no presses"
        (check_screen allow_home S.Home_dimmed)
        "ok; no press; ends on HOME (dimmed)";
      case "allow-home: black / asleep still fails fast"
        (check_screen allow_home S.Black)
        "error: console appears asleep or capture shows a black screen; no \
         press; ends on black";
      case "allow-home: no frame still fails fast"
        (check_no_frame allow_home)
        "error: no frame received from the capture card";
    ]
