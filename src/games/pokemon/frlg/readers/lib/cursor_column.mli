(** A menu's selection arrow: which box of a column of row boxes holds it.
    Ported from the fork's read_item_list_cursor_row
    (Menus/PokemonFRLG_ItemListReader): one [core.color_count@1] probe per row,
    left of the row's text, counts the dark pixels (every channel at most
    {!dark_max}); the row with the largest share is the cursor's when that share
    is at least {!min_share} and {!min_lead} times the next row's. The menu's
    white or cream background and its text right of the box count as nothing. *)

type t
(** A column of rows, top first. *)

val make : prefix:string -> Wire.box list -> t
(** Probe ids are [prefix ^ ".row" ^ index]. *)

val probes : t -> Wire.probe_spec list

(** {1 Thresholds} *)

val dark_max : int
(** The arrow's dark grey and its shadow: channels up to this (the fork's 150).
*)

val min_share : float
(** The fork's 0.10. Measured: the arrow fills 0.14-0.39 of its row's box on
    Switch and mGBA, an empty row's box 0. *)

val min_lead : float
(** The fork's 3. *)

(** {1 Reader} *)

val row : ?rows:int -> t -> Effects.measurements -> int option
(** The arrow's row from 0 at the top, among the first [rows] (default all);
    [None] when no row holds it clearly or a probe is missing. *)
