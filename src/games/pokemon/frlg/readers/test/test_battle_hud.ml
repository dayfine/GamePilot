(* Typed unit tests for Frlg_readers.Battle_hud.
   Synthetic Wire.frame measurements stand in for daemon color_stats probes so
   HP bar ratios, foe status badges, and Battle_screen box gating are verified
   directly on typed values. *)

open Frlg_readers

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

let cs (r, g, b) (sr, sg, sb) =
  Wire.Color_stats
    { mean = { Wire.r; g; b }; stddev = { Wire.r = sr; g = sg; b = sb } }

let frame probes : Effects.measurements = { Wire.seq = 1; t_ms = 0.; probes }

(* Synthetic Battle_screen.foe_box probes matching light/dark edges and a
   plain (non-white, non-sand) battle background. *)
let foe_box_probes =
  let light = cs (245., 245., 235.) (2., 2., 2.) in
  let dark = cs (80., 95., 90.) (2., 2., 2.) in
  let bg = cs (80., 140., 220.) (4., 4., 4.) in
  [
    ("battle.foe.left", light);
    ("battle.foe.right", light);
    ("battle.foe.top", light);
    ("battle.foe.bottom", dark);
    ("battle.foe.background", bg);
  ]

(* Synthetic Battle_screen.player_box probes. *)
let player_box_probes =
  let light = cs (245., 245., 235.) (2., 2., 2.) in
  let dark = cs (80., 95., 90.) (2., 2., 2.) in
  let bg = cs (80., 140., 220.) (4., 4., 4.) in
  [
    ("battle.player.left", light);
    ("battle.player.right", dark);
    ("battle.player.top", light);
    ("battle.player.bottom", dark);
    ("battle.player.background", bg);
  ]

let hp_bar_probes prefix ~filled ~rgb =
  List.init 12 (fun idx ->
      let id = Printf.sprintf "%s%d" prefix idx in
      let color = if idx < filled then rgb else (72., 88., 88.) in
      (id, cs color (3., 3., 3.)))

let test_hp_ratios () =
  let full_foe =
    frame
      (foe_box_probes
      @ hp_bar_probes "battle.hud.foe_hp." ~filled:12 ~rgb:(80., 240., 128.))
  in
  assert_eq "foe full green" (Battle_hud.foe_hp_ratio full_foe) (Some 1.0);
  let half_foe =
    frame
      (foe_box_probes
      @ hp_bar_probes "battle.hud.foe_hp." ~filled:6 ~rgb:(248., 224., 56.))
  in
  assert_eq "foe yellow 50%" (Battle_hud.foe_hp_ratio half_foe) (Some 0.5);
  let low_player =
    frame
      (player_box_probes
      @ hp_bar_probes "battle.hud.player_hp." ~filled:3 ~rgb:(248., 88., 56.))
  in
  assert_eq "player red 25%" (Battle_hud.player_hp_ratio low_player) (Some 0.25);
  (* Gating: without Battle_screen.foe_box / player_box, ratios return None. *)
  let ungated_foe =
    frame (hp_bar_probes "battle.hud.foe_hp." ~filled:12 ~rgb:(80., 240., 128.))
  in
  assert_eq "ungated foe bar returns None"
    (Battle_hud.foe_hp_ratio ungated_foe)
    None;
  let ungated_player =
    frame
      (hp_bar_probes "battle.hud.player_hp." ~filled:12 ~rgb:(80., 240., 128.))
  in
  assert_eq "ungated player bar returns None"
    (Battle_hud.player_hp_ratio ungated_player)
    None;
  assert_eq "foe box without HP probes returns None"
    (Battle_hud.foe_hp_ratio (frame foe_box_probes))
    None

let test_foe_status () =
  let with_status rgb =
    frame (foe_box_probes @ [ ("battle.hud.foe_status", cs rgb (6., 6., 6.)) ])
  in
  assert_eq "cream background is Healthy"
    (Battle_hud.foe_status (with_status (255., 255., 222.)))
    (Some Battle_hud.Healthy);
  assert_eq "caught mark on cream is still Healthy"
    (Battle_hud.foe_status (with_status (235., 235., 205.)))
    (Some Battle_hud.Healthy);
  assert_eq "grey SLP badge is Asleep"
    (Battle_hud.foe_status (with_status (148., 152., 148.)))
    (Some Battle_hud.Asleep);
  assert_eq "foe_asleep true on SLP"
    (Battle_hud.foe_asleep (with_status (148., 152., 148.)))
    (Some true);
  assert_eq "foe_asleep false on Healthy"
    (Battle_hud.foe_asleep (with_status (255., 255., 222.)))
    (Some false);
  assert_eq "yellow PAR badge is Paralyzed"
    (Battle_hud.foe_status (with_status (235., 195., 40.)))
    (Some Battle_hud.Paralyzed);
  assert_eq "purple PSN badge is Other_status"
    (Battle_hud.foe_status (with_status (175., 85., 195.)))
    (Some Battle_hud.Other_status);
  assert_eq "orange BRN badge is Other_status"
    (Battle_hud.foe_status (with_status (230., 100., 65.)))
    (Some Battle_hud.Other_status);
  assert_eq "cyan FRZ badge is Other_status"
    (Battle_hud.foe_status (with_status (105., 195., 225.)))
    (Some Battle_hud.Other_status);
  (* Gating: without Battle_screen.foe_box, status returns None. *)
  let ungated =
    frame [ ("battle.hud.foe_status", cs (148., 152., 148.) (6., 6., 6.)) ]
  in
  assert_eq "ungated foe status returns None"
    (Battle_hud.foe_status ungated)
    None;
  assert_eq "ungated foe_asleep returns None"
    (Battle_hud.foe_asleep ungated)
    None

let test_probe_count () =
  assert_eq "hud probes count (12 foe + 12 player + 1 status)"
    (List.length Battle_hud.probes)
    25

let () =
  test_hp_ratios ();
  test_foe_status ();
  test_probe_count ();
  print_endline "OK"
