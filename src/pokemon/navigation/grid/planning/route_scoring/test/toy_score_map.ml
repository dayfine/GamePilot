(* Small made-up grids for the route scorer, from the C++ fork's
   Pokemon_RouteScorer_Tests.cpp: '#' wall (and everything outside the
   rows), '.' floor, '"' tall grass, 'D' a warp, 'T' a scene's trigger, 'w'
   a wanderer's tile, 's' a trainer's sight, 'v' a ledge hopped south. *)

open Grid_maps
open Grid_route_scoring

let pos x y = { Tile_pos.x; y }

let at rows (p : Tile_pos.t) =
  match if p.y < 0 then None else List.nth_opt rows p.y with
  | Some row when p.x >= 0 && p.x < String.length row -> row.[p.x]
  | _ -> '#'

let step rows p direction =
  let next = Tile_pos.next p direction in
  match at rows next with
  | 'v' ->
      if direction = Direction.South then Some (Tile_pos.next next South)
      else None
  | '#' -> None
  | _ -> Some next

let risk rows p : Score_map.risk =
  match at rows p with
  | '"' -> Encounter
  | 'D' -> Warp
  | 'T' -> Trigger
  | 'w' -> Wanderer
  | 's' -> Sight
  | _ -> No_risk

let map rows = { Score_map.step = step rows; risk = risk rows }

let paces =
  {
    Route_paces.ms_per_tile = (fun _ ~run -> if run then 100 else 250);
    start_ms = 250;
    tap_ms = 800;
    press_ms = 100;
    stop_ms = 1000;
    open_hold_error = Some (fun tiles -> 1 + (tiles / 5));
  }

let model =
  {
    Interrupt_model.none with
    encounter_per_tile = 0.1;
    encounter_ms = 12000;
    wanderer_per_tile = 0.25;
    wanderer_ms = 2500;
    trainer_ms = 45000;
    replan_ms = 2000;
  }

let leg ?(run = false) kind direction tiles =
  { Scored_leg.direction; tiles; kind; run }

let score ?replan ?(model = model) rows ~from ~goal legs =
  Route_scorer.score ?replan (map rows) paces model ~from:[ from ]
    ~goal:(Tile_pos.equal goal) legs

let verdict (score : Route_score.t) = Route_score.verdict_name score.verdict

(* A replanner that always gives the same legs. *)
let always legs _ = Some legs
