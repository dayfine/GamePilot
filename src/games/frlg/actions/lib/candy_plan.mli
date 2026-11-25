(** The Rare Candy actions as data: whom a candy goes to and what its level
    brings is answered with ({!Level_up_policy.policy}: which offered moves it
    learns and over what, whether it may evolve), and a leveling goal on top of
    that ({!goal}). Pure: {!Rare_candy} and {!Candy_level} run them.

    A move is learned only where a rule names it: the game asks "Should a move
    be deleted and replaced with ...?" only when the member knows four moves
    already, and every move offered then that no rule names is declined. A move
    offered while a slot is free is learned by the game without asking
    (pokefirered party_menu.c, [MonTryLearningNewMove] giving it at once). *)

type use = { member : Action_args.member; policy : Level_up_policy.policy }

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

val decode_use : Json_field.obj -> (use, Checkpoints_run.Failure.cause) result
(** ["use_rare_candy"]'s args: ["species"] or ["target_slot"], ["evolve"] (true
    or false, required: an evolution is not undone), and an optional ["learn"],
    a list of [{"move": ..., "replacing": ...}]. [bad_args] naming the field. *)

val decode_goal : Json_field.obj -> (goal, Checkpoints_run.Failure.cause) result
(** ["candy_level"]'s args: {!decode_use}'s, ["target_level"] (2-100), and the
    optional ["expect_species"], ["expect_moves"] (a list of slugs) and
    ["max_candies"] (1-99, default {!default_max_candies}). *)

val describe_use : use -> string
(** One line: ["gastly, learn mean-look over lick, evolve"]. *)

val describe_goal : goal -> string
