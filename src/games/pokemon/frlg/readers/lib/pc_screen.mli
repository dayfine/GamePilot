(** Reader: what shows during a PC deposit, from one frame. Ported from the
    fork's Inference/Box/PokemonFRLG_PcScreenReader ([read_pc_screen()],
    [frlg/lean]), made from captures of FireRed on console B (2026-11-02, Route
    4's Pokémon Center), in GBA pixels, the same patches and thresholds:

    - the PC list ("Which PC should be accessed?") and the storage menu
      (WITHDRAW ... SEE YA!) are windows at the top left, their arrow at x 9 and
      rows 16 apart from y 12; both have the white message box below them;
    - the box screens have the PKMN DATA panel at the left. DEPOSIT shows the
      party in a teal column, the hand over the slot it points at; a Pokémon's
      menu (STORE, SUMMARY, MARK, RELEASE, CANCEL) opens at (154, 34), its arrow
      at x 160, rows 16 apart from y 44; "Deposit in which BOX?" a yellow box
      with the box's name; "Continue BOX operations?" a YES/NO at (188, 85).

    A dark frame (the fade into and out of a box screen) is [Other] whatever
    else it matches. A message box with nothing else is [Text]; a frame with
    none of these, no Start menu and not dark is the [Overworld], which a frame
    between two menus can look like: the caller confirms it on a later frame.

    Where we differ: an arrow's dark pixels are counted with every channel at
    most 110 (the wire's color ranges are per channel; the fork sums the three
    under 330), and a party slot's hand white with every channel 235 and over
    (the fork also bounds the spread to 20). The box grid (WITHDRAW) is not
    read: a deposit never shows it. GamePilot's own: under WITHDRAW, a box
    Pokémon's menu (WITHDRAW, SUMMARY, ...) is wider and its arrow
    {!withdraw_shift} pixels left; its cursor is read there when STORE's column
    shows none. *)

type screen =
  | Overworld
  | Text  (** A message waiting for a button. *)
  | Pc_list  (** "Which PC should be accessed?". *)
  | Storage_menu  (** WITHDRAW, DEPOSIT, MOVE POKéMON, MOVE ITEMS, SEE YA!. *)
  | Party_panel
      (** DEPOSIT's box screen: the hand on the party (0-5, 6 CANCEL). *)
  | Box_grid  (** A box screen that is none of the others. *)
  | Mon_menu  (** A Pokémon's menu: STORE, SUMMARY, MARK, RELEASE, CANCEL. *)
  | Box_chooser  (** "Deposit in which BOX?". *)
  | Yes_no  (** "Continue BOX operations?". *)
  | Other  (** A fade, a frame between two screens. *)

type view = { screen : screen; cursor : int option }
(** The cursor's row (a menu, the party panel; YES/NO: 0 YES, 1 NO), when read.
*)

val probes : Wire.probe_spec list
val read : Effects.measurements -> view

val box_screen_shown : Effects.measurements -> bool
(** The box screen shows, whatever is over its grid: the PKMN DATA panel's
    lilac, the screen not dark. {!read} can take a yellow wallpaper's grid
    (Savanna, Box 4's default) for the box chooser; this does not look at the
    grid. *)

val screen_name : screen -> string
(** ["storage menu"], as the fork's [pc_screen_name()]. *)

val withdraw_shift : int
(** 8: how far left of STORE's a box Pokémon's menu under WITHDRAW sits, its
    arrow at x 153 and its text from x 160 (mGBA, 2026-11-25), because WITHDRAW
    is wider than STORE. Measured on the English game: another language's labels
    have other widths, and its menu needs its own measure. Also
    {!Frlg_text.Text_lines.pc_withdraw_menu_row}'s shift. *)

val storage_menu_rows : int
(** 5. *)

val party_panel_rows : int
(** 7: the lead, five slots, CANCEL. *)
