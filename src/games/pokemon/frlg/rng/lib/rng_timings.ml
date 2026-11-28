(* Port of the timing preparation in PokemonFRLG_RngCalibration.cpp for the
   Sweet Scent target, with the frame model as a value. *)

type frame_model = {
  frame_duration_ms : float;
  ingame_advances_per_frame : float;
  fixed_seed_offset_ms : int;
  sweet_scent_advances_offset : int;
  gift_advances_offset : int;
  static_advances_offset : int;
}

let switch_framerate = 59.999977
let gba_framerate = 59.7275
let ms_per_second = 1000.0

let switch =
  {
    frame_duration_ms = ms_per_second /. switch_framerate;
    ingame_advances_per_frame = 2.0;
    fixed_seed_offset_ms = -845;
    sweet_scent_advances_offset = -352;
    gift_advances_offset = 160;
    static_advances_offset = 160;
  }

let mgba =
  {
    frame_duration_ms = ms_per_second /. gba_framerate;
    ingame_advances_per_frame = 1.0;
    fixed_seed_offset_ms = 0;
    sweet_scent_advances_offset = -183;
    gift_advances_offset = 0;
    static_advances_offset = 0;
  }

let continue_screen_frames = 200
let recap_base_delay_ms = 1450
let sweet_scent_fixed_duration_ms = 7400
let gift_fixed_duration_ms = 8200
let static_fixed_duration_ms = 5000

type calibrations = { seed_offset : int; csf_offset : int; ingame_offset : int }

let no_calibrations = { seed_offset = 0; csf_offset = 0; ingame_offset = 0 }

type t = {
  seed_delay_ms : int;
  csf_delay_ms : int;
  recap_delay_ms : int;
  teachy_delay_ms : int;
  ingame_delay_ms : int;
}

let total_delay_ms t =
  t.seed_delay_ms + t.csf_delay_ms
  + (t.recap_delay_ms - recap_base_delay_ms)
  + t.teachy_delay_ms + t.ingame_delay_ms

(* Teachy TV: 313 advances a frame while it plays, kept for a margin of 12000
   advances, and 14067 ms of opening and closing it. *)
let teachy_advances_per_frame = 313.0
let teachy_tv_buffer = 12000.0
let teachy_tv_rounding = 7500.0
let teachy_tv_overhead_ms = 14067.0

(* The minimums of the C++'s timing check (PokemonFRLG_BlindNavigation.cpp). *)
let min_csf_delay_ms = 3200
let min_seed_delay_ms = 29650
let min_press_gap_ms = 300

let teachy_advances ~use_teachy_tv modified =
  if use_teachy_tv && modified > teachy_tv_buffer then
    Float.floor
      ((modified -. teachy_tv_buffer +. teachy_tv_rounding)
      /. teachy_advances_per_frame)
    *. teachy_advances_per_frame
  else 0.0

let checked ~fixed_duration_ms ~min_wait_ms ~label t =
  if t.csf_delay_ms < min_csf_delay_ms then
    Error
      "The Continue Screen delay cannot be less than 3200ms (192 advances). \
       Check your Continue Screen calibration."
  else if t.recap_delay_ms < min_press_gap_ms then
    Error
      "The Recap delay cannot be less than 300ms. Check your Continue Screen \
       calibration."
  else if t.seed_delay_ms < min_seed_delay_ms then
    Error
      "The title screen delay cannot be less than 30s. Check your seed delay \
       and calibration."
  else if t.ingame_delay_ms < fixed_duration_ms + min_wait_ms then
    Error ("The in-game delay is too short for the " ^ label ^ " presses.")
  else Ok t

let compute ~advances_offset ~fixed_duration_ms ~min_wait_ms ~label m
    ~seed_delay_ms ~advances ~use_teachy_tv c =
  let dur = m.frame_duration_ms in
  let modified =
    float_of_int
      (advances - continue_screen_frames + c.ingame_offset + advances_offset)
  in
  let teachy = teachy_advances ~use_teachy_tv modified in
  let seed =
    float_of_int seed_delay_ms
    +. (float_of_int c.seed_offset *. dur)
    +. float_of_int m.fixed_seed_offset_ms
  in
  let csf = float_of_int continue_screen_frames *. dur in
  let recap =
    float_of_int recap_base_delay_ms +. (float_of_int c.csf_offset *. dur)
  in
  let ingame =
    ((modified -. teachy) *. dur /. m.ingame_advances_per_frame)
    -. if teachy > 0.0 then teachy_tv_overhead_ms else 0.0
  in
  if modified < 0.0 then
    Error
      "In-game advances cannot be negative. Check your in-game advances and \
       calibration."
  else if seed < 0.0 || csf < 0.0 || recap < 0.0 || ingame < 0.0 then
    Error "A delay cannot be negative. Check your calibration values."
  else
    checked ~fixed_duration_ms ~min_wait_ms ~label
      {
        seed_delay_ms = int_of_float seed;
        csf_delay_ms = int_of_float csf;
        recap_delay_ms = int_of_float (Float.round recap);
        teachy_delay_ms =
          int_of_float (teachy *. dur /. teachy_advances_per_frame);
        ingame_delay_ms = int_of_float ingame;
      }

let sweet_scent m ~seed_delay_ms ~advances ~use_teachy_tv c =
  compute ~advances_offset:m.sweet_scent_advances_offset
    ~fixed_duration_ms:sweet_scent_fixed_duration_ms
    ~min_wait_ms:min_press_gap_ms ~label:"Sweet Scent" m ~seed_delay_ms
    ~advances ~use_teachy_tv c

let gift m ~seed_delay_ms ~advances ~use_teachy_tv c =
  compute ~advances_offset:m.gift_advances_offset
    ~fixed_duration_ms:gift_fixed_duration_ms ~min_wait_ms:min_press_gap_ms
    ~label:"gift" m ~seed_delay_ms ~advances ~use_teachy_tv c

let static m ~seed_delay_ms ~advances ~use_teachy_tv c =
  compute ~advances_offset:m.static_advances_offset
    ~fixed_duration_ms:static_fixed_duration_ms ~min_wait_ms:0
    ~label:"static encounter" m ~seed_delay_ms ~advances ~use_teachy_tv c
