(** The ACE setup's game actions (frlg.ace_setup; pomeg-letterbombers' FRLG
    non-JPN Post-E4 route): the ? Mail written, and one PC box slot checked.

    - ["write_glitched_mail"], args ["species"] or ["target_slot"], ["words"]: a
      list of [{"group", "word"}]. Retro Mail given to the member (as
      {!Mail_glitch_use}'s [read_glitched_mail], the member holding nothing: no
      switch question); the editor must show the ? Mail (the words' fields read
      ["???"], kept as [ace-mail-before.png]); the words written and read back
      ({!Easy_chat_entry.write}, the message kept as [ace-mail-typed.png]);
      START, YES; the bag or party closed through its fades. The ? Mail is the
      save's mail record 0xFF, which lies on Box 3 slot 1: its first four words
      are that slot's personality and OT ID. Fails as {!Easy_chat_entry.write}
      does, or as [not_question_mark_mail]. The words are read in English only
      ({!Easy_chat_entry}).
    - ["check_box_slot"], args ["box"] (3, the only one: its default Desert
      wallpaper is how the box is told), ["slot"] (from 1), ["occupied"], and
      for an occupied slot optional ["level"] and ["male"]: facing a Pokémon
      Center's PC, BILL'S PC, MOVE POKéMON ({!Pc_box.to_box_screen}), the hand
      from Box 1's first slot to the slot (UP to the box title, RIGHT per box,
      DOWN onto the row's third slot, LEFT or RIGHT, DOWN; Box 1 and Box 3 told
      by the title bar, {!Frlg_readers.Pc_box_screen.title_wallpaper}, read once
      more if no box screen showed), the box screen read
      ({!Frlg_readers.Pc_box_screen}, kept as [box<box>-slot<slot>.png]), back
      out to the overworld ({!Pc_box.leave}). Empty: PKMN DATA flat, and the
      hand's shadow on the first slot. Occupied: PKMN DATA shows text, and the
      level ({!Frlg_text.Text_lines.pc_data_level}) and the male mark as asked.
      The species is not read: the ACE Pokémon (0x0351) shows a ? picture and a
      garbled name. Fails as [box_slot_wrong] or [pc_box]. *)

type slot_check = {
  box : int;
  slot : int;  (** From 1. *)
  occupied : bool;
  level : int option;  (** Checked only on an occupied slot. *)
  male : bool option;  (** Checked only on an occupied slot. *)
}
(** ["check_box_slot"]'s args. *)

type box_view = {
  panel_occupied : bool option;
  desert : bool option;  (** Box 3's default wallpaper. *)
  hand_on_first_slot : bool option;
  male : bool option;
  level_shown : int -> bool;  (** PKMN DATA shows this level. *)
}
(** The box screen as read ({!Frlg_readers.Pc_box_screen}), [None] where a
    reading did not come. *)

val box_view : Effects.measurements -> box_view
(** The box screen read from one frame with {!Frlg_readers.Pc_box_screen}'s
    probes; [level_shown] reads PKMN DATA's level
    ({!Frlg_text.Text_lines.pc_data_level}) when asked. *)

(** What the box screen says about the checked slot. *)
type verdict =
  | As_asked  (** Box 3, and the slot occupied or empty as the check asks. *)
  | Wrong of string  (** Why the slot is not as asked. *)
  | Unread of string  (** Which reading did not come. *)

val slot_verdict : slot_check -> box_view -> verdict
(** The box must be Box 3 by its wallpaper and the slot occupied or empty as
    asked; an empty first slot also needs the hand's shadow on it, an occupied
    one the gender mark and level asked for. *)

val handlers :
  log:(string -> unit) ->
  party:Party_roster.t ref ->
  (string * Pokemon_engine.Game.game_action) list
(** ["write_glitched_mail"] and ["check_box_slot"], their args decoded first (a
    wrong arg fails as [bad_args] before anything is pressed); [party] finds the
    member a ["species"] names, [log] gets each step's line. *)
