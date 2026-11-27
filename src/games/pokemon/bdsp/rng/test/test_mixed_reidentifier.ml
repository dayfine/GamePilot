(* 50-seed synthetic simulation tests for 1PK mixed-model timeline simulation,
   re-identification (including tick-period drift, arbitrary initial Pokemon
   blink phases, order-swap branching, frame drops, ambiguous & missing
   matches), and Static_press_schedule. *)

open Bdsp_rng

let lcg state =
  let next = ((state * 1103515245) + 12345) land 0x7fff_ffff in
  next

let seed_of_index i =
  let a = lcg (0x1020_3040 + (i * 9973)) in
  let b = lcg a in
  let c = lcg b in
  let d = lcg c in
  { Xorshift128.s0 = a lor 1; s1 = b; s2 = c; s3 = d }

(* Simulates a 1PK scene from [base_state] starting at [start_advance] with
   arbitrary initial Pokemon blink phase [first_pk_s] and drifted player tick
   period [true_period]. Returns the first [count] player blinks (with
   deterministic jitter) and the ground-truth (first_adv, last_adv,
   next_pk_after_last). *)
let simulate_1pk_session ~base_state ~start_advance ~true_period ~first_pk_s
    ~count ~jitter_seed =
  let rng = Xorshift128.create base_state in
  Xorshift128.advance rng start_advance;
  (* Advance until we hit a player blink to serve as the first observed blink,
     simulating from [start_advance]. *)
  let events =
    Static_timeline.simulate_from_phase (Xorshift128.state rng)
      ~tick_seconds:true_period ~first_player_tick_seconds:0.0
      ~first_pokemon_blink_seconds:first_pk_s ~duration_seconds:240.0
    |> Result.get_ok
  in
  let player_blinks =
    List.filter_map
      (fun (ev : Static_timeline.event) ->
        match ev.actor with
        | Npc 0 when Blink_model.npc_blinks ev.roll -> Some ev
        | _ -> None)
      events
  in
  let chosen = List.filteri (fun i _ -> i < count) player_blinks in
  let first_ev = List.hd chosen in
  let last_ev = List.hd (List.rev chosen) in
  let next_pk_after_last =
    List.find_map
      (fun (ev : Static_timeline.event) ->
        match ev.actor with
        | Pokemon 0 when ev.advance > last_ev.advance ->
            Some (ev.time_seconds -. last_ev.time_seconds)
        | _ -> None)
      events
    |> Option.get
  in
  let jitter_state = ref jitter_seed in
  let observed =
    List.mapi
      (fun i (ev : Static_timeline.event) ->
        jitter_state := lcg !jitter_state;
        let jitter =
          if i = 0 then 0.0
          else (float_of_int (!jitter_state mod 41) -. 20.0) /. 1000.0
        in
        {
          Mixed_reidentifier.seconds =
            ev.time_seconds -. first_ev.time_seconds +. jitter;
          blink_type = Some (Blink_model.npc_blink_type ev.roll);
        })
      chosen
  in
  ( observed,
    start_advance + first_ev.advance,
    start_advance + last_ev.advance,
    next_pk_after_last )

