(** Move names as FRLG shows them, from Packages' [BattleMovesOCR.json]
    ([{language: {slug: [names]}}]), read in place from the submodule. *)

type t = (string * string) list
(** (slug, name) in the file's order; the first name of each slug. *)

val of_json : language:string -> Yojson.Safe.t -> t

val load : language:string -> string -> t
(** [load ~language:"eng" path]. *)

val name : t -> string -> string option
(** The name of this slug. *)
