(** A party member's level read on its summary ({!Frlg_text.Summary_level}), as
    the fork's story reads it: [console_member_reader()]
    (Programs/AutoStory/PokemonFRLG_AutoStoryMember.cpp, [frlg/lean]) opens the
    member's summary and takes the level from page 1 ([read_party_summary()],
    [StatsReader::read_level()]). Opened the way {!Summary_moves} opens it; only
    the level is read. *)

val read : log:(string -> unit) -> slot:int -> int option
(** From the overworld: the party, the member in [slot] (from 1), SUMMARY, the
    info page's level read until two reads {!Summary_moves.reread_ms} apart
    agree on one ([None] after {!Summary_moves.max_reads} reads that don't),
    then B back to the overworld. Logs ["Summary: slot 1 is Lv 33."]. Fails as
    [no_party], [no_member_menu] or [no_summary]. *)
