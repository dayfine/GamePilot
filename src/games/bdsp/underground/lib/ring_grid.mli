(** In-memory 2D tile grid for the right half of the central BDSP Grand
    Underground Hideaway ring, built directly on GamePilot's shared
    {!Grid_maps.Grid} and {!Grid_planning.Leg_planner}.

    Tile coordinates (width 16 x height 24, 3-tile-wide corridors):
    - [south_door]: [(1, 20)], North-wall track outside the South Hideaway
      doorway (dig spots never spawn on the South cutaway rim)
    - [north_door]: [(1, 1)], North-wall track outside the North Hideaway
      doorway
    - Bottom-East corridor: [x = 1..14, y = 20..22]
    - East vertical corridor: [x = 12..14, y = 1..22]
    - Top-East corridor: [x = 1..14, y = 1..3]

    Routes between any start tile, sparkle waypoints, and the nearest doorway
    are planned with {!Grid_planning.Leg_planner.plan}, producing standard
    wall-aligned {!Grid_planning.Leg.t} legs. *)

(** Cell type on the in-memory Grand Underground ring grid. *)
type cell =
  | Wall  (** Impassable tunnel rock wall (diggable where sparkling). *)
  | Floor  (** Walkable corridor floor tile. *)
  | Doorway  (** Hideaway entrance tile used to bounce and refresh sparkles. *)

(** The three corridor segments matching {!Bdsp_readers.Minimap_sparkles}. *)
type segment =
  | Bottom_east  (** Horizontal corridor East of the South doorway. *)
  | East_vertical  (** Vertical corridor along the East outer wall. *)
  | Top_east  (** Horizontal corridor West from NE corner to North doorway. *)

type stop = {
  tile : Grid_geometry.Tile_pos.t;
  legs : Grid_geometry.Tile_pos.t Grid_planning.Leg.t list;
  wall_dirs : Grid_geometry.Direction.t list;
}
(** One planned waypoint stop: the legs to reach [tile] and which adjacent
    directions are diggable walls at [tile]. *)

type route = {
  stops : stop list;
  return_door : Grid_geometry.Tile_pos.t;
  return_legs : Grid_geometry.Tile_pos.t Grid_planning.Leg.t list;
}
(** A full multi-waypoint route ending at the nearest Hideaway doorway. *)

val grid : cell Grid_maps.Grid.t
(** The in-memory 16x24 ring tile grid. *)

val south_door : Grid_geometry.Tile_pos.t
(** Tile on the North-wall track outside the South Hideaway doorway [(1, 20)].
*)

val north_door : Grid_geometry.Tile_pos.t
(** Tile on the outer-wall track outside the North Hideaway doorway [(1, 1)]. *)

val adjacent_walls : Grid_geometry.Tile_pos.t -> Grid_geometry.Direction.t list
(** All cardinal directions from [pos] that directly face a {!Wall} cell on
    {!grid}. *)

val waypoint_of_bucket :
  segment:segment -> bucket:int -> Grid_geometry.Tile_pos.t
(** Map a minimap sparkle [(segment, bucket)] ([0..3]) to its center walkable
    tile on {!grid}. *)

val plan_legs :
  start:Grid_geometry.Tile_pos.t ->
  goal:Grid_geometry.Tile_pos.t ->
  Grid_geometry.Tile_pos.t Grid_planning.Leg.t list option
(** Plan shortest wall-aligned {!Grid_planning.Leg.t} legs from [start] to
    [goal] on {!grid}. *)

val plan_route :
  start:Grid_geometry.Tile_pos.t ->
  waypoints:Grid_geometry.Tile_pos.t list ->
  route
(** Plan a route visiting each waypoint in order, then returning to whichever
    Hideaway doorway ([south_door] or [north_door]) is closest. *)
