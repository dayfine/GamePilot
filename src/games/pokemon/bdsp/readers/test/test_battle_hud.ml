(* Unit tests for Bdsp_readers.Battle_hud.
   Fakes stand in for daemon color_stats probe frames: synthetic Wire.frame
   measurements with controlled RGB means and stddevs for HP bar segments,
   the foe Sleep badge, and screen classification. *)

open Bdsp_readers

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

let cs (r, g, b) (sr, sg, sb) =
  Wire.Color_stats
    { mean = { Wire.r; g; b }; stddev = { Wire.r = sr; g = sg; b = sb } }

let frame probes : Effects.measurements = { Wire.seq = 1; t_ms = 0.; probes }

let hp_bar_probes prefix ~filled ~rgb =
  List.init 10 (fun idx ->
      let id = Printf.sprintf "%s%d" prefix idx in
      let color = if idx < filled then rgb else (35., 35., 38.) in
      (id, cs color (4., 4., 4.)))

let test_hp_ratios () =
  let green_full =
    frame (hp_bar_probes "bdsp_foe_hp_" ~filled:10 ~rgb:(50., 210., 70.))
  in
  assert_eq "foe full green" (Battle_hud.foe_hp_ratio green_full) (Some 1.0);
  let yellow_mid =
    frame (hp_bar_probes "bdsp_foe_hp_" ~filled:4 ~rgb:(235., 200., 40.))
  in
  assert_eq "foe yellow 40%" (Battle_hud.foe_hp_ratio yellow_mid) (Some 0.4);
  let red_low =
    frame (hp_bar_probes "bdsp_ply_hp_" ~filled:1 ~rgb:(225., 55., 45.))
  in
  assert_eq "player red 10%" (Battle_hud.player_hp_ratio red_low) (Some 0.1);
  let empty = frame [] in
  assert_eq "missing foe bar" (Battle_hud.foe_hp_ratio empty) None;
  assert_eq "missing player bar" (Battle_hud.player_hp_ratio empty) None

let test_sleep_badge () =
  let asleep =
    frame [ ("bdsp_foe_slp", cs (121., 174., 225.) (12., 12., 12.)) ]
  in
  assert_eq "foe asleep pill" (Battle_hud.foe_asleep asleep) (Some true);
  let white_hud =
    frame [ ("bdsp_foe_slp", cs (245., 245., 245.) (3., 3., 3.)) ]
  in
  assert_eq "foe awake white plate"
    (Battle_hud.foe_asleep white_hud)
    (Some false);
  let para_yellow =
    frame [ ("bdsp_foe_slp", cs (230., 190., 30.) (8., 8., 8.)) ]
  in
  assert_eq "foe paralyzed not sleep"
    (Battle_hud.foe_asleep para_yellow)
    (Some false);
  assert_eq "missing sleep probe" (Battle_hud.foe_asleep (frame [])) None

let test_screen_classification () =
  let switch_frame =
    frame [ ("bdsp_switch_hdr", cs (60., 190., 180.) (10., 10., 10.)) ]
  in
  assert_eq "forced switch"
    (Battle_hud.classify_screen switch_frame)
    Battle_hud.Forced_switch;
  let black_frame =
    frame [ ("start_game.black", cs (5., 5., 5.) (1., 1., 1.)) ]
  in
  assert_eq "black screen"
    (Battle_hud.classify_screen black_frame)
    Battle_hud.Black;
  let menu_frame =
    frame
      [
        ("bdsp_battle_menu_fight", cs (217., 92., 91.) (20., 20., 20.));
        ("bdsp_battle_menu_run", cs (76., 144., 180.) (20., 20., 20.));
      ]
  in
  assert_eq "action menu"
    (Battle_hud.classify_screen menu_frame)
    Battle_hud.Action_menu;
  assert_eq "other screen"
    (Battle_hud.classify_screen (frame []))
    Battle_hud.Other

let test_probe_list_non_empty () =
  let picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. } in
  assert_eq "hud probes count" (List.length (Battle_hud.probes ~picture)) 22

let () =
  test_hp_ratios ();
  test_sleep_badge ();
  test_screen_classification ();
  test_probe_list_non_empty ();
  print_endline "OK"
