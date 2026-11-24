(** An in-game trade, facing the trader: A, YES to their offer, the offered
    member on the party, then A through the trade until the trader's white text
    box is back, and the talk settle. Ported from the fork's
    [run_ingame_trade()] (Programs/MailGlitch/PokemonFRLG_MailGlitchActions).
    The trade's own battle-style text box is not the white one, so it is pressed
    through.

    Where it differs: the trader's white box must show for {!text_hold_ms}, not
    on one frame as the fork's WhiteDialogWatcher: the scene's fade into its
    blue box passes through colours that read as the white box for a frame or
    two (mGBA, 2026-11-23), and the settle then met the blue box, which reads as
    a battle. The party showing before the question was seen is YES taken by the
    last page's A ({!Menu_input.answer_yes}): the slot is chosen as after the
    question (mg-02 testing on console B, 2026-11-24). *)

val trade_presses : int
(** A presses through the trade before failing: 45, as the fork. *)

val trade_press_ms : int
(** Between them: 1000. *)

val text_hold_ms : int
(** 300 ms. *)

val party_timeout_ms : int
(** The party opening after YES: 15 s. *)

val trade : log:(string -> unit) -> slot:int -> unit
(** Fails as [trade_no_question], [trade_no_party] or [trade_not_done]. *)
