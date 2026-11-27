module EBR = Bdsp_readers.Eye_blink_reader
module BM = Bdsp_rng.Blink_model
module XS = Bdsp_rng.Xorshift128
module MSF = Bdsp_actions.Munchlax_seed_finder

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label
let full_pic : Wire.box = { x = 0.0; y = 0.0; w = 1.0; h = 1.0 }

(* Synthesizes a 30 fps NCC score stream from [seed], with Munchlax's first
   blink at [first_blink_s] and [blink_count] blinks total. Each blink is a
   5-frame dip centred on the exact blink time. *)
let synthesize_munchlax_stream ~seed ~first_blink_s ~blink_count =
  let rng = XS.create seed in
  let rec build_times t remaining acc =
    if remaining <= 0 then List.rev acc
    else
      let dt = BM.pokemon_blink_interval (XS.next rng) in
      build_times (t +. dt) (remaining - 1) (t :: acc)
  in
  let blink_times = Array.of_list (build_times first_blink_s blink_count []) in
  let last_t = blink_times.(Array.length blink_times - 1) +. 2.0 in
  let fps = 30.0 in
  let frame_dt = 1.0 /. fps in
  let total_frames = int_of_float (ceil (last_t /. frame_dt)) in
  let cursor = ref 0 in
  let score_at t =
    while
      !cursor + 1 < Array.length blink_times
      && blink_times.(!cursor) +. 0.25 < t
    do
      incr cursor
    done;
    let dist = Float.abs (t -. blink_times.(!cursor)) in
    if dist <= 0.05 then 0.30 else if dist <= 0.085 then 0.55 else 0.92
  in
  Array.init total_frames (fun i ->
      let t_s = float_of_int i *. frame_dt in
      let t_ms = t_s *. 1000.0 in
      let s = score_at t_s in
      {
        Wire.seq = i + 1;
        t_ms;
        probes =
          [
            ( EBR.munchlax_probe_id,
              Wire.Template_ncc { score = s; x = 0.3828; y = 0.6306 } );
          ];
      })

type handler_stats = {
  mutable renew_lease_calls : int;
  mutable submit_calls : int;
  mutable subscribed_every : bool;
}

(* Runs [f] under a scripted effect handler replaying [frames], injecting
   [injected_gaps] when frame sequence numbers cross their [to_seq]. *)
let run_scripted ~frames ~injected_gaps f =
  let idx = ref 0 in
  let current_t_ms = ref 0.0 in
  let pending_gaps = ref [] in
  let remaining_gaps = ref injected_gaps in
  let stats =
    { renew_lease_calls = 0; submit_calls = 0; subscribed_every = false }
  in
  let deliver_gaps_up_to seq =
    let due, later =
      List.partition (fun (g : Wire.gap) -> g.to_seq <= seq) !remaining_gaps
    in
    remaining_gaps := later;
    if due <> [] then pending_gaps := !pending_gaps @ due
  in
  let rec step_await ~deadline_ms pred =
    if !idx >= Array.length frames then Effects.Timeout
    else
      let (frame : Wire.frame) = frames.(!idx) in
      incr idx;
      current_t_ms := frame.t_ms;
      deliver_gaps_up_to frame.seq;
      if pred frame then Effects.Holds frame
      else if frame.t_ms >= deadline_ms then Effects.Timeout
      else step_await ~deadline_ms pred
  in
  let effc : type a. a Effect.t -> ((a, _) Effect.Deep.continuation -> _) option
      = function
    | Effects.Subscribe specs ->
        Some
          (fun k ->
            stats.subscribed_every <-
              List.for_all
                (fun (s : Wire.probe_spec) -> s.delivery = Wire.Every)
                specs;
            let ids = List.map (fun (s : Wire.probe_spec) -> s.id) specs in
            Effect.Deep.continue k ids)
    | Effects.Unsubscribe ids -> Some (fun k -> Effect.Deep.continue k ids)
    | Effects.Now -> Some (fun k -> Effect.Deep.continue k !current_t_ms)
    | Effects.Read ->
        Some
          (fun k ->
            let m =
              if !idx > 0 && !idx <= Array.length frames then
                Some frames.(!idx - 1)
              else None
            in
            Effect.Deep.continue k m)
    | Effects.Take_gaps ->
        Some
          (fun k ->
            let out = !pending_gaps in
            pending_gaps := [];
            Effect.Deep.continue k out)
    | Effects.Renew_lease _ ->
        Some
          (fun k ->
            stats.renew_lease_calls <- stats.renew_lease_calls + 1;
            Effect.Deep.continue k ())
    | Effects.Await (pred, timeout_ms) ->
        Some
          (fun k ->
            let deadline_ms = !current_t_ms +. float_of_int timeout_ms in
            Effect.Deep.continue k (step_await ~deadline_ms pred))
    | Effects.Submit _ ->
        Some
          (fun k ->
            stats.submit_calls <- stats.submit_calls + 1;
            Effect.Deep.continue k
              { Wire.batch_id = "b"; seq = !idx; t_ms = !current_t_ms })
    | Effects.Submit_at _ ->
        Some
          (fun k ->
            stats.submit_calls <- stats.submit_calls + 1;
            Effect.Deep.continue k
              { Wire.batch_id = "b"; seq = !idx; t_ms = !current_t_ms })
    | Effects.Queue _ ->
        Some
          (fun k ->
            stats.submit_calls <- stats.submit_calls + 1;
            Effect.Deep.continue k ())
    | Effects.Race _ ->
        Some
          (fun k ->
            stats.submit_calls <- stats.submit_calls + 1;
            Effect.Deep.continue k
              (Effects.Finished
                 { Wire.batch_id = "b"; seq = !idx; t_ms = !current_t_ms }))
    | Effects.Race_held _ ->
        Some
          (fun k ->
            stats.submit_calls <- stats.submit_calls + 1;
            Effect.Deep.continue k
              (Effects.Finished
                 { Wire.batch_id = "b"; seq = !idx; t_ms = !current_t_ms }))
    | _ -> None
  in
  let res = Effect.Deep.try_with f () { effc } in
  (res, stats)

