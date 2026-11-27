(* Unit tests for Bdsp_actions.Check_bag.
   Fakes stand in for Switch Bag inputs and snapshot callbacks: fake_game_steps
   records typed pocket switches, page scrolls, and snapshots so we can verify
   multi-pocket traversal, page counts, and validation. *)

open Bdsp_readers
open Bdsp_actions

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

type bag_event =
  | Open_bag
  | Switch of Bag_pocket_reader.pocket * Bag_pocket_reader.pocket
  | Scroll_page
  | Snapshot of Bag_pocket_reader.pocket * int
  | Close_bag

let fake_game_steps ?(open_result = Ok ()) () =
  let events = ref [] in
  let record ev = events := ev :: !events in
  let steps : Check_bag.game_steps =
    {
      open_bag =
        (fun () ->
          record Open_bag;
          open_result);
      switch_pocket = (fun ~from ~to_ -> record (Switch (from, to_)));
      scroll_page = (fun () -> record Scroll_page);
      snapshot = (fun ~pocket ~page -> record (Snapshot (pocket, page)));
      close_bag = (fun () -> record Close_bag);
    }
  in
  (steps, fun () -> List.rev !events)

let test_multi_pocket_traversal () =
  let steps, trace = fake_game_steps () in
  let plan : Check_bag.pocket_snapshot list =
    [ { pocket = Medicine; pages = 1 }; { pocket = Treasures; pages = 2 } ]
  in
  assert_eq "total snapshots"
    (Check_bag.run steps ~start_pocket:Medicine plan)
    (Ok 3);
  assert_eq "traversal sequence" (trace ())
    [
      Open_bag;
      Snapshot (Medicine, 1);
      Switch (Medicine, Treasures);
      Snapshot (Treasures, 1);
      Scroll_page;
      Snapshot (Treasures, 2);
      Close_bag;
    ]

let test_empty_plan_noop () =
  let steps, trace = fake_game_steps () in
  assert_eq "empty plan returns 0"
    (Check_bag.run steps ~start_pocket:Key_items [])
    (Ok 0);
  assert_eq "empty plan does not open bag" (trace ()) []

let test_invalid_pages_rejected () =
  let steps, trace = fake_game_steps () in
  assert_eq "zero pages rejected"
    (Check_bag.run steps ~start_pocket:Medicine [ { pocket = Tms; pages = 0 } ])
    (Error "check_bag: pages 0 must be at least 1");
  assert_eq "invalid plan never opens bag" (trace ()) []

let test_open_error_propagated () =
  let steps, trace =
    fake_game_steps ~open_result:(Error "X menu did not open") ()
  in
  assert_eq "open error returned"
    (Check_bag.run steps ~start_pocket:Medicine
       [ { pocket = Poke_balls; pages = 1 } ])
    (Error "X menu did not open");
  assert_eq "stops after failed open" (trace ()) [ Open_bag ]

let () =
  test_multi_pocket_traversal ();
  test_empty_plan_noop ();
  test_invalid_pages_rejected ();
  test_open_error_propagated ();
  print_endline "OK"
