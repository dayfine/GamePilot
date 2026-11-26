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
    so A never lands on a Pokémon's menu or on JUMP. *)

type rename = { from : string; to_ : string }
(** The box's name now and the one to give it. *)

type game_steps = {
  open_move_pokemon : unit -> unit;
      (** From the overworld facing the PC to MOVE POKéMON's box screen. *)
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
  close : unit -> unit;  (** B out of the box screen and the PC. *)
}
(** What the rename reads and presses on the game. *)

val name_row : int
(** 2: NAME on the title's menu. *)

val run : game_steps -> log:(string -> unit) -> rename -> unit
(** Fails as [box_name_not_from] (the title reads neither name),
    [box_menu_missing] (no NAME on row 2 after A on the title),
    [box_menu_cursor] (the arrow does not reach NAME), [naming_no_screen],
    {!Naming_entry.type_text}'s causes, or [box_name_wrong] (the title does not
    read the new name after OK). *)

val screen_game_steps : log:(string -> unit) -> game_steps
(** The game's. *)

val handlers :
  log:(string -> unit) -> (string * Pokemon_engine.Game.game_action) list
(** [rename_box], args [{"from": <name>, "to": <name>}]. *)
