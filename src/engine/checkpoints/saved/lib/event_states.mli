(** The save states a checkpoint run on mGBA keeps at each event's start, so a
    fix can be tested from just before the changed event
    ({!Engine_run.Event_range}): [<states>/<checkpoint>.events/<n>-<event>.ss],
    [n] the event's number from 1 (two digits), one per event, the newest run's.
    A run keeps an event's state only when it reached that event cleanly: every
    event it ran before it passed or was skipped.

    Beside each state, [<n>-<event>.json] keeps what the run read at the
    checkpoint's start (what a promise of a change needs: the money, coins and
    items in Pokémon) and where the player was reckoned to stand, as the game's
    {!SAVED} writes them: a postcondition that depends on the start (money
    spent, an item gained or used) is checked against the checkpoint's start,
    never re-read at the event, so a partial run checks the same promise a whole
    run does. Not in the fork. *)

(** What a game keeps beside an event's state, and its JSON. The names are those
    [ppx_deriving_yojson] derives. *)
module type SAVED = sig
  type t
  (** What the run read at the checkpoint's start for a promise of a change (the
      money before a purchase), and where the player was reckoned to stand. *)

  val to_yojson : t -> Yojson.Safe.t
  (** The [<n>-<event>.json] kept beside the state. *)

  val of_yojson : Yojson.Safe.t -> (t, string) result
  (** What {!to_yojson} wrote. *)
end

val dir : states:string -> checkpoint:string -> string
(** [<states>/<checkpoint>.events]. *)

val file : index:int -> event_id:string -> string
(** ["13-trade_chding.ss"] for event [index] (from 0) [12]. *)

val path :
  states:string -> checkpoint:string -> index:int -> event_id:string -> string
(** {!dir} and {!file}. *)

val kept_path : string -> string
(** What is kept beside a state: [13-trade_chding.ss] -> [13-trade_chding.json].
*)

val is_other_state : index:int -> keep:string -> string -> bool
(** A file of the events folder that is an older state (or its start reads) of
    event [index] under another id (or what is kept beside it), to remove once
    [keep] is saved: a renamed event leaves one state per number. *)

val missing : checkpoint:string -> label:string -> path:string -> string
(** No state for the event yet: says so and names the run that would make one.
*)

(** {2 Which events get a state} *)

type tracker
(** The events a run has heard so far. *)

val tracker : first:int -> tracker
(** For a run whose first event is [first] (0 for a whole run). *)

val hear : tracker -> int -> _ Engine_run.Event_progress.t -> bool
(** Hears event [index]'s progress; [true] when its state is to be kept now: it
    started and every event from [first] before it passed or was skipped. *)

(** {2 What is kept beside a state} *)

(** The game's kept reads on disk. *)
module Make (S : SAVED) : sig
  val write_kept : string -> S.t -> unit
  (** [write_kept state kept] writes [kept] to {!kept_path}[ state], one line of
      JSON. *)

  val read_kept : missing:string -> string -> (S.t, string) result
  (** What {!write_kept} wrote beside the state at the path; [Error missing]
      when there is no such file. *)
end
