(** What a game gives the checkpoint engine so the engine's plans, runner and
    checks can carry the game's own parts: where the player stands, the game's
    own event kinds, what a checkpoint promises, and what a run keeps beside an
    event's save state ([docs/design/Engine-Boundary.md], section 2). The engine
    is applied to a game's terms once per game family
    ([Engine_checkpoints.Make]); the plan format does not change, and a kind
    name the engine does not know is the game's.

    Decoders take [where], the prefix of the object's fields
    (["f: checkpoint.events[2].args."]), as {!Json_field} readers do, and return
    an [Error] naming the field. *)

(** Where a plan says the player stands, and where the game reads them. *)
module type POSE = sig
  type t
  (** Where a plan says the player stands: a checkpoint's [start], an event's
      [declared_after] (a grid pose, a zone). *)

  type observed
  (** Where the game reads the player to be. *)

  val decode : where:string -> Json_field.obj -> (t, string) result
  (** A [start] or [declared_after] object. *)

  val matches : t -> observed -> bool
  (** Whether the player read stands where the pose says. A pose the game does
      not check holds wherever the player is. *)

  val text : t -> string
  (** The pose in a log line or a failure: ["CeladonCity (48, 12) south"]. *)

  val observed_text : observed -> string
  (** Where the player was read, in a log line or a failure. *)
end

(** The game's own event kinds. *)
module type KIND = sig
  type t
  (** The game's own event kinds with their args (route, battle, heal; walk,
      rest), beside the engine's [talk], [answer], [scene], [save] and
      [game_action]. *)

  val decode :
    string -> (where:string -> Json_field.obj -> (t, string) result) option
  (** The decoder of the kind of that name, given the event's [args] (unknown
      args are its errors), or [None] when the name is not one of the game's. *)

  val text : t -> string
  (** The kind with its args, its name first: ["route to Town (4, 0) north"]. *)
end

(** What a checkpoint promises, and its check. *)
module type POSTCONDITIONS = sig
  type t
  (** What a checkpoint promises once its events are done: the plan's
      [metadata.postconditions], and a repeat's [until]. *)

  type reads
  (** What the game read for those promises, with what it read at the
      checkpoint's start for a promise of a change. *)

  val decode : where:string -> Json_field.obj -> (t, string) result
  (** A [postconditions] or [until] object. *)

  val check : t -> reads -> Engine_postcondition.Postcondition.result list
  (** One result per promise, in the order they are logged. *)

  val text : t -> string list
  (** The promises, one per line, in the order the plan's text gives them. *)
end

(** What a run keeps beside an event's save state. *)
module type SAVED = sig
  type t
  (** What the game read at the checkpoint's start for a promise of a change
      (the money before a purchase), and where the player was reckoned to stand.
  *)

  val to_json : t -> Yojson.Safe.t
  (** The [<n>-<event>.json] kept beside the state. *)

  val of_json : Yojson.Safe.t -> (t, string) result
  (** What {!to_json} wrote. *)
end

(** The terms a game family gives the engine. *)
module type GAME_TERMS = sig
  module Pose : POSE
  module Kind : KIND
  module Postconditions : POSTCONDITIONS
  module Saved : SAVED
end
