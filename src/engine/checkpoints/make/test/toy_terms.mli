(** A toy game's terms for the engine's tests: zones and no grid. *)

type pose = { place : string; spot : string option }
(** A place, and maybe a spot in it. *)

(** The toy's own kinds. *)
type own_kind =
  | Walk of { toward : string; until : string }
      (** Hold a direction until a landmark shows. *)
  | Rest  (** Rest at an inn. *)

type promises = { gold : Engine_promise.Count.t option; flags : string list }
(** Gold gained since the start, and flags set. *)

type reads = { gold_now : int option; start : int option; set : string list }
(** The gold now and at the start, and the flags set. *)

include
  Engine_terms.GAME_TERMS
    with type pose := pose
     and type observed = pose
     and type own_kind := own_kind
     and type promises := promises
     and type reads := reads
     and type start_reads = int option
