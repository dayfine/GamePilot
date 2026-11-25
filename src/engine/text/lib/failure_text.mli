(** A failure ({!Engine_run.Failure.Make}) as text, its poses printed by the
    game's text. *)

(** Failures over the game's rules, printed by [X]. *)
module Make
    (T : Engine_rules.GAME_RULES)
    (_ : Rules_text.TEXT with module T = T) : sig
  val reason_to_string : Engine_run.Failure.Make(T).reason -> string
  (** ["declared end at <pose>, but the game reads <observed>"],
      ["postconditions unmet: coins: failed: expected 20, read 0; ..."], ... *)

  val to_string : Engine_run.Failure.Make(T).t -> string
  (** ["01-celadon-setup event 3 (talk_coin_case_man): no_text: ..."], the event
      counted from 1. *)
end
