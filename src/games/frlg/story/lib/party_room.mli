(** Room in the party for a chain of FireRed checkpoints: how many members the
    chain's plans bring into the party (a Game Corner prize, a capture) and
    which members they use (a species an action names or a promised party
    lists), as the shared {!Story.Room_policy}'s precondition and rules:
    FireRed's field moves, and the lead stays. GamePilot's own (the fork's
    AutoStory deposits by its PC plan, PokemonFRLG_AutoStoryPcStorage). *)

type need = {
  joins : (string * string) list;
      (** Each member that joins, with the checkpoint it joins in, in order. *)
  used : string list;  (** Species the plans use or promise in the party. *)
}

val party_size : int
(** 6. *)

val field_moves : string list
(** cut, fly, surf, strength: a member knowing one stays. *)

val chain_need : Story.Plan.t list -> need
(** Over the plans in run order. Raises {!Grid_maps.Json_field.Invalid} for an
    arg that does not read. *)

val free_needed : need -> int
(** The members that join: each must reach the party (a trade or a battle uses
    it), and none leaves. *)

type member = Story.Room_policy.member

val lead_stays : bool
(** true: the chain's battles are planned with the lead the save has. *)

val rules : need -> Story.Room_policy.rules
val precondition : need -> Story.Room_policy.precondition

val deposits : need -> member list -> (string list, string) result
(** The species {!Story.Room_policy.choose} deposits so {!free_needed} slots are
    free: [Ok []] when they are; [Error] naming the members kept and why when
    too few may go. *)

val report : need -> string option list option -> string * string * bool option
(** The pre-flight's row for a party read (species by slot): the need, what was
    read and the deposits it would take, and whether there is room ([None]: the
    party did not read). Moves are not read there, so only members the plans
    name are known; every other member stays. *)
