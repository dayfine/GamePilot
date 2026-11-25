(** The Mail Glitch's item duplication (mg-06, proof B): a port of upstream's
    Programs/Farming/PokemonFRLG_ItemDuplication.cpp, its loop as it is. Its
    start state: the bag open on the Items pocket, Retro Mail on the list's top
    row, the member in party slot 1 holding the item to copy. One round
    ({!round}), each wait 4 s:
    + the selection arrow on the top row (Retro Mail); A, DOWN, A: GIVE;
    + slot 1's held-item mark; A (300 ms after), 400 ms after the mark here
      (below);
    + the "already holding" message's advance arrow; A;
    + the Yes/No box's arrow on YES; A; 500 ms;
    + PLUS (START); the editor's Yes/No arrow on YES; A; 300 ms. Each press is
      held 200 ms and released 100 ms, as the C++ presses.

    Where it differs:
    - The waits use our readers: the top row's arrow is
      {!Frlg_readers.Bag_screen.cursor_row} (the fork's item list rows, where
      the C++ watches its own box over the same row), the held item
      {!Frlg_readers.Party_menu.mark} once the party shows, the message
      {!Frlg_readers.Dialog}'s advance arrow and Yes/No, the editor's Yes/No
      {!Frlg_readers.Mail_editor}.
    - Two guards the C++ leaves out (docs/mail-glitch-use.md, section 4): the
      editor's field 1 must read the expected word before PLUS (the C++ has
      "Detect '???' screen?" as a TODO), and no round starts with fewer than
      {!min_mail} Retro Mail on the top row (at 0 the row goes and A would act
      on the next item).
    - The party takes no A for a moment after it shows: GamePilot sees the mark
      within a frame, and the A the C++ presses as it sees it was dropped (mGBA,
      mg-06 testing run 4), so the fork's give wait
      ({!Party_actions.party_input_ms}) comes first.
    - The item's count is read before and after the rounds (after them once the
      pocket's arrows show again: the list redraws after the editor), and must
      have gone up by one per round (the C++ only counts its rounds); an item of
      another pocket (an Ultra Ball) is counted on its own pocket, then the
      Items pocket is back at its top. *)

val wait_ms : int
(** Every wait of the C++'s loop: 4000. *)

val min_mail : int
(** Retro Mail a round needs on the top row: 2, so one is left. *)

type plan = { item : string; rounds : int; word : string }
(** The item slot 1 holds (a slug), how many rounds, and the word the editor
    must read in field 1. *)

val editor_verdict :
  word:string -> Frlg_text.Line_reading.reading -> string option
(** [None] when field 1 read [word]; else what the editor showed, for the
    failure: a blank field (the record was freed: the glitch is off), ["???"]
    (the member's mail index is 0xFF) or no editor. *)

val counted : plan -> before:int -> after:int -> string option
(** [None] when the count went up by [rounds]; else the failure's detail. *)

val check_editor : frame:string -> word:string -> unit
(** The editor's field 1 read until a candidate (the word, ["???"], blank)
    reads, for up to {!wait_ms}, and that frame kept in the run folder as
    [frame] ({!Effects.save_run_frame}); anything but the word fails as
    [mail_glitch_not_active] ({!editor_verdict}). *)

val round : frame:string -> word:string -> unit
(** One round of the C++'s loop, from the bag with the cursor on Retro Mail at
    the top; the editor's frame is kept as [frame]. Fails as [no_mail_arrow],
    [no_held_item], [no_item_message], [no_switch_question],
    [mail_glitch_not_active] (the editor's word) or [no_mail_confirmation]. *)

val run : log:(string -> unit) -> plan -> unit
(** From the overworld: the Items pocket at its top, Retro Mail checked on its
    top row, the item's count read, the rounds (each after the Retro Mail guard;
    round [i]'s editor kept as [proof-a-round<i>.png]), the count read again
    (that frame kept as [proof-b.png]), the bag closed through its fade
    ({!Menu_input.close_through_fades}). Fails as {!round} does, or as
    [retro_mail_not_on_top], [retro_mail_low], [count_not_read] or
    [duplication_failed]. *)
