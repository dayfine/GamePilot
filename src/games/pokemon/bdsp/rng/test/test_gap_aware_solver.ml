(* Synthetic frame-drop and capture-stall tests for W10's 3-state gap-aware
   State_solver, Blink_extraction.find_frame_gaps, and
   Blink_grid.build_samples_with_gaps. *)

open Bdsp_rng

let seed =
  {
    Xorshift128.s0 = 0x51a3_9c11;
    s1 = 0x2084_7e23;
    s2 = 0x99f1_0b45;
    s3 = 0x0c72_4d67;
  }

let period = 1.017
let double_offset = 0.30
let dip_half_width = 0.045

type stall = { start_s : float; stop_s : float }

let in_any_stall stalls t =
  List.exists (fun s -> t >= s.start_s && t <= s.stop_s) stalls

(* Builds a synthetic match_sample stream at [fps] for [ticks] ticks of 1 NPC,
   dropping all frames that fall inside [stalls]. *)
let synthesize_stream ~fps ~ticks ~stalls =
  let tick_list =
    Blink_model.generate_blink_ticks seed ~ticks ~npcs:1 ~slot:0
    |> Result.get_ok |> Array.of_list
  in
  let dips =
    Array.to_list
      (Array.mapi
         (fun tick (b : Blink_model.blink_tick) ->
           let t = 2.0 +. (float_of_int tick *. period) in
           if not b.blinked then []
           else if b.blink_type = Double then [ t; t +. double_offset ]
           else [ t ])
         tick_list)
    |> List.concat
  in
  let dt = 1.0 /. fps in
  let total_s = 2.0 +. (float_of_int ticks *. period) +. 1.0 in
  let n_frames = int_of_float (total_s /. dt) in
  let samples = ref [] in
  for i = 0 to n_frames do
    let t = float_of_int i *. dt in
    if not (in_any_stall stalls t) then
      let dipped =
        List.exists (fun d -> Float.abs (t -. d) <= dip_half_width) dips
      in
      let score = if dipped then 0.50 else 0.95 in
      samples := { Blink_extraction.timestamp = t; score } :: !samples
  done;
  (tick_list, List.rev !samples)

let first_tick_where pred ticks =
  let found = ref None in
  Array.iteri
    (fun idx tick -> if !found = None && pred idx tick then found := Some idx)
    ticks;
  Option.get !found

let solve_pipeline ~use_gaps samples =
  let origin = (List.hd samples).Blink_extraction.timestamp in
  let blinks =
    Blink_extraction.extract_blinks ~origin samples ~threshold:0.20
  in
  let events = Blink_extraction.group_blinks blinks in
  let gaps = Blink_extraction.find_frame_gaps ~origin samples in
  let built =
    if use_gaps then
      Blink_grid.build_samples_with_gaps [ events ] ~gaps:[ gaps ] ~slots:[ 0 ]
        ~period_seconds:period
    else Blink_grid.build_samples [ events ] ~slots:[ 0 ] ~period_seconds:period
  in
  let grid_samples = Result.get_ok built in
  let solved =
    State_solver.solve_state_from_samples grid_samples |> Result.get_ok
  in
  (grid_samples, solved)

(* Expected state at the first blink tick (advance 0 of the grid). *)
let expected_first_blink_state ticks =
  let first_blink =
    first_tick_where (fun _ (b : Blink_model.blink_tick) -> b.blinked) ticks
  in
  let rng = Xorshift128.create seed in
  Xorshift128.advance rng first_blink;
  Xorshift128.state rng

let check_recovered name ~expected_state (r : State_solver.blink_solve_result) =
  Table_test.report name
    (if r.success && r.state = expected_state then Ok ()
     else Error ("expected success with exact state, got: " ^ r.failure_reason))

let check_failed name (r : State_solver.blink_solve_result) =
  Table_test.report name
    (if not r.success then Ok () else Error "expected naive solve to fail")

