(** Finding an item in the bag: the bag opened from the Start menu on a pocket
    with its cursor on the list's top row, then the item's row read by its name
    ({!Frlg_text.Line_reading}, the open pocket's names as candidates). The
    fork's open_bag_pocket_top and find_item_row_in_open_pocket
    (Programs/MailGlitch/PokemonFRLG_MailGlitchActions), driven by the bag's
    readers instead of counted presses.

    The bag's list scrolls as pokefirered's list_menu.c scrolls it: going down,
    the cursor stops on the window's fourth row and the list moves under it, so
    with the cursor on the list's top row the six rows shown are the list's
    first six, and each further tap shows one more on the bottom row. *)

val bag_row : int
(** BAG on the full Start menu: 2. *)

val display_name : string list -> string -> string option
(** The name among the pocket's names (["RETRO MAIL"]) that a plan's slug
    (["retro-mail"]) names: lowercase, é as e, spaces as dashes. *)

val pocket_of_item : string -> Frlg_readers.Bag_screen.pocket
(** The pocket a slug's item sits in: Poké Balls for a name ending in ["-ball"],
    Key Items for a key item's name (["coin-case"]), else Items. (Berries are
    not looked up yet.) *)

val shown_rows : int
(** Rows the list shows: 6. *)

val scroll_row : int
(** The window row the cursor stops on going down: 3. *)

val taps_to_reveal : int -> int
(** Taps from the list's top before list row [k] (from 0) shows on the screen's
    bottom row: 0 while [k] is one of the first six, else [k - 2]. *)

val pocket_top : Frlg_readers.Bag_screen.pocket -> unit
(** In the open bag (the Start menu's or a battle's BAG): to the pocket and its
    list's top row. Fails as [no_bag] or [no_pocket]. *)

val to_top : unit -> unit
(** In the open pocket: UP until the cursor reads on the list's top row (none
    when it is there). Fails as [no_pocket]. *)

val open_pocket_top : Frlg_readers.Bag_screen.pocket -> unit
(** From the overworld: the bag open on the pocket (turned to by LEFT or RIGHT
    as its arrows read) with the cursor on the list's top row. Fails as [no_bag]
    or [no_pocket]. *)

val item_action : string -> int -> unit
(** From the overworld: the item's pocket opened ({!open_pocket_top}), the item
    selected ({!select}), A, and once its menu shows (USE or CHECK or OPEN,
    GIVE, TOSS, CANCEL: the pocket arrows hide), the action on this row (from 0)
    chosen with A. Fails as {!open_pocket_top} and {!select} do, or as
    [no_item_menu]. *)

val count_on_row : int -> int option
(** The count on shown list row [row] (0..5; the Berry Pouch's 0..6, the same
    column), read digit by digit in the small font
    ({!Frlg_text.Text_lines.bag_count_digit}); [None] where no count shows (a
    key item, CANCEL, an empty row). Not in the fork, whose bag reader
    (Menus/PokemonFRLG_ItemListReader) reads counts with its own digit
    templates. Read right on mGBA (1 to 9) and on Switch captures (up to 21). *)

val select : string -> unit
(** In the open pocket, from the list's top: the item the slug names found by
    reading the rows, then DOWN until the cursor's own row reads its name (a
    lost tap is tapped again). Fails as [not_in_bag] when the item is not in the
    pocket. *)

val count : log:(string -> unit) -> string -> int option
(** From the overworld: the item's pocket opened ({!open_pocket_top}), its rows
    read down to the item as {!select} reads them, the count on its row
    ({!count_on_row}), then the bag closed and the talk settle. [Some 0] when
    the list reaches CANCEL first; [None] when a row or the count did not read.
    New for the end checks: the fork's [check_postconditions()] reads counts
    with its own bag reader (Menus/PokemonFRLG_ItemListReader). Fails as
    {!open_pocket_top}, or as [unknown_item] for a slug no item is named. *)

val list_row : string -> int option
(** In the item's open pocket, from the list's top: its row in the list (from
    0), the rows read down to it as {!select} reads them; [None] when the pocket
    does not hold it or a row does not read. The list may be left scrolled. *)

val count_in_pocket : string -> int option
(** {!count} in the open pocket, from the list's top: [Some 0] when the list
    reaches CANCEL first, [None] when a row or the count does not read. The
    cursor stays where the reading left it. *)
