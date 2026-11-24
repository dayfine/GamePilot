(** Room in the party before a chain of checkpoints runs, for any Pokémon game:
    the precondition a program declares ("at least N free party slots"), and,
    when the party is too full, which members go to the PC. The rule:

    - never a member the plans use (a species an action names or a promised
      party lists);
    - never one that knows a field move (the game's list, {!rules.field_moves});
    - never the lead, when the plans need it ({!rules.lead_stays}): battles send
      it out first;
    - never one whose moves were not read;
    - of the rest, the lowest level first (an unread level last), then the
      earlier slot.

    Nothing is ever released: the plan only deposits. GamePilot's own: the
    fork's AutoStory deposits by the PC steps its plans name
    (PokemonFRLG_AutoStoryPcStorage, [frlg/lean]). *)

type precondition = { free_slots : int }
(** At least this many free party slots before the chain's first event. *)

type rules = {
  party_size : int;  (** The game's party size: 6. *)
  used : string list;  (** Species the plans use or promise. *)
  field_moves : string list;  (** Moves a member keeps its place for. *)
  lead_stays : bool;  (** The member in slot 1 stays. *)
}

type member = {
  slot : int;  (** From 1. *)
  species : string;
  level : int option;
  moves : string list option;  (** [None]: not read. *)
}

type deposit = { slot : int; species : string }
(** A member to deposit: its slot as read, from 1, and its species, which the PC
    step looks for (a deposit moves the members after it up). *)

type plan = deposit list
(** The deposits, in the party's order. *)

val free_slots : rules -> int -> int
(** The free slots of a party of this many members. *)

val holds : rules -> precondition -> int -> bool
(** Whether a party of this many members meets the precondition. *)

val keeps : rules -> member -> string option
(** Why the member stays, or [None] when it may go. *)

val choose : rules -> precondition -> member list -> (plan, string) result
(** The deposits that meet the precondition: [Ok []] when it holds already;
    [Error] naming each member kept and why when too few may go. *)

val plan_to_string : plan -> string
(** ["deposit eevee (slot 2), magikarp (slot 6)"], or ["nothing to deposit"]. *)

val member_to_string : member -> string
(** ["eevee Lv 25 (tackle, sand-attack)"]; [?] for what was not read. *)
