(** The make-room checkpoint ("mg-00 make room"), generated before a chain's
    first checkpoint when the party has too few free slots ({!Party_room},
    {!Story.Room_policy}): Fly to the Pokémon Center nearest the save, walk to
    its PC, deposit the policy's members ({!Frlg_actions.Pc_deposit}), walk out
    to the town's Fly landing. Its postconditions are its end check: the end
    there, the party left in order (so the free slots), and each needed field
    move still known by a member that knows it. GamePilot's own: the fork's
    AutoStory deposits at the PC steps its plans name. *)

val id : string
(** ["mg-00"]: sorts before the chain's first checkpoint. *)

val center_map : string -> string
(** ["ViridianCity"] -> ["ViridianCity_PokemonCenter_1F"]. *)

val pc_front : Grid_maps.Tile_pos.t
(** (11, 2), facing north: below the PC (11, 1) on every Center's ground floor
    of the maps (PokemonSimulation's [CeruleanCity_PokemonCenter_1F] names it
    [pc]). *)

val town_of_map :
  Frlg_actions.Fly_towns.t -> string -> Frlg_actions.Fly_towns.town option
(** The Fly town a map belongs to: the town itself, or the town whose name
    begins the map's (["PalletTown_PlayersHouse_1F"] is Pallet Town's). *)

val nearest_center :
  Frlg_actions.Fly_towns.t ->
  maps:string list ->
  string ->
  (Frlg_actions.Fly_towns.town, string) result
(** The Fly town with a Center in [maps] whose fly-map cell is nearest (by
    squared distance; the table's order breaks ties) to the town of the save's
    map: Viridian City from Pallet Town, which has no Center. *)

type room = {
  center : Frlg_actions.Fly_towns.town;
  fly_user : string;  (** A member that knows Fly. *)
  deposits : Story.Room_policy.plan;
  party : Story.Room_policy.member list;  (** As read, slot 1 first. *)
  needed_moves : string list;  (** Field moves the chain needs. *)
}

val plan_json : room -> Yojson.Safe.t
(** The checkpoint as a plan file ([pokesim-authored-checkpoint/1]). *)
