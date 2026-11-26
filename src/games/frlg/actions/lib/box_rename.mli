(** Renames the box the PC shows: from the overworld facing a Pokémon Center's
    PC, BILL'S PC, MOVE POKéMON, the hand UP onto the box title, A, NAME on its
    menu, the name typed on the naming screen ({!Naming_entry}), and the title
    read back; then B out to the overworld. New, not in the fork, which never
    renames a box: step 2 of docs/roadmap/frlg-ace-balls.md.

    The box screen opens on the box last viewed. Its title must read [from]
    before anything is typed ({!Frlg_text.Box_title}), so a plan names the box
    by its current name; a title that reads [to] already is left as it is (a
    rerun after the rename). The menu's rows are read (JUMP, WALLPAPER, NAME,
    CANCEL from x 152, glyph cells from y 58, 16 apart, measured on mGBA) and
    its arrow ({!Frlg_readers.Pc_box_screen.title_menu_row}) before A on NAME,
    so A never lands on a Pokémon's menu or on JUMP.

    The walk to the box screen and back out is {!Pc_box}'s. The menu's labels
    (JUMP, WALLPAPER, NAME, CANCEL) and the title are matched in English, as
    {!Pc_box} matches MOVE POKéMON: another language's game needs its own. *)

type rename = { from : string; to_ : string }
(** The box's name now and the one to give it. *)

type game_steps = {
  open_move_pokemon : unit -> unit;
      (** From the overworld facing the PC to MOVE POKéMON's box screen
          ({!Pc_box.to_box_screen}). *)
  read_title : string list -> string option;
      (** Which of these the box title reads, if any. *)
  read_menu_label : int -> string option;
      (** What row [i] of the title's menu reads: JUMP, WALLPAPER, NAME or
          CANCEL. *)
  read_menu_row : unit -> int option;  (** The title menu's arrow. *)
  await_naming_screen : unit -> bool;
      (** The naming screen shows, on its capitals. *)
  type_name : string -> unit;  (** {!Naming_entry.type_text}. *)
  await_box_screen : unit -> bool;  (** Back on the box screen. *)
  press : Wire.button -> unit;  (** A press and its wait. *)
  close : unit -> unit;
      (** Out of the box screen and the PC ({!Pc_box.leave}). *)
}
(** What the rename reads and presses on the game. *)

val name_row : int
(** 2: NAME on the title's menu. *)

val name_on_title :
  game_steps -> log:(string -> unit) -> others:string list -> string -> unit
(** With the hand on the box screen's title: A, NAME on its menu, the name typed
    and OK, then the title read back against the name and [others] (what it may
    still read); fails as {!run} does after its first read. *)

val run : game_steps -> log:(string -> unit) -> rename -> unit
(** Fails as [box_name_not_from] (the title reads neither name),
    [box_menu_missing] (no NAME on row 2 after A on the title),
    [box_menu_cursor] (the arrow does not reach NAME), [naming_no_screen],
    {!Naming_entry.type_text}'s causes, or [box_name_wrong] (the title does not
    read the new name after OK). *)

val screen_game_steps : log:(string -> unit) -> game_steps
(** The real reads and presses: {!Pc_box.to_box_screen} and {!Pc_box.leave} on
    {!Frlg_readers.Pc_screen}'s probes to open and close the PC; the title by
    {!Frlg_text.Box_title}, read again while it slides in; the menu's rows by
    their glyphs and its arrow on {!Frlg_readers.Pc_box_screen}'s probes; the
    naming screen awaited on {!Frlg_readers.Naming_screen}'s probes and typed by
    {!Naming_entry.type_text}; the box screen awaited by its PKMN DATA panel
    ({!Frlg_readers.Pc_screen.box_screen_shown}: a Savanna grid reads as the box
    chooser). Logs to [log]. *)

val handlers :
  log:(string -> unit) -> (string * Pokemon_engine.Game.game_action) list
(** [rename_box], args [{"from": <name>, "to": <name>}]. *)
