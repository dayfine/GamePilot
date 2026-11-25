(** Reader: how many of the party bar's six slots hold a Pokémon. Ported from
    PokemonLZA_PartyBarDetector.cpp: its bar detection and per-slot HP bar
    check.

    The bar must show (its D-pad marker, or its empty last slot:
    {!Party_bar.shown}). Slots fill left to right, so the count is one past the
    rightmost slot that is sent out (the D-pad down marker under it:
    {!Party_marker.down_slot}; a fainted lead has no green bar) or shows an HP
    bar. A slot's HP bar is the box (0.045 + 0.0398 i, 0.9519, 0.026, 0.0037) of
    the frame, its card the box above it (0.9454, 0.0046 high). The bar shows
    when half its pixels or more are HP colours (green: green over 140 and over
    red and blue by 60; yellow: red over 170, green over 150, blue under 100;
    red: red over 170, green and blue under 110) or the trough, darker than 0.65
    times the card's mean brightness (the card darkened, about 0.46 times the
    scene over a charcoal floor); 0.72 once 5% or more are HP colours (a
    weakened yellow or red bar over dark asphalt, card about 73). Bars read 0.74
    and up; slots without one 0.16 at most.

    Where it differs: the trough's limit depends on the card's brightness, and a
    probe's test is fixed when it is subscribed. So a read takes two frames: the
    cards ({!card_probes}) on one, then the bars' tests made from them
    ({!bar_probes}) on the next. The HP colours and the trough are counted as
    shares of each bar by [core.line_shares@1] probes, with the pixels both an
    HP colour and dark (and both green and yellow) counted once, as the fork's
    loop counts them. *)

val card_probes : picture:Wire.box -> Wire.probe_spec list
(** The six cards' [core.color_stats@1] probes. *)

val cards : Effects.measurements -> float list option
(** The six cards' mean brightness; [None] when a probe is missing. *)

val bar_probes : picture:Wire.box -> float list -> Wire.probe_spec list
(** The bars' probes for these card brightnesses: 14 per slot. *)

type bar = { hp : float; strict : float; relaxed : float }
(** One bar's shares of its pixels: HP colours, and HP colours or darker than
    0.65 (strict) or 0.72 (relaxed) of its card. *)

val bars : Effects.measurements -> bar list option
(** The six bars, from {!bar_probes}' results. *)

val filled : sent_out:int option -> bar list -> int
(** One past the rightmost slot sent out or with an HP bar; 0 for none. *)
