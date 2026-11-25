(** What a run logs and how it stops, as text: the runner's
    {!Engine_run.Log_line.Make} lines and a loop's stop
    ({!Engine_run.Repeat_until.Make.stop}), the game's rules in them printed by
    the game's text. *)

(** A run's text over the game's rules, printed by [X]. *)
module Make
    (T : Engine_rules.GAME_RULES)
    (_ : Rules_text.TEXT with module T = T) : sig
  val line : Engine_run.Log_line.Make(T).t -> string
  (** The line as logged: ["[Story] 01-celadon-setup end <pose>: holds"]. *)

  val stop :
    Engine_run.Repeat_until.Make(T)(Engine_plan_codec.Raw_json).stop -> string
  (** ["round 3 failed after 2 attempts: <failure>"],
      ["save failed in round 2: <cause>"], ["goal not met after 60 rounds"]. *)
end
