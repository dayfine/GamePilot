(** Readers: FireRed's Start menu and its cursor. Ported from the fork's
    Menus/PokemonFRLG_StartMenuDetector: the menu's white frame along its top
    and left edges, and the selection arrow in one of its rows
    (PokemonFRLG_SelectionArrowDetector's row boxes, which the fork finds by
    waterfill on a template; here {!Cursor_column} counts the arrow's dark
    pixels per row). The boxes are the fork's, relative to the game picture.

    The menu has up to seven rows (POKéDEX, POKéMON, BAG, the player's name,
    SAVE, OPTION, EXIT); before the Pokédex or the first Pokémon it has fewer,
    from the same top, and the Safari Zone's starts with RETIRE. The reader
    gives the row on screen; what that row is depends on the menu. Only the rows
    the menu reaches count (its white left edge beside them): below a short menu
    the overworld can be dark. *)

val probes : Wire.probe_spec list

val cursor : Cursor_column.t
(** The seven row boxes left of the names. *)

val start_menu_open : Effects.measurements -> bool
(** The white top and left edges, with the arrow in a row. *)

val cursor_row : Effects.measurements -> int option
(** The arrow's row from 0 at the top while the menu is open; [None] when it is
    not. *)
