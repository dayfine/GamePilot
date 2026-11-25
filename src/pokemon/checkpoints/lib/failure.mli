(** Why a story event or checkpoint failed. *)

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

(** Why the runner stopped at an event. *)
type reason =
  | Handler of cause  (** The game's handler for the event failed. *)
  | No_handler of string
      (** The game has no handler for this game action; found before any event
          runs. *)
  | Not_at_declared of { declared : Pose.grid; observed : Pose.observed }
      (** The event passed, but the game reads the player somewhere other than
          its [declared_after]. *)
  | Not_at_end of { declared : Pose.grid; observed : Pose.observed option }
      (** Every event passed, but the player is not at the checkpoint's declared
          end ({!Checkpoint_end}), or the game cannot tell where they are. *)
  | Unmet_postconditions of string list
      (** Every event passed, but postconditions of the plan failed or could not
          be read ({!Postcondition_check}): each as
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

val repeats : t -> bool
(** Whether another attempt would fail the same way: a handler's cause says so,
    and a missing handler always does. *)

val reason_to_string : reason -> string

val to_string : t -> string
(** ["01-celadon-setup event 3 (talk_coin_case_man): no_text: ..."], the event
    counted from 1. *)
