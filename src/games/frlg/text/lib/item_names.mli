(** FRLG item names by bag pocket, as the bag shows them, from the file
    [src/games/frlg/assets/extract/extract_frlg_item_names.py] writes. A bag
    reader draws only the open pocket's names: that pocket's list is all a row
    can show. *)

type pocket = Items | Key_items | Poke_balls | Tm_case | Berry_pouch
type t

val of_string : string -> t
(** Parses the file's text. Raises [Failure] on an unknown pocket. *)

val load : string -> t

val in_pocket : t -> pocket -> string list
(** The pocket's names in the game's item order. *)
