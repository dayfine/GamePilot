(** How a game prints its rules ({!Engine_rules.GAME_RULES}) in a log line, a
    failure or a plan's text. Only the edges use it: {!Plan_text},
    {!Failure_text} and {!Run_text}, which print what the runner and the checks
    keep as values. *)

(** A game's text, over its rules [T]. *)
module type TEXT = sig
  module T : Engine_rules.GAME_RULES

  val pose : T.Pose.t -> string
  (** A plan's pose: ["CeladonCity (48, 12) south"]. *)

  val observed : T.Pose.observed -> string
  (** Where the player was read. *)

  val kind : T.Action.t -> string
  (** One of the game's actions with its args, its name first:
      ["route to Town (4, 0) north"]. *)

  val postconditions : T.Postconditions.t -> string list
  (** The promises, one per line, in the order the plan's text gives them. *)
end
