(** What a checkpoint promises, checked: one result per promise, passed, failed
    or not checked, with what was expected and read, and the log lines over
    them. The game-agnostic half of {!Postcondition_check}, which keeps the
    Pokémon half (party, moves, levels, marks) and the plan's types. Ported with
    it from the fork's [check_postconditions()] and [postcondition_log_lines()]
    ([Pokemon/AutoStory/Pokemon_StoryPostconditionCheck.{h,cpp}], [frlg/lean]).

    A promise the game cannot read is not checked, never passed. Counts (items,
    coins, {!Count}) and money ({!Money}) are checked as a value, a floor, a
    range, or a change from what was read at the checkpoint's start. *)

(** How one promise came out: it held, it did not, or it could not be checked.
*)
type verdict = Passed | Failed | Not_checked

type result = {
  what : string;  (** ["party"], ["item retro-mail"], ["coins"], ["flag x"]. *)
  verdict : verdict;
  detail : string;
      (** What was read when it passed; ["expected X, read Y"] when it failed;
          why it was not checked. *)
}
(** One promise's outcome: what was promised, its verdict, and a detail to log.
*)

val judge : string -> expected:string -> read:string -> bool -> result
(** [judge what ~expected ~read holds]: passed with [read] as its detail when
    [holds], else failed with ["expected X, read Y"]. *)

val not_checked : string -> why:string -> result
(** Not checked, with [why] as its detail. *)

val not_read : string -> result
(** Not checked: ["the game can't read it"]. *)

val count : string -> Count.t -> start:int option -> read:int -> result
(** [count what promised ~start ~read]: ["coins: passed: 20"],
    ["coins: failed: expected 20, read 200"],
    ["item rope: failed: expected at least 2, read 1"]. A {!Count.Gained}
    promise holds when the count went from [start] to [read] by exactly the
    promised change, which is negative for a count used:
    ["gained 20 (50 to 70)"], ["expected used 1, read gained 3 (2 to 5)"]; it is
    not checked when the start was not read ([None]). *)

val money : Money.t -> start:int option -> read:int -> result
(** What is ["money"]. A {!Money.Range}: ["$25014"] when [min = max],
    ["$100 to $200"] else. A {!Money.Spent}: the money went down from [start] to
    [read] by exactly the amount: ["spent $4100 ($29202 to $25102)"]; not
    checked when the start was not read ([None]). *)

val unmet : result list -> result list
(** The results that failed or were not checked. *)

val result_to_string : result -> string
(** ["coins: failed: expected 20, read 0"]. *)

val log_lines : tag:string -> string -> result list -> string list
(** [log_lines ~tag checkpoint results]: one line per result and a summary, each
    ["[<tag>] <checkpoint>"] first:
    {v
    [Postcondition] 01-celadon-setup party: passed: pidgey, abra
    [Postcondition] 01-celadon-setup coins: failed: expected 20, read 200
    [Postcondition] 01-celadon-setup: 1 passed, 1 failed, 0 not checked: failed
    v}
    The summary is ["passed"] only when every one passed, ["incomplete"] when
    none failed and some were not checked, ["nothing to check"] for none. *)
