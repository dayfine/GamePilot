(* Typed unit and scripted Effect.Deep tests for
   Frlg_readers.Shiny_encounter_reader and Shiny_encounter_detector. *)

module R = Frlg_readers.Shiny_encounter_reader
module D = Frlg_readers.Shiny_encounter_detector

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

let cs (r, g, b) (sr, sg, sb) =
  Wire.Color_stats
    { mean = { Wire.r; g; b }; stddev = { Wire.r = sr; g = sg; b = sb } }

let battle_text_probes =
  [
    ("battle.box.top", cs (40., 81., 106.) (2., 2., 2.));
    ("battle.box.right", cs (40., 81., 106.) (2., 2., 2.));
    ("battle.box.line", cs (250., 250., 250.) (2., 2., 2.));
    ("battle.box.gold", cs (197., 156., 46.) (4., 4., 4.));
  ]

let arrow_probe ~shown =
  if shown then
    ( "battle.arrow",
      Wire.Color_count
        { fraction = 0.05; mean = Some { Wire.r = 240.; g = 30.; b = 20. } } )
  else ("battle.arrow", Wire.Color_count { fraction = 0.; mean = None })

let dark_text_probes =
  let d = cs (10., 10., 10.) (1., 1., 1.) in
  [
    ("battle.box.top", d);
    ("battle.box.right", d);
    ("battle.box.line", d);
    ("battle.box.gold", d);
  ]

let frame ~seq ~t_ms ~battle_text ~advance_arrow : Effects.measurements =
  let text = if battle_text then battle_text_probes else dark_text_probes in
  { seq; t_ms; probes = arrow_probe ~shown:advance_arrow :: text }

let run_with_frames frames f =
  let remaining = ref frames in
  let subscribed = ref [] in
  let unsubscribed = ref [] in
  let rec feed pred =
    match !remaining with
    | [] -> Effects.Timeout
    | hd :: tl ->
        remaining := tl;
        if pred hd then Effects.Holds hd else feed pred
  in
  let result =
    Effect.Deep.match_with f ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Effects.Subscribe specs ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    let ids =
                      List.map (fun (p : Wire.probe_spec) -> p.id) specs
                    in
                    subscribed := !subscribed @ ids;
                    Effect.Deep.continue k ids)
            | Effects.Unsubscribe ids ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    unsubscribed := !unsubscribed @ ids;
                    Effect.Deep.continue k ids)
            | Effects.Await (pred, _timeout_ms) ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (feed pred))
            | _ -> None);
      }
  in
  (result, !subscribed, !unsubscribed)

let test_pure_state_machine () =
  (* Shiny: 2800 ms between battle text box and advance arrow. *)
  let s =
    R.init
    |> R.step_signals ~t_ms:500. ~battle_text:true ~foe_box:false
         ~advance_arrow:false ~player_box:false ~battle_menu:false
    |> R.step_signals ~t_ms:3300. ~battle_text:true ~foe_box:true
         ~advance_arrow:true ~player_box:false ~battle_menu:false
  in
  assert_eq "shiny finished" (R.is_finished s) true;
  assert_eq "shiny reading" (R.classify s)
    {
      R.verdict = R.Shiny;
      wild_intro_ms = Some 2800.;
      phase = R.Intro_complete;
    };
  (* Non-shiny: 1500 ms between foe box and player send-out. *)
  let s_norm =
    R.init
    |> R.step_signals ~t_ms:200. ~battle_text:false ~foe_box:true
         ~advance_arrow:false ~player_box:false ~battle_menu:false
    |> R.step_signals ~t_ms:1700. ~battle_text:true ~foe_box:true
         ~advance_arrow:false ~player_box:true ~battle_menu:false
  in
  assert_eq "non-shiny reading" (R.classify s_norm)
    {
      R.verdict = R.Not_shiny;
      wild_intro_ms = Some 1500.;
      phase = R.Intro_complete;
    };
  (* Started late: advance arrow already up on first frame -> Unknown. *)
  let s_late =
    R.init
    |> R.step_signals ~t_ms:100. ~battle_text:true ~foe_box:true
         ~advance_arrow:true ~player_box:false ~battle_menu:false
  in
  assert_eq "late start unknown" (R.classify s_late)
    { R.verdict = R.Unknown; wild_intro_ms = None; phase = R.Intro_complete }

let test_detect_shiny () =
  let frames =
    [
      frame ~seq:1 ~t_ms:100. ~battle_text:false ~advance_arrow:false;
      frame ~seq:2 ~t_ms:400. ~battle_text:true ~advance_arrow:false;
      frame ~seq:3 ~t_ms:1800. ~battle_text:true ~advance_arrow:false;
      frame ~seq:4 ~t_ms:3300. ~battle_text:true ~advance_arrow:true;
    ]
  in
  let reading, sub, unsub = run_with_frames frames (fun () -> D.detect ()) in
  assert_eq "detect shiny reading" reading
    {
      R.verdict = R.Shiny;
      wild_intro_ms = Some 2900.;
      phase = R.Intro_complete;
    };
  assert_eq "probes cleanly unsubscribed" sub unsub;
  assert_eq "probes non-empty" (List.length sub > 0) true

let test_detect_not_shiny () =
  let frames =
    [
      frame ~seq:1 ~t_ms:400. ~battle_text:true ~advance_arrow:false;
      frame ~seq:2 ~t_ms:1900. ~battle_text:true ~advance_arrow:true;
    ]
  in
  let reading, sub, unsub = run_with_frames frames (fun () -> D.detect ()) in
  assert_eq "detect not_shiny reading" reading
    {
      R.verdict = R.Not_shiny;
      wild_intro_ms = Some 1500.;
      phase = R.Intro_complete;
    };
  assert_eq "not_shiny probes unsubscribed" sub unsub

let test_detect_timeout () =
  let frames =
    [ frame ~seq:1 ~t_ms:400. ~battle_text:true ~advance_arrow:false ]
  in
  let reading, sub, unsub =
    run_with_frames frames (fun () -> D.detect ~timeout_ms:5000 ())
  in
  assert_eq "detect timeout reading" reading
    { R.verdict = R.Unknown; wild_intro_ms = None; phase = R.Wild_appearance };
  assert_eq "timeout probes unsubscribed" sub unsub

let () =
  test_pure_state_machine ();
  test_detect_shiny ();
  test_detect_not_shiny ();
  test_detect_timeout ();
  print_endline "OK"
