(* Scripted effect-handler tests for Bdsp_actions.Shiny_encounter_detector.

   The fake effect handler stands in for the live daemon: it records subscribed
   and unsubscribed probe ids and feeds a scripted list of synthetic frames to
   Effects.await until the predicate holds or the list ends (Timeout). *)

module R = Bdsp_readers.Shiny_encounter_reader
module D = Bdsp_actions.Shiny_encounter_detector

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let full_pic : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let color_stat ~r ~g ~b ~sd : Wire.probe_result =
  Wire.Color_stats { mean = { r; g; b }; stddev = { r = sd; g = sd; b = sd } }

let white_stat = color_stat ~r:245. ~g:245. ~b:245. ~sd:2.
let border_stat = color_stat ~r:120. ~g:120. ~b:120. ~sd:25.
let dark_stat = color_stat ~r:20. ~g:20. ~b:20. ~sd:3.
let fight_stat = color_stat ~r:216. ~g:92. ~b:90. ~sd:20.
let run_stat = color_stat ~r:76. ~g:144. ~b:180. ~sd:20.

let frame ~seq ~t_ms ~battle_menu ~dialog_on : Wire.frame =
  let menu_probes =
    if battle_menu then
      [
        ("bdsp_battle_menu_fight", fight_stat);
        ("bdsp_battle_menu_run", run_stat);
      ]
    else
      [
        ("bdsp_battle_menu_fight", dark_stat);
        ("bdsp_battle_menu_run", dark_stat);
      ]
  in
  let dialog_probes =
    if dialog_on then
      [
        ("bdsp_bdlg_bot", white_stat);
        ("bdsp_bdlg_lw", white_stat);
        ("bdsp_bdlg_l", border_stat);
        ("bdsp_bdlg_r", border_stat);
      ]
    else
      [
        ("bdsp_bdlg_bot", dark_stat);
        ("bdsp_bdlg_lw", dark_stat);
        ("bdsp_bdlg_l", dark_stat);
        ("bdsp_bdlg_r", dark_stat);
      ]
  in
  { seq; t_ms; probes = menu_probes @ dialog_probes }

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

let check_reading label ~expected ~actual =
  if expected <> actual then
    fail
      (Printf.sprintf "%s: expected %s, got %s" label
         (R.format_reading expected)
         (R.format_reading actual))

let test_detect_shiny_weather () =
  let frames =
    [
      frame ~seq:1 ~t_ms:100. ~battle_menu:false ~dialog_on:true;
      frame ~seq:2 ~t_ms:1600. ~battle_menu:false ~dialog_on:false;
      frame ~seq:3 ~t_ms:5600. ~battle_menu:false ~dialog_on:true;
      frame ~seq:4 ~t_ms:6500. ~battle_menu:false ~dialog_on:false;
      frame ~seq:5 ~t_ms:8400. ~battle_menu:false ~dialog_on:true;
      frame ~seq:6 ~t_ms:9800. ~battle_menu:false ~dialog_on:false;
      frame ~seq:7 ~t_ms:10200. ~battle_menu:true ~dialog_on:false;
    ]
  in
  let reading, sub, unsub =
    run_with_frames frames (fun () -> D.detect ~picture:full_pic ())
  in
  let expected : R.reading =
    {
      verdict = Shiny;
      wild_animation_ms = Some 4000.;
      your_animation_ms = Some 1900.;
      phase = Post_entry;
    }
  in
  check_reading "detect shiny weather" ~expected ~actual:reading;
  if sub <> unsub || List.length sub <> 6 then
    fail "expected 6 probes subscribed and cleanly unsubscribed"

let test_detect_timeout () =
  let frames = [ frame ~seq:1 ~t_ms:100. ~battle_menu:false ~dialog_on:true ] in
  let reading, sub, unsub =
    run_with_frames frames (fun () ->
        D.detect ~picture:full_pic ~timeout_ms:5000 ())
  in
  let expected : R.reading =
    {
      verdict = Unknown;
      wild_animation_ms = None;
      your_animation_ms = None;
      phase = Wild_animation;
    }
  in
  check_reading "detect timeout" ~expected ~actual:reading;
  if sub <> unsub then fail "probes must unsubscribe on timeout"

let () =
  test_detect_shiny_weather ();
  test_detect_timeout ();
  print_endline "OK"
