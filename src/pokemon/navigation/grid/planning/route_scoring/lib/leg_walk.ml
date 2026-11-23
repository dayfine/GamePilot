type t = {
  path : Tile_pos.t list;
  ends : Tile_pos.t list;
  ms : int;
  stop : bool;
  unsafe : string option;
}

let distance (a : Tile_pos.t) (b : Tile_pos.t) =
  abs (a.x - b.x) + abs (a.y - b.y)

let path_tiles from path =
  fst
    (List.fold_left
       (fun (tiles, at) p -> (tiles + distance at p, p))
       (0, from) path)

let last_or from path =
  match List.rev path with last :: _ -> last | [] -> from

let to_wall (map : Score_map.t) (paces : Route_paces.t) from
    (leg : Scored_leg.t) =
  let path = Score_map.walk_steps map from leg.direction ~most:max_int in
  let last = last_or from path in
  let stop = path = [] || not (Score_map.stops_on (map.risk last)) in
  let ms =
    paces.start_ms
    + (path_tiles from path * paces.ms_per_tile leg.direction ~run:leg.run)
    + if stop then paces.stop_ms else 0
  in
  { path; ends = [ last ]; ms; stop; unsafe = None }

let taps (map : Score_map.t) (paces : Route_paces.t) from (leg : Scored_leg.t) =
  let path = Score_map.walk_steps map from leg.direction ~most:leg.tiles in
  let last = last_or from path in
  let walked = List.length path in
  let blocked =
    walked < leg.tiles && (path = [] || not (Score_map.stops_on (map.risk last)))
  in
  (* A blocked walk of taps ends after two taps that move nothing. *)
  let taps = walked + if blocked then 2 else 0 in
  {
    path;
    ends = [ last ];
    ms = taps * paces.tap_ms;
    stop = false;
    unsafe = None;
  }

(* Why a tile in a held leg's uncertain end must not be reached, if it must
   not. *)
let unsafe_overshoot (map : Score_map.t) ~goal before pos =
  let at what =
    Some (Printf.sprintf "%s at %s" what (Tile_pos.to_string pos))
  in
  if distance before pos > 1 then at "a ledge hop"
  else
    match map.risk pos with
    | No_risk -> None
    | Trigger -> if goal pos then None else at "a trigger"
    | Warp -> if goal pos then None else at "a warp"
    | Encounter -> at "grass"
    | Wanderer -> at "a wanderer's tile"
    | Sight -> at "a trainer's sight"

(* The first unsafe tile past the [fewest]th of [all], walked from [from]. *)
let first_unsafe map ~goal from all fewest =
  let rec scan k before = function
    | [] -> None
    | pos :: rest -> (
        let found =
          if k > fewest then unsafe_overshoot map ~goal before pos else None
        in
        match found with Some _ -> found | None -> scan (k + 1) pos rest)
  in
  scan 1 from all

let open_hold (map : Score_map.t) (paces : Route_paces.t) ~goal from
    (leg : Scored_leg.t) =
  let error =
    match paces.open_hold_error with Some f -> f leg.tiles | None -> 0
  in
  let all =
    Score_map.walk_steps map from leg.direction ~most:(leg.tiles + error)
  in
  (* A hold stopped before its shortest end ends where it is stopped. *)
  let fewest = min (max 0 (leg.tiles - error)) (List.length all) in
  let path = List.filteri (fun i _ -> i < fewest) all in
  let ends = List.filteri (fun i _ -> i >= fewest) (from :: all) in
  {
    path;
    ends;
    ms =
      paces.start_ms + (leg.tiles * paces.ms_per_tile leg.direction ~run:leg.run);
    stop = false;
    unsafe = first_unsafe map ~goal from all fewest;
  }

let walk map (paces : Route_paces.t) ~goal from (leg : Scored_leg.t) =
  let walked =
    match leg.kind with
    | To_wall -> to_wall map paces from leg
    | Taps -> taps map paces from leg
    | Open_hold -> open_hold map paces ~goal from leg
  in
  { walked with ms = walked.ms + paces.press_ms }
