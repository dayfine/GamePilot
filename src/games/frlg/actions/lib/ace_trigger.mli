(** The ACE trigger (frlg.ace's 02-trigger, docs/design/FRLG-ACE-Execution.md):
    from the overworld facing a Pokémon Center's PC, MOVE POKéMON, a partner
    (any Pokémon) put in Box 3 slot 2 if that slot is empty, then the two swaps
    that run the box names' code, and a check that the game still answers. New,
    not in the fork, which has no ACE.

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

    Box 3 is told by its title ({!Frlg_text.Box_title}): after the code is
    typed, it reads the code's name for it, the run's item's
    ({!Ace_presets.box_name}) unless a plan gives one. The partner's box is
    counted from Box 3 by scrolls; its partner is the first slot there, in
    reading order, that holds a Pokémon (PKMN DATA shows text), unless a plan
    names the slot. The species is never read: the swap needs a Pokémon there,
    not a given one. *)

type trigger = {
  box3_title : string;  (** Box 3's name: 0x0351 in slot 1. *)
  partner_box : int;
      (** Where the partner waits when Box 3 slot 2 is empty: its box (1-14,
          default 1) ... *)
  partner_slot : int option;
      (** ... and slot there (1-30); [None]: the box's first slot that holds a
          Pokémon (from slot 3 in Box 3). *)
}
(** ["ace_trigger"]'s args. *)

type game_steps = {
  open_move_pokemon : unit -> unit;
      (** From the overworld facing the PC to MOVE POKéMON's box screen, the
          hand on the shown box's first slot. *)
  press : Wire.button -> unit;  (** A press and the wait after it. *)
  read_title : string list -> string option;
      (** Which of these the box title reads, if any. *)
  slot_empty : unit -> bool option;
      (** PKMN DATA shows no text: the slot under the hand holds no Pokémon. *)
  ace_at_hand : unit -> bool;
      (** The slot under the hand passes {!Ace_mail.slot_verdict} for Box 3 slot
          1 occupied, Lv 100, the male mark: species 0x0351 as frlg.ace_setup
          leaves it. *)
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

val slots : int
(** 30: a box's slots. *)

val alive_timeout_ms : int
(** 3000. *)

val run : game_steps -> log:(string -> unit) -> trigger -> unit
(** Fails as [ace_box_not_found] (no title reads the box in {!boxes} scrolls, or
    the partner was put down in another box), [ace_partner_missing] (the
    partner's given slot holds no Pokémon, its box holds none, a slot does not
    read, or it did not land), [ace_not_in_slot] (Box 3 slot 1 does not show
    0x0351), [ace_hand_not_quick] (SELECT did not turn the hand orange) or
    [ace_game_stopped] (no box title after the swaps: the game hung or reset).
*)

val screen_game_steps : log:(string -> unit) -> game_steps
(** The box screen's steps on mGBA's timings: {!Pc_box}'s walk to MOVE POKéMON
    and out on {!Frlg_readers.Pc_screen}'s probes; presses held 100 ms, then a
    wait (LEFT, RIGHT and A 1200 ms: a box scroll, a shift; others 500 ms); the
    title read with {!Frlg_text.Box_title.read} (its own probes); [slot_empty],
    [hand_quick] and [ace_at_hand] from one frame of
    {!Frlg_readers.Pc_box_screen}'s probes, [ace_at_hand] also reading PKMN
    DATA's level; [await_alive] reads the title up to four times. *)

val handlers :
  log:(string -> unit) ->
  options:Run_options.t ->
  (string * Pokemon_engine.Game.game_action) list
(** [ace_trigger], args [{"box3_title"?, "partner_box"?, "partner_slot"?}]: the
    box 1-14 and slot 1-30, not Box 3 slot 1. With no [box3_title], Box 3's name
    is the run's [item] option's ({!Ace_presets.run_item}); with neither, it
    fails as [bad_args] before anything is pressed. *)
