(** How a step waits for the game to settle after a talk, a scene, a warp or a
    door: one loop over {!Talk_over} for every game. A game gives it its looks
    (facts from its readers) and its presses through {!io}; the rule for each
    kind of settle is one table here. *)

(** What ends a settle. *)
type kind =
  | Talk  (** text and scenes pressed through, then the overworld quiet *)
  | After_warp
      (** as [Talk], but a warp (a map change) must come first: a fade, or the
          far map's banner *)
  | Door
      (** after a door or a way through with no text to come: the fade back up
          and a short still spell around the player, people walking about
          ignored *)
  | Menu_closed
      (** after a menu (the party, a summary) is backed out of, with no text to
          come: B until the overworld shows still and with no box for 0.5 s,
          looking every 0.3 s, at most 15 s; the talk's 5 s quiet is for a scene
          that may go on *)

type rule = {
  judge : Talk_over.rule;  (** what ends it *)
  look_every_ms : int;
      (** The wait after a press before the next look: a line's text takes about
          a second to run out; a door has no text and looks often to catch its
          short still spell. *)
  cap_ms : int;  (** how long it may take before it fails *)
  watch_battles : bool;
      (** For a game that only watches: a battle on screen is watched like any
          other unsettled screen, until the overworld is quiet after it; no
          [flee_battle], no press. *)
}

val rule : kind -> rule
(** The rule of [kind]. *)

type look = {
  facts : Facts.t;
  at_ms : float;  (** when it was taken, on the daemon clock *)
  since_ms : float option;
      (** For a look that watches a span: since when the screen has shown
          [facts] unchanged, so a quiet that began early in it counts from then.
          [None]: from [at_ms]. *)
}

type io = {
  look : unit -> look;  (** the screen now *)
  press : Talk_over.press -> wait_ms:int -> unit;
      (** answers a look, then waits [wait_ms]; a game that only watches just
          waits *)
  flee_battle : unit -> bool;
      (** a battle started: flees a wild one and returns true, or returns false
          for one that ends the settle (a trainer's after their talk) *)
  log : string -> unit;
}
(** What {!run} needs of a game. *)

(** How a settle ended, with what it saw (["black fade back up"]). *)
type ending =
  | Quiet of string  (** the rule's end: the overworld quiet, or calm *)
  | Battle of string  (** a battle [flee_battle] did not flee *)
  | Timed_out of string  (** the cap: the step fails; the string says why *)

val run : rule -> label:string -> io -> ending
(** Looks and presses until [rule] says the game has settled, a battle ends it,
    or the cap. [label] names the step in the log and the failure. *)
