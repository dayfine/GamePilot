(** A decoded plan as text, one line per thing, so a test can compare it with
    what the plan file says. The game's poses, kinds and promises are its terms'
    texts ({!Engine_terms.GAME_TERMS}). *)

(** The game's plans as text. *)
module Make (T : Engine_terms.GAME_TERMS) : sig
  val pose : T.pose -> string
  (** {!Engine_terms.GAME_TERMS.pose_text}: ["CeladonCity (48, 12) south"]. *)

  val kind : Plan.Make(T).kind -> string
  (** The kind with its typed args: ["answer no"],
      ["route to Town (4, 0) north"]. *)

  val kind_name : Plan.Make(T).kind -> string
  (** The kind's name in the plan format: ["route"], ["game_action"], ... *)

  val event : Plan.Make(T).event -> string
  (** ["id: [action] kind => declared_after skip_if a,b once_per_save"], each
      part only when the event has it. *)

  val event_named : Plan.Make(T).t -> string -> string
  (** The plan's event of that id as {!event}, or ["no event <id>"]. *)

  val outline : Plan.Make(T).t -> string
  (** ["frlg 01-celadon-setup from CeladonCity (48, 12) south: 6 game_action, 7
       route"]: the plan's game, id, start, and how many events of each kind, in
      first-seen order. *)

  val postconditions : Plan.Make(T).t -> string
  (** The plan's postconditions, one per line; ["none"] when it states none. *)

  val repeat : Plan.Make(T).t -> string
  (** ["at most N rounds, until:"] and the goal's postconditions, or
      ["no repeat"]. *)
end
