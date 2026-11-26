(** The PC's item storage: from the overworld facing a Pokémon Center's PC,
    PLAYER'S PC, ITEM STORAGE, WITHDRAW ITEM; its list read to CANCEL, and an
    item withdrawn by a count set in the quantity box. New, not in the fork,
    which never opens it: for frlg.ace (docs/design/FRLG-ACE-Execution.md),
    whose code writes its item into slot 30 of this storage, so the storage
    must hold fewer than 30 items first, and the item's stack must read x999
    after.

    From pret pokefirered ([ce6406d]): item_pc.c lists the stored items then
    CANCEL ([ItemPc_CountPcItems]: [nItems], the list [nItems + 1] rows), six
    rows at most, scrolled by list_menu.c as the bag is ({!Bag_items.taps_to_reveal});
    A on an item opens WITHDRAW, GIVE, CANCEL with the cursor on WITHDRAW
    ([sItemPcSubmenuOptions], [Menu_InitCursor] at 0); WITHDRAW of a stack of
    one takes it at once, of more opens the quantity box at x001
    ([Task_ItemPcWithdraw]), which UP and DOWN move by one, wrapping between 1
    and the stack, and RIGHT and LEFT by ten, stopping there
    (menu_helpers.c [AdjustQuantityAccordingToDPadInput]); A withdraws and
    prints "Withdrew ..." or "There is no more room in the BAG." until A or B. *)

(** What one list row shows. *)
type row =
  | Item of { named : bool; count : int }
      (** An item and its count; [named] when the name read is the one asked
          about. *)
  | Cancel

type game_steps = {
  open_withdraw : unit -> unit;
      (** From the overworld facing the PC to WITHDRAW ITEM's list, its cursor
          on the top row. *)
  read_row : int -> string -> row option;
      (** Shown row [i] (0..5), read against this item name. *)
  cursor_row : unit -> int option;  (** The list's arrow, 0..5. *)
  press : Wire.button -> unit;  (** A press and its wait. *)
  await_quantity : unit -> bool;  (** The quantity box shows. *)
  read_quantity : unit -> int option;  (** The quantity box's number. *)
  close : unit -> unit;  (** B out to the overworld. *)
}
(** What the item storage reads and presses in the game. *)

type stock = {
  items : int;  (** Rows before CANCEL: the stacks stored. *)
  stacks : (int * int) list;
      (** The asked item's stacks: list row (from 0) and count, top first. *)
}

val slots : int
(** 30: [PC_ITEMS_COUNT]. *)

val scan : game_steps -> string -> stock
(** From the list's top, every row read down to CANCEL, the cursor left on
    CANCEL. Fails as [item_storage_unread] on a row that reads as neither an
    item with a count nor CANCEL. *)

val quantity_press : now:int -> target:int -> stack:int -> Wire.button option
(** The press that moves the quantity box from [now] toward [target] (in 1 ..
    [stack]): DOWN from 1 straight to the stack when that is the target,
    RIGHT or LEFT while ten or more away, UP or DOWN for the rest; [None] at
    the target. *)

val max_quantity_presses : int
(** 200: more than any count needs (999 from 1 is one press; 990 from 1 is
    ten). *)

val withdraw : game_steps -> log:(string -> unit) -> string -> int -> unit
(** {!scan}, then the first stack of the item holding at least [count]: the
    cursor up to it (its row read again), A, A on WITHDRAW, the quantity set
    to [count] (each press read back), A, A past the message. Fails as
    {!scan}, or [item_storage_missing] (no stack that big),
    [item_storage_cursor] (the cursor is not on the stack),
    [item_storage_no_quantity] or [item_storage_quantity] (the box does not
    come or does not reach the count). *)

val check : game_steps -> log:(string -> unit) -> string -> int option -> unit
(** {!scan}; fails as [item_storage_full] with {!slots} items or more, and, for
    [Some n], as [item_storage_missing] unless a stack of the item reads [n]. *)

val screen_game_steps : log:(string -> unit) -> game_steps
(** The game's. *)

val handlers :
  log:(string -> unit) -> (string * Pokemon_engine.Game.game_action) list
(** [check_item_storage], args [{"item": <slug>, "count"?: <n>}], and
    [withdraw_from_item_storage], args [{"item": <slug>, "count": <n>}]: both
    from the overworld facing the PC and back there, the PC closed. *)
