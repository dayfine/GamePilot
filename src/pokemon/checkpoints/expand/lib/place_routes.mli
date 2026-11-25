(** Route targets that name a place, expanded into plain events when a plan is
    loaded, before it is decoded (Programs-As-Goals section 3). A pure rewrite
    of the plan's JSON ({!Plan_json}): the runner, logs, event states and the
    watch page see plain events. The game gives its places and its rides.

    A route whose [args.target] is [{"place": NAME}] becomes a route to the
    place's spot. When the game says the walk needs a ride (a lift to another
    floor), it becomes the route (same id) to where the ride starts, the ride
    ([ID.<suffix>], declaring where it lets the player out), and [ID.walk] from
    there to the place; the walk is left out when the ride lets the player out
    on the place itself.

    Where the player stands is reckoned along the plan: the checkpoint's
    [start], then each route's one-tile target, or else each event's one-tile
    [declared_after]. A place route needs it known. *)

type spot = {
  map : string;
  tile : Grid_maps.Tile_pos.t;
  facing : Grid_maps.Direction.t option;  (** [None]: any way, or not known. *)
}
(** Where the player stands, or where a route ends. *)

type ride = {
  start : spot;  (** Where the walk to the ride ends (below a lift door). *)
  event : Plan_json.fields;
      (** The ride's event but its id, why and [declared_after]: its kind,
          action and args. *)
  suffix : string;  (** The ride's id is the route's id, a dot, this. *)
  why : string;
  arrival : spot;  (** Where the ride lets the player out. *)
}
(** A ride a walk takes on the way: walk to [start], take the ride, walk on. *)

type game = {
  place : string -> (spot, string) result;
      (** The spot of the place of that name; an error says why there is none
          (an unknown name, with the nearest). *)
  ride : at:spot -> spot -> (ride option, string) result;
      (** The ride a walk from [at] to the spot takes, if it takes one. *)
}
(** What the expansion asks the game. *)

val expand :
  game -> source:string -> Yojson.Safe.t -> (Yojson.Safe.t, string) result
(** The plan with every place route expanded; a plan with none comes back as it
    was. Errors name [source] (the file) and the event: the game's, or an
    unknown position. *)
