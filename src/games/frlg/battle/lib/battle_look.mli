(** One look at a battle: the readers' facts, and which screen they make. Pure
    apart from {!of_measurements}, so the rules that act on a look run in tests
    on facts alone. *)

type facts = {
  action_menu : bool;  (** FIGHT / BAG / POKEMON / RUN *)
  move_menu : bool;  (** the moves box and the PP box *)
  text_box : bool;  (** the full-width teal text box *)
  level_up : bool;  (** the stats box after a level up *)
  player_box : bool;  (** the player's HP box *)
  foe_box : bool;  (** the foe's HP box *)
  party_list : bool;  (** the party list *)
  bag : bool;  (** the bag *)
  yes_no : bool;  (** a YES/NO box over the battle *)
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
  | Battle_text  (** the text box or an HP box: the battle runs on *)
  | No_battle

val classify : facts -> screen
val screen_name : screen -> string

val probes : Wire.probe_spec list
(** The probes {!of_measurements} reads: the battle screen's, the party menu's,
    the bag's and the summary screen's. *)

val of_measurements : Effects.measurements -> facts
(** The facts from {!Frlg_readers}. There is no reader for the battle's YES/NO
    box yet (it needs a capture of one), so [yes_no] is always false: a prompt
    reads as battle text, which gets B, and B answers NO ("Delete a move?": NO,
    then "Stop learning?": B is YES, so the move is not learned). *)
