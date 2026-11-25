open Grid_maps
open Grid_geometry

let open_leg_shortfall = 2

let shifted (place : Connected_maps.place) d n =
  let rec go tile n =
    if n = 0 then tile else go (Tile_pos.next tile d) (n - 1)
  in
  { place with tile = go place.tile n }

(* The tiles up to [open_leg_shortfall] past and short of [place] along [d]. *)
let around (place : Connected_maps.place) d =
  let back = Direction.opposite d in
  List.init open_leg_shortfall (fun i -> i + 1)
  |> List.concat_map (fun n -> [ shifted place d n; shifted place back n ])

let ended_open (before : Connected_maps.place Grid_planning.Leg.t) start =
  let open_walk =
    match before.kind with Walk { to_wall; _ } -> not to_wall | _ -> false
  in
  open_walk && (not before.warps)
  && Connected_maps.compare_place before.finish start = 0

let possible_starts ~before (leg : Connected_maps.place Grid_planning.Leg.t) =
  match before with
  | Some before when ended_open before leg.start ->
      leg.start :: around leg.start before.direction
  | _ -> [ leg.start ]

(* The step a hold takes from [place]: a plain one on the same map. *)
let plain_step w (place : Connected_maps.place) d =
  match Frlg_steps.press w place d with
  | Some step when (not step.warped) && step.next.map = place.map ->
      Some step.next
  | _ -> None

(* The last place a hold from [start] reaches in [presses] plain steps. *)
let rec held_from w start d presses =
  if presses = 0 then start
  else
    match plain_step w start d with
    | Some next -> held_from w next d (presses - 1)
    | None -> start

let standable w (place : Connected_maps.place) =
  let map = Connected_maps.map w.Frlg_steps.maps place.map in
  match Grid.find map.tiles place.tile with
  | Some (Open | Tall_grass) -> true
  | _ -> false

let leg_tiles (leg : Connected_maps.place Grid_planning.Leg.t) =
  match leg.kind with Walk { tiles; _ } -> tiles | Special_step _ | Face -> 0

(* Where a hold of [leg] from [start] stops before a sign, if it does. *)
let stop_before_sign w (leg : Connected_maps.place Grid_planning.Leg.t) start =
  let stop =
    held_from w start leg.direction (leg_tiles leg + open_leg_shortfall)
  in
  if standable w start && Frlg_steps.sign_ahead w stop leg.direction then
    Some stop
  else None

let add_new found stop =
  if List.exists (fun p -> Connected_maps.compare_place p stop = 0) found then
    found
  else found @ [ stop ]

let stops w starts leg =
  List.filter_map (stop_before_sign w leg) starts |> List.fold_left add_new []
