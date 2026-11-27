(* Unit tests for Battle_dialog_detector and Shiny_encounter_reader.

   Fakes stand in for daemon color-statistics frames: synthetic frames supply
   only the six battle-menu and battle-dialog probe readings needed to drive
   dialog transitions and battle-menu arrival without a live Switch. *)

open Bdsp_readers
module R = Shiny_encounter_reader

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let check_reading label ~expected ~actual =
  if expected <> actual then
    fail
      (Printf.sprintf "%s: expected %s, got %s" label
         (R.format_reading expected)
         (R.format_reading actual))

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

let run_frames frames =
  List.fold_left (fun s f -> R.step ~frame:f s) R.init frames |> R.classify

let test_probes_layout () =
  let ps = R.probes ~picture:full_pic in
  let expected_ids =
    [
      "bdsp_battle_menu_fight";
      "bdsp_battle_menu_run";
      "bdsp_bdlg_bot";
      "bdsp_bdlg_lw";
      "bdsp_bdlg_l";
      "bdsp_bdlg_r";
    ]
  in
  let actual_ids = List.map (fun (p : Wire.probe_spec) -> p.id) ps in
  if expected_ids <> actual_ids then fail "unexpected probe id list"

let test_non_shiny_standard () =
  let frames =
    [
      frame ~seq:1 ~t_ms:0. ~battle_menu:false ~dialog_on:false;
      frame ~seq:2 ~t_ms:1000. ~battle_menu:false ~dialog_on:true;
      frame ~seq:3 ~t_ms:2500. ~battle_menu:false ~dialog_on:false;
      frame ~seq:4 ~t_ms:4300. ~battle_menu:false ~dialog_on:true;
      frame ~seq:5 ~t_ms:5200. ~battle_menu:false ~dialog_on:false;
      frame ~seq:6 ~t_ms:7000. ~battle_menu:true ~dialog_on:false;
    ]
  in
  let expected : R.reading =
    {
      verdict = Not_shiny;
      wild_animation_ms = Some 1800.;
      your_animation_ms = Some 1800.;
      phase = Your_animation;
    }
  in
  check_reading "non-shiny standard" ~expected ~actual:(run_frames frames)

let test_shiny_standard () =
  let frames =
    [
      frame ~seq:1 ~t_ms:0. ~battle_menu:false ~dialog_on:false;
      frame ~seq:2 ~t_ms:1000. ~battle_menu:false ~dialog_on:true;
      frame ~seq:3 ~t_ms:2500. ~battle_menu:false ~dialog_on:false;
      frame ~seq:4 ~t_ms:6400. ~battle_menu:false ~dialog_on:true;
      frame ~seq:5 ~t_ms:7300. ~battle_menu:false ~dialog_on:false;
      frame ~seq:6 ~t_ms:9100. ~battle_menu:true ~dialog_on:false;
    ]
  in
  let expected : R.reading =
    {
      verdict = Shiny;
      wild_animation_ms = Some 3900.;
      your_animation_ms = Some 1800.;
      phase = Your_animation;
    }
  in
  check_reading "shiny standard" ~expected ~actual:(run_frames frames)

let test_weather_banner_non_shiny () =
  (* Kyogre Drizzle / Groudon Drought: post-entry weather dialog appears after
     player send-out and clears before the battle menu. *)
  let frames =
    [
      frame ~seq:1 ~t_ms:500. ~battle_menu:false ~dialog_on:true;
      frame ~seq:2 ~t_ms:2000. ~battle_menu:false ~dialog_on:false;
      frame ~seq:3 ~t_ms:3900. ~battle_menu:false ~dialog_on:true;
      frame ~seq:4 ~t_ms:4800. ~battle_menu:false ~dialog_on:false;
      frame ~seq:5 ~t_ms:6700. ~battle_menu:false ~dialog_on:true;
      frame ~seq:6 ~t_ms:8200. ~battle_menu:false ~dialog_on:false;
      frame ~seq:7 ~t_ms:9000. ~battle_menu:false ~dialog_on:true;
      frame ~seq:8 ~t_ms:10100. ~battle_menu:false ~dialog_on:false;
      frame ~seq:9 ~t_ms:10500. ~battle_menu:true ~dialog_on:false;
    ]
  in
  let expected : R.reading =
    {
      verdict = Not_shiny;
      wild_animation_ms = Some 1900.;
      your_animation_ms = Some 1900.;
      phase = Post_entry;
    }
  in
  check_reading "weather banner non-shiny" ~expected ~actual:(run_frames frames)

let test_weather_banner_shiny () =
  (* Shiny Kyogre/Groudon with Drizzle/Drought banner after lead send-out. *)
  let frames =
    [
      frame ~seq:1 ~t_ms:500. ~battle_menu:false ~dialog_on:true;
      frame ~seq:2 ~t_ms:2000. ~battle_menu:false ~dialog_on:false;
      frame ~seq:3 ~t_ms:5850. ~battle_menu:false ~dialog_on:true;
      frame ~seq:4 ~t_ms:6700. ~battle_menu:false ~dialog_on:false;
      frame ~seq:5 ~t_ms:8600. ~battle_menu:false ~dialog_on:true;
      frame ~seq:6 ~t_ms:10100. ~battle_menu:false ~dialog_on:false;
      frame ~seq:7 ~t_ms:10800. ~battle_menu:true ~dialog_on:false;
    ]
  in
  let expected : R.reading =
    {
      verdict = Shiny;
      wild_animation_ms = Some 3850.;
      your_animation_ms = Some 1900.;
      phase = Post_entry;
    }
  in
  check_reading "weather banner shiny" ~expected ~actual:(run_frames frames)

let test_timeout_unknown () =
  let frames =
    [
      frame ~seq:1 ~t_ms:500. ~battle_menu:false ~dialog_on:true;
      frame ~seq:2 ~t_ms:2000. ~battle_menu:false ~dialog_on:false;
      frame ~seq:3 ~t_ms:5900. ~battle_menu:false ~dialog_on:true;
    ]
  in
  let expected : R.reading =
    {
      verdict = Unknown;
      wild_animation_ms = Some 3900.;
      your_animation_ms = None;
      phase = Your_animation;
    }
  in
  check_reading "timeout before battle menu" ~expected
    ~actual:(run_frames frames)

let () =
  test_probes_layout ();
  test_non_shiny_standard ();
  test_shiny_standard ();
  test_weather_banner_non_shiny ();
  test_weather_banner_shiny ();
  test_timeout_unknown ();
  print_endline "OK"
