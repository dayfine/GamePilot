(** The people on the ground floor of each standard Pokemon Center
    ({!Standard_center.centers}) but its nurse, who stands at (7, 2) in every
    one: pret's object events (pokefirered data/maps/<Center>/map.json at
    ce6406d8), without the invisible Pokemon Journals on the back wall.

    GamePilot's own: the fork's coded room has the nurse alone, and it is added
    only for Centers PokemonSimulation has no map of; their people were in those
    maps. With the coded room the one ground floor for all 17, they are listed
    here so that routes go round them. *)

(** How a person in a Center moves, as pret's object events give it. *)
type motion =
  | Faces of Grid_geometry.Direction.t  (** Stands still, facing that way. *)
  | Turns  (** Stands still, looking about. *)
  | Wanders of {
      min : Grid_geometry.Tile_pos.t;
      max : Grid_geometry.Tile_pos.t;
    }  (** May stand anywhere in the box. *)

type person = {
  name : string;  (** Its graphics, as PokemonSimulation's maps name it. *)
  at : Grid_geometry.Tile_pos.t;  (** Where it stands in the Center's room. *)
  motion : motion;
  script : string option;  (** Its pret script; none for Six Island's rival. *)
  hide_flag : string option;  (** The game hides it while this is set. *)
}
(** One person in a standard Center, an obstacle the walks go round. *)

val of_town : string -> person list
(** The people of the town's Center (["CinnabarIsland"]), in pret's order; none
    for a town without a standard Center. *)