let test_50_seeds_1pk () =
  let failures = ref [] in
  for i = 0 to 49 do
    let base_state = seed_of_index i in
    let start_advance = 500 + (i * 271 mod 12000) in
    (* Vary true player tick period across [1.005, 1.032] s to test drift. *)
    let true_period = 1.005 +. (float_of_int (i mod 28) *. 0.001) in
    (* Vary initial Pokemon phase across (0.05, 12.15] s, including near-swap
       phases close to multiples of true_period. *)
    let first_pk_s =
      if i mod 5 = 0 then (float_of_int ((i mod 8) + 1) *. true_period) +. 0.004
      else 0.15 +. (float_of_int (i * 37 mod 119) *. 0.1)
    in
    let rec try_counts count =
      let blinks, true_first, true_last, true_next_pk =
        simulate_1pk_session ~base_state ~start_advance ~true_period ~first_pk_s
          ~count ~jitter_seed:(1000 + i)
      in
      let res =
        State_reidentifier.reidentify_with_pokemon_models
          {
            base_state;
            search_min = 0;
            search_max = 15000;
            blinks;
            unknown_ticks = [];
            tick_seconds = None;
            order_swap_tolerance =
              Mixed_reidentifier.default_order_swap_tolerance;
          }
      in
      if res.ambiguous && count < 13 then try_counts (count + 1)
      else (res, true_first, true_last, true_next_pk)
    in
    let res, true_first, true_last, true_next_pk = try_counts 10 in
    let pk_window_ok =
      true_next_pk >= res.next_pokemon_blink_min_seconds -. 0.25
      && true_next_pk <= res.next_pokemon_blink_max_seconds +. 0.25
    in
    if
      not
        (res.success
        && res.advances_to_first_blink = true_first
        && res.advances_to_last_blink = true_last
        && pk_window_ok)
    then
      failures :=
        Printf.sprintf
          "seed %d: success=%b first=%d(want %d) last=%d(want %d) \
           pk=[%.2f,%.2f](want %.2f) reason=%s"
          i res.success res.advances_to_first_blink true_first
          res.advances_to_last_blink true_last
          res.next_pokemon_blink_min_seconds res.next_pokemon_blink_max_seconds
          true_next_pk res.failure_reason
        :: !failures
  done;
  Table_test.report
    "50-seed 1PK re-identification (drift + arbitrary phase + swaps)"
    (match !failures with
    | [] -> Ok ()
    | errs -> Error (String.concat "; " (List.rev errs)))

let test_edge_cases () =
  let base_state = seed_of_index 7 in
  let blinks, true_first, true_last, _ =
    simulate_1pk_session ~base_state ~start_advance:2000 ~true_period:1.0197
      ~first_pk_s:4.3 ~count:12 ~jitter_seed:77
  in
  (* Ambiguous match: only 2 blinks over a 10,000-advance range. *)
  let short_blinks = List.filteri (fun i _ -> i < 2) blinks in
  let amb =
    State_reidentifier.reidentify_with_pokemon_models
      {
        base_state;
        search_min = 0;
        search_max = 10000;
        blinks = short_blinks;
        unknown_ticks = [];
        tick_seconds = Some 1.0197;
        order_swap_tolerance = Mixed_reidentifier.default_order_swap_tolerance;
      }
  in
  Table_test.report "1PK ambiguous match with too few blinks"
    (if (not amb.success) && amb.ambiguous && amb.match_count >= 2 then Ok ()
     else Error ("expected ambiguous, got: " ^ amb.failure_reason));

  (* Missing match: flip a blink type so no advance fits. *)
  let corrupted =
    List.mapi
      (fun i (b : Mixed_reidentifier.player_blink) ->
        if i = 5 then
          let flipped =
            match b.blink_type with
            | Some Blink_model.Single -> Some Blink_model.Double
            | Some Blink_model.Double -> Some Blink_model.Single
            | None -> None
          in
          { b with blink_type = flipped }
        else b)
      blinks
  in
  let miss =
    State_reidentifier.reidentify_with_pokemon_models
      {
        base_state;
        search_min = 0;
        search_max = 5000;
        blinks = corrupted;
        unknown_ticks = [];
        tick_seconds = None;
        order_swap_tolerance = Mixed_reidentifier.default_order_swap_tolerance;
      }
  in
  Table_test.report "1PK missing match on corrupted blink"
    (if (not miss.success) && (not miss.ambiguous) && miss.match_count = 0 then
       Ok ()
     else
       Error
         ("expected no match, got match_count=" ^ string_of_int miss.match_count));

  (* Frame drops: drop blink types on 2 blinks and drop 1 entire blink into
     unknown_ticks. *)
  let dropped_blink = List.nth blinks 4 in
  let dropped_tick =
    int_of_float (Float.round (dropped_blink.seconds /. 1.0197))
  in
  let with_drops =
    List.filteri (fun i _ -> i <> 4) blinks
    |> List.mapi (fun i (b : Mixed_reidentifier.player_blink) ->
           if i = 2 || i = 6 then { b with blink_type = None } else b)
  in
  let drop_res =
    State_reidentifier.reidentify_with_pokemon_models
      {
        base_state;
        search_min = 0;
        search_max = 5000;
        blinks = with_drops;
        unknown_ticks = [ dropped_tick ];
        tick_seconds = None;
        order_swap_tolerance = Mixed_reidentifier.default_order_swap_tolerance;
      }
  in
  Table_test.report
    "1PK recovers uniquely with frame-drop untyped & unknown ticks"
    (if
       drop_res.success
       && drop_res.advances_to_first_blink = true_first
       && drop_res.advances_to_last_blink = true_last
     then Ok ()
     else Error ("frame-drop 1PK failed: " ^ drop_res.failure_reason))

