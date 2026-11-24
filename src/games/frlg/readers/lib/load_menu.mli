(** Reader: the load menu after the title (CONTINUE over NEW GAME), ported from
    the fork's Menus/PokemonFRLG_LoadMenuDetector ([frlg/lean]): the blue
    columns down the screen's left and right edges and the white CONTINUE
    window's top right corner, each one flat color. The boxes and the colors are
    the fork's, relative to the game picture. *)

val probes : Wire.probe_spec list

val load_menu_open : Effects.measurements -> bool
(** The two blue edges and the white window corner. *)
