type open_leg_press = Step_taps | Timed_hold
type tile_time = { across_ms : int; up_down_ms : int }

let along time direction =
  if Direction.is_across direction then time.across_ms else time.up_down_ms

type step_tap = { hold_ms : int; release_ms : int }
type gait = { tile : tile_time; tap : step_tap; open_legs : open_leg_press }

type t = {
  turn_tap_ms : int;
  start_delay_ms : int;
  walk : gait;
  run : gait;
  bike : gait option;
}

(* The measurements: AutoStory's BDSP RouteInput/RouteTiming and FRLG
   MovementMechanics/BikeSpinMechanics headers on the Arduino-Source fork. *)

let bdsp_tap = { hold_ms = 160; release_ms = 640 }

let bdsp =
  {
    turn_tap_ms = 50;
    start_delay_ms = 250;
    walk =
      {
        tile = { across_ms = 160; up_down_ms = 240 };
        tap = bdsp_tap;
        open_legs = Step_taps;
      };
    run =
      {
        tile = { across_ms = 100; up_down_ms = 150 };
        tap = bdsp_tap;
        open_legs = Step_taps;
      };
    bike = None;
  }

let frlg_foot_tap = { hold_ms = 66; release_ms = 700 }

let frlg =
  {
    turn_tap_ms = 40;
    start_delay_ms = 0;
    walk =
      {
        tile = { across_ms = 267; up_down_ms = 267 };
        tap = frlg_foot_tap;
        open_legs = Timed_hold;
      };
    run =
      {
        tile = { across_ms = 133; up_down_ms = 133 };
        tap = frlg_foot_tap;
        open_legs = Timed_hold;
      };
    bike =
      Some
        {
          tile = { across_ms = 100; up_down_ms = 100 };
          tap = { hold_ms = 40; release_ms = 60 };
          open_legs = Step_taps;
        };
  }
