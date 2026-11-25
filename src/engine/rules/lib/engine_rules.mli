(** A game's rules, as the checkpoint engine's plans, runner and checks carry
    them: where the player stands, the game's actions (its event kinds), and
    what a checkpoint promises ([docs/design/Engine-Boundary.md], section 2).
    Pure: no JSON and no text. How a plan writes them is the game's
    {!Engine_plan_format.Plan_format.PLAN_FORMAT}, how a log prints them its
    {!Engine_text.Rules_text.TEXT}, and what a run keeps on disk its
    {!Engine_event_snapshot.Event_snapshot.SNAPSHOT}; the engine is applied to
    all four once per game family ([Program_engine.Make]). *)

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

(** The game's actions: its event kinds. *)
module type ACTION = sig
  type t
  (** The game's actions, its event kinds, with their args (route, battle, heal;
      walk, rest), beside the engine's [talk], [answer], [scene], [save] and
      [game_action]. *)
end

(** What a checkpoint promises, and its check. *)
module type POSTCONDITIONS = sig
  type t
  (** What a checkpoint promises once its events are done: the plan's
      [metadata.postconditions], and a repeat's [until]. *)

  type reads
  (** What the game read for those promises, with what it read at the
      checkpoint's start for a promise of a change. *)

  val check : t -> reads -> Engine_postcondition.Postcondition.result list
  (** One result per promise, in the order they are logged. *)
end

(** The rules a game family gives the engine. *)
module type GAME_RULES = sig
  module Pose : POSE
  module Action : ACTION
  module Postconditions : POSTCONDITIONS

  val ends_at : Action.t -> Pose.t option
  (** Where an action says it leaves the player (a route's target), or [None]
      when it says nothing: a checkpoint's declared end, failing a declared pose
      after its last event. *)

  val position : Postconditions.t -> Pose.t option
  (** The end position the promises name, if any: preferred over the declared
      end. *)
end

(** {2 Pieces}

    A game's rules are written by hand from pieces: a pose, action sets and a
    set of promises ([docs/design/Composable-Rules.md]). These are the engine's;
    each brings its plan format, text and event snapshot in those libraries. *)

module Story_action = Story_action
(** {!Story_action}: talk, answer, scene and save. *)

module Command_step = Command_step
(** {!Command_step}: a command's step, by name. *)

module Zone_pose = Zone_pose
(** {!Zone_pose}: a place, and maybe a spot in it. *)

module Promises = Promises
(** {!Promises}: a position plus a family's promises
    ({!Promises.With_position}). *)
