(* Each game's measured movement is usable: taps take time, a turn tap is
   shorter than a step tap, each faster gait is faster on both axes, and
   open legs on foot are pressed as the game needs. Ported from
   Pokemon_MoveMechanics_Tests.cpp. *)

open Grid_maps
open Move_mechanics

type case = {
  name : string;
  input : Move_mechanics.t;
  expectation : open_leg_press;
}

let cases =
  [
    { name = "BDSP"; input = bdsp; expectation = Step_taps };
    { name = "FRLG"; input = frlg; expectation = Timed_hold };
  ]

let fails condition message () = if condition then Error message else Ok ()

let empty_tap name gait =
  fails
    (gait.tap.hold_ms <= 0 || gait.tap.release_ms <= 0)
    (Printf.sprintf "the %s step tap is %d ms pressed, %d ms released" name
       gait.tap.hold_ms gait.tap.release_ms)

let turn_steps name gait turn_tap_ms =
  fails
    (turn_tap_ms >= gait.tap.hold_ms)
    (Printf.sprintf
       "the turn tap (%d ms) is not shorter than the %s step tap (%d ms)"
       turn_tap_ms name gait.tap.hold_ms)

let not_faster faster_name faster slower_name slower =
  fails
    (faster.tile.across_ms >= slower.tile.across_ms
    || faster.tile.up_down_ms >= slower.tile.up_down_ms)
    (Printf.sprintf "%s is not faster than %s on both axes" faster_name
       slower_name)

let press_name = function
  | Step_taps -> "step taps"
  | Timed_hold -> "a timed hold"

let wrong_open_legs name gait expected =
  fails
    (gait.open_legs <> expected)
    (Printf.sprintf "open legs %s are pressed as %s, expected %s" name
       (press_name gait.open_legs)
       (press_name expected))

let bike_checks game =
  match game.bike with
  | None -> []
  | Some bike ->
      [ empty_tap "bike" bike; not_faster "the bike" bike "running" game.run ]

let run_case { name; input = game; expectation } =
  Check.report name
    (Check.all
       ([
          empty_tap "walking" game.walk;
          empty_tap "running" game.run;
          turn_steps "walking" game.walk game.turn_tap_ms;
          turn_steps "running" game.run game.turn_tap_ms;
          not_faster "running" game.run "walking" game.walk;
          wrong_open_legs "walking" game.walk expectation;
          wrong_open_legs "running" game.run expectation;
        ]
       @ bike_checks game))

let () =
  List.iter run_case cases;
  Check.finish ()
