(** The starter 01.04 picks, plza.autostory's [starter] option. Ported from the
    fork's Starter option (PokemonLZA_AutoStory.h and .cpp, and the walk's
    [to_starter] in PokemonLZA_AutoStoryActionTable.cpp;
    dayfine/Arduino-Source#644): 01.04's walk to the starter has Chikorita's
    legs, and Totodile's or Tepig's own walk replaces them, each 600 ms with the
    stick held at its angle (console B, 2026-11-20).

    Where it differs: the option's values are the starters' types ([grass],
    [fire], [water]), not the fork's names. *)

(** The three starters the fork's option offers. *)
type t =
  | Chikorita  (** grass, the fork's default *)
  | Tepig  (** fire *)
  | Totodile  (** water *)

val default : t
(** Chikorita, the fork's default: the plan's legs. *)

val tag : t -> string
(** ["grass"], ["fire"] or ["water"]: the option's value. *)

val name : t -> string
(** ["Chikorita"], ["Tepig"] or ["Totodile"]: for the log. *)

val of_tag : string -> t option
(** {!tag} read back. *)

val move : t -> Plza_rules.Walk_args.move option
(** The walk from 01.04's start to the starter: Totodile [[-50, 600]] and Tepig
    [[-34, 600]], both steered; [None] for Chikorita, whose walk is the plan's
    legs ([[-66, 600]] steered). *)

val aimed : t -> Plza_rules.Walk_args.t -> Plza_rules.Walk_args.t
(** A walk with [to_starter] set gets the starter's {!move} in place of its
    legs, keeping its wait before; any other walk, or Chikorita's, is as given.
*)

val decls : Run_options.declared list
(** plza.autostory's [starter] option: one of [grass], [fire] or [water],
    optional (not given: the plan's walk, Chikorita's). *)
