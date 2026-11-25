(** A game's rules, as the checkpoint engine's plans, runner and checks carry
    them: where the player stands, the game's own event kinds, and what a
    checkpoint promises ([docs/design/Engine-Boundary.md], section 2). Pure: no
    JSON and no text. How a plan writes them is the game's
    {!Engine_plan_codec.Plan_codec.PLAN_CODEC}, how a log prints them its
    {!Engine_text.Terms_text.TEXT}, and what a run keeps on disk its
    {!Engine_saved.Event_states.SAVED}; the engine is applied to all four once
    per game family ([Engine_checkpoints.Make]). *)

(** Where a plan says the player stands, and where the game reads them. *)
module type POSE = sig
  type t
  (** Where a plan says the player stands: a checkpoint's [start], an event's
      [declared_after] (a grid pose, a zone). *)

  type observed
  (** Where the game reads the player to be. *)

  val matches : t -> observed -> bool
  (** Whether the player read stands where the pose says. A pose the game does
      not check holds wherever the player is. *)
end

(** The game's own event kinds. *)
module type KIND = sig
  type t
  (** The game's own event kinds with their args (route, battle, heal; walk,
      rest), beside the engine's [talk], [answer], [scene], [save] and
      [game_action]. *)
end

(** What a checkpoint promises, and its check. *)
module type PROMISES = sig
  type t
  (** What a checkpoint promises once its events are done: the plan's
      [metadata.postconditions], and a repeat's [until]. *)

  type reads
  (** What the game read for those promises, with what it read at the
      checkpoint's start for a promise of a change. *)

  val check : t -> reads -> Engine_promise.Promise.result list
  (** One result per promise, in the order they are logged. *)
end

(** The rules a game family gives the engine. *)
module type TERMS = sig
  module Pose : POSE
  module Kind : KIND
  module Promises : PROMISES
end
