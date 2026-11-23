(* Plans through gates on the real maps: Card Key doors at Silph Co. 5F, the
   Pokemon Mansion's statue switch and its holes. Ported from the C++ fork's
   Pokemon_Gates_Tests.cpp (its planner cases). *)

open Grid_maps
open Grid_planning
module Names = Gate_state.Names

type legs = Connected_maps.place Gated_model.state Leg.t list

type input = {
  from : Connected_maps.place;
  goal : Connected_maps.place;
  gates : Gate_state.t;
  card_key_held : bool;
}

type case = {
  name : string;
  input : input;
  expectation : string * (legs option -> bool);
}

let place = Gate_maps.place
let silph = Gate_maps.silph
let mansion_1f = Gate_maps.mansion_1f
let mansion_3f = Gate_maps.mansion_3f
let door = Gate_state.gate_key ~map:"SilphCo_5F" ~gate:"door_1"
let none = Gate_state.new_game
let mansion_on = { none with switches_on = Names.singleton "mansion" }

let plan { from; goal; gates; card_key_held } =
  Gated_planner.plan Gate_maps.game Gate_maps.world
    { Gated_model.default_rules with card_key_held }
    ~start:{ inner = from; gates } ~start_facing:None
    ~at_goal:(fun p -> Connected_maps.compare_place p goal = 0)
    ~goal_facing:None

let walk ?(gates = none) ?(card_key_held = false) from goal =
  { from; goal; gates; card_key_held }

let actions action (legs : legs) =
  List.filter (fun (leg : _ Leg.t) -> leg.kind = Action action) legs

let route holds = function Some legs -> holds legs | None -> false
let no_route = Option.is_none

(* Exactly one [action] leg, which [holds]. *)
let one action holds legs =
  match actions action legs with [ leg ] -> holds leg | _ -> false

let from_facing tile direction (leg : _ Gated_model.state Leg.t) =
  Connected_maps.compare_place leg.start.inner tile = 0
  && leg.direction = direction

let opened_door_alone leg =
  let change = Gated_planner.gate_change_of leg in
  Names.elements change.newly_opened = [ door ] && change.switches = []

let after before holds legs = holds (Gated_planner.gates_after before legs)
let mansion_is on state = Gate_state.switch_on state "mansion" = on

let silph_cases =
  let from = place silph 10 9 and goal = place silph 5 9 in
  [
    {
      name = "a Card Key door needs the key";
      input = walk from goal;
      expectation = ("no route", no_route);
    };
    {
      name = "the key opens it";
      input = walk ~card_key_held:true from goal;
      expectation =
        ( "one open-gate leg facing west from (9, 9) opening door_1 alone, \
           open after",
          route (fun legs ->
              one Gated_model.Open_gate
                (fun leg ->
                  from_facing (place silph 9 9) West leg
                  && opened_door_alone leg)
                legs
              && after none (fun s -> Names.mem door s.opened) legs) );
    };
    {
      name = "an open door needs no key";
      input = walk ~gates:{ none with opened = Names.singleton door } from goal;
      expectation =
        ( "a route with no open-gate leg",
          route (fun legs -> actions Gated_model.Open_gate legs = []) );
    };
  ]

let mansion_cases =
  [
    {
      name = "a statue press opens a barrier";
      input = walk (place mansion_1f 5 8) (place mansion_1f 19 13);
      expectation =
        ( "one press, facing north from (5, 6); the switch on after",
          route (fun legs ->
              one Gated_model.Press_switch
                (from_facing (place mansion_1f 5 6) North)
                legs
              && after none (mansion_is true) legs) );
    };
    {
      name = "a press again closes it";
      input =
        walk ~gates:mansion_on (place mansion_1f 5 6) (place mansion_1f 25 21);
      expectation =
        ( "one press; the switch off after",
          route (fun legs ->
              one Gated_model.Press_switch (fun _ -> true) legs
              && after mansion_on (mansion_is false) legs) );
    };
    {
      name = "no press when not needed";
      input = walk (place mansion_1f 5 6) (place mansion_1f 5 8);
      expectation =
        ( "a route with no press",
          route (fun legs -> actions Gated_model.Press_switch legs = []) );
    };
    {
      name = "down a hole";
      input = walk (place mansion_3f 18 17) (place mansion_1f 19 22);
      expectation =
        ( "a route taking the warp",
          route (List.exists (fun (leg : _ Leg.t) -> leg.warps)) );
    };
    {
      name = "not back up a hole";
      input = walk (place mansion_1f 19 22) (place mansion_3f 18 17);
      expectation = ("no route", no_route);
    };
  ]

let describe_leg (leg : Connected_maps.place Gated_model.state Leg.t) =
  let at = leg.finish.inner in
  let kind =
    match leg.kind with
    | Walk { tiles; _ } -> Printf.sprintf "walk %d" tiles
    | Action Gated_model.Open_gate -> "open gate"
    | Action Gated_model.Press_switch -> "press switch"
    | Action _ | Face -> "other"
  in
  Printf.sprintf "%s %s -> %d %s" kind
    (Direction.name leg.direction)
    at.map
    (Tile_pos.to_string at.tile)

let describe = function
  | None -> "no route"
  | Some legs -> String.concat "; " (List.map describe_leg legs)

let () =
  List.iter
    (fun { name; input; expectation = expected, holds } ->
      let legs = plan input in
      Check.report name
        (Check.expect ~expected ~plan:(describe legs) (holds legs)))
    (silph_cases @ mansion_cases);
  Check.finish ()
