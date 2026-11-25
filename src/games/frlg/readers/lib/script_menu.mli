(** Reader: a script's multichoice window and its selection arrow (pokefirered
    src/script_menu.c, DrawMultichoiceMenu): a white window, framed, with its
    rows 14 pixels apart and the arrow at its left edge, shown over the white
    text box that asked. Not in the fork. A window is placed by its inside's
    tiles: CreateWindowFromRect puts it one tile right of and below the script's
    [multichoice x, y], after DrawMultichoiceMenu moved it left to end by tile
    28. Measured on mGBA frames of the Seagallop sailor's list at One Island's
    harbor: the inside white from (144, 56) to (232, 104), the arrow in x
    145-150 from 2 pixels below each row's top (y 60-68 on the first). *)

type t
(** One multichoice window. *)

val make : prefix:string -> left:int -> top:int -> width:int -> rows:int -> t
(** The window whose inside starts at tile ([left], [top]) and is [width] tiles
    wide, with [rows] choices. Probe ids start with [prefix]. *)

val probes : t -> Wire.probe_spec list
(** The window's right margin, its arrow's row boxes and {!Dialog.probes}. *)

val cursor_row : t -> Effects.measurements -> int option
(** The arrow's row from 0 at the top while the window shows: the text box up,
    the inside's right margin white beside every row, one row clearly holding
    the arrow ({!Cursor_column}). [None] otherwise. *)

val seagallop_islands : t
(** The Seagallop sailor's list of two islands and EXIT, at One or Two Island's
    harbor (pokefirered EventScript_ChooseDestFromOneIsland and
    ...FromTwoIsland: [multichoice 19, 6], MULTICHOICE_ISLAND_23 and _13). THREE
    ISLAND is the widest row of both, so the window is 11 tiles wide, moved left
    to end by tile 28: its inside starts at tile (18, 7). Three rows. *)
