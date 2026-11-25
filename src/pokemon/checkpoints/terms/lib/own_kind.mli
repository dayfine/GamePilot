(** The event kinds Pokémon games run beside the engine's own: walks on the tile
    grid, battles, healing, shopping, and the opening's new game and options, as
    FireRed runs them. Each kind's args are typed here; [Kind_decode] fills in
    the format's fallbacks. *)

type leg = { direction : Grid_geometry.Direction.t; tiles : int }
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
  | Step of Grid_geometry.Direction.t
      (** One step or turn toward the direction. *)
  | Battle of { may_lose : bool }
  | Train of int  (** Fight this many trainer battles. *)
  | Heal
  | Shop of item list
