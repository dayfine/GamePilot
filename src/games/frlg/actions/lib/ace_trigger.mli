(** The ACE trigger (frlg.ace's 02-trigger, docs/design/FRLG-ACE-Execution.md):
    from the overworld facing a Pokémon Center's PC, MOVE POKéMON, the partner
    put in Box 3 slot 2 if it is not there, then the two swaps that run the box
    names' code, and a check that the game still answers. New, not in the fork,
    which has no ACE.

    The presses, from pret pokefirered ([ce6406d]):
    - the box screen's hand: UP from the top row goes to the box title, LEFT and
      RIGHT on the title scroll the box, DOWN from the title lands on the top
      row's third slot (pokemon_storage_system_data.c [HandleInput_InBox_Normal]
      and [HandleInput_BoxTitle]); L and R are the help system's in the default
      button mode, so boxes are never scrolled with them;
    - SELECT toggles the hand's quick mode, its sprite palette switched
      ([ToggleCursorMultiMoveMode]: [cursorPalNums[1]], the orange hand): with
      it on, A on a Pokémon in MOVE POKéMON picks it up with no menu (the
      multi-move grab of one, [HandleInput_InBox_GrabbingMultiple] then
      [INPUT_MULTIMOVE_SINGLE]), and A over a slot while holding one shifts or
      places ([MENU_TEXT_SHIFT], [MENU_TEXT_PLACE]: [INPUT_SHIFT_MON] runs
      pokemon_storage_system_tasks.c [Task_ShiftMon], [INPUT_PLACE_MON]
      [Task_PlaceMon]);
    - the second shift picks species 0x0351 up again: its PKMN DATA name
      overruns into [monPlaceChangeFunc] and the code runs (the design note,
      "How the code runs").

    Boxes are told by their titles ({!Frlg_text.Box_title}): after the code is
    typed, Box 1 and Box 3 read the code's names, so a plan gives them. *)

type trigger = {
  box1_title : string;  (** Box 1's name: where the partner waits. *)
  box3_title : string;  (** Box 3's name: 0x0351 in slot 1. *)
  partner : string;  (** The partner's species slug (["mr-mime"]). *)
}
(** ["ace_trigger"]'s args. *)

type game_steps = {
  open_move_pokemon : unit -> unit;
      (** From the overworld facing the PC to MOVE POKéMON's box screen, the
          hand on the shown box's first slot. *)
  press : Wire.button -> unit;  (** A press and the wait after it. *)
  read_title : string list -> string option;
      (** Which of these the box title reads, if any. *)
  species_at_hand : unit -> string option;
      (** The species slug PKMN DATA shows for the slot under the hand. *)
  slot_empty : unit -> bool option;  (** PKMN DATA is flat: no Pokémon. *)
  ace_at_hand : unit -> bool;
      (** PKMN DATA shows species 0x0351: Lv 100, the male mark. *)
  hand_quick : unit -> bool option;
      (** The hand is orange ({!Frlg_readers.Pc_box_screen.hand_quick}). *)
  await_alive : string -> bool;
      (** With the hand on the title, the title reads this name within
          {!alive_timeout_ms}: the game still runs and draws. *)
  close : unit -> unit;  (** B out of the box screen and the PC. *)
}
(** What the trigger reads and presses on the game. *)

val boxes : int
(** 14: the most scrolls that can find a box. *)

val alive_timeout_ms : int
(** 3000. *)

val run : game_steps -> log:(string -> unit) -> trigger -> unit
(** Fails as [ace_box_not_found] (no title reads the box in {!boxes} scrolls),
    [ace_partner_missing] (Box 1 slot 1 does not hold the partner),
    [ace_slot_taken] (Box 3 slot 2 holds another Pokémon), [ace_not_in_slot]
    (Box 3 slot 1 does not show 0x0351), [ace_hand_not_quick] (SELECT did not
    turn the hand orange) or [ace_game_stopped] (no box title after the swaps:
    the game hung or reset). *)

val screen_game_steps : log:(string -> unit) -> game_steps
(** The game's. *)

val handlers :
  log:(string -> unit) -> (string * Pokemon_engine.Game.game_action) list
(** [ace_trigger], args [{"box1_title", "box3_title", "partner"}]. *)
