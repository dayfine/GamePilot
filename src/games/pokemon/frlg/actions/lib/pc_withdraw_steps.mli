(** What a PC withdraw presses on each screen it reads, from the overworld
    facing a Pokémon Center's PC to the overworld again with one Pokémon from
    the box moved into the party. Pure, so it runs in tests against looks made
    up by hand. New: the fork has no withdraw. It reads the screens as
    {!Pc_deposit_steps} does and keeps its bounds.

    The walk: A at the PC, on a message a wait first and B only at the second
    settled look in a row (as {!Pc_deposit_steps}: "Which PC should be
    accessed?" has the PC list right behind it in pokefirered pc.inc, so a B on
    the first look can cancel the list), A on the PC list's top row ("BILL'S PC"
    or "SOMEONE'S PC") once read, A on WITHDRAW POKéMON once read (UP toward it
    from a lower row). The box screen opens on the box the PC was last left on,
    the hand on its first slot (pokefirered [InitCursor]). The hand goes along
    the box's 30 slots, row by row, RIGHT on the first row, LEFT on the second
    (DOWN between them), until PKMN DATA names a species; A there, A on WITHDRAW
    (a Pokémon's menu's first row, once read), and the game moves it into the
    party's first free slot ([Task_WithdrawMon]). Once PKMN DATA is blank again
    (the hand is over the emptied slot), B through "Continue BOX operations?" (B
    is NO), the storage menu and the PC list to the overworld, seen twice.

    Which Pokémon: the first the hand finds holding nothing, any species. A box
    Pokémon holds no Mail (the PC takes none that does), and once withdrawn its
    mail index is 0xFF (pokefirered [BoxMonToMon], src/pokemon.c, sets
    [MON_DATA_MAIL] to [MAIL_NONE]). One holding an item (PKMN DATA prints its
    name) is passed: Retro Mail given to it would ask to switch items. A slot
    whose panel shows something but no species (an egg) is passed, and so is one
    whose item line did not read. A Pokémon's menu gets three looks to read its
    cursor and first row (its first frame did not read on mGBA). Fails when no
    box Pokémon holding nothing is found in the box, when a message comes after
    WITHDRAW ("Your party's full!"), or as {!Pc_deposit_steps} on a screen that
    does not settle. *)

type look = {
  view : Frlg_readers.Pc_screen.view;
  label : string option;  (** The text of the cursor's row, when read. *)
  species : string option;
      (** The species slug PKMN DATA shows, on a box screen, when read. *)
  panel_empty : bool option;
      (** PKMN DATA is flat: the hand is over an empty slot
          ({!Frlg_readers.Pc_box_screen.panel_occupied}). *)
  holds_item : bool option;
      (** PKMN DATA's held-item line has text
          ({!Frlg_readers.Pc_box_screen.holds_item}). *)
}
(** One look at the PC's screen: the view, the cursor row's label, and on a box
    screen PKMN DATA's species and whether it is blank. *)

type t
(** Where the withdraw is: opening the PC, walking the box's slots, on a
    Pokémon's menu, waiting for the game to move it, leaving. *)

val start : t
(** At the PC, nothing pressed. *)

val next : t -> look -> t * Pc_deposit_steps.press
(** The press for this look, and where the withdraw is once it went in. *)

val withdrawn : t -> string option
(** The species moved into the party, once the game took it. *)

val withdraw_row : string
(** ["WITHDRAW POKéMON"], matched in English: another language's game needs its
    own label. *)

val mon_withdraw_row : string
(** ["WITHDRAW"]: a box Pokémon's menu's first row, matched in English as
    {!withdraw_row}. *)

val box_slots : int
(** 30: six columns, five rows (pokefirered [IN_BOX_COUNT]). *)

val max_looks : int
(** 120: the looks {!next} may take, the slots walked included. *)
