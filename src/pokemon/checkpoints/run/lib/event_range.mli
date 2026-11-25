(** The events of one checkpoint a partial run runs: from one event to another
    (or to the last), picked by [--from-event] and [--to-event] as an event's id
    or its number ([13], as the story log's [#13]). A partial run starts from
    the save state kept at its first event's start ({!Event_states}) and is only
    a test of the events it runs: its record's mode is {!mode_name}, it never
    counts towards a verification and its end is never saved as the next
    checkpoint's start ({!keeps_end}). Not in the fork, whose AutoStory runs a
    checkpoint only from its start. *)

open Engine_run
open Checkpoints_plan

type t = { first : int; last : int option }
(** Indices from 0; [last = None]: to the checkpoint's last event. *)

val resolve :
  Plan.event list ->
  from_event:string ->
  to_event:string option ->
  (t, string) result
(** The range [from_event .. to_event] of these events, each an event id or a
    number from 1; an error naming the unknown event, or a [to_event] before
    [from_event]. *)

val select : t -> Plan.event list -> (int * Plan.event) list
(** The events it runs, with their indices. *)

val reaches_end : t -> Plan.event list -> bool
(** It runs the checkpoint's last event, so the end checks apply. *)

val label : Plan.event list -> int -> string
(** ["#13 trade_chding"]: event [index] as the story log names it. *)

val describe : t -> Plan.event list -> string * string
(** The first and the last event it runs, as {!label}s: what run.json's
    [from_event] and [to_event] say. *)

val mode_name : string
(** ["from-event"]: a partial run's mode, in its folder name and run.json. *)

val check :
  mode:Checkpoint_trials.mode ->
  keeps_states:bool ->
  checkpoints:int ->
  (unit, string) result
(** Whether a partial run may run: only in testing mode (it never verifies),
    only on a backend that keeps save states (mGBA; the Switch has none), and
    over one checkpoint. *)

val keeps_end : t option -> Checkpoint_trials.policy -> bool
(** Whether a passing run's end becomes the next checkpoint's start: the
    policy's say for a whole run, never for a partial one. *)
