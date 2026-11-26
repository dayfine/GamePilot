(** Where a line of text sits on an FRLG screen, in game pixels (240x160).
    Measured on Switch captures by matching drawn words (the fork's
    CommandLineTests images); the game draws the same pixels on every backend.
*)

type t = {
  id : string;  (** names the line in probe ids, e.g. ["bag.2"] *)
  left : int;  (** x of the first glyph's left edge *)
  glyph_top : int;  (** y of the glyphs' top row (row 0 of the font cell) *)
  indent : int;
      (** blank columns the template keeps left of the text: on a row that shows
          other text there (the TM case's CLOSE), nothing matches *)
  width : int;
      (** the template's width from [left - indent]: the name column, blank
          included, so a short word does not match a longer one's start *)
}

val bag_row : int -> t
(** Row [i] (0..5) of a bag pocket's list: item names and CANCEL. *)

val tm_case_row : int -> t
(** Row [i] (0..4) of the TM case list: the move name after "No03 ". The CLOSE
    row starts further left and matches nothing here. *)

val summary_move : int -> t
(** Move [i] (0..3) on the summary's KNOWN MOVES page; row 4 is the move offered
    on the list a battle opens to forget a move from (the same 28-pixel pitch,
    pokefirered pokemon_summary_screen.c). *)

val battle_message : int -> t
(** Line [i] (0..1) of a battle's message box, white on teal ("Wild SPEAROW
    appeared!"; read with {!Line_reading.light_ink}), as wide as the box.
    Measured on mGBA frames of the opening message (Route 16, mg-02 testing run
    7): its capitals from x 10, rows from 125, three below the cell's top as on
    the bag's list. *)

val start_menu_row : int -> t
(** Row [i] (0..6) of the Start menu's names (POKéDEX, POKéMON, BAG, the
    player's, SAVE, OPTION, EXIT on the full menu). Measured on mGBA
    (mail-glitch-04 pause-menu.png, 2026-11-23): the capitals' top at y 11 + 15
    i (glyph cell top 3 above), the names from x 184, the window's right edge at
    x 234. *)

val summary_species : t
(** The species on the summary's POKéMON INFO page (page 1), right of NAME:
    pokefirered pokemon_summary_screen.c, [PrintInfoPage], at (47, 19) in the
    right pane's window (15 tiles from the left, 2 from the top). Placed from
    the source and read right on mGBA (each member of mg-02's start,
    2026-11-23). *)

val digit_width : int
(** Every digit of the normal font is 6 pixels wide. *)

val trainer_card_money_digit : int -> t
(** Digit [k] of the money on the Trainer Card's front, counted from the right
    (0: ones): pokefirered trainer_card.c, [PrintMoneyOnCard], right-aligns
    ["¥<money>"] to end at x 136 of window 1 (at (8, 8)), at y 56. Read right on
    mGBA ($25,014 and $29,114, 2026-11-23). *)

val trainer_card_dex_digit : int -> t
(** Digit [k] of the Pokédex count on the Trainer Card's front, counted from the
    right (0: ones): pokefirered src/trainer_card.c right-aligns the count of
    species caught to end at x 136 of window 1, at y 72, so the ones digit
    starts at x 138 of the picture, as the money's does, two rows of 16 pixels
    lower. The count is the Kanto Pokédex's until the National Pokédex is
    enabled, then the National one's; 3 digits at most. *)

val bag_message_digit : int -> t
(** Digit [k] (from the left) of the bag message's second line, where the Coin
    Case's ["Your COINS:\n<coins>"] (pokefirered strings.c [gText_CoinCase],
    item_use.c [FieldUseFunc_CoinCase], left-aligned) prints its count: the
    message window 5 of bag.c at (16, 120), the second line's glyphs at y 137.
    Read right on mGBA (20 coins, 2026-11-23). *)

val summary_level_digit : int -> t
(** Digit [k] (from the left) of the level in the summary's top left, shown on
    every page: white with a dark shadow on the header's lilac (teal on the info
    page), after the 10-pixel "Lv" glyph at x 4, so the first digit starts at x
    14 with its cell's top at y 18. The box of the fork's
    PokemonFRLG_StatsReader ([m_box_level], English and the other Latin
    languages but Spanish) holds it. Measured on mGBA (MIMIEN Lv 9, Lv 50,
    2026-11-23); read with {!Summary_level.ink}. *)

val small_digit_width : int
(** Every digit (and the space) of the small font is 5 pixels wide. *)

val bag_count_digit : int -> int -> t
(** [bag_count_digit row k]: digit [k], counted from the right (0: ones), of the
    count on list row [row] of a bag pocket (0..5) or the Berry Pouch (0..6).
    Small font: pokefirered item_menu.c [BagListMenuItemPrintFunc] and
    berry_pouch.c [BerryPouchItemPrintFunc] print ["×<count>"] (the count right
    aligned in 3 cells, spaces before it) at x 110 of the list window (left 88),
    on the row's line; the × is 8 wide, so the ones digit starts at x 216. *)

val berry_pouch_number_digit : int -> int -> t
(** [berry_pouch_number_digit row k]: digit [k] (0: tens) of the berry's number
    on Berry Pouch row [row] (0..6), the ["06"] of ["No06 LEPPA BERRY"]. Small
    font: pokefirered berry_pouch.c [GetBerryNameAndIndexForMenu] prints the No
    symbol (8 wide), a 1-pixel gap and the two digits (leading zero) from the
    label's x 97, so the digits start at x 106. *)

val mail_field_one : width:int -> t
(** The first word field of the Easy Chat mail editor, [width] pixels from its
    left: pokefirered easy_chat_3.c prints each row of the phrase window as
    [CLEAR 17], the word (or seven underscores for an empty field), [CLEAR 17],
    the next word, so field 1 starts 17 pixels into the window and the next
    field after the word and a 17-pixel gap. The window's left (x 24) and top
    measured on mGBA, where ABRA reads at x 41, glyphs from y 2 (2026-11-23). *)

val mail_field : row:int -> left:int -> width:int -> t
(** A word field on row [row] (0..4) of the mail editor, starting [left] pixels
    into the picture: each row's first field at {!mail_field_one}'s x 41, the
    second after the first's word and a 17-pixel gap; rows 16 apart (pokefirered
    easy_chat_3.c prints row [i] at y [16 i]). Measured on mGBA (the ? Mail's
    ??? fields and BULK UP, CAPABLE, KARATE CHOP, MAGIKARP, 2026-11-25). *)

val easy_chat_rows : int
(** Rows the Easy Chat lower panel shows at once: 4. *)

val easy_chat_word_cell : row:int -> col:int -> width:int -> t
(** A word on shown row [row] (0..3) and column [col] (0..1) of the Easy Chat
    word list: pokefirered easy_chat_3.c prints column [j] at x [(13 j + 3) 8]
    of window 2 (at x 8), rows 16 apart; the shown rows' glyph tops at y 92,
    108, 124, 140. Measured on mGBA (MOVE 1, ACTIONS, MOVE 2 and POKéMON lists,
    2026-11-25). *)

val easy_chat_group_cell : row:int -> col:int -> width:int -> t
(** A group's name on shown row [row] (0..3) and column [col] (0..1) of the Easy
    Chat group grid: easy_chat_3.c prints column [x] at x [84 x + 10] of window
    2, so x 18 and 102, on the word list's rows. Measured on mGBA. *)

val pc_data_level : t
(** The level's digits in the box screen's PKMN DATA panel, after the "Lv"
    glyph: white with a dark shadow (read with {!Line_reading.light_ink}), the
    digits' cell top at y 117 from x 34. Measured on mGBA (the ACE Pokémon in
    Box 3, Lv 100, 2026-11-25). *)

val pokedex_list_rows : int
(** Rows the Pokédex's numerical list shows at once: 9. *)

val pokedex_list_name : int -> t
(** The name on shown row [row] (0..8) of the Pokédex's numerical list: the
    species' name, or ["-----"] for one not seen. pokefirered pokedex_screen.c
    prints the list in window 1 tile from the left 2 and the top 2, its rows 14
    pixels apart from y 2 and its names at x 56, so at x 72 from y 18; type
    icons from x 136 on a caught species' row. Measured on mGBA (the Mail Glitch
    save's list, 2026-11-25), on the English game, whose names and dashes it is
    read against: another language needs its own names and a check of the
    positions. *)

val pokedex_list_number_digit : int -> int -> t
(** [pokedex_list_number_digit row k]: digit [k] (0: hundreds) of the number on
    shown row [row] (0..8) of the Pokédex's numerical list, the ["129"] of
    ["No129"]. Small font: pokedex_screen.c prints the No symbol at x 12 of the
    window and the three digits (leading zeros) 9 pixels right of it, so from x
    37. Measured on the English game: another language's No symbol may be wider,
    and the position needs a check there. *)

(** {1 Template rows and the probe box} *)

val template_top : int
(** The first glyph row a template keeps: row 0 is blank in every glyph. *)

val template_height : int
(** Rows kept: down to the shadow under descenders, above the next line's window
    decorations (the bag's dashed separators). *)

val slack : int
(** Game pixels the probe box extends past the template on each side, for a
    capture that is off by a pixel. *)

val box : t -> Wire.box
(** The probe box, normalized to the game picture. *)

val pc_menu_row : int -> t
(** Row [i] of the PC list ("BILL'S PC" on top) and of the storage menu
    (WITHDRAW POKéMON, DEPOSIT POKéMON, ...): pokefirered's menus, measured on
    console B's captures (the CommandLineTests of the fork's
    Inference/Box/PokemonFRLG_PcScreenReader.cpp) and mGBA frames. *)

val pc_mon_menu_row : int -> t
(** Row [i] (0-4) of a Pokémon's menu on the box screen: STORE, SUMMARY, MARK,
    RELEASE, CANCEL. *)

val pc_withdraw_menu_row : int -> t
(** Row [i] (0-4) of a box Pokémon's menu under WITHDRAW POKéMON: WITHDRAW,
    SUMMARY, MARK, RELEASE, CANCEL. WITHDRAW is wider than STORE, so the menu
    sits {!Frlg_readers.Pc_screen.withdraw_shift} pixels left of
    {!pc_mon_menu_row}'s (text from x 160, mGBA, 2026-11-25). Measured and
    matched on the English game: another language's labels have other widths,
    and its menu needs its own measure and text. *)

val pc_data_species : t
(** The box screen's PKMN DATA species line, ["/ODDISH"]: window 0 at (0, 88)
    prints it at (6, 14) (pokefirered [PrintDisplayMonInfo]), white with a dark
    shadow: read with {!Line_reading.light_ink}. *)

val pc_message : t
(** The box screen's message ("Deposit in which BOX?", "The BOX is full.",
    "Please remove the MAIL."): window 1 at (88, 136) prints at (0, 2)
    ([PrintStorageMessage]). The messages are matched in English: another
    language's game needs its own text. *)

val naming_entry_cell : max_chars:int -> int -> t
(** Character [i] (from 0) of the naming screen's text entry, on a screen that
    takes [max_chars] (a box's name 8, the player's 7, a Pokémon's 10): the game
    prints each character alone in an 8-pixel cell, the entry centred
    (pokefirered naming_screen.c, [DrawTextEntry]), so for a box's name from x
    94, its glyph cells' top at y 49. Measured on mGBA (BOX NAME?, every
    character of the English keyboard, 2026-11-25). The underscore under each
    cell (y 62 and below) stays out of the template's rows. *)
