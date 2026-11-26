(** What a level-up is answered with, per member: which offered moves it learns
    and over what, and whether it may evolve. A battle levels several members at
    once ({!Level_up}), so the plan gives a policy per party slot or species,
    and a default. Pure. *)

type move_rule = {
  learn : string;  (** the move offered, a slug *)
  replacing : string;  (** the known move it is learned over, a slug *)
}

type policy = {
  rules : move_rule list;
      (** in the plan's order; the first that learns the move offered is taken,
          any move no rule names is declined *)
  evolve : bool;  (** let an evolution run; else cancel it with B *)
}

type t = {
  by_slot : (int * policy) list;  (** party slots from 1 *)
  by_species : (string * policy) list;  (** slugs *)
  default : policy;
}

val for_everyone : policy -> t
(** One policy for every member: no per-slot or per-species entries, only the
    default. What a Rare Candy uses, since it levels one member. *)

val decline_all : policy
(** No rules, no evolution. *)

val for_member : t -> slot:int -> species:string -> policy
(** The slot's policy, else the species', else the default. *)

val rule_for : move_rule list -> offered:string -> move_rule option

val describe_rule : move_rule -> string
(** ["mean-look over lick"]. *)
