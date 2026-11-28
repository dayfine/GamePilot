(* Rng_timings: prepare_timings' formula for the Sweet Scent target, worked by
   hand from PokemonFRLG_RngCalibration.cpp for the Switch, and the mGBA run
   that hit a shiny Ekans on Route 10 (press 30740 ms after reset, advance
   1555: a 3348 ms continue screen and a 19622 ms in-game wait). *)

open Frlg_rng

let text = function
  | Ok (t : Rng_timings.t) ->
      Printf.sprintf "seed %d csf %d teachy %d ingame %d" t.seed_delay_ms
        t.csf_delay_ms t.teachy_delay_ms t.ingame_delay_ms
  | Error why -> "error: " ^ why

let case name model ~seed ~advances ?(teachy = false)
    ?(calibrations = Rng_timings.no_calibrations) expectation =
  {
    Table_test.name;
    input =
      (fun () ->
        text
          (Rng_timings.sweet_scent model ~seed_delay_ms:seed ~advances
             ~use_teachy_tv:teachy calibrations));
    expectation;
  }

let static_case name model ~seed ~advances ?(teachy = false)
    ?(calibrations = Rng_timings.no_calibrations) expectation =
  {
    Table_test.name;
    input =
      (fun () ->
        text
          (Rng_timings.static model ~seed_delay_ms:seed ~advances
             ~use_teachy_tv:teachy calibrations));
    expectation;
  }

let () =
  Table_test.run "rng_timings"
    [
      (* (1555 - 200 - 352) * 16.6667 / 2 = 8358; 50920 - 845; 200 frames. *)
      case "switch, no calibration" Rng_timings.switch ~seed:50920
        ~advances:1555 "seed 50075 csf 3333 teachy 0 ingame 8358";
      (* +3 seed frames, -4 CSF frames, +10 advances. *)
      case "switch, calibrated" Rng_timings.switch ~seed:50920 ~advances:1555
        ~calibrations:{ seed_offset = 3; csf_offset = -4; ingame_offset = 10 }
        "seed 50125 csf 3266 teachy 0 ingame 8441";
      (* 29448 advances: floor((29448 - 12000 + 7500) / 313) * 313 = 24727 on
         Teachy TV, (29448 - 24727) * 16.6667 / 2 - 14067 in game. *)
      case "switch, Teachy TV" Rng_timings.switch ~seed:50920 ~advances:30000
        ~teachy:true "seed 50075 csf 3333 teachy 1316 ingame 25274";
      case "teachy TV unused under its buffer" Rng_timings.switch ~seed:50920
        ~advances:1555 ~teachy:true "seed 50075 csf 3333 teachy 0 ingame 8358";
      case "mgba, the shiny Ekans run" Rng_timings.mgba ~seed:30740
        ~advances:1555 "seed 30740 csf 3348 teachy 0 ingame 19622";
      case "too few advances for Sweet Scent's presses" Rng_timings.mgba
        ~seed:30740 ~advances:700
        "error: The in-game delay is too short for the Sweet Scent presses.";
      case "seed before the title screen" Rng_timings.mgba ~seed:20000
        ~advances:1555
        "error: The title screen delay cannot be less than 30s. Check your \
         seed delay and calibration.";
      case "negative advances" Rng_timings.switch ~seed:50920 ~advances:300
        "error: In-game advances cannot be negative. Check your in-game \
         advances and calibration.";
      (* Static encounter: (1555 - 200 + 160) * 16.6667 / 2 = 12625 on Switch. *)
      static_case "static, switch, no calibration" Rng_timings.switch
        ~seed:50920 ~advances:1555 "seed 50075 csf 3333 teachy 0 ingame 12625";
      (* Static encounter calibrated: +3 seed frames, -4 CSF, +10 advances. *)
      static_case "static, switch, calibrated" Rng_timings.switch ~seed:50920
        ~advances:1555
        ~calibrations:{ seed_offset = 3; csf_offset = -4; ingame_offset = 10 }
        "seed 50125 csf 3266 teachy 0 ingame 12708";
      (* Static encounter on mGBA: (1555 - 200 + 0) * 1000 / 59.7275 = 22686. *)
      static_case "static, mgba" Rng_timings.mgba ~seed:30740 ~advances:1555
        "seed 30740 csf 3348 teachy 0 ingame 22686";
      (* Static encounter allows ingame_delay_ms = 5000 (min_wait = 0). *)
      static_case "static, switch at 5000 ms floor" Rng_timings.switch
        ~seed:50920 ~advances:640 "seed 50075 csf 3333 teachy 0 ingame 5000";
      static_case "static, too few advances" Rng_timings.switch ~seed:50920
        ~advances:600
        "error: The in-game delay is too short for the static encounter \
         presses.";
    ]
