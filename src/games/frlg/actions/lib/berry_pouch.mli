(** Giving a berry from the Berry Pouch: the pouch opened from Key Items and the
    berry's row found by its number, the ["06"] of ["No06 LEPPA BERRY"], which
    every language prints the same. Ported from the fork's Mail Glitch give step
    (Programs/MailGlitch/PokemonFRLG_MailGlitchActions: [run_give_bag_item()]'s
    berry branch and [find_berry_row_in_pouch()], as on the tested Route 16 run
    of 2026-11-23), with its presses and waits.

    Where it differs: the pouch's numbers are read with the small font's glyphs
    ({!Frlg_text.Text_lines.berry_pouch_number_digit}), not the fork's digit
    templates; a berry's number is its place in the game's berry order (the item
    names' Berry Pouch list), where the fork knows three (Leppa 6, Oran 7,
    Sitrus 10); and the pouch is waited for by its reader
    ({!Frlg_readers.Berry_pouch_screen}) after the fork's 2 s. *)

val is_berry : string -> bool
(** A slug ending in ["-berry"]. *)

val berry_number : string -> int option
(** The berry's number in the pouch (["leppa-berry"]: 6), from 1 in the game's
    berry order; [None] for no berry's slug. *)

val shown_rows : int
(** Rows the pouch's list shows: 7. *)

val scroll_downs : int
(** DOWN presses before the list scrolls: 3. After them each DOWN shows one more
    berry on the bottom row. *)

val open_pouch : unit -> unit
(** From the overworld: Key Items, BERRY POUCH, OPEN, the pouch read, then UP to
    its top. Fails as [no_berry_pouch] when it does not open. *)

val number_on_row : int -> int option
(** The berry number on shown row [row] (0..6); [None] on CLOSE or an empty row.
*)

val find_row : int -> int option
(** In the open pouch, from its top: the list row of the berry with this number,
    the shown rows read first, then one more row at a time (DOWN, the bottom row
    read) until the number, a row with none, or the same number twice; the
    cursor back at the top after. *)

val choose_give : string -> unit
(** From the overworld: the pouch opened, the berry found, DOWN to it, A, GIVE
    (row 1 of USE, GIVE, TOSS, EXIT), A. The party to give to follows. Fails as
    [unknown_item] for no berry's slug, [not_in_bag] when the pouch does not
    hold it. *)

val shows_pouch : Effects.measurements -> bool
(** The pouch shows ({!Frlg_readers.Berry_pouch_screen.berry_pouch}), for a
    caller that subscribes {!probes}. *)

val probes : Wire.probe_spec list
