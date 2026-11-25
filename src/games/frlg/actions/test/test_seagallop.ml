(* The ferry action: a trip from its args and the harbor stood in, where it
   lands, and a crossing on a scripted screen read through the FRLG readers
   from the sailor's list recorded at One Island's harbor. *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Pokemon_engine.Failure.cause_to_string cause

let args to_ = Json_field.as_object "args" (`Assoc [ ("to", `String to_) ])

let trip ~from to_ () =
  match Seagallop.trip_of_args ~from (args to_) with
  | Error cause -> "failed " ^ Pokemon_engine.Failure.cause_to_string cause
  | Ok t ->
      let at = Seagallop.arrival t in
      Printf.sprintf "row %d; lands %s %s" t.row at.at_map
        (Grid_geometry.Tile_pos.to_string at.at_tile)

(* The list shows after the talk's A; each DOWN moves its arrow a row; A on a
   row closes it into "All aboard", the black of the crossing and the harbor. *)
let crossing_screen ~list_shows =
  let row = ref 0 in
  fun screen (p : S.press) ->
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    match p.buttons with
    | [ Wire.A ] when p.index = 0 ->
        if list_shows then show 300 (S.Seagallop_list 0) else show 300 S.Dialog
    | [ Wire.Down ] ->
        incr row;
        show 50 (S.Seagallop_list !row)
    | [ Wire.A ] ->
        show 50 S.Dialog;
        show 600 S.Black;
        show 2000 S.Overworld
    | _ -> ()

let sail ~list_shows to_ () =
  let screen = S.create ~react:(crossing_screen ~list_shows) () in
  let trip =
    Result.get_ok
      (Seagallop.trip_of_args ~from:(Some "OneIsland_Harbor") (args to_))
  in
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () -> Seagallop.sail ~log:ignore trip))
  in
  Printf.sprintf "%s; %s" (outcome result) (S.presses_text screen)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "seagallop"
    [
      case "One Island to Two: the top row"
        (trip ~from:(Some "OneIsland_Harbor") "TwoIsland")
        "row 0; lands TwoIsland_Harbor (8, 5)";
      case "One Island to Three: the second row"
        (trip ~from:(Some "OneIsland_Harbor") "ThreeIsland")
        "row 1; lands ThreeIsland_Harbor (8, 5)";
      case "Two Island to One: the top row"
        (trip ~from:(Some "TwoIsland_Harbor") "OneIsland")
        "row 0; lands OneIsland_Harbor (8, 5)";
      case "no list of One Island's has One Island"
        (trip ~from:(Some "OneIsland_Harbor") "OneIsland")
        "failed bad_args: ferry: OneIsland_Harbor's list has no OneIsland";
      case "Three Island's list is not read"
        (trip ~from:(Some "ThreeIsland_Harbor") "OneIsland")
        "failed bad_args: ferry: no Seagallop list is read at \
         ThreeIsland_Harbor";
      case "no harbor stood in"
        (trip ~from:None "TwoIsland")
        "failed bad_args: ferry: no harbor to sail from: the position is \
         unknown";
      case "to Three Island: one DOWN, A, the crossing settled"
        (sail ~list_shows:true "ThreeIsland")
        "ok; A, down, A, B x5";
      case "a list that never shows fails"
        (sail ~list_shows:false "TwoIsland")
        "failed no_seagallop_list: the sailor's list did not show; A";
    ]
