(* Unit tests for Bdsp_actions.Mart_shop.
   Fakes stand in for Switch shop inputs and dialog readers: fake_game_steps
   records typed shop events in order and injects clerk or purchase errors so
   we can verify input validation, multi-item buying, and error cleanup. *)

open Bdsp_actions

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

type shop_event =
  | Open_shop
  | Move_to_row of int
  | Set_quantity of int
  | Confirm_purchase
  | Close_shop

let fake_game_steps ?(open_result = Ok ()) ?(confirm_result = Ok ()) () =
  let events = ref [] in
  let record ev = events := ev :: !events in
  let steps : Mart_shop.game_steps =
    {
      open_shop =
        (fun () ->
          record Open_shop;
          open_result);
      move_to_row = (fun row -> record (Move_to_row row));
      set_quantity = (fun qty -> record (Set_quantity qty));
      confirm_purchase =
        (fun () ->
          record Confirm_purchase;
          confirm_result);
      close_shop = (fun () -> record Close_shop);
      log = (fun _ -> ());
    }
  in
  (steps, fun () -> List.rev !events)

let test_valid_purchases () =
  let steps, trace = fake_game_steps () in
  let purchases : Mart_shop.purchase list =
    [ { row = 0; quantity = 10 }; { row = 3; quantity = 5 } ]
  in
  assert_eq "total bought" (Mart_shop.run steps purchases) (Ok 15);
  assert_eq "event sequence" (trace ())
    [
      Open_shop;
      Move_to_row 0;
      Set_quantity 10;
      Confirm_purchase;
      Move_to_row 3;
      Set_quantity 5;
      Confirm_purchase;
      Close_shop;
    ]

let test_empty_purchases_noop () =
  let steps, trace = fake_game_steps () in
  assert_eq "empty returns 0" (Mart_shop.run steps []) (Ok 0);
  assert_eq "empty does not open shop" (trace ()) []

let test_invalid_inputs_rejected_before_open () =
  let steps_zero, trace_zero = fake_game_steps () in
  assert_eq "qty 0 rejected"
    (Mart_shop.run steps_zero [ { row = 0; quantity = 0 } ])
    (Error "mart_shop: quantity 0 out of range 1..99");
  assert_eq "qty 0 never opens shop" (trace_zero ()) [];
  let steps_high, trace_high = fake_game_steps () in
  assert_eq "qty 100 rejected"
    (Mart_shop.run steps_high [ { row = 1; quantity = 100 } ])
    (Error "mart_shop: quantity 100 out of range 1..99");
  assert_eq "qty 100 never opens shop" (trace_high ()) [];
  let steps_neg, trace_neg = fake_game_steps () in
  assert_eq "negative row rejected"
    (Mart_shop.run steps_neg [ { row = -1; quantity = 1 } ])
    (Error "mart_shop: negative row -1");
  assert_eq "negative row never opens shop" (trace_neg ()) []

let test_clerk_and_confirm_errors () =
  let steps_open, trace_open =
    fake_game_steps ~open_result:(Error "clerk did not respond") ()
  in
  assert_eq "open error propagated"
    (Mart_shop.run steps_open [ { row = 0; quantity = 1 } ])
    (Error "clerk did not respond");
  assert_eq "open error stops before buying" (trace_open ()) [ Open_shop ];
  let steps_confirm, trace_confirm =
    fake_game_steps ~confirm_result:(Error "not enough money") ()
  in
  assert_eq "confirm error propagated"
    (Mart_shop.run steps_confirm [ { row = 2; quantity = 10 } ])
    (Error "not enough money");
  assert_eq "confirm error closes shop" (trace_confirm ())
    [ Open_shop; Move_to_row 2; Set_quantity 10; Confirm_purchase; Close_shop ]

let () =
  test_valid_purchases ();
  test_empty_purchases_noop ();
  test_invalid_inputs_rejected_before_open ();
  test_clerk_and_confirm_errors ();
  print_endline "OK"
