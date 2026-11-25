(* A small made-up game with the kinds of tiles the real games have, from
   the C++ fork's Pokemon_LegPlanner_Tests.cpp: '#' wall, '.' floor, '"' tall
   grass, 'C' map connection, 'p' a person (blocks, but may walk off, so not a
   wall to stop against), 'v' entered only going south, 'W' a warp to the
   tile marked 'X'. Off the rows is wall. *)

open Grid_geometry
open Grid_planning

let grass_cost = 5
let warp_cost = 10

let at rows (pos : Tile_pos.t) =
  let row = if pos.y < 0 then None else List.nth_opt rows pos.y in
  match row with
  | Some row when pos.x >= 0 && pos.x < String.length row -> row.[pos.x]
  | _ -> '#'

let warp_target rows =
  let in_row y row =
    String.index_opt row 'X' |> Option.map (fun x -> { Tile_pos.x; y })
  in
  List.find_map Fun.id (List.mapi in_row rows)

let blocks tile direction =
  tile = '#' || (tile = 'v' && direction <> Direction.South)

let press rows pos direction =
  let next = Tile_pos.next pos direction in
  let tile = at rows next in
  if blocks tile direction || tile = 'p' then None
  else
    let step = Leg.plain_step next direction in
    Some
      (match tile with
      | '"' -> { step with extra_cost = grass_cost; wild = true }
      | 'C' -> { step with connection = true }
      | 'W' ->
          {
            step with
            next = Option.get (warp_target rows);
            warped = true;
            ends_leg = true;
            extra_cost = warp_cost;
          }
      | _ -> step)

let held_at rows pos direction =
  blocks (at rows (Tile_pos.next pos direction)) direction

let model rows =
  Step_model.simple ~compare_state:Tile_pos.compare ~press:(press rows)
    ~held_at:(held_at rows)

let describe_leg (leg : Tile_pos.t Leg.t) =
  let kind =
    match leg.kind with
    | Walk { tiles; to_wall } ->
        Printf.sprintf "walk %s %d%s"
          (Direction.name leg.direction)
          tiles
          (if to_wall then " (to wall)" else "")
    | Face -> "face " ^ Direction.name leg.direction
    | Action _ -> "action " ^ Direction.name leg.direction
  in
  Printf.sprintf "%s%s%s -> %s" kind
    (if leg.wild then " (wild)" else "")
    (if leg.warps then " (warp)" else "")
    (Tile_pos.to_string leg.finish)

let describe = function
  | None -> "no route"
  | Some legs -> String.concat "; " (List.map describe_leg legs)
