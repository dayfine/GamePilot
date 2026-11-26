(** frlg.ace's 02-trigger around the trigger itself
    (docs/design/FRLG-ACE-Execution.md, "The program"): room for the item before
    the code runs, the item x999 in the PC's item storage after, and the run's
    [withdraw] count moved to the bag. The item and the count are the run's
    options ([item], [withdraw]); each action starts and ends in the overworld
    facing a Pokémon Center's PC. New, not in the fork, which has no ACE.

    The bag's room is its count of the item plus [withdraw], at most
    {!bag_most}. The pocket's free slot is not checked: the presets are all
    balls, and the Poké Balls pocket (13 slots, pokefirered
    [BAG_POKEBALLS_COUNT]) holds every one of the 12 kinds; a preset outside it
    needs that check first. *)

type game_steps = {
  storage : Item_storage.game_steps;  (** The PC's item storage. *)
  bag_count : string -> int option;
      (** From the overworld: the bag's count of the slug's item, [Some 0] when
          it holds none ({!Bag_items.count}). *)
}
(** What the checks read and press in the game. *)

type order = {
  slug : string;  (** The item: ["master-ball"]. *)
  name : string;  (** As the item storage lists it: ["MASTER BALL"]. *)
  withdraw : int;  (** 1 to 999. *)
}
(** What the run asked for. *)

val stack : int
(** 999: what the code stores. *)

val bag_most : int
(** 999: the most of one item the bag holds. *)

val check_room : game_steps -> log:(string -> unit) -> order -> unit
(** Fewer than {!Item_storage.slots} stacks stored ({!Item_storage.check}), and
    the bag's count plus the order's at most {!bag_most}. Fails as
    {!Item_storage.check}, [ace_bag_full], or [bag_unread]. *)

val check_stored : game_steps -> log:(string -> unit) -> order -> unit
(** A stack of the item reads {!stack} in the item storage; fails as
    {!Item_storage.check}. *)

val withdraw : game_steps -> log:(string -> unit) -> order -> unit
(** The bag's count read, the order's count withdrawn
    ({!Item_storage.withdraw}), the bag read again: it must have risen by the
    count. Fails as {!Item_storage.withdraw}, [bag_unread] or [ace_bag_count].
*)

val screen_game_steps : log:(string -> unit) -> game_steps
(** {!Item_storage.screen_game_steps} and {!Bag_items.count}. *)

val handlers :
  log:(string -> unit) ->
  options:Run_options.t ->
  (string * Pokemon_engine.Game.game_action) list
(** [ace_check_room], [ace_check_stored] and [ace_withdraw], no args: the order
    is the run's [item] and [withdraw] options; a missing option or an item the
    game does not name fails as [bad_args] before anything is pressed. *)
