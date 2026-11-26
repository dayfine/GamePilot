(* Home_bank.run_deposit: failure contracts (Stop_open, Quit_discard,
   Save_partial) tested against fake_game_steps. *)

open Pokemon_home

let mk_move name : Box_moves.t =
  {
    name;
    source = { box = 1; row = 0; col = 0 };
    destination = { boxes = [ 152 ]; fallback = []; order = Left_to_right };
  }

let run_case ~results ?(save_res = Ok ()) ?(close_res = Ok ()) on_failure () =
  let trace = ref [] in
  let step s = trace := s :: !trace in
  let remaining = ref results in
  let fake_game_steps : Home_bank.game_steps =
    {
      move =
        (fun m ->
          step ("move:" ^ m.name);
          match !remaining with
          | r :: rest ->
              remaining := rest;
              r
          | [] -> Ok ());
      save =
        (fun () ->
          step "save";
          save_res);
      close =
        (fun () ->
          step "close";
          close_res);
      log = ignore;
    }
  in
  let moves =
    List.mapi (fun i _ -> mk_move (Printf.sprintf "M%d" (i + 1))) results
  in
  let res = Home_bank.run_deposit fake_game_steps { moves; on_failure } in
  let outcome = match res with Ok () -> "ok" | Error e -> "error: " ^ e in
  String.concat "," (List.rev !trace) ^ " -> " ^ outcome

let err ?(holding = false) message : (unit, Box_moves.move_error) result =
  Error { message; holding }

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "home_bank"
    [
      case "all moves succeed: saves and closes"
        (run_case ~results:[ Ok (); Ok () ] Stop_open)
        "move:M1,move:M2,save,close -> ok";
      case "Stop_open: leaves HOME open unsaved on failure"
        (run_case ~results:[ Ok (); err "box full" ] Stop_open)
        "move:M1,move:M2 -> error: box full";
      case "Quit_discard: closes without saving on failure"
        (run_case ~results:[ Ok (); err "box full" ] Quit_discard)
        "move:M1,move:M2,close -> error: box full; Pokémon HOME closed, unsaved";
      case "Save_partial with prior moves: saves and closes"
        (run_case ~results:[ Ok (); err "box full" ] Save_partial)
        "move:M1,move:M2,save,close -> error: saved 1 of 2 Pokémon before \
         failure: box full";
      case "Save_partial with zero prior moves: closes without saving"
        (run_case ~results:[ err "empty slot" ] Save_partial)
        "move:M1,close -> error: empty slot; nothing moved, Pokémon HOME closed";
      case "Save_partial while holding a Pokémon: leaves open unsaved"
        (run_case
           ~results:[ Ok (); err ~holding:true "drop failed" ]
           Save_partial)
        "move:M1,move:M2 -> error: drop failed; cursor may hold a Pokémon, \
         Pokémon HOME left open unsaved";
      case "Save_partial when save fails: does not close"
        (run_case
           ~results:[ Ok (); err "box full" ]
           ~save_res:(Error "save banner timeout") Save_partial)
        "move:M1,move:M2,save -> error: save banner timeout";
    ]
