open Frlg_readers

type facts = {
  action_menu : bool;
  move_menu : bool;
  text_box : bool;
  level_up : bool;
  player_box : bool;
  foe_box : bool;
  party_list : bool;
  bag : bool;
  yes_no : bool;
  arrow : bool;
  evolution : bool;
}

let nothing =
  {
    action_menu = false;
    move_menu = false;
    text_box = false;
    level_up = false;
    player_box = false;
    foe_box = false;
    party_list = false;
    bag = false;
    yes_no = false;
    arrow = false;
    evolution = false;
  }

type screen =
  | Yes_no
  | Party_list
  | Level_up
  | Move_menu
  | Action_menu
  | Bag
  | Text_arrow
  | Evolution
  | Battle_text
  | No_battle

(* A YES/NO and the party list come over the battle screen, so they go first;
   the move menu covers the action menu's place; the arrow and an evolution
   are kinds of battle text. *)
let order : ((facts -> bool) * screen) list =
  [
    ((fun f -> f.yes_no), Yes_no);
    ((fun f -> f.party_list), Party_list);
    ((fun f -> f.level_up), Level_up);
    ((fun f -> f.move_menu), Move_menu);
    ((fun f -> f.action_menu), Action_menu);
    ((fun f -> f.bag), Bag);
    ((fun f -> f.arrow), Text_arrow);
    ((fun f -> f.evolution), Evolution);
    ((fun f -> f.text_box || f.player_box || f.foe_box), Battle_text);
  ]

let classify f =
  match List.find_opt (fun (holds, _) -> holds f) order with
  | Some (_, screen) -> screen
  | None -> No_battle

let screen_name = function
  | Yes_no -> "yes/no"
  | Party_list -> "party list"
  | Level_up -> "level up"
  | Move_menu -> "move menu"
  | Action_menu -> "action menu"
  | Bag -> "bag"
  | Text_arrow -> "text arrow"
  | Evolution -> "evolution"
  | Battle_text -> "battle text"
  | No_battle -> "no battle"

let probes =
  Battle_screen.probes @ Battle_yes_no.probes @ Battle_text_arrow.probes
  @ Move_pp.probes @ Dark_corners.probes @ Party_menu.probes @ Bag_screen.probes
  @ Summary_screen.probes @ Move_list_cursor.probes

let of_measurements m =
  {
    action_menu = Battle_screen.battle_menu m;
    move_menu = Battle_screen.move_menu m;
    text_box = Battle_screen.battle_text_box m;
    level_up = Battle_screen.level_up_box m;
    player_box = Battle_screen.player_box m;
    foe_box = Battle_screen.foe_box m;
    party_list = Party_menu.party_menu m;
    bag = Bag_screen.bag_open m;
    yes_no = Battle_yes_no.yes_no_box m;
    arrow = Battle_text_arrow.advance_arrow m;
    evolution = Evolution_screen.evolution_shows m;
  }
