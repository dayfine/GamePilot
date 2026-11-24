(* Wall anchors on two synthetic maps. Ported from the C++ fork's
   Pokemon_WallRecovery_Tests.cpp; game adapters keep the real forest and mine
   cases. *)

open Grid_maps
open Grid_recovery

type hold = { direction : Direction.t; tiles : int }

let describe_holds = function
  | [] -> "none"
  | holds ->
      String.concat "; "
        (List.map
           (fun h ->
             Printf.sprintf "%s %d tiles" (Direction.name h.direction) h.tiles)
           holds)

(* A corridor between walls, walkable from x = 0 to [far_end]:
       wall | . . A B . . . . . . . | wall
   A and B are example candidates at x = 2 and 3. West stops at 0, east at
   [far_end]; north and south go nowhere. A person anywhere on the way makes a
   hold unsafe. *)
let far_end = 10

module Corridor = struct
  type context = int option (* where a person stands, if anywhere *)
  type hypothesis = int
  type position = int
  type nonrec hold = hold

  let position at = at
  let equal_hypothesis = Int.equal
  let equal_position = Int.equal
  let tiles hold = hold.tiles

  let blocks person start end_ =
    min start end_ <= person && person <= max start end_

  let unsafe person from end_ =
    match person with
    | None -> false
    | Some person -> List.exists (fun start -> blocks person start end_) from

  let hold person from (direction : Direction.t) =
    let end_ =
      match direction with West -> Some 0 | East -> Some far_end | _ -> None
    in
    match end_ with
    | None -> None
    | Some end_ when unsafe person from end_ -> None
    | Some end_ ->
        let longest =
          List.fold_left (fun m start -> max m (abs (start - end_))) 0 from
        in
        Some
          {
            Wall_recovery.positions = [ end_ ];
            hold = { direction; tiles = longest };
          }
end

(* A closed room: every tile with x and y in 0 .. [far_end] is walkable.
       #############
       #C..........#  C = (0, 0), where north then west ends
       #...........#
       #...........#
       #..A........#  A = (2, 3)
       #...B.......#  B = (3, 4)
       #############
   North 4 takes A and B to (2, 0) and (3, 0); west 3 then joins them at C. *)
module Corner = struct
  type context = unit
  type hypothesis = Tile_pos.t
  type position = Tile_pos.t
  type nonrec hold = hold

  let position at = at
  let equal_hypothesis = Tile_pos.equal
  let equal_position = Tile_pos.equal
  let tiles hold = hold.tiles

  (* Where a hold from [start] stops, and how far it went. *)
  let stop (start : Tile_pos.t) (direction : Direction.t) =
    match direction with
    | North -> ({ start with y = 0 }, start.y)
    | South -> ({ start with y = far_end }, far_end - start.y)
    | West -> ({ start with x = 0 }, start.x)
    | East -> ({ start with x = far_end }, far_end - start.x)

  let hold () from direction =
    let add (ends, longest) start =
      let end_, distance = stop start direction in
      let ends =
        if List.exists (Tile_pos.equal end_) ends then ends else ends @ [ end_ ]
      in
      (ends, max longest distance)
    in
    let ends, longest = List.fold_left add ([], 0) from in
    Some
      { Wall_recovery.positions = ends; hold = { direction; tiles = longest } }
end

module Corridor_anchors = Wall_recovery.Make (Corridor)
module Corner_anchors = Wall_recovery.Make (Corner)

type ('position, 'context) case = {
  name : string;
  positions : 'position list;
  context : 'context;
  max_holds : int;
  first_anchor : 'position option;
  holds : hold list;
}

let check_first ~show (case : _ case) found =
  let actual =
    match found with [] -> None | first :: _ -> Some first.Wall_recovery.at
  in
  let show_opt = Option.fold ~none:"none" ~some:show in
  if actual <> case.first_anchor then
    Error
      (Printf.sprintf "expected first anchor %s, got %s (%d anchors)"
         (show_opt case.first_anchor)
         (show_opt actual) (List.length found))
  else
    match found with
    | first :: _ when first.holds <> case.holds ->
        Error
          (Printf.sprintf "expected holds %s, got %s"
             (describe_holds case.holds)
             (describe_holds first.holds))
    | _ -> Ok ()

let corridor ~name ~positions ?person ~max_holds ?first_anchor holds =
  { name; positions; context = person; max_holds; first_anchor; holds }

let corridor_cases =
  [
    corridor ~name:"empty" ~positions:[] ~max_holds:3 [];
    corridor ~name:"already known" ~positions:[ 4 ] ~max_holds:0 ~first_anchor:4
      [];
    corridor ~name:"both tiles" ~positions:[ 2; 3 ] ~max_holds:3 ~first_anchor:0
      [ { direction = West; tiles = 3 } ];
    corridor ~name:"three shortfall endpoints" ~positions:[ 3; 4; 5 ]
      ~max_holds:3 ~first_anchor:0
      [ { direction = West; tiles = 5 } ];
    corridor ~name:"shortest hold first" ~positions:[ 8; 9 ] ~max_holds:3
      ~first_anchor:10
      [ { direction = East; tiles = 2 } ];
    corridor ~name:"person is not an anchor" ~positions:[ 2; 3 ] ~person:1
      ~max_holds:3 ~first_anchor:10
      [ { direction = East; tiles = 8 } ];
    corridor ~name:"person splits belief" ~positions:[ 2; 8 ] ~person:5
      ~max_holds:3 [];
    corridor ~name:"budget exhausted" ~positions:[ 2; 3 ] ~max_holds:0 [];
  ]

let pos x y = { Tile_pos.x; y }
let a_and_b = [ pos 2 3; pos 3 4 ]

let corner_cases =
  [
    {
      name = "one hold cannot localize both axes";
      positions = a_and_b;
      context = ();
      max_holds = 1;
      first_anchor = None;
      holds = [];
    };
    {
      name = "two holds converge at northwest corner";
      positions = a_and_b;
      context = ();
      max_holds = 2;
      first_anchor = Some (pos 0 0);
      holds =
        [ { direction = North; tiles = 4 }; { direction = West; tiles = 3 } ];
    };
  ]

let () =
  List.iter
    (fun case ->
      Table_test.report case.name
        (check_first ~show:string_of_int case
           (Corridor_anchors.find_anchors ~max_holds:case.max_holds case.context
              case.positions)))
    corridor_cases;
  List.iter
    (fun case ->
      Table_test.report case.name
        (check_first ~show:Tile_pos.to_string case
           (Corner_anchors.find_anchors ~max_holds:case.max_holds case.context
              case.positions)))
    corner_cases;
  Table_test.finish ()
