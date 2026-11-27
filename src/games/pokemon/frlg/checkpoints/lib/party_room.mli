(** Room in the party for a chain of FireRed checkpoints: how many members the
    chain's plans bring into the party (a Game Corner prize, a capture) and
    which members they use (a species an action names or a promised party
    lists), as the shared {!Room_policy}'s precondition and rules: FireRed's
    field moves, and the lead stays. GamePilot's own (the fork's AutoStory
    deposits by its PC plan, PokemonFRLG_AutoStoryPcStorage). *)

type need = {
  joins : (string * string) list;
      (** Each member that joins, with the checkpoint it joins in, in order. *)
  used : string list;  (** Species the plans use or promise in the party. *)
  moves : string list;
      (** Field moves the plans' events need some member to know (Cut for a
          [cut_tree]). *)
  free : int;
      (** Peak free party slots needed at the start of the chain, counting
          unconditional [pc_deposit] events that free slots before or between
          joins. *)
}

val party_size : int
(** 6. *)

val field_moves : string list
(** cut, fly, surf, strength: a member knowing one stays. *)

val chain_need : Pokemon_engine.Plan.t list -> (need, string) result
(** Over the plans in run order. [Error] for an arg that does not decode. *)

val free_needed : need -> int
(** Peak free party slots needed at the start of the chain ({!need.free}): a
    plan that deposits a member before catching or stores each catch before the
    next needs only the peak simultaneous growth, not the total joins. *)

type member = Room_policy.member

val lead_stays : bool
(** true: the chain's battles are planned with the lead the save has. *)

val rules : need -> Room_policy.rules
val precondition : need -> Room_policy.precondition

val deposits : need -> member list -> (string list, string) result
(** The species {!Room_policy.choose} deposits so {!free_needed} slots are free:
    [Ok []] when they are; [Error] naming the members kept and why when too few
    may go. *)

val report :
  need ->
  members:member list option ->
  string option list option ->
  string * string * bool option
(** The pre-flight's row: the need, what was read and the deposits it would
    take, and whether there is room ([None]: the party did not read). Judged on
    [members] (species, level, moves) when read; else on the party's species,
    where only members the plans name are known and every other member stays. *)
