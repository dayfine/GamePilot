(** What {!Screen_driver}'s [next_event] does at each look: the one table from
    the screen to an answer. Pure: a state is a value, and each look returns the
    next one.

    Presses wait for the screen to hold: battle text is pressed through with B
    only once it has stayed up {!press_gap_ms} since the last press (most battle
    text runs on by itself, and a B that lands on a double battle's second
    action menu would take back the first battler's command). B never answers
    YES. The battle is over once no battle screen has shown for
    {!over_after_ms}, after one did. *)

type state

val start : at_ms:float -> state
(** Before the first look; nothing pressed yet, no battle seen. *)

(** The answer to a look. *)
type step =
  | Report of Battle_driver.event  (** [next_event] returns this *)
  | Press of Wire.button  (** then look again *)
  | Look  (** nothing to do yet: look again *)

val next : state -> Battle_look.facts -> at_ms:float -> state * step
(** The state after a look taken at [at_ms] (daemon clock) and its answer. *)

val press_gap_ms : float
(** 1.5 s, the fork's STUCK wait before a B on battle text. *)

val over_after_ms : float
(** 3 s with no battle screen: the fade out of a battle is shorter, a wild
    battle's text after RUN is a battle screen. *)
