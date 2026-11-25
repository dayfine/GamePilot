(** What a Pokémon checkpoint promises once its events are done: the plan's
    [metadata.postconditions] (and a repeat's [until]), read by
    [Pokemon_plan_codec] and checked by {!Postcondition_check}. *)

(** Which party a checkpoint promises. *)
type party =
  | Party_in_order of string list
      (** Exactly these species (slugs, ["abra"]), slot 1 first. *)
  | Party_includes of { members : string list; slots : slot list }
      (** Each of [members] somewhere in the party (a species named twice needs
          two members), and each of [slots] in its slot: only the members the
          plans use and only the positions they depend on, so a save whose other
          members differ keeps the promise. *)

and slot = { slot : int; species : string }
(** The member in party slot [slot] (from 1) is of [species] (a slug). *)

type bag_count = { bag_item : string; count : Engine_promise.Count.t }
(** A count of the bag item [bag_item] (a slug). *)

type knows = { species : string; moves : string list }
(** The party member of this species (a slug; the first such member) knows each
    of these moves (slugs). *)

type level = { species : string; min : int }
(** The party member of this species (a slug; the first such member) is at least
    at this level. *)

type t = {
  position : Pose.grid option;
      (** Where the checkpoint ends; unset, the end is the next checkpoint's
          start ([Checkpoint_end]). *)
  party : party option;
  items : bag_count list;  (** Each item's count in the bag. *)
  coins : Engine_promise.Count.t option;  (** Game Corner coins. *)
  money : Engine_promise.Money.t option;
  flags : string list;  (** Story flags (named by the game) that must be set. *)
  knows : knows list;  (** Moves members must know. *)
  levels : level list;
      (** Levels members must have reached, e.g. MIMIEN at least Lv 33. *)
  marks : string list option;
      (** Each party slot's held-item mark, slot 1 first: ["held_item"],
          ["mail"] or ["none"] (a slot left out is not checked). *)
}
(** What must hold once the checkpoint is done, from the plan's
    [metadata.postconditions]. [position], [items] and [flags] are
    PokemonSimulation's ([read_metadata] in
    [src/pokesim/story/checkpoint_wire.py]) and the C++'s ([StoryPostconditions]
    in [Pokemon/AutoStory/Types/Pokemon_StoryPostconditions.h], fork
    [frlg/lean]); [party], [coins], [money], [knows], [levels] and [marks] are
    GamePilot's additions: the state a Mail Glitch checkpoint exists to change.
*)

val none : t
(** Nothing promised: what a plan that states no postconditions promises. *)

val stated : t option -> t
(** A plan's postconditions: {!none} when it states none. *)

val at_end : t -> t option
(** What the runner reads and checks after the end position: [None] unless a
    party, items, coins, money or flags are promised (moves, levels and marks
    alone are not read at the end). *)
