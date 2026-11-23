open Grid_maps
open Grid_planning

type costs = { grass : int; warp : int; wander : int; trainer_line : int }

let default_costs = { grass = 3; warp = 10; wander = 8; trainer_line = 100 }

type world = {
  maps : Connected_maps.t;
  hidden : Map_features.map_object -> bool;
  costs : costs;
}

let world ?(hidden = fun _ -> false) maps =
  { maps; hidden; costs = default_costs }

let map_of w (place : Connected_maps.place) =
  Connected_maps.map w.maps place.map

let tile_at (map : Map_data.t) pos = Grid.find map.tiles pos

let object_at w (map : Map_data.t) pos =
  List.find_opt
    (fun (o : Map_features.map_object) ->
      Tile_pos.equal o.object_pos pos && not (w.hidden o))
    map.objects

let in_box (box : Map_features.tile_box) (pos : Tile_pos.t) =
  pos.x >= box.top_left.x
  && pos.x <= box.bottom_right.x
  && pos.y >= box.top_left.y
  && pos.y <= box.bottom_right.y

let wander_at w (map : Map_data.t) pos =
  List.exists
    (fun (o : Map_features.map_object) ->
      (not (w.hidden o))
      && match o.wander with Some box -> in_box box pos | None -> false)
    map.objects

(* Whether a trainer standing still and looking one way sees [pos]: one of the
   [sight] tiles ahead of them, up to a wall. *)
let in_line_of (map : Map_data.t) pos (o : Map_features.map_object) =
  match (o.trainer, o.wander) with
  | Some { sight; looks = [ look ] }, None ->
      let rec sees tile n =
        n > 0
        &&
        let seen = Tile_pos.next tile look in
        match tile_at map seen with
        | Some (Wall | Outside) | None -> false
        | Some _ -> Tile_pos.equal seen pos || sees seen (n - 1)
      in
      sees o.object_pos sight
  | _ -> false

let in_trainer_line w (map : Map_data.t) pos =
  List.exists (fun o -> (not (w.hidden o)) && in_line_of map pos o) map.objects

(* Whether a tile can be stepped onto moving [d], on foot. *)
let enterable kind d =
  match (kind : Tile_kind.t) with
  | Open | Tall_grass | Stop_spin | Strength_button -> true
  | Closed_side side -> side <> Direction.opposite d
  | Wall | Water | Ledge _ | Door | Sign | Outside | Spin _ | Fall_hole | Ice
  | Thin_ice | Gate ->
      false

let leaves kind d =
  match (kind : Tile_kind.t) with Closed_side side -> side <> d | _ -> true

(* The warp the player takes on a press, and how. *)
let exit_mat (map : Map_data.t) here d =
  match Map_data.warp_at map here with
  | Some ({ enter = Walk way; _ } as warp) when way = d -> Some warp
  | _ -> None

let door_ahead (map : Map_data.t) ahead d =
  if d <> Direction.North then None
  else
    match (Map_data.warp_at map ahead, tile_at map ahead) with
    | Some ({ enter = Walk_into; _ } as warp), _ -> Some warp
    | Some warp, Some Door -> Some warp
    | _ -> None

let warps_on_step (warp : Map_features.warp) =
  match warp.enter with Step_on | Cave_entrance -> true | _ -> false

let walks_out (map : Map_data.t) pos =
  match (Map_data.warp_at map pos, tile_at map pos) with
  | Some { enter = Walk_into | Cave_entrance; _ }, _ | _, Some Door -> true
  | _ -> false

(* Where a warp leaves the player and which way they face, or [None] for one
   off the loaded maps. *)
(* Where an arrival leaves the player and which way they face, pressing [d]. *)
let arrive w (arrival : Connected_maps.place) d =
  let map = Connected_maps.map w.maps arrival.map in
  if walks_out map arrival.tile then
    ({ arrival with tile = Tile_pos.next arrival.tile South }, Direction.South)
  else
    match Map_data.warp_at map arrival.tile with
    | Some { enter = Walk way; _ } -> (arrival, Direction.opposite way)
    | _ -> (arrival, d)

let warp_step w (next, facing) d =
  let step = Leg.plain_step next d in
  {
    step with
    warped = true;
    ends_leg = true;
    facing;
    extra_cost = w.costs.warp;
  }

let take_warp w warp d =
  Connected_maps.warp_arrival w.maps warp
  |> Option.map (fun arrival -> warp_step w (arrive w arrival d) d)

