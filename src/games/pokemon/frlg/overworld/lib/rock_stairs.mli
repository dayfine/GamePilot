(** FireRed's rock stairs: the tiles a step slows down on. Walking or running
    north off one, or south onto one, the game moves the player with its slow
    movement (pokefirered's [PlayerIsMovingOnRockStairs] in
    src/field_player_avatar.c); east or west it does not. The tiles come from
    src/games/pokemon/frlg/assets/rock_stairs.txt, which
    src/games/pokemon/frlg/assets/extract/extract_frlg_rock_stairs.py writes
    from the decomp's layouts, as the PokemonSimulation maps do not mark them.

    Measured on mGBA (2026-11-23, Indigo Plateau's stairs at rows 14, 16 and 18
    and Route 23's row 0): a slow step takes 11 frames running (8 otherwise) and
    23 walking (16), and the steps between them take their normal time. *)

type t

val none : t
(** No rock stairs anywhere. *)

val asset : string
(** The asset's path from the repo root. *)

val parse : string -> (t, string) result
(** The asset's text: [#] comment lines, then one line per map,
    [<map> <x>,<y> ...]. *)

val load : string -> (t, string) result
(** {!parse} of a file. *)

val on : t -> map:string -> Grid_geometry.Tile_pos.t -> bool
(** Whether the map has a rock stair on the tile. *)
