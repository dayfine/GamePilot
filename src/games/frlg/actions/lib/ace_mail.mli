(** The ACE setup's game actions (frlg.ace_setup; pomeg-letterbombers' FRLG
    non-JPN Post-E4 route): the ? Mail written, and one PC box slot checked.

    - ["write_glitched_mail"], args ["species"] or ["target_slot"], ["words"]: a
      list of [{"group", "word"}]. Retro Mail given to the member (as
      {!Mail_glitch_use}'s [read_glitched_mail], the member holding nothing: no
      switch question); the editor must show the ? Mail (the words' fields read
      ["???"], kept as [ace-mail-before.png]); the words written and read back
      ({!Easy_chat_entry.write}, the message kept as [ace-mail-typed.png]);
      START, YES; the bag or party closed through its fades. The ? Mail is
      gSaveBlock1's mail[0xFF], which lies on Box 3 slot 1: its first four words
      are that slot's personality and OT ID. Fails as {!Easy_chat_entry.write}
      does, or as [not_question_mark_mail].
    - ["check_box_slot"], args ["box"] (3, the only one: its default Desert
      wallpaper is how the box is told), ["slot"] (from 1), ["occupied"], and
      for an occupied slot optional ["level"] and ["male"]: facing a Pokémon
      Center's PC, BILL'S PC, MOVE POKéMON ({!Pc_deposit}'s looks and presses),
      the hand from Box 1's first slot to the slot (UP to the box title, RIGHT
      per box, DOWN onto the row's third slot, LEFT or RIGHT, DOWN), the box
      screen read ({!Frlg_readers.Pc_box_screen}, kept as
      [box<box>-slot<slot>.png]), back out to the overworld. Empty: PKMN DATA
      flat, and the hand's shadow on the first slot. Occupied: PKMN DATA shows
      text, and the level ({!Frlg_text.Text_lines.pc_data_level}) and the male
      mark as asked. The species is not read: the ACE Pokémon (0x0351) shows a ?
      picture and a garbled name. Fails as [box_slot_wrong] or [pc_box]. *)

val handlers :
  log:(string -> unit) ->
  party:Party_roster.t ref ->
  (string * Pokemon_checkpoints.Game.game_action) list
