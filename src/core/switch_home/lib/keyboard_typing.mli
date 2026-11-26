(** Typing text on the Switch's own keyboard as a game opens it for a name,
    reading the cursor before each key, so it starts wherever the cursor is and
    corrects a move the keyboard dropped: a port of the fork's
    NintendoSwitch_SystemKeyboardTyping.cpp (branch [lab/dev-plza-slice1]), its
    moves, holds, waits and tries, with the QWERTY layout of
    NintendoSwitch_KeyboardEntryMappings.cpp and the key-to-key path of
    NintendoSwitch_KeyboardCodeEntry.cpp (rows first, then columns the short way
    round the 12-column ring, wrapping at the sides). The text field's white
    pixels are NintendoSwitch_SystemKeyboardDetector.cpp's.

    The keyboard's first page, four rows of eleven:
    {v
    1 2 3 4 5 6 7 8 9 0 -
    Q W E R T Y U I O P /
    A S D F G H J K L : '
    Z X C V B N M , . ? !
    v}
    Letters are typed by their key, an upper-case one with Shift (the left
    stick's click) first; the keyboard opens with Shift off. Only this QWERTY
    layout is typed on, the one console B's English and French games opened: a
    keyboard laid out otherwise (AZERTY, QWERTZ) is not supported, as for
    {!Code_keyboard}: the presses would type other characters.

    The same keyboard as {!Code_keyboard}'s, and its cursor read
    ({!Code_keyboard.cursor}); the code keyboard's typer is the lab script's,
    which presses its whole route blind round the disabled keys.

    Where it differs: the cursor reads only on the four character rows and the
    eleven character columns ({!Code_keyboard.cursor}). On the right column
    (backspace, Return, OK) or the bottom row it reads as none, where the fork
    reads it and steps back onto the characters, so a cursor left there fails
    after the tries. Nothing types to there. *)

type game_steps = {
  read_cursor : unit -> Code_keyboard.key option;
      (** The key under the cursor, once the inputs are done. *)
  read_text_pixels : unit -> int;
      (** The text field's white pixels ({!text_pixels}), once the inputs are
          done. *)
  submit : Wire.command list -> unit;
      (** Send inputs and return once they are done. *)
  log : string -> unit;
      (** A line for the run's log: each move toward a key (the cursor read, the
          key, the moves, the try) and each read with no cursor. *)
}
(** What the typer reads and does on the keyboard. *)

val key_of_char : char -> Code_keyboard.key option
(** The first page's key for a character (a letter in either case); [None] for
    one not on it. *)

val missing : string -> string
(** The characters of the text no key types, in order; [""] when every one has a
    key. *)

type move = { button : Wire.button; wraps : bool }
(** One D-pad move; [wraps] when it wraps round a side (a longer release). *)

val path : from:Code_keyboard.key -> Code_keyboard.key -> move list
(** The moves from one key to another: up or down to the row, then along it the
    shorter way round the twelve columns (the right column the twelfth). *)

val type_text : game_steps -> string -> (unit, string) result
(** Types the text: for each character, moves the cursor onto its key (read
    first, then the path, 300 ms, read again; 10 tries), then Shift for an
    upper-case letter and A, and checks that the field gained 10 white pixels
    (read 3 times, 300 ms apart). Holds 80 ms (the fork's Switch 1 code entry
    hold); releases 200 ms after a move, 400 after a wrap, 250 after Shift, 300
    after A. [Error] before any press when a character has no key, else when the
    cursor does not reach a key or a key adds nothing to the field (a wrong case
    is not caught). *)

val probes : Wire.probe_spec list
(** {!Code_keyboard.probes} and the text field's, on the whole 1920x1080 frame
    (the daemon's [native] viewport). *)

val text_pixels : Effects.measurements -> int
(** The text field's white pixels (every channel over 190; x 0.03 to 0.90, y
    0.17 to 0.275 of the frame, above its underline), counted as on the 1080p
    frame; 0 with no probe. A typed "1" adds about 110. *)
