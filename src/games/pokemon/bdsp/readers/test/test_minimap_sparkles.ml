open Bdsp_readers
module MS = Minimap_sparkles

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label
let full_pic : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let frame_of pairs : Wire.frame =
  let probes =
    List.map
      (fun (id, fraction) -> (id, Wire.Color_count { fraction; mean = None }))
      pairs
  in
  { seq = 1; t_ms = 0.; probes }

let fm_id corr i = Printf.sprintf "bdsp_fm_sp_%s_%d" corr i
let mm_sp_id corr i = Printf.sprintf "bdsp_mm_sp_%s_%d" corr i
let mm_pl_id corr i = Printf.sprintf "bdsp_mm_pl_%s_%d" corr i

let test_probe_counts () =
  assert_true "8 buckets per corridor" (MS.buckets_per_corridor = 8);
  assert_true "24 full-map probes"
    (List.length (MS.full_map_probes ~picture:full_pic) = 24);
  assert_true "48 minimap probes (sparkle + player)"
    (List.length (MS.probes ~picture:full_pic) = 48)

let test_two_nearby_diamonds_bottom_east () =
  (* Real run-68 / run-71 / run-74 c2 layout: diamonds at buckets 2 and 5. *)
  let m =
    frame_of
      [
        (fm_id "bottom_east" 1, 0.08);
        (fm_id "bottom_east" 2, 0.21);
        (fm_id "bottom_east" 4, 0.12);
        (fm_id "bottom_east" 5, 0.25);
      ]
  in
  let n = MS.read_full_map m in
  assert_true "bottom_east active" n.bottom_east;
  assert_true "two bottom_east targets [2; 5]"
    (n.targets
    = [
        { MS.corridor = Bottom_east; bucket = 2 };
        { MS.corridor = Bottom_east; bucket = 5 };
      ])

let test_two_close_diamonds_with_se_corner () =
  (* Real run-74 c1 layout: diamonds at buckets 4/5 and 7 (SE corner). *)
  let m =
    frame_of
      [
        (fm_id "bottom_east" 4, 0.12);
        (fm_id "bottom_east" 5, 0.12);
        (fm_id "bottom_east" 6, 0.08);
        (fm_id "bottom_east" 7, 0.21);
      ]
  in
  let n = MS.read_full_map m in
  assert_true "two close bottom_east targets [4; 7]"
    (n.targets
    = [
        { MS.corridor = Bottom_east; bucket = 4 };
        { MS.corridor = Bottom_east; bucket = 7 };
      ])

let test_straddling_single_diamond_merges () =
  (* Equal tie across two buckets merges to the earlier bucket. *)
  let m_tie =
    frame_of [ (fm_id "top_east" 4, 0.19); (fm_id "top_east" 5, 0.19) ]
  in
  let n_tie = MS.read_full_map m_tie in
  assert_true "tie straddle merges to bucket 4"
    (n_tie.targets = [ { MS.corridor = Top_east; bucket = 4 } ]);
  (* Unequal straddle across three buckets merges to the center peak. *)
  let m_peak =
    frame_of
      [
        (fm_id "top_east" 4, 0.14);
        (fm_id "top_east" 5, 0.24);
        (fm_id "top_east" 6, 0.14);
      ]
  in
  let n_peak = MS.read_full_map m_peak in
  assert_true "3-bucket single diamond merges to peak 5"
    (n_peak.targets = [ { MS.corridor = Top_east; bucket = 5 } ])

let test_multi_corridor_and_east_vertical_pair () =
  (* Real run-64 c3 / run-74 c3 layout: 2 east_vertical + bottom_east + top_east. *)
  let m =
    frame_of
      [
        (fm_id "bottom_east" 7, 0.25);
        (fm_id "east_vertical" 2, 0.12);
        (fm_id "east_vertical" 5, 0.27);
        (fm_id "east_vertical" 6, 0.20);
        (fm_id "top_east" 4, 0.19);
        (fm_id "top_east" 5, 0.19);
      ]
  in
  let n = MS.read_full_map m in
  assert_true "all three corridors active"
    (n.bottom_east && n.east_vertical && n.top_east);
  assert_true "four ordered targets across ring"
    (n.targets
    = [
        { MS.corridor = Bottom_east; bucket = 7 };
        { MS.corridor = East_vertical; bucket = 2 };
        { MS.corridor = East_vertical; bucket = 5 };
        { MS.corridor = Top_east; bucket = 4 };
      ])

let test_below_threshold_and_minimap_player () =
  let m =
    frame_of
      [
        (mm_sp_id "bottom_east" 3, 0.004);
        (mm_pl_id "east_vertical" 5, 0.025);
        (mm_pl_id "east_vertical" 6, 0.012);
      ]
  in
  let n = MS.read m in
  assert_true "noise below threshold ignored" (not (MS.any n));
  assert_true "player dot peak at east_vertical[5]"
    (n.player = Some { MS.corridor = East_vertical; bucket = 5 })

let () =
  test_probe_counts ();
  test_two_nearby_diamonds_bottom_east ();
  test_two_close_diamonds_with_se_corner ();
  test_straddling_single_diamond_merges ();
  test_multi_corridor_and_east_vertical_pair ();
  test_below_threshold_and_minimap_player ();
  print_endline "OK"
