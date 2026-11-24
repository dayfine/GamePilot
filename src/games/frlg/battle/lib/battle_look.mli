(** One look at a battle: the readers' facts, and which screen they make. Pure
    apart from {!of_measurements}, so the rules that act on a look run in tests
    on facts alone. *)

type facts = {
  action_menu : bool;  (** FIGHT / BAG / POKEMON / RUN *)
  move_menu : bool;  (** the moves box and the PP box *)
  text_box : bool;  (** the full-width teal text box *)
  level_up : bool;  (** the stats box after a level up *)
  player_box : bool;  (** the player's HP box *)
  move_learn : bool;
      (** a YES/NO with the player's HP box beside it: a move to learn *)
  foe_box : bool;  (** the foe's HP box *)
  party_list : bool;  (** the party list *)
  bag : bool;  (** the bag *)
  yes_no : bool;  (** a YES/NO box over the battle *)
  arrow : bool;  (** the battle text's red arrow: the page waits for a button *)
  evolution : bool;
      (** the text box with no HP box, arrow or YES/NO: an evolution, or a
          battle's text while it prints where no HP box reads *)
}

val nothing : facts
(** Every fact false. *)

(** What a look shows, by the first fact that holds in this order. *)
type screen =
  | Yes_no
  | Party_list
  | Level_up
  | Move_menu
  | Action_menu
  | Bag
  | Text_arrow  (** battle text done, its arrow up *)
  | Evolution  (** what an evolution shows: nothing may be pressed *)
  | Battle_text  (** the text box or an HP box: the battle runs on *)
  | No_battle

val classify : facts -> screen
val screen_name : screen -> string

val probes : Wire.probe_spec list
(** The probes {!of_measurements} and {!Screen_driver} read: the battle
    screen's, its YES/NO box's, arrow's and PP's, the dark corners', the party
    menu's, the bag's, the summary screen's and its move list cursor's. *)

val of_measurements : Effects.measurements -> facts
(** The facts from {!Frlg_readers}. *)
