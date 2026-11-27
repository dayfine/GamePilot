(* Unit tests for Bdsp_readers.Bag_pocket_reader.
   Fakes stand in for daemon color_stats probe frames: synthetic Wire.frame
   measurements with controlled RGB means and stddevs for the Bag header bar. *)

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

let test_pocket_indices () =
  let indices =
    List.map Bag_pocket_reader.pocket_index
      [
        Medicine;
        Poke_balls;
        Battle_items;
        Berries;
        Items;
        Tms;
        Treasures;
        Key_items;
      ]
  in
  assert_eq "pocket indices 0..7" indices [ 0; 1; 2; 3; 4; 5; 6; 7 ]

let test_pocket_steps () =
  assert_eq "same pocket stays"
    (Bag_pocket_reader.pocket_steps ~from:Tms ~to_:Tms)
    `Stay;
  assert_eq "wrap left from Medicine to Key_items"
    (Bag_pocket_reader.pocket_steps ~from:Medicine ~to_:Key_items)
    (`Left 1);
  assert_eq "wrap right from Key_items to Medicine"
    (Bag_pocket_reader.pocket_steps ~from:Key_items ~to_:Medicine)
    (`Right 1);
  assert_eq "short right from Medicine to Berries"
    (Bag_pocket_reader.pocket_steps ~from:Medicine ~to_:Berries)
    (`Right 3);
  assert_eq "short left from Medicine to Tms"
    (Bag_pocket_reader.pocket_steps ~from:Medicine ~to_:Tms)
    (`Left 3);
  assert_eq "halfway tie goes right"
    (Bag_pocket_reader.pocket_steps ~from:Medicine ~to_:Items)
    (`Right 4)

let apply_mart_steps steps =
  List.fold_left
    (fun acc step ->
      match step with
      | `Up n -> acc + n
      | `Down n -> acc - n
      | `Right n -> acc + (10 * n)
      | `Left n -> acc - (10 * n))
    1 steps

let test_mart_quantity_steps () =
  assert_eq "qty 1 is empty"
    (Bag_pocket_reader.mart_quantity_steps ~target_qty:1)
    [];
  assert_eq "qty 5 uses 4 ups"
    (Bag_pocket_reader.mart_quantity_steps ~target_qty:5)
    [ `Up 4 ];
  assert_eq "qty 7 overshoots to 11 then down 4"
    (Bag_pocket_reader.mart_quantity_steps ~target_qty:7)
    [ `Right 1; `Down 4 ];
  assert_eq "qty 10 uses right 1 down 1"
    (Bag_pocket_reader.mart_quantity_steps ~target_qty:10)
    [ `Right 1; `Down 1 ];
  assert_eq "qty 11 uses right 1"
    (Bag_pocket_reader.mart_quantity_steps ~target_qty:11)
    [ `Right 1 ];
  assert_eq "qty 40 uses right 4 down 1"
    (Bag_pocket_reader.mart_quantity_steps ~target_qty:40)
    [ `Right 4; `Down 1 ];
  assert_eq "qty 99 avoids overshoot past 99"
    (Bag_pocket_reader.mart_quantity_steps ~target_qty:99)
    [ `Right 9; `Up 8 ];
  for qty = 1 to 99 do
    let steps = Bag_pocket_reader.mart_quantity_steps ~target_qty:qty in
    assert_eq
      (Printf.sprintf "qty %d reaches target" qty)
      (apply_mart_steps steps) qty
  done

let test_bag_open () =
  let picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. } in
  assert_eq "one bag header probe"
    (List.length (Bag_pocket_reader.bag_open_probes ~picture))
    1;
  let green_bar =
    frame [ ("bdsp_bag_header", cs (65., 185., 125.) (12., 12., 12.)) ]
  in
  assert_eq "green header detected" (Bag_pocket_reader.bag_open green_bar) true;
  let white_bar =
    frame [ ("bdsp_bag_header", cs (240., 240., 240.) (5., 5., 5.)) ]
  in
  assert_eq "white screen rejected" (Bag_pocket_reader.bag_open white_bar) false;
  assert_eq "missing probe rejected"
    (Bag_pocket_reader.bag_open (frame []))
    false

let () =
  test_pocket_indices ();
  test_pocket_steps ();
  test_mart_quantity_steps ();
  test_bag_open ();
  print_endline "OK"
