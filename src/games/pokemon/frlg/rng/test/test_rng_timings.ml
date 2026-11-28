(* Rng_timings: prepare_timings' formula for the Sweet Scent target, worked by
   hand from PokemonFRLG_RngCalibration.cpp for the Switch, and the mGBA run
   that hit a shiny Ekans on Route 10 (press 30740 ms after reset, advance
   1555: a 3348 ms continue screen and a 19622 ms in-game wait). *)

open Frlg_rng

let text = function
  | Ok (t : Rng_timings.t) ->
      Printf.sprintf "seed %d csf %d recap %d teachy %d ingame %d total %d"
        t.seed_delay_ms t.csf_delay_ms t.recap_delay_ms t.teachy_delay_ms
        t.ingame_delay_ms
        (Rng_timings.total_delay_ms t)
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

let gift_case name model ~seed ~advances ?(teachy = false)
    ?(calibrations = Rng_timings.no_calibrations) expectation =
  {
    Table_test.name;
    input =
      (fun () ->
        text
          (Rng_timings.gift model ~seed_delay_ms:seed ~advances
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
        ~advances:1555
        "seed 50075 csf 3333 recap 1450 teachy 0 ingame 8358 total 61766";
      (* +3 seed frames, -4 CSF frames (shifts recap, not csf), +10 advances. *)
      case "switch, calibrated" Rng_timings.switch ~seed:50920 ~advances:1555
        ~calibrations:{ seed_offset = 3; csf_offset = -4; ingame_offset = 10 }
        "seed 50125 csf 3333 recap 1383 teachy 0 ingame 8441 total 61832";
      (* Odd vs even target parity on Switch (2 adv/frame in-game): csf_offset=1
         shifts recap_delay_ms by +1 frame (+17 ms) while preserving
         seed_delay_ms and csf_delay_ms. *)
      case "switch, even target parity (csf_offset = 0)" Rng_timings.switch
        ~seed:50920 ~advances:1554
        "seed 50075 csf 3333 recap 1450 teachy 0 ingame 8350 total 61758";
      case "switch, odd target parity (csf_offset = 1)" Rng_timings.switch
        ~seed:50920 ~advances:1554
        ~calibrations:{ Rng_timings.no_calibrations with csf_offset = 1 }
        "seed 50075 csf 3333 recap 1467 teachy 0 ingame 8350 total 61775";
      gift_case "switch gift, odd parity (csf_offset = 1) shifts recap only"
        Rng_timings.switch ~seed:50920 ~advances:1554
        ~calibrations:{ Rng_timings.no_calibrations with csf_offset = 1 }
        "seed 50075 csf 3333 recap 1467 teachy 0 ingame 11283 total 64708";
      (* Console B Switch runs (TID 15287, SID 51290, 59.999977 fps):
         1. Static Electrode #1 odd target 5217/1015 (FR_Eng delay 30754 ms;
            observed indoor Power Plant parity lock at even advances 1014/1016):
            csf_offset = 1 shifts recap_delay_ms from 1450 to 1467 (+17 ms) and
            total_delay_ms by +17 ms while seed_delay_ms and csf_delay_ms stay
            identical. *)
      gift_case "console B static Electrode #1 odd 5217/1015 (csf_offset = 0)"
        Rng_timings.switch ~seed:30754 ~advances:1015
        "seed 29909 csf 3333 recap 1450 teachy 0 ingame 6791 total 40033";
      gift_case "console B static Electrode #1 odd 5217/1015 (csf_offset = 1)"
        Rng_timings.switch ~seed:30754 ~advances:1015
        ~calibrations:{ Rng_timings.no_calibrations with csf_offset = 1 }
        "seed 29909 csf 3333 recap 1467 teachy 0 ingame 6791 total 40050";
      (* 2. Static Electrode #1 even target A91A/1040 (FR_Eng delay 30620 ms;
            caught on attempt 2/25 on Console B). *)
      gift_case "console B static Electrode #1 even A91A/1040 (csf_offset = 0)"
        Rng_timings.switch ~seed:30620 ~advances:1040
        "seed 29775 csf 3333 recap 1450 teachy 0 ingame 7000 total 40108";
      (* 3. Wild Electabuzz target 4ADF/1732 (FR_Eng delay 35187 ms; caught on
            attempt 2/25 on Console B via Sweet Scent). *)
      case "console B wild Electabuzz 4ADF/1732 (csf_offset = 0)"
        Rng_timings.switch ~seed:35187 ~advances:1732
        "seed 34342 csf 3333 recap 1450 teachy 0 ingame 9833 total 47508";
      case "console B wild Electabuzz 4ADF/1732 (csf_offset = 1)"
        Rng_timings.switch ~seed:35187 ~advances:1732
        ~calibrations:{ Rng_timings.no_calibrations with csf_offset = 1 }
        "seed 34342 csf 3333 recap 1467 teachy 0 ingame 9833 total 47525";
      (* 29448 advances: floor((29448 - 12000 + 7500) / 313) * 313 = 24727 on
         Teachy TV, (29448 - 24727) * 16.6667 / 2 - 14067 in game. *)
      case "switch, Teachy TV" Rng_timings.switch ~seed:50920 ~advances:30000
        ~teachy:true
        "seed 50075 csf 3333 recap 1450 teachy 1316 ingame 25274 total 79998";
      case "teachy TV unused under its buffer" Rng_timings.switch ~seed:50920
        ~advances:1555 ~teachy:true
        "seed 50075 csf 3333 recap 1450 teachy 0 ingame 8358 total 61766";
      case "mgba, the shiny Ekans run" Rng_timings.mgba ~seed:30740
        ~advances:1555
        "seed 30740 csf 3348 recap 1450 teachy 0 ingame 19622 total 53710";
      case "too few advances for Sweet Scent's presses" Rng_timings.mgba
        ~seed:30740 ~advances:700
        "error: The in-game delay is too short for the Sweet Scent presses.";
      case "seed before the title screen" Rng_timings.mgba ~seed:20000
        ~advances:1555
        "error: The title screen delay cannot be less than 30s. Check your \
         seed delay and calibration.";
      case "recap delay too short" Rng_timings.switch ~seed:50920 ~advances:1555
        ~calibrations:{ Rng_timings.no_calibrations with csf_offset = -70 }
        "error: The Recap delay cannot be less than 300ms. Check your Continue \
         Screen calibration.";
      case "negative advances" Rng_timings.switch ~seed:50920 ~advances:300
        "error: In-game advances cannot be negative. Check your in-game \
         advances and calibration.";
      (* Static encounter: (1555 - 200 + 160) * 16.6667 / 2 = 12625 on Switch. *)
      static_case "static, switch, no calibration" Rng_timings.switch
        ~seed:50920 ~advances:1555
        "seed 50075 csf 3333 recap 1450 teachy 0 ingame 12625 total 66033";
      (* Static encounter calibrated: +3 seed frames, -4 CSF (shifts recap, not
         csf), +10 advances. *)
      static_case "static, switch, calibrated" Rng_timings.switch ~seed:50920
        ~advances:1555
        ~calibrations:{ seed_offset = 3; csf_offset = -4; ingame_offset = 10 }
        "seed 50125 csf 3333 recap 1383 teachy 0 ingame 12708 total 66099";
      (* Static encounter on mGBA: (1555 - 200 + 0) * 1000 / 59.7275 = 22686. *)
      static_case "static, mgba" Rng_timings.mgba ~seed:30740 ~advances:1555
        "seed 30740 csf 3348 recap 1450 teachy 0 ingame 22686 total 56774";
      (* Static encounter allows ingame_delay_ms = 5000 (min_wait = 0). *)
      static_case "static, switch at 5000 ms floor" Rng_timings.switch
        ~seed:50920 ~advances:640
        "seed 50075 csf 3333 recap 1450 teachy 0 ingame 5000 total 58408";
      static_case "static, too few advances" Rng_timings.switch ~seed:50920
        ~advances:600
        "error: The in-game delay is too short for the static encounter \
         presses.";
    ]
