(** A looped checkpoint: run its events as one bounded batch per round, do what
    the game does between rounds (Pokémon: heal) and save after each round,
    until the goal holds.

    The checkpoint starts and ends at the same place (its save point), so every
    round can save there. A round that fails reloads the last save and runs
    again, losing less than one round of progress; the goal is checked before
    each round against the world itself, so a run started from any of the loop's
    saves (after a crash or a later reload) picks up where that save stands, and
    one whose goal already holds runs no round. *)

open Engine_plan

(** The loop over the game's rules. *)
module Make (T : Engine_rules.GAME_RULES) (Raw : Plan.RAW) : sig
  type limits = {
    max_rounds : int;  (** Rounds to run before giving up; at least 1. *)
    attempts_per_round : int;
        (** Runs of one round, counting the first, each after a reload; at least
            1. *)
  }

  (** What between rounds failed. *)
  type chore =
    | Goal_check
    | Between_rounds
        (** The game's {!Game.Make.t.between_rounds}, logged as ["heal"]. *)
    | Save
    | Reload

  type stop =
    | Round_failed of {
        round : int;
        attempts : int;
        failure : Failure.Make(T).t;
      }  (** The round failed on its last attempt, or in a way that repeats. *)
    | Chore_failed of { round : int; chore : chore; cause : Failure.cause }
    | Limit_reached of { rounds : int }
        (** [max_rounds] rounds passed and the goal still does not hold. *)

  val run :
    limits ->
    goal:(unit -> (bool, Failure.cause) result) ->
    say:(Log_line.Make(T).t -> unit) ->
    Game.Make(T)(Raw).t ->
    Plan.Make(T)(Raw).checkpoint ->
    (int, stop) result
  (** Rounds until [goal ()] holds; [Ok rounds] is how many ran. Each round's
      lines, and the runner's, go to [say] ({!Runner.Make.run}). Raises
      [Invalid_argument] when a limit is below 1. A stop is printed by
      [Engine_text.Run_text.stop]. *)
end
