(** What a game supplies to run its plans: a handler for the engine's kinds and
    one for its own, one per game action it implements, and its checkpoint save
    and reload. Handlers run in the program's effect context (they press buttons
    and read the screen); the runner only orders them. *)

open Engine_plan

(** The game's handlers over its rules. *)
module Make (T : Engine_rules.GAME_RULES) (Raw : Plan.RAW) : sig
  type outcome = (unit, Failure.cause) result
  (** How a handler came out: [Error] with the game's cause. *)

  type game_action = Plan.Make(T)(Raw).event -> Raw.t -> outcome
  (** Runs one game action with the event's args, which the handler reads (and
      rejects with a {!Failure.cause} when they are wrong). *)

  type t = {
    run_own : Plan.Make(T)(Raw).event -> T.Kind.t -> outcome;
        (** An event of one of the game's own kinds, with its args. *)
    run_builtin : Plan.Make(T)(Raw).event -> outcome;
        (** An event of the engine's other kinds ([talk], [answer], [scene],
            [save]), told apart by [event.kind]. *)
    game_actions : (string * game_action) list;
        (** The game actions it implements, by name. *)
    flag_holds : string -> bool;
        (** Whether a flag an event's [skip_if] names holds now. *)
    position : unit -> T.Pose.observed option;
        (** Where the player is, or [None] when the game cannot tell; checked
            against an event's [declared_after]. *)
    between_rounds : unit -> outcome;
        (** What a repeated checkpoint does between its rounds (Pokémon: heal
            the party). *)
    save : unit -> outcome;  (** Save the game where the player stands. *)
    reload : unit -> outcome;  (** Go back to the last save. *)
    log : string -> unit;
  }
  (** The game's handlers. *)
end
