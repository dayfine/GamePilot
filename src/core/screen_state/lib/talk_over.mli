(** When a talk or a scene is over, judged from looks over time, not from one
    look. It is over once every fade has come back up, no dialogue box shows,
    and the overworld (free control) has been quiet, or calm, for long enough
    since. A look that shows a fade starts the quiet over, however still it is.
    Pure: a judge is a value, and each look returns the next one. *)

(** What "still" means for the quiet clock. *)
type still_source =
  | Screen  (** the whole screen still ({!Facts.t.screen_still}) *)
  | Player
      (** only the box around the player still, so people walking about neither
          hold the quiet up nor end it early *)

type rule = {
  warp : bool;
      (** A map change must come first: a fade or the banner. Only the quiet
          after it counts: a scene can go quiet for 5 s before the fade home. *)
  end_on_quiet : bool;
      (** False when a battle is to follow (a trainer's lines pause for more
          than 4 s before it): no quiet ends the talk then. *)
  calm_ms : int;
      (** How long the overworld with no box ends it, still or not: wanderers or
          grass can keep the screen from ever being still. *)
  quiet_ms : int;  (** How long the overworld still and with no box ends it. *)
  still : still_source;
}

val quiet_ms : int
(** 5 s: a scene pauses while someone walks off, a scripted walk-in can run 5 s
    with no text before someone speaks, and a speech pauses for a fanfare. *)

val calm_ms : int
(** 15 s. *)

val default_rule : rule
(** No warp, ends on quiet, {!calm_ms}, {!quiet_ms}, the whole screen. *)

(** The answer to a look that does not end the judging. *)
type press =
  | Next  (** a box shows: the talk's button *)
  | B
      (** no box: B, which never starts a talk on the overworld (A would, and
          answers Yes on a prompt) *)

type move = Press of press | Battle  (** a battle started *) | Done
type t

val create : rule -> t

val observe : t -> Facts.t -> at_ms:float -> t * move
(** The judge after a look taken at [at_ms] (daemon clock), and what to do. *)

val warped : t -> bool
(** Whether the warp the rule asks for has shown (true without one). *)

val describe : t -> string
(** What it has seen, for the log: ["black fade back up, banner read"]. *)
