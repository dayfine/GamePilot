(** The pre-flight of a save: before the first checkpoint of a run on the
    console, does the loaded save hold what that checkpoint's plan needs? The
    needs come from the plan's args: each party member an action names (Fly's
    user, a grind's member and sweeper, a swap's member, ...) unless an earlier
    event of the plan brings it (a capture, a trade), and Cut's user knowing
    Cut; no Mail on a member a [pc_deposit] stores (each member's held-item mark
    on the party menu); the money its purchases cost (a Mart's prices from the
    stock table, ¥1000 for each 50 Game Corner coins); each bag item an action
    gives or uses that no earlier purchase or pickup ([pick_up_item]) brought.
    When the checkpoint before it promises a state (its postconditions: the
    members it names and the slots it pins, the money as a range (not what it
    spent), item counts and floors (not what it gained or used)), that is needed
    too, as promised. The plan's declared preconditions ({!Plan_preconditions}:
    the badges, the Hall of Fame), read off the Trainer Card. And the place: the
    frame kept at the checkpoint's start ({!Start_check}).

    GamePilot's own: the fork checks the save's place on the save card and its
    StoryPreflight only the program's settings. *)

type need = Plan_needs.need =
  | Party_in_order of string list
  | Party_includes of {
      members : string list;
      slots : Pokemon_engine.Postconditions.slot list;
    }
  | Member of { species : string; for_ : string }
      (** A member an event uses ([for_]: ["fly"]). *)
  | No_mail of { species : string; for_ : string }
      (** The first member of this species holds no Mail: a [pc_deposit] stores
          it, and the game will not store a Mail holder ("Please remove the
          MAIL."). *)
  | Knows_move of { move : string; for_ : string }
      (** Some member knows this field move: a [cut_tree] event's Cut, which the
          game lets any member that knows it use. *)
  | Badge of { badge : string; for_ : string }
      (** The badge a field move needs outside battle ([for_]: the action),
          judged on the Trainer Card. *)
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string  (** The checkpoint's start map. *)
  | Badges_at_least of int
      (** At least this many badges ({!Plan_preconditions}: [badges] a count).
      *)
  | Badges of string list  (** Each of these badges, by name. *)
  | Hall_of_fame  (** The Hall of Fame entered: a star on the card. *)
  | Caught_at_least of int
      (** At least this many species caught, the Trainer Card's Pokédex count
          ({!Plan_preconditions}: [caught]). *)

val needs :
  Frlg_actions.Mart_plan.stocks ->
  before:Pokemon_engine.Postconditions.t option ->
  Pokemon_engine.Plan.t ->
  (need list, string) result
(** What the save must hold for the plan's first event, in the table's order:
    the plan's declared preconditions ({!Plan_preconditions.needs}), then the
    party, the money, the items, the place. [Error] for declared preconditions
    that do not decode. Raises {!Json_field.Invalid} for a plan arg that does
    not read. *)

type read = {
  observed : Pokemon_engine.Postcondition_check.observed;
  place : Frlg_readers.Start_frame.difference option;
      (** The frame after the load against the one kept at the start; [None]
          when none was kept or the frame did not read. *)
  members : Room_policy.member list option;
      (** Each member's species, level and moves on its summary
          ({!Frlg_actions.Party_summary}): the field moves and the room are
          judged on them. [None] when not read. *)
  card : Frlg_readers.Trainer_card_front.t option;
      (** The badges and stars on the Trainer Card
          ({!Frlg_actions.Trainer_card_badges}); [None] when not read. *)
}

type verdict = Ok | Mismatch | Not_read
type row = { need : string; read : string; verdict : verdict }

val describe : need -> string
(** {!Plan_needs.describe}: the need as the table's NEED column says it. *)

val asks_something : need -> bool
(** {!Plan_needs.asks_something}. *)

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

val reads_card : need list -> bool
(** A need is judged on the Trainer Card's badges or stars: the pre-flight reads
    them. *)

val to_read : need list -> Pokemon_engine.Postconditions.t
(** What {!Postcondition_reads.observe} must read for these needs. *)
