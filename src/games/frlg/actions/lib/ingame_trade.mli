(** An in-game trade, facing the trader: A, YES to their offer, the offered
    member on the party, then A through the trade until the trader's white text
    box is back, and the talk settle. Ported from the fork's
    [run_ingame_trade()] (Programs/MailGlitch/PokemonFRLG_MailGlitchActions).
    The trade's own battle-style text box is not the white one, so it is pressed
    through. *)

val trade_presses : int
(** A presses through the trade before failing: 45, as the fork. *)

val trade_press_ms : int
(** Between them: 1000. *)

val party_timeout_ms : int
(** The party opening after YES: 15 s. *)

val trade : log:(string -> unit) -> slot:int -> unit
(** Fails as [trade_no_question], [trade_no_party] or [trade_not_done]. *)