let test_recovers_seed_with_gaps_and_lease_renewal () =
  let seed : XS.state =
    { s0 = 0x1234_5678; s1 = 0x9abc_def0; s2 = 0x0fed_cba9; s3 = 0x8765_4321 }
  in
  let frames =
    synthesize_munchlax_stream ~seed ~first_blink_s:2.5 ~blink_count:75
  in
  let gap1 : Wire.gap =
    { from_seq = 1200; to_seq = 1202; from_t_ms = 40_000.0; to_t_ms = 40_066.7 }
  in
  let gap2 : Wire.gap =
    {
      from_seq = 4500;
      to_seq = 4503;
      from_t_ms = 150_000.0;
      to_t_ms = 150_100.0;
    }
  in
  let cfg = MSF.default_config ~picture:full_pic ~template:"munchlax_hash" in
  let res, stats =
    run_scripted ~frames ~injected_gaps:[ gap1; gap2 ] (fun () -> MSF.run cfg)
  in
  match res with
  | Error msg -> fail ("expected seed recovery, got Error: " ^ msg)
  | Ok out ->
      assert_true "subscribed Every probe" stats.subscribed_every;
      assert_true "exact 128-bit seed recovered" (out.state = seed);
      assert_true "solve succeeded" out.solve.success;
      assert_true "waited >180s simulated time" (out.elapsed_seconds > 180.0);
      assert_true "renewed lease periodically (>= 6 calls)"
        (stats.renew_lease_calls >= 6);
      assert_true "zero button presses submitted" (stats.submit_calls = 0);
      assert_true "recorded both injected gaps" (List.length out.gaps = 2);
      let first_gap = List.hd out.gaps in
      assert_true "first gap start_seconds near 40.0"
        (Float.abs (first_gap.start_seconds -. 40.0) < 0.05)

let test_timeout_returns_error () =
  (* Constant open-eye frames with zero blinks: must time out cleanly. *)
  let frames =
    Array.init 900 (fun i ->
        {
          Wire.seq = i + 1;
          t_ms = float_of_int i *. (1000.0 /. 30.0);
          probes =
            [
              ( EBR.munchlax_probe_id,
                Wire.Template_ncc { score = 0.92; x = 0.3828; y = 0.6306 } );
            ];
        })
  in
  let cfg =
    {
      (MSF.default_config ~picture:full_pic ~template:"munchlax_hash") with
      timeout_seconds = 10.0;
    }
  in
  let res, stats =
    run_scripted ~frames ~injected_gaps:[] (fun () -> MSF.run cfg)
  in
  assert_true "zero button presses on timeout" (stats.submit_calls = 0);
  match res with
  | Error _ -> ()
  | Ok _ -> fail "expected Error on timeout with no blinks"

let () =
  test_recovers_seed_with_gaps_and_lease_renewal ();
  test_timeout_returns_error ();
  print_endline "OK"
