(** A checkpoint's postconditions ({!Plan.postconditions}) checked against what
    the game read once its events were done. Ported from the fork's
    [check_postconditions()] and [postcondition_log_lines()]
    ([Pokemon/AutoStory/Pokemon_StoryPostconditionCheck.{h,cpp}], [frlg/lean]):
    one result per postcondition, passed, failed or not checked, with what was
    expected and read; a postcondition the game cannot read is not checked,
    never passed.

    Where it differs: the position stays the runner's end check ({!Runner.run}'s
    [end_at]), as before; party, coins and money are checked too
    ({!Plan.postconditions} says why); and the runner fails a run on a
    postcondition not checked as well as a failed one (the C++'s
    [all_passed()]), so a promise nobody read never passes. *)

type observed = {
  party : string option list option;
      (** Each member's species slug, slot 1 first; [None] for a member whose
          species did not read. [None] when the party was not read. *)
  items : (string * int) list;
      (** Each item read and its count in the bag (0: read, not there). An item
          left out was not read. *)
  coins : int option;
  money : int option;
  flags : (string * bool) list;
      (** Each flag read and whether it is set; one left out was not read. *)
  knows : (string * string list) list;
      (** Each species whose moves were read, and the moves; one left out was
          not read. *)
}

val nothing_read : observed

type verdict = Passed | Failed | Not_checked

type result = {
  what : string;  (** ["party"], ["item retro-mail"], ["coins"], ["flag x"]. *)
  verdict : verdict;
  detail : string;
      (** What was read when it passed; ["expected X, read Y"] when it failed;
          why it was not checked. *)
}

val check : Plan.postconditions -> observed -> result list
(** The party, then each item, the coins, the money, each flag and each member's
    moves, in that order; a postcondition the plan leaves out gives no result.
*)

val unmet : result list -> result list
(** The results that failed or were not checked. *)

val result_to_string : result -> string
(** ["coins: failed: expected 20, read 0"]. *)

val log_lines : string -> result list -> string list
(** One line per result and a summary, the checkpoint first:
    {v
    [Postcondition] mg-01 party: passed: pidgey, abra
    [Postcondition] mg-01 coins: failed: expected 20, read 200
    [Postcondition] mg-01: 1 passed, 1 failed, 0 not checked: failed
    v}
    The summary is ["passed"] only when every one passed, ["incomplete"] when
    none failed and some were not checked, ["nothing to check"] for none. *)
