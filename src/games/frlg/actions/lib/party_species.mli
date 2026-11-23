(** Each party member's species read off the summary's POKéMON INFO page, the
    line right of NAME ({!Frlg_text.Text_lines.summary_species}), with every
    species name a candidate ({!Frlg_text.Line_reading}): the species, not the
    nickname the party menu shows (CH'DING is a Spearow). New for the end
    checks: the fork reads the species only in battle and through its party
    tracker; its Mail Glitch checks ([run_verify_mail_glitch()] in
    Programs/MailGlitch/PokemonFRLG_MailGlitchActions.cpp) find a member by the
    species its tracker reckons. Opened the way {!Summary_moves} opens the
    summary. *)

val read_shown : unit -> string option
(** The species slug on the open info page; [None] when the line shows no
    species name (an egg, another screen). *)

val read_all : log:(string -> unit) -> string option list
(** From the overworld: the party, then for each member (slot 1 first, as many
    as {!Frlg_readers.Party_menu.members} counts) its menu, SUMMARY, the info
    page's species read until two reads {!Summary_moves.reread_ms} apart agree
    ([None] after {!Summary_moves.max_reads} reads that don't), B back to its
    menu and B back to the party; then out to the overworld. Fails as
    [no_party], [no_member_menu] or [no_summary]. *)