let test_static_press_schedule () =
  let base_state = seed_of_index 3 in
  (* DirectNoPokemonModel (Rotom). *)
  let rotom_ctx =
    {
      (Static_timeline.default_context ~npcs:1 ~pokemon_models:0) with
      advance_delay = 2;
      advances_after_accept = 84;
    }
  in
  let direct =
    Static_press_schedule.schedule
      ~trigger_kind:Static_targets.Direct_no_pokemon_model ~context:rotom_ctx
      ~timings:Static_press_schedule.default_timings base_state
    |> Result.get_ok
  in
  Table_test.report "Static_press_schedule DirectNoPokemonModel"
    (if
       direct.span = 86
       && direct.confirm_seconds = 0.0
       && direct.events_before_confirm = 0
     then Ok ()
     else Error "unexpected direct schedule");

  (* TimelineSingleConfirm across 10 seeds. *)
  let ctx =
    {
      (Static_timeline.default_context ~npcs:1 ~pokemon_models:1) with
      white_delay_seconds = 2.0;
      advance_delay = 3;
      advances_after_accept = 84;
    }
  in
  let timings = Static_press_schedule.default_timings in
  let ok_all = ref true in
  for i = 0 to 9 do
    let s = seed_of_index (100 + i) in
    let sched =
      Static_press_schedule.schedule
        ~trigger_kind:Static_targets.Timeline_single_confirm ~context:ctx
        ~timings s
      |> Result.get_ok
    in
    let events =
      Static_timeline.simulate_timeline s ~context:ctx
        ~duration_seconds:(timings.max_wait_seconds +. 15.0)
      |> Result.get_ok
    in
    let before =
      List.filter
        (fun (ev : Static_timeline.event) ->
          ev.time_seconds < sched.confirm_seconds)
        events
    in
    let clear =
      List.for_all
        (fun (ev : Static_timeline.event) ->
          Float.abs (ev.time_seconds -. sched.confirm_seconds)
          >= timings.guard_seconds -. 1e-9)
        events
    in
    if
      not
        (sched.confirm_seconds >= timings.ready_seconds
        && sched.confirm_seconds <= timings.max_wait_seconds
        && sched.gap_margin_seconds >= timings.guard_seconds -. 1e-9
        && clear
        && List.length before = sched.events_before_confirm
        && sched.span
           = ctx.advance_delay + sched.events_before_confirm
             + ctx.advances_after_accept)
    then ok_all := false
  done;
  Table_test.report
    "Static_press_schedule TimelineSingleConfirm respects guard margin"
    (if !ok_all then Ok () else Error "guard margin or span invariant violated")

let () =
  test_50_seeds_1pk ();
  test_edge_cases ();
  test_static_press_schedule ();
  Table_test.finish ()
