module EBR = Bdsp_readers.Eye_blink_reader
module BM = Bdsp_rng.Blink_model
module SE = Bdsp_rng.Static_encounter
module ST = Bdsp_rng.Static_targets
module STL = Bdsp_rng.Static_timeline
module XS = Bdsp_rng.Xorshift128
module ICR = Bdsp_blink_rng.In_chamber_reidentifier
module SRT = Bdsp_blink_rng.Static_rng_trigger

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label

let assert_float_near label ~eps ~got ~want =
  if Float.abs (got -. want) > eps then fail label

let full_pic : Wire.box = { x = 0.0; y = 0.0; w = 1.0; h = 1.0 }
let player_probe_id = "bdsp_eye_player"

let player_target : EBR.target =
  {
    id = player_probe_id;
    box = { x = 0.45; y = 0.40; w = 0.05; h = 0.05 };
    template = "player_eye_hash";
  }

(* Synthesizes a 30 fps player eye NCC stream from a 1PK scene starting at
   [start_advance] from [base_state], returning the frame array, ground-truth
   (first_adv, last_adv, next_pk_s), and a gap injected inside the double-blink
   window of blink #3 to test gap handling. *)
let synthesize_1pk_frames ~base_state ~start_advance ~true_period ~first_pk_s
    ~origin_t_ms =
  let rng = XS.create base_state in
  XS.advance rng start_advance;
  let events =
    STL.simulate_from_phase (XS.state rng) ~tick_seconds:true_period
      ~first_player_tick_seconds:0.0 ~first_pokemon_blink_seconds:first_pk_s
      ~duration_seconds:200.0
    |> Result.get_ok
  in
  let player_blinks =
    List.filter_map
      (fun (ev : STL.event) ->
        match ev.actor with
        | STL.Npc 0 when BM.npc_blinks ev.roll -> Some ev
        | _ -> None)
      events
  in
  let dips =
    List.concat_map
      (fun (ev : STL.event) ->
        match BM.npc_blink_type ev.roll with
        | BM.Single -> [ ev.time_seconds ]
        | BM.Double -> [ ev.time_seconds; ev.time_seconds +. 0.28 ])
      player_blinks
    |> Array.of_list
  in
  let fps = 30.0 in
  let frame_dt = 1.0 /. fps in
  let total_frames = int_of_float (ceil (200.0 /. frame_dt)) in
  let cursor = ref 0 in
  let score_at t =
    while !cursor + 1 < Array.length dips && dips.(!cursor) +. 0.12 < t do
      incr cursor
    done;
    let dist = Float.abs (t -. dips.(!cursor)) in
    if dist <= 0.035 then 0.35 else if dist <= 0.065 then 0.60 else 0.90
  in
  let frames =
    Array.init total_frames (fun i ->
        let t_s = float_of_int i *. frame_dt in
        let t_ms = origin_t_ms +. (t_s *. 1000.0) in
        {
          Wire.seq = i + 1;
          t_ms;
          probes =
            [
              ( player_probe_id,
                Wire.Template_ncc { score = score_at t_s; x = 0.46; y = 0.41 }
              );
            ];
        })
  in
  (* Inject a gap shortly after the 3rd player blink to exercise unknown/untyped
     gap handling without breaking unique 1PK identification. *)
  let third = List.nth player_blinks 2 in
  let gap_t_ms = origin_t_ms +. ((third.time_seconds +. 0.25) *. 1000.0) in
  let gap_seq = int_of_float ((third.time_seconds +. 0.25) *. fps) in
  let injected_gap : Wire.gap =
    {
      from_seq = gap_seq;
      to_seq = gap_seq + 3;
      from_t_ms = gap_t_ms;
      to_t_ms = gap_t_ms +. 100.0;
    }
  in
  (frames, player_blinks, injected_gap)

type recorded_action =
  | Submitted of Wire.command list
  | Submitted_at of float * Wire.command list

type script_stats = {
  mutable renew_lease_calls : int;
  mutable actions : recorded_action list;
}

let run_with_frames ~frames ~injected_gaps ~start_t_ms f =
  let idx = ref 0 in
  let current_t_ms = ref start_t_ms in
  let pending_gaps = ref [] in
  let remaining_gaps = ref injected_gaps in
  let stats = { renew_lease_calls = 0; actions = [] } in
  let deliver_gaps seq =
    let due, later =
      List.partition (fun (g : Wire.gap) -> g.to_seq <= seq) !remaining_gaps
    in
    remaining_gaps := later;
    if due <> [] then pending_gaps := !pending_gaps @ due
  in
  let rec step_await ~deadline_ms pred =
    if !idx >= Array.length frames then (
      current_t_ms := deadline_ms;
      let synthetic : Wire.frame =
        { seq = !idx + 1; t_ms = !current_t_ms; probes = [] }
      in
      incr idx;
      if pred synthetic then Effects.Holds synthetic else Effects.Timeout)
    else
      let (frame : Wire.frame) = frames.(!idx) in
      incr idx;
      current_t_ms := frame.t_ms;
      deliver_gaps frame.seq;
      if pred frame then Effects.Holds frame
      else if frame.t_ms >= deadline_ms then Effects.Timeout
      else step_await ~deadline_ms pred
  in
  let effc : type a. a Effect.t -> ((a, _) Effect.Deep.continuation -> _) option
      = function
    | Effects.Subscribe specs ->
        Some
          (fun k ->
            Effect.Deep.continue k
              (List.map (fun (s : Wire.probe_spec) -> s.id) specs))
    | Effects.Unsubscribe ids -> Some (fun k -> Effect.Deep.continue k ids)
    | Effects.Now -> Some (fun k -> Effect.Deep.continue k !current_t_ms)
    | Effects.Read -> Some (fun k -> Effect.Deep.continue k None)
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
    | Effects.Submit cmds ->
        Some
          (fun k ->
            stats.actions <- stats.actions @ [ Submitted cmds ];
            Effect.Deep.continue k
              { Wire.batch_id = "sub"; seq = !idx; t_ms = !current_t_ms })
    | Effects.Submit_at (t_ms, cmds) ->
        Some
          (fun k ->
            stats.actions <- stats.actions @ [ Submitted_at (t_ms, cmds) ];
            current_t_ms := Float.max !current_t_ms t_ms;
            Effect.Deep.continue k
              { Wire.batch_id = "sub_at"; seq = !idx; t_ms })
    | _ -> None
  in
  let res = Effect.Deep.try_with f () { effc } in
  (res, stats)

let is_press_a = function
  | [ Wire.Press { buttons = [ Wire.A ]; _ } ] -> true
  | _ -> false

let test_end_to_end_legendary ~target_id ~base_state ~start_advance ~true_period
    ~first_pk_s =
  let target =
    match ST.find target_id with
    | Some t -> t
    | None -> fail ("missing target " ^ target_id)
  in
  let origin_t_ms = 5000.0 in
  let frames, player_blinks, injected_gap =
    synthesize_1pk_frames ~base_state ~start_advance ~true_period ~first_pk_s
      ~origin_t_ms
  in
  let reid_cfg =
    {
      (ICR.default_config ~picture:full_pic ~target:player_target ~base_state) with
      bounds =
        {
          ICR.default_bounds with
          search_min = 0;
          search_max = 10_000;
          min_blinks = 10;
          max_blinks = 18;
        };
    }
  in
  let anchor_res, reid_stats =
    run_with_frames ~frames ~injected_gaps:[ injected_gap ]
      ~start_t_ms:origin_t_ms (fun () -> ICR.run reid_cfg)
  in
  let anchor =
    match anchor_res with
    | Ok a -> a
    | Error msg -> fail (target_id ^ " 1PK re-ID failed: " ^ msg)
  in
  let expected_first = start_advance + (List.hd player_blinks).advance in
  assert_true
    (target_id ^ " locked exact first advance")
    (anchor.advances_to_first_blink = expected_first);
  assert_true
    (target_id ^ " locked exact last advance (> first)")
    (anchor.advances_to_last_blink > anchor.advances_to_first_blink);
  assert_true
    (target_id ^ " re-ID sent zero button presses")
    (reid_stats.actions = []);
  assert_true
    (target_id ^ " re-ID renewed lease during watch")
    (reid_stats.renew_lease_calls >= 1);
  assert_true
    (target_id ^ " re-ID recorded injected gap")
    (List.length anchor.gaps >= 1);

  (* Now trigger the shiny encounter from the locked 1PK anchor. *)
  let trig_cfg =
    {
      (SRT.default_config ~target ~accept:(fun p -> p.SE.shiny <> SE.Not_shiny)) with
      search =
        {
          tsv = 0;
          synchronize_nature = None;
          min_wait_advances = 200;
          max_wait_advances = 12_000;
          accept = (fun p -> p.SE.shiny <> SE.Not_shiny);
        };
    }
  in
  let expected_plan =
    match SRT.plan trig_cfg anchor with
    | Ok p -> p
    | Error msg -> fail (target_id ^ " plan failed: " ^ msg)
  in
  let trig_res, trig_stats =
    run_with_frames ~frames:[||] ~injected_gaps:[]
      ~start_t_ms:anchor.anchor_time_ms (fun () -> SRT.run trig_cfg anchor)
  in
  match trig_res with
  | Error msg -> fail (target_id ^ " trigger failed: " ^ msg)
  | Ok out -> (
      let gen_rng = XS.create base_state in
      XS.advance gen_rng out.plan.hit.advances;
      let generated =
        SE.generate (XS.state gen_rng) target.template ~tsv:0
          ~synchronize_nature:None
      in
      assert_true (target_id ^ " hit is shiny") (generated.shiny <> SE.Not_shiny);
      assert_true
        (target_id ^ " span matches hit")
        (out.plan.timeline_start_advance + out.plan.schedule.span
        = out.plan.hit.advances);
      assert_true
        (target_id ^ " renewed lease during wait")
        (trig_stats.renew_lease_calls >= 2);
      match trig_stats.actions with
      | [ Submitted open_cmds; Submitted_at (t_ms, confirm_cmds) ] ->
          assert_true
            (target_id ^ " opened cry dialog with A")
            (is_press_a open_cmds);
          assert_true
            (target_id ^ " confirmed encounter with A")
            (is_press_a confirm_cmds);
          assert_float_near
            (target_id ^ " submit_at exact confirm_t_ms")
            ~eps:1e-6 ~got:t_ms ~want:expected_plan.confirm_t_ms
      | _ -> fail (target_id ^ " expected [Submit A; Submit_at confirm_t_ms A]")
      )

let () =
  test_end_to_end_legendary ~target_id:"kyogre"
    ~base_state:
      { s0 = 0x1122_3344; s1 = 0x5566_7788; s2 = 0x99aa_bbcc; s3 = 0xddee_ff01 }
    ~start_advance:2400 ~true_period:1.0197 ~first_pk_s:4.3;
  test_end_to_end_legendary ~target_id:"groudon"
    ~base_state:
      { s0 = 0x2468_ace0; s1 = 0x1357_9bdf; s2 = 0xfedc_ba98; s3 = 0x7654_3210 }
    ~start_advance:3100 ~true_period:1.0170 ~first_pk_s:6.1;
  print_endline "OK"
