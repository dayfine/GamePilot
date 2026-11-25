(** A trainer's "Will <player> change POKéMON?" between their Pokémon, under the
    Shift battle style, after "... is about to use ..." (pokefirered
    battle_message.c). Its YES/NO stands where a move learn's does, beside the
    player's HP box, so the battle's readers take it for one
    ({!Frlg_readers.Battle_yes_no.move_learn}); the message's second line tells
    them apart: ["POKéMON?"] here, ["room for <move>?"] or ["<move>?"] in a move
    learn. Read white on the battle's teal
    ({!Frlg_text.Line_reading.light_ink}), on mGBA frames of the Three Island
    Bikers (2026-11-25). Only the English line is read: another language's
    prompt is not told apart and stays a move learn. Not in the fork, whose
    farmers play the Set style or mash B. *)

val text : string
(** ["POKéMON?"]: the prompt's second line. *)

val line : Frlg_text.Text_lines.t
(** The battle message's second line ({!Frlg_text.Text_lines.battle_message} 1).
*)

val shows : Effects.measurements -> bool
(** The line reads as {!text}, with {!probes} subscribed. *)

val probes : unit -> Wire.probe_spec list
(** The line's template for {!text}. *)

val read : unit -> bool
(** {!shows} on the latest frame, {!probes} subscribed for the look. *)
