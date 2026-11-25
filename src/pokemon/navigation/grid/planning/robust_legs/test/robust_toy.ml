(* A small made-up game for the robust planner, from the C++ fork's
   Pokemon_RobustLegPlanner_Tests.cpp: '#' wall (and everything outside the
   rows), '.' floor, '"' tall grass, 'w' where someone wanders, 'D' a door:
   the player is stopped there but not held, since walking on enters the
   building. 'v' a ledge: a step south onto it hops to the tile past it and
   counts 2; it holds the player any other way. Rows that wrap join their
   east end to their west end, so a walk along them is never stopped. *)

open Grid_geometry
open Grid_robust_legs

let pos x y = { Tile_pos.x; y }
let row rows y = if y < 0 then None else List.nth_opt rows y

let at rows (p : Tile_pos.t) =
  match row rows p.y with
  | Some row when p.x >= 0 && p.x < String.length row -> row.[p.x]
  | _ -> '#'

let wrapped rows ~wraps (p : Tile_pos.t) =
  match row rows p.y with
  | Some row when wraps ->
      let width = String.length row in
      { p with x = ((p.x mod width) + width) mod width }
  | _ -> p

let step rows ~wraps p direction =
  let next = wrapped rows ~wraps (Tile_pos.next p direction) in
  match at rows next with
  | 'v' when direction = Direction.South ->
      let past = Tile_pos.next next South in
      if at rows past = '#' then None else Some past
  | '#' | 'D' | 'v' -> None
  | _ -> Some next

let step_tiles (a : Tile_pos.t) (b : Tile_pos.t) =
  if b.y - a.y = 2 then 2 else 1

let model ?(wraps = false) rows =
  {
    Robust_model.compare_state = Tile_pos.compare;
    step = step rows ~wraps;
    step_tiles;
    held_at =
      (fun p direction ->
        at rows (wrapped rows ~wraps (Tile_pos.next p direction)) <> 'D');
    wild = (fun p -> at rows p = '"');
    wander = (fun p -> at rows p = 'w');
  }

(* Costs whose open legs land exactly. *)
let exact = { Robust_costs.default with exact_open_tiles = 12 }

(* Open legs held for their time, a tile short or long at any length. *)
let held =
  {
    Robust_costs.default with
    open_error = 1;
    open_error_per = 0;
    hold_open_legs = true;
  }

let describe_leg (leg : Tile_pos.t Robust_leg.t) =
  let how =
    if leg.to_wall then "to wall" else if leg.held then "held" else "open"
  in
  Printf.sprintf "%s %d %s:%s"
    (Direction.name leg.direction)
    leg.tiles how
    (String.concat ""
       (List.map (fun p -> " " ^ Tile_pos.to_string p) leg.after))

(* Legs as "east 2 to wall: (2, 0); south 1 open: (2, 1) (2, 2)", or
   "none". *)
let describe = function
  | None -> "none"
  | Some legs -> String.concat "; " (List.map describe_leg legs)
