(** Room in the party for a chain of checkpoints: how many members the chain's
    plans bring into the party (a Game Corner prize, a capture), which members
    they use (a species an action names or a promised party lists), and, when
    the party is too full, which members to deposit: never one the plans use,
    never one that knows a field move ({!field_moves}), then the lowest levels
    first; nothing is ever released. GamePilot's own (the fork's AutoStory
    deposits by its PC plan, PokemonFRLG_AutoStoryPcStorage). *)

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

type member = {
  species : string;
  level : int option;
  moves : string list option;  (** [None]: not read. *)
}

val deposits : need -> member list -> (string list, string) result
(** The members to deposit so {!free_needed} slots are free: [Ok []] when they
    are; [Error] naming the members kept and why when too few may go. A member
    whose moves were not read may not go. *)

val report : need -> string option list option -> string * string * bool option
(** The pre-flight's row for a party read (species by slot): the need, what was
    read and the deposits it would take, and whether there is room ([None]: the
    party did not read). Moves are not read there, so only members the plans
    name are known; every other member stays. *)
