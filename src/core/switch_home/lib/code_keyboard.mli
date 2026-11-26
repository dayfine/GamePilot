(** The Switch's own keyboard as a game opens it for a code (PLZA's Mystery Gift
    code): typing a code with the D-pad and A, on the keys it leaves enabled.
    The route is [type_code_cmds] in [plza_claim_and_bank.sh] from the BDSPLab
    lab tools (console B, 2026-11-20): its layout, its key-to-key moves round
    the disabled keys, and its presses (D-pad 80 ms, released 140; A 80 ms,
    released 180). The cursor read is the fork's
    NintendoSwitch_SystemKeyboardDetector.cpp (branch [ns/system-keyboard]): the
    centroid of the cursor border's cyan over the keys, mapped to the nearest
    key.

    The code keyboard's first four rows, ten columns each:
    {v
    1 2 3 4 5 6 7 8 9 0
    Q W E R T Y U . . P
    A S D F G H J K L .
    . X C V B N M . . .
    v}
    where [.] is a disabled key (I, O, Z and the punctuation), never stepped on.
    That is the QWERTY layout, the one console B's English and French games
    opened; a keyboard laid out otherwise (AZERTY, QWERTZ) is not supported: the
    presses would type other characters.

    Where it differs: the script assumed the cursor on "1" when the keyboard
    opens; here the cursor is read first (the fork: "the keyboard remembers the
    cursor between uses, so read it"), and only when no cursor reads is "1"
    assumed, as the script did, with a log line. The script's keyboard test knew
    only the dark theme's grey keys; the light theme's grey counts too. Read on
    console B's code keyboard (2026-11-25: dark, empty, cursor on "1"; I, O and
    Z greyed as the layout says), also shifted. *)

type key = { row : int; col : int }
(** A key: row 0 the digits, column 0 the leftmost. *)

val first_key : key
(** "1", where the script starts. *)

val key_of_char : char -> key option
(** The enabled key for a character (letters in either case); [None] for a
    disabled or absent one. *)

val normalize : string -> string
(** The code as typed: upper case, spaces and hyphens dropped. *)

val presses : from:key -> string -> (Wire.button list, string) result
(** The D-pad moves and A presses that type the code (after {!normalize}) from
    the cursor at [from]: per character, along its row then its column when
    neither path crosses a disabled key, else along its column then its row.
    [Error] naming the first character no enabled key types. *)

val probes : Wire.probe_spec list
(** The keyboard's probes on the whole 1920x1080 frame (the daemon's [native]
    viewport). *)

val shown : Effects.measurements -> bool
(** The keyboard is open: most of its keys' area (x 0.10 to 0.80, y 0.50 to 0.85
    of the frame) is the dark theme's grey keys (each channel 41 to 134, within
    15 of each other), as the script read it, or the light theme's (200 to 250),
    and a cursor reads ({!cursor}). The dark HOME menu passes too (its grey, its
    tile cursor's cyan): look for the keyboard only where it opens. *)

val cursor : Effects.measurements -> key option
(** The key under the cursor in the first four rows, from its border's cyan (red
    under 130, green over 160, blue over 170, green over red by 60); [None] when
    too little cyan shows (under 0.0005 of the frame). *)

val type_code :
  log:(string -> unit) -> picture:Wire.box -> string -> (unit, string) result
(** On the open keyboard: reads the cursor, then presses the code's keys.
    [Error] before any press when the picture is not the whole frame, the
    keyboard is not open, or the code has a character no enabled key types. *)
