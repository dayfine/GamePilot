(** A plan's score ({!Route_scorer}): whether it gets there, and how long it
    takes. *)

(** Whether a plan gets there, from every start and through every recovery. *)
type verdict =
  | Pass
  | Fail  (** May end off the goal, overshoot onto a hazard, or never arrive. *)
  | Strand
      (** A recovery can lead back into itself without first stopping at a wall
          out of harm's way. *)
  | Retries
      (** More recoveries in a row than {!Interrupt_model.t.max_recoveries}. *)

val verdict_name : verdict -> string
(** ["PASS"], ["FAIL"], ["STRAND"], ["RETRIES"]. *)

type t = {
  verdict : verdict;
  why : string;  (** For a verdict other than [Pass]. *)
  nominal_ms : int;  (** Slowest start, nothing interrupting. *)
  expected_ms : float;  (** Average start, interruptions by their chance. *)
  worst_ms : int;  (** Slowest start and the costliest single interruption. *)
  stops : int;  (** Legs that end on a wall: each re-localizes. *)
  presses : int;  (** Legs plus taps. *)
  recoveries : int;  (** Places an interruption may happen. *)
  replans : int;  (** Of those, the ones the plan's own legs cannot absorb. *)
}

val pass : t
(** A pass that takes no time. *)

val fail : verdict -> string -> t -> t
(** The score with that verdict and why, unless it already failed: the first
    failure is the one reported. *)
