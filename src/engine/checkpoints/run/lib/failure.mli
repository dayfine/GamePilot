(** Why a story event or checkpoint failed. A handler's {!cause} is the game's
    and the same for every game; where the player stood ({!Make.reason}) is in
    the game's terms. *)

type cause = {
  code : string;  (** A name the game owns, such as ["route_blocked"]. *)
  detail : string;
  repeats : bool;
      (** Another attempt would fail the same way, so nothing reloads to retry.
      *)
}
(** What a game's handler reports when its event did not do what it should. *)

val cause : ?repeats:bool -> string -> string -> cause
(** [cause code detail]; [repeats] is [false] unless given. *)

val cause_to_string : cause -> string
(** ["code: detail"], or the code alone when there is no detail. *)

(** Where a run over the game's terms stopped, and why. *)
module Make (T : Engine_terms.GAME_TERMS) : sig
  type nonrec cause = cause = { code : string; detail : string; repeats : bool }
  (** {!Failure.cause}. *)

  val cause : ?repeats:bool -> string -> string -> cause
  (** {!Failure.cause}. *)

  val cause_to_string : cause -> string
  (** {!Failure.cause_to_string}. *)

  (** Why the runner stopped at an event. *)
  type reason =
    | Handler of cause  (** The game's handler for the event failed. *)
    | No_handler of string
        (** The game has no handler for this game action; found before any event
            runs. *)
    | Not_at_declared of { declared : T.Pose.t; observed : T.Pose.observed }
        (** The event passed, but the game reads the player somewhere other than
            its [declared_after]. *)
    | Not_at_end of { declared : T.Pose.t; observed : T.Pose.observed option }
        (** Every event passed, but the player is not at the checkpoint's
            declared end, or the game cannot tell where they are. *)
    | Unmet_postconditions of string list
        (** Every event passed, but promises of the plan failed or could not be
            read ({!Engine_terms.PROMISES.check}): each as
            ["coins: failed: expected 20, read 0"]. *)

  type t = {
    checkpoint_id : string;
    event_index : int;
        (** From 0; the number of events for a {!Not_at_end} or
            {!Unmet_postconditions}, which come after the last one. *)
    event_id : string;
        (** ["end"] for a {!Not_at_end}, ["postconditions"] for
            {!Unmet_postconditions}. *)
    reason : reason;
  }
  (** Where a run stopped, and why. *)

  val repeats : t -> bool
  (** Whether another attempt would fail the same way: a handler's cause says
      so, and a missing handler always does. *)

  val reason_to_string : reason -> string
  (** ["declared end at <pose>, but the game reads <observed>"], ... *)

  val to_string : t -> string
  (** ["01-celadon-setup event 3 (talk_coin_case_man): no_text: ..."], the event
      counted from 1. *)
end
