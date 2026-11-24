(** The moves FRLG's TMs and HMs teach, as the TM case shows them, from the file
    [src/games/frlg/assets/extract/extract_frlg_tm_moves.py] writes. A TM case
    row shows one of these names, so they are its candidates rather than every
    move. *)

type t

val of_string : string -> t
(** Parses the file's text. Raises [Failure] on a malformed line. *)

val load : string -> t

val names : t -> string list
(** The move names in item order: TM01 .. TM50, then HM01 .. HM08. *)
