(* Unit tests for Bdsp_actions.Teach_tm.
   Fakes stand in for Switch Bag/party inputs and dialog readers:
   fake_game_steps records typed TM-teaching events and injects step errors so
   we can verify request validation, move replacement, and cleanup on error. *)

open Bdsp_actions

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

type tm_event =
  | Open_tm_pocket
  | Select_tm of int
  | Choose_party_slot of int
  | Replace_move of int option
  | Close_to_overworld

let fake_game_steps ?(open_result = Ok ()) ?(party_result = Ok ())
    ?(replace_result = Ok ()) () =
  let events = ref [] in
  let record ev = events := ev :: !events in
  let steps : Teach_tm.game_steps =
    {
      open_tm_pocket =
        (fun () ->
          record Open_tm_pocket;
          open_result);
      select_tm = (fun row -> record (Select_tm row));
      choose_party_slot =
        (fun slot ->
          record (Choose_party_slot slot);
          party_result);
      replace_move =
        (fun slot ->
          record (Replace_move slot);
          replace_result);
      close_to_overworld = (fun () -> record Close_to_overworld);
      log = (fun _ -> ());
    }
  in
  (steps, fun () -> List.rev !events)

let test_teach_with_replacement () =
  let steps, trace = fake_game_steps () in
  let req : Teach_tm.request =
    { tm_row = 4; party_slot = 2; replace_move_slot = Some 3 }
  in
  assert_eq "teach succeeds" (Teach_tm.run steps req) (Ok ());
  assert_eq "teach event order" (trace ())
    [
      Open_tm_pocket;
      Select_tm 4;
      Choose_party_slot 2;
      Replace_move (Some 3);
      Close_to_overworld;
    ]

let test_teach_without_replacement () =
  let steps, trace = fake_game_steps () in
  let req : Teach_tm.request =
    { tm_row = 0; party_slot = 6; replace_move_slot = None }
  in
  assert_eq "teach free slot succeeds" (Teach_tm.run steps req) (Ok ());
  assert_eq "free slot event order" (trace ())
    [
      Open_tm_pocket;
      Select_tm 0;
      Choose_party_slot 6;
      Replace_move None;
      Close_to_overworld;
    ]

let test_validation_rejects_bad_slots () =
  let steps_party, trace_party = fake_game_steps () in
  assert_eq "party slot 7 rejected"
    (Teach_tm.run steps_party
       { tm_row = 0; party_slot = 7; replace_move_slot = None })
    (Error "teach_tm: party_slot 7 out of range 1..6");
  assert_eq "bad party never opens bag" (trace_party ()) [];
  let steps_move, trace_move = fake_game_steps () in
  assert_eq "move slot 5 rejected"
    (Teach_tm.run steps_move
       { tm_row = 0; party_slot = 1; replace_move_slot = Some 5 })
    (Error "teach_tm: replace_move_slot 5 out of range 1..4");
  assert_eq "bad move slot never opens bag" (trace_move ()) [];
  let steps_row, trace_row = fake_game_steps () in
  assert_eq "negative tm_row rejected"
    (Teach_tm.run steps_row
       { tm_row = -1; party_slot = 1; replace_move_slot = None })
    (Error "teach_tm: negative tm_row -1");
  assert_eq "bad tm_row never opens bag" (trace_row ()) []

let test_error_closes_to_overworld () =
  let steps, trace =
    fake_game_steps ~party_result:(Error "pokemon cannot learn TM") ()
  in
  let req : Teach_tm.request =
    { tm_row = 2; party_slot = 1; replace_move_slot = Some 1 }
  in
  assert_eq "party error propagated" (Teach_tm.run steps req)
    (Error "pokemon cannot learn TM");
  assert_eq "party error closes bag" (trace ())
    [ Open_tm_pocket; Select_tm 2; Choose_party_slot 1; Close_to_overworld ]

let () =
  test_teach_with_replacement ();
  test_teach_without_replacement ();
  test_validation_rejects_bad_slots ();
  test_error_closes_to_overworld ();
  print_endline "OK"
