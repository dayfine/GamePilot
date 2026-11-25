(** What a game gives the checkpoint engine so the engine's plans, runner and
    checks can carry the game's own parts: where the player stands, the game's
    own event kinds, and what a checkpoint promises
    ([docs/design/Engine-Boundary.md], section 2). The engine is applied to a
    game's terms once per game family ([Engine_checkpoints.Make]); the plan
    format does not change, and a kind name the engine does not know is the
    game's.

    Decoders take [where], the prefix of the object's fields
    (["f: checkpoint.events[2].args."]), as {!Json_field} readers do, and return
    an [Error] naming the field. *)

module type GAME_TERMS = sig
  type pose
  (** Where a plan says the player stands: a checkpoint's [start], an event's
      [declared_after] (a grid pose, a zone). *)

  type observed
  (** Where the game reads the player to be. *)

  type own_kind
  (** The game's own event kinds with their args (route, battle, heal; walk,
      rest), beside the engine's [talk], [answer], [scene], [save] and
      [game_action]. *)

  type promises
  (** What a checkpoint promises once its events are done: the plan's
      [metadata.postconditions], and a repeat's [until]. *)

  type reads
  (** What the game read for those promises, with what it read at the
      checkpoint's start for a promise of a change. *)

  type start_reads
  (** What the game reads at a checkpoint's start for a promise of a change (the
      money before a purchase), kept beside an event's save state. *)

  val pose : where:string -> Json_field.obj -> (pose, string) result
  (** A [start] or [declared_after] object. *)

  val matches : pose -> observed -> bool
  (** Whether the player read stands where the pose says. A pose the game does
      not check holds wherever the player is. *)

  val pose_text : pose -> string
  (** The pose in a log line or a failure: ["CeladonCity (48, 12) south"]. *)

  val observed_text : observed -> string
  (** Where the player was read, in a log line or a failure. *)

  val observed_to_json : observed -> Yojson.Safe.t
  (** Where the player was read, kept beside an event's save state. *)

  val observed_of_json : Yojson.Safe.t -> (observed, string) result
  (** What {!observed_to_json} wrote. *)

  val own_kind :
    string ->
    (where:string -> Json_field.obj -> (own_kind, string) result) option
  (** The decoder of the kind of that name, given the event's [args] (unknown
      args are its errors), or [None] when the name is not one of the game's. *)

  val own_kind_text : own_kind -> string
  (** The kind with its args, its name first: ["route to Town (4, 0) north"]. *)

  val promises : where:string -> Json_field.obj -> (promises, string) result
  (** A [postconditions] or [until] object. *)

  val no_promises : promises
  (** What a plan that states no postconditions promises. *)

  val checked_at_end : promises -> bool
  (** Whether the runner reads and checks the promises after the checkpoint's
      end: a plan whose promises it does not check at the end reads nothing. *)

  val check : promises -> reads -> Engine_promise.Promise.result list
  (** One result per promise, in the order they are logged. *)

  val promises_text : promises -> string list
  (** The promises, one per line, in the order the plan's text gives them. *)

  val start_reads_to_json : start_reads -> Json_field.obj
  (** The fields kept beside an event's save state. *)

  val start_reads_of_json : Json_field.obj -> (start_reads, string) result
  (** What {!start_reads_to_json} wrote. *)
end
