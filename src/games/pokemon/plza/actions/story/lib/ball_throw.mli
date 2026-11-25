(** One Poke Ball throw, presses only: ported from PokemonLZA_BallThrow.cpp. ZL
    alone for [lock_on_ms] (to lock on first), then ZL and ZR held for [aim_ms]
    and every scroll (D-pad right, or left for a negative count,
    [scroll_hold_ms] then [scroll_release_ms] each, ZL and ZR still held), all
    released (the throw), then [after_throw_ms] with nothing held. The caller
    checks what the throw did.

    Where it differs: the fork queues the D-pad presses over the ZL + ZR hold;
    here each scroll is a step of the hold with the D-pad added, the same
    timings. *)

type options = {
  lock_on_ms : int;  (** 0: ZL and ZR together from the start *)
  aim_ms : int;
  right_scrolls : int;  (** negative scrolls left *)
  scroll_hold_ms : int;
  scroll_release_ms : int;
  after_throw_ms : int;
}

val default : options
(** The fork's defaults: no lock-on, a 500 ms aim, no scrolls (120 ms held, 80
    released each), no wait after. *)

val inputs : options -> Wire.command list
(** The throw's inputs, to send as one batch. *)

val throw : Steps.game_steps -> options -> unit
(** The throw sent and done. *)
