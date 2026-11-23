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
    else Items. (Key items and berries are not looked up yet.) *)

val shown_rows : int
(** Rows the list shows: 6. *)

val scroll_row : int
(** The window row the cursor stops on going down: 3. *)

val taps_to_reveal : int -> int
(** Taps from the list's top before list row [k] (from 0) shows on the screen's
    bottom row: 0 while [k] is one of the first six, else [k - 2]. *)

val open_pocket_top : Frlg_readers.Bag_screen.pocket -> unit
(** From the overworld: the bag open on the pocket (turned to by LEFT or RIGHT
    as its arrows read) with the cursor on the list's top row. Fails as [no_bag]
    or [no_pocket]. *)

val select : string -> unit
(** In the open pocket, from the list's top: the item the slug names found by
    reading the rows, then DOWN until the cursor's own row reads its name (a
    lost tap is tapped again). Fails as [not_in_bag] when the item is not in the
    pocket. *)
