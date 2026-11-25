(** The event kinds Pokémon games run beside the engine's own: walks on the tile
    grid, battles, healing, shopping, and the opening's new game and options, as
    FireRed runs them. Each kind's args are typed here, with the format's
    fallbacks filled in. *)

type leg = { direction : Grid_maps.Direction.t; tiles : int }
(** A straight walk of [tiles] tiles. *)

type item = { item : string; quantity : int }
(** [quantity] of the bag item [item] (a slug), to buy. *)

type route = { target : Pose.grid; fight_wild : bool }
(** A planned walk to [target]; [fight_wild] fights wild encounters on the way
    instead of running. *)

(** A Pokémon event kind, with its args. *)
type t =
  | New_game
  | Options
  | Route of route
  | Ready of Pose.grid  (** Walk to the pose and stand ready there. *)
  | Legs of { legs : leg list; fight_wild : bool }
      (** Walk these legs as written, without planning. *)
  | Step of Grid_maps.Direction.t  (** One step or turn toward the direction. *)
  | Battle of { may_lose : bool }
  | Train of int  (** Fight this many trainer battles. *)
  | Heal
  | Shop of item list

val decoder : string -> (where:string -> Json_field.obj -> t) option
(** The decoder of the kind of that name, given the event's [args] ([where]
    their prefix), or [None] when the name is not a Pokémon kind. It raises
    {!Json_field.Invalid} on an unknown arg, as on a malformed one. *)

val text : t -> string
(** The kind with its typed args, its name first:
    ["route to Town (4, 0) north"], ["battle (may lose)"],
    ["shop 2 retro-mail"]. *)
