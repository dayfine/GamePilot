(** The pre-flight of a save: before the first checkpoint of a run on the
    console, does the loaded save hold what that checkpoint's plan needs? The
    needs come from the plan's args: each party member an action names (Fly's
    user, a grind's member and sweeper, a swap's member, ...) unless an earlier
    event of the plan brings it (a capture, a trade), and Cut's user knowing
    Cut; the money its purchases cost (a Mart's prices from the stock table,
    ¥1000 for each 50 Game Corner coins); each bag item an action gives or uses
    that no earlier purchase or pickup ([pick_up_item]) brought. When the
    checkpoint before it promises a state (its postconditions: the members it
    names and the slots it pins, the money as a range (not what it spent), item
    counts and floors (not what it gained or used)), that is needed too, as
    promised. And the place: the frame kept at the checkpoint's start
    ({!Start_check}).

    GamePilot's own: the fork checks the save's place on the save card and its
    StoryPreflight only the program's settings. *)

type need = Plan_needs.need =
  | Party_in_order of string list
  | Party_includes of {
      members : string list;
      slots : Checkpoints_plan.Plan.slot list;
    }
  | Member of { species : string; for_ : string }
      (** A member an event uses ([for_]: ["fly"]). *)
  | Knows_move of { move : string; for_ : string }
      (** Some member knows this field move: a [cut_tree] event's Cut, which the
          game lets any member that knows it use. *)
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string  (** The checkpoint's start map. *)

val needs :
  Frlg_actions.Mart_plan.stocks ->
  before:Checkpoints_plan.Plan.postconditions option ->
  Checkpoints_plan.Plan.t ->
  need list
(** What the save must hold for the plan's first event, in the table's order:
    the party, the money, the items, the place. Raises
    {!Grid_maps.Json_field.Invalid} for a plan arg that does not read. *)

type read = {
  observed : Checkpoints_run.Postcondition_check.observed;
  place : Frlg_readers.Start_frame.difference option;
      (** The frame after the load against the one kept at the start; [None]
          when none was kept or the frame did not read. *)
  members : Checkpoints_run.Room_policy.member list option;
      (** Each member's species, level and moves on its summary
          ({!Frlg_actions.Party_summary}): the field moves and the room are
          judged on them. [None] when not read. *)
}

type verdict = Ok | Mismatch | Not_read
type row = { need : string; read : string; verdict : verdict }

val describe : need -> string
(** The need as the table's NEED column and the user guides (docs/guide/) say
    it: ["money at least ¥4100 (buy_coins)"]. *)

val compare : need list -> read -> row list

val room : Party_room.need -> read -> row
(** The chain's free party slots ({!Party_room}) against the party read:
    [Mismatch] naming the members to deposit, or why too few may go (moves are
    not read here, so every member not named by the plans stays). Depositing is
    the developer's, at a PC: the runner has no [--make-room] yet. *)

val passed : row list -> bool
(** Every row [Ok]: a need not read fails the pre-flight too. *)

val table : row list -> string
(** A text table: NEED, READ, OK / MISMATCH / NOT READ, one row a line. *)

val to_read : need list -> Checkpoints_plan.Plan.postconditions
(** What {!Postcondition_reads.observe} must read for these needs. *)
