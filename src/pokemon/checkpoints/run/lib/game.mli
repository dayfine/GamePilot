(** What a game supplies to run its plans: a handler for each kind of event, one
    per game action it implements, and its checkpoint save and reload. Handlers
    run in the program's effect context (they press buttons and read the
    screen); the runner only orders them. Types only. *)

open Checkpoints_plan

type outcome = (unit, Failure.cause) result

type game_action = Plan.event -> Json_field.obj -> outcome
(** Runs one game action with the event's args, which the handler reads (and
    rejects with a {!Failure.cause} when they are wrong). *)

type t = {
  walk_route : Plan.event -> Plan.route -> outcome;
      (** A [route] event: plan and walk the way to its target. *)
  run_builtin : Plan.event -> outcome;
      (** Every other built-in kind ([ready], [legs], [step], [talk], [answer],
          [scene], [battle], [train], [heal], [shop], [save], [new_game],
          [options]), told apart by [event.kind]. *)
  game_actions : (string * game_action) list;
      (** The game actions it implements, by name. *)
  flag_holds : string -> bool;
      (** Whether a flag an event's [skip_if] names holds now. *)
  position : unit -> Pose.observed option;
      (** Where the player is, or [None] when the game cannot tell; checked
          against an event's [declared_after]. *)
  heal : unit -> outcome;  (** Heal the party (between loop rounds). *)
  save : unit -> outcome;  (** Save the game where the player stands. *)
  reload : unit -> outcome;  (** Go back to the last save. *)
  log : string -> unit;
}
