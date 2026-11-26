open Bdsp_readers
module WS = Wall_sparkle
module BF = Wire.Blob_find

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label
let full_pic : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let mk_blob ~cx ~cy ~w ~h : BF.blob =
  {
    filter = 0;
    x = cx -. (w /. 2.);
    y = cy -. (h /. 2.);
    w;
    h;
    fill = 0.7;
    stray = None;
    score = None;
    overlap = None;
  }

let frame_of ?(left = []) right : Wire.frame =
  {
    seq = 1;
    t_ms = 0.;
    probes =
      [
        ("bdsp_wall_star_right", Wire.Find { blobs = right });
        ("bdsp_wall_star_left", Wire.Find { blobs = left });
      ];
  }

let test_probe_layout () =
  let ps = WS.probes ~picture:full_pic in
  assert_true "2 core.find@1 probes (right + left below minimap)"
    (List.length ps = 2);
  let right = List.hd ps in
  assert_true "right box excludes minimap (x >= 0.24)" (right.box.x >= 0.24);
  assert_true "right probe is core.find@1" (right.kind = "core.find@1")

let test_torch_and_star_same_wall () =
  (* Exact run-2/000231.jpg SE corner case: static wall torch at (1115, 388)
     and new sparkle star at (1052, 103) on the SAME East wall. Blob-diffing
     cancels the torch and returns the star's exact offset. *)
  let torch = mk_blob ~cx:1115. ~cy:388. ~w:12. ~h:14. in
  let star = mk_blob ~cx:1052. ~cy:103. ~w:26. ~h:28. in
  let before = frame_of [ torch ] in
  let after = frame_of [ torch; star ] in
  match WS.locate_diff ~before ~after with
  | Some off ->
      assert_true "dx = +1 (East wall)" (off.dx = 1);
      assert_true "dy = -1 (North of player)" (off.dy = -1);
      assert_true "dy_norm is ~-0.38"
        (off.dy_norm < -0.35 && off.dy_norm > -0.42)
  | None -> fail "expected star to survive torch cancellation"

let test_bottom_east_half_tile_right () =
  (* Exact prev-run-2/000268.jpg: star at (0.557, 0.388) -> dx=+1, dy=-1. *)
  let star = mk_blob ~cx:(0.557 *. 1920.) ~cy:(0.388 *. 1080.) ~w:20. ~h:20. in
  let before = frame_of [] in
  let after = frame_of [ star ] in
  match WS.locate_diff ~before ~after with
  | Some off ->
      assert_true "half-tile right star gives dx=+1" (off.dx = 1);
      assert_true "North wall star gives dy=-1" (off.dy = -1)
  | None -> fail "expected bottom_east star"

let test_player_sprite_ignored () =
  (* Flicker on player's own shoe at (0.495, 0.514) is ignored. *)
  let shoe = mk_blob ~cx:(0.495 *. 1920.) ~cy:(0.514 *. 1080.) ~w:10. ~h:10. in
  let after = frame_of [ shoe ] in
  assert_true "player sprite blob ignored" (WS.locate after = None)

let test_west_wall_blob_below_minimap () =
  let west_star = mk_blob ~cx:300. ~cy:520. ~w:18. ~h:18. in
  let after = frame_of ~left:[ west_star ] [] in
  match WS.locate after with
  | Some off -> assert_true "West wall star gives dx=-1" (off.dx = -1)
  | None -> fail "expected West wall star"

let () =
  test_probe_layout ();
  test_torch_and_star_same_wall ();
  test_bottom_east_half_tile_right ();
  test_player_sprite_ignored ();
  test_west_wall_blob_below_minimap ();
  print_endline "OK"
