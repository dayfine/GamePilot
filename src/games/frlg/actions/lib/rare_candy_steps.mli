(** The game's {!Rare_candy.game_steps}, and the party menu's
    {!Level_up.game_steps} in them: the bag's Rare Candy used on a member
    ({!Bag_items.item_action}, USE, {!Party_actions.choose_slot}), then what
    follows read and answered as upstream's [use_rare_candy()]
    (Programs/RngManipulation/PokemonFRLG_RngNavigation.cpp) watches for it: the
    stats window and the party's YES/NO box ({!Frlg_readers.Party_dialogs}, its
    PartyLevelUpWatcher and PartyMoveLearnWatcher), the evolution scene
    ({!Level_up_screens}, its BattleDialogWatcher) and the bag
    ({!Frlg_readers.Bag_screen}, its BagWatcher). The list to forget from is
    worked as the battle's ({!Frlg_battle.Screen_driver}): read by
    {!Summary_moves}, its cursor by {!Frlg_readers.Move_list_cursor}.

    Where it differs:
    - Text is pressed with A, never B (the C++ mashes B, which would cancel an
      evolution the plan lets run): on a page with its advance arrow at once, on
      a message with none ("... was elevated to Lv. 51.") once it has shown
      {!still_ms} with no box over it, so no A lands on a YES/NO box as it
      draws. An A that went to YES anyway shows the list, which the decisions
      take as {!Level_up.Forget_list}.
    - A cancel holds B for {!evolution_hold_ms} from the scene's first look: the
      game stops the evolution while B alone is held as the sprites cycle.

    Run it with {!Menu_input.probes} and {!probes} subscribed. Its menu steps
    fail as a Result ({!Menu_step}), not by raising. *)

val probes : Wire.probe_spec list
(** {!Frlg_readers.Party_dialogs}', the shared level-up screens'
    ({!Level_up_screens.probes}) and the white text box's
    ({!Frlg_readers.Dialog}). *)

val party_menu : Level_up_screens.context
(** The party menu's screens: its stats window and YES/NO box
    ({!Frlg_readers.Party_dialogs}), and the bag (no item menu over it) where it
    ends. *)

val classify : Effects.measurements -> Level_up.look option
(** {!Level_up_screens.classify} on {!party_menu}. *)

val still_ms : int
(** 1500 ms. *)

val evolution_hold_ms : int
(** 12 s: the scene's start (its message, the cry, the intro sound, the
    sparkles) lasts some seconds before the sprites cycle. Unmeasured. *)

val party_menu_game_steps : log:(string -> unit) -> Level_up.game_steps
(** The party menu's {!Level_up.game_steps}: a stats window pressed through
    (both pages) is one {!Level_up.Stats}; {!Level_up.Back} is the bag. *)

val make : log:(string -> unit) -> Rare_candy.game_steps
