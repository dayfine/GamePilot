(** From the overworld facing a Pokémon Center's PC to one of its menus, and
    back out: BILL'S PC (or SOMEONE'S PC), MOVE POKéMON, to the box screen; or
    the player's PC, ITEM STORAGE, WITHDRAW ITEM, to the stored items' list.
    GamePilot's own (the fork has no MOVE POKéMON walk and never opens item
    storage); it reads the screens as {!Pc_deposit} does.

    Not an ordered list of presses: each step looks at the screen and decides
    the next press from what it shows ({!open_next}, {!leave_next}), so a
    message, a fade or a cursor left on another row is handled wherever it
    comes. Both walks stop after {!max_looks} looks.

    The player's PC's menus are read by their top row's label in English (ITEM
    STORAGE, WITHDRAW ITEM): another language's game needs its own labels. *)

(** Where {!open_menu} goes. *)
type target =
  | Move_pokemon  (** BILL'S PC, MOVE POKéMON: the box screen. *)
  | Withdraw_item
      (** The player's PC (the PC list's second row, pokefirered pc.inc), ITEM
          STORAGE, WITHDRAW ITEM: the stored items' list
          ({!Frlg_readers.Item_pc_screen.shown}). *)

type look = {
  pc : Pc_deposit_steps.look;  (** The PC screen, the cursor's row and label. *)
  menu_top : string option;
      (** For [Withdraw_item] on a [Text] screen: the top row's label of the
          player's PC's menu (["ITEM STORAGE"]) or ITEM STORAGE's
          (["WITHDRAW ITEM"]), when it reads as one. Those menus have no cursor
          {!Frlg_readers.Pc_screen} reads, and open on their top row
          (pokefirered player_pc.c [Task_DrawPlayerPcTopMenu],
          [Task_CreateItemStorageSubmenu]). *)
  item_list : bool;  (** For [Withdraw_item]: WITHDRAW ITEM's list shows. *)
}
(** One look at the PC, as {!open_next} needs it for a target. *)

type game_steps = {
  look : target -> look;
      (** The screen, the cursor's row and its label, and what the target needs
          besides. *)
  press : Pc_deposit_steps.press -> unit;
      (** One press (or a wait) in the game, as {!open_next} or {!leave_next}
          chose it. *)
}
(** What the walk reads and presses in the game. *)

val screen_game_steps : game_steps
(** {!Pc_deposit.look}, plus for [Withdraw_item] the top menu row read on a
    [Text] screen and {!Frlg_readers.Item_pc_screen.shown}; {!Pc_deposit.press}.
    The caller subscribes {!Frlg_readers.Pc_screen}'s probes, and for
    [Withdraw_item] {!Frlg_readers.Item_pc_screen}'s. *)

type opening = {
  booted : bool;  (** A went in at the PC, so the overworld is not the PC. *)
  chosen : bool;
      (** A went in on the last menu row (MOVE POKéMON, WITHDRAW ITEM). *)
}
(** Where {!open_menu} is, from what it pressed so far. *)

val opening : opening
(** At the PC, nothing pressed. *)

(** What {!open_next} answers for one look: the walk is done, or the next press
    and where the walk will be once it went in. *)
type next =
  | Opened  (** The target shows: the walk is done. *)
  | Press of Pc_deposit_steps.press * opening
      (** The press, and where the walk is once it went in. *)

val open_next : target -> opening -> look -> next
(** [Move_pokemon]: the box screen ([Box_grid], or once MOVE POKéMON was chosen
    a settled frame that reads as the overworld: the box screen with a Pokémon's
    data shown does) is the end. Else A at the PC, B on a message, A on the PC
    list's top row once read, UP on another row, A on MOVE POKéMON once read,
    DOWN or UP toward it on the storage menu, and a wait on anything else.

    [Withdraw_item]: the item list is the end. Else A at the PC; on the PC list
    A on the second row, DOWN or UP toward it; A on a menu whose top row reads
    ITEM STORAGE or WITHDRAW ITEM; B on any other message until WITHDRAW ITEM
    was chosen; and a wait on anything else (the fade into the list). *)

val leave_next : Pc_deposit_steps.look -> Pc_deposit_steps.press option
(** [None] on the overworld; a wait on a fade; B on any other screen. *)

val max_looks : int
(** The most looks {!open_menu} or {!leave} takes before it fails: 40. *)

val open_menu : log:(string -> unit) -> game_steps -> target -> unit
(** Walks {!open_next} from {!opening}. Fails as [pc_box] when the target did
    not open in {!max_looks} looks. *)

val to_box_screen : log:(string -> unit) -> game_steps -> unit
(** {!open_menu} to [Move_pokemon]. *)

val leave : log:(string -> unit) -> game_steps -> unit
(** From the box screen, B (the box screen can read as the overworld), then
    {!leave_next} until the overworld. Fails as [pc_box] when it did not come
    back in {!max_looks} looks. *)
