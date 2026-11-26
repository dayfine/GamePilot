(** The make-room checkpoint ("00-make-room"), generated before a chain's first
    checkpoint when the party has too few free slots ({!Party_room},
    {!Room_policy}): Fly to the Pokémon Center nearest the save, walk to its PC,
    deposit the policy's members ({!Frlg_actions.Pc_deposit}), walk out to the
    town's Fly landing. Its postconditions are its end check: the end there, the
    party left in order (so the free slots), and each needed field move still
    known by a member that knows it. GamePilot's own: the fork's AutoStory
    deposits at the PC steps its plans name. *)

val id : string
(** ["00-make-room"]: sorts before the chain's first checkpoint. *)

val pc_front : Grid_geometry.Tile_pos.t
(** (11, 2), facing north: below the PC (11, 1) on a standard Center's ground
    floor ({!Frlg_overworld.Standard_center.pc_front}). *)

type center = {
  town : Frlg_actions.Fly_towns.town;  (** The Fly town to fly to. *)
  map : string;
      (** Its standard Center's ground floor map, from the places table. *)
}
(** A Fly town and its standard Pokémon Center map. *)

val town_of_map :
  Frlg_actions.Fly_towns.t ->
  maps:Grid_maps.Connected_maps.t ->
  string ->
  Frlg_actions.Fly_towns.town option
(** The Fly town a map belongs to: the town (or its Fly landing map) itself, or
    the town reached by indoor warps from an indoor map in [maps]. *)

val nearest_center :
  Frlg_actions.Fly_towns.t ->
  places:Frlg_places.Place_table.t ->
  maps:Grid_maps.Connected_maps.t ->
  string ->
  (center, string) result
(** The Fly town with a standard Center ({!Frlg_overworld.Standard_center}) in
    [places] and [maps] whose fly-map cell is nearest (by squared distance; the
    table's order breaks ties) to the town of the save's map: Viridian City from
    Pallet Town, which has no Center. The Indigo Plateau's Center has its own
    layout, with no PC at {!pc_front}, so it is never chosen. *)

type room = {
  center : center;
  deposits : Room_policy.plan;
  party : Room_policy.member list;  (** As read, slot 1 first. *)
  needed_moves : string list;  (** Field moves the chain needs. *)
}
(** Inputs to build the ["00-make-room"] checkpoint plan. *)

val room_plan : room -> Yojson.Safe.t
(** The checkpoint as a plan file ([gamepilot-checkpoint/1]). *)
