(** Types a text on the naming screen (a box's name, the player's, a Pokémon's
    nickname), each step checked on screen. New, not in the fork, which has no
    FRLG naming screen; the keys and the cursor's moves are pokefirered
    src/naming_screen.c's:

    - the cursor wraps from the top row to the bottom one and back, and from the
      last column into the button column (page, BACK, OK), which the typer never
      enters: it goes LEFT or RIGHT straight to the key's column, UP or DOWN the
      shorter way round ([HandleDpadMovement]);
    - SELECT turns the page (capitals, small letters, others), keeping the
      cursor's column or the page's last one ([MainState_WaitPageSwap]); B
      deletes the last character, START puts the cursor on OK.

    For each character: SELECT until {!Frlg_readers.Naming_screen.page} reads
    its page, the moves, the cursor read on its key
    ({!Frlg_readers.Naming_screen.key}; moved again from where it is if not, and
    LEFT off the button column when it reads on no key), A, then its cell read
    ({!Frlg_text.Text_lines.naming_entry_cell}, against every character the
    keyboard types and a blank). A wrong character, or one typed twice, is
    deleted with B and typed again. Once all are in, every cell is read again,
    then START and A press OK.

    English only: the keys are the English game's, read in its font. The Switch
    release keeps a name only when it passes the game's bad-word check
    ([svc_BadWordCheck], REVISION 0xA); mGBA's FireRed has none. *)

type game_steps = {
  read_page : unit -> Frlg_readers.Naming_screen.page;
      (** fails as [naming_no_page] when no page reads *)
  read_key :
    Frlg_readers.Naming_screen.page -> Frlg_readers.Naming_screen.key option;
      (** the key the cursor is on; [None] when it reads on none (the button
          column, where typing the last character leaves it) *)
  read_cell : int -> string option;
      (** what entry cell [i] shows: a character, [" "] when blank, [None] when
          it reads as none *)
  press : Wire.button -> unit;  (** a press and its wait *)
}
(** What the typer reads and presses on the naming screen. *)

val max_tries : int
(** Tries per character, and cursor moves per key, before the typer gives up: 3.
*)

val moves :
  Frlg_readers.Naming_screen.key ->
  Frlg_readers.Naming_screen.key ->
  Wire.button list
(** From one key to another on a page: UP or DOWN the shorter way (DOWN on a
    tie), then LEFT or RIGHT without wrapping. *)

val type_text :
  game_steps -> log:(string -> unit) -> max_chars:int -> string -> unit
(** On the naming screen with an empty entry: types the text and presses OK.
    Fails before any press as [bad_args] when a character is not on the
    keyboard, the text is longer than [max_chars] or has nothing but spaces (the
    game keeps the old name then); as [naming_no_page], [naming_no_cursor],
    [naming_wrong_page] (SELECT showed another page than the next) or
    [naming_text_wrong] (a cell still wrong after {!max_tries}, or the final
    read) while typing, before OK. *)

val screen_game_steps : max_chars:int -> game_steps
(** The game's: the readers awaited on the frames, presses paced as measured on
    mGBA (a D-pad tap 80 ms held and 240 ms released, A and B 80 then 400,
    SELECT 80 then 1000 for the page's slide). *)

val box_name_chars : int
(** 8: a box's name ([BOX_NAME_LENGTH]). *)
