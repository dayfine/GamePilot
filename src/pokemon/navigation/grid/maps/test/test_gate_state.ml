(* What a step does to the open gates and the switches, and back. *)

open Grid_maps
module Names = Gate_state.Names

let state opened on : Gate_state.t =
  { opened = Names.of_list opened; switches_on = Names.of_list on }

let describe_change (change : Gate_state.change) =
  let switch (id, on) =
    Printf.sprintf "%s %s" id (if on then "on" else "off")
  in
  Printf.sprintf "opened [%s] switches [%s]"
    (String.concat " " (Names.elements change.newly_opened))
    (String.concat ", " (List.map switch change.switches))

type case = {
  name : string;
  input : Gate_state.t * Gate_state.t;
  expectation : string;
}

let door = Gate_state.gate_key ~map:"SilphCo_5F" ~gate:"door_1"

let cases =
  [
    {
      name = "nothing changes";
      input = (state [ door ] [ "mansion" ], state [ door ] [ "mansion" ]);
      expectation = "opened [] switches []";
    };
    {
      name = "a door opened";
      input = (Gate_state.new_game, state [ door ] []);
      expectation = "opened [SilphCo_5F/door_1] switches []";
    };
    {
      name = "a switch on and another off";
      input = (state [] [ "b" ], state [] [ "a" ]);
      expectation = "opened [] switches [a on, b off]";
    };
    {
      name = "a door does not close again";
      input = (state [ door ] [], Gate_state.new_game);
      expectation = "opened [] switches []";
    };
  ]

(* The change between two states, and that applying it to the first gives
   the second (except a door the second has closed, which stays open). *)
let run_case { name; input = before, after; expectation } =
  let change = Gate_state.change_between ~before ~after in
  let reached = Gate_state.apply before change in
  let expected_after =
    { after with opened = Names.union before.opened after.opened }
  in
  Table_test.report name
    (Check.all
       [
         (fun () ->
           Check.equal "change" ~expected:expectation (describe_change change));
         (fun () ->
           if Gate_state.equal reached expected_after then Ok ()
           else Error "apply did not reach the after state");
       ])

let () =
  List.iter run_case cases;
  Table_test.finish ()
