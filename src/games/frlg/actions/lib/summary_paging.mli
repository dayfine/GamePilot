(** Every party member's summary in one pass: the party opened once, the first
    member's summary, then DOWN on its info page to the next member, and one
    close back to the overworld at the end ({!Menu_input.close_to_overworld}).
    On the info page DOWN goes to the next slot, eggs included, and stops at the
    last member (pokefirered pokemon_summary_screen.c,
    SeekToNextMonInSingleParty: only the other pages skip eggs), so the member
    shown is always the next slot. GamePilot's own: the fork reads each member
    from the overworld ([read_party_summary()],
    Programs/AutoStory/PokemonFRLG_AutoStorySummary, [frlg/lean]). *)

val member_switch_ms : int
(** After a DOWN, before the next member's page is read: 500 ms, so a frame from
    before the switch (the Switch's capture shows a press up to about 335 ms
    late) and the redraw (about 10 frames) are over. *)

val each_member : label:string -> log:(string -> unit) -> (int -> 'a) -> 'a list
(** From the overworld: [read slot] (from 1) for each member the party shows,
    each run on that member's info page and back on it when it returns, then out
    to the overworld. In {!Frlg_readers.Summary_screen}'s probes. Fails as
    [no_party], [no_member_menu], [no_summary] or the close's cause. *)

val settled : (unit -> 'a option) -> 'a option
(** A read of the page once two reads {!Summary_moves.reread_ms} apart agree
    (the page's mark shows before its text is drawn); [None] when they never did
    in {!Summary_moves.max_reads} reads. *)

val to_page : int -> unit
(** RIGHT or LEFT until the summary shows this page, presses
    {!Summary_moves.page_turn_ms} apart. Fails as [no_summary]. *)
