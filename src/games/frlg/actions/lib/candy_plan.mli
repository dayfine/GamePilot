(** The Rare Candy actions as data: whom a candy goes to, which offered moves it
    learns and over what, and whether it may evolve ({!use}); and a leveling
    goal on top of that ({!goal}). Pure: {!Rare_candy} and {!Candy_level} run
    them.

    A move is learned only where a rule names it: the game asks "Should a move
    be deleted and replaced with ...?" only when the member knows four moves
    already, and every move offered then that no rule names is declined. A move
    offered while a slot is free is learned by the game without asking
    (pokefirered party_menu.c, [MonTryLearningNewMove] giving it at once). *)

type move_rule = {
  learn : string;  (** the move offered, a slug *)
  replacing : string;  (** the known move it is learned over, a slug *)
}

type use = {
  member : Action_args.member;
  rules : move_rule list;  (** in the plan's order; the first match is taken *)
  evolve : bool;  (** let an evolution run; else cancel it with B *)
}

type goal = {
  use : use;
  target_level : int;
  species : string option;
      (** the member's species at the end, read on its summary *)
  moves : string list;  (** moves it must know at the end *)
  max_candies : int;  (** candies at most *)
}

val max_level : int
(** 100: a candy on a Lv 100 member "won't have any effect". *)

val default_max_candies : int
(** 99, from Lv 1 to 100. *)

val decode_use : Grid_maps.Json_field.obj -> (use, Story.Failure.cause) result
(** ["use_rare_candy"]'s args: ["species"] or ["target_slot"], ["evolve"] (true
    or false, required: an evolution is not undone), and an optional ["learn"],
    a list of [{"move": ..., "replacing": ...}]. [bad_args] naming the field. *)

val decode_goal : Grid_maps.Json_field.obj -> (goal, Story.Failure.cause) result
(** ["candy_level"]'s args: {!decode_use}'s, ["target_level"] (2-100), and the
    optional ["expect_species"], ["expect_moves"] (a list of slugs) and
    ["max_candies"] (1-99, default {!default_max_candies}). *)

val rule_for : move_rule list -> offered:string -> move_rule option
(** The first rule that learns the move offered. *)

val describe_use : use -> string
(** One line: ["gastly, learn mean-look over lick, evolve"]. *)

val describe_goal : goal -> string
