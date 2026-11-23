(** What a tile is, for walking. Map files write each kind as one glyph
    (PokemonSimulation's [tile-legend.json]); the glyph is in brackets. *)

type t =
  | Wall  (** [#] *)
  | Open  (** [.] *)
  | Tall_grass  (** [~] open, with wild encounters *)
  | Water  (** [w] *)
  | Ledge of Direction.t
      (** [^ v < >] a wall, except that walking into it the arrow's way hops the
          player over it *)
  | Door  (** [D] a door or warp tile walked into *)
  | Sign  (** [S] a sign, read by facing it *)
  | Outside
      (** [' '] no map of the game's here (a map's rectangle reaching past the
          game's own) *)
  | Closed_side of Direction.t
      (** [8 2 4 6] (north, south, west, east, as on a number pad) open, but not
          crossed through that side: not entered from it, nor left through it *)
  | Spin of Direction.t
      (** [u d l r] open; stepping on it slides the player that way (Rocket
          Hideout and Viridian Gym spin tiles) *)
  | Stop_spin  (** [o] open; where a spin's slide stops *)
  | Fall_hole  (** [H] open; a hole that drops the player a floor *)
  | Strength_button  (** [B] open; Victory Road's switch for a boulder *)
  | Ice  (** [i] the player slides until something stops them *)
  | Thin_ice
      (** [I] cracks on the first step, drops the player on the second *)
  | Gate
      (** [G] a wall until the story opens it: the map's gates name it, and
          {!Gate_state} says whether it is open *)

val of_glyph : char -> t option
(** The tile a glyph stands for, or [None] if it is not a tile glyph. *)

val glyph : t -> char
(** The glyph map files write for a tile. *)

val glyphs : string
(** Every tile glyph, one per kind. *)
