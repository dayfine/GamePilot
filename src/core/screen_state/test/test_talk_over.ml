(* Talk_over on scripted scenes, a look a second apart. Ported from the fork's
   Pokemon_SceneJudges_Tests (test_talk_over). *)

open Screen_state

let quiet = { Facts.none with free_control = true; screen_still = true }
let calm = { Facts.none with free_control = true }
let box = { quiet with dialog = true }

(* A black frame as BDSP's eyes see it: no box, so "overworld", and still. *)
let faded = { quiet with fade = Fade.Black }
let calm_faded = { calm with fade = Fade.Black }
let black = { Facts.none with fade = Fade.Black }
let banner = { Facts.none with banner = true; free_control = true }
let battle = { Facts.none with battle = true }

(* The overworld with people walking about: the screen moves, the player does
   not. *)
let people_walking = { calm with player_still = true }

(* The player walking: the box around the player moves too. *)
let player_moving = calm
let beat_ms = 1000.
let repeat look n = List.init n (fun _ -> look)

let move_name = function
  | Talk_over.Press Next -> "next"
  | Press B -> "B"
  | Battle -> "battle"
  | Done -> "done"

(* The beat the judge first says [want] at, if any. *)
let first_beat rule beats want =
  let rec go judge i = function
    | [] -> Printf.sprintf "never %s (%s)" want (Talk_over.describe judge)
    | facts :: rest ->
        let at_ms = float_of_int i *. beat_ms in
        let judge, move = Talk_over.observe judge facts ~at_ms in
        if move_name move = want then Printf.sprintf "%s at beat %d" want i
        else go judge (i + 1) rest
  in
  go (Talk_over.create rule) 0 beats

let case name ?(rule = Talk_over.default_rule) beats want expectation =
  {
    Table_test.name;
    input = (fun () -> first_beat rule beats want);
    expectation;
  }

let default = Talk_over.default_rule
let short_calm = { default with calm_ms = 1000 }

(* Stillness judged by the player alone, as the fork's settle after a door. *)
let player_still = { default with still = Player }

let () =
  Table_test.run "Talk_over"
    [
      case "5 s of quiet ends it" (repeat quiet 8) "done" "done at beat 5";
      case "a box restarts the quiet"
        (repeat quiet 3 @ [ box ] @ repeat quiet 8)
        "done" "done at beat 9";
      case "a box is answered" [ box ] "next" "next at beat 0";
      case "no box is a B press" [ quiet ] "B" "B at beat 0";
      case "15 s calm but moving ends it" (repeat calm 20) "done"
        "done at beat 15";
      (* PLZA: its party bar never shows mid-scene for long, and its city
         never stands still. *)
      case "a shorter calm rule ends it sooner" ~rule:short_calm (repeat calm 5)
        "done" "done at beat 1";
      case "a shorter calm rule still waits out a box" ~rule:short_calm
        ([ calm; box ] @ repeat calm 5)
        "done" "done at beat 3";
      case "a warp rule waits for the fade"
        ~rule:{ default with warp = true }
        (repeat quiet 8 @ [ black ] @ repeat quiet 8)
        "done" "done at beat 14";
      case "a banner is the warp too"
        ~rule:{ default with warp = true }
        (banner :: repeat quiet 8) "done" "done at beat 6";
      case "no quiet ends a talk before a battle"
        ~rule:{ default with end_on_quiet = false }
        (repeat quiet 30) "done" "never done (no fade or banner)";
      case "a battle"
        ~rule:{ default with end_on_quiet = false }
        (repeat quiet 6 @ [ battle ])
        "battle" "battle at beat 6";
      (* Quiet, then the scene's closing fade: the scene must not end at the
         fade's start, or the next step's input lands in the fade. *)
      case "a closing fade starts the quiet over"
        (repeat quiet 4 @ repeat faded 3 @ repeat quiet 8)
        "done" "done at beat 12";
      case "a fade still down never ends it"
        (repeat quiet 3 @ repeat faded 20)
        "done" "never done (black fade still down)";
      case "a fade is never calm"
        (repeat calm 10 @ repeat calm_faded 10)
        "done" "never done (black fade still down)";
      case "people walking about do not hold up a player-still quiet"
        ~rule:player_still (repeat people_walking 8) "done" "done at beat 5";
      case "the player moving holds up a player-still quiet" ~rule:player_still
        (repeat player_moving 3 @ repeat people_walking 8)
        "done" "done at beat 8";
      case "people walking about hold up a whole-screen quiet until calm"
        (repeat people_walking 20) "done" "done at beat 15";
    ]