let test_stalls () =
  let base_ticks, _ = synthesize_stream ~fps:30.0 ~ticks:420 ~stalls:[] in
  let expected_state = expected_first_blink_state base_ticks in
  let double_tick =
    first_tick_where
      (fun idx (b : Blink_model.blink_tick) ->
        idx > 20 && b.blinked && b.blink_type = Double)
      base_ticks
  in
  let double_tick_2 =
    first_tick_where
      (fun idx (b : Blink_model.blink_tick) ->
        idx > double_tick + 10 && b.blinked && b.blink_type = Double)
      base_ticks
  in
  let single_tick =
    first_tick_where
      (fun idx (b : Blink_model.blink_tick) ->
        idx > double_tick_2 + 10 && b.blinked && b.blink_type = Single)
      base_ticks
  in
  let t_of tick = 2.0 +. (float_of_int tick *. period) in
  (* 1. Stall hiding the second dip of a Double blink at 30 fps (including a
     dropped-frame 110ms gap). *)
  let second_dip_stall =
    [
      {
        start_s = t_of double_tick +. double_offset -. 0.055;
        stop_s = t_of double_tick +. double_offset +. 0.055;
      };
    ]
  in
  let _, samples_s2 =
    synthesize_stream ~fps:30.0 ~ticks:420 ~stalls:second_dip_stall
  in
  let _, naive_s2 = solve_pipeline ~use_gaps:false samples_s2 in
  let grid_s2, gap_s2 = solve_pipeline ~use_gaps:true samples_s2 in
  check_failed "naive solver fails when second dip is hidden" naive_s2;
  check_recovered "gap-aware solver recovers when second dip is hidden"
    ~expected_state gap_s2;
  let has_untyped_blink =
    List.exists
      (fun (s : State_solver.blink_sample) ->
        s.observation = State_solver.Blinked None)
      grid_s2
  in
  Table_test.report "second-dip stall downgrades blink to Blinked None"
    (if has_untyped_blink then Ok () else Error "expected Blinked None");

  (* 2. Stall hiding the first dip of a Double blink at 30 fps. *)
  let first_dip_stall =
    [
      {
        start_s = t_of double_tick_2 -. 0.06;
        stop_s = t_of double_tick_2 +. 0.06;
      };
    ]
  in
  let _, samples_s1 =
    synthesize_stream ~fps:30.0 ~ticks:420 ~stalls:first_dip_stall
  in
  let _, naive_s1 = solve_pipeline ~use_gaps:false samples_s1 in
  let _, gap_s1 = solve_pipeline ~use_gaps:true samples_s1 in
  check_failed "naive solver fails when first dip is hidden" naive_s1;
  check_recovered "gap-aware solver recovers when first dip is hidden"
    ~expected_state gap_s1;

  (* 3. Stall hiding an entire Single blink at 30 fps. *)
  let whole_blink_stall =
    [
      { start_s = t_of single_tick -. 0.09; stop_s = t_of single_tick +. 0.09 };
    ]
  in
  let _, samples_whole =
    synthesize_stream ~fps:30.0 ~ticks:420 ~stalls:whole_blink_stall
  in
  let _, naive_whole = solve_pipeline ~use_gaps:false samples_whole in
  let grid_whole, gap_whole = solve_pipeline ~use_gaps:true samples_whole in
  check_failed "naive solver rejects true state when entire blink is hidden"
    naive_whole;
  check_recovered "gap-aware solver recovers when entire blink is hidden"
    ~expected_state gap_whole;
  let has_unknown =
    List.exists
      (fun (s : State_solver.blink_sample) ->
        s.observation = State_solver.Unknown)
      grid_whole
  in
  Table_test.report "entire-blink stall marks unobserved tick Unknown"
    (if has_unknown then Ok () else Error "expected Unknown tick");

  (* 4. All three stalls together at 30 fps + single dropped frame (> 65ms). *)
  let single_drop_30fps =
    {
      start_s = t_of (single_tick + 5) -. 0.01;
      stop_s = t_of (single_tick + 5) +. 0.04;
    }
  in
  let all_stalls =
    single_drop_30fps :: (second_dip_stall @ first_dip_stall @ whole_blink_stall)
  in
  let _, samples_all =
    synthesize_stream ~fps:30.0 ~ticks:450 ~stalls:all_stalls
  in
  let _, gap_all = solve_pipeline ~use_gaps:true samples_all in
  check_recovered "gap-aware solver recovers under combined 30 fps stalls"
    ~expected_state gap_all

let () =
  test_stalls ();
  Table_test.finish ()
