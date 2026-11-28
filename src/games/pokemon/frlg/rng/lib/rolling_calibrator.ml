(* Port of PA/CC's 10-attempt rolling calibration history from
   PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngCalibration.cpp
   (get_seed_calibration_frames, get_advances_calibration, update_history). *)

type sample = { implied_boot_offset_ms : float; implied_ingame_offset : int }
type advance_obs = { used_ingame_offset : int; advance_delta : int }

type estimate = {
  boot_offset_ms : int;
  ingame_offset : int;
  sample_count : int;
}

type t = {
  max_history : int;
  frame_duration_ms : float;
  max_seed_delta : int;
  max_advance_delta : int;
  samples : sample list;
  advance_obs : advance_obs list;
}

type outcome =
  | Accepted of { state : t; estimate : estimate }
  | Rejected_outlier of { seed_delta_frames : int; advance_delta : int }

let max_history_length = 10
let max_seed_delta_frames = 30
let max_advance_delta = 50
let min_parity_lock_samples = 3
let default_frame_duration_ms = Rng_timings.switch.frame_duration_ms

let create ?(max_history = max_history_length)
    ?(frame_duration_ms = default_frame_duration_ms)
    ?(max_seed_delta = max_seed_delta_frames)
    ?(max_advance_delta = max_advance_delta) () =
  {
    max_history = max 1 max_history;
    frame_duration_ms;
    max_seed_delta = max 0 max_seed_delta;
    max_advance_delta = max 0 max_advance_delta;
    samples = [];
    advance_obs = [];
  }

let empty = create ()
let count t = List.length t.samples
let samples t = t.samples
let reset t = { t with samples = []; advance_obs = [] }

let rec take n = function
  | [] -> []
  | _ when n <= 0 -> []
  | x :: xs -> x :: take (n - 1) xs

let opt_max acc v = Some (Option.fold ~none:v ~some:(max v) acc)
let opt_min acc v = Some (Option.fold ~none:v ~some:(min v) acc)

let step_bounds (max_neg, min_pos) o =
  if o.advance_delta = -1 then (opt_max max_neg o.used_ingame_offset, min_pos)
  else (max_neg, opt_min min_pos o.used_ingame_offset)

let bracket_bounds obs = List.fold_left step_bounds (None, None) obs

let parity_locked t =
  let recent = take min_parity_lock_samples t.advance_obs in
  List.length recent = min_parity_lock_samples
  && (not (List.exists (fun o -> o.advance_delta = 0) t.advance_obs))
  && List.for_all (fun o -> abs o.advance_delta = 1) recent
  &&
  match bracket_bounds recent with
  | Some max_neg, Some min_pos -> max_neg < min_pos
  | _ -> false

let sum_samples samples =
  List.fold_left
    (fun (boot_acc, ingame_acc, n) s ->
      ( boot_acc +. s.implied_boot_offset_ms,
        ingame_acc + s.implied_ingame_offset,
        n + 1 ))
    (0.0, 0, 0) samples

let round_int x = int_of_float (Float.round x)

let compute_estimate samples =
  let boot_sum, ingame_sum, sample_count = sum_samples samples in
  let denom = float_of_int sample_count in
  {
    boot_offset_ms = round_int (boot_sum /. denom);
    ingame_offset = round_int (float_of_int ingame_sum /. denom);
    sample_count;
  }

let is_outlier t ~seed_delta_frames ~advance_delta =
  abs seed_delta_frames > t.max_seed_delta
  || abs advance_delta > t.max_advance_delta

let record t ~used_boot_offset_ms ~used_ingame_offset ~seed_delta_frames
    ~advance_delta =
  if is_outlier t ~seed_delta_frames ~advance_delta then
    Rejected_outlier { seed_delta_frames; advance_delta }
  else
    let implied_boot_offset_ms =
      float_of_int used_boot_offset_ms
      -. (float_of_int seed_delta_frames *. t.frame_duration_ms)
    in
    let implied_ingame_offset = used_ingame_offset - advance_delta in
    let sample = { implied_boot_offset_ms; implied_ingame_offset } in
    let obs = { used_ingame_offset; advance_delta } in
    let next_samples = take t.max_history (sample :: t.samples) in
    let next_obs = take t.max_history (obs :: t.advance_obs) in
    let estimate = compute_estimate next_samples in
    Accepted
      {
        state = { t with samples = next_samples; advance_obs = next_obs };
        estimate;
      }
