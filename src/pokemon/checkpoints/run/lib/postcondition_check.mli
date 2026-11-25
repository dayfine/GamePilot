(** A checkpoint's postconditions ({!Plan.postconditions}) checked against what
    the game read once its events were done. Ported from the fork's
    [check_postconditions()] and [postcondition_log_lines()]
    ([Pokemon/AutoStory/Pokemon_StoryPostconditionCheck.{h,cpp}], [frlg/lean]):
    one result per postcondition, passed, failed or not checked, with what was
    expected and read; a postcondition the game cannot read is not checked,
    never passed. The game-agnostic half (verdicts, counts, money, the log) is
    {!Promise}; this module keeps the Pokémon promises and the plan's types.

    Where it differs: money is promised as a range or as what the checkpoint
    spent from the money read at its start ({!Plan.money}), and coins and items
    as a count, a floor or what the checkpoint gained from the count read at its
    start ({!Plan.count}), so the promise holds on any save, not only on the one
    the plan was made on; and the position stays the runner's end check
    ({!Runner.run}'s [end_at]), as before; party, coins and money are checked
    too ({!Plan.postconditions} says why); and the runner fails a run on a
    postcondition not checked as well as a failed one (the C++'s
    [all_passed()]), so a promise nobody read never passes. *)

open Checkpoints_plan

type start = {
  start_money : int option;
      (** The money read at the checkpoint's start, for a {!Plan.Money_spent}
          promise; [None] when not read. *)
  start_coins : int option;
      (** The coins read at the checkpoint's start, for a {!Plan.Count_gained}
          promise; [None] when not read. *)
  start_items : (string * int) list;
      (** Each item read at the checkpoint's start, for a {!Plan.Count_gained}
          promise, and its count; one left out was not read. *)
}
(** What a promise of a change is checked against: the counts read before the
    checkpoint's first event. *)

val nothing_at_start : start

type observed = {
  party : string option list option;
      (** Each member's species slug, slot 1 first; [None] for a member whose
          species did not read. [None] when the party was not read. *)
  items : (string * int) list;
      (** Each item read and its count in the bag (0: read, not there). An item
          left out was not read. *)
  coins : int option;
  money : int option;
  start : start;
      (** What was read at the checkpoint's start, for a promise of a change. *)
  flags : (string * bool) list;
      (** Each flag read and whether it is set; one left out was not read. *)
  knows : (string * string list) list;
      (** Each species whose moves were read, and the moves; one left out was
          not read. *)
  levels : (string * int) list;
      (** Each species whose level was read, and the level; one left out was not
          read. *)
  marks : string list option;
      (** Each party slot's held-item mark as read, slot 1 first; [None] when
          not read. *)
}

val nothing_read : observed

type verdict = Promise.verdict = Passed | Failed | Not_checked

type result = Promise.result = {
  what : string;
  verdict : verdict;
  detail : string;
}
(** One result per postcondition ({!Promise.result}). *)

val check : Plan.postconditions -> observed -> result list
(** The party, then each item, the coins, the money, each flag, each member's
    moves, each member's level and the party's marks, in that order; a
    postcondition the plan leaves out gives no result. *)

val unmet : result list -> result list
(** {!Promise.unmet}. *)

val result_to_string : result -> string
(** {!Promise.result_to_string}. *)

val log_lines : string -> result list -> string list
(** {!Promise.log_lines} tagged ["Postcondition"]:
    {v
    [Postcondition] 01-celadon-setup coins: failed: expected 20, read 200
    v} *)
