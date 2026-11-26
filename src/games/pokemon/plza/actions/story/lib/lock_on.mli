(** ZL held to lock on to the opponent while the move effectiveness symbols are
    watched: ported from PokemonLZA_AutoStoryConsoleBackend.cpp, as the scene
    machine's lock-on and the story battle's start use it. Where we differ: the
    fork's watcher wants a symbol held 100 ms; here the first read with a symbol
    ends the hold. *)

val zl_until_symbols : Steps.game_steps -> hold_ms:int -> bool
(** ZL held up to [hold_ms] (no release after), cut short by the first read with
    a move symbol: whether one showed. *)

val hold_ms : int
(** How long one lock-on holds ZL: 2 s. *)

type state = {
  mutable after_fade : bool;
  mutable quiet_since : float option;
  mutable control_since : float option;
  mutable attempts : int;  (** tried so far, this one included once due *)
  mutable locked_on : bool;  (** a try brought up the symbols *)
}
(** The scene machine's lock-on with [stop_at_battle], since the last text or
    choice: after a battle's black fade, a still screen or the party bar with
    nothing busy held 3 s is due one, or the party bar while control shows
    instead of the battle held 1 s; five at most. *)

val new_state : unit -> state
(** No fade, no quiet or control yet, no try. *)

val due : state -> Look.t -> bool
(** A try is due on this read. *)

val record : state -> tried:bool -> control_instead:bool -> Look.t -> unit
(** What this read changes; [tried]: it was classed due (counted before the try
    runs); [control_instead]: the scene machine's control-instead-of-the-end
    read. Text or a choice starts over. *)

val run : state -> Steps.game_steps -> string -> unit
(** The try: from the second, a quarter turn right and L put the camera behind
    the player, then ZL for {!hold_ms}; [locked_on] set when the symbols showed.
*)