let costed w (place : Connected_maps.place) (next : Connected_maps.place) d =
  let map = map_of w next in
  let grass = tile_at map next.tile = Some Tall_grass in
  let step = Leg.plain_step next d in
  {
    step with
    wild = grass;
    connection = next.map <> place.map;
    extra_cost =
      ((if grass then w.costs.grass else 0)
      + (if wander_at w map next.tile then w.costs.wander else 0)
      + if in_trainer_line w map next.tile then w.costs.trainer_line else 0);
  }

(* Where a step onto [target] (on [place]'s map or across its edge) lands:
   over a ledge walked into its way, two tiles on. *)
let landing w d (target : Connected_maps.place) =
  let map = map_of w target in
  let free (p : Connected_maps.place) =
    match tile_at map p.tile with
    | Some kind -> enterable kind d && Option.is_none (object_at w map p.tile)
    | None -> false
  in
  match tile_at map target.tile with
  | Some (Ledge way) when way = d ->
      let beyond = { target with tile = Tile_pos.next target.tile d } in
      if free beyond then Some beyond else None
  | _ -> if free target then Some target else None

(* The step onto [target], taking a warp the player lands on. *)
let step_onto w place d target =
  Option.bind (landing w d target) (fun (p : Connected_maps.place) ->
      match Map_data.warp_at (map_of w p) p.tile with
      | Some warp when warps_on_step warp -> take_warp w warp d
      | _ -> Some (costed w place p d))

let press w (place : Connected_maps.place) d =
  let map = map_of w place in
  let ahead = Tile_pos.next place.tile d in
  match (exit_mat map place.tile d, door_ahead map ahead d) with
  | Some warp, _ | None, Some warp -> take_warp w warp d
  | None, None ->
      let here =
        Option.value (tile_at map place.tile) ~default:Tile_kind.Open
      in
      if not (leaves here d) then None
      else if Grid.contains map.tiles ahead then
        step_onto w place d { place with tile = ahead }
      else
        Option.bind
          (Connected_maps.across_edge w.maps place d)
          (step_onto w place d)

let warp_off_maps w (place : Connected_maps.place) d =
  let map = map_of w place in
  let ahead = Tile_pos.next place.tile d in
  let warp =
    match (exit_mat map place.tile d, door_ahead map ahead d) with
    | Some warp, _ | None, Some warp -> Some warp
    | None, None -> (
        match Map_data.warp_at map ahead with
        | Some warp when warps_on_step warp -> Some warp
        | _ -> None)
  in
  match warp with
  | Some warp -> Option.is_none (Connected_maps.warp_arrival w.maps warp)
  | None -> false

let sign_read map ahead d =
  tile_at map ahead = Some Tile_kind.Sign
  && (d = Direction.North || d = Direction.South)

let stands_still (o : Map_features.map_object) =
  Option.is_none o.wander && Option.is_none o.trainer

let edge_leads_on (map : Map_data.t) d =
  List.exists (fun (c : Map_features.connection) -> c.side = d) map.connections

(* Whether what stands ahead keeps a held player where they are. *)
let holds_ahead w (map : Map_data.t) ahead d =
  match tile_at map ahead with
  | Some (Ledge _) -> false
  | Some _ -> Option.fold ~none:true ~some:stands_still (object_at w map ahead)
  | None -> not (edge_leads_on map d)

let held_at w (place : Connected_maps.place) d =
  let map = map_of w place in
  let ahead = Tile_pos.next place.tile d in
  Option.is_none (press w place d)
  && (not (warp_off_maps w place d))
  && (not (sign_read map ahead d))
  && holds_ahead w map ahead d

let sign_ahead w (place : Connected_maps.place) d =
  sign_read (map_of w place) (Tile_pos.next place.tile d) d

let walked_out_onto w (place : Connected_maps.place) =
  let map = map_of w place in
  let doorway = Tile_pos.next place.tile North in
  Grid.contains map.tiles doorway && walks_out map doorway

let hop_tiles w (place : Connected_maps.place) d =
  let map = map_of w place in
  match tile_at map (Tile_pos.next place.tile d) with
  | Some (Ledge way) when way = d -> 2
  | _ -> 1

let model w =
  Step_model.simple ~compare_state:Connected_maps.compare_place ~press:(press w)
    ~held_at:(held_at w)
